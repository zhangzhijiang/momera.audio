import 'package:flutter/foundation.dart';

import '../services/transcription_service.dart';
import 'apple_translator.dart';
import 'mlkit_translator.dart';
import 'translator.dart';

/// Picks a translation engine and runs transcripts through it.
///
/// Engine order is Apple, then ML Kit:
///
/// * **Apple (iOS 18+)** — the system owns the models, so there is nothing for
///   the app to download or explain, quality is generally better, and it tells
///   Simplified from Traditional Chinese.
/// * **ML Kit** — Android, and iOS 15.5–17.x. Downloads a model per language.
///
/// An online engine would slot in as a third entry. It is deliberately not
/// registered: see [OnlineTranslator] for why, and for what has to change
/// about the app's privacy claims before one can be.
class TranslationService {
  TranslationService({TranslatorRegistry? registry})
      : _registry = registry ??
            TranslatorRegistry([
              const AppleTranslator(),
              MlKitTranslator(),
            ]);

  final TranslatorRegistry _registry;

  Set<TranslationLanguage>? _cachedTargets;

  /// Languages any available engine can translate into.
  ///
  /// Cached: it costs a platform round trip and the answer only changes with
  /// the OS.
  Future<Set<TranslationLanguage>> supportedTargets() async {
    return _cachedTargets ??= await _registry.supportedTargets();
  }

  /// Which engine would handle [to], or null if nothing can.
  ///
  /// [preferReusable] biases towards engines that keep their native machinery
  /// open across calls, which matters when translating utterance by utterance.
  Future<Translator?> engineFor(
    TranslationLanguage to, {
    bool preferReusable = false,
  }) =>
      _registry.engineFor(to, preferReusable: preferReusable);

  /// Best guess at the source language for a transcript, from what the
  /// recogniser detected.
  ///
  /// Returns null when the recording is multilingual or nothing was detected —
  /// ML Kit needs one definite source language, and guessing wrong is worse
  /// than declining.
  static TranslationLanguage? sourceFor(List<TranscriptionLanguage> detected) {
    if (detected.length != 1) return null;
    switch (detected.first) {
      case TranscriptionLanguage.mandarin:
        return TranslationLanguage.chineseSimplified;
      case TranscriptionLanguage.cantonese:
        return TranslationLanguage.cantonese;
      case TranscriptionLanguage.english:
        return TranslationLanguage.english;
      case TranscriptionLanguage.japanese:
        return TranslationLanguage.japanese;
      case TranscriptionLanguage.korean:
        return TranslationLanguage.korean;
      case TranscriptionLanguage.auto:
        return null;
    }
  }

  /// Translate [text] into [to].
  ///
  /// Throws [TranslationException] with [TranslationFailure.unsupportedPair]
  /// when no engine handles the pair — the Cantonese case, which is what the
  /// online engine is meant for.
  Future<TranslationOutcome> translate(
    String text, {
    TranslationLanguage? from,
    required TranslationLanguage to,
  }) async {
    if (from == TranslationLanguage.cantonese) {
      // No on-device engine translates Cantonese. Fail loudly rather than
      // quietly routing it through Chinese and returning subtly wrong text.
      throw const TranslationException(
        TranslationFailure.unsupportedPair,
        'Cantonese needs an online translator',
      );
    }

    final engine = await _registry.engineFor(to);
    if (engine == null) {
      throw const TranslationException(TranslationFailure.unsupportedPair);
    }

    final translated = await engine.translate(text, from: from, to: to);
    return TranslationOutcome(
      text: translated,
      language: to,
      engineId: engine.id,
    );
  }

  Future<void> dispose() async {
    for (final engine in _registry.engines) {
      await engine.dispose();
    }
  }
}

/// A translated transcript, and which engine produced it.
@immutable
class TranslationOutcome {
  const TranslationOutcome({
    required this.text,
    required this.language,
    required this.engineId,
  });

  factory TranslationOutcome.fromJson(Map<String, dynamic> json) {
    return TranslationOutcome(
      text: json['text'] as String? ?? '',
      language: TranslationLanguage.fromName(json['language'] as String?) ??
          TranslationLanguage.english,
      engineId: json['engine'] as String? ?? 'unknown',
    );
  }

  final String text;
  final TranslationLanguage language;

  /// Recorded so a transcript translated by a weaker engine can be identified
  /// later — ML Kit and an online engine will not produce the same text.
  final String engineId;

  Map<String, dynamic> toJson() => {
        'text': text,
        'language': language.name,
        'engine': engineId,
      };
}
