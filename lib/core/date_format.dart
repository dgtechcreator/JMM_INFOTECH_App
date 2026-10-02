import 'package:intl/intl.dart';

/// The API now emits ISO-8601 date strings (see MVC.Web/Controllers/API/JsonNetResult.cs — before that
/// fix it was the legacy ASP.NET "/Date(1788507436267)/" format). Models still carry these as plain
/// strings (see e.g. ReimbursementRecord.expenseDate), so screens need to parse + format them for
/// display rather than showing the raw ISO string as-is. Falls back to the raw string if it isn't a
/// parseable date, so a genuinely malformed value is still visible rather than silently blanked.
String formatDate(String? raw) {
  if (raw == null || raw.isEmpty) return '-';
  final dt = DateTime.tryParse(raw);
  if (dt == null) return raw;
  return DateFormat('d MMM yyyy').format(dt.toLocal());
}

String formatDateTime(String? raw) {
  if (raw == null || raw.isEmpty) return '-';
  final dt = DateTime.tryParse(raw);
  if (dt == null) return raw;
  return DateFormat('d MMM yyyy, h:mm a').format(dt.toLocal());
}

String formatTime(String? raw) {
  if (raw == null || raw.isEmpty) return '--:--';
  final dt = DateTime.tryParse(raw);
  if (dt == null) return raw;
  return DateFormat('h:mm a').format(dt.toLocal());
}

/// Minutes worked "so far" for the Home screen's live Working Hours card. While the employee is punched in and
/// not yet punched out it is [now] minus the punch-in time, so the card counts up by itself; once punched out
/// (or when the punch-in time can't be read) it is the server's figure. Never negative: a phone clock a little
/// behind the server must not show a minus. [now] is injectable for tests.
int liveWorkedMinutes({required String? punchIn, required String? punchOut, required int serverMinutes, DateTime? now}) {
  if (punchIn == null || punchIn.isEmpty || (punchOut != null && punchOut.isNotEmpty)) return serverMinutes;
  final start = DateTime.tryParse(punchIn);
  if (start == null) return serverMinutes;
  final elapsed = (now ?? DateTime.now()).difference(start.toLocal()).inMinutes;
  return elapsed < 0 ? 0 : elapsed;
}

/// "Today" / "Yesterday" / "30 Sep 2026" — for date-wise section dividers (e.g. the notifications list).
/// [d] must already be in local time (call `.toLocal()` before passing it in).
String dateGroupLabel(DateTime d) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final yesterday = today.subtract(const Duration(days: 1));
  final day = DateTime(d.year, d.month, d.day);
  if (day == today) return 'Today';
  if (day == yesterday) return 'Yesterday';
  return DateFormat('d MMM yyyy').format(d);
}
