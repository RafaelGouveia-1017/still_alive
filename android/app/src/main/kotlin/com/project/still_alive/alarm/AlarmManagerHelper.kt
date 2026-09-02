package com.appsbyrafa.stillalive

import android.app.AlarmManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.os.Build

/**
 * Provides the native Android implementation for scheduling and cancelling
 * application alarms.
 *
 * This class encapsulates all interaction with Android's [AlarmManager].
 * It deliberately contains no Flutter or notification-specific logic.
 *
 * Alarms are scheduled using [AlarmManager.setAlarmClock], which is intended
 * for user-visible alarm-clock functionality and provides Android with
 * information about the application's next alarm.
 *
 * When an alarm fires, Android delivers the associated [PendingIntent] to
 * [AlarmReceiver].
 *
 * ```
 * Flutter
 *     ↓
 * MainActivity
 *     ↓
 * AlarmManagerHelper
 *     ↓
 * AlarmManager
 *     ↓
 * AlarmReceiver
 * ```
 *
 * @param context Android context used to access [AlarmManager] and create
 * alarm PendingIntents.
 */
class AlarmManagerHelper(
    private val context: Context
) {

    private val alarmManager =
        context.getSystemService(
            Context.ALARM_SERVICE
        ) as AlarmManager

    /**
     * Schedules an exact, user-visible alarm.
     *
     * The alarm is represented by two PendingIntents:
     *
     * 1. An alarm PendingIntent delivered to [AlarmReceiver] when the alarm
     *    fires.
     * 2. A show PendingIntent used by Android for the alarm-clock UI and
     *    associated "next alarm" functionality.
     *
     * On Android 12 (API 31) and later, exact alarm scheduling may require
     * the `SCHEDULE_EXACT_ALARM` permission. If the application does not
     * currently have permission, this method throws [SecurityException].
     *
     * @param alarmId Unique identifier of the alarm. The identifier is used
     * as the PendingIntent request code so that the alarm can later be
     * cancelled using the same identity.
     * @param triggerAt Alarm trigger time represented as milliseconds since
     * the Unix epoch.
     *
     * @throws SecurityException if exact alarm scheduling is not permitted.
     */
    fun schedule(
        alarmId: Int,
        triggerAt: Long
    ) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            if (!alarmManager.canScheduleExactAlarms()) {
                throw SecurityException(
                    "SCHEDULE_EXACT_ALARM permission not granted"
                )
            }
        }

        val alarmIntent = Intent(
            context,
            AlarmReceiver::class.java
        ).apply {
            putExtra(
                AlarmReceiver.EXTRA_ALARM_ID,
                alarmId
            )
        }

        val alarmPendingIntent =
            PendingIntent.getBroadcast(
                context,
                alarmId,
                alarmIntent,
                PendingIntent.FLAG_UPDATE_CURRENT or
                PendingIntent.FLAG_IMMUTABLE
            )

        val showIntent = Intent(
            context,
            MainActivity::class.java
        ).apply {
            flags =
                Intent.FLAG_ACTIVITY_NEW_TASK or
                Intent.FLAG_ACTIVITY_CLEAR_TOP

            putExtra(
                AlarmReceiver.EXTRA_ALARM_ID,
                alarmId
            )
        }

        val showPendingIntent =
            PendingIntent.getActivity(
                context,
                alarmId + 100000,
                showIntent,
                PendingIntent.FLAG_UPDATE_CURRENT or
                PendingIntent.FLAG_IMMUTABLE
            )

        val alarmClockInfo =
            AlarmManager.AlarmClockInfo(
                triggerAt,
                showPendingIntent
            )

        alarmManager.setAlarmClock(
            alarmClockInfo,
            alarmPendingIntent
        )
    }

    /**
     * Cancels a previously scheduled alarm.
     *
     * The same PendingIntent identity used when scheduling the alarm is
     * recreated so that [AlarmManager] can identify the corresponding
     * scheduled alarm.
     *
     * Cancelling the PendingIntent itself after removing the alarm ensures
     * that the PendingIntent is no longer retained by the application.
     *
     * @param alarmId Unique identifier of the alarm to cancel.
     */
    fun cancel(
        alarmId: Int
    ) {
        val intent = Intent(
            context,
            AlarmReceiver::class.java
        )

        val pendingIntent =
            PendingIntent.getBroadcast(
                context,
                alarmId,
                intent,
                PendingIntent.FLAG_UPDATE_CURRENT or
                PendingIntent.FLAG_IMMUTABLE
            )

        alarmManager.cancel(
            pendingIntent
        )

        pendingIntent.cancel()
    }
}
