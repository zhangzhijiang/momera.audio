import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// How much memory the device has, as far as the platform will say.
@immutable
class DeviceMemoryInfo {
  const DeviceMemoryInfo({
    required this.totalMemoryBytes,
    required this.isLowRamDevice,
  });

  /// Nothing is known — the channel failed, or is not implemented here.
  ///
  /// `-1` rather than `0` so a caller comparing against a threshold has to
  /// notice: an unknown device read as "0 bytes of RAM" would be classified as
  /// the smallest possible phone.
  const DeviceMemoryInfo.unknown()
      : totalMemoryBytes = -1,
        isLowRamDevice = false;

  /// Total physical RAM, or `-1` when unknown.
  final int totalMemoryBytes;

  /// Android's `ActivityManager.isLowRamDevice()` — an OEM declaration that the
  /// device should not be offered memory-heavy features. Always false on iOS,
  /// which has no equivalent.
  final bool isLowRamDevice;

  bool get isKnown => totalMemoryBytes > 0;
}

/// Device facts that need a platform call: free disk, and physical memory.
///
/// **Every failure path is permissive.** A capability gate is allowed to hide a
/// feature only when it knows the device cannot run it; a channel that is
/// missing, throwing, or not implemented on this platform knows nothing, so it
/// answers "unknown" and the caller carries on as if the device were capable.
/// That is why the catches here are on `Object` rather than `PlatformException`
/// — a `MissingPluginException` from an unregistered channel is exactly the
/// case that must not turn into a hidden feature.
class DeviceInfoChannel {
  const DeviceInfoChannel._();

  static const MethodChannel _channel =
      MethodChannel('com.idatagear.momerarecording/capabilities');

  /// Free space on the volume holding the app's own files, or `-1` if unknown.
  ///
  /// Deliberately not cached: free space changes, and the user deleting
  /// something is the whole remedy for the state this feeds.
  static Future<int> freeDiskBytes() async {
    try {
      final bytes = await _channel.invokeMethod<int>('freeDiskBytes');
      return bytes ?? -1;
    } catch (e) {
      debugPrint('DeviceInfoChannel.freeDiskBytes unavailable: $e');
      return -1;
    }
  }

  static Future<DeviceMemoryInfo> describe() async {
    try {
      final info = await _channel.invokeMapMethod<String, Object?>('describe');
      if (info == null) return const DeviceMemoryInfo.unknown();
      return DeviceMemoryInfo(
        totalMemoryBytes: (info['totalMemoryBytes'] as num?)?.toInt() ?? -1,
        isLowRamDevice: info['isLowRamDevice'] as bool? ?? false,
      );
    } catch (e) {
      debugPrint('DeviceInfoChannel.describe unavailable: $e');
      return const DeviceMemoryInfo.unknown();
    }
  }
}
