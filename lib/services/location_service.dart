import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_polyline_algorithm/google_polyline_algorithm.dart';
import 'package:latlong2/latlong.dart';
import 'package:still_alive/data/all.dart';

import 'package:still_alive/services/timer_service.dart';
import 'package:still_alive/views/widgets/tile_map_viewer.dart';
import 'package:still_alive/src/rust/api/data/db.dart';

/// Provides access to the device's current geographic location and manages
/// persistent GPS route recordings.
///
/// [LocationService] is implemented as a singleton because location
/// recording is application-wide state: there should only be one active GPS
/// recording and one underlying location subscription at a time.
///
/// Before using this service, [TimerService] must be initialized because route
/// recordings are associated with the currently active timer.
///
/// Route points are kept in memory as [LatLng] objects for immediate access by
/// the UI, while the complete route is persisted in SQLite as a Google
/// encoded polyline. Each new GPS point is encoded incrementally so the
/// existing polyline does not need to be decoded and re-encoded on every
/// update.
///
/// Background recording is configured through [Geolocator]. On Android this
/// uses a foreground location service, while on iOS background location
/// updates are enabled through the platform's Core Location integration.
///
/// While recording is active, location availability is monitored
/// periodically. If the user disables device location services, the active
/// GPS subscription is cancelled while the recording itself remains active.
/// When location services become available again, the GPS subscription is
/// recreated automatically.
///
/// This service does not own or display any map UI. Consumers are responsible
/// for passing the resulting route to a map widget such as
/// [TileMapViewer].
class LocationService {
  LocationService._();

  /// The singleton instance used throughout the application.
  ///
  /// A singleton is used so that multiple screens cannot accidentally create
  /// independent location subscriptions or simultaneous route recordings.
  static final LocationService instance = LocationService._();

  /// The active GPS position subscription.
  ///
  /// This subscription is created when route recording starts and cancelled
  /// when recording stops or when location services become unavailable.
  ///
  /// The recording itself can remain active while this subscription is
  /// temporarily unavailable. The subscription is recreated automatically
  /// when location services become available again.
  StreamSubscription<Position>? _positionSubscription;

  /// In-memory copy of the currently recorded route.
  ///
  /// The database remains the persistent source of truth, while this list
  /// provides fast access to the route for the UI and for [routeStream].
  final List<LatLng> _route = <LatLng>[];

  /// Broadcasts the current route whenever a new GPS point is successfully
  /// persisted.
  ///
  /// A broadcast controller is used because multiple parts of the application
  /// may want to observe the route simultaneously without competing for a
  /// single subscription.
  final StreamController<List<LatLng>> _routeController = StreamController<List<LatLng>>.broadcast();

  /// Indicates whether a route recording is currently active.
  bool _isRecording = false;

  /// Periodically checks whether device location services are still enabled
  /// while a route recording is active.
  ///
  /// The timer does not collect GPS data. It only detects transitions between
  /// available and unavailable location-service states so the underlying GPS
  /// stream can be stopped or recreated as necessary.
  Timer? _locationMonitorTimer;

  /// Indicates whether an active GPS position subscription is currently
  /// considered available.
  ///
  /// This is intentionally separate from [_isRecording]. A recording may
  /// remain active while location services are temporarily disabled.
  bool _locationStreamActive = false;

  /// Prevents multiple asynchronous attempts from creating the GPS
  /// subscription at the same time.
  ///
  /// Location availability checks and stream error callbacks can occur close
  /// together, so this flag ensures that only one stream-start operation is
  /// in progress at any given time.
  bool _startingLocationStream = false;

  /// Timestamp at which the last GPS point was accepted into the route.
  ///
  /// This is used to enforce [_recordingInterval] even on platforms where the
  /// operating system does not provide an exact location-update interval.
  DateTime? _lastRecordedAt;

  /// Minimum amount of time that must pass between persisted GPS points.
  ///
  /// The default interval is three seconds. The value can be changed through
  /// [recordingInterval] or when [startRecording] is called.
  Duration _recordingInterval = const Duration(seconds: 3);

