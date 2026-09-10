import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/utils/app_theme.dart';
import '../../core/utils/byte_format.dart';
import '../../l10n/app_localizations.dart';
import '../providers/transcription_provider.dart';

/// Bottom sheet that prompts the user to download the offline speech-to-text
/// model on first transcription, showing live download progress.
///
/// Returns `true` once the model is ready, or `null`/`false` if dismissed.
Future<bool?> showModelDownloadSheet(BuildContext context) {
  final colors = AppTheme.of(context);
  return showModalBottomSheet<bool>(
    context: context,
    backgroundColor: colors.surface,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (_) => const _ModelDownloadSheet(),
  );
}

class _ModelDownloadSheet extends ConsumerWidget {
  const _ModelDownloadSheet();

  String _formatMb(int bytes) => '${(bytes / (1024 * 1024)).round()} MB';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = AppTheme.of(context);
    final l10n = AppLocalizations.of(context)!;
    ref.listen<ModelDownloadData>(modelDownloadProvider, (prev, next) {
      if (next.state == ModelDownloadState.ready && Navigator.canPop(context)) {
        Navigator.of(context).pop(true);
      }
    });

    final data = ref.watch(modelDownloadProvider);
    final notifier = ref.read(modelDownloadProvider.notifier);
    final isDownloading = data.state == ModelDownloadState.downloading;
    final isError = data.state == ModelDownloadState.error;
    final noSpace = data.state == ModelDownloadState.insufficientStorage;

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: 24,
          right: 24,
          top: 24,
          bottom: 24 + MediaQuery.of(context).viewInsets.bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: colors.accentLight,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(Icons.graphic_eq_rounded,
                      color: colors.accent, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    l10n.downloadModelTitle,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: colors.textPrimary,
                      letterSpacing: -0.3,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Text(
              l10n.downloadModelBody(_formatMb(notifier.downloadBytes)),
              style: TextStyle(
                fontSize: 14,
                height: 1.4,
                color: colors.textSecondary,
              ),
            ),
            const SizedBox(height: 24),
            if (isDownloading) ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(
                  value: data.progress > 0 ? data.progress : null,
                  minHeight: 8,
                  backgroundColor: colors.borderLight,
                  valueColor:
                      AlwaysStoppedAnimation<Color>(colors.accent),
                ),
              ),
              const SizedBox(height: 10),
              Text(
                '${(data.progress * 100).toStringAsFixed(0)}%',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: colors.textSecondary,
                ),
              ),
            ] else ...[
              // Both failures keep the sheet open with a live Retry: the user
              // fixes the network or frees space and comes straight back.
              if (isError || noSpace)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Text(
                    noSpace
                        ? l10n.notEnoughSpaceBody(
                            formatBytes(data.neededBytes),
                            formatBytes(data.availableBytes),
                          )
                        : l10n.downloadFailed,
                    style: TextStyle(
                      fontSize: 13,
                      color: colors.recordRed,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: colors.accent,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  onPressed: notifier.downloadAndInitialize,
                  child: Text(
                    isError || noSpace ? l10n.retry : l10n.download,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: colors.onAccent,
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
