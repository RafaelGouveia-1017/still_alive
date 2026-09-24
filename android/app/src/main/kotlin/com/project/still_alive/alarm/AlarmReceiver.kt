package com.appsbyrafa.stillalive

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent

/**
 * Broadcast receiver responsible for handling alarms delivered by
 * Android's [android.app.AlarmManager].
 *
 * Android invokes [onReceive] when a scheduled alarm reaches its trigger
 * time. The receiver extracts the alarm identifier and delegates the
 * resulting notification to [NotificationSender].
 *
 * The receiver intentionally does not contain alarm scheduling logic.
 * Scheduling and cancellation are handled by [AlarmManagerHelper].
 *
 * It also does not communicate directly with Flutter. Flutter communication
 * is handled later by [FullScreenIntentHandler] when [MainActivity] is
 * launched by the full-screen notification.
 *
 * ```
 * AlarmManager
 *      ↓
 * AlarmReceiver
 *      ↓
 * NotificationSender
 *      ↓
 * Full-screen notification
 *      ↓
 * MainActivity
 *      ↓
 * FullScreenIntentHandler
 *      ↓
 * Flutter
 * ```
 */
class AlarmReceiver : BroadcastReceiver() {

    companion object {
        /**
         * Intent extra containing the unique identifier of the alarm that
         * triggered the receiver.
         */
        const val EXTRA_ALARM_ID = "alarm_id"
    }

    /**
     * Called by Android when a scheduled alarm is delivered.
     *
     * The method retrieves the alarm identifier from the incoming Intent.
     * If a valid identifier is present, an alarm notification is created
     * using [NotificationSender].
     *
     * @param context Context supplied by Android for the receiver.
     * @param intent Intent containing the alarm identifier.
     */
    override fun onReceive(
        context: Context,
        intent: Intent
    ) {
        val alarmId =
            intent.getIntExtra(
                EXTRA_ALARM_ID,
                -1
            )

        if (alarmId == -1) {
            return
        }

        val localizedContext =
            LocaleHelper.localizedContext(
                context
            )

        val notificationSender =
            NotificationSender(
                localizedContext
            )

        notificationSender.sendAlarm(
            alarmId
        )
    }
}