  /// Emits an immutable snapshot of the current route whenever a new point
  /// has been successfully recorded and persisted.
  ///
  /// The emitted list is a copy of the internal route, so consumers cannot
  /// modify the service's internal state through the stream.
  Stream<List<LatLng>> get routeStream => _routeController.stream;

  /// Whether the service is currently recording a route.
  ///
  /// Returns `true` after [startRecording] successfully starts the recording
  /// session and remains `true` until [stopRecording] is called.
  ///
  /// This value does not indicate whether the GPS stream is currently
  /// available. Location services may temporarily be disabled while a
  /// recording remains active.
  bool get isRecording => _isRecording;

  /// Returns an immutable view of the points currently held in memory.
  ///
  /// The returned list contains the GPS points recorded during the current
  /// recording session. If no route has been recorded, an empty list is
  /// returned.
  ///
  /// The returned list cannot be modified by the caller.
  List<LatLng> get currentRoute => List.unmodifiable(_route);

  /// Gets the minimum interval between persisted GPS points.
  Duration get recordingInterval => _recordingInterval;

  // ---------------------------------------------------------------------------
  // Database
  // ---------------------------------------------------------------------------

  /// The last GPS point successfully persisted to the database.
  ///
  /// Google Polyline encoding stores coordinates as deltas relative to the
  /// previous coordinate. Keeping this point in memory allows each new GPS
  /// position to be encoded directly against the previous position without
  /// decoding the entire stored polyline.
  LatLng? _lastPersistedPoint;

  /// The Google encoded polyline representing the current route.
  ///
  /// This is kept in memory alongside the database copy so that new points can
  /// be appended incrementally. Re-encoding the entire route after every GPS
  /// update would become increasingly expensive as the route grows.
  String _encodedPolyline = '';

  /// Number of GPS points currently stored in the active route.
  ///
  /// This value mirrors the `point_count` column in the database and is useful
  /// for quickly determining the size of a route without decoding its
  /// polyline.
  int _pointCount = 0;

  /// Serializes GPS point processing so multiple asynchronous location updates
  /// cannot modify the incremental polyline state concurrently.
  ///
  /// Each position waits for the previous position to finish processing before
  /// its own database and in-memory updates are performed.
  Future<void> _positionProcessingQueue = Future<void>.value();

  // ---------------------------------------------------------------------------
  // Current location
  // ---------------------------------------------------------------------------

  /// Returns the device's current geographic location.
  ///
  /// Before requesting the position, this method verifies that location
  /// services are enabled and that the application has an appropriate
  /// location permission.
  ///
  /// The returned [LatLng] contains the latitude and longitude reported by
  /// the device.
  ///
  /// Throws [LocationServiceDisabledException] when the device's location
  /// service is disabled.
  ///
  /// Throws [LocationPermissionDeniedException] when location permission is
  /// denied.
  ///
  /// Throws [LocationPermissionPermanentlyDeniedException] when the user has
  /// permanently denied location permission.
  ///
  /// Throws [LocationServiceException] when the returned position is invalid
  /// or cannot otherwise be used.
  Future<LatLng> getCurrentLocation() async {
    await _ensureLocationAvailable();

    final position = await Geolocator.getCurrentPosition(locationSettings: const LocationSettings(accuracy: LocationAccuracy.best));

    _validatePosition(position);

    return LatLng(position.latitude, position.longitude);
  }

  // ---------------------------------------------------------------------------
  // Recording
  // ---------------------------------------------------------------------------

