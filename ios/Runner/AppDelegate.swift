import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  /// Matches ModelDownloadService._backupChannel on the Dart side.
  private static let backupChannelName = "com.idatagear.momerarecording/backup"
  /// Matches RecordingSessionChannel on the Dart side.
  private static let recordingSessionChannelName =
    "com.idatagear.momerarecording/recording_session"
  /// Matches DeviceInfoChannel on the Dart side.
  private static let capabilitiesChannelName =
    "com.idatagear.momerarecording/capabilities"

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
    registerCapabilitiesChannel(with: engineBridge.pluginRegistry)
  }

  /// Answers the device questions a capability gate cannot settle from Dart.
  ///
  /// Best-effort by design: the Dart side treats any error as "unknown" and
  /// stays permissive, so a failure here can never hide a feature.
  private func registerCapabilitiesChannel(with registry: FlutterPluginRegistry) {
    guard let registrar = registry.registrar(forPlugin: "MomeraCapabilities") else {
      return
    }
    let channel = FlutterMethodChannel(
      name: AppDelegate.capabilitiesChannelName,
      binaryMessenger: registrar.messenger()
    )
    channel.setMethodCallHandler { call, result in
      switch call.method {
      case "freeDiskBytes":
        result(AppDelegate.freeDiskBytes() ?? FlutterError(
          code: "unavailable",
          message: "Could not read free disk space",
          details: nil))

      case "describe":
        // `physicalMemory` is a UInt64; clamp so a machine with more RAM than
        // Int64.max (not today, but the cast is still a lie without this)
        // cannot wrap into a negative "tiny device".
        let physical = ProcessInfo.processInfo.physicalMemory
        let total = physical > UInt64(Int64.max) ? Int64.max : Int64(physical)
        result([
          "totalMemoryBytes": total,
          // iOS has no equivalent of Android's isLowRamDevice. The real
          // constraint is the per-device jetsam limit, which is not readable.
          "isLowRamDevice": false,
        ])

      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }

  /// Free space on the volume holding the app's container, or nil.
  ///
  /// Prefers `volumeAvailableCapacityForImportantUsage` because it counts
  /// purgeable space — the space iOS would itself free to let a download
  /// through — so a device that could accept the model is not told it is full.
  /// That key is optional and can come back nil, hence the plain fallback.
  private static func freeDiskBytes() -> Int64? {
    let url = URL(fileURLWithPath: NSHomeDirectory())
    if let values = try? url.resourceValues(
      forKeys: [.volumeAvailableCapacityForImportantUsageKey]),
      let important = values.volumeAvailableCapacityForImportantUsage
    {
      return important
    }
    if let attributes = try? FileManager.default.attributesOfFileSystem(
      forPath: NSHomeDirectory()),
      let free = attributes[.systemFreeSize] as? NSNumber
    {
      return free.int64Value
    }
    return nil
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
