import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:shared_preferences/shared_preferences.dart';

/// Points at the ASP.NET MVC app's /EmployeeApp/* API (MVC.Web/Controllers/API/EmployeeAppController.cs).
///
/// The address is NOT fixed at build time any more: the portal's "Mobile App Settings" page can hand the app
/// a new server address (and backups) via /EmployeeApp/GetAppConfig (see app_config.dart), so moving the
/// server or changing the domain no longer needs a new APK on every phone. What happens:
///   * [_compiledBaseUrl] is the built-in address — always remembered as a last resort.
///   * A server-supplied address is stored as an override ([setActive]) only after the app has confirmed that
///     it answers, and survives restarts (SharedPreferences, so the background trip service sees it too).
///   * If a request cannot even connect, ApiClient retries it on the [fallbacks] / built-in address and
///     remembers whichever works.
/// A dev build started with --dart-define=API_BASE_URL=... is "pinned": it never follows remote settings, so
/// pointing a test phone at a local machine can't be undone behind your back.
class ApiConfig {
  // Live server — real HTTPS domain, works from anywhere (mobile data or any Wi-Fi), no Android
  // cleartext-traffic exception needed since it's HTTPS.
  //
  // A dev build can point elsewhere WITHOUT editing this file:
  //   flutter run --dart-define=API_BASE_URL=http://<your-dev-machine>:<port>
  // (the default below is what every normal/release build uses).
  static const String _compiledBaseUrl = String.fromEnvironment('API_BASE_URL', defaultValue: 'https://portal.jmmportal.com');
  static const bool isPinned = bool.hasEnvironment('API_BASE_URL');

  static const _kOverride = 'api_base_override';
  static const _kFallbacks = 'api_fallback_urls';

  static String? _override;
  static List<String> _fallbacks = const [];

  /// The address every request uses right now.
  static String get baseUrl => _override ?? _compiledBaseUrl;
  static String get compiledBaseUrl => _compiledBaseUrl;
  static List<String> get fallbacks => _fallbacks;

  /// Every address worth trying, in order: current, server-supplied backups, built-in. No duplicates.
  /// Pinned (dev) builds only ever have their own address.
  static List<String> get candidates {
    if (isPinned) return [_compiledBaseUrl];
    final out = <String>[];
    for (final u in [baseUrl, ..._fallbacks, _compiledBaseUrl]) {
      if (!out.contains(u)) out.add(u);
    }
    return out;
  }

  /// Only ever accept https addresses from the server (and a built-in one) — never downgrade to plain HTTP.
  static bool isAcceptable(String? url) {
    if (url == null) return false;
    final uri = Uri.tryParse(url.trim());
    return uri != null && uri.scheme == 'https' && uri.host.isNotEmpty;
  }

  static String normalize(String url) => url.trim().replaceFirst(RegExp(r'/+$'), '');

  static Future<void> loadPersisted() async {
    if (isPinned) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString(_kOverride);
      _override = isAcceptable(saved) ? normalize(saved!) : null;
      _fallbacks = (prefs.getStringList(_kFallbacks) ?? const []).where(isAcceptable).map(normalize).toList();
    } catch (_) {
      // Preferences unreadable -> keep the built-in address; never block startup on this.
    }
  }

  /// Switch the address used from now on (and across restarts). Passing the built-in address clears the override.
  static Future<void> setActive(String url) async {
    if (isPinned || !isAcceptable(url)) return;
    final clean = normalize(url);
    _override = clean == _compiledBaseUrl ? null : clean;
    try {
      final prefs = await SharedPreferences.getInstance();
      if (_override == null) {
        await prefs.remove(_kOverride);
      } else {
        await prefs.setString(_kOverride, _override!);
      }
    } catch (_) {}
  }

  /// Test seam: forget any override/backups held in memory.
  @visibleForTesting
  static void resetForTest() {
    _override = null;
    _fallbacks = const [];
  }

  static Future<void> setFallbacks(List<String> urls) async {
    if (isPinned) return;
    _fallbacks = urls.where(isAcceptable).map(normalize).take(5).toList();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(_kFallbacks, _fallbacks);
    } catch (_) {}
  }
}

const String _tokenPrefsKey = 'auth_token';