  /// Starts a new GPS route recording.
  ///
  /// [secondsInterval] specifies the minimum number of seconds between
  /// persisted GPS snapshots. Values of two seconds or less are rejected to
  /// prevent unnecessarily frequent GPS and database operations.
  ///
  /// When [resetRoute] is `true`, the existing in-memory route and incremental
  /// polyline encoder state are cleared before recording starts. This should be
  /// used when beginning a completely new timer run.
  ///
  /// When [resetRoute] is `false`, the persisted route associated with the
  /// currently active timer is restored and recording continues from its final
  /// point. This is used when a timer is resumed after being paused or when
  /// timer state is restored after application process recreation.
  ///
  /// The interval is stored in [_recordingInterval] and is used both as the
  /// requested platform location interval and as an additional application-level
  /// throttle when GPS positions are delivered.
  ///
  /// Before recording starts, this method verifies that location services are
  /// enabled and that the required permissions are available.
  ///
  /// Once recording has started, temporary loss of device location services
  /// does not terminate the recording. The location subscription is stopped
  /// while services are unavailable and recreated automatically when services
  /// become available again.
  ///
  /// On Android, the location stream is configured to use a foreground location
  /// service so that recording can continue while the application is
  /// backgrounded.
  ///
  /// On iOS, background location updates are enabled through the platform's
  /// Core Location integration.
  ///
  /// Throws [ArgumentError] if [secondsInterval] is two seconds or less.
  ///
  /// Throws [StateError] if a recording is already active.
  ///
  /// Throws a location-related exception if the device's location service or
  /// permissions are unavailable.
  Future<void> startRecording({required int secondsInterval, bool resetRoute = true}) async {
    if (secondsInterval <= 2) {
      throw ArgumentError.value(secondsInterval, 'secondsInterval', 'Must be greater than two.');
    }

    if (_isRecording) {
      throw StateError('A route is already being recorded.');
    }

    await _ensureLocationAvailable();

    final recordingTimerId = TimerService.instance.activeTimer.key;

    if (resetRoute) {
      _route.clear();

      _lastPersistedPoint = null;
      _encodedPolyline = '';
      _pointCount = 0;
    } else {
      await _restorePersistedRouteState();
    }

    _recordingInterval = Duration(seconds: secondsInterval);
    _lastRecordedAt = null;

    final startedAt = DateTime.now().toUtc().millisecondsSinceEpoch;

    await executeSql(
      sql:
          '''
          UPDATE route_recording
          SET started_at_ms = $startedAt,
              stopped_at_ms = NULL
          WHERE timer_id = "$recordingTimerId"
          ''',
    );

    _isRecording = true;

    await _startLocationStream();
    _startLocationMonitor();
  }

  /// Starts the GPS position stream for the active recording.
  ///
  /// The method does nothing when recording is inactive, when a location
  /// stream is already active, or when another stream-start operation is
  /// already in progress.
  ///
  /// Device location services and application permissions are checked again
  /// immediately before the stream is created because their state may have
  /// changed since [startRecording] or the previous availability check.
  ///
  /// If location services or permissions are unavailable, the recording
  /// remains active and this method returns without creating a subscription.
  /// The location monitor will retry when the service becomes available.
  ///
  /// Errors encountered while creating the stream are logged and treated as
  /// temporary stream unavailability so that the recording can remain active.
  Future<void> _startLocationStream() async {
    if (!_isRecording) {
      return;
    }

    if (_locationStreamActive) {
      return;
    }

    if (_startingLocationStream) {
      return;
    }

    _startingLocationStream = true;

    try {
      // Double-check before creating the stream.
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();

      if (!serviceEnabled) {
        return;
      }

      final permission = await Geolocator.checkPermission();

      if (permission != LocationPermission.always && permission != LocationPermission.whileInUse) {
        return;
      }

      final settings = _createLocationSettings();

      final subscription = Geolocator.getPositionStream(
        locationSettings: settings,
      ).listen(_processPosition, onError: _onLocationError, cancelOnError: false);

      _positionSubscription = subscription;
      _locationStreamActive = true;
    } catch (e, st) {
      AppLogger.log.severe('LocationService: failed to start location stream.', e, st);

      _positionSubscription = null;
      _locationStreamActive = false;
    } finally {
      _startingLocationStream = false;
    }
  }

