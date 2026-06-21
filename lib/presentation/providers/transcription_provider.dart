import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/services/model_download_service.dart';
import 'service_providers.dart';

enum ModelDownloadState { idle, downloading, ready, error }

class ModelDownloadData {
  final ModelDownloadState state;
  final double progress; // 0.0 – 1.0

  const ModelDownloadData({
    this.state = ModelDownloadState.idle,
    this.progress = 0.0,
  });

  ModelDownloadData copyWith({ModelDownloadState? state, double? progress}) {
    return ModelDownloadData(
      state: state ?? this.state,
      progress: progress ?? this.progress,
    );
  }
}

/// Drives the SenseVoice model download and initializes the transcription
/// service once it is ready. Backed by [showModelDownloadSheet].
class ModelDownloadNotifier extends StateNotifier<ModelDownloadData> {
  ModelDownloadNotifier(this._ref) : super(const ModelDownloadData());

  final Ref _ref;

  /// Total bytes that will be downloaded (for the prompt copy).
  int get downloadBytes => ModelDownloadService.expectedBytes;

  Future<void> downloadAndInitialize() async {
    state = state.copyWith(
      state: ModelDownloadState.downloading,
      progress: 0,
    );
    try {
      await ModelDownloadService.download(
        onProgress: (p) =>
            state = state.copyWith(progress: p, state: ModelDownloadState.downloading),
      );
      await _ref.read(transcriptionServiceProvider).initialize();
      state = state.copyWith(state: ModelDownloadState.ready, progress: 1);
    } catch (_) {
      state = state.copyWith(state: ModelDownloadState.error);
    }
  }
}

final modelDownloadProvider =
    StateNotifierProvider<ModelDownloadNotifier, ModelDownloadData>(
  (ref) => ModelDownloadNotifier(ref),
);
