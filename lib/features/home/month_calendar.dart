import 'package:flutter/material.dart';

import '../../app/theme/naroo_colors.dart';
import '../../app/theme/naroo_spacing.dart';
import '../../app/theme/naroo_text.dart';
import '../../core/money_format.dart';
import 'home_summary.dart';

const _weekdays = ['일', '월', '화', '수', '목', '금', '토'];

/// Sunday-first month grid. Each day shows its income and expense totals.
class MonthCalendar extends StatelessWidget {
  const MonthCalendar({
    super.key,
    required this.month,
    required this.totals,
    required this.today,
    required this.onDayTap,
  });

  final DateTime month;
  final Map<DateTime, DayTotal> totals;
  final DateTime today;
  final ValueChanged<DateTime> onDayTap;

  @override
  Widget build(BuildContext context) {
    final leading = DateTime(month.year, month.month).weekday % 7;
    final days = DateTime(month.year, month.month + 1, 0).day;
    final weeks = ((leading + days) / 7).ceil();

    return Column(
      children: [
        Row(
          children: [
            for (final weekday in _weekdays)
              Expanded(
                child: Text(
                  weekday,
                  textAlign: TextAlign.center,
                  style: NarooText.caption.copyWith(
                    color: NarooColors.textSecondary,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: NarooSpacing.space8),
        for (var week = 0; week < weeks; week++)
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (var weekday = 0; weekday < 7; weekday++)
                Expanded(child: _cell(week * 7 + weekday - leading + 1, days)),
            ],
          ),
      ],
    );
  }

  Widget _cell(int day, int days) {
    if (day < 1 || day > days) return const SizedBox(height: 64);
    final date = DateTime(month.year, month.month, day);
    final total = totals[date] ?? const DayTotal();
    final isToday = date == today;

    return Semantics(
      button: true,
      label: [
        '${month.month}월 $day일',
        if (total.income > 0) '수입 ${MoneyFormat.krw(total.income)}원',
        if (total.expense > 0) '지출 ${MoneyFormat.krw(total.expense)}원',
      ].join(', '),
      excludeSemantics: true,
      child: InkWell(
        onTap: () => onDayTap(date),
        borderRadius: BorderRadius.circular(NarooRadius.input),
        child: SizedBox(
          height: 64,
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 2,
              vertical: NarooSpacing.space4,
            ),
            child: Column(
              children: [
                Container(
                  width: 24,
                  height: 24,
                  alignment: Alignment.center,
                  decoration: isToday
                      ? const BoxDecoration(
                          color: NarooColors.primaryLight,
                          shape: BoxShape.circle,
                        )
                      : null,
                  child: Text(
                    '$day',
                    style: NarooText.caption.copyWith(
                      color: isToday
                          ? NarooColors.primary
                          : NarooColors.textPrimary,
                      fontWeight: isToday ? FontWeight.w700 : null,
                    ),
                  ),
                ),
                if (total.income > 0)
                  _amount(
                    '+${MoneyFormat.krw(total.income)}',
                    NarooColors.income,
                  ),
                if (total.expense > 0)
                  _amount(
                    '-${MoneyFormat.krw(total.expense)}',
                    NarooColors.expense,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _amount(String text, Color color) => FittedBox(
    fit: BoxFit.scaleDown,
    child: Text(
      text,
      maxLines: 1,
      style: NarooText.money(NarooText.caption, color),
    ),
  );
}