  /// Stops the currently active GPS route recording.
  ///
  /// The underlying location subscription is cancelled and the recording's
  /// `stopped_at_ms` timestamp is persisted to SQLite.
  ///
  /// The complete route is returned as a new [List] of [LatLng] objects,
  /// allowing it to be passed directly to a map widget without exposing the
  /// service's internal route list.
  ///
  /// If no recording is active, the current in-memory route is returned
  /// without modifying the database.
  ///
  /// The persisted route itself is intentionally retained in SQLite after
  /// stopping so it can be loaded again later.
  Future<List<LatLng>> stopRecording() async {
    if (!_isRecording) {
      return List.unmodifiable(_route);
    }

    _isRecording = false;

    _stopLocationMonitor();

    await _stopLocationStreamOnly();

    _lastRecordedAt = null;

    final recordingTimerId = TimerService.instance.activeTimer.key;
    final stoppedAt = DateTime.now().millisecondsSinceEpoch;
    await executeSql(
      sql:
          '''
          UPDATE route_recording
          SET stopped_at_ms = $stoppedAt
          WHERE timer_id = "$recordingTimerId"
          ''',
    );

    return List.unmodifiable(_route);
  }

  /// Stops only the active GPS position subscription.
  ///
  /// This method does not stop the route recording itself. It is used when
  /// device location services become temporarily unavailable so the recording
  /// can remain active while waiting for location services to return.
  ///
  /// The subscription is cleared and [_locationStreamActive] is reset so the
  /// location monitor can recreate the subscription when appropriate.
  Future<void> _stopLocationStreamOnly() async {
    await _positionSubscription?.cancel();

    _positionSubscription = null;
    _locationStreamActive = false;
  }

  /// Clears the current in-memory route and resets the incremental polyline
  /// encoder state.
  ///
  /// This method must not be called while a recording is active. It does not
  /// delete the corresponding database record because the persisted route may
  /// represent a completed recording that should remain available to the
  /// application.
  ///
  /// After clearing, [routeStream] emits an empty route so observers can
  /// update their UI accordingly.
  void clearRoute() {
    if (_isRecording) {
      throw StateError(
        'Cannot clear the route while recording. '
        'Call stopRecording() first.',
      );
    }

    _route.clear();

    _lastPersistedPoint = null;
    _encodedPolyline = '';
    _pointCount = 0;

    _routeController.add(List.unmodifiable(_route));
  }

  // ---------------------------------------------------------------------------
  // Load persisted route
  // ---------------------------------------------------------------------------

  /// Restores the persisted route and incremental polyline encoder state for
  /// the currently active timer.
  ///
  /// This method is used when continuous route recording resumes after a pause
  /// or after the application process has been recreated.
  ///
  /// The persisted polyline and point count are restored directly from SQLite,
  /// while the final decoded route point is used as the previous coordinate for
  /// subsequent Google Polyline delta encoding.
  ///
  /// If no persisted route exists, the encoder is reset to its empty state.
  Future<void> _restorePersistedRouteState() async {
    final recordingTimerId = TimerService.instance.activeTimer.key;

    final data = await select(
      sql:
          '''
          SELECT polyline, point_count
          FROM route_recording
          WHERE timer_id = "$recordingTimerId"
          ''',
    );
    List<dynamic> result = jsonDecode(data);

    if (result.isEmpty) {
      _route.clear();
      _lastPersistedPoint = null;
      _encodedPolyline = '';
      _pointCount = 0;
      return;
    }

    final polyline = _readString(result[0], 'polyline');

    if (polyline.isEmpty) {
      _route.clear();
      _lastPersistedPoint = null;
      _encodedPolyline = '';
      _pointCount = 0;
      return;
    }

    final decoded = decodePolyline(polyline);

    _route
      ..clear()
      ..addAll(decoded.map((point) => LatLng(point[0].toDouble(), point[1].toDouble())));

    _lastPersistedPoint = _route.isEmpty ? null : _route.last;
    _encodedPolyline = polyline;

    final rawPointCount = _readValue(result[0], 'point_count');

    _pointCount = int.tryParse(rawPointCount?.toString() ?? '') ?? _route.length;
  }

  /// Loads the persisted route for the currently active timer and replaces
  /// the service's in-memory route with it.
  ///
  /// The persisted polyline, point count, and final coordinate are restored so
  /// that a subsequent recording can continue appending to the existing route
  /// without re-encoding the complete route.
  ///
  /// The loaded route is emitted through [routeStream], allowing UI components
  /// that listen to the stream to immediately receive the restored route.
  ///
  /// Returns the restored route as an immutable list.
  Future<List<LatLng>> loadRouteIntoMemory() async {
    await _restorePersistedRouteState();

    _routeController.add(List.unmodifiable(_route));

    return List.unmodifiable(_route);
  }

