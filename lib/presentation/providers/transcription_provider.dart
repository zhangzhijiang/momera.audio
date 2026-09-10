import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/services/model_download_service.dart';
import 'service_providers.dart';

enum ModelDownloadState {
  idle,
  downloading,
  ready,

  /// Something went wrong and retrying might work — usually the network.
  error,

  /// There is not enough free space. Distinct from [error] because the remedy
  /// is the user's, and the copy has to name it.
  insufficientStorage,
}

class ModelDownloadData {
  final ModelDownloadState state;
  final double progress; // 0.0 – 1.0

  /// Set only for [ModelDownloadState.insufficientStorage], so the sheet can
  /// tell the user how much to free rather than just that it failed.
  final int neededBytes;
  final int availableBytes;

  const ModelDownloadData({
    this.state = ModelDownloadState.idle,
    this.progress = 0.0,
    this.neededBytes = 0,
    this.availableBytes = 0,
  });

  ModelDownloadData copyWith({
    ModelDownloadState? state,
    double? progress,
    int? neededBytes,
    int? availableBytes,
  }) {
    return ModelDownloadData(
      state: state ?? this.state,
      progress: progress ?? this.progress,
      neededBytes: neededBytes ?? this.neededBytes,
      availableBytes: availableBytes ?? this.availableBytes,
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
      // The device just proved it can load the model; re-resolve so a Transcribe
      // button that was blocked on the download becomes available at once.
      _ref.read(deviceCapabilityServiceProvider).invalidate();
    } on InsufficientStorageException catch (e) {
      state = state.copyWith(
        state: ModelDownloadState.insufficientStorage,
        neededBytes: e.neededBytes,
        availableBytes: e.availableBytes,
      );
    } catch (_) {
      state = state.copyWith(state: ModelDownloadState.error);
    }
  }
}

final modelDownloadProvider =
    StateNotifierProvider<ModelDownloadNotifier, ModelDownloadData>(
  (ref) => ModelDownloadNotifier(ref),
);
