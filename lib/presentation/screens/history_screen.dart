import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/search/recording_search.dart';
import '../../core/utils/app_theme.dart';
import '../../data/models/recording.dart';
import '../../l10n/app_localizations.dart';
import '../providers/capability_provider.dart';
import '../providers/recordings_provider.dart';
import '../providers/settings_provider.dart';
import '../widgets/no_results.dart';
import '../widgets/recording_calendar.dart';
import '../widgets/recording_tile.dart';
import '../widgets/search_field.dart';

/// Every recording ever made, newest first, grouped by the day it was made.
///
/// The home screen deliberately shows only today, so this is where a recording
/// goes to be found again — which is why the search here spans the whole
/// archive rather than a single day, and why the day headers are part of the
/// list rather than decoration: they are the index.
class HistoryScreen extends ConsumerStatefulWidget {
  const HistoryScreen({super.key});

  @override
  ConsumerState<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends ConsumerState<HistoryScreen> {
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    // The query outlives this screen (it is a provider), so a re-entry shows
    // the field and the list agreeing with each other.
    _searchController.text = ref.read(historySearchQueryProvider);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppTheme.of(context);
    final l10n = AppLocalizations.of(context)!;
    final recordingsAsync = ref.watch(recordingsProvider);
    final sttVisible = watchTranscriptionVisible(ref);

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        title: Text(
          l10n.history,
          style: TextStyle(
            fontSize: 19,
            fontWeight: FontWeight.w800,
            color: colors.textPrimary,
            letterSpacing: -0.3,
          ),
        ),
      ),
      body: SafeArea(
        child: recordingsAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text(l10n.loadFailed('$e'))),
          data: (recordings) {
            if (recordings.isEmpty) return const _HistoryEmpty();

            final query = ref.watch(historySearchQueryProvider);
            final selectedDay = ref.watch(historySelectedDayProvider);
            final searching = query.trim().isNotEmpty;

            // The calendar marks every day in the archive, not just the days
            // surviving the current search — it is the index, and an index that
            // changed under the query would be useless for finding your way
            // back out of one.
            final days = {
              for (final r in recordings)
                DateTime(r.createdAt.year, r.createdAt.month, r.createdAt.day),
            };

            // Day first, then text: the calendar narrows the archive, and the
            // search field searches whatever is left, which is what the two
            // controls appear to promise sitting one above the other.
            var visible = selectedDay == null
                ? recordings
                : [
                    for (final r in recordings)
                      if (isSameDay(r.createdAt, selectedDay)) r,
                  ];
            final hits = searching
                ? const RecordingSearch().search(visible, query)
                : const <SearchHit>[];
            if (searching) {
              visible = const RecordingSearch().filter(visible, query);
            }

            final rows = _rowsFor(l10n, visible);

            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Pinned: the search field is how you get out of a long
                // archive, and scrolling to reach it would be backwards.
                SearchField(
                  controller: _searchController,
                  hint: sttVisible ? l10n.searchHint : l10n.searchHintNamesOnly,
                  clearTooltip: l10n.clear,
                  onChanged: (v) =>
                      ref.read(historySearchQueryProvider.notifier).state = v,
                ),
                Expanded(
                  // The calendar scrolls with the list rather than sitting in a
                  // fixed slot above it. A month grid is ~300px, which is most
                  // of a phone in landscape — given a slot of its own it would
                  // overflow, and giving it one would also mean the list could
                  // never use the whole screen.
                  child: CustomScrollView(
                    slivers: [
                      SliverToBoxAdapter(
                        child: RecordingCalendar(
                          daysWithRecordings: days,
                          selected: selectedDay,
                          onSelect: (day) => ref
                              .read(historySelectedDayProvider.notifier)
                              .state = day,
                        ),
                      ),
                      if (rows.isEmpty)
                        SliverFillRemaining(
                          hasScrollBody: false,
                          child: NoResults(
                            message: searching
                                ? l10n.searchNoResults(query)
                                : l10n.noRecordingsOnDay,
                            hint: searching
                                ? (sttVisible
                                    ? l10n.searchNoResultsHint
                                    : l10n.searchNoResultsHintNamesOnly)
                                : l10n.noRecordingsOnDayHint,
                          ),
                        )
                      else
                        SliverList.builder(
                          itemCount: rows.length,
                          itemBuilder: (context, i) =>
                              _rowWidget(rows[i], i == 0, hits),
                        ),
                      const SliverToBoxAdapter(child: SizedBox(height: 8)),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// Flatten the archive into rows: a day label before each new day, then that
/// day's recordings.
///
/// One flat list rather than a widget per day so the whole archive stays lazily
/// built — a user with a thousand recordings builds as many live widgets as one
/// with ten.
///
/// Banding restarts at each header rather than running through the whole
/// archive, so every day group opens on the same colour and the headers stay the
/// thing that separates days.
List<Object> _rowsFor(AppLocalizations l10n, List<Recording> visible) {
  final now = DateTime.now();
  final rows = <Object>[];
  DateTime? previous;
  var withinDay = 0;
  for (final recording in visible) {
    if (previous == null || !isSameDay(recording.createdAt, previous)) {
      rows.add(_dayLabel(l10n, recording.createdAt, now));
      previous = recording.createdAt;
      withinDay = 0;
    }
    rows.add(_DayRow(recording, withinDay.isOdd));
    withinDay++;
  }
  return rows;
}

Widget _rowWidget(Object row, bool first, List<SearchHit> hits) {
  if (row is String) return _DayHeader(label: row, first: first);
  final day = row as _DayRow;
  return RecordingTile(
    recording: day.recording,
    alternate: day.alternate,
    hits: [
      for (final h in hits)
        if (h.recording.path == day.recording.path) h,
    ],
  );
}

/// "Today" and "Yesterday" carry more meaning than a date does; older days get
/// the same fixed, unambiguous date the tiles themselves use.
String _dayLabel(AppLocalizations l10n, DateTime day, DateTime now) {
  if (isSameDay(day, now)) return l10n.today;
  if (isSameDay(day, now.subtract(const Duration(days: 1)))) {
    return l10n.yesterday;
  }
  return formatDay(day);
}

/// One recording in the archive, and whether it is an odd row within its day.
@immutable
class _DayRow {
  const _DayRow(this.recording, this.alternate);

  final Recording recording;
  final bool alternate;
}

class _DayHeader extends StatelessWidget {
  const _DayHeader({required this.label, required this.first});

  final String label;

  /// The first header needs no gap above it — the search field already
  /// provides one.
  final bool first;

  @override
  Widget build(BuildContext context) {
    final colors = AppTheme.of(context);
    return Padding(
      padding: EdgeInsets.fromLTRB(20, first ? 12 : 20, 20, 6),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.4,
          color: colors.textHint,
        ),
      ),
    );
  }
}

class _HistoryEmpty extends StatelessWidget {
  const _HistoryEmpty();

  @override
  Widget build(BuildContext context) {
    final colors = AppTheme.of(context);
    final l10n = AppLocalizations.of(context)!;
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.history_rounded, size: 56, color: colors.textHint),
            const SizedBox(height: 12),
            Text(
              l10n.noRecordingsTitle,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: colors.textSecondary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              l10n.noRecordingsBody,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: colors.textHint),
            ),
          ],
        ),
      ),
    );
  }
}
