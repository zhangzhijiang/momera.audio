import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  /// Matches ModelDownloadService._backupChannel on the Dart side.
  private static let backupChannelName = "com.idatagear.momerarecording/backup"
  /// Matches RecordingSessionChannel on the Dart side.
  private static let recordingSessionChannelName =
    "com.idatagear.momerarecording/recording_session"

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    registerBackupChannel(with: engineBridge.pluginRegistry)
    registerRecordingSessionChannel(with: engineBridge.pluginRegistry)
    TranslationBridge.register(with: engineBridge.pluginRegistry)
  }

  /// Exposes NSURLIsExcludedFromBackupKey to Dart.
  ///
  /// The ~228 MB speech model is re-downloadable, so it must not be backed up
  /// to iCloud. It lives in Application Support (not Documents, which Apple
  /// rejects for re-creatable data, and not Caches, which the system may purge
  /// out from under a model the user waited to download).
  private func registerBackupChannel(with registry: FlutterPluginRegistry) {
    guard let registrar = registry.registrar(forPlugin: "MomeraBackupChannel") else { return }
    let channel = FlutterMethodChannel(
      name: AppDelegate.backupChannelName,
      binaryMessenger: registrar.messenger()
    )
    channel.setMethodCallHandler { call, result in
      guard call.method == "excludeFromBackup" else {
        result(FlutterMethodNotImplemented)
        return
      }
      guard let path = call.arguments as? String else {
        result(FlutterError(code: "bad_args",
                            message: "excludeFromBackup expects a path string",
                            details: nil))
        return
      }
      var url = URL(fileURLWithPath: path)
      var values = URLResourceValues()
      values.isExcludedFromBackup = true
      do {
        try url.setResourceValues(values)
        result(nil)
      } catch {
        result(FlutterError(code: "exclude_failed",
                            message: error.localizedDescription,
                            details: path))
      }
    }
  }

  /// Background / lock-screen capture on iOS.
  ///
  /// Deliberately does **not** configure `AVAudioSession`. `record_ios` manages
  /// the shared session itself — it sets `.playAndRecord` with the options from
  /// `RecordConfig.iosConfig` when capture starts — so a category set here would
  /// simply be overwritten, and two owners of one audio session is how you get
  /// intermittent, unreproducible audio bugs. Session options are configured
  /// from Dart instead (see AudioRecordingService).
  ///
  /// What actually keeps capture alive when the screen locks is
  /// `UIBackgroundModes: audio` in Info.plist plus the plugin's active session.
  ///
  /// The channel exists so the Dart side is uniform across platforms. On iOS
  /// there is no notification to show — the system displays its own recording
  /// indicator — so every method is a no-op.
  private func registerRecordingSessionChannel(with registry: FlutterPluginRegistry) {
    guard let registrar = registry.registrar(forPlugin: "MomeraRecordingSession") else {
      return
    }
    let channel = FlutterMethodChannel(
      name: AppDelegate.recordingSessionChannelName,
      binaryMessenger: registrar.messenger()
    )
    channel.setMethodCallHandler { call, result in
      switch call.method {
      case "start", "update", "stop":
        result(nil)
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }
}
