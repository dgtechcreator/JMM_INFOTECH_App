import 'package:flutter_test/flutter_test.dart';
import 'package:jmm_employee_app/services/app_update_service.dart';

void main() {
  final now = DateTime(2026, 11, 23, 12);

  test('asks when the user has never declined', () {
    expect(AppUpdateService.shouldAsk(availableVersion: 20, now: now), isTrue);
  });

  test('does not ask again about the same version within 24 hours of "No thanks"', () {
    expect(
      AppUpdateService.shouldAsk(availableVersion: 20, declinedVersion: 20, declinedAt: now.subtract(const Duration(hours: 5)), now: now),
      isFalse,
    );
  });

  test('asks again about the same version once 24 hours have passed', () {
    expect(
      AppUpdateService.shouldAsk(availableVersion: 20, declinedVersion: 20, declinedAt: now.subtract(const Duration(hours: 25)), now: now),
      isTrue,
    );
  });

  test('a newer version asks straight away even right after a decline', () {
    expect(
      AppUpdateService.shouldAsk(availableVersion: 21, declinedVersion: 20, declinedAt: now.subtract(const Duration(minutes: 5)), now: now),
      isTrue,
    );
  });
}
