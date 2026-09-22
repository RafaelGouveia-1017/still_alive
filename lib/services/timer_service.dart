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

    await _scheduleAlarm(alarmId: _activeTimer.key, triggerAt: _activeTimer.run.expiresAtMs);

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
  Future<void> cancelTimer({required bool passwordVerified}) async {
    final now = DateTime.now().toUtc().millisecondsSinceEpoch;

    await _activeTimer.cancelTimerRun(nowMs: now, passwordVerified: passwordVerified);

    if (_activeTimer.run.state == TimerState.cancelled) {
      await _cancelAlarm(alarmId: _activeTimer.key);

      await _stopLocationRecording();
    }

    launchTimerNotification();
    notifyListeners();

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
  /// * [TimerState.warning] navigates to [PreAlertWarningScreen], continuous
  /// route recording remains active when route sharing is enabled (because the
  /// route may be needed by the eventual emergency response) and records a
  /// [TimerWarningEvent] in the timer history.
  /// * [TimerState.expired] navigates to [EmergencyActiveScreen] and
  /// [triggerEmergency] is invoked, where the complete recorded route or a
  /// single current location is obtained depending on the timer configuration.
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
  ///
  Future<void> timerHasExpired() async {
    if (_activeTimer.run.state == TimerState.expired || _activeTimer.run.state == TimerState.warning) {
      AppLogger.log.info('timerHasExpired() called, but timer is already expired or warning.');
      return;
    }

    final now = DateTime.now().toUtc().millisecondsSinceEpoch;
    _activeTimer.updateRunState(nowMs: now);

    NavigatorState? navigator = PermissionManager.instance.navigatorKey.currentState;

    while (navigator == null) {
      AppLogger.log.warning("Navigator not ready to handle timer expiration.");
      await Future.delayed(const Duration(seconds: 2));
      navigator = PermissionManager.instance.navigatorKey.currentState;
    }

    launchTimerNotification();

    switch (_activeTimer.run.state) {
      case TimerState.warning:
        await HistoryService.insertHistoryRecord(
          TimerWarningEvent(
            timerName: _activeTimer.config.name,
            startedAt: DateTime.fromMillisecondsSinceEpoch(_activeTimer.run.startedAtMs),
            endedAt: DateTime.fromMillisecondsSinceEpoch(_activeTimer.run.expiresAtMs),
            remainingSeconds: _activeTimer.config.gracePeriodSecs!,
          ),
        );

        AppLogger.log.info("\n\ntimer state change: running -> warning\n\n");

        navigator.pushAndRemoveUntil(AppRoute(page: PreAlertWarningScreen(), transition: AppRouteTransitionType.slideLeft), (route) => false);
        break;

      case TimerState.expired:
        AppLogger.log.info("\n\ntimer state change: running -> expired\n\n");

        navigator.pushAndRemoveUntil(AppRoute(page: EmergencyActiveScreen(), transition: AppRouteTransitionType.slideLeft), (route) => false);
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
  Future<void> _scheduleAlarm({required String alarmId, required int triggerAt}) async {
    await AppMethodChannel.instance.invokeMethod('scheduleAlarm', {'alarmId': alarmId.hashCode, 'triggerAt': triggerAt});
  }

  /// Cancels a previously scheduled native alarm.
  ///
  /// The [alarmId] identifies the alarm associated with the timer.
  Future<void> _cancelAlarm({required String alarmId}) async {
    await AppMethodChannel.instance.invokeMethod('cancelAlarm', {'alarmId': alarmId.hashCode});
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

  Future<void> triggerEmergency() async {
    final config = _activeTimer.config;

    LatLng? currentLocation;
    String polyline = '';

    // Continuous route recording is no longer required.
    List<LatLng>? route = await _stopLocationRecording();
    if (route != null) currentLocation = route.last;

    if (config.routeSharingEnabled) {
      try {
        polyline = await LocationService.instance.loadEncodedRoute();
        AppLogger.log.info('Loaded recorded route for emergency sharing.');
      } catch (e, st) {
        AppLogger.log.severe('Failed to load recorded route for emergency.', e, st);
      }
    } else if (config.locationSharingEnabled) {
      try {
        currentLocation = await LocationService.instance.getCurrentLocation();

        AppLogger.log.info('Obtained current location for emergency sharing.');
      } on LocationServiceException catch (e, st) {
        AppLogger.log.warning('Unable to obtain current location for emergency sharing: $e', e, st);
      } catch (e, st) {
        AppLogger.log.severe('Unexpected error while obtaining current location.', e, st);
      }
    }

    // TODO:
    //
    // Combine and deduplicate:
    //
    //   _activeTimer.config.contacts[*].email
    //   _activeTimer.config.customEmail
    //
    // and:
    //
    //   _activeTimer.config.contacts[*].sms
    //   _activeTimer.config.customSms
    //
    // TODO:
    //
    // Send the current location or encoded route through the configured
    // emergency channels.
    //
    // TODO:
    //
    // Trigger Discord/Telegram integrations.

    final location = (currentLocation == null)
        ? null
        : <String, dynamic>{'latitude': currentLocation.latitude, 'longitude': currentLocation.longitude};

    await HistoryService.insertHistoryRecord(
      TimerExpiredEvent(
        timerName: config.name,
        startedAt: DateTime.fromMillisecondsSinceEpoch(_activeTimer.run.startedAtMs),
        endedAt: DateTime.now(),
        location: location,
        polyline: polyline,
        sms: [],
        emails: [],
        channels: [],
        alarmTriggered: false,
        audioRecorded: false,
      ),
    );

    // The emergency flow has consumed the route/current location.
    // Continuous route recording is no longer required.
    await _stopLocationRecording();
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
