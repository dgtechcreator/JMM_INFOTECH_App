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
