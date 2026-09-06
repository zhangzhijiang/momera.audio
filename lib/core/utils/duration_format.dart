/// Formats a duration as `mm:ss`, widening to `h:mm:ss` at an hour.
///
/// The obvious `'${d.inMinutes.remainder(60)}:${d.inSeconds.remainder(60)}'`
/// silently wraps: a 90-minute recording renders as `30:00`, identical to a
/// 30-minute one. That matters here because recordings continue while the app
/// is backgrounded and the screen is locked, so multi-hour recordings are an
/// ordinary case rather than a curiosity.
///
/// Locale-independent by design, matching the fixed `yyyy-MM-dd HH:mm:ss`
/// timestamps elsewhere in the UI.
String formatDuration(Duration? d) {
  if (d == null) return '--:--';
  final total = d.isNegative ? Duration.zero : d;

  final hours = total.inHours;
  final minutes = total.inMinutes.remainder(60);
  final seconds = total.inSeconds.remainder(60);

  String two(int v) => v.toString().padLeft(2, '0');

  return hours > 0
      ? '$hours:${two(minutes)}:${two(seconds)}'
      : '${two(minutes)}:${two(seconds)}';
}