  /// Loads the Google encoded polyline persisted for the currently active
  /// timer.
  ///
  /// This method returns the route without decoding it, which avoids unnecessary
  /// CPU work when the encoded representation is already suitable for an
  /// emergency transport or history record.
  ///
  /// Returns an empty string when the active timer has no persisted route.
  Future<String> loadEncodedRoute() async {
    final recordingTimerId = TimerService.instance.activeTimer.key;

    final result = await selectOne(
      sql:
          '''
          SELECT polyline
          FROM route_recording
          WHERE timer_id = "$recordingTimerId"
          ''',
    );

    if (_isNone(result)) {
      return '';
    }

    return _readString(result, 'polyline');
  }

  // ---------------------------------------------------------------------------
  // Location settings
  // ---------------------------------------------------------------------------

  /// Creates platform-specific location settings for the active recording.
  ///
  /// Android receives an [AndroidSettings] configuration with a foreground
  /// notification so that location updates can continue while the application
  /// is running in the background.
  ///
  /// iOS receives [AppleSettings] with background location updates enabled and
  /// automatic pausing disabled, which is appropriate for continuous route
  /// tracking.
  ///
  /// Other platforms receive generic [LocationSettings].
  LocationSettings _createLocationSettings() {
    if (defaultTargetPlatform == TargetPlatform.android) {
      BuildContext? context = PermissionManager.instance.navigatorKey.currentContext;
      AppLocalizations? local;
      if (context != null) {
        local = AppLocalizations.of(context)!;
      } else {
        local = null;
      }

      return AndroidSettings(
        accuracy: LocationAccuracy.high,

        // Requested interval between Android location updates.
        intervalDuration: _recordingInterval,

        // Zero means we don't require movement before receiving
        // another update.
        distanceFilter: 5,

        // This is what allows the location stream to continue while
        // the Flutter UI is in the background.
        foregroundNotificationConfig: ForegroundNotificationConfig(
          notificationIcon: AndroidResource(name: 'ic_notification_route'),
          notificationTitle: (local != null) ? local.translate("time_map_viewer.route_notif.0") : 'Recording your route',
          notificationText: (local != null)
              ? local.translate("time_map_viewer.route_notif.1")
              : 'Your location is being recorded. (between your configured interval)',
          enableWakeLock: false,
          enableWifiLock: false,
        ),
      );
    }

    if (defaultTargetPlatform == TargetPlatform.iOS) {
      return AppleSettings(
        accuracy: LocationAccuracy.high,

        // Allow Core Location updates while the app is in the background.
        allowBackgroundLocationUpdates: true,

        // Don't let Core Location automatically pause the route recording.
        pauseLocationUpdatesAutomatically: false,

        distanceFilter: 5,

        activityType: ActivityType.fitness,

        showBackgroundLocationIndicator: true,
      );
    }

    return LocationSettings(accuracy: LocationAccuracy.high, distanceFilter: 5);
  }

  // ---------------------------------------------------------------------------
  // Position processing
  // ---------------------------------------------------------------------------

  /// Queues a GPS position for processing.
  ///
  /// GPS callbacks may arrive while a previous position is still being
  /// persisted. Processing is therefore serialized to ensure that
  /// [_encodedPolyline], [_pointCount], [_lastPersistedPoint], and [_route]
  /// are always updated in the correct order.
  ///
  /// Unexpected processing errors are caught so that one failed callback
  /// cannot leave [_positionProcessingQueue] in an error state and prevent
  /// subsequent GPS positions from being processed.
  void _processPosition(Position position) {
    _positionProcessingQueue = _positionProcessingQueue.then((_) => _onPosition(position));
  }

