import 'package:flutter/foundation.dart';

import '../../l10n/app_localizations.dart';

/// Languages a transcript can be translated into.
///
/// Deliberately a separate enum from `TranscriptionLanguage`: the set of
/// languages that can be *recognised* and the set that can be *translated* do
/// not coincide. Cantonese is the clearest case — the speech model transcribes
/// it, but no on-device translator supports it.
enum TranslationLanguage {
  english('en', 'en'),
  chineseSimplified('zh', 'zh-Hans'),
  chineseTraditional('zh', 'zh-Hant'),
  japanese('ja', 'ja'),
  korean('ko', 'ko'),

  /// Recognised by the speech model, translatable only by an online engine.
  /// Neither ML Kit nor Apple's on-device translation supports Cantonese.
  cantonese('yue', 'yue');

  const TranslationLanguage(this.mlKitCode, this.bcp47);

  /// ML Kit language tag. Note that ML Kit has no Traditional/Simplified
  /// distinction — both Chinese variants map to `zh`, and it returns
  /// Simplified. Apple's engine does distinguish them, which is one reason to
  /// prefer it where available.
  final String mlKitCode;

  /// BCP-47 tag, used by Apple's engine and by any online engine.
  final String bcp47;

  static TranslationLanguage? fromName(String? name) {
    if (name == null) return null;
    for (final l in TranslationLanguage.values) {
      if (l.name == name) return l;
    }
    return null;
  }
}

/// Display name for a translation target.
String translationLanguageLabel(
  AppLocalizations l10n,
  TranslationLanguage language,
) {
  switch (language) {
    case TranslationLanguage.english:
      return l10n.langEnglish;
    case TranslationLanguage.chineseSimplified:
      return l10n.langChineseSimplified;
    case TranslationLanguage.chineseTraditional:
      return l10n.langChineseTraditional;
    case TranslationLanguage.japanese:
      return l10n.langJapanese;
    case TranslationLanguage.korean:
      return l10n.langKorean;
    case TranslationLanguage.cantonese:
      return l10n.langCantonese;
  }
}

/// Why a translation could not be produced.
enum TranslationFailure {
  /// The engine does not handle this language pair at all.
  unsupportedPair,

  /// The engine supports the pair but its model is not downloaded, and the
  /// caller asked not to download.
  modelNotDownloaded,

  /// Download or setup failed (usually offline).
  modelUnavailable,

  /// The engine is not usable on this device or OS version.
  engineUnavailable,

  /// Anything else.
  failed,
}

class TranslationException implements Exception {
  const TranslationException(this.reason, [this.message]);

  final TranslationFailure reason;
  final String? message;

  @override
  String toString() => 'TranslationException($reason)${message == null ? '' : ': $message'}';
}

/// A translation engine.
///
/// Three implementations are foreseen and the app picks between them at
/// runtime:
///
/// * **ML Kit** — Android, and iOS below 18. Models download per language pair.
/// * **Apple** — iOS 18 and later. Higher quality, models managed by the
///   system, no download for the app to manage.
/// * **Online** — not implemented. See [OnlineTranslator]; it exists so the
///   seam is designed rather than retrofitted.
abstract class Translator {
  /// Short identifier for logs and for telling the user which engine ran.
  String get id;

  /// Whether this engine can run at all on this device/OS.
  Future<bool> isAvailable();

  /// Languages this engine can translate into. Callers should grey out the
  /// rest rather than letting a translation fail after the fact.
  Future<Set<TranslationLanguage>> supportedTargets();

  /// Whether the model for [from] → [to] is present locally.
  ///
  /// Engines with nothing to download (Apple manages its own, an online engine
  /// has none) should report true when the pair is supported.
  Future<bool> isPairReady(TranslationLanguage from, TranslationLanguage to);

  /// Download or prepare whatever [from] → [to] needs.
  Future<void> prepare(TranslationLanguage from, TranslationLanguage to);

  /// Translate [text]. Throws [TranslationException] on failure.
  ///
  /// [from] may be null when the engine can infer the source language.
  Future<String> translate(
    String text, {
    TranslationLanguage? from,
    required TranslationLanguage to,
  });

  /// Release native resources.
  Future<void> dispose();
}

/// Placeholder for a future cloud translator.
///
/// **Intentionally unimplemented.** No provider, model or SDK has been chosen,
/// and picking one now would bake an assumption into the codebase for no
/// benefit. What this type does is fix the *seam*: everything above it — the
/// engine selection, the UI, the persisted results — is written against
/// [Translator], so adding a cloud engine later is a new file and one line in
/// [TranslatorRegistry], not a refactor.
///
/// Whoever implements this must also deal with what it changes about the
/// product, not just the code:
///
/// * The app currently tells users transcription "runs fully offline" and its
///   `PrivacyInfo.xcprivacy` declares that **nothing** is collected. Sending a
///   transcript to a server contradicts both. The manifest, the App Store
///   privacy answers and that copy all have to change together.
/// * Transcripts are meetings, interviews and private conversations. Sending
///   one anywhere must be explicit, per-use consent — never a silent fallback
///   when an offline engine happens not to support a pair.
/// * It needs a key, a cost model, offline handling and cancellation.
///
/// Its one clear use today is Cantonese, which no on-device engine translates.
abstract class OnlineTranslator implements Translator {
  @override
  String get id => 'online';

  /// Whether the user has explicitly agreed to send transcript text off the
  /// device. Must default to false and must be checked before every call.
  Future<bool> hasUserConsent();
}

/// Chooses the best available engine.
///
/// Order is deliberate: Apple first where it exists (better quality, no model
/// downloads for the app to manage, and it distinguishes Simplified from
/// Traditional Chinese, which ML Kit does not), then ML Kit, then anything
/// else registered.
@immutable
class TranslatorRegistry {
  const TranslatorRegistry(this.engines);

  final List<Translator> engines;

  /// First engine that is available and supports [to], or null.
  Future<Translator?> engineFor(TranslationLanguage to) async {
    for (final engine in engines) {
      if (!await engine.isAvailable()) continue;
      if ((await engine.supportedTargets()).contains(to)) return engine;
    }
    return null;
  }

  /// Union of everything the available engines can translate into.
  Future<Set<TranslationLanguage>> supportedTargets() async {
    final all = <TranslationLanguage>{};
    for (final engine in engines) {
      if (await engine.isAvailable()) all.addAll(await engine.supportedTargets());
    }
    return all;
  }
}
