import 'dart:async';
import 'dart:convert';
import 'dart:ui';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:geolocator/geolocator.dart';

import '../core/api_client.dart';
import 'trip_cache_service.dart';
import 'visit_service.dart';

/// Battery-friendly, keeps-running-when-closed trip location tracking, 2026-09-27.
///
/// Design (per the user's explicit ask, "20-20 meter ka data cached data me save karte jao phone me
/// then har 20 mins me usko database me save karte jao"):
/// - A location reading is only taken/cached when the device has actually moved ~20m
///   (`LocationSettings.distanceFilter`), not on a fixed timer — this is the actual battery saving, far
///   more than batching alone: no movement (parked, indoors, stationary) means no GPS wake-ups at all.
/// - Each reading goes into a local SQLite cache (TripCacheService) immediately — fast, free, no network.
/// - Every 20 minutes, the whole cache for the active trip is flushed to the server in one batch call
///   (SaveTripPingsBatch) — turns what would be dozens of individual requests into one.
/// - Runs inside `flutter_background_service`'s background isolate (Android foreground service / iOS
///   background modes), so it keeps working after the user backgrounds or fully closes the app — the
///   previous implementation (a plain `Timer` inside TripMapScreen's State) stopped the instant that
///   screen was closed, which is exactly what the user flagged as wrong.
///
/// Also handles the "employee turned off location/internet mid-trip" alert: while a trip is active, this
/// watches `Geolocator.getServiceStatusStream()` and `Connectivity().onConnectivityChanged` and reports a
/// transition to off immediately via ReportTripAnomaly, and the transition back on via
/// ResolveTripAnomaly.
///
/// **Two things this genuinely cannot do, and no regular (non-MDM) app can**: it cannot stop the user
/// from actually toggling GPS/Wi-Fi off — Android/iOS give apps no API to lock their own settings toggles;
/// the best any app can do is detect it and react (report it, nag the user) — and it cannot detect the
/// instant a phone is physically powered off, since nothing runs on a powered-off phone to report that.
/// The "Disconnected" case is instead inferred server-side by a watchdog (TripAnomalyWatchdogService,
/// MVC.Services) — if an active trip goes quiet for longer than one full sync cycle, it's flagged and
/// admins notified. Reporting NetworkOff itself is inherently best-effort for the same reason: the app
/// tries to tell the server the instant connectivity drops, but if it's genuinely offline that call can't
/// succeed either — the watchdog is the real safety net for a sustained outage, this is just a faster
/// path for the common case (e.g. GPS off but Wi-Fi/data still up, or a brief connectivity blip).
///
/// **Not verified on a real device** — this environment has no physical phone/emulator available (same
/// standing limitation as every other Flutter change in this project, see project memory). Verified only
/// via `flutter analyze` (0 errors). Background-service behavior, and especially OEM battery-optimization
/// behavior (Xiaomi/Oppo/Vivo/Samsung aggressively kill background work unless the user manually
/// whitelists the app — no app can fully prevent this on its own), needs real field testing before relying
/// on it for live tracking.
class TripTrackingService {
  static const _flushInterval = Duration(minutes: 20);
  static const _distanceFilterMeters = 20;

  static Future<void> initialize() async {
    final service = FlutterBackgroundService();
    await service.configure(
      androidConfiguration: AndroidConfiguration(
        onStart: _onStart,
        autoStart: false,
        isForegroundMode: true,
        notificationChannelId: 'trip_tracking_channel',
        initialNotificationTitle: 'JMM Field Visit',
        initialNotificationContent: 'Ready',
        foregroundServiceNotificationId: 9001,
      ),
      iosConfiguration: IosConfiguration(
        autoStart: false,
        onForeground: _onStart,
        onBackground: _onIosBackground,
      ),
    );
  }

  /// Called from TripMapScreen when the employee taps "Start Trip" — starts (or reuses) the background
  /// service, then hands it the trip id. Can't pass the trip id as a start parameter with this package's
  /// API, only via invoke() after the service is up, which is why this is two steps.
  static Future<void> startTracking(int tripId) async {
    final service = FlutterBackgroundService();
    if (!await service.isRunning()) {
      await service.startService();
      // Give the background isolate a moment to register its `on('startTrip')` listener before the
      // first invoke — a fixed short delay is what this package's own examples use, since there's no
      // "ready" signal in its public API.
      await Future.delayed(const Duration(milliseconds: 500));
    }
    service.invoke('startTrip', {'tripId': tripId});
  }

