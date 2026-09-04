import 'package:flutter_test/flutter_test.dart';

import 'package:jmm_employee_app/core/session.dart';

void main() {
  test('Session defaults to unknown before restore()', () {
    final session = Session();
    expect(session.status, AuthStatus.unknown);
    expect(session.loginType, 'Employee');
    expect(session.hasAdminAccess, isFalse);
  });
}
