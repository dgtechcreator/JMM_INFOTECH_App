import 'package:flutter_test/flutter_test.dart';
import 'package:jmm_employee_app/core/session.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('a plain server photo URL gets a cache-busting version on every sign-in', () async {
    SharedPreferences.setMockInitialValues({});
    final s = Session();

    await s.applyLogin(
      token: 't',
      userId: 4,
      userName: 'VIVEK PAL',
      loginType: 'Employee',
      employeeId: 3,
      hasAdminAccess: false,
      photoUrl: '/assets/ProfilePhotos/4.jpg',
    );

    expect(s.photoUrl, startsWith('/assets/ProfilePhotos/4.jpg?v='));
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('session_photoUrl'), s.photoUrl); // the stored value is the versioned one
  });

  test('an already-versioned URL is left alone; null/empty stay empty', () {
    expect(Session.withPhotoVersion('/a/4.jpg?v=123'), '/a/4.jpg?v=123');
    expect(Session.withPhotoVersion('/a/4.jpg?x=1'), startsWith('/a/4.jpg?x=1&v='));
    expect(Session.withPhotoVersion(null), isNull);
    expect(Session.withPhotoVersion(''), '');
  });
}
