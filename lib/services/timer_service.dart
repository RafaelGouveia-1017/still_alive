import 'dart:io';
import 'dart:convert';
import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:bcrypt/bcrypt.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:latlong2/latlong.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:still_alive/data/all.dart';
import 'package:still_alive/services/location_service.dart';
import 'package:still_alive/services/history_service.dart';
import 'package:still_alive/services/native/method_channel.dart';
import 'package:still_alive/services/notification_service_android.dart';
import 'package:still_alive/src/rust/api/data/db.dart';
import 'package:still_alive/src/rust/api/timer/active_timer.dart';
import 'package:still_alive/src/rust/api/timer/state.dart';
import 'package:still_alive/src/rust/api/timer/config.dart';
import 'package:still_alive/views/app/screens.dart';
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
    final expiresAt = DateTime.fromMillisecondsSinceEpoch(run.expiresAtMs, isUtc: true).add(Duration(seconds: 1));

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

  /// Object containing the currently active timer.
  late ActiveTimer _activeTimer;

  /// Indicates whether [TimerService] has initialized or not.
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

  /// Gets the current state in the timer run.
  TimerState get timerRunCurrentState => _activeTimer.run.state;

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
  ///
  /// When the restored timer requires continuous route sharing, the persisted
  /// GPS recording state is also restored. This allows route collection to
  /// continue after the Flutter process has been recreated while the timer
  /// remains active.
  Future<void> reconcile() async {
    final now = DateTime.now().toUtc().millisecondsSinceEpoch;

    ActiveTimer? result = await reconcileActiveTimer(nowMs: now);
    if (result == null) return;
    _activeTimer = result;

    _initialized = true;

    if (_activeTimer.config.routeSharingEnabled && _activeTimer.run.state == TimerState.running) {
      try {
        await _startLocationRecordingIfRequired(resetRoute: false);
      } catch (e) {
        // Continuing without route tracking, because timer might already be running.
      }
    }

    notifyListeners();
  }

  /// Starts a new timer run for the active timer.
  ///
  /// Schedules a native alarm for the timer's expiration time, starts
  /// continuous GPS route recording when [TimerConfig.routeSharingEnabled] is
  /// enabled, notifies listeners of the state change, and records the timer
  /// start in history.
  ///
  /// When location sharing is enabled without route sharing, no continuous GPS
  /// recording is started. The current location is obtained only when the
  /// emergency is triggered.
  Future<void> startTimer() async {
    try {
      await _startLocationRecordingIfRequired(resetRoute: true);
    } catch (e) {
      return;
    }

    final now = DateTime.now().toUtc().millisecondsSinceEpoch;

    await _activeTimer.startTimerRun(nowMs: now);

    if (_activeTimer.key != "timer0") {
      await _scheduleAlarm(alarmId: _activeTimer.key, triggerAt: _activeTimer.run.expiresAtMs);
    }

    launchTimerNotification();
    notifyListeners();

    await HistoryService.insertHistoryRecord(
      TimerStartedEvent(
        timerName: _activeTimer.config.name,
        startedAt: DateTime.fromMillisecondsSinceEpoch(_activeTimer.run.startedAtMs),
        endedAt: null,
        durationSeconds: _activeTimer.config.durationSecs,
        gracePeriodSeconds: _activeTimer.config.gracePeriodSecs,
        passwordProtected: _activeTimer.config.passwordProtected,
      ),
    );
  }

  /// Pauses the currently active timer run.
  ///
  /// Cancels the scheduled native alarm and stops continuous GPS route
  /// recording. The persisted route is retained in the database so recording
  /// can continue from the same route when the timer is resumed.
  ///
  /// The [passwordVerified] value indicates whether any required password
  /// verification was successfully completed before pausing the timer.
  ///
  /// A timer configured for single-location sharing does not have an active GPS
  /// recording to stop.
  Future<void> pauseTimer({required bool passwordVerified}) async {
    final now = DateTime.now().toUtc().millisecondsSinceEpoch;

    await _activeTimer.pauseTimerRun(nowMs: now, passwordVerified: passwordVerified);

    await _cancelAlarm(alarmId: _activeTimer.key);

    await _stopLocationRecording();

    launchTimerNotification();
    notifyListeners();

    await HistoryService.insertHistoryRecord(
      TimerPausedEvent(
        timerName: _activeTimer.config.name,
        startedAt: DateTime.fromMillisecondsSinceEpoch(_activeTimer.run.startedAtMs),
        endedAt: DateTime.fromMillisecondsSinceEpoch(now),
        remainingSeconds: _activeTimer.remaining().inSeconds,
        passwordVerified: passwordVerified,
      ),
    );
  }

  /// Resumes the currently paused timer run.
  ///
  /// Schedules a new native alarm for the timer's expiration time and resumes
  /// continuous GPS route recording when route sharing is enabled.
  ///
  /// The existing persisted route is restored before recording resumes so new
  /// GPS points are appended to the existing route rather than creating a new
  /// route segment.
  ///
  /// When only single-location sharing is enabled, no location recording is
  /// started during resume.
  Future<void> resumeTimer() async {
    try {
      await _startLocationRecordingIfRequired(resetRoute: false);
    } catch (e) {
      return;
    }

    final now = DateTime.now().toUtc().millisecondsSinceEpoch;

    await _activeTimer.resumeTimerRun(nowMs: now);

    await _scheduleAlarm(alarmId: _activeTimer.key, triggerAt: _activeTimer.run.expiresAtMs);

    notifyListeners();
  }

  /// Cancels the currently active timer run.
  ///
  /// Cancels the scheduled native alarm and stops any active continuous GPS
  /// route recording. The persisted route is retained in the database so that
  /// it remains available for history or other application purposes.
  ///
  /// The [passwordVerified] value indicates whether any required password
  /// verification was successfully completed before cancelling the timer.
  ///
  /// The [recordHistory] value indicates whether a [TimerCancelledEvent]
  /// should be recorded or not.
  Future<void> cancelTimer({required bool passwordVerified, bool recordHistory = true}) async {
    final now = DateTime.now().toUtc().millisecondsSinceEpoch;

    await _activeTimer.cancelTimerRun(nowMs: now, passwordVerified: passwordVerified);

    if (_activeTimer.run.state == TimerState.cancelled) {
      await _cancelAlarm(alarmId: _activeTimer.key);
    }
    await _stopLocationRecording();

    launchTimerNotification();
    notifyListeners();

    if (recordHistory) {
      await HistoryService.insertHistoryRecord(
        TimerCancelledEvent(
          timerName: _activeTimer.config.name,
          startedAt: DateTime.fromMillisecondsSinceEpoch(_activeTimer.run.startedAtMs),
          endedAt: DateTime.fromMillisecondsSinceEpoch(now),
          remainingSeconds: _activeTimer.remaining().inSeconds,
          passwordVerified: passwordVerified,
        ),
      );
    }
  }

  /// Handles method calls received from the native platform.
  ///
  /// When the native platform reports that a scheduled timer alarm has fired
  /// through the `alarmFired` method, this method delegates timer expiration
  /// handling to [timerHasExpired].
  ///
  /// If the timer service has not been initialized, the native call is ignored
  /// because there is no active timer available to process the alarm.
  ///
  /// The [call] contains the method name and arguments supplied by the native
  /// platform through the method channel. For an `alarmFired` call, the
  /// arguments are expected to contain an integer `alarmId` identifying the
  /// native alarm that fired.
  ///
  /// The alarm ID is currently logged for diagnostic purposes. Timer expiration
  /// is handled by the active timer rather than by matching the received alarm
  /// ID against the timer key.
  ///
  /// This method is intended to be registered as the callback for native
  /// platform method-channel calls and requires [initialize] to have completed
  /// successfully before timer alarms can be processed.
  Future<void> handleNativeCall(MethodCall call) async {
    AppLogger.log.info("TimerService.handleNativeCall() called...");

    if (!_initialized) {
      AppLogger.log.severe("Alarm received before TimerService initialization.");
      return;
    }

    if (call.method == 'alarmFired') {
      final args = Map<String, dynamic>.from(call.arguments);
      final alarmId = args['alarmId'] as int;
      AppLogger.log.info("User has app opened and alarm has fired: $alarmId");

      timerHasExpired();
    }
  }

  /// Handles expiration of the active timer after its native alarm fires.
  ///
  /// The method first ignores the request when the active timer has already
  /// reached [TimerState.expired], preventing the expiration flow from being
  /// processed more than once.
  ///
  /// The application's navigator must be available because the expiration flow
  /// may replace the current navigation stack with either the pre-alert warning
  /// screen or the emergency screen. If no navigator is currently available,
  /// expiration handling is aborted and an error is logged.
  ///
  /// The timer identified by the special `timer0` key is handled separately by
  /// [_handleExampleTimer]. This timer is an example/demo timer and does not
  /// enter the normal warning or emergency flow.
  ///
  /// For normal timers, the current UTC timestamp is used to recalculate the
  /// active run state. A notification reflecting the resulting state is then
  /// launched.
  ///
  /// When the resulting state is [TimerState.warning], the warning run is
  /// started, a [TimerWarningEvent] is recorded in history, a new native alarm
  /// is scheduled for the end of the warning period, and
  /// [PreAlertWarningScreen] replaces the current navigation stack.
  ///
  /// When the resulting state is [TimerState.expired],
  /// [EmergencyActiveScreen] replaces the current navigation stack. The
  /// emergency screen is responsible for continuing the emergency flow.
  ///
  /// Any other resulting timer state does not trigger navigation.
  ///
  /// This method is normally called after the native platform reports that the
  /// scheduled timer alarm has fired, but it may also be called by other parts
  /// of the application that need to process the active timer's current
  /// expiration state.
  Future<void> timerHasExpired() async {
    if (_activeTimer.run.state == TimerState.expired) {
      AppLogger.log.info('timerHasExpired() called, but timer is already expired.');
      return;
    }

    NavigatorState? navigator = PermissionManager.instance.navigatorKey.currentState;
    if (navigator == null) {
      AppLogger.log.severe("Could not handle timer expiration because navigator was not ready.\nLiterally unplayable...");
      return;
    }

    if (_activeTimer.key == "timer0") {
      _handleExampleTimer();
      return;
    }

    final now = DateTime.now().toUtc().millisecondsSinceEpoch;
    _activeTimer.updateRunState(nowMs: now);

    launchTimerNotification();

    switch (_activeTimer.run.state) {
      case TimerState.warning:
        AppLogger.log.info("\n\ntimer state change: running -> warning\n");

        final now = DateTime.now().toUtc().millisecondsSinceEpoch;
        await _activeTimer.startWarningRun(nowMs: now);

        await HistoryService.insertHistoryRecord(
          TimerWarningEvent(
            timerName: _activeTimer.config.name,
            startedAt: DateTime.fromMillisecondsSinceEpoch(_activeTimer.run.startedAtMs),
            endedAt: DateTime.fromMillisecondsSinceEpoch(_activeTimer.run.expiresAtMs),
            remainingSeconds: _activeTimer.config.gracePeriodSecs!,
          ),
        );

        await _scheduleAlarm(alarmId: _activeTimer.key, triggerAt: _activeTimer.run.expiresAtMs);

        navigator.pushAndRemoveUntil(AppRoute(page: PreAlertWarningScreen(), transition: AppRouteTransitionType.slideLeft), (route) => false);

        break;

      case TimerState.expired:
        AppLogger.log.info("\n\ntimer state change: running (or warning) -> expired\n");

        navigator.pushAndRemoveUntil(AppRoute(page: EmergencyActiveScreen(), transition: AppRouteTransitionType.slideLeft), (route) => false);
        break;

      default:
        // Nothing to do.
        break;
    }
  }

  /// Handles expiration of the application's example/demo timer.
  ///
  /// The example timer does not enter the normal emergency flow. Instead, its
  /// active run is cancelled without password verification and the user is
  /// shown a localized informational toast explaining that the example timer
  /// has expired.
  ///
  /// The cancellation is performed through [cancelTimer] so that the native
  /// alarm and any timer-related state are cleaned up consistently with a
  /// normal timer cancellation.
  ///
  /// The current navigator context is required to resolve the application's
  /// theme and localized strings and to display the toast. If the context is
  /// unavailable, the timer is still cancelled but the informational message
  /// cannot be displayed.
  ///
  /// This method is intended only for the special timer identified by the
  /// `timer0` key and should not be used for normal emergency timers.
  void _handleExampleTimer() {
    AppLogger.log.info('timer0 expired, displaying info to user.');

    cancelTimer(passwordVerified: false);

    BuildContext? context = PermissionManager.instance.navigatorKey.currentContext;
    if (context == null) {
      AppLogger.log.severe("Could not handle timer expiration because context was not ready.\nLiterally unplayable...");
      return;
    }
    ColorScheme scheme = Theme.of(context).colorScheme;
    AppLocalizations local = AppLocalizations.of(context)!;

    showToast(
      scheme: scheme,
      toast: Text(local.translate("home.example_timer_message"), style: AppText.bodySm(scheme), textAlign: TextAlign.center),
      gravity: ToastGravity.TOP,
      position: (context, child, gravity) => Positioned(top: 250, left: 50, right: 50, child: child),
      secs: 10,
    );
  }

  /// Schedules a native alarm for the specified Unix timestamp.
  ///
  /// The timestamp is represented as milliseconds since the Unix epoch, which
  /// makes the trigger time independent of the device's local time zone.
  ///
  /// The [alarmId] identifies the alarm associated with the timer.
  /// The [triggerAt] specifies when the alarm should fire, in milliseconds
  /// since the Unix epoch.
  Future<void> _scheduleAlarm({required String alarmId, required int triggerAt}) async {
    await AppMethodChannel.instance.invokeMethod('scheduleAlarm', {'alarmId': alarmId.hashCode, 'triggerAt': triggerAt});
  }

  /// Cancels a previously scheduled native alarm.
  ///
  /// The [alarmId] identifies the alarm associated with the timer.
  Future<void> _cancelAlarm({required String alarmId}) async {
    await AppMethodChannel.instance.invokeMethod('cancelAlarm', {'alarmId': alarmId.hashCode});
  }

  /// Manually trigger a timer's expiration.
  ///
  /// Cancels the scheduled native alarm and sends the user straight to
  /// [EmergencyActiveScreen].
  Future<void> triggerTimerExpire() async {
    AppLogger.log.info("Triggering manual expiration of timer with key: ${_activeTimer.key}");

    final navigator = PermissionManager.instance.navigatorKey.currentState;
    if (navigator == null) {
      AppLogger.log.warning('Could not navigate to EmergencyActiveScreen because navigator was not ready.');
      return;
    }

    final now = DateTime.now().toUtc().millisecondsSinceEpoch;
    await _cancelAlarm(alarmId: _activeTimer.key);

    _activeTimer.triggerManualExpire(nowMs: now);

    launchTimerNotification();
    notifyListeners();

    navigator.pushAndRemoveUntil(AppRoute(page: EmergencyActiveScreen(), transition: AppRouteTransitionType.slideLeft), (route) => false);
  }

  /// Starts continuous GPS route recording when the active timer is configured
  /// to share a route. Can also restore continuous GPS route recording for a
  /// timer whose state survived application process recreation or was resumed
  /// after being paused. Start or Restore mode is defined by [resetRoute].
  ///
  /// Continuous location recording is controlled by
  /// [ActiveTimer.config.routeSharingEnabled]. Route sharing implicitly enables
  /// location collection.
  ///
  /// [ActiveTimer.config.locationSharingEnabled] without route sharing does not
  /// start a background recording. In that configuration, a single current
  /// location is obtained when the emergency is triggered instead.
  ///
  /// If restoring, the existing persisted route is restored before new GPS
  /// points are accepted so the route remains a single continuous polyline.
  ///
  /// This method does nothing when route sharing is disabled.
  ///
  /// Location permission or GPS availability failures are logged and do not
  /// prevent the timer itself from running.
  Future<void> _startLocationRecordingIfRequired({required bool resetRoute}) async {
    final config = _activeTimer.config;

    if (!config.routeSharingEnabled) {
      return;
    }

    if (LocationService.instance.isRecording) {
      return;
    }

    final interval = config.locationCollectionIntervalSecs;

    if (interval == null) {
      if (resetRoute) {
        AppLogger.log.severe(
          'Route sharing is enabled but no location collection interval '
          'is configured.',
        );
      } else {
        AppLogger.log.severe(
          'Unable to restore location recording because route sharing is '
          'enabled without a location collection interval.',
        );
      }
      return;
    }

    try {
      await LocationService.instance.startRecording(secondsInterval: interval.toInt(), resetRoute: resetRoute);

      if (resetRoute) {
        AppLogger.log.info(
          'Location route recording started for timer "${config.name}" '
          'with ${interval.toInt()} second interval.',
        );
      } else {
        AppLogger.log.info('Location route recording restored for timer "${config.name}".');
      }
    } on LocationServiceException catch (e, st) {
      AppLogger.log.warning('Unable to ${(resetRoute) ? 'start' : 'restore'} location route recording: $e', e, st);

      WidgetsBinding.instance.addPostFrameCallback((_) async {
        BuildContext? context = PermissionManager.instance.navigatorKey.currentContext;
        if (context == null) return;

        ColorScheme scheme = Theme.of(context).colorScheme;
        AppLocalizations local = AppLocalizations.of(context)!;
        showToast(
          scheme: scheme,
          toast: Text(local.translate("time_map_viewer.location_error"), style: AppText.bodySm(scheme), textAlign: TextAlign.center),
          gravity: ToastGravity.TOP,
          position: (context, child, gravity) {
            return Positioned(top: 150, left: 60, right: 60, child: child);
          },
          secs: 7,
        );
      });
      rethrow;
    } catch (e, st) {
      AppLogger.log.severe('Unexpected error while ${(resetRoute) ? 'starting' : 'restoring'} location route recording.', e, st);
      rethrow;
    }
  }

  /// Stops continuous GPS route recording when it is currently active.
  ///
  /// The persisted route remains in the database after recording stops so that
  /// it can be retrieved later by [LocationService.loadRoute].
  ///
  /// Stopping route recording is intentionally independent from the
  /// [TimerConfig.locationSharingEnabled] value. Continuous recording only
  /// occurs when [TimerConfig.routeSharingEnabled] is enabled.
  Future<List<LatLng>?> _stopLocationRecording() async {
    if (!LocationService.instance.isRecording) {
      return null;
    }

    try {
      return await LocationService.instance.stopRecording().whenComplete(() => AppLogger.log.info('Location route recording stopped.'));
    } catch (e, st) {
      AppLogger.log.severe('Failed to stop location route recording.', e, st);
      return null;
    }
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
      AppLogger.log.warning("Cannot launch timer notification: navigator context unavailable.");
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

    void passwordWritten() {
      passFocus.unfocus();

      if (passController.text.isEmpty) return;
      bool result = verifyPassword(passController.text, _activeTimer.config.passwordHash!);

      try {
        if (result) {
          Navigator.of(context).pop(result);
        } else {
          showToast(
            scheme: scheme,
            toast: Text(local.translate("home.password_invalid"), style: AppText.bodySm(scheme), textAlign: TextAlign.center),
            gravity: ToastGravity.TOP,
            position: (context, child, gravity) {
              return Positioned(bottom: 150, left: 60, right: 60, child: child);
            },
          );
          Navigator.of(context).pop(null);
        }
      } finally {
        passController.dispose();
        passFocus.dispose();
      }
    }

    return showBlurredBottomSheet<bool>(
      context: context,
      scheme: scheme,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => passFocus.requestFocus(),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: passController,
                focusNode: passFocus,
                keyboardType: TextInputType.text,
                maxLength: 30,
                maxLengthEnforcement: MaxLengthEnforcement.enforced,
                style: AppText.body(scheme),
                cursorColor: scheme.primary,
                scrollPadding: const EdgeInsets.all(0),
                inputFormatters: [FilteringTextInputFormatter.singleLineFormatter],
                decoration: InputDecoration(
                  hintText: local.translate("home.password_hint"),
                  counterText: '',
                  contentPadding: EdgeInsets.symmetric(vertical: AppSpacing.xl),
                  border: InputBorder.none,
                  filled: false,
                  fillColor: Colors.transparent,
                ),
                obscureText: true,
                onTap: () {
                  passController.selection = TextSelection(baseOffset: 0, extentOffset: passController.text.length);
                },
                onSubmitted: (_) => passwordWritten(),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
              child: SizedBox(
                height: 64,
                child: PrimaryButton(width: 64, icon: LucideIcons.keySquare, onPressed: () => passwordWritten()),
              ),
            ),
          ],
        ),
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

  /// Retrieves the location data that should be shared as part of the
  /// emergency flow.
  ///
  /// The returned record contains:
  /// - `currentLocation`, which represents the most recent location available
  ///   for the emergency.
  /// - `polyline`, which contains the encoded route recorded during the timer
  ///   run, or an empty string when no route is available or route sharing is
  ///   disabled.
  ///
  /// When [TimerConfig.routeSharingEnabled] is enabled, the method uses the
  /// currently recorded route to determine the latest location and loads the
  /// persisted encoded route from [LocationService]. The last point in the
  /// current route is used as `currentLocation`. This avoids requesting a new
  /// GPS location because continuous route recording is already providing the
  /// location data.
  ///
  /// When route sharing is disabled but [TimerConfig.locationSharingEnabled]
  /// is enabled, any existing route is cleared and a single current location
  /// is requested from [LocationService]. No encoded route is returned in
  /// this configuration.
  ///
  /// Location retrieval and route loading failures are handled internally and
  /// logged. A failure to retrieve the location does not prevent the method
  /// from returning any other location data that is available.
  ///
  /// When location sharing is disabled entirely, no location service is
  /// accessed and the method returns `null` for `currentLocation` and an empty
  /// string for `polyline`.
  ///
  /// Returns a record containing the current emergency location and, when
  /// route sharing is enabled, the encoded route associated with the active
  /// timer.
  Future<({LatLng? currentLocation, String polyline})> getLocationData() async {
    final config = _activeTimer.config;

    LatLng? currentLocation;
    String polyline = '';

    if (config.routeSharingEnabled) {
      try {
        final route = LocationService.instance.currentRoute;
        if (route.isNotEmpty) {
          currentLocation = route.last;
        }
      } catch (e, st) {
        AppLogger.log.warning('Could not read current emergency route.', e, st);
      }

      try {
        polyline = await LocationService.instance.loadEncodedRoute();
      } catch (e, st) {
        AppLogger.log.severe('Failed to load recorded route for emergency.', e, st);
      }
    } else if (config.locationSharingEnabled) {
      try {
        LocationService.instance.clearRoute();
        currentLocation = await LocationService.instance.getCurrentLocation();

        AppLogger.log.info('Obtained current location for emergency sharing.');
      } on LocationServiceException catch (e, st) {
        AppLogger.log.warning('Unable to obtain current location for emergency sharing: $e', e, st);
      } catch (e, st) {
        AppLogger.log.severe('Unexpected error while obtaining current location.', e, st);
      }
    }

    return (currentLocation: currentLocation, polyline: polyline);
  }

  /// Displays an informational warning when an already-expired timer attempts
  /// to trigger the expiration flow again.
  ///
  /// The application's navigator context is used to obtain the current
  /// [ColorScheme] and [AppLocalizations] instances. If no navigator context
  /// is available, the warning cannot be displayed and an error is logged.
  ///
  /// This method does not modify the active timer, change its state, or
  /// navigate to another screen. It only provides user feedback about the
  /// repeated expiration event.
  static void showRepeatedExpiredWarning() {
    AppLogger.log.info('Displaying repeated timer expiration info to user.');

    BuildContext? context = PermissionManager.instance.navigatorKey.currentContext;
    if (context == null) {
      AppLogger.log.severe("Could not display info because context was not ready.\nLiterally unplayable...");
      return;
    }
    ColorScheme scheme = Theme.of(context).colorScheme;
    AppLocalizations local = AppLocalizations.of(context)!;

    showToast(
      scheme: scheme,
      toast: Text(local.translate("emergency_active.warning"), style: AppText.bodySm(scheme), textAlign: TextAlign.center),
      gravity: ToastGravity.BOTTOM,
      position: (context, child, gravity) => Positioned(bottom: 250, left: 30, right: 30, child: child),
      secs: 12,
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

  /// Removes a timer from the database.
  ///
  /// The timer identified by [timerKey] is deleted from persistent storage.
  /// If the deleted timer was associated with the active timer run, the native
  /// timer implementation is responsible for creating a replacement run for
  /// another available timer.
  ///
  /// Returns `true` when the timer is successfully removed.
  ///
  /// Returns `false` if an error occurs while deleting the timer. Errors are
  /// caught internally and are not propagated to the caller.
  ///
  /// The current UTC timestamp in milliseconds since the Unix epoch is passed
  /// to the native timer implementation.
  Future<bool> removeTimerFromDatabase(String timerKey) async {
    try {
      final now = DateTime.now().toUtc().millisecondsSinceEpoch;
      await _activeTimer.deleteTimer(nowMs: now, key: timerKey);
      return true;
    } catch (e, st) {
      AppLogger.log.severe('Failed to delete timer from database.', e, st);
      return false;
    }
  }

  /// Removes [contactID] from the active timer's contacts list.
  ///
  /// If [contactID] exists in the active timer's `contacts` array, that contact
  /// is removed. Other contacts remain unchanged.
  Future<void> removeDeletedContactFromActiveTimer(String contactID) async {
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

    _activeTimer.config.contacts.removeWhere((contact) => contact.id == contactID);
  }

  /// Removes deleted destinations from an account in the active timer's
  /// integration configuration.
  ///
  /// The account is identified by [accountID] and its current destinations are
  /// retrieved from the integration identified by [integrationKey]. Any
  /// destinations configured on the active timer that are no longer present in
  /// the integration account are removed. Other destinations remain unchanged.
  ///
  /// Throws an [Exception] if [integrationKey] is not a supported integration.
  Future<void> removeDeletedAccountDestinationFromActiveTimer(String integrationKey, String accountID) async {
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

    final destinations = rows.map((row) => row['destination_id'] as String).toList();

    final activeIntegration = switch (integrationKey) {
      'discord' => _activeTimer.config.integrations.discord,
      'telegram' => _activeTimer.config.integrations.telegram,
      _ => throw Exception("somehow there's an unknown integration key here"),
    };

    activeIntegration.accounts
        .firstWhereOrNull((account) => account.id == accountID)
        ?.destinations
        .removeWhere((destination) => !destinations.contains(destination));
  }

  /// Removes an account from the active timer's integration configuration.
  ///
  /// The account is identified by [accountID] and removed from the integration
  /// identified by [integrationKey]. Any other accounts configured for the
  /// integration remain unchanged.
  ///
  /// Throws an [Exception] if [integrationKey] is not a supported integration.
  Future<void> removeDeletedIntegrationAccountFromActiveTimer(String integrationKey, String accountID) async {
    final activeIntegration = switch (integrationKey) {
      'discord' => _activeTimer.config.integrations.discord,
      'telegram' => _activeTimer.config.integrations.telegram,
      _ => throw Exception("somehow there's an unknown integration key here"),
    };

    activeIntegration.accounts.removeWhere((account) => account.id == accountID);
  }
}
