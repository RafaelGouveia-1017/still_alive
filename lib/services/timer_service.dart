import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:bcrypt/bcrypt.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:still_alive/data/all.dart';
import 'package:still_alive/services/history_service.dart';
import 'package:still_alive/services/native/method_channel.dart';
import 'package:still_alive/services/notification_service_android.dart';
import 'package:still_alive/src/rust/api/data/db.dart';
import 'package:still_alive/src/rust/api/timer/active_timer.dart';
import 'package:still_alive/src/rust/api/timer/state.dart';
import 'package:still_alive/views/app/home/timer/emergency_active.dart';
import 'package:still_alive/views/app/home/timer/pre_alert_warning.dart';
import 'package:still_alive/views/widgets/primitives.dart';

/// Provides convenience methods for working with an [ActiveTimer].
extension ActiveTimerExtension on ActiveTimer {
  /// Returns the amount of time remaining before the active timer run expires.
  ///
  /// The expiration timestamp is interpreted as a UTC timestamp. If the
  /// expiration time has already passed, [Duration.zero] is returned instead
  /// of a negative duration.
  Duration remaining() {
    final now = DateTime.now().toUtc();
    final expiresAt = DateTime.fromMillisecondsSinceEpoch(
      run.expiresAtMs,
      isUtc: true,
    ).add(Duration(seconds: 1));

    final difference = expiresAt.difference(now);
    if (difference.isNegative) {
      return Duration.zero;
    }

    return difference;
  }
}

/// Manages the application's active timer and coordinates timer state,
/// native alarms, notifications, and timer history.
///
/// [TimerService] is implemented as a singleton and should be accessed through
/// [TimerService.instance].
class TimerService extends ChangeNotifier {
  /// Creates the singleton [TimerService] instance.
  ///
  /// This constructor is private to prevent creating additional instances.
  TimerService._();

  /// The singleton instance of [TimerService].
  static final TimerService instance = TimerService._();

  late ActiveTimer _activeTimer;

  bool _initialized = false;

  /// The currently configured active timer.
  ///
  /// [initialize] must be called before accessing this property.
  ActiveTimer get activeTimer {
    if (!_initialized) {
      throw StateError('TimerService has not been initialized.');
    }

    return _activeTimer;
  }

  /// Whether the current active timer has an active timer run.
  Future<bool> get hasActiveTimer => _activeTimer.run.isActive();

  /// Initializes the singleton timer service and reconciles the persisted
  /// active timer state.
  ///
  /// This should be called during application initialization before using
  /// [activeTimer] or handling native timer callbacks.
  static Future<void> initialize() async => await instance.reconcile();

  /// Reconciles the persisted active timer state with the current time.
  ///
  /// If an active timer can be restored, it is stored as the current
  /// [activeTimer] and listeners are notified of the updated state.
  Future<void> reconcile() async {
    final now = DateTime.now().toUtc().millisecondsSinceEpoch;

    ActiveTimer? result = await reconcileActiveTimer(nowMs: now);
    if (result == null) return;
    _activeTimer = result;

    _initialized = true;

    notifyListeners();
  }

  /// Starts a new timer run for the active timer.
  ///
  /// Schedules a native alarm for the timer's expiration time, notifies
  /// listeners of the state change, and records the timer start in history.
  Future<void> startTimer() async {
    final now = DateTime.now().toUtc().millisecondsSinceEpoch;

    await _activeTimer.startTimerRun(nowMs: now);

    await _scheduleAlarm(
      alarmId: _activeTimer.key,
      triggerAt: _activeTimer.run.expiresAtMs,
    );

    launchTimerNotification();
    notifyListeners();

    HistoryService.insertHistoryRecord(
      TimerStartedEvent(
        timerName: _activeTimer.config.name,
        startedAt: DateTime.fromMillisecondsSinceEpoch(
          _activeTimer.run.startedAtMs,
          isUtc: true,
        ),
        endedAt: null,
        durationSeconds: _activeTimer.config.durationSecs,
        gracePeriodSeconds: _activeTimer.config.gracePeriodSecs,
        passwordProtected: _activeTimer.config.passwordProtected,
      ),
    );
  }

