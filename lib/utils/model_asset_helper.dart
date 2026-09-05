import 'dart:io';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as path;
import '../core/services/model_download_service.dart';

/// Utility class for managing model assets that need to be on the filesystem
/// before being used by sherpa_onnx (since Flutter assets aren't real file paths).
///
/// The small support files (tokens + VAD model) are bundled and copied out of
/// the asset bundle on first run. The large SenseVoice model is NOT bundled —
/// it is downloaded at runtime by [ModelDownloadService] to keep the app
/// package small. Call [isModelReady] before [resolveModelPaths] and trigger a
/// download if it returns false.
class ModelAssetHelper {
  static const String _tokensAssetPath = 'assets/models/sensevoice/tokens.txt';
  static const String _vadModelAssetPath =
      'assets/models/silero_vad/silero_vad.onnx';

  /// Whether the downloaded STT model is present and valid.
  static Future<bool> isModelReady() => ModelDownloadService.isModelReady();

  /// Copy the bundled support assets (tokens + VAD) to disk and resolve all
  /// model file paths. Assumes the STT model has already been downloaded —
  /// guard with [isModelReady] first.
  static Future<ModelPaths> resolveModelPaths() async {
    // All model files live under Application Support, never Documents —
    // see ModelDownloadService for why.
    final modelsRoot = await ModelDownloadService.modelsRoot();

    // STT model (SenseVoice) — downloaded at runtime, not bundled.
    final modelFile = await ModelDownloadService.modelFile();

    // tokens.txt is small (~300 KB) and stays bundled.
    final modelDir = modelFile.parent;
    if (!await modelDir.exists()) {
      await modelDir.create(recursive: true);
    }
    final tokensFile = File(path.join(modelDir.path, 'tokens.txt'));
    if (!await tokensFile.exists()) {
      final tokensData = await rootBundle.loadString(_tokensAssetPath);
      await tokensFile.writeAsString(tokensData);
    }

    // VAD model (Silero VAD) — small (~600 KB), stays bundled.
    final vadDir = Directory(path.join(modelsRoot.path, 'silero_vad'));
    if (!await vadDir.exists()) {
      await vadDir.create(recursive: true);
    }
    final vadFile = File(path.join(vadDir.path, 'silero_vad.onnx'));
    if (!await vadFile.exists()) {
      final vadData = await rootBundle.load(_vadModelAssetPath);
      await vadFile.writeAsBytes(vadData.buffer.asUint8List());
    }

    return ModelPaths(
      modelPath: modelFile.path,
      tokensPath: tokensFile.path,
      vadModelPath: vadFile.path,
    );
  }
}

/// Container for model file paths
class ModelPaths {
  final String modelPath;
  final String tokensPath;
  final String vadModelPath;

  const ModelPaths({
    required this.modelPath,
    required this.tokensPath,
    required this.vadModelPath,
  });
}