  /// Processes a position received from the platform location stream.
  ///
  /// Positions are ignored when recording has stopped, when the position is
  /// invalid or inaccurate, or when the configured recording interval has not
  /// elapsed since the previous accepted position.
  ///
  /// Valid positions are first persisted to SQLite. Only after persistence
  /// succeeds are they added to the in-memory route and emitted through
  /// [routeStream].
  ///
  /// Persisting before updating the in-memory route ensures that the UI does
  /// not display a point that failed to reach persistent storage.
  ///
  /// This method is asynchronous because each accepted point must be written
  /// to the database before the route state is updated.
  Future<void> _onPosition(Position position) async {
    if (!_isRecording) {
      return;
    }

    // Reject obviously invalid GPS fixes.
    if (!_isUsablePosition(position)) {
      return;
    }

    final now = DateTime.now().toUtc();

    // Enforce the configured interval independently of the platform's
    // location update frequency.
    if (_lastRecordedAt != null && now.difference(_lastRecordedAt!) < _recordingInterval) {
      return;
    }

    final point = LatLng(position.latitude, position.longitude);

    // Avoid storing an exact duplicate of the previous coordinate.
    if (_route.isNotEmpty && _samePoint(_route.last, point)) {
      return;
    }

    try {
      await _persistPoint(point);
    } catch (e, st) {
      AppLogger.log.severe("LocationService: failed to persist point.", e, st);
      return;
    }

    _route.add(point);
    _lastRecordedAt = now;

    _routeController.add(List.unmodifiable(_route));
  }

  /// Appends a single GPS point to the persisted Google Polyline.
  ///
  /// Google Polyline encoding stores each latitude and longitude as a delta
  /// relative to the corresponding coordinate of the previous point.
  /// Therefore, this method only encodes the new point instead of decoding
  /// and re-encoding the complete route.
  ///
  /// The encoded point is appended to [_encodedPolyline], and the complete
  /// updated polyline is persisted to the active `route_recording` row.
  ///
  /// [_lastPersistedPoint] is updated only after the database operation
  /// succeeds, ensuring the in-memory encoder state remains consistent with
  /// the persisted route.
  Future<void> _persistPoint(LatLng point) async {
    final recordingTimerId = TimerService.instance.activeTimer.key;

    final previous = _lastPersistedPoint;

    final encodedLatitude = encodePoint(point.latitude, previous: previous?.latitude ?? 0);

    final encodedLongitude = encodePoint(point.longitude, previous: previous?.longitude ?? 0);

    final encodedPoint = '$encodedLatitude$encodedLongitude';

    _encodedPolyline += encodedPoint;

    _pointCount++;

    // SQLite string literals require single quotes to be escaped.
    final escapedPolyline = _encodedPolyline.replaceAll("'", "''");

    await executeSql(
      sql:
          '''
          UPDATE route_recording
          SET
            polyline = "$escapedPolyline",
            point_count = $_pointCount
          WHERE timer_id = "$recordingTimerId"
          ''',
    );

    _lastPersistedPoint = point;
  }

  // ---------------------------------------------------------------------------
  // Position validation
  // ---------------------------------------------------------------------------

  /// Determines whether a GPS position is suitable for route recording.
  ///
  /// A position is considered unusable when its latitude or longitude is not
  /// finite, falls outside the valid geographic coordinate ranges, or reports
  /// an accuracy worse than 100 meters.
  ///
  /// This prevents obviously corrupted or extremely inaccurate GPS fixes from
  /// being added to the route.
  bool _isUsablePosition(Position position) {
    if (!position.latitude.isFinite || !position.longitude.isFinite) {
      return false;
    }

    if (position.latitude < -90 || position.latitude > 90 || position.longitude < -180 || position.longitude > 180) {
      return false;
    }

    // Ignore very inaccurate GPS fixes.
    if (position.accuracy.isFinite && position.accuracy > 100) {
      return false;
    }

    return true;
  }

  /// Determines whether two geographic coordinates are exactly identical.
  ///
  /// This is used as a final safeguard against storing the same GPS coordinate
  /// repeatedly when the platform reports duplicate positions.
  bool _samePoint(LatLng a, LatLng b) {
    return a.latitude == b.latitude && a.longitude == b.longitude;
  }