  /// Called from TripMapScreen when the employee taps "End Trip" — flushes any remaining cached pings
  /// and stops the background service.
  static Future<void> stopTracking() async {
    FlutterBackgroundService().invoke('stopTrip');
  }

  @pragma('vm:entry-point')
  static void _onStart(ServiceInstance service) async {
    DartPluginRegistrant.ensureInitialized();

    int? activeTripId;
    StreamSubscription<Position>? positionSub;
    Timer? flushTimer;
    StreamSubscription<ServiceStatus>? locationServiceSub;
    StreamSubscription<List<ConnectivityResult>>? connectivitySub;
    bool locationWasOn = true;
    bool networkWasOn = true;

    await ApiClient.instance.loadPersistedToken();
    final visitService = VisitService();

    Future<void> flush() async {
      final tripId = activeTripId;
      if (tripId == null) return;
      final pending = await TripCacheService.getPending(tripId);
      if (pending.isEmpty) return;
      try {
        final json = jsonEncode(pending
            .map((p) => {'lat': p.lat, 'lng': p.lng, 'capturedOn': p.capturedOn.toIso8601String()})
            .toList());
        await visitService.saveTripPingsBatch(tripId, json);
        await TripCacheService.clearSynced(tripId, pending.map((p) => p.id!).whereType<int>().toList());
      } catch (_) {
        // Left cached — picked up again on the next cycle. Never dropped, worst case just late.
      }
    }

    Future<void> stopAll() async {
      await flush();
      await positionSub?.cancel();
      await locationServiceSub?.cancel();
      await connectivitySub?.cancel();
      flushTimer?.cancel();
      activeTripId = null;
      if (service is AndroidServiceInstance) {
        service.stopSelf();
      }
    }

    service.on('startTrip').listen((event) async {
      final tripId = event?['tripId'] as int?;
      if (tripId == null) return;
      activeTripId = tripId;

      if (service is AndroidServiceInstance) {
        service.setForegroundNotificationInfo(
          title: 'JMM Field Visit',
          content: 'Trip in progress — tracking your location',
        );
      }

      await positionSub?.cancel();
      positionSub = Geolocator.getPositionStream(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high, distanceFilter: _distanceFilterMeters),
      ).listen((pos) {
        final id = activeTripId;
        if (id != null) {
          TripCacheService.addPing(id, pos.latitude, pos.longitude, DateTime.now());
        }
      });

      flushTimer?.cancel();
      flush(); // also flush right away so the very first reading doesn't wait the full 20 minutes
      flushTimer = Timer.periodic(_flushInterval, (_) => flush());

      await locationServiceSub?.cancel();
      locationServiceSub = Geolocator.getServiceStatusStream().listen((status) async {
        final isOn = status == ServiceStatus.enabled;
        if (isOn == locationWasOn) return;
        locationWasOn = isOn;
        final id = activeTripId;
        if (id == null) return;
        try {
          if (isOn) {
            await visitService.resolveTripAnomaly(id, 'LocationOff');
          } else {
            await visitService.reportTripAnomaly(id, 'LocationOff');
          }
        } catch (_) {}
      });

      await connectivitySub?.cancel();
      connectivitySub = Connectivity().onConnectivityChanged.listen((results) async {
        final isOn = results.isNotEmpty && !results.contains(ConnectivityResult.none);
        if (isOn == networkWasOn) return;
        networkWasOn = isOn;
        final id = activeTripId;
        if (id == null) return;
        try {
          if (isOn) {
            await visitService.resolveTripAnomaly(id, 'NetworkOff');
          } else {
            // Best-effort only — see the class doc comment on why this can't be guaranteed to reach the
            // server while genuinely offline. A synced batch on reconnect resolves it automatically too.
            await visitService.reportTripAnomaly(id, 'NetworkOff');
          }
        } catch (_) {}
      });
    });

    service.on('stopTrip').listen((event) => stopAll());
  }

  @pragma('vm:entry-point')
  static bool _onIosBackground(ServiceInstance service) {
    return true;
  }
}