  /// Pauses the currently active timer run.
  ///
  /// Cancels the scheduled native alarm, notifies listeners, and records the
  /// pause event in timer history.
  ///
  /// The [passwordVerified] value indicates whether any required password
  /// verification was successfully completed before pausing the timer.
  Future<void> pauseTimer({required bool passwordVerified}) async {
    final now = DateTime.now().toUtc().millisecondsSinceEpoch;
    await _activeTimer.pauseTimerRun(
      nowMs: now,
      passwordVerified: passwordVerified,
    );

    await _cancelAlarm(alarmId: _activeTimer.key);

    launchTimerNotification();
    notifyListeners();

    HistoryService.insertHistoryRecord(
      TimerPausedEvent(
        timerName: _activeTimer.config.name,
        startedAt: DateTime.fromMillisecondsSinceEpoch(
          _activeTimer.run.startedAtMs,
          isUtc: true,
        ),
        endedAt: DateTime.fromMillisecondsSinceEpoch(now, isUtc: true),
        remainingSeconds: _activeTimer.remaining().inSeconds,
      ),
    );
  }

  /// Resumes the currently paused timer run.
  ///
  /// Schedules a new native alarm for the timer's expiration time and notifies
  /// listeners of the state change.
  Future<void> resumeTimer() async {
    final now = DateTime.now().toUtc().millisecondsSinceEpoch;

    await _activeTimer.resumeTimerRun(nowMs: now);

    await _scheduleAlarm(
      alarmId: _activeTimer.key,
      triggerAt: _activeTimer.run.expiresAtMs,
    );

    notifyListeners();
  }

  /// Cancels the currently active timer run.
  ///
  /// Cancels the scheduled native alarm, notifies listeners, and records the
  /// cancellation in timer history.
  ///
  /// The [passwordVerified] value indicates whether any required password
  /// verification was successfully completed before cancelling the timer.
  Future<void> cancelTimer({required bool passwordVerified}) async {
    final now = DateTime.now().toUtc().millisecondsSinceEpoch;
    await _activeTimer.cancelTimerRun(
      nowMs: now,
      passwordVerified: passwordVerified,
    );

    if (_activeTimer.run.state == TimerState.cancelled) {
      await _cancelAlarm(alarmId: _activeTimer.key);
    }

    launchTimerNotification();
    notifyListeners();

    HistoryService.insertHistoryRecord(
      TimerCancelledEvent(
        timerName: _activeTimer.config.name,
        startedAt: DateTime.fromMillisecondsSinceEpoch(
          _activeTimer.run.startedAtMs,
          isUtc: true,
        ),
        endedAt: DateTime.fromMillisecondsSinceEpoch(now, isUtc: true),
        remainingSeconds: _activeTimer.remaining().inSeconds,
        passwordVerified: passwordVerified,
      ),
    );
  }

  /// Handles method calls received from the native platform.
  ///
  /// When the native platform reports that the alarm has fired through the
  /// alarmFired method, this method updates the active timer's run state by
  /// calling [timerHasExpired].
  ///
  /// This method does nothing if [TimerService] has not been initialized yet.
  ///
  /// The [call] contains the method name and arguments supplied by the native
  /// platform. For an alarmFired call, the arguments are expected to contain
  /// an integer alarmId.
  ///
  /// Requires [initialize] to have been called successfully so that the active
  /// timer is available.
  ///
  /// This method is intended to be used as the callback for native platform
  /// method-channel calls.
  Future<void> handleNativeCall(MethodCall call) async {
    AppLogger.log.info("TimerService.handleNativeCall() called...");

    if (!_initialized) {
      AppLogger.log.severe(
        "Alarm received before TimerService initialization.",
      );
      return;
    }

    if (call.method == 'alarmFired') {
      final args = Map<String, dynamic>.from(call.arguments);
      final alarmId = args['alarmId'] as int;
      AppLogger.log.info("User has app opened and alarm has fired: $alarmId");

      timerHasExpired();
    }
  }

