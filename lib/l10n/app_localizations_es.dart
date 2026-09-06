// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Spanish Castilian (`es`).
class AppLocalizationsEs extends AppLocalizations {
  AppLocalizationsEs([String locale = 'es']) : super(locale);

  @override
  String get appTitle => 'Momera.Audio';

  @override
  String get tapToRecord => 'Toca para grabar';

  @override
  String get noRecordingsTitle => 'Aún no hay grabaciones';

  @override
  String get noRecordingsBody => 'Toca el botón de grabar para capturar audio.';

  @override
  String get micPermissionRequired =>
      'Se necesita permiso del micrófono para grabar.';

  @override
  String loadFailed(String error) {
    return 'Error al cargar: $error';
  }

  @override
  String get transcribe => 'Transcribir';

  @override
  String get deleteRecordingTitle => '¿Eliminar la grabación?';

  @override
  String get deleteRecordingBody => 'Esta acción no se puede deshacer.';

  @override
  String get delete => 'Eliminar';

  @override
  String get cancel => 'Cancelar';

  @override
  String get retry => 'Reintentar';

  @override
  String get downloadModelTitle => 'Descargar el modelo de voz';

  @override
  String downloadModelBody(String size) {
    return 'La transcripción funciona sin conexión. El modelo de voz ($size) se descarga una sola vez y se guarda en este dispositivo.';
  }

  @override
  String get download => 'Descargar';

  @override
  String get downloadFailed =>
      'Error en la descarga. Comprueba tu conexión e inténtalo de nuevo.';

  @override
  String get settings => 'Ajustes';

  @override
  String get settingsLanguage => 'Idioma';

  @override
  String get settingsLanguageSubtitle =>
      'Idioma utilizado en toda la aplicación';

  @override
  String get languageSystem => 'Predeterminado del sistema';

  @override
  String get languageEnglish => 'English';

  @override
  String get languageSpanish => 'Español';

  @override
  String get languageChineseSimplified => '简体中文';

  @override
  String get languageChineseTraditional => '繁體中文';

  @override
  String get settingsStorage => 'Almacenamiento';

  @override
  String get settingsMaxStorage => 'Almacenamiento máximo';

  @override
  String get settingsMaxStorageSubtitle =>
      'La grabación se detiene cuando tus grabaciones alcanzan este tamaño.';

  @override
  String settingsStorageUsed(String used, String total) {
    return '$used de $total en uso';
  }

  @override
  String get settingsRecording => 'Grabación';

  @override
  String get settingsAutosaveInterval => 'Intervalo de guardado automático';

  @override
  String get settingsAutosaveIntervalSubtitle =>
      'Con qué frecuencia se guarda en el disco la grabación en curso. Un fallo perderá como máximo esta cantidad de audio.';

  @override
  String seconds(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count segundos',
      one: '1 segundo',
    );
    return '$_temp0';
  }

  @override
  String storageFullBody(String limit) {
    return 'La grabación se detuvo porque tus grabaciones alcanzaron el límite de $limit. Elimina algunas grabaciones o aumenta el límite en Ajustes.';
  }

  @override
  String get recoveredRecordingBody =>
      'Se ha recuperado una grabación que se interrumpió.';

  @override
  String get stop => 'Detener';

  @override
  String get notificationRecording => 'Grabación en curso';

  @override
  String get noSpeechDetected => 'No se detectó voz en esta grabación.';

  @override
  String get modelNotReady => 'El modelo de voz aún no está listo.';

  @override
  String get transcriptionFailed => 'Error en la transcripción.';

  @override
  String transcribingPercent(int percent) {
    return 'Transcribiendo… $percent %';
  }

  @override
  String get playbackFailed => 'No se pudo reproducir esta grabación.';
}
