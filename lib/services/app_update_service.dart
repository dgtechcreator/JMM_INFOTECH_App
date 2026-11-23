import 'dart:async';

import 'package:flutter/foundation.dart' show TargetPlatform, defaultTargetPlatform, kIsWeb, visibleForTesting;
import 'package:flutter/material.dart';
import 'package:in_app_update/in_app_update.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/app_config.dart';
import 'notification_router.dart' show navigatorKey;

/// "A new version is on the Play Store" for people who already have the app.
///
/// On every app open (and when the app comes back to the foreground after a while) it asks Google Play whether a
/// newer build of this app is available. If so, Play's own update dialog appears over the app ("Update" /
/// "No thanks") - the same experience as other Play apps - and the new version downloads in the background
/// while the user keeps working; when it is ready a "Restart" bar offers to install it. A build that has been
/// out for 3+ weeks, or one the developer marked high priority in Play Console, uses Play's full-screen
/// "must update now" flow instead.
///
/// Needs the app to be installed FROM Google Play with the same package (`com.jmm_infotech`) - a sideloaded
/// or debug APK can't be updated by Play, so there it quietly does nothing (or uses the portal-driven prompt
/// below). The portal's "minimum version" switch (AppGate's "Update required" screen) stays the hard stop for
/// versions that must not be used any more; this is the friendly nudge before that.
///
/// Fallback: when Play's updater can't be used at all (no Play services, not installed from Play) but the
/// portal says a newer version exists ("latest version code" in Mobile App Settings), a plain "Update
/// available" dialog opens the Play Store page instead.
class AppUpdateService {
  AppUpdateService._();

  static const _kDeclinedVersion = 'update_declined_version';
  static const _kDeclinedAt = 'update_declined_at';

  /// Do not ask Play again more often than this while the app stays in use.
  static const Duration recheckEvery = Duration(hours: 6);

  /// After "No thanks" for a version, wait this long before asking about the SAME version again
  /// (a newer version asks straight away).
  static const Duration reAskAfterDecline = Duration(hours: 24);

  static DateTime? _lastCheck;
  static bool _running = false;
  static StreamSubscription<InstallStatus>? _downloadSub;

  /// Whether to bring the update up again, given what the user did last time. Pure, so it is unit-tested.
  @visibleForTesting
  static bool shouldAsk({required int availableVersion, int? declinedVersion, DateTime? declinedAt, required DateTime now}) {
    if (declinedVersion == null || declinedAt == null) return true;
    if (declinedVersion != availableVersion) return true;
    return now.difference(declinedAt) >= reAskAfterDecline;
  }

  static bool get _supported => !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  /// Safe to call as often as you like: throttled, never throws, never blocks the UI.
  static Future<void> checkOnOpen({bool force = false}) async {
    if (!_supported || _running) return;
    final now = DateTime.now();
    if (!force && _lastCheck != null && now.difference(_lastCheck!) < recheckEvery) return;
    _running = true;
    _lastCheck = now;
    var playUnavailable = false;
    try {
      final info = await InAppUpdate.checkForUpdate();

      // An immediate update the user started earlier but did not finish: Play wants it resumed.
      if (info.updateAvailability == UpdateAvailability.developerTriggeredUpdateInProgress) {
        await InAppUpdate.performImmediateUpdate();
        return;
      }
      // A flexible update that finished downloading while the app was closed: just offer the restart.
      if (info.installStatus == InstallStatus.downloaded) {
        _offerRestart();
        return;
      }
      if (info.updateAvailability != UpdateAvailability.updateAvailable) return;

      final version = info.availableVersionCode ?? 0;
      final prefs = await SharedPreferences.getInstance();
      final declinedAtMs = prefs.getInt(_kDeclinedAt);
      final ask = shouldAsk(
        availableVersion: version,
        declinedVersion: prefs.getInt(_kDeclinedVersion),
        declinedAt: declinedAtMs == null ? null : DateTime.fromMillisecondsSinceEpoch(declinedAtMs),
        now: now,
      );
      if (!ask) return;

      final urgent = info.immediateUpdateAllowed && (info.updatePriority >= 4 || (info.clientVersionStalenessDays ?? 0) >= 21);
      AppUpdateResult result;
      if (urgent || !info.flexibleUpdateAllowed) {
        if (!info.immediateUpdateAllowed) return;
        result = await InAppUpdate.performImmediateUpdate();
      } else {
        result = await InAppUpdate.startFlexibleUpdate();
        if (result == AppUpdateResult.success) _watchDownload();
      }
      if (result == AppUpdateResult.userDeniedUpdate) {
        await prefs.setInt(_kDeclinedVersion, version);
        await prefs.setInt(_kDeclinedAt, now.millisecondsSinceEpoch);
      }
    } catch (_) {
      // Not installed from Play / no Play services / no network: Play's updater can't help here.
      playUnavailable = true;
    } finally {
      _running = false;
    }
    if (playUnavailable) await _portalFallback(now);
  }

  /// Once the flexible update has downloaded, show a "Restart" bar (Play restarts the app to install it).
  static void _watchDownload() {
    _downloadSub?.cancel();
    _downloadSub = InAppUpdate.installUpdateListener.listen((status) {
      if (status == InstallStatus.downloaded) {
        _downloadSub?.cancel();
        _downloadSub = null;
        _offerRestart();
      }
    }, onError: (_) {});
  }

  static void _offerRestart() {
    final ctx = navigatorKey.currentContext;
    if (ctx == null || !ctx.mounted) return;
    ScaffoldMessenger.of(ctx).showSnackBar(
      SnackBar(
        content: const Text('A new version has been downloaded.'),
        duration: const Duration(days: 1),
        behavior: SnackBarBehavior.floating,
        action: SnackBarAction(label: 'Restart', onPressed: () => InAppUpdate.completeFlexibleUpdate()),
      ),
    );
  }

  /// Portal-driven "Update available" dialog (Mobile App Settings -> latest version code) for installs where
  /// Play's own updater is unavailable. The "Update required" hard stop is separate (AppGate).
  static Future<void> _portalFallback(DateTime now) async {
    final ctx = navigatorKey.currentContext;
    if (ctx == null || !ctx.mounted) return;
    final config = ctx.read<AppConfigController>();
    final latest = config.config?.latestVersionCode ?? 0;
    if (latest <= config.currentVersionCode || config.forceUpdate) return;

    final prefs = await SharedPreferences.getInstance();
    final declinedAtMs = prefs.getInt(_kDeclinedAt);
    if (!shouldAsk(
      availableVersion: latest,
      declinedVersion: prefs.getInt(_kDeclinedVersion),
      declinedAt: declinedAtMs == null ? null : DateTime.fromMillisecondsSinceEpoch(declinedAtMs),
      now: now,
    )) {
      return;
    }
    if (!ctx.mounted) return;
    final name = config.config?.latestVersionName ?? '';
    final go = await showDialog<bool>(
      context: ctx,
      builder: (d) => AlertDialog(
        icon: const Icon(Icons.system_update_alt_rounded, size: 36),
        title: const Text('Update available'),
        content: Text(name.isEmpty
            ? 'A newer version of JMM InfoTech is available on Google Play.'
            : 'Version $name of JMM InfoTech is available on Google Play.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(d, false), child: const Text('Later')),
          FilledButton(onPressed: () => Navigator.pop(d, true), child: const Text('Update')),
        ],
      ),
    );
    if (go == true) {
      await config.openUpdatePage();
    } else {
      await prefs.setInt(_kDeclinedVersion, latest);
      await prefs.setInt(_kDeclinedAt, now.millisecondsSinceEpoch);
    }
  }
}
