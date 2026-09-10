/// Byte-size formatting shared by settings, the recorder and the model
/// download sheet.
///
/// A pure formatter, so it lives here rather than in whichever screen happened
/// to need it first.
library;

/// Human-readable byte size, e.g. `512 MB` / `2 GB`.
String formatBytes(int bytes) {
  const gb = 1024 * 1024 * 1024;
  const mb = 1024 * 1024;
  if (bytes >= gb) {
    final value = bytes / gb;
    // Whole numbers read better than "2.0 GB".
    return value == value.roundToDouble()
        ? '${value.round()} GB'
        : '${value.toStringAsFixed(1)} GB';
  }
  return '${(bytes / mb).round()} MB';
}