  /// Updates the active timer's run state after its native alarm has fired and
  /// navigates to the appropriate timer screen.
  ///
  /// If the active timer is already in [TimerState.warning] or
  /// [TimerState.expired], no further action is taken.
  ///
  /// The timer's run state is recalculated using the current UTC timestamp.
  /// Once the state has been updated, a timer notification is launched and the
  /// appropriate screen is displayed:
  ///
  /// * [TimerState.warning] navigates to [PreAlertWarningScreen] and records a
  /// [TimerWarningEvent] in the timer history.
  /// * [TimerState.expired] navigates to [EmergencyActiveScreen].
  /// * Any other state results in no navigation.
  ///
  /// This method requires a mounted application navigator. If
  /// [PermissionManager.instance.navigatorKey.currentState] is not yet
  /// available, this method waits until a navigator becomes available before
  /// continuing.
  ///
  /// The navigation stack is cleared before displaying the warning or emergency
  /// screen, ensuring that the timer state is presented as the active screen.
  ///
  /// This method should be called after the native platform reports that the
  /// timer alarm has fired.
  Future<void> timerHasExpired() async {
    if (_activeTimer.run.state == TimerState.expired ||
        _activeTimer.run.state == TimerState.warning) {
      AppLogger.log.info(
        "timerHasExpired() called, but timer is already expired.",
      );
      return;
    }

    final now = DateTime.now().toUtc().millisecondsSinceEpoch;
    _activeTimer.updateRunState(nowMs: now);

    NavigatorState? navigator =
        PermissionManager.instance.navigatorKey.currentState;

    while (navigator == null) {
      AppLogger.log.warning("Navigator not ready to handle timer expiration.");
      await Future.delayed(const Duration(seconds: 2));
      navigator = PermissionManager.instance.navigatorKey.currentState;
    }

    launchTimerNotification();

    switch (_activeTimer.run.state) {
      case TimerState.warning:
        HistoryService.insertHistoryRecord(
          TimerWarningEvent(
            timerName: _activeTimer.config.name,
            startedAt: DateTime.fromMillisecondsSinceEpoch(
              _activeTimer.run.startedAtMs,
              isUtc: true,
            ),
            endedAt: DateTime.fromMillisecondsSinceEpoch(
              _activeTimer.run.expiresAtMs,
              isUtc: true,
            ),
            remainingSeconds: _activeTimer.config.gracePeriodSecs!,
          ),
        );

        AppLogger.log.info("\n\ntimer state change: running -> warning\n\n");

        navigator.pushAndRemoveUntil(
          AppRoute(
            page: PreAlertWarningScreen(),
            transition: AppRouteTransitionType.slideLeft,
          ),
          (route) => false,
        );
        break;

      case TimerState.expired:
        AppLogger.log.info("\n\ntimer state change: running -> expired\n\n");

        navigator.pushAndRemoveUntil(
          AppRoute(
            page: EmergencyActiveScreen(),
            transition: AppRouteTransitionType.slideLeft,
          ),
          (route) => false,
        );
        break;

      default:
        // Nothing to do.
        break;
    }
  }

  /// Schedules a native alarm for the specified Unix timestamp.
  ///
  /// The timestamp is represented as milliseconds since the Unix epoch, which
  /// makes the trigger time independent of the device's local time zone.
  ///
  /// The [alarmId] identifies the alarm associated with the timer.
  /// The [triggerAt] specifies when the alarm should fire, in milliseconds
  /// since the Unix epoch.
  Future<void> _scheduleAlarm({
    required String alarmId,
    required int triggerAt,
  }) async {
    await AppMethodChannel.instance.invokeMethod('scheduleAlarm', {
      'alarmId': alarmId.hashCode,
      'triggerAt': triggerAt,
    });
  }

  /// Cancels a previously scheduled native alarm.
  ///
  /// The [alarmId] identifies the alarm associated with the timer.
  Future<void> _cancelAlarm({required String alarmId}) async {
    await AppMethodChannel.instance.invokeMethod('cancelAlarm', {
      'alarmId': alarmId.hashCode,
    });
  }

