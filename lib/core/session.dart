import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'api_client.dart';

enum AuthStatus { unknown, signedOut, signedIn }

/// App-wide session state — mirrors what AccountController.LoginSubmit puts in the web Session, but
/// carried as a token instead of a cookie. loginType ("Admin"/"Employee") picks which shell
/// (EmployeeShell/AdminShell) the app shows; a user who has both an employee link and admin menu access
/// can switch without re-entering credentials (see AuthService.switchRole).
class Session extends ChangeNotifier {
  AuthStatus status = AuthStatus.unknown;
  int userId = 0;
  String userName = '';
  String loginType = 'Employee';
  int employeeId = 0;
  bool hasAdminAccess = false;
  String? photoUrl;

  static const _kUserId = 'session_userId';
  static const _kUserName = 'session_userName';
  static const _kLoginType = 'session_loginType';
  static const _kEmployeeId = 'session_employeeId';
  static const _kHasAdminAccess = 'session_hasAdminAccess';
  static const _kPhotoUrl = 'session_photoUrl';

  Future<void> restore() async {
    await ApiClient.instance.loadPersistedToken();
    final prefs = await SharedPreferences.getInstance();
    if (!ApiClient.instance.hasToken) {
      status = AuthStatus.signedOut;
      notifyListeners();
      return;
    }
    userId = prefs.getInt(_kUserId) ?? 0;
    userName = prefs.getString(_kUserName) ?? '';
    loginType = prefs.getString(_kLoginType) ?? 'Employee';
    employeeId = prefs.getInt(_kEmployeeId) ?? 0;
    hasAdminAccess = prefs.getBool(_kHasAdminAccess) ?? false;
    photoUrl = prefs.getString(_kPhotoUrl);
    status = AuthStatus.signedIn;
    notifyListeners();
  }

  Future<void> applyLogin({
    required String token,
    required int userId,
    required String userName,
    required String loginType,
    required int employeeId,
    required bool hasAdminAccess,
    String? photoUrl,
  }) async {
    await ApiClient.instance.setToken(token);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_kUserId, userId);
    await prefs.setString(_kUserName, userName);
    await prefs.setString(_kLoginType, loginType);
    await prefs.setInt(_kEmployeeId, employeeId);
    await prefs.setBool(_kHasAdminAccess, hasAdminAccess);
    if (photoUrl == null) {
      await prefs.remove(_kPhotoUrl);
    } else {
      await prefs.setString(_kPhotoUrl, photoUrl);
    }

    this.userId = userId;
    this.userName = userName;
    this.loginType = loginType;
    this.employeeId = employeeId;
    this.hasAdminAccess = hasAdminAccess;
    this.photoUrl = photoUrl;
    status = AuthStatus.signedIn;
    notifyListeners();
  }

  Future<void> updatePhotoUrl(String photoUrl) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kPhotoUrl, photoUrl);
    this.photoUrl = photoUrl;
    notifyListeners();
  }

  Future<void> signOut() async {
    await ApiClient.instance.setToken(null);
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kUserId);
    await prefs.remove(_kUserName);
    await prefs.remove(_kLoginType);
    await prefs.remove(_kEmployeeId);
    await prefs.remove(_kHasAdminAccess);
    await prefs.remove(_kPhotoUrl);
    userId = 0;
    userName = '';
    employeeId = 0;
    hasAdminAccess = false;
    photoUrl = null;
    status = AuthStatus.signedOut;
    notifyListeners();
  }
}
