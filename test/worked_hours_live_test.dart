import 'package:flutter_test/flutter_test.dart';
import 'package:jmm_employee_app/core/date_format.dart';

void main() {
  final now = DateTime(2026, 10, 2, 20, 4);

  test('punched in, not out: counts whole minutes since punch-in (live)', () {
    int at(DateTime n) => liveWorkedMinutes(punchIn: '2026-10-02T17:49:00', punchOut: null, serverMinutes: 0, now: n);
    expect(at(DateTime(2026, 10, 2, 17, 49, 40)), 0);
    expect(at(DateTime(2026, 10, 2, 18, 50)), 61);
    expect(at(now), 135); // 2h 15m
  });

  test('punched out: uses the server figure, not the clock', () {
    expect(liveWorkedMinutes(punchIn: '2026-10-02T09:02:00', punchOut: '2026-10-02T18:15:00', serverMinutes: 553, now: now), 553);
  });

  test('not punched in yet: server figure (0)', () {
    expect(liveWorkedMinutes(punchIn: null, punchOut: null, serverMinutes: 0, now: now), 0);
    expect(liveWorkedMinutes(punchIn: '', punchOut: null, serverMinutes: 0, now: now), 0);
  });

  test('never negative when the phone clock is behind the server', () {
    expect(liveWorkedMinutes(punchIn: '2026-10-02T20:30:00', punchOut: null, serverMinutes: 0, now: now), 0);
  });

  test('an unreadable punch-in time falls back to the server figure', () {
    expect(liveWorkedMinutes(punchIn: 'garbage', punchOut: null, serverMinutes: 42, now: now), 42);
  });
}
