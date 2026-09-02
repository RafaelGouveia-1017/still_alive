package com.appsbyrafa.stillalive

import android.content.Intent
import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/**
 * Main Android activity for the StillAlive application.
 *
 * This activity hosts the Flutter application and acts as the boundary
 * between Flutter and the native Android functionality required by the
 * application.
 *
 * Native functionality is delegated to dedicated helper classes:
 *
 * - [AlarmManagerHelper] handles scheduling and cancellation of alarms.
 * - [NotificationSender] handles Android notification creation and delivery.
 * - [FullScreenIntentHandler] handles alarm launch intents and communication
 *   of alarm events back to Flutter.
 *
 * The activity itself intentionally contains minimal Android-specific logic
 * so that each native responsibility remains isolated and independently
 * maintainable.
 *
 * Flutter communicates with the native Android implementation through the
 * following [MethodChannel]:
 *
 * ```
 * com.appsbyrafa.stillalive/android
 * ```
 *
 * Supported Flutter-to-Android methods include:
 *
 * - `flutterReady`
 * - `canUseFullScreenIntent`
 * - `openFullScreenIntentSettings`
 * - `scheduleAlarm`
 * - `cancelAlarm`
 * - `launchNotification`
 */
class MainActivity : FlutterActivity() {

    companion object {
        /**
         * MethodChannel name used for communication between Flutter and
         * the native Android implementation.
         */
        const val CHANNEL = "com.appsbyrafa.stillalive/flutter"
    }

    private lateinit var alarmManagerHelper: AlarmManagerHelper
    private lateinit var notificationSender: NotificationSender
    private lateinit var fullScreenIntentHandler: FullScreenIntentHandler

    /**
     * Initializes the native Android helpers and processes the Intent that
     * was used to launch the activity.
     *
     * The launch Intent may contain an alarm identifier when the activity
     * was opened through a full-screen alarm notification.
     *
     * @param savedInstanceState Previously saved activity state, or `null`
     * if the activity is being created for the first time.
     */
    override fun onCreate(
        savedInstanceState: Bundle?
    ) {

        alarmManagerHelper =
            AlarmManagerHelper(this)

        notificationSender =
            NotificationSender(this)

        fullScreenIntentHandler =
            FullScreenIntentHandler(this)

        super.onCreate(savedInstanceState)

        fullScreenIntentHandler.handleIntent(
            intent
        )
    }

    /**
     * Handles a new Intent delivered to an existing activity instance.
     *
     * This can occur when Android reuses the existing [MainActivity]
     * instead of creating a new instance, for example when the activity
     * is launched using a `singleTop`-compatible launch configuration.
     *
     * The Intent is forwarded to [FullScreenIntentHandler] so that alarm
     * events can be detected and delivered to Flutter.
     *
     * @param intent New Intent delivered to the existing activity.
     */
    override fun onNewIntent(
        intent: Intent
    ) {
        super.onNewIntent(intent)

        setIntent(intent)

        fullScreenIntentHandler.handleIntent(
            intent
        )
    }

    /**
     * Configures the Flutter engine and registers the native
     * [MethodChannel] used by the Flutter application.
     *
     * The method channel acts as the entry point for Flutter requests
     * involving Android alarms, notifications, and full-screen intent
     * functionality.
     *
     * @param flutterEngine Flutter engine being configured.
     */
    override fun configureFlutterEngine(
        flutterEngine: FlutterEngine
    ) {
        super.configureFlutterEngine(flutterEngine)

        val channel = MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            CHANNEL
        )

        fullScreenIntentHandler.setFlutterEngine(
            flutterEngine
        )

        channel.setMethodCallHandler { call, result ->

            when (call.method) {

                "flutterReady" -> {
                    fullScreenIntentHandler
                        .markFlutterReady()
                    result.success(null)
                }

                "canUseFullScreenIntent" -> {
                    result.success(
                        fullScreenIntentHandler
                            .canUseFullScreenIntent()
                    )
                }

                "openFullScreenIntentSettings" -> {
                    fullScreenIntentHandler
                        .openSettings()

                    result.success(null)
                }

                "scheduleAlarm" -> {
                    val alarmId =
                        call.argument<Int>("alarmId")

                    val triggerAt =
                        call.argument<Long>("triggerAt")

                    if (
                        alarmId == null ||
                        triggerAt == null
                    ) {
                        result.error(
                            "INVALID_ARGUMENTS",
                            "alarmId and triggerAt are required",
                            null
                        )
                        return@setMethodCallHandler
                    }

                    try {
                        alarmManagerHelper.schedule(
                            alarmId,
                            triggerAt
                        )

                        result.success(null)

                    } catch (e: SecurityException) {
                        result.error(
                            "EXACT_ALARM_PERMISSION",
                            e.message,
                            null
                        )
                    }
                }

                "cancelAlarm" -> {
                    val alarmId =
                        call.argument<Int>("alarmId")

                    if (alarmId == null) {
                        result.error(
                            "INVALID_ARGUMENTS",
                            "alarmId is required",
                            null
                        )
                        return@setMethodCallHandler
                    }

                    alarmManagerHelper.cancel(
                        alarmId
                    )

                    result.success(null)
                }

                "launchNotification" -> {
                    try {
                        notificationSender.send(
                            call.arguments
                        )

                        result.success(null)

                    } catch (e: Exception) {
                        result.error(
                            "NOTIFICATION_ERROR",
                            e.message,
                            null
                        )
                    }
                }

                else -> {
                    result.notImplemented()
                }
            }
        }
    }
}
