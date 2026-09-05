import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  /// Matches ModelDownloadService._backupChannel on the Dart side.
  private static let backupChannelName = "com.idatagear.momera.audio/backup"

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    registerBackupChannel(with: engineBridge.pluginRegistry)
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
}
