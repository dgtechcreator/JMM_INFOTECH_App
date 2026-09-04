import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Points at the ASP.NET MVC app's /EmployeeApp/* API (MVC.Web/Controllers/API/EmployeeAppController.cs).
/// Exactly one of the two lines below should be uncommented at a time — swap which one is active to
/// switch environments, then do a full rebuild (`flutter build apk`), not just hot reload.
class ApiConfig {
  // Live server — real HTTPS domain, works from anywhere (mobile data or any Wi-Fi), no Android
  // cleartext-traffic exception needed since it's HTTPS.
  static const String baseUrl = 'https://portal.jmmportal.com';

  // Local dev machine — LAN IP (not "localhost", which on a real phone means the phone itself).
  // Needs: IIS Express running + a matching host-header binding in applicationhost.config, a Windows
  // firewall rule for the port, a `netsh http add urlacl` reservation for this IP, the phone on the same
  // Wi-Fi as this machine, and the network_security_config.xml cleartext exception (already set up) —
  // update the IP below to match this machine's current one (Windows: `ipconfig`, Wi-Fi adapter IPv4).
  // static const String baseUrl = 'http://192.168.0.124:60080';
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
        handler.next(options);
      },
    ));
  }

  static final ApiClient instance = ApiClient._internal();
  late final Dio _dio;
  String? _token;

  Future<void> loadPersistedToken() async {
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
      throw ApiException(extractMessage(res.data, 'Your session has expired. Please log in again.'), statusCode: 401);
    }
  }
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
