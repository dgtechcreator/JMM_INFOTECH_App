import 'dart:math';

import 'package:android_id/android_id.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Who this phone is, as reported to the server at login (Login Activity / "where am I signed in") and on
/// every app start (so a session that predates login tracking gets linked to its device).
///
/// [deviceId] is the Android ID — stable for this phone + this app's signing key across reinstalls and
/// clear-data, which is exactly what "is the same physical phone used by two different accounts?" needs.
/// If the platform refuses to give one, a random install id (persisted) is used instead: still stable for
/// the life of the install, just not across a reinstall.
///
/// This is self-reported (an audit aid for the admin, not hardware attestation) — the server separately
/// records the IP it actually saw.
class DeviceIdentity {
  DeviceIdentity({
    required this.deviceId,
    required this.deviceName,
    required this.platform,
    required this.osVersion,
    required this.appVersion,
  });

  final String deviceId;
  final String deviceName;
  final String platform;
  final String osVersion;
  final String appVersion;

  static DeviceIdentity? _cached;

  static Future<DeviceIdentity> load() async {
    final cached = _cached;
    if (cached != null) return cached;

    String deviceId = '';
    String deviceName = 'Unknown device';
    String osVersion = '';
    String appVersion = '';

    // defaultTargetPlatform (not dart:io's Platform) so this also runs in a Flutter web build, which is how UI
    // changes get checked quickly in a browser.
    final isAndroid = !kIsWeb && defaultTargetPlatform == TargetPlatform.android;
    final isIos = !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;
    if (kIsWeb) deviceName = 'Web browser';

    try {
      final info = DeviceInfoPlugin();
      if (isAndroid) {
        final a = await info.androidInfo;
        final maker = a.manufacturer.isEmpty ? '' : '${a.manufacturer[0].toUpperCase()}${a.manufacturer.substring(1)} ';
        deviceName = '$maker${a.model}'.trim();
        osVersion = 'Android ${a.version.release}';
        try {
          deviceId = (await const AndroidId().getId()) ?? '';
        } catch (_) {}
      } else if (isIos) {
        final i = await info.iosInfo;
        deviceName = i.utsname.machine.isNotEmpty ? i.utsname.machine : i.model;
        osVersion = 'iOS ${i.systemVersion}';
        deviceId = i.identifierForVendor ?? '';
      }
    } catch (_) {
      // Keep the defaults: a failure to describe the phone must never stop a login.
    }

    try {
      final p = await PackageInfo.fromPlatform();
      appVersion = p.version;
    } catch (_) {}

    if (deviceId.isEmpty) {
      deviceId = await _installId();
    }

    final identity = DeviceIdentity(
      deviceId: deviceId,
      deviceName: deviceName,
      platform: kIsWeb ? 'web' : (isAndroid ? 'android' : (isIos ? 'ios' : 'other')),
      osVersion: osVersion,
      appVersion: appVersion,
    );
    _cached = identity;
    return identity;
  }

  static Future<String> _installId() async {
    const key = 'install_device_id';
    final prefs = await SharedPreferences.getInstance();
    var id = prefs.getString(key);
    if (id == null || id.isEmpty) {
      final r = Random.secure();
      id = 'inst-${List.generate(16, (_) => r.nextInt(16).toRadixString(16)).join()}';
      await prefs.setString(key, id);
    }
    return id;
  }

  /// Form fields the API reads (ClientInfo.FromMobileRequest) — form fields rather than custom headers,
  /// because the /EmployeeApp/ CORS policy only allows Content-Type and X-Auth-Token.
  Map<String, dynamic> toFormFields() => {
        'deviceId': deviceId,
        'deviceName': deviceName,
        'platform': platform,
        'osVersion': osVersion,
        'appVersion': appVersion,
      };
}
