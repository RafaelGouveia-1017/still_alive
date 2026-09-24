package com.appsbyrafa.stillalive

import android.content.Context
import android.content.res.Configuration
import java.util.Locale

/**
 * Provides locale-related utilities shared by the native Android
 * implementation of the StillAlive application.
 *
 * This object is responsible for maintaining access to the language
 * selected by Flutter and for creating Android [Context] instances whose
 * resources are explicitly configured for that language.
 * 
 * The selected language is persisted using [android.content.SharedPreferences]
 * so that native Android components that execute independently of Flutter,
 * such as [AlarmReceiver], can determine the application's language even
 * when the Flutter engine is not running.
 * 
 * This is particularly important for alarm notifications. An alarm may be
 * delivered by Android after the application process has been stopped or
 * killed. In that situation, the [Context] supplied to [AlarmReceiver] may
 * use the device's default locale rather than the locale previously selected
 * by Flutter. [localizedContext] creates a context configured explicitly
 * with the persisted application language so that calls such as
 * `context.getString(R.string.alarm_notification_text)` resolve to the
 * correct localized Android resource.
 * 
 * The object contains only stateless utility functions. The actual language
 * value is persisted in [android.content.SharedPreferences] rather than
 * being held in memory, allowing the value to remain available to
 * background Android components.
*/
object LocaleHelper {

    private const val PREFS_NAME = "still_alive"
    private const val LANGUAGE_KEY = "language_code"

    /**
    * Retrieves the language code currently selected by the application.
    * 
    * The language code is read from the application's private
    * [android.content.SharedPreferences] storage. If no language has been
    * explicitly selected, English (`en`) is used as the default.
    * 
    * This method can safely be called by Android components that are
    * running independently of Flutter, including [AlarmReceiver].
    * 
    * @param context Android context used to access the application's
    * shared preferences.
    * 
    * @return The persisted ISO language code, such as `en` or `pt`.
    */
    fun getLanguageCode(
        context: Context
    ): String {
        return context
            .getSharedPreferences(
                PREFS_NAME,
                Context.MODE_PRIVATE
            )
            .getString(
                LANGUAGE_KEY,
                "en"
            ) ?: "en"
    }

    /**
    * Persists the language selected by Flutter for use by native Android
    * components.
    *
    * The value is stored in private application [android.content.SharedPreferences]
    * under the same storage keys used by [LocaleHelper]. This allows
    * background components such as [AlarmReceiver] to determine the
    * application's language without requiring the Flutter engine to be
    * running.
    *
    * The persisted language is later read by [getLanguageCode]
    * when a localized Android [Context] is required.
    *
    * @param context Android context used to access application preferences.
    * @param languageCode ISO language code selected by Flutter, such as
    * `en` or `pt`.
    */
    fun saveLanguage(
        context: Context,
        languageCode: String
    ) {
        context
            .getSharedPreferences(
                PREFS_NAME,
                Context.MODE_PRIVATE
            )
            .edit()
            .putString(
                LANGUAGE_KEY,
                languageCode
            )
            .apply()
    }

    /**
    * Creates a [Context] configured with the application's selected locale.
    * 
    * Android components such as [AlarmReceiver] may receive a context whose
    * configuration reflects the device locale rather than the language
    * selected inside Flutter. This method creates a new configuration
    * context with the language persisted by [getLanguageCode].
    * 
    * The returned context should be used whenever localized Android
    * resources need to be resolved by a background component.
    * 
    * For example:
    * ```
    * val localizedContext = LocaleHelper.localizedContext(context)
    *
    * localizedContext.getString(
    *    R.string.alarm_notification_text
    * )
    * ```
    * 
    * This allows Android's resource system to automatically select the
    * appropriate resource directory, such as values/ or values-pt/.
    * 
    * @param context Base Android context from which resources and
    * application configuration are obtained.
    * 
    * @return A new context whose resources are configured for the
    * application's persisted language.
    */
    fun localizedContext(
        context: Context
    ): Context {
        val languageCode =
            getLanguageCode(context)

        val locale =
            Locale.forLanguageTag(languageCode)

        Locale.setDefault(locale)

        val configuration =
            Configuration(
                context.resources.configuration
            )

        configuration.setLocale(locale)

        return context.createConfigurationContext(
            configuration
        )
    }
}