  /// Launches a notification reflecting the current state of the active timer.
  ///
  /// Builds and displays a localized notification based on the
  /// current [TimerState]. The notification's description, type, priority,
  /// sound, and vibration behavior are adjusted according to the timer state.
  ///
  /// This method requires a mounted application [BuildContext] to resolve
  /// [AppLocalizations]. If the navigator context is not yet available or
  /// mounted, this method waits until a valid context becomes available.
  void launchTimerNotification() {
    final context = PermissionManager.instance.navigatorKey.currentContext;

    if (context == null || !context.mounted) {
      AppLogger.log.warning(
        "Cannot launch timer notification: navigator context unavailable.",
      );
      return;
    }

    AppLocalizations local = AppLocalizations.of(context)!;

    if (Platform.isAndroid) {
      String title = local.translate("notifications.timer.title");
      String description = '';
      NotificationType type = NotificationType.silent;
      NotificationPriority priority = NotificationPriority.defaultPriority;
      bool playSound = false;
      bool vibrate = false;

      String timerName = _activeTimer.config.name;

      switch (_activeTimer.run.state) {
        case TimerState.cancelled:
          description =
              '"$timerName" '
              '${local.translate("notifications.timer.cancelled")}';
          priority = NotificationPriority.high;
          vibrate = true;
          break;
        case TimerState.completed:
          description =
              '${local.translate("notifications.timer.completed.0")}'
              ' "$timerName" '
              '${local.translate("notifications.timer.completed.1")}';
          break;
        case TimerState.paused:
          description =
              '"$timerName" '
              '${local.translate("notifications.timer.paused")}';
          vibrate = true;
          break;
        case TimerState.warning:
          description =
              '${local.translate("notifications.timer.warning.0")}'
              ' "$timerName" '
              '${local.translate("notifications.timer.warning.1")}';
          priority = NotificationPriority.high;
          break;
        case TimerState.expired:
          description =
              '${local.translate("notifications.timer.expired.0")}'
              ' "$timerName" '
              '${local.translate("notifications.timer.expired.1")}';
          priority = NotificationPriority.max;
          vibrate = true;
          break;
        case TimerState.running:
          description =
              '${local.translate("notifications.timer.running.0")}'
              ' "$timerName" '
              '${local.translate("notifications.timer.running.1")}';
          break;
      }

      AndroidNotificationService.launchNotification(
        title: title,
        description: description,
        type: type,
        priority: priority,
        category: 'timer',
        playSound: playSound,
        vibrate: vibrate,
      );
    }
  }

