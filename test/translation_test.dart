import 'package:flutter_test/flutter_test.dart';
import 'package:momera_audio/core/services/transcription_service.dart';
import 'package:momera_audio/core/translation/translation_service.dart';
import 'package:momera_audio/core/translation/translator.dart';

/// Stand-in engine so registry and service logic can be tested without a
/// platform channel or an ML Kit model download.
class _FakeTranslator implements Translator {
  _FakeTranslator({
    required this.id,
    required this.available,
    required this.targets,
    this.output = 'translated',
    this.isReusable = true,
  });

  @override
  final String id;
  @override
  final bool isReusable;
  final bool available;
  final Set<TranslationLanguage> targets;
  final String output;

  int translateCalls = 0;
  TranslationLanguage? lastFrom;
  TranslationLanguage? lastTo;

  @override
  Future<bool> isAvailable() async => available;

  @override
  Future<Set<TranslationLanguage>> supportedTargets() async => targets;

  @override
  Future<bool> isPairReady(TranslationLanguage from, TranslationLanguage to) async =>
      targets.contains(to);

  @override
  Future<void> prepare(TranslationLanguage from, TranslationLanguage to) async {}

  @override
  Future<String> translate(
    String text, {
    TranslationLanguage? from,
    required TranslationLanguage to,
  }) async {
    translateCalls++;
    lastFrom = from;
    lastTo = to;
    return output;
  }

  @override
  Future<void> dispose() async {}
}

