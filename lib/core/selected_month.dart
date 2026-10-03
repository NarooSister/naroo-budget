import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'seoul_date.dart';

/// Web `setTimeout` stores the delay as a signed 32-bit millisecond count.
/// A wait longer than about 24.8 days overflows and runs immediately, so each
/// timer stays within one day and the provider recomputes until the month changes.
const currentMonthMaxTimerDelay = Duration(hours: 24);

Duration currentMonthTimerDelay({
  required DateTime nowUtc,
  required DateTime month,
}) {
  final nextMonthStartUtc = DateTime.utc(
    month.year,
    month.month + 1,
  ).subtract(const Duration(hours: 9));
  final remaining = nextMonthStartUtc.difference(nowUtc);
  if (remaining > currentMonthMaxTimerDelay) return currentMonthMaxTimerDelay;
  if (remaining < const Duration(milliseconds: 1)) {
    return const Duration(seconds: 1);
  }
  return remaining;
}

final currentMonthProvider = Provider.autoDispose<DateTime>((ref) {
  final now = DateTime.now().toUtc();
  final month = SeoulDate.monthStart();
  final timer = Timer(
    currentMonthTimerDelay(nowUtc: now, month: month),
    ref.invalidateSelf,
  );
  ref.onDispose(timer.cancel);
  return month;
});

/// Month shared by home and the transaction list. It returns to the current
/// Seoul month when that month changes.
class SelectedMonth extends Notifier<DateTime> {
  @override
  DateTime build() => ref.watch(currentMonthProvider);

  void goToPreviousMonth() {
    state = SeoulDate.previousMonth(state);
  }

  void goToNextMonth() {
    state = SeoulDate.nextMonth(state);
  }
}

final selectedMonthProvider = NotifierProvider<SelectedMonth, DateTime>(
  SelectedMonth.new,
);
