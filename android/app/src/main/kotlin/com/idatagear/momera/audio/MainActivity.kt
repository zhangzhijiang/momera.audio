package com.idatagear.momera.audio

import android.Manifest
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {

    private var channel: MethodChannel? = null

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
                    startService(intent)
                    result.success(null)
                }

                "stop" -> {
                    stopService(Intent(this, RecordingService::class.java))
                    result.success(null)
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
        super.onDestroy()
    }

    companion object {
        private const val RECORDING_SESSION_CHANNEL =
            "com.idatagear.momera.audio/recording_session"
        private const val NOTIFICATION_PERMISSION_REQUEST = 4712
    }
}
