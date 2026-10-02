import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import 'api_client.dart';

/// What the portal's "Mobile App Settings" page tells the app (GET /EmployeeApp/GetAppConfig, public — it is
/// asked before login). Only the settings marked public on the portal are ever included.
class AppConfig {
  const AppConfig({
    this.apiBaseUrl = '',
    this.fallbackUrls = const [],
    this.minVersionCode = 0,
    this.latestVersionCode = 0,
    this.latestVersionName = '',
    this.updateUrl = '',
    this.updateMessage = '',
    this.maintenanceEnabled = false,
    this.maintenanceMessage = '',
    this.companyName = '',
    this.supportEmail = '',
    this.supportPhone = '',
    this.privacyPolicyUrl = '',
    this.placesApiKey = '',
  });

  final String apiBaseUrl;
  final List<String> fallbackUrls;
  final int minVersionCode;
  final int latestVersionCode;
  final String latestVersionName;
  final String updateUrl;
  final String updateMessage;
  final bool maintenanceEnabled;
  final String maintenanceMessage;
  final String companyName;
  final String supportEmail;
  final String supportPhone;
  final String privacyPolicyUrl;

  /// Search / address (Places + Geocoding REST) key set on the portal; '' = use the built-in key.
  final String placesApiKey;

  static int _int(dynamic v) => v is num ? v.toInt() : int.tryParse('$v') ?? 0;
  static String _str(dynamic v) => v == null ? '' : '$v';

  factory AppConfig.fromJson(Map<String, dynamic> j) => AppConfig(
        apiBaseUrl: _str(j['apiBaseUrl']),
        fallbackUrls: (j['fallbackUrls'] is List) ? (j['fallbackUrls'] as List).map(_str).toList() : const [],
        minVersionCode: _int(j['minVersionCode']),
        latestVersionCode: _int(j['latestVersionCode']),
        latestVersionName: _str(j['latestVersionName']),
        updateUrl: _str(j['updateUrl']),
        updateMessage: _str(j['updateMessage']),
        maintenanceEnabled: j['maintenanceEnabled'] == true,
        maintenanceMessage: _str(j['maintenanceMessage']),
        companyName: _str(j['companyName']),
        supportEmail: _str(j['supportEmail']),
        supportPhone: _str(j['supportPhone']),
        privacyPolicyUrl: _str(j['privacyPolicyUrl']),
        placesApiKey: _str(j['placesApiKey']),
      );

  Map<String, dynamic> toJson() => {
        'apiBaseUrl': apiBaseUrl,
        'fallbackUrls': fallbackUrls,
        'minVersionCode': minVersionCode,
        'latestVersionCode': latestVersionCode,
        'latestVersionName': latestVersionName,
        'updateUrl': updateUrl,
        'updateMessage': updateMessage,
        'maintenanceEnabled': maintenanceEnabled,
        'maintenanceMessage': maintenanceMessage,
        'companyName': companyName,
        'supportEmail': supportEmail,
        'supportPhone': supportPhone,
        'privacyPolicyUrl': privacyPolicyUrl,
        'placesApiKey': placesApiKey,
      };
}

/// Keys the portal can hand to the app at runtime (see AppConfig.placesApiKey). Static so plain service classes
/// (no BuildContext) can read them. Not the native map-tile key: that one is read from the manifest at startup.
class RemoteKeys {
  static String? placesKey;
}

/// Fetches, caches and applies the portal's remote settings:
///   * a new server address / backups  -> [ApiConfig] (only after the new address is confirmed to answer),
///   * a minimum allowed version       -> [forceUpdate] ("Update required" screen, see widgets/app_gate.dart),
///   * maintenance mode                -> [maintenance] (live only: never cached, so a stale flag can't trap anyone).
///
/// Failing to reach the portal is never an error for the user: the last known settings stay in effect and the
/// app carries on (the normal request failover in ApiClient still applies).
class AppConfigController extends ChangeNotifier {
  /// [fetcher] replaces the real network call — a seam for unit tests only.
  AppConfigController({this._fetcher});

  final Future<AppConfig?> Function(String baseUrl)? _fetcher;

  static const _kCache = 'remote_app_config_json';
  static const _staleAfter = Duration(minutes: 10);

  AppConfig? config;
  int currentVersionCode = 0;
  bool maintenance = false;
  bool refreshing = false;
  DateTime? _lastRefresh;

  bool get forceUpdate => config != null && config!.minVersionCode > 0 && config!.minVersionCode > currentVersionCode;

  String get updateMessage =>
      (config?.updateMessage.isNotEmpty ?? false) ? config!.updateMessage : 'A newer version of the app is required. Please update to continue.';

