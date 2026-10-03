/// MVP date helper using Asia/Seoul (UTC+9), without extra timezone packages.
abstract final class SeoulDate {
  static DateTime today() {
    final seoulNow = DateTime.now().toUtc().add(const Duration(hours: 9));
    return DateTime(seoulNow.year, seoulNow.month, seoulNow.day);
  }

  static DateTime monthStart([DateTime? date]) {
    final base = date ?? today();
    return DateTime(base.year, base.month);
  }

  static DateTime previousMonth(DateTime month) {
    return DateTime(month.year, month.month - 1);
  }

  static DateTime nextMonth(DateTime month) {
    return DateTime(month.year, month.month + 1);
  }

  static DateTime monthEnd(DateTime month) {
    final start = monthStart(month);
    return DateTime(start.year, start.month + 1, 0);
  }

  static String format(DateTime date) {
    final year = date.year.toString().padLeft(4, '0');
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '$year-$month-$day';
  }

  /// Parses `yyyy-MM-dd`; returns null for any other or impossible date.
  static DateTime? tryParse(String? raw) {
    final match = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$').firstMatch(raw ?? '');
    if (match == null) return null;
    final year = int.parse(match.group(1)!);
    final month = int.parse(match.group(2)!);
    final day = int.parse(match.group(3)!);
    final date = DateTime(year, month, day);
    if (date.year != year || date.month != month || date.day != day) {
      return null;
    }
    return date;
  }

  static String display(DateTime date) {
    return '${date.year}년 ${date.month}월 ${date.day}일';
  }

  static String monthLabel(DateTime month) {
    return '${month.year}년 ${month.month}월';
  }

  static String daySectionLabel(DateTime date, {DateTime? today}) {
    final current = today ?? SeoulDate.today();
    if (date.year == current.year &&
        date.month == current.month &&
        date.day == current.day) {
      return '오늘';
    }
    return '${date.month}월 ${date.day}일';
  }
}
