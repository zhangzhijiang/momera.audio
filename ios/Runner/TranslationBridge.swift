import Flutter
import SwiftUI
import UIKit

#if canImport(Translation)
  import Translation
#endif

/// Bridges Apple's Translation framework (iOS 18+) to Dart.
///
/// **Why this is more involved than it looks.** On iOS 18 through 26.3,
/// `TranslationSession` has no public initialiser — it can only be vended by
/// SwiftUI's `.translationTask` modifier. So to translate from a Flutter app we
/// host a zero-sized SwiftUI view off-screen, let SwiftUI hand it a session,
/// and complete a continuation with the result. iOS 26.4 added a direct
/// `init()`, but the app supports earlier versions, so the hosted path is the
/// one that has to work.
///
/// Everything is gated on `#available(iOS 18, *)`; below that the channel
/// reports unavailable and Dart falls back to ML Kit.
enum TranslationBridge {
  static let channelName = "com.idatagear.momera.audio/translation"

  /// Languages the app offers. Kept in step with TranslationLanguage on the
  /// Dart side; anything Apple does not actually support is filtered out at
  /// runtime by `LanguageAvailability`.
  private static let candidateTags = ["en", "zh-Hans", "zh-Hant", "ja", "ko"]

  static func register(with registry: FlutterPluginRegistry) {
    guard let registrar = registry.registrar(forPlugin: "MomeraTranslation") else {
      return
    }
    let channel = FlutterMethodChannel(
      name: channelName,
      binaryMessenger: registrar.messenger()
    )

    channel.setMethodCallHandler { call, result in
      switch call.method {
      case "isAvailable":
        if #available(iOS 18.0, *) {
          result(true)
        } else {
          result(false)
        }

      case "supportedTargets":
        guard #available(iOS 18.0, *) else {
          result([String]())
          return
        }
        Task {
          let supported = await supportedTargetTags()
          await MainActor.run { result(supported) }
        }

      case "isPairReady":
        guard #available(iOS 18.0, *),
          let args = call.arguments as? [String: Any],
          let from = args["from"] as? String,
          let to = args["to"] as? String
        else {
          result(false)
          return
        }
        Task {
          let status = await LanguageAvailability().status(
            from: Locale.Language(identifier: from),
            to: Locale.Language(identifier: to)
          )
          // `.installed` means translation can run right now. `.supported`
          // means the system would download assets first, which it prompts
          // for — still usable, but not instant.
          await MainActor.run { result(status == .installed) }
        }

      case "translate":
        guard #available(iOS 18.0, *) else {
          result(
            FlutterError(
              code: "unavailable",
              message: "Apple translation requires iOS 18", details: nil))
          return
        }
        guard let args = call.arguments as? [String: Any],
          let text = args["text"] as? String,
          let to = args["to"] as? String
        else {
          result(
            FlutterError(code: "bad_args", message: "text and to are required", details: nil))
          return
        }
        let from = args["from"] as? String
        Task { @MainActor in
          do {
            let translated = try await AppleTranslationRunner.shared.translate(
              text: text, from: from, to: to)
            result(translated)
          } catch let error as TranslationBridgeError {
            result(
              FlutterError(code: error.code, message: error.localizedDescription, details: nil))
          } catch {
            result(
              FlutterError(code: "failed", message: error.localizedDescription, details: nil))
          }
        }

      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }

  @available(iOS 18.0, *)
  private static func supportedTargetTags() async -> [String] {
    let availability = LanguageAvailability()
    var supported: [String] = []
    // English is the practical pivot: if a language pairs with English the
    // system can generally reach the rest.
    let reference = Locale.Language(identifier: "en")
    for tag in candidateTags {
      let language = Locale.Language(identifier: tag)
      let status =
        tag == "en"
        ? await availability.status(from: language, to: Locale.Language(identifier: "zh-Hans"))
        : await availability.status(from: reference, to: language)
      if status != .unsupported {
        supported.append(tag)
      }
    }
    return supported
  }
}

enum TranslationBridgeError: LocalizedError {
  case unsupportedPair
  case unavailable
  case failed(String)

  var code: String {
    switch self {
    case .unsupportedPair: return "unsupported_pair"
    case .unavailable: return "unavailable"
    case .failed: return "failed"
    }
  }

  var errorDescription: String? {
    switch self {
    case .unsupportedPair: return "That language pair is not supported."
    case .unavailable: return "Translation is unavailable on this device."
    case .failed(let message): return message
    }
  }
}

/// Drives a `TranslationSession` by hosting an off-screen SwiftUI view.
///
/// SwiftUI owns the session's lifetime, so the flow is: attach a hidden host
/// view to the key window, let `.translationTask` deliver a session, run the
/// translation, resume the continuation, then tear the host down. Serialised
/// with an actor because two overlapping sessions on one host would race.
@available(iOS 18.0, *)
@MainActor
final class AppleTranslationRunner {
  static let shared = AppleTranslationRunner()

  private init() {}

  private var pending: [UUID: CheckedContinuation<String, Error>] = [:]
  private var hosts: [UUID: UIViewController] = [:]

  func translate(text: String, from: String?, to: String) async throws -> String {
    guard let window = Self.keyWindow(), let root = window.rootViewController else {
      throw TranslationBridgeError.unavailable
    }

    let id = UUID()
    let configuration = TranslationSession.Configuration(
      source: from.map { Locale.Language(identifier: $0) },
      target: Locale.Language(identifier: to)
    )

    return try await withCheckedThrowingContinuation { continuation in
      pending[id] = continuation

      let view = TranslationHostView(
        configuration: configuration,
        text: text,
        onResult: { [weak self] result in
          Task { @MainActor in self?.finish(id: id, result: result) }
        }
      )

      let host = UIHostingController(rootView: view)
      host.view.frame = .zero
      host.view.isUserInteractionEnabled = false
      host.view.alpha = 0
      hosts[id] = host

      root.addChild(host)
      root.view.addSubview(host.view)
      host.didMove(toParent: root)
    }
  }

  private func finish(id: UUID, result: Result<String, Error>) {
    if let host = hosts.removeValue(forKey: id) {
      host.willMove(toParent: nil)
      host.view.removeFromSuperview()
      host.removeFromParent()
    }
    guard let continuation = pending.removeValue(forKey: id) else { return }
    continuation.resume(with: result)
  }

  private static func keyWindow() -> UIWindow? {
    UIApplication.shared.connectedScenes
      .compactMap { $0 as? UIWindowScene }
      .flatMap { $0.windows }
      .first { $0.isKeyWindow }
  }
}

/// Zero-sized SwiftUI view whose only job is to receive a `TranslationSession`.
@available(iOS 18.0, *)
private struct TranslationHostView: View {
  let configuration: TranslationSession.Configuration
  let text: String
  let onResult: (Result<String, Error>) -> Void

  var body: some View {
    Color.clear
      .frame(width: 0, height: 0)
      .translationTask(configuration) { session in
        do {
          let response = try await session.translate(text)
          onResult(.success(response.targetText))
        } catch {
          onResult(.failure(TranslationBridgeError.failed(error.localizedDescription)))
        }
      }
  }
}