  /// Displays a password prompt for the currently active timer.
  ///
  /// The prompt allows the user to enter their password and verifies it
  /// against the BCrypt password hash configured for the active timer.
  ///
  /// Returns a [Future] that completes with:
  ///
  /// - `true` if the entered password matches the configured password.
  /// - `false` if the entered password does not match.
  /// - `null` if the prompt is dismissed without submitting a password.
  ///
  /// The supplied [context] is used to display the password prompt and
  /// retrieve the current theme and localized strings.
  ///
  /// The returned [Future] should be awaited when the caller needs to
  /// determine whether password verification succeeded.
  Future<bool?> showPasswordPrompt(BuildContext context) async {
    ColorScheme scheme = Theme.of(context).colorScheme;
    AppLocalizations local = AppLocalizations.of(context)!;

    final TextEditingController passController = TextEditingController();
    final FocusNode passFocus = FocusNode();

    return showBlurredBottomSheet<bool>(
      context: context,
      scheme: scheme,
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: passController,
              focusNode: passFocus,
              keyboardType: TextInputType.text,
              maxLength: 250,
              style: AppText.body(scheme),
              inputFormatters: [
                FilteringTextInputFormatter.singleLineFormatter,
              ],
              decoration: InputDecoration(
                hintText: local.translate("home.password_hint"),
                counterText: '',
                border: InputBorder.none,
              ),
              obscureText: true,
              onTap: () {
                passController.selection = TextSelection(
                  baseOffset: 0,
                  extentOffset: passController.text.length,
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
            child: PrimaryButton(
              icon: LucideIcons.keySquare,
              onPressed: () async {
                bool result = verifyPassword(
                  passController.text,
                  _activeTimer.config.passwordHash!,
                );
                Navigator.of(context).pop(result);
                passController.dispose();
                passFocus.dispose();
              },
            ),
          ),
        ],
      ),
    );
  }

  /// Generates a BCrypt hash for the supplied [password].
  ///
  /// A new salt is generated for each password hash.
  static String generatePasswordHash(String password) {
    return BCrypt.hashpw(password, BCrypt.gensalt());
  }

  /// Verifies a plaintext [password] against a stored BCrypt [passwordHash].
  ///
  /// Returns `true` when the password matches the hash and `false` otherwise.
  static bool verifyPassword(String password, String passwordHash) {
    return BCrypt.checkpw(password, passwordHash);
  }

  Future<void> triggerEmergency() async {
    //TODO trigger emergency protocols (send messages & stuff)

    //TODO when sending, create a list of unique emails (combine contact emails & custom emails) and a list of unique phone numbers (combine contact numbers & custom numbers)

    HistoryService.insertHistoryRecord(
      TimerExpiredEvent(
        timerName: _activeTimer.config.name,
        startedAt: DateTime.now(),
        endedAt: DateTime.now(),
        location: {},
        polyline: '',
        sms: [],
        emails: [],
        channels: [],
        alarmTriggered: false,
        audioRecorded: false,
      ),
    );
  }

  /// Formats a [Duration] into a compact human-readable string.
  ///
  /// Zero-valued time units are omitted. For example, a duration of
  /// `1 hour, 5 minutes, and 30 seconds` is formatted as `01h 05m 30s`,
  /// while a duration of `30 seconds` is formatted as `30s`.
  ///
  /// Returns `0s` when the duration is zero.
  static String formatDuration(Duration duration) {
    final parts = <String>[];

    final hours = duration.inHours;
    final minutes = duration.inMinutes % 60;
    final seconds = duration.inSeconds % 60;

    if (hours > 0) {
      parts.add('${hours.toString().padLeft(2, '0')}h');
    }

    if (minutes > 0) {
      parts.add('${minutes.toString().padLeft(2, '0')}m');
    }

    if (seconds > 0) {
      parts.add('${seconds.toString().padLeft(2, '0')}s');
    }

    if (parts.isEmpty) {
      return '0s';
    }

    return parts.join(' ');
  }

  /// Removes [contactID] from the contacts list of every timer.
  ///
  /// If [contactID] exists in a timer's `contacts` array, that contact object
  /// is removed. Timers that don't contain the contact are left unchanged.
  Future<void> removeDeletedContactFromTimers(String contactID) async {
    await executeBatchSql(
      sql:
          """
          UPDATE timers
          SET value = json_set(
              value,
              '\$.contacts',
              COALESCE(
                  (
                      SELECT json_group_array(contact.value)
                      FROM json_each(timers.value, '\$.contacts') AS contact
                      WHERE json_extract(contact.value, '\$.id') <> '$contactID'
                  ),
                  json('[]')
              )
          )
          WHERE EXISTS (
              SELECT 1
              FROM json_each(timers.value, '\$.contacts') AS contact
              WHERE json_extract(contact.value, '\$.id') = '$contactID'
          );
          """,
    );

    _activeTimer.config.contacts.removeWhere(
      (contact) => contact.id == contactID,
    );
  }

  /// Removes deleted destinations from an account in the active timer's
  /// integration configuration.
  ///
  /// The account is identified by [accountID] and its current destinations are
  /// retrieved from the integration identified by [integrationKey]. Any
  /// destinations configured on the active timer that are no longer present in
  /// the integration account are removed. Other destinations remain unchanged.
  ///
  /// This is used to keep the active timer configuration in sync when a
  /// destination is deleted from an external integration.
  ///
  /// Throws an [Exception] if [integrationKey] is not a supported integration.
  Future<void> removeDeletedAccountDestinationFromTimers(
    String integrationKey,
    String accountID,
  ) async {
    final result = await select(
      sql:
          '''
          SELECT json_extract(destination.value, '\$.id') AS destination_id
          FROM integrations
          JOIN json_each(integrations.value, '\$.accounts') AS account
          JOIN json_each(account.value, '\$.destinations') AS destination
          WHERE integrations.key = '$integrationKey'
            AND json_extract(account.value, '\$.id') = '$accountID'
          ''',
    );

    final rows = jsonDecode(result) as List<dynamic>;

    final destinations = rows
        .map((row) => row['destination_id'] as String)
        .toList();

    final activeIntegration = switch (integrationKey) {
      'discord' => _activeTimer.config.integrations.discord,
      'telegram' => _activeTimer.config.integrations.telegram,
      _ => throw Exception("somehow there's an unknown integration key here"),
    };

    activeIntegration.accounts
        .firstWhere((account) => account.id == accountID)
        .destinations
        .removeWhere((destination) => !destinations.contains(destination));
  }

  /// Removes an account from the active timer's integration configuration.
  ///
  /// The account is identified by [accountID] and removed from the integration
  /// identified by [integrationKey]. Any other accounts configured for the
  /// integration remain unchanged.
  ///
  /// This is used to keep the active timer configuration in sync when an
  /// account is deleted from an external integration.
  ///
  /// Throws an [Exception] if [integrationKey] is not a supported integration.
  Future<void> removeDeletedIntegrationAccountFromTimers(
    String integrationKey,
    String accountID,
  ) async {
    final activeIntegration = switch (integrationKey) {
      'discord' => _activeTimer.config.integrations.discord,
      'telegram' => _activeTimer.config.integrations.telegram,
      _ => throw Exception("somehow there's an unknown integration key here"),
    };

    activeIntegration.accounts.removeWhere(
      (account) => account.id == accountID,
    );
  }
}