  /// Validates a position returned by [Geolocator].
  ///
  /// Throws [LocationServiceException] when the position fails the same
  /// validity checks used for route recording.
  void _validatePosition(Position position) {
    if (!_isUsablePosition(position)) {
      throw LocationServiceException('The device returned an invalid or inaccurate location.');
    }
  }

  /// Handles errors emitted by the underlying GPS position stream.
  ///
  /// The failed subscription is marked as inactive and cancelled before the
  /// service attempts to recreate it. This prevents an errored subscription
  /// from remaining alive while a replacement subscription is created.
  ///
  /// The recording itself remains active. If location services are available
  /// again, [_checkLocationAvailability] recreates the GPS stream.
  void _onLocationError(Object error) {
    AppLogger.log.severe('LocationService: location stream error.', error);

    _locationStreamActive = false;

    if (_isRecording) {
      unawaited(_handleLocationStreamError());
    }
  }

  /// Cleans up a failed GPS subscription and requests a stream restart when
  /// recording is still active.
  ///
  /// This method is separated from [_onLocationError] because stream error
  /// callbacks cannot synchronously await subscription cancellation.
  Future<void> _handleLocationStreamError() async {
    await _positionSubscription?.cancel();

    _positionSubscription = null;

    if (!_isRecording) {
      return;
    }

    await _checkLocationAvailability();
  }

  // ---------------------------------------------------------------------------
  // Permissions / service availability
  // ---------------------------------------------------------------------------

  /// Starts the periodic location-service availability monitor.
  ///
  /// The monitor runs only while a route recording is active. Every interval
  /// it checks whether device location services are enabled and ensures that
  /// the GPS position stream matches the current availability state.
  ///
  /// Starting the monitor cancels any existing monitor first, preventing
  /// multiple timers from monitoring the same recording simultaneously.
  void _startLocationMonitor() {
    _locationMonitorTimer?.cancel();

    _locationMonitorTimer = Timer.periodic(const Duration(seconds: 5), (_) => _checkLocationAvailability());
  }

  /// Stops the periodic location-service availability monitor.
  ///
  /// This is called when route recording stops or when the service is disposed.
  /// No availability checks are performed while the monitor is stopped.
  void _stopLocationMonitor() {
    _locationMonitorTimer?.cancel();
    _locationMonitorTimer = null;
  }