/// Thin Dio wrapper: attaches the X-Auth-Token header (MVC.Web/Action_Filter/MobileAuthAttribute.cs)
/// automatically to every request once a token is set, and exposes the plain get/post helpers the
/// per-feature services use.
class ApiClient {
  ApiClient._internal() {
    _dio = Dio(BaseOptions(
      baseUrl: ApiConfig.baseUrl,
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 20),
      validateStatus: (status) => status != null && status < 500,
    ));
    _dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) {
        if (_token != null) {
          options.headers['X-Auth-Token'] = _token;
        }
        // The address can change at runtime (remote settings / failover), so resolve it per request — except
        // for a failover retry, which deliberately carries its own address.
        if (options.extra['failover'] != true) {
          options.baseUrl = ApiConfig.baseUrl;
        }
        handler.next(options);
      },
      onError: _failOver,
    ));
  }

  /// Test seam: swap the HTTP transport for a fake one.
  @visibleForTesting
  void useAdapter(HttpClientAdapter adapter) => _dio.httpClientAdapter = adapter;

  static bool _isConnectivityFailure(DioException e) =>
      e.type == DioExceptionType.connectionError || e.type == DioExceptionType.connectionTimeout;

  /// The request never reached a server (DNS failure, refused, unreachable, connect timeout) — try the other
  /// known addresses once. Whichever answers becomes the active address until the portal says otherwise. A
  /// response of ANY kind (even 4xx/5xx) means a server was reached, so that is never retried here.
  Future<void> _failOver(DioException err, ErrorInterceptorHandler handler) async {
    final ro = err.requestOptions;
    if (ApiConfig.isPinned || ro.extra['failover'] == true || !_isConnectivityFailure(err)) {
      return handler.next(err);
    }
    for (final alt in ApiConfig.candidates) {
      if (alt == ro.baseUrl) continue;
      try {
        final data = ro.data;
        final retry = ro.copyWith(
          baseUrl: alt,
          connectTimeout: const Duration(seconds: 6),
          data: data is FormData ? data.clone() : data,
          extra: {...ro.extra, 'failover': true},
        );
        final res = await _dio.fetch(retry);
        await ApiConfig.setActive(alt);
        return handler.resolve(res);
      } on DioException catch (e) {
        if (_isConnectivityFailure(e)) continue; // this one is down too — next address
        return handler.next(e); // reached a server that answered with an error: surface that answer
      } catch (_) {
        return handler.next(err); // e.g. the body could not be re-sent
      }
    }
    handler.next(err);
  }

  static final ApiClient instance = ApiClient._internal();
  late final Dio _dio;
  String? _token;

  Future<void> loadPersistedToken() async {
    // Also loads the persisted server address: the background trip-tracking isolate has its own copy of this
    // singleton and only calls this method, so this keeps it on the same address as the main app.
    await ApiConfig.loadPersisted();
    final prefs = await SharedPreferences.getInstance();
    _token = prefs.getString(_tokenPrefsKey);
  }

  Future<void> setToken(String? token) async {
    _token = token;
    final prefs = await SharedPreferences.getInstance();
    if (token == null) {
      await prefs.remove(_tokenPrefsKey);
    } else {
      await prefs.setString(_tokenPrefsKey, token);
    }
  }

  bool get hasToken => _token != null;

  /// Exposed (read-only) for building a PDF view/download URL to hand to url_launcher — those open in
  /// the device's external browser/PDF viewer, which can't carry the X-Auth-Token header the interceptor
  /// above attaches, so the token has to travel as a `?token=` query param instead. MobileAuthAttribute
  /// already accepts that as a fallback to the header (see its ValidateToken check), purely to support
  /// this exact "open a link outside the app" case.
  String? get token => _token;

  Future<Response<T>> get<T>(String path, {Map<String, dynamic>? query}) async {
    final res = await _dio.get<T>(path, queryParameters: query);
    _throwIfUnauthorized(res);
    return res;
  }

  /// POSTs as multipart/form-data with fields matching parameter/property names directly (no JSON
  /// envelope) — this is the exact wire format the existing web app's jQuery AJAX calls already use
  /// against these same ASP.NET MVC model-bound actions (both plain scalar-parameter actions and
  /// single-complex-type actions bind this way; MVC treats multipart and x-www-form-urlencoded the same
  /// for non-file fields). Using one consistent encoding for every POST — instead of Dio's JSON default,
  /// which ASP.NET MVC's JSON binder handles differently for a named complex parameter — avoids a whole
  /// class of "silently didn't bind" bugs.
  Future<Response<T>> post<T>(String path, {Map<String, dynamic>? data, FormData? form}) async {
    final body = form ?? (data != null ? FormData.fromMap(data) : null);
    final res = await _dio.post<T>(path, data: body);
    _throwIfUnauthorized(res);
    return res;
  }

  /// [MobileAuthAttribute] returns 401 with a valid-looking JSON body ({status, message}) rather than
  /// failing the request outright — Dio's validateStatus (status < 500) treats that as a normal response,
  /// so every service's `Model.fromJson(res.data)` would otherwise silently parse that {status, message}
  /// shape into a model full of default/zero values instead of surfacing that the session is invalid.
  void _throwIfUnauthorized(Response res) {
    if (res.statusCode == 401) {
      // A 401 on a request that CARRIED a token means the session itself ended (signed out from another
      // device, password changed, admin forced logout, or expiry) — let the app really sign out instead of
      // leaving every screen showing "Unauthorized". A 401 with no token is just a wrong login attempt.
      if (_token != null) onUnauthorized?.call();
      throw ApiException(extractMessage(res.data, 'Your session has expired. Please log in again.'), statusCode: 401);
    }
  }

  /// Set once from main.dart; see [_throwIfUnauthorized].
  static void Function()? onUnauthorized;
}

/// Raised by service methods when the API returns a non-2xx/handled-error body, carrying a
/// user-presentable message pulled from the API's own {message}/{Message} JSON field where possible.
class ApiException implements Exception {
  ApiException(this.message, {this.statusCode});
  final String message;
  final int? statusCode;

  @override
  String toString() => message;
}

String extractMessage(dynamic data, String fallback) {
  if (data is Map) {
    final m = data['message'] ?? data['Message'];
    if (m != null) return m.toString();
  }
  return fallback;
}

/// The API stores/returns profile photo paths as a server-relative path (e.g. "/assets/ProfilePhotos/4.jpg")
/// — needs ApiConfig.baseUrl prepended before it's a URL Image.network can load.
String? resolvePhotoUrl(String? path) {
  if (path == null || path.isEmpty) return null;
  if (path.startsWith('http')) return path;
  return '${ApiConfig.baseUrl}$path';
}