void main() {
  group('TranslationLanguage', () {
    test('Chinese variants share an ML Kit code but differ in BCP-47', () {
      // ML Kit has no script distinction; Apple does. The mapping has to record
      // both so each engine gets the tag it understands.
      expect(TranslationLanguage.chineseSimplified.mlKitCode,
          TranslationLanguage.chineseTraditional.mlKitCode);
      expect(TranslationLanguage.chineseSimplified.bcp47, 'zh-Hans');
      expect(TranslationLanguage.chineseTraditional.bcp47, 'zh-Hant');
    });

    test('fromName round-trips and rejects nonsense', () {
      for (final l in TranslationLanguage.values) {
        expect(TranslationLanguage.fromName(l.name), l);
      }
      expect(TranslationLanguage.fromName('klingon'), isNull);
      expect(TranslationLanguage.fromName(null), isNull);
    });
  });

  group('TranslatorRegistry', () {
    test('prefers the first available engine that supports the target', () {
      // Apple is registered first because it is better where it exists.
      final apple = _FakeTranslator(
          id: 'apple', available: true, targets: {TranslationLanguage.english});
      final mlkit = _FakeTranslator(
          id: 'mlkit', available: true, targets: {TranslationLanguage.english});
      final registry = TranslatorRegistry([apple, mlkit]);

      expectLater(
        registry.engineFor(TranslationLanguage.english).then((e) => e?.id),
        completion('apple'),
      );
    });

    test('skips an unavailable engine', () async {
      final apple = _FakeTranslator(
          id: 'apple', available: false, targets: {TranslationLanguage.english});
      final mlkit = _FakeTranslator(
          id: 'mlkit', available: true, targets: {TranslationLanguage.english});
      final registry = TranslatorRegistry([apple, mlkit]);

      expect((await registry.engineFor(TranslationLanguage.english))?.id, 'mlkit');
    });

    test('skips an engine that does not support the target', () async {
      final apple = _FakeTranslator(
          id: 'apple', available: true, targets: {TranslationLanguage.korean});
      final mlkit = _FakeTranslator(
          id: 'mlkit', available: true, targets: {TranslationLanguage.english});
      final registry = TranslatorRegistry([apple, mlkit]);

      expect((await registry.engineFor(TranslationLanguage.english))?.id, 'mlkit');
    });

    test('preferReusable skips a non-reusable engine when another exists',
        () async {
      // Live translation runs once per utterance. Apple's bridge mounts a fresh
      // SwiftUI host per call, so per-phrase work must fall to ML Kit even
      // though Apple is otherwise preferred.
      final apple = _FakeTranslator(
        id: 'apple',
        available: true,
        targets: {TranslationLanguage.english},
        isReusable: false,
      );
      final mlkit = _FakeTranslator(
          id: 'mlkit', available: true, targets: {TranslationLanguage.english});
      final registry = TranslatorRegistry([apple, mlkit]);

      expect((await registry.engineFor(TranslationLanguage.english))?.id,
          'apple',
          reason: 'without the flag, registration order still wins');
      expect(
        (await registry.engineFor(TranslationLanguage.english,
                preferReusable: true))
            ?.id,
        'mlkit',
      );
    });

    test('preferReusable still returns a non-reusable engine if it is the only '
        'one', () async {
      final apple = _FakeTranslator(
        id: 'apple',
        available: true,
        targets: {TranslationLanguage.english},
        isReusable: false,
      );
      final registry = TranslatorRegistry([apple]);
      expect(
        (await registry.engineFor(TranslationLanguage.english,
                preferReusable: true))
            ?.id,
        'apple',
        reason: 'a slow engine beats no translation at all',
      );
    });

    test('returns null when nothing handles the target', () async {
      final registry = TranslatorRegistry([
        _FakeTranslator(
            id: 'mlkit', available: true, targets: {TranslationLanguage.english}),
      ]);
      expect(await registry.engineFor(TranslationLanguage.cantonese), isNull);
    });

    test('supportedTargets unions only the available engines', () async {
      final registry = TranslatorRegistry([
        _FakeTranslator(
            id: 'apple', available: false, targets: {TranslationLanguage.korean}),
        _FakeTranslator(
            id: 'mlkit',
            available: true,
            targets: {TranslationLanguage.english, TranslationLanguage.japanese}),
      ]);
      expect(await registry.supportedTargets(),
          {TranslationLanguage.english, TranslationLanguage.japanese});
    });
  });

  group('TranslationService.sourceFor', () {
    test('maps a single detected language', () {
      expect(TranslationService.sourceFor([TranscriptionLanguage.english]),
          TranslationLanguage.english);
      expect(TranslationService.sourceFor([TranscriptionLanguage.mandarin]),
          TranslationLanguage.chineseSimplified);
      expect(TranslationService.sourceFor([TranscriptionLanguage.cantonese]),
          TranslationLanguage.cantonese);
      expect(TranslationService.sourceFor([TranscriptionLanguage.japanese]),
          TranslationLanguage.japanese);
      expect(TranslationService.sourceFor([TranscriptionLanguage.korean]),
          TranslationLanguage.korean);
    });

    test('declines when there is no detected language', () {
      expect(TranslationService.sourceFor([]), isNull);
    });

    test('declines for a multilingual recording rather than guessing', () {
      // ML Kit needs one definite source. Picking the first detected language
      // would mistranslate the other half of a bilingual conversation.
      expect(
        TranslationService.sourceFor(
            [TranscriptionLanguage.cantonese, TranscriptionLanguage.english]),
        isNull,
      );
    });
  });

  group('TranslationService.translate', () {
    test('routes to the chosen engine and records which one ran', () async {
      final mlkit = _FakeTranslator(
        id: 'mlkit',
        available: true,
        targets: {TranslationLanguage.english},
        output: 'hello',
      );
      final service =
          TranslationService(registry: TranslatorRegistry([mlkit]));

      final outcome = await service.translate(
        '你好',
        from: TranslationLanguage.chineseSimplified,
        to: TranslationLanguage.english,
      );

      expect(outcome.text, 'hello');
      expect(outcome.language, TranslationLanguage.english);
      expect(outcome.engineId, 'mlkit');
      expect(mlkit.translateCalls, 1);
      expect(mlkit.lastFrom, TranslationLanguage.chineseSimplified);
    });

    test('refuses Cantonese rather than silently routing it through Chinese',
        () async {
      // Routing yue through zh would return plausible but subtly wrong text.
      final service = TranslationService(
        registry: TranslatorRegistry([
          _FakeTranslator(
              id: 'mlkit',
              available: true,
              targets: {TranslationLanguage.english}),
        ]),
      );

      expect(
        () => service.translate('你好',
            from: TranslationLanguage.cantonese,
            to: TranslationLanguage.english),
        throwsA(isA<TranslationException>().having(
            (e) => e.reason, 'reason', TranslationFailure.unsupportedPair)),
      );
    });

    test('throws when no engine handles the target', () async {
      final service = TranslationService(
        registry: TranslatorRegistry([
          _FakeTranslator(
              id: 'mlkit', available: true, targets: {TranslationLanguage.english}),
        ]),
      );

      expect(
        () => service.translate('hi',
            from: TranslationLanguage.english, to: TranslationLanguage.korean),
        throwsA(isA<TranslationException>()),
      );
    });
  });

  group('TranslationOutcome', () {
    test('round-trips through JSON', () {
      const outcome = TranslationOutcome(
        text: '你好',
        language: TranslationLanguage.chineseSimplified,
        engineId: 'apple',
      );
      final restored = TranslationOutcome.fromJson(outcome.toJson());
      expect(restored.text, outcome.text);
      expect(restored.language, outcome.language);
      expect(restored.engineId, outcome.engineId);
    });

    test('tolerates a malformed record instead of throwing', () {
      final restored = TranslationOutcome.fromJson(const {});
      expect(restored.text, '');
      expect(restored.engineId, 'unknown');
    });
  });
}
