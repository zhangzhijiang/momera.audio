import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'translator.dart';

/// On-device translation via Apple's Translation framework (iOS 18+).
///
/// Preferred over ML Kit where available: the system manages the models (no
/// download for the app to run or explain), quality is generally better, and
/// unlike ML Kit it distinguishes Simplified from Traditional Chinese.
///
/// Availability is decided natively, not here. The Dart side cannot see the OS
/// version reliably enough to gate a framework, and the native side has to
/// check `#available(iOS 18, *)` anyway — so [isAvailable] asks it.
class AppleTranslator implements Translator {
  const AppleTranslator();

  @override
  String get id => 'apple';

  /// Every call mounts a fresh SwiftUI host and TranslationSession — there is
  /// no session cache — so this engine is a poor fit for per-utterance work.
  /// See TranslationBridge.swift.
  @override
  bool get isReusable => false;

  static const MethodChannel _channel =
      MethodChannel('com.idatagear.momerarecording/translation');

  @override
  Future<bool> isAvailable() async {
    if (defaultTargetPlatform != TargetPlatform.iOS) return false;
    try {
      return await _channel.invokeMethod<bool>('isAvailable') ?? false;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<Set<TranslationLanguage>> supportedTargets() async {
    if (!await isAvailable()) return const {};
    try {
      final codes = await _channel.invokeListMethod<String>('supportedTargets');
      if (codes == null) return const {};
      return {
        for (final language in TranslationLanguage.values)
          if (codes.contains(language.bcp47)) language,
      };
    } catch (_) {
      return const {};
    }
  }

  @override
  Future<bool> isPairReady(
    TranslationLanguage from,
    TranslationLanguage to,
  ) async {
    if (!await isAvailable()) return false;
    try {
      return await _channel.invokeMethod<bool>('isPairReady', {
            'from': from.bcp47,
            'to': to.bcp47,
          }) ??
          false;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<void> prepare(TranslationLanguage from, TranslationLanguage to) async {
    // The system prompts for and installs language assets on first use; there
    // is nothing for the app to download. Treated as a no-op rather than
    // pretending to manage models we do not own.
  }

  @override
  Future<String> translate(
    String text, {
    TranslationLanguage? from,
    required TranslationLanguage to,
  }) async {
    if (text.trim().isEmpty) return '';
    if (!await isAvailable()) {
      throw const TranslationException(TranslationFailure.engineUnavailable);
    }
    try {
      final result = await _channel.invokeMethod<String>('translate', {
        // Apple can infer the source when it is omitted.
        'from': from?.bcp47,
        'to': to.bcp47,
        'text': text,
      });
      if (result == null) {
        throw const TranslationException(TranslationFailure.failed);
      }
      return result;
    } on PlatformException catch (e) {
      throw TranslationException(
        switch (e.code) {
          'unsupported_pair' => TranslationFailure.unsupportedPair,
          'unavailable' => TranslationFailure.engineUnavailable,
          _ => TranslationFailure.failed,
        },
        e.message,
      );
    }
  }

  @override
  Future<void> dispose() async {}
}
