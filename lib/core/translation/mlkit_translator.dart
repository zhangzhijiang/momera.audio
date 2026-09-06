import 'package:flutter/foundation.dart';
import 'package:google_mlkit_translation/google_mlkit_translation.dart';

import 'translator.dart';

/// On-device translation via Google ML Kit.
///
/// Used on Android, and on iOS below 18 where Apple's translation API does not
/// exist. Models are per language and downloaded on demand (~30 MB each).
///
/// **ML Kit has no Traditional/Simplified distinction.** Both Chinese variants
/// map to its single `chinese` language and it returns Simplified, so a user
/// who asks for Traditional gets Simplified. Apple's engine does distinguish
/// them, which is part of why it is preferred on iOS 18+.
class MlKitTranslator implements Translator {
  MlKitTranslator();

  @override
  String get id => 'mlkit';

  /// One native translator is cached per language pair and reused, so repeated
  /// calls are cheap — which makes this the engine of choice for live,
  /// per-utterance translation.
  @override
  bool get isReusable => true;

  final OnDeviceTranslatorModelManager _models =
      OnDeviceTranslatorModelManager();

  /// One translator per pair; they hold native resources, so they are reused
  /// rather than rebuilt per call and closed together in [dispose].
  final Map<String, OnDeviceTranslator> _translators = {};

  /// ML Kit ships on every platform this app targets, and the plugin is a hard
  /// dependency, so it is always available. Web is not a target.
  @override
  Future<bool> isAvailable() async =>
      defaultTargetPlatform == TargetPlatform.android ||
      defaultTargetPlatform == TargetPlatform.iOS;

  @override
  Future<Set<TranslationLanguage>> supportedTargets() async => const {
        TranslationLanguage.english,
        TranslationLanguage.chineseSimplified,
        // Offered, but ML Kit will return Simplified text — see the class doc.
        TranslationLanguage.chineseTraditional,
        TranslationLanguage.japanese,
        TranslationLanguage.korean,
        // Cantonese is deliberately absent: ML Kit has no `yue`.
      };

  /// Maps to ML Kit's language enum, or null if it has no equivalent.
  static TranslateLanguage? _toMlKit(TranslationLanguage language) {
    switch (language) {
      case TranslationLanguage.english:
        return TranslateLanguage.english;
      case TranslationLanguage.chineseSimplified:
      case TranslationLanguage.chineseTraditional:
        return TranslateLanguage.chinese;
      case TranslationLanguage.japanese:
        return TranslateLanguage.japanese;
      case TranslationLanguage.korean:
        return TranslateLanguage.korean;
      case TranslationLanguage.cantonese:
        return null;
    }
  }

  @override
  Future<bool> isPairReady(
    TranslationLanguage from,
    TranslationLanguage to,
  ) async {
    final source = _toMlKit(from);
    final target = _toMlKit(to);
    if (source == null || target == null) return false;
    return await _models.isModelDownloaded(source.bcpCode) &&
        await _models.isModelDownloaded(target.bcpCode);
  }

  @override
  Future<void> prepare(TranslationLanguage from, TranslationLanguage to) async {
    final source = _toMlKit(from);
    final target = _toMlKit(to);
    if (source == null || target == null) {
      throw const TranslationException(TranslationFailure.unsupportedPair);
    }
    try {
      for (final code in {source.bcpCode, target.bcpCode}) {
        if (!await _models.isModelDownloaded(code)) {
          await _models.downloadModel(code);
        }
      }
    } catch (e) {
      throw TranslationException(
          TranslationFailure.modelUnavailable, e.toString());
    }
  }

  @override
  Future<String> translate(
    String text, {
    TranslationLanguage? from,
    required TranslationLanguage to,
  }) async {
    if (text.trim().isEmpty) return '';
    // ML Kit cannot infer the source language; a caller that does not know it
    // must resolve it (from the transcript's detected language) first.
    if (from == null) {
      throw const TranslationException(TranslationFailure.unsupportedPair,
          'ML Kit requires an explicit source language');
    }
    final source = _toMlKit(from);
    final target = _toMlKit(to);
    if (source == null || target == null) {
      throw const TranslationException(TranslationFailure.unsupportedPair);
    }
    if (source == target) return text;

    await prepare(from, to);

    final key = '${source.bcpCode}>${target.bcpCode}';
    final translator = _translators.putIfAbsent(
      key,
      () => OnDeviceTranslator(sourceLanguage: source, targetLanguage: target),
    );

    try {
      return await translator.translateText(text);
    } catch (e) {
      throw TranslationException(TranslationFailure.failed, e.toString());
    }
  }

  @override
  Future<void> dispose() async {
    for (final translator in _translators.values) {
      await translator.close();
    }
    _translators.clear();
  }
}
