import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';

/// Downloads the large SenseVoice STT model at runtime instead of bundling it
/// inside the app package.
///
/// The model (`model.int8.onnx`, ~228 MB) is far too large to ship inside the
/// Android App Bundle / IPA, so it is fetched on first use and cached in the
/// app documents directory. Downloads are resumable (HTTP Range) and verified
/// by byte length before being marked ready.
class ModelDownloadService {
  /// Sources the model is fetched from, tried in order until one succeeds.
  /// A partially downloaded file is resumed against the next source since all
  /// sources serve the byte-identical model. Order them most- to least-
  /// preferred (own CDN / object storage first for production).
  static const List<String> modelUrls = [
    // Primary: our own pinned GitHub Release asset (stable, version-locked).
    'https://github.com/zhangzhijiang/momera/releases/download/sensevoice_small_model_v20240717/model.int8.onnx',
    // Fallback: public copy of the SenseVoice model on HuggingFace.
    'https://huggingface.co/csukuangfj/sherpa-onnx-sense-voice-zh-en-ja-ko-yue-2024-07-17/resolve/main/model.int8.onnx',
  ];

  /// Exact size of the expected model file, used as an integrity check so a
  /// truncated or corrupted download is never treated as ready.
  static const int expectedBytes = 239233841;

  static const String _fileName = 'model.int8.onnx';

  /// Final on-disk location of the model once fully downloaded.
  static Future<File> modelFile() async {
    final appDir = await getApplicationDocumentsDirectory();
    final dir = Directory(path.join(appDir.path, 'models', 'sensevoice'));
    return File(path.join(dir.path, _fileName));
  }

  /// True when the model is present and the byte length matches [expectedBytes].
  static Future<bool> isModelReady() async {
    final file = await modelFile();
    if (!await file.exists()) return false;
    return await file.length() == expectedBytes;
  }

  /// Download the model, trying each source in [modelUrls] until one succeeds.
  /// A partial `.part` file is resumed (and carries over between sources).
  ///
  /// [onProgress] is called with a value in [0.0, 1.0]. Throws only if every
  /// source fails; the partial file is preserved so a retry can resume.
  static Future<File> download({
    void Function(double progress)? onProgress,
  }) async {
    final file = await modelFile();
    if (await isModelReady()) return file;

    await file.parent.create(recursive: true);

    Object? lastError;
    for (final url in modelUrls) {
      try {
        return await _downloadFrom(url, file, onProgress);
      } catch (e) {
        lastError = e;
        debugPrint('Model download from $url failed: $e — trying next source');
      }
    }
    throw lastError ?? StateError('No model download sources configured.');
  }

  /// Download (or resume) the model from a single [url] into [file].
  static Future<File> _downloadFrom(
    String url,
    File file,
    void Function(double progress)? onProgress,
  ) async {
    final partFile = File('${file.path}.part');

    int downloaded = await partFile.exists() ? await partFile.length() : 0;
    // Guard against a corrupt/oversized partial — start over if it's bogus.
    if (downloaded > expectedBytes) {
      await partFile.delete();
      downloaded = 0;
    }

    final client = http.Client();
    try {
      final request = http.Request('GET', Uri.parse(url));
      if (downloaded > 0) {
        request.headers['Range'] = 'bytes=$downloaded-';
      }

      final response = await client.send(request);

      // 200 = full body (server ignored Range); restart from byte 0.
      // 206 = partial content; append to what we already have.
      final bool append = response.statusCode == 206 && downloaded > 0;
      if (response.statusCode != 200 && response.statusCode != 206) {
        throw HttpException(
          'Model download failed: HTTP ${response.statusCode}',
          uri: Uri.parse(url),
        );
      }
      if (!append) downloaded = 0;

      final total = append && response.contentLength != null
          ? downloaded + response.contentLength!
          : (response.contentLength ?? expectedBytes);

      final sink = partFile.openWrite(
        mode: append ? FileMode.append : FileMode.write,
      );
      try {
        await for (final chunk in response.stream) {
          sink.add(chunk);
          downloaded += chunk.length;
          if (onProgress != null && total > 0) {
            onProgress((downloaded / total).clamp(0.0, 1.0));
          }
        }
      } finally {
        await sink.flush();
        await sink.close();
      }

      final partLength = await partFile.length();
      if (partLength != expectedBytes) {
        throw StateError(
          'Downloaded model size mismatch: got $partLength, '
          'expected $expectedBytes bytes.',
        );
      }

      // Atomic-ish swap so a half-written file is never seen as the real model.
      if (await file.exists()) await file.delete();
      await partFile.rename(file.path);
      onProgress?.call(1.0);
      debugPrint('Model downloaded successfully: ${file.path}');
      return file;
    } finally {
      client.close();
    }
  }

  /// Delete the cached model (and any partial download). Useful for a
  /// "free up space" / re-download action in settings.
  static Future<void> deleteModel() async {
    final file = await modelFile();
    final partFile = File('${file.path}.part');
    if (await file.exists()) await file.delete();
    if (await partFile.exists()) await partFile.delete();
  }
}
