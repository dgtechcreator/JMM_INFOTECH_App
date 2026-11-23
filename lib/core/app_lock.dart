import 'package:flutter/foundation.dart' show ChangeNotifier, kIsWeb;
import 'package:flutter/widgets.dart';
import 'package:local_auth/local_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Optional fingerprint / face (or phone PIN, pattern) unlock for the app.
///
/// What it does: when turned on, a signed-in user must verify themselves (a) when the app is opened from fully
/// closed and (b) when they come back after the app sat in the background for [graceAfterBackground] or more.
/// The sign-in itself is unchanged - this only guards an already signed-in app on a phone someone else may pick
/// up. The phone's own biometric prompt is used, so it also accepts the screen-lock PIN/pattern as a fallback
/// (a phone with a wet finger or a new enrolment must never lock the user out of their own attendance app).
///
/// Short trips out of the app (camera for a selfie, the permission dialogs, a map) stay under the grace period
/// and do not lock. The prompt itself pauses/resumes the Activity, so lifecycle changes that happen while it is
/// showing ([_busy]) are ignored.
///
/// The "on" switch is per phone and is cleared on sign-out, so the next person to sign in on the same phone
/// starts with their own choice.
class AppLockController extends ChangeNotifier with WidgetsBindingObserver {
  static const _kEnabled = 'app_lock_enabled';
  static const _kAsked = 'app_lock_asked';

  /// How long the app may sit in the background before it locks again.
  static const Duration graceAfterBackground = Duration(seconds: 60);

  final LocalAuthentication _auth = LocalAuthentication();

  bool enabled = false;
  bool locked = false;
  String? lastError;
  bool _busy = false;
  DateTime? _backgroundedAt;

  bool get busy => _busy;

  /// Call once before runApp. A cold start with the lock on starts locked.
  Future<void> init() async {
    if (kIsWeb) return;
    final prefs = await SharedPreferences.getInstance();
    enabled = prefs.getBool(_kEnabled) ?? false;
    locked = enabled;
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!enabled) return;
    if (state == AppLifecycleState.paused || state == AppLifecycleState.hidden) {
      if (!_busy) _backgroundedAt ??= DateTime.now();
    } else if (state == AppLifecycleState.resumed) {
      final at = _backgroundedAt;
      _backgroundedAt = null;
      if (!_busy && !locked && at != null && DateTime.now().difference(at) >= graceAfterBackground) {
        locked = true;
        notifyListeners();
      }
    }
  }

  /// Whether this phone can verify the user at all (biometrics enrolled, or a screen lock set).
  Future<bool> isSupported() async {
    if (kIsWeb) return false;
    try {
      return await _auth.isDeviceSupported();
    } catch (_) {
      return false;
    }
  }

  Future<bool> alreadyAsked() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_kAsked) ?? false;
  }

  Future<void> markAsked() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kAsked, true);
  }

  Future<bool> _verify(String reason) async {
    if (_busy) return false;
    _busy = true;
    lastError = null;
    try {
      // biometricOnly stays false: the phone PIN / pattern is an accepted fallback.
      return await _auth.authenticate(localizedReason: reason);
    } on LocalAuthException catch (e) {
      switch (e.code) {
        case LocalAuthExceptionCode.userCanceled:
        case LocalAuthExceptionCode.systemCanceled:
          lastError = null;
        case LocalAuthExceptionCode.noCredentialsSet:
        case LocalAuthExceptionCode.noBiometricsEnrolled:
        case LocalAuthExceptionCode.noBiometricHardware:
          lastError = 'Set a screen lock (PIN, pattern or fingerprint) in your phone settings first.';
        case LocalAuthExceptionCode.temporaryLockout:
        case LocalAuthExceptionCode.biometricLockout:
          lastError = 'Too many attempts. Wait a moment, then try again.';
        default:
          lastError = 'Could not verify you. Please try again.';
      }
      return false;
    } catch (_) {
      lastError = 'Could not verify you. Please try again.';
      return false;
    } finally {
      _busy = false;
      _backgroundedAt = null;
    }
  }

  /// Unlock screen button / automatic prompt. True when the user passed.
  Future<bool> unlock() async {
    final ok = await _verify('Unlock JMM InfoTech');
    if (ok) locked = false;
    notifyListeners();
    return ok;
  }

  /// Turn the lock on - only after the user proves it works on this phone.
  Future<bool> enable() async {
    if (!await isSupported()) {
      lastError = 'Set a screen lock (PIN, pattern or fingerprint) in your phone settings first.';
      notifyListeners();
      return false;
    }
    final ok = await _verify('Confirm to turn on fingerprint unlock');
    if (ok) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_kEnabled, true);
      enabled = true;
      locked = false;
    }
    notifyListeners();
    return ok;
  }

  /// Turning it off needs the same proof, so someone holding an unlocked phone cannot just switch it off.
  Future<bool> disable() async {
    final ok = await _verify('Confirm to turn off fingerprint unlock');
    if (ok) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_kEnabled, false);
      enabled = false;
      locked = false;
    }
    notifyListeners();
    return ok;
  }

  /// Signing out ends the lock (the next sign-in starts fresh and chooses again).
  Future<void> onSignedOut() async {
    if (!enabled && !locked) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kEnabled, false);
    enabled = false;
    locked = false;
    notifyListeners();
  }
}
