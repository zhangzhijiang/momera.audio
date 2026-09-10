import 'package:flutter/material.dart';

import '../../core/utils/app_theme.dart';
import '../providers/recordings_provider.dart';

/// A month grid over the archive, marking the days that hold recordings.
///
/// The point is not to be a date picker but an index: at a glance you can see
/// which days you recorded on, and tap one to see only that day. Days with
/// nothing on them are deliberately inert — there is nothing behind them to
/// show, and letting them be tapped would suggest otherwise.
///
/// Month names, weekday initials and the first day of the week come from
/// [MaterialLocalizations], so the grid follows the user's language and calendar
/// conventions. That is a deliberate departure from the fixed `yyyy-MM-dd` used
/// for recording timestamps: a timestamp is an identifier and must read the same
/// everywhere, while a calendar is a thing you navigate.
class RecordingCalendar extends StatefulWidget {
  const RecordingCalendar({
    super.key,
    required this.daysWithRecordings,
    required this.selected,
    required this.onSelect,
  });

  /// Date-only days that hold at least one recording.
  final Set<DateTime> daysWithRecordings;

  /// The day being shown alone, or null for the whole archive.
  final DateTime? selected;

  /// Called with a day to filter by, or null to go back to everything.
  final ValueChanged<DateTime?> onSelect;

  @override
  State<RecordingCalendar> createState() => _RecordingCalendarState();
}

class _RecordingCalendarState extends State<RecordingCalendar> {
  /// First of the month on display.
  late DateTime _month;

  @override
  void initState() {
    super.initState();
    final anchor = widget.selected ?? DateTime.now();
    _month = DateTime(anchor.year, anchor.month);
  }

  @override
  void didUpdateWidget(RecordingCalendar old) {
    super.didUpdateWidget(old);
    // A selection made elsewhere (or restored on re-entry) should be on screen.
    final selected = widget.selected;
    if (selected != null && !_isSameMonth(selected, _month)) {
      _month = DateTime(selected.year, selected.month);
    }
  }

  static bool _isSameMonth(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month;

  void _shift(int months) {
    setState(() => _month = DateTime(_month.year, _month.month + months));
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppTheme.of(context);
    final materialL10n = MaterialLocalizations.of(context);
    final today = DateTime.now();

    // Day 0 of the next month is the last day of this one.
    final daysInMonth = DateTime(_month.year, _month.month + 1, 0).day;
    // DateTime.weekday is 1..7 for Mon..Sun; the grid starts on whichever day
    // this locale considers first.
    final firstWeekday = _month.weekday % 7;
    final leading = (firstWeekday - materialL10n.firstDayOfWeekIndex + 7) % 7;
    final cells = leading + daysInMonth;
    final rows = (cells / 7).ceil();

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      padding: const EdgeInsets.fromLTRB(8, 4, 8, 8),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.borderLight),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _MonthHeader(
            label: materialL10n.formatMonthYear(_month),
            previousTooltip: materialL10n.previousMonthTooltip,
            nextTooltip: materialL10n.nextMonthTooltip,
            onPrevious: () => _shift(-1),
            onNext: () => _shift(1),
          ),
          _WeekdayRow(
            narrowWeekdays: materialL10n.narrowWeekdays,
            firstDayOfWeekIndex: materialL10n.firstDayOfWeekIndex,
          ),
          for (var row = 0; row < rows; row++)
            Row(
              children: [
                for (var col = 0; col < 7; col++)
                  Expanded(
                    child: _cellFor(
                      row * 7 + col - leading,
                      daysInMonth,
                      today,
                    ),
                  ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _cellFor(int dayOfMonth, int daysInMonth, DateTime today) {
    // Days spilling in from the neighbouring months are left blank rather than
    // greyed: this is an index of one month, not a continuous calendar.
    if (dayOfMonth < 1 || dayOfMonth > daysInMonth) {
      return const SizedBox(height: 38);
    }

    final date = DateTime(_month.year, _month.month, dayOfMonth);
    final has = widget.daysWithRecordings.contains(date);
    final selected = widget.selected != null && isSameDay(date, widget.selected!);

    return _DayCell(
      day: dayOfMonth,
      hasRecordings: has,
      selected: selected,
      isToday: isSameDay(date, today),
      // Tapping the selected day again clears the filter — the only way back to
      // the whole archive without hunting for a "show all" control.
      onTap: has ? () => widget.onSelect(selected ? null : date) : null,
    );
  }
}

class _MonthHeader extends StatelessWidget {
  const _MonthHeader({
    required this.label,
    required this.previousTooltip,
    required this.nextTooltip,
    required this.onPrevious,
    required this.onNext,
  });

  final String label;
  final String previousTooltip;
  final String nextTooltip;
  final VoidCallback onPrevious;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    final colors = AppTheme.of(context);
    return Row(
      children: [
        IconButton(
          icon: const Icon(Icons.chevron_left_rounded, size: 22),
          color: colors.textSecondary,
          tooltip: previousTooltip,
          visualDensity: VisualDensity.compact,
          onPressed: onPrevious,
        ),
        Expanded(
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: colors.textPrimary,
            ),
          ),
        ),
        IconButton(
          icon: const Icon(Icons.chevron_right_rounded, size: 22),
          color: colors.textSecondary,
          tooltip: nextTooltip,
          visualDensity: VisualDensity.compact,
          onPressed: onNext,
        ),
      ],
    );
  }
}

class _WeekdayRow extends StatelessWidget {
  const _WeekdayRow({
    required this.narrowWeekdays,
    required this.firstDayOfWeekIndex,
  });

  /// Sunday-first, as `MaterialLocalizations` provides them.
  final List<String> narrowWeekdays;
  final int firstDayOfWeekIndex;

  @override
  Widget build(BuildContext context) {
    final colors = AppTheme.of(context);
    return Row(
      children: [
        for (var i = 0; i < 7; i++)
          Expanded(
            child: Center(
              child: Text(
                narrowWeekdays[(firstDayOfWeekIndex + i) % 7],
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: colors.textHint,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _DayCell extends StatelessWidget {
  const _DayCell({
    required this.day,
    required this.hasRecordings,
    required this.selected,
    required this.isToday,
    required this.onTap,
  });

  final int day;
  final bool hasRecordings;
  final bool selected;
  final bool isToday;

  /// Null on a day with nothing to show.
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = AppTheme.of(context);

    final Color text;
    if (selected) {
      text = colors.onAccent;
    } else if (hasRecordings) {
      text = colors.textPrimary;
    } else {
      text = colors.textHint;
    }

    return Semantics(
      button: hasRecordings,
      selected: selected,
      child: InkResponse(
        onTap: onTap,
        radius: 22,
        child: SizedBox(
          height: 38,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 28,
                height: 28,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: selected ? colors.accent : Colors.transparent,
                  shape: BoxShape.circle,
                  border: isToday && !selected
                      ? Border.all(color: colors.accent, width: 1.5)
                      : null,
                ),
                child: Text(
                  '$day',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight:
                        hasRecordings ? FontWeight.w700 : FontWeight.w400,
                    color: text,
                  ),
                ),
              ),
              // The mark that makes this an index rather than a date picker.
              // Hidden under the selected day, whose filled circle already says
              // there is something there.
              SizedBox(
                height: 5,
                child: hasRecordings && !selected
                    ? Container(
                        width: 4,
                        height: 4,
                        margin: const EdgeInsets.only(top: 1),
                        decoration: BoxDecoration(
                          color: colors.accent,
                          shape: BoxShape.circle,
                        ),
                      )
                    : null,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
