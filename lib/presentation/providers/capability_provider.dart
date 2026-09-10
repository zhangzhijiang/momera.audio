import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/capabilities/capability.dart';
import 'service_providers.dart';

/// Bumped whenever a capability verdict may have changed — a model download
/// finished, a load failed, learned failures were reset.
///
/// The capability providers watch it, so the UI re-resolves without needing an
/// app restart.
final capabilityRevisionProvider = StateProvider<int>((ref) => 0);

/// Whether this device may be offered transcription.
final transcriptionCapabilityProvider =
    FutureProvider<FeatureCapability>((ref) {
  ref.watch(capabilityRevisionProvider);
  return ref.read(deviceCapabilityServiceProvider).transcription();
});

/// Convenience for widgets: should the transcription UI be drawn at all?
///
/// Defaults to **true** while the verdict is still resolving. A one-frame flash
/// of a button that then disappears is a far smaller problem than the feature
/// blinking out of existence on every cold start, and the overwhelmingly common
/// case is that the device is capable.
bool watchTranscriptionVisible(WidgetRef ref) {
  return ref.watch(transcriptionCapabilityProvider).maybeWhen(
        data: (capability) => capability.isVisible,
        orElse: () => true,
      );
}

/// Re-resolve every capability. Call after a download or a reset.
void invalidateCapabilities(WidgetRef ref) {
  ref.read(deviceCapabilityServiceProvider).invalidate();
  ref.read(capabilityRevisionProvider.notifier).state++;
}
