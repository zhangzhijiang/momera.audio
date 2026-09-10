import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';

import '../capabilities/device_info_channel.dart';

/// Downloads the large SenseVoice STT model at runtime instead of bundling it
/// inside the app package.
///
/// The model (`model.int8.onnx`, ~228 MB) is far too large to ship inside the
/// Android App Bundle / IPA, so it is fetched on first use and cached in the
/// app *support* directory. Downloads are resumable (HTTP Range) and verified
/// by byte length before being marked ready.
///
/// Storage location matters on iOS: re-downloadable content must NOT live in
/// `Documents/`, which is backed up to iCloud and cannot be purged. Apple
/// rejects apps that put re-creatable data there. `getApplicationSupportDirectory()`
/// maps to `Library/Application Support`, and the directory is additionally
/// flagged do-not-back-up. User recordings are different — they are genuine
/// user-generated content and stay in `Documents/` (see RecordingRepository).
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

  /// Slack on top of the model itself, for the filesystem and the tokens file.
  /// The `.part` is renamed into place on the same volume, so the download
  /// never needs two copies of the model at once.
  static const int downloadHeadroomBytes = 64 * 1024 * 1024;

  /// Free space a fresh download needs.
  static int get requiredFreeBytes => expectedBytes + downloadHeadroomBytes;

  /// Root directory for all downloaded/derived model files.
  ///
  /// `Library/Application Support` on iOS/macOS, and the equivalent private
  /// app-data directory on Android — never `Documents/`.
  static Future<Directory> modelsRoot() async {
    final appDir = await getApplicationSupportDirectory();
    return Directory(path.join(appDir.path, 'models'));
  }

  /// Final on-disk location of the model once fully downloaded.
  static Future<File> modelFile() async {
    final root = await modelsRoot();
    final dir = Directory(path.join(root.path, 'sensevoice'));
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
    await _excludeFromBackup(file.parent);

    // Checked once, before the source loop: inside it, the `catch` below would
    // dutifully try the second URL, fail identically, and burn a DNS lookup and
    // a connection first. Only what is still missing has to fit — a user who is
    // 90% downloaded should not be told to free another 228 MB.
    final resumable = await _partLength(file);
    final needed =
        (expectedBytes - resumable).clamp(0, expectedBytes) + downloadHeadroomBytes;
    final free = await DeviceInfoChannel.freeDiskBytes();
    if (free >= 0 && free < needed) {
      throw InsufficientStorageException(needed, free);
    }

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

  /// Bytes of a resumable partial download, or 0 if there is none.
  static Future<int> _partLength(File file) async {
    try {
      final part = File('${file.path}.part');
      if (!await part.exists()) return 0;
      final length = await part.length();
      return (length > 0 && length < expectedBytes) ? length : 0;
    } catch (_) {
      return 0;
    }
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
      return file;
    } finally {
      client.close();
    }
  }

  /// Mark [dir] as excluded from iCloud/iTunes backup.
  ///
  /// No-op off Apple platforms. This is belt-and-braces on top of using
  /// Application Support: Apple's guidance is that re-downloadable content is
  /// either kept out of Documents *or* flagged, and doing both is free.
  static Future<void> _excludeFromBackup(Directory dir) async {
    if (defaultTargetPlatform != TargetPlatform.iOS &&
        defaultTargetPlatform != TargetPlatform.macOS) {
      return;
    }
    try {
      await _backupChannel.invokeMethod<void>('excludeFromBackup', dir.path);
    } catch (e) {
      // Never fail a download because the hint could not be applied.
      debugPrint('Could not set do-not-back-up on ${dir.path}: $e');
    }
  }

  static const MethodChannel _backupChannel =
      MethodChannel('com.idatagear.momerarecording/backup');

  /// Delete the cached model (and any partial download). Useful for a
  /// "free up space" / re-download action in settings.
  static Future<void> deleteModel() async {
    final file = await modelFile();
    final partFile = File('${file.path}.part');
    if (await file.exists()) await file.delete();
    if (await partFile.exists()) await partFile.delete();
  }
}

/// Thrown when there is not enough free space to download the speech model.
///
/// A **temporary** condition, deliberately distinct from any device limit: the
/// user can free space and retry, so callers must keep the feature visible and
/// say what is needed rather than hiding it.
class InsufficientStorageException implements Exception {
  const InsufficientStorageException(this.neededBytes, this.availableBytes);

  /// Free space the download requires.
  final int neededBytes;

  /// Free space there actually is.
  final int availableBytes;

  @override
  String toString() =>
      'Not enough space for the speech model: needs $neededBytes bytes, '
      '$availableBytes available.';
}
