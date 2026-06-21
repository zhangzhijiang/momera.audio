import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/utils/app_theme.dart';
import '../providers/transcription_provider.dart';

/// Bottom sheet that prompts the user to download the offline speech-to-text
/// model on first transcription, showing live download progress.
///
/// Returns `true` once the model is ready, or `null`/`false` if dismissed.
Future<bool?> showModelDownloadSheet(BuildContext context) {
  return showModalBottomSheet<bool>(
    context: context,
    backgroundColor: AppTheme.surface,
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
    ref.listen<ModelDownloadData>(modelDownloadProvider, (prev, next) {
      if (next.state == ModelDownloadState.ready && Navigator.canPop(context)) {
        Navigator.of(context).pop(true);
      }
    });

    final data = ref.watch(modelDownloadProvider);
    final notifier = ref.read(modelDownloadProvider.notifier);
    final isDownloading = data.state == ModelDownloadState.downloading;
    final isError = data.state == ModelDownloadState.error;

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
                    color: AppTheme.accentLight,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.graphic_eq_rounded,
                      color: AppTheme.accent, size: 22),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'Download voice model',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.textPrimary,
                      letterSpacing: -0.3,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Text(
              'Transcription runs fully offline. The speech model '
              '(${_formatMb(notifier.downloadBytes)}) is downloaded once and '
              'reused for every recording.',
              style: const TextStyle(
                fontSize: 14,
                height: 1.4,
                color: AppTheme.textSecondary,
              ),
            ),
            const SizedBox(height: 24),
            if (isDownloading) ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(
                  value: data.progress > 0 ? data.progress : null,
                  minHeight: 8,
                  backgroundColor: AppTheme.borderLight,
                  valueColor:
                      const AlwaysStoppedAnimation<Color>(AppTheme.accent),
                ),
              ),
              const SizedBox(height: 10),
              Text(
                '${(data.progress * 100).toStringAsFixed(0)}%',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textSecondary,
                ),
              ),
            ] else ...[
              if (isError)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Text(
                    'Download failed. Check your connection and try again.',
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.red.shade400,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: AppTheme.accent,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  onPressed: notifier.downloadAndInitialize,
                  child: Text(
                    isError ? 'Retry' : 'Download',
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
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
