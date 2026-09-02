package com.appsbyrafa.stillalive

import android.app.NotificationManager
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.provider.Settings
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/**
 * Handles full-screen notification intents and communication of alarm
 * events from Android back to Flutter.
 *
 * This class bridges the lifecycle gap between Android and Flutter.
 *
 * An alarm may launch [MainActivity] before the Flutter engine and its
 * MethodChannel are ready. In that situation, the alarm identifier is
 * temporarily stored in [pendingAlarmId] and delivered once the Flutter
 * engine becomes available.
 *
 * The class is also responsible for:
 *
 * - Detecting alarm launch Intents.
 * - Retaining pending alarm identifiers.
 * - Forwarding alarm events to Flutter.
 * - Checking full-screen intent permission.
 * - Opening the Android full-screen intent settings screen.
 * - Removing the active alarm notification once the alarm Activity opens.
 *
 * ```
 * Android
 *     ↓
 * Full-screen Intent
 *     ↓
 * MainActivity
 *     ↓
 * FullScreenIntentHandler
 *     ↓
 * MethodChannel
 *     ↓
 * Flutter
 * ```
 *
 * @param context Android context used to access system services and launch
 * Android settings.
 */
class FullScreenIntentHandler(
    private val context: Context
) {

    /**
     * Alarm identifier received from Android but not yet delivered to
     * Flutter.
     *
     * The identifier remains pending until the Flutter engine is available
     * and the event can be sent through the MethodChannel.
     */
    private var pendingAlarmId: Int? = null

    /**
     * Flutter engine used to communicate alarm events back to Dart.
     *
     * The engine may not be available when an alarm launches the activity,
     * which is why [pendingAlarmId] is retained separately.
     */
    private var flutterEngine: FlutterEngine? = null

    /**
     * Associates this handler with the Flutter engine used by the activity.
     *
     * If an alarm was received before the Flutter engine became available,
     * this method attempts to deliver the pending alarm immediately.
     *
     * @param engine Flutter engine associated with [MainActivity].
     */
    fun setFlutterEngine(
        engine: FlutterEngine
    ) {
        flutterEngine = engine
    }

    /**
     * Boolean value that expresses if Flutter is ready to receive
     * pending alarms.
     */
    private var flutterReady = false

    /**
     * If an alarm was received before the Flutter engine became available,
     * this method attempts to deliver the pending alarm immediately.
     */
    fun markFlutterReady() {
        flutterReady = true
        sendPendingAlarmToFlutter()
    }

    /**
     * Processes an Intent received by [MainActivity].
     *
     * If the Intent contains a valid alarm identifier, the identifier is
     * stored until Flutter is ready. The active alarm notification is then
     * cancelled because the full-screen activity has successfully opened.
     *
     * If the Flutter engine is already available, the alarm is forwarded
     * immediately.
     *
     * @param intent Intent received when the activity is created or when an
     * existing activity receives a new Intent.
     */
    fun handleIntent(
        intent: Intent?
    ) {
        if (intent == null) {
            return
        }

        val alarmId =
            intent.getIntExtra(
                AlarmReceiver.EXTRA_ALARM_ID,
                -1
            )

        if (alarmId == -1) {
            return
        }

        pendingAlarmId = alarmId

        cancelAlarmNotification()

        sendPendingAlarmToFlutter()
    }

    /**
     * Sends the currently pending alarm event to Flutter.
     *
     * The event is sent through the application's MethodChannel using the
     * `alarmFired` method.
     *
     * If no alarm is pending, or if the Flutter engine is not yet available,
     * the method returns without clearing the pending alarm. This allows
     * the event to be delivered later when Flutter becomes ready.
     *
     * Once the event has been sent to Flutter, the pending alarm identifier
     * is cleared.
     */
    fun sendPendingAlarmToFlutter() {
        if (!flutterReady) {
            return
        }
        
        val alarmId =
            pendingAlarmId
                ?: return

        val messenger =
            flutterEngine
                ?.dartExecutor
                ?.binaryMessenger
                ?: return

        MethodChannel(
            messenger,
            MainActivity.CHANNEL
        ).invokeMethod(
            "alarmFired",
            mapOf(
                "alarmId" to alarmId
            )
        )

        pendingAlarmId = null
    }

    /**
     * Determines whether the application is currently allowed to use
     * full-screen intents.
     *
     * Android 14 (API 34) and later expose an explicit system setting for
     * full-screen intent access. On earlier Android versions, full-screen
     * intent access is treated as available.
     *
     * @return `true` if full-screen intents are currently available,
     * otherwise `false`.
     */
    fun canUseFullScreenIntent(): Boolean {
        return if (
            Build.VERSION.SDK_INT >= 34
        ) {
            val manager =
                context.getSystemService(
                    NotificationManager::class.java
                )

            manager.canUseFullScreenIntent()
        } else {
            true
        }
    }

    /**
     * Opens the Android system settings screen where the user can manage
     * full-screen intent access for the application.
     *
     * This functionality is only available on Android 14 (API 34) and later.
     * On earlier Android versions the method performs no action.
     */
    fun openSettings() {
        if (
            Build.VERSION.SDK_INT >= 34
        ) {
            val intent = Intent(
                Settings
                    .ACTION_MANAGE_APP_USE_FULL_SCREEN_INTENT
            ).apply {
                data = Uri.parse(
                    "package:${context.packageName}"
                )
            }

            intent.addFlags(
                Intent.FLAG_ACTIVITY_NEW_TASK
            )

            context.startActivity(intent)
        }
    }

    /**
     * Removes the active alarm notification from the notification shade.
     *
     * This is called when the full-screen alarm Activity has successfully
     * opened so that the notification does not remain visible behind the
     * alarm UI.
     */
    private fun cancelAlarmNotification() {
        val manager =
            context.getSystemService(
                NotificationManager::class.java
            )

        manager.cancel(
            NotificationSender.ALARM_NOTIFICATION_ID
        )
    }
}
