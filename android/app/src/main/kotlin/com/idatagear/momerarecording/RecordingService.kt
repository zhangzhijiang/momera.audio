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
import android.os.PowerManager
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

    private var wakeLock: PowerManager.WakeLock? = null

    /**
     * Whether this instance has been promoted with `startForeground`.
     *
     * A per-second update intent can arrive at a *fresh* service instance —
     * Android killed the old one and the intent brought the class back. Such an
     * instance has been started but never promoted, so posting its notification
     * would leave a "recording" notification with no foreground service behind
     * it, and a service started via `startForegroundService` that never calls
     * `startForeground` is killed by the platform within five seconds.
     */
    private var isForeground = false

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
                //
                // Promote first if this instance was created by this very
                // intent: stopping a service that was started and never
                // promoted is what raises ForegroundServiceDidNotStartInTime.
                if (!isForeground) startInForeground()
                onStopRequested?.invoke()
                stopRecording()
                return START_NOT_STICKY
            }
            ACTION_UPDATE -> {
                seconds = intent.getIntExtra(EXTRA_SECONDS, seconds)
                if (isForeground) {
                    notificationManager().notify(NOTIFICATION_ID, buildNotification())
                } else {
                    // Recreated by this update. Promote rather than post, or
                    // the platform kills us for never calling startForeground.
                    startInForeground()
                }
                return START_NOT_STICKY
            }
            else -> {
                intent?.getStringExtra(EXTRA_TITLE)?.let { title = it }
                intent?.getStringExtra(EXTRA_BODY)?.let { body = it }
                intent?.getStringExtra(EXTRA_STOP_LABEL)?.let { stopLabel = it }
                seconds = 0
                startInForeground()
                // Not sticky: if the process is killed the engine goes with it,
                // so a restarted service would show a recording notification
                // with no recording behind it.
                return START_NOT_STICKY
            }
        }
    }

    private fun startInForeground() {
        acquireWakeLock()
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
        isForeground = true
    }

    private fun stopRecording() {
        isForeground = false
        releaseWakeLock()
        stopForeground(STOP_FOREGROUND_REMOVE)
        stopSelf()
    }

    /**
     * Keep the CPU running for the length of the recording.
     *
     * An active AudioRecord usually holds the device awake by itself, but
     * "usually" is not the promise this app makes: the recording continues
     * until the user stops it. The lock is partial — the screen stays off — and
     * is released the moment recording ends, including if the service is killed
     * out from under us.
     */
    private fun acquireWakeLock() {
        if (wakeLock?.isHeld == true) return
        val power = getSystemService(Context.POWER_SERVICE) as PowerManager
        wakeLock = power.newWakeLock(
            PowerManager.PARTIAL_WAKE_LOCK,
            "MomeraRecorder::capture"
        ).apply {
            setReferenceCounted(false)
            acquire()
        }
    }

    private fun releaseWakeLock() {
        wakeLock?.let { if (it.isHeld) it.release() }
        wakeLock = null
    }

    /**
     * The user swiped the app away.
     *
     * Capture lives in the Flutter engine, which is destroyed with the activity,
     * so the recording is over whatever this service does. Shutting down keeps
     * the notification honest; the audio flushed so far is finalised on the next
     * launch by `recoverInterrupted`.
     *
     * Belt and braces: `android:stopWithTask="true"` in the manifest already
     * makes the platform stop this service on task removal, and that flag means
     * this callback is not guaranteed to run. Whichever path a given ROM takes,
     * the wake lock is released — here, or in [onDestroy].
     */
    override fun onTaskRemoved(rootIntent: Intent?) {
        stopRecording()
        super.onTaskRemoved(rootIntent)
    }

    override fun onDestroy() {
        isForeground = false
        releaseWakeLock()
        super.onDestroy()
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
