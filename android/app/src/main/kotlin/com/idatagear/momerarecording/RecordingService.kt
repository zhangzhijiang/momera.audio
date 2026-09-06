package com.idatagear.momerarecording

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.os.Build
import android.os.IBinder
import androidx.core.app.NotificationCompat

/**
 * Foreground service that keeps microphone capture alive while the app is
 * backgrounded or the screen is locked.
 *
 * Android will not let an app record indefinitely from the background. A
 * foreground service is the sanctioned mechanism, and the platform requires it
 * to show a persistent, non-dismissable notification for its whole lifetime —
 * that notification is how the user can always tell that recording is running.
 *
 * The service does not touch the microphone itself. The `record` plugin owns
 * capture; this only holds the process in the foreground so that capture is not
 * killed. Text is passed in from Dart so it is localised with the rest of the
 * UI.
 */
class RecordingService : Service() {

    companion object {
        const val ACTION_START = "com.idatagear.momerarecording.START_RECORDING"
        const val ACTION_STOP = "com.idatagear.momerarecording.STOP_RECORDING"
        const val ACTION_UPDATE = "com.idatagear.momerarecording.UPDATE_RECORDING"

        const val EXTRA_TITLE = "title"
        const val EXTRA_BODY = "body"
        const val EXTRA_STOP_LABEL = "stopLabel"
        const val EXTRA_SECONDS = "seconds"

        private const val CHANNEL_ID = "momera_recording"
        private const val NOTIFICATION_ID = 4711

        /** Set by the plugin so a Stop tap can be forwarded to Dart. */
        @Volatile
        var onStopRequested: (() -> Unit)? = null
    }

    private var title: String = "Momera Recorder"
    private var body: String = "Recording in progress"
    private var stopLabel: String = "Stop"
    private var seconds: Int = 0

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        when (intent?.action) {
            ACTION_STOP -> {
                // The user tapped Stop in the notification. Tell Dart, which
                // owns the recorder, and let it drive the teardown.
                onStopRequested?.invoke()
                stopRecording()
                return START_NOT_STICKY
            }
            ACTION_UPDATE -> {
                seconds = intent.getIntExtra(EXTRA_SECONDS, seconds)
                notificationManager().notify(NOTIFICATION_ID, buildNotification())
                return START_STICKY
            }
            else -> {
                intent?.getStringExtra(EXTRA_TITLE)?.let { title = it }
                intent?.getStringExtra(EXTRA_BODY)?.let { body = it }
                intent?.getStringExtra(EXTRA_STOP_LABEL)?.let { stopLabel = it }
                seconds = 0
                startInForeground()
                return START_STICKY
            }
        }
    }

    private fun startInForeground() {
        createChannel()
        val notification = buildNotification()
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            // From Android 14 the type is mandatory and must match a declared
            // foregroundServiceType in the manifest.
            startForeground(
                NOTIFICATION_ID,
                notification,
                ServiceInfo.FOREGROUND_SERVICE_TYPE_MICROPHONE
            )
        } else {
            startForeground(NOTIFICATION_ID, notification)
        }
    }

    private fun stopRecording() {
        stopForeground(STOP_FOREGROUND_REMOVE)
        stopSelf()
    }

    private fun buildNotification(): Notification {
        val contentIntent = PendingIntent.getActivity(
            this,
            0,
            Intent(this, MainActivity::class.java).apply {
                flags = Intent.FLAG_ACTIVITY_SINGLE_TOP or Intent.FLAG_ACTIVITY_CLEAR_TOP
            },
            PendingIntent.FLAG_IMMUTABLE
        )

        val stopIntent = PendingIntent.getService(
            this,
            1,
            Intent(this, RecordingService::class.java).setAction(ACTION_STOP),
            PendingIntent.FLAG_IMMUTABLE
        )

        return NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle(title)
            .setContentText("$body · ${formatElapsed(seconds)}")
            .setSmallIcon(android.R.drawable.presence_audio_online)
            .setContentIntent(contentIntent)
            .addAction(0, stopLabel, stopIntent)
            .setOngoing(true)
            .setSilent(true)
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .setCategory(NotificationCompat.CATEGORY_SERVICE)
            .setVisibility(NotificationCompat.VISIBILITY_PUBLIC)
            .build()
    }

    /** `mm:ss`, or `h:mm:ss` once past an hour. */
    private fun formatElapsed(total: Int): String {
        val h = total / 3600
        val m = (total % 3600) / 60
        val s = total % 60
        return if (h > 0) {
            String.format("%d:%02d:%02d", h, m, s)
        } else {
            String.format("%02d:%02d", m, s)
        }
    }

    private fun createChannel() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        val channel = NotificationChannel(
            CHANNEL_ID,
            title,
            NotificationManager.IMPORTANCE_LOW
        ).apply {
            description = body
            setShowBadge(false)
            enableVibration(false)
            setSound(null, null)
        }
        notificationManager().createNotificationChannel(channel)
    }

    private fun notificationManager(): NotificationManager =
        getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
}