  String get maintenanceMessage =>
      (config?.maintenanceMessage.isNotEmpty ?? false) ? config!.maintenanceMessage : 'The app is under maintenance. Please try again shortly.';

  String get privacyPolicyUrl =>
      (config?.privacyPolicyUrl.isNotEmpty ?? false) && ApiConfig.isAcceptable(config!.privacyPolicyUrl)
          ? config!.privacyPolicyUrl
          : '${ApiConfig.baseUrl}/PrivacyPolicy';

  /// Loads this build's version code and the last cached settings. Fast and offline-safe — call before runApp.
  Future<void> init() async {
    try {
      final info = await PackageInfo.fromPlatform();
      currentVersionCode = int.tryParse(info.buildNumber) ?? 0;
    } catch (_) {}
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_kCache);
      if (raw != null) {
        config = AppConfig.fromJson(jsonDecode(raw) as Map<String, dynamic>);
        RemoteKeys.placesKey = config!.placesApiKey.isEmpty ? null : config!.placesApiKey;
      }
    } catch (_) {}
  }

  Future<void> refreshIfStale() async {
    if (_lastRefresh == null || DateTime.now().difference(_lastRefresh!) > _staleAfter) {
      await refresh();
    }
  }

  Future<void> refresh() async {
    if (refreshing) return;
    refreshing = true;
    notifyListeners();
    try {
      for (final url in ApiConfig.candidates) {
        final cfg = await _fetch(url);
        if (cfg != null) {
          await _apply(cfg, answeredBy: url);
          _lastRefresh = DateTime.now();
          return;
        }
      }
      // Nobody answered: keep what we have (cached settings, current address, no maintenance block).
    } finally {
      refreshing = false;
      notifyListeners();
    }
  }

  Future<AppConfig?> _fetch(String baseUrl) async {
    if (_fetcher != null) return _fetcher(baseUrl);
    try {
      final dio = Dio(BaseOptions(
        baseUrl: baseUrl,
        connectTimeout: const Duration(seconds: 6),
        receiveTimeout: const Duration(seconds: 8),
        validateStatus: (s) => s != null && s < 500,
      ));
      final res = await dio.get('/EmployeeApp/GetAppConfig', queryParameters: {'platform': 'android', 'versionCode': currentVersionCode});
      final data = res.data;
      if (res.statusCode == 200 && data is Map && '${data['status']}' == '1' && data['config'] is Map) {
        return AppConfig.fromJson(Map<String, dynamic>.from(data['config'] as Map));
      }
    } catch (_) {}
    return null;
  }

  Future<void> _apply(AppConfig cfg, {required String answeredBy}) async {
    // 1. Backup addresses (https only, max 5 — enforced again inside ApiConfig).
    await ApiConfig.setFallbacks(cfg.fallbackUrls);

    // 2. The server address. answeredBy is known to work. A different address from the portal is adopted only
    //    if it ALSO answers like the portal — a typo or not-yet-live address on the settings page can never
    //    strand the phones, they just stay where they are.
    var target = answeredBy;
    final remote = cfg.apiBaseUrl.trim();
    if (ApiConfig.isAcceptable(remote)) {
      final clean = ApiConfig.normalize(remote);
      if (clean == ApiConfig.normalize(answeredBy) || await _fetch(clean) != null) {
        target = clean;
      }
    }
    await ApiConfig.setActive(target);

    // 3. Version gate + maintenance + cache.
    config = cfg;
    RemoteKeys.placesKey = cfg.placesApiKey.isEmpty ? null : cfg.placesApiKey;
    maintenance = cfg.maintenanceEnabled;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_kCache, jsonEncode(cfg.toJson()));
    } catch (_) {}
  }

  /// "Update now": the portal's update link (Google Play), else the market:// deep link for this app.
  Future<void> openUpdatePage() async {
    final link = config?.updateUrl ?? '';
    final uri = Uri.tryParse(link);
    if (uri != null && uri.hasScheme) {
      if (await launchUrl(uri, mode: LaunchMode.externalApplication)) return;
    }
    try {
      final info = await PackageInfo.fromPlatform();
      await launchUrl(Uri.parse('market://details?id=${info.packageName}'), mode: LaunchMode.externalApplication);
    } catch (e) {
      debugPrint('openUpdatePage failed: $e');
    }
  }

  Future<bool> openPrivacyPolicy() async {
    final uri = Uri.tryParse(privacyPolicyUrl);
    if (uri == null) return false;
    return launchUrl(uri, mode: LaunchMode.externalApplication);
  }
}
