import 'package:flutter_test/flutter_test.dart';
import 'package:momera_recording/core/services/transcription_service.dart';
import 'package:momera_recording/data/models/recording.dart';
import 'package:momera_recording/data/repositories/recording_repository.dart';

Recording _recordingAt(String path) => Recording(
      path: path,
      createdAt: DateTime(2026, 9, 5, 16, 30, 0),
      sizeBytes: 32044,
    );

void main() {
  group('sanitizeFileName', () {
    test('keeps ordinary names untouched', () {
      expect(RecordingRepository.sanitizeFileName('Team standup'),
          'Team standup');
      expect(RecordingRepository.sanitizeFileName('會議紀錄'), '會議紀錄');
      expect(RecordingRepository.sanitizeFileName('Reunión 2026'),
          'Reunión 2026');
    });

    test('strips path separators so a rename cannot escape the directory', () {
      expect(RecordingRepository.sanitizeFileName('../../etc/passwd'),
          isNot(contains('/')));
      expect(RecordingRepository.sanitizeFileName('a/b\\c'), 'abc');
    });

    test('strips characters that are illegal in a filename', () {
      expect(RecordingRepository.sanitizeFileName('a:b*c?d"e<f>g|h'),
          'abcdefgh');
    });

    test('trims, collapses whitespace and drops leading dots', () {
      expect(RecordingRepository.sanitizeFileName('   spaced   out   '),
          'spaced out');
      expect(RecordingRepository.sanitizeFileName('...hidden'), 'hidden');
    });

    test('caps the length', () {
      final long = 'a' * 400;
      expect(RecordingRepository.sanitizeFileName(long).length, 100);
    });

    test('returns empty for input that is only illegal characters', () {
      expect(RecordingRepository.sanitizeFileName('///'), '');
      expect(RecordingRepository.sanitizeFileName('   '), '');
      expect(RecordingRepository.sanitizeFileName(''), '');
    });
  });

  group('Recording.customName', () {
    test('is null for an auto-generated name, so the UI shows a timestamp', () {
      expect(_recordingAt('/r/recording_20260905_163000.wav').customName, isNull);
    });

    test('is the base name once the user has renamed it', () {
      expect(_recordingAt('/r/Team standup.wav').customName, 'Team standup');
      expect(_recordingAt('/r/會議紀錄.wav').customName, '會議紀錄');
    });

    test('a name that merely resembles the generated form is still custom', () {
      // Wrong digit counts must not be mistaken for a generated name.
      expect(_recordingAt('/r/recording_2026_1630.wav').customName,
          'recording_2026_1630');
      expect(_recordingAt('/r/recording_20260905_163000_v2.wav').customName,
          'recording_20260905_163000_v2');
    });
  });

  group('TranscriptionLanguage', () {
    test('auto is the empty code, which is how SenseVoice detects', () {
      expect(TranscriptionLanguage.auto.code, '');
    });

    test('covers exactly the five the model supports', () {
      final codes = TranscriptionLanguage.values
          .where((l) => l != TranscriptionLanguage.auto)
          .map((l) => l.code)
          .toSet();
      expect(codes, {'zh', 'yue', 'en', 'ja', 'ko'});
      // Spanish is a UI language but not a transcription one — the checkpoint
      // is not trained for it. If this ever changes, the settings copy needs
      // revisiting too.
      expect(codes, isNot(contains('es')));
    });

    test('parses tags in both the bare and wrapped forms', () {
      expect(TranscriptionLanguage.fromTag('zh'), TranscriptionLanguage.mandarin);
      expect(TranscriptionLanguage.fromTag('<|zh|>'),
          TranscriptionLanguage.mandarin);
      expect(TranscriptionLanguage.fromTag('<|yue|>'),
          TranscriptionLanguage.cantonese);
      expect(TranscriptionLanguage.fromTag('<|ko|>'),
          TranscriptionLanguage.korean);
    });

    test('unknown or empty tags yield null rather than a wrong language', () {
      expect(TranscriptionLanguage.fromTag(''), isNull);
      expect(TranscriptionLanguage.fromTag('<||>'), isNull);
      expect(TranscriptionLanguage.fromTag('es'), isNull);
      expect(TranscriptionLanguage.fromTag('nonsense'), isNull);
    });

    test('fromName round-trips and falls back to auto', () {
      for (final l in TranscriptionLanguage.values) {
        expect(TranscriptionLanguage.fromName(l.name), l);
      }
      expect(TranscriptionLanguage.fromName('klingon'),
          TranscriptionLanguage.auto);
      expect(TranscriptionLanguage.fromName(null), TranscriptionLanguage.auto);
    });
  });

  group('Recording.isMultilingual', () {
    test('is false with none or one detected language', () {
      expect(_recordingAt('/r/a.wav').isMultilingual, isFalse);
      expect(
        _recordingAt('/r/a.wav')
            .copyWith(languages: [TranscriptionLanguage.english])
            .isMultilingual,
        isFalse,
      );
    });

    test('is true when speakers switched language', () {
      expect(
        _recordingAt('/r/a.wav').copyWith(languages: [
          TranscriptionLanguage.cantonese,
          TranscriptionLanguage.english,
        ]).isMultilingual,
        isTrue,
      );
    });
  });
}
