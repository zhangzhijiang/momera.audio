import 'package:flutter/foundation.dart';

/// Whether a feature can be offered on this device.
enum CapabilityState {
  /// Offer it, enabled.
  available,

  /// Offer it, but it cannot run until the user does something — download the
  /// model, free some space. **Still visible.**
  blocked,

  /// This device can never run it. Remove it from the UI.
  unsupported,
}

/// Why a feature is not simply [CapabilityState.available].
///
/// The split between permanent and temporary is the whole point of this file.
/// A permanent blocker means the device cannot do it at all, so the UI removes
/// the feature. A temporary one means the user can fix it, so the UI keeps the
/// feature visible and says what is needed — hiding it would leave no way back.
enum CapabilityBlocker {
  none,

  // --- Permanent: the device cannot do this ---------------------------------

  /// A 32-bit process. The speech model is 228 MB on disk and roughly 300 MB
  /// resident, which does not fit reliably in a ~3 GB address space. This is
  /// the `armeabi-v7a` Android split.
  processIs32Bit,

  /// sherpa-onnx's native library would not load — missing `.so`, or an ABI
  /// the build does not ship.
  nativeLibraryMissing,

  /// Loading the model has already died on this device. See
  /// `DeviceCapabilityService` for why this is a breadcrumb rather than a
  /// caught exception.
  modelLoadFailedBefore,

  // --- Temporary: the user can fix this -------------------------------------

  /// The speech model has not been downloaded yet.
  modelNotDownloaded,

  /// Not enough free space to download the model right now.
  notEnoughFreeDisk,
}

/// What the app may offer for one feature on this device.
@immutable
class FeatureCapability {
  const FeatureCapability(
    this.state, {
    this.blocker = CapabilityBlocker.none,
    this.bytesNeeded,
  });

  const FeatureCapability.available()
      : state = CapabilityState.available,
        blocker = CapabilityBlocker.none,
        bytesNeeded = null;

  const FeatureCapability.blocked(this.blocker, {this.bytesNeeded})
      : state = CapabilityState.blocked;

  const FeatureCapability.unsupported(this.blocker)
      : state = CapabilityState.unsupported,
        bytesNeeded = null;

  final CapabilityState state;
  final CapabilityBlocker blocker;

  /// Bytes the user needs to free, when [blocker] is
  /// [CapabilityBlocker.notEnoughFreeDisk].
  final int? bytesNeeded;

  /// Whether the feature should appear in the UI at all.
  ///
  /// True for [CapabilityState.blocked]: a feature the user could unblock must
  /// stay findable.
  bool get isVisible => state != CapabilityState.unsupported;

  /// Whether it can run right now.
  bool get isUsable => state == CapabilityState.available;

  @override
  bool operator ==(Object other) =>
      other is FeatureCapability &&
      other.state == state &&
      other.blocker == blocker &&
      other.bytesNeeded == bytesNeeded;

  @override
  int get hashCode => Object.hash(state, blocker, bytesNeeded);

  @override
  String toString() => 'FeatureCapability($state, $blocker)';
}