  /// Checks whether device location services and application permissions are
  /// currently available for the active recording.
  ///
  /// When location services are disabled, the active GPS subscription is
  /// cancelled but [_isRecording] remains `true`.
  ///
  /// When location services become available again, the method recreates the
  /// GPS subscription automatically.
  ///
  /// If application permission is unavailable, the GPS subscription remains
  /// inactive and the monitor continues checking. This allows recording to
  /// remain active while the user changes the permission state externally.
  Future<void> _checkLocationAvailability() async {
    if (!_isRecording) {
      return;
    }

    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();

      if (!serviceEnabled) {
        // Location was turned off.
        //
        // Keep the recording alive, but stop the old GPS subscription.
        if (_locationStreamActive) {
          await _stopLocationStreamOnly();
        }

        return;
      }

      final permission = await Geolocator.checkPermission();

      final permissionGranted = permission == LocationPermission.always || permission == LocationPermission.whileInUse;

      if (!permissionGranted) {
        if (_locationStreamActive) {
          await _stopLocationStreamOnly();
        }

        return;
      }

      // Location is enabled again.
      //
      // If the stream isn't running, recreate it.
      if (!_locationStreamActive) {
        await _startLocationStream();
      }
    } catch (e, st) {
      AppLogger.log.severe('LocationService: failed to check location availability.', e, st);
    }
  }

  /// Verifies that device location services and application permissions are
  /// available.
  ///
  /// If permission has not yet been granted, this method requests it from the
  /// operating system.
  ///
  /// Throws [LocationServiceDisabledException] when device location services
  /// are disabled.
  ///
  /// Throws [LocationPermissionDeniedException] when the user denies the
  /// requested location permission.
  ///
  /// Throws [LocationPermissionPermanentlyDeniedException] when permission
  /// has been permanently denied and must be changed through application
  /// settings.
  ///
  /// Throws [LocationServiceException] when the permission state cannot be
  /// determined.
  Future<void> _ensureLocationAvailable() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();

    if (!serviceEnabled) {
      throw const LocationServiceDisabledException();
    }

    var permission = await Geolocator.checkPermission();

    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.denied) {
      throw const LocationPermissionDeniedException();
    }

    if (permission == LocationPermission.deniedForever) {
      throw const LocationPermissionPermanentlyDeniedException();
    }

    if (permission == LocationPermission.unableToDetermine) {
      throw const LocationServiceException('Unable to determine location permission.');
    }
  }

  // ---------------------------------------------------------------------------
  // Database helpers
  // ---------------------------------------------------------------------------

  /// Determines whether the result returned by [selectOne] represents a
  /// missing database row.
  ///
  /// The application's database API uses the string `"None"` when no matching
  /// row exists, while a null result is also treated as an absent row.
  bool _isNone(dynamic value) {
    if (value == null) {
      return true;
    }

    if (value is String && value.toLowerCase() == 'none') {
      return true;
    }

    return false;
  }

  /// Reads a string column from a row returned by [selectOne].
  ///
  /// A null database value is converted to an empty string so callers do not
  /// need to perform additional null checks.
  String _readString(dynamic row, String column) {
    final value = _readValue(row, column);

    return value?.toString() ?? '';
  }

  /// Retrieves a named column from a database row.
  ///
  /// The current database API is expected to return a [Map] for
  /// [selectOne]. A [StateError] is thrown if the returned value has an
  /// unexpected type, which helps identify database-wrapper contract changes
  /// early.
  dynamic _readValue(dynamic row, String column) {
    if (row is Map) {
      return row[column];
    }

    throw StateError(
      'Expected selectOne() to return a Map, '
      'but received ${row.runtimeType}.',
    );
  }

  // ---------------------------------------------------------------------------
  // Cleanup
  // ---------------------------------------------------------------------------

  /// Releases the resources owned by this service.
  ///
  /// The active GPS subscription is cancelled and the route stream controller
  /// is closed.
  ///
  /// Because [LocationService] is a singleton, application code normally
  /// should not call this method during ordinary screen disposal. Calling it
  /// effectively makes the singleton unusable for future route-stream
  /// subscriptions unless the service itself is recreated.
  Future<void> dispose() async {
    _isRecording = false;

    _stopLocationMonitor();

    await _positionSubscription?.cancel();
    _positionSubscription = null;

    _locationStreamActive = false;

    await _routeController.close();
  }
}

// -----------------------------------------------------------------------------
// Exceptions
// -----------------------------------------------------------------------------

/// Base exception thrown when the location service cannot complete an
/// operation because of a location-related problem.
class LocationServiceException implements Exception {
  /// Creates a location service exception with a human-readable [message].
  const LocationServiceException(this.message);

  /// Description of the problem that caused the exception.
  final String message;

  @override
  String toString() => message;
}

/// Indicates that the device-wide location service is disabled.
///
/// The application cannot obtain a GPS position until the user enables
/// location services in the operating system settings.
class LocationServiceDisabledException extends LocationServiceException {
  /// Creates an exception indicating that location services are disabled.
  const LocationServiceDisabledException() : super('Location services are disabled.');
}

/// Indicates that the application does not currently have permission to access
/// the device's location.
class LocationPermissionDeniedException extends LocationServiceException {
  /// Creates an exception indicating that location permission was denied.
  const LocationPermissionDeniedException() : super('Location permission was denied.');
}

/// Indicates that location permission has been permanently denied.
///
/// The application should direct the user to its operating-system settings
/// page rather than repeatedly requesting the permission through the normal
/// permission dialog.
class LocationPermissionPermanentlyDeniedException extends LocationServiceException {
  /// Creates an exception indicating that location permission was permanently
  /// denied.
  const LocationPermissionPermanentlyDeniedException()
    : super(
        'Location permission was permanently denied. '
        'Enable it from the application settings.',
      );
}
