package com.idatagear.momerarecording

import android.Manifest
import android.app.ActivityManager
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import android.os.StatFs
import android.util.Log
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {

    private var channel: MethodChannel? = null
    private var capabilitiesChannel: MethodChannel? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        val channel = MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            RECORDING_SESSION_CHANNEL
        )
        this.channel = channel

        // A Stop tap on the foreground-service notification has to reach Dart,
        // which owns the recorder and the file being written.
        RecordingService.onStopRequested = {
            runOnUiThread { channel.invokeMethod("stopRequested", null) }
        }

        channel.setMethodCallHandler { call, result ->
            when (call.method) {
                "start" -> {
                    // Without POST_NOTIFICATIONS on Android 13+ the foreground
                    // service still runs, but its notification is not shown —
                    // so the user gets no recording indicator and no Stop
                    // action. Ask once, and carry on regardless of the answer.
                    ensureNotificationPermission()
                    val intent = Intent(this, RecordingService::class.java).apply {
                        action = RecordingService.ACTION_START
                        putExtra(RecordingService.EXTRA_TITLE, call.argument<String>("title"))
                        putExtra(RecordingService.EXTRA_BODY, call.argument<String>("body"))
                        putExtra(
                            RecordingService.EXTRA_STOP_LABEL,
                            call.argument<String>("stopLabel")
                        )
                    }
                    ContextCompat.startForegroundService(this, intent)
                    result.success(null)
                }

                "update" -> {
                    val intent = Intent(this, RecordingService::class.java).apply {
                        action = RecordingService.ACTION_UPDATE
                        putExtra(
                            RecordingService.EXTRA_SECONDS,
                            call.argument<Int>("seconds") ?: 0
                        )
                    }
                    // startForegroundService, not startService. These updates
                    // arrive once a second for the whole recording, including
                    // while the app is in the background — and a plain
                    // startService from the background throws once the target
                    // service is no longer running. The service promotes itself
                    // on an update it was recreated by, so the five-second
                    // startForeground deadline is always met.
                    //
                    // Caught rather than thrown: a notification that stops
                    // counting is a cosmetic fault, and must never take the
                    // recording down with it.
                    try {
                        ContextCompat.startForegroundService(this, intent)
                    } catch (e: Exception) {
                        Log.w(TAG, "could not refresh the recording notification", e)
                    }
                    result.success(null)
                }

                "stop" -> {
                    stopService(Intent(this, RecordingService::class.java))
                    result.success(null)
                }

                else -> result.notImplemented()
            }
        }

        registerCapabilitiesChannel(flutterEngine)
    }

    /// Answers the device questions a capability gate cannot settle from Dart.
    ///
    /// Matches DeviceInfoChannel on the Dart side. Every method is best-effort:
    /// the Dart wrapper treats an error as "unknown" and stays permissive, so
    /// failing here can never hide a feature from the user.
    private fun registerCapabilitiesChannel(flutterEngine: FlutterEngine) {
        val channel = MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            CAPABILITIES_CHANNEL
        )
        capabilitiesChannel = channel

        channel.setMethodCallHandler { call, result ->
            when (call.method) {
                "freeDiskBytes" -> {
                    try {
                        // filesDir, not external storage: the speech model lives
                        // in the app-private area, on this volume.
                        result.success(StatFs(filesDir.path).availableBytes)
                    } catch (e: Exception) {
                        result.error("unavailable", e.message, null)
                    }
                }

                "describe" -> {
                    try {
                        val manager =
                            getSystemService(Context.ACTIVITY_SERVICE) as ActivityManager
                        val memory = ActivityManager.MemoryInfo()
                        manager.getMemoryInfo(memory)
                        result.success(
                            mapOf(
                                "totalMemoryBytes" to memory.totalMem,
                                // An OEM declaration that this device should not
                                // be offered memory-heavy features — the one
                                // signal here that is not a proxy.
                                "isLowRamDevice" to manager.isLowRamDevice
                            )
                        )
                    } catch (e: Exception) {
                        result.error("unavailable", e.message, null)
                    }
                }

                else -> result.notImplemented()
            }
        }
    }

    /// Request POST_NOTIFICATIONS once, if this Android version gates it.
    private fun ensureNotificationPermission() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU) return
        val granted = ContextCompat.checkSelfPermission(
            this,
            Manifest.permission.POST_NOTIFICATIONS
        ) == PackageManager.PERMISSION_GRANTED
        if (granted) return
        ActivityCompat.requestPermissions(
            this,
            arrayOf(Manifest.permission.POST_NOTIFICATIONS),
            NOTIFICATION_PERMISSION_REQUEST
        )
    }

    override fun onDestroy() {
        RecordingService.onStopRequested = null
        channel?.setMethodCallHandler(null)
        channel = null
        capabilitiesChannel?.setMethodCallHandler(null)
        capabilitiesChannel = null
        super.onDestroy()
    }

    companion object {
        private const val RECORDING_SESSION_CHANNEL =
            "com.idatagear.momerarecording/recording_session"
        private const val CAPABILITIES_CHANNEL =
            "com.idatagear.momerarecording/capabilities"
        private const val NOTIFICATION_PERMISSION_REQUEST = 4712
        private const val TAG = "MomeraRecording"
    }
}
