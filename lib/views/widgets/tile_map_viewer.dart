import 'dart:async';
import 'dart:math';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_compass/flutter_map_compass.dart';
import 'package:flutter_map_vector_tiles/flutter_map_vector_tiles.dart' as vt;
import 'package:fluttertoast/fluttertoast.dart';
import 'package:geolocator/geolocator.dart';
import 'package:internet_connection_checker_plus/internet_connection_checker_plus.dart';
import 'package:latlong2/latlong.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:still_alive/data/all.dart';
import 'package:still_alive/views/app/home/timer/full_map_screen.dart';
import 'package:url_launcher/url_launcher.dart';
import 'primitives.dart';

/// A map widget for displaying a recorded GPS route using OpenFreeMap
/// vector tiles.
///
/// The widget renders a route as a polyline when multiple GPS points are
/// provided, or displays a single location marker when the route contains
/// only one point. Start, intermediate, and optional end markers are rendered
/// on top of the map using the application's current [ColorScheme].
///
/// The OpenFreeMap map style is selected according to the application's
/// current theme brightness:
///
/// - The `bright` OpenFreeMap style is used in light mode.
/// - The `dark` OpenFreeMap style is used in dark mode.
///
/// Vector tiles are cached both in memory and on disk. The disk cache is
/// limited to 500 MB and cached tiles are retained for 31 days. This allows
/// previously viewed map areas to remain available without repeatedly
/// downloading the same vector tiles.
///
/// Internet connectivity is monitored while the widget is mounted. The map
/// itself remains rendered regardless of connectivity so that cached tiles
/// can still be displayed when the device is offline.
///
/// The [route] points must be supplied in their recorded order. The first
/// point represents the beginning of the route and the last point represents
/// its end.
///
/// When multiple points are provided, the initial camera position is fitted
/// to the route bounds. When a single point is provided, the map is centered
/// directly on that point at [maxZoom].
///
/// Example:
///
/// ```dart
/// TileMapViewer(
///   route: recordedRoute,
///   height: 300,
///   mode: Theme.of(context).brightness,
///   maxZoom: 17,
///   showEndMarker: true,
/// )
/// ```
class TileMapViewer extends StatefulWidget {
  /// Creates a map viewer for a recorded GPS [route].
  ///
  /// The [height] determines the vertical size of the map and is required.
  /// The [width] defaults to [double.infinity].
  ///
  /// [minZoom] and [maxZoom] control the minimum and maximum zoom levels
  /// available to the user. By default, the map can be zoomed from level 8
  /// through level 17.
  ///
  /// [routeWidth] controls the width of the rendered route polyline and
  /// defaults to 5 logical pixels.
  ///
  /// Set [showEndMarker] to `false` to omit the marker at the final route
  /// position.
  const TileMapViewer({
    super.key,
    required this.route,
    required this.height,
    this.width = double.infinity,
    this.minZoom = 8,
    this.maxZoom = 17,
    this.routeWidth = 5.0,
    this.showEndMarker = true,
    this.expandMode = false,
  });

  /// The ordered latitude/longitude points that make up the recorded route.
  ///
  /// An empty list causes the widget to display a "no route" state.
  ///
  /// A single point is displayed as a location marker without a route
  /// polyline. Two or more points are rendered as a connected route.
  final List<LatLng> route;

  /// The vertical size of the map in logical pixels.
  ///
  /// This value is required because the map needs a bounded height when
  /// placed inside most Flutter layouts.
  final double height;

  /// The horizontal size of the map in logical pixels.
  ///
  /// Defaults to [double.infinity], allowing the map to occupy the available
  /// horizontal space provided by its parent.
  final double? width;

  /// The minimum zoom level allowed when interacting with the map.
  ///
  /// Defaults to `8`.
  final double minZoom;

  /// The maximum zoom level allowed when interacting with the map.
  ///
  /// Defaults to `17`.
  final double maxZoom;

  /// The width of the route polyline in logical pixels.
  ///
  /// Defaults to `5.0`.
  final double routeWidth;

  /// Whether to display a marker at the final point of the route.
  ///
  /// The starting point and intermediate route markers are always displayed.
  /// This option only controls the final destination marker.
  ///
  /// Defaults to `true`.
  final bool showEndMarker;

  /// Whether the tile map occupies the whole screen, instead of just a
  /// portion.
  final bool expandMode;

  @override
  State<TileMapViewer> createState() => _TileMapViewerState();
}

/// State implementation for [TileMapViewer].
///
/// This state is responsible for:
///
/// - Loading the appropriate OpenFreeMap style.
/// - Monitoring internet connectivity.
/// - Rendering the vector-tile map.
/// - Configuring the vector-tile disk and memory caches.
/// - Fitting the map camera to the recorded route.
/// - Rendering the route and its location markers.
/// - Cleaning up the connectivity subscription when the widget is disposed.
class _TileMapViewerState extends State<TileMapViewer> {
  /// Subscription used to monitor changes in the device's internet
  /// connectivity.
  StreamSubscription<InternetStatus>? _connectionSubscription;

  /// Whether the device currently has an active internet connection.
  ///
  /// This value is updated both by the initial connectivity check and by
  /// subsequent [InternetConnection] status changes.
  bool _hasInternet = false;

  /// Future that resolves to the OpenFreeMap style used by the map.
  ///
  /// The style is selected once during [initState] according to the current
  /// application brightness and reused by [FutureBuilder] during rebuilds.
  late final Future<vt.Style> _styleFuture;

  @override
  void initState() {
    super.initState();

    _styleFuture = vt.StyleReader(uri: 'https://tiles.openfreemap.org/styles/liberty').read();

    _checkInternet();

    _connectionSubscription = InternetConnection().onStatusChange.listen((status) {
      if (!mounted) return;

      setState(() {
        _hasInternet = status == InternetStatus.connected;
      });
    });
  }

  /// Performs the initial internet connectivity check.
  ///
  /// The result is stored in [_hasInternet]. The mounted check prevents
  /// calling [setState] if the asynchronous connectivity lookup completes
  /// after this state object has already been disposed.
  Future<void> _checkInternet() async {
    final status = await InternetConnection().internetStatus;

    if (!mounted) return;
    setState(() {
      _hasInternet = status == InternetStatus.connected;
    });
  }

  @override
  void dispose() {
    _connectionSubscription?.cancel();
    super.dispose();
  }

  /// Creates a geographic bounding box containing a circle centered around
  /// the given [points].
  ///
  /// The circle is centered on the geographic center of the route and has a
  /// radius equal to the greatest distance from the center to any route point,
  /// plus [paddingKm] kilometers.
  ///
  /// This is useful when fitting a map camera to a route because it provides
  /// consistent visual space around the entire route while avoiding an
  /// unnecessarily large rectangular area.
  ///
  /// The returned [LatLngBounds] represents the bounding box of the resulting
  /// circle and can be passed directly to [CameraFit.bounds].
  ///
  /// A minimum radius of [paddingKm] is used when all route points are at the
  /// same location. This prevents zero-size bounds and helps avoid invalid
  /// camera calculations.
  ///
  /// Example:
  ///
  /// ```dart
  /// final circleBounds = _boundsAroundRoute(
  ///   widget.route,
  ///   paddingKm: 1,
  /// );
  ///
  /// initialCameraFit: CameraFit.bounds(
  ///   bounds: circleBounds,
  ///   padding: const EdgeInsets.all(40),
  ///   maxZoom: widget.maxZoom,
  /// ),
  /// ```
  LatLngBounds _boundsAroundRoute(List<LatLng> points, {double paddingKm = 1}) {
    final bounds = LatLngBounds.fromPoints(points);

    final centerLat = (bounds.north + bounds.south) / 2;
    final centerLon = (bounds.east + bounds.west) / 2;

    // Earth's approximate radius in meters.
    const earthRadius = 6371000.0;

    double maxDistance = 0;

    for (final point in points) {
      final lat1 = centerLat * pi / 180;
      final lat2 = point.latitude * pi / 180;
      final deltaLat = (point.latitude - centerLat) * pi / 180;
      final deltaLon = (point.longitude - centerLon) * pi / 180;

      final a = pow(sin(deltaLat / 2), 2) + cos(lat1) * cos(lat2) * pow(sin(deltaLon / 2), 2);

      final distance = 2 * earthRadius * asin(sqrt(a));

      maxDistance = max(maxDistance, distance);
    }

    final radius = maxDistance + paddingKm * 1000;

    final latPadding = radius / earthRadius * 180 / pi;

    final lonPadding = radius / (earthRadius * cos(centerLat * pi / 180)) * 180 / pi;

    return LatLngBounds(LatLng(centerLat - latPadding, centerLon - lonPadding), LatLng(centerLat + latPadding, centerLon + lonPadding));
  }

  @override
  Widget build(BuildContext context) {
    ColorScheme scheme = Theme.of(context).colorScheme;
    AppLocalizations local = AppLocalizations.of(context)!;

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!await Geolocator.isLocationServiceEnabled()) {
        showToast(
          scheme: scheme,
          toast: Text(local.translate("time_map_viewer.location_error"), style: AppText.bodySm(scheme), textAlign: TextAlign.center),
          gravity: ToastGravity.TOP,
          position: (context, child, gravity) {
            return Positioned(top: 150, left: 60, right: 60, child: child);
          },
          secs: 7,
        );
      }
    });

    if (widget.route.isEmpty) {
      AppCard message = AppCard(
        color: scheme.surfaceContainerHigh,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(LucideIcons.routeOff, size: 32, color: scheme.error),
            const SizedBox(width: AppSpacing.md),
            Text(
              local.translate("time_map_viewer.no_route"),
              style: AppText.bodySm(scheme).copyWith(color: scheme.error),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );

      if (widget.expandMode) {
        return Stack(
          children: [
            Positioned(
              top: 12,
              left: 12,
              child: CircleIconButton(icon: LucideIcons.chevronLeft, onTap: () => Navigator.pop(context)),
            ),
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xxl),
                child: message,
              ),
            ),
          ],
        );
      } else {
        return message;
      }
    }

    final point = widget.route.first;
    final bounds = _boundsAroundRoute(widget.route, paddingKm: 10);

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (!_hasInternet) ...[
          Padding(
            padding: const EdgeInsets.only(top: AppSpacing.xs),
            child: SizedBox(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(LucideIcons.wifiOff, size: 22, color: scheme.error),
                  const SizedBox(width: AppSpacing.md),
                  Text(
                    local.translate("time_map_viewer.no_internet"),
                    style: AppText.bodySm(scheme).copyWith(color: scheme.error),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
        ],

        Hero(
          tag: 'map',
          child: ClipRRect(
            borderRadius: (widget.expandMode) ? BorderRadius.zero : AppRadius.card,
            child: SizedBox(
              width: widget.width,
              height: widget.height,
              child: FutureBuilder<vt.Style>(
                future: _styleFuture,
                builder: (context, snapshot) {
                  if (!snapshot.hasData) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
                      child: SizedBox(
                        width: 44,
                        height: 44,
                        child: Center(child: CircularProgressIndicator(color: scheme.tertiary)),
                      ),
                    );
                  }

                  final style = snapshot.data!;

                  return Stack(
                    fit: StackFit.expand,
                    children: [
                      FlutterMap(
                        options: MapOptions(
                          initialCenter: (widget.route.length == 1) ? point : widget.route.last,

                          initialZoom: (widget.maxZoom < 14) ? widget.maxZoom : 14,

                          initialRotation: 0,

                          backgroundColor: scheme.surface,
                          minZoom: widget.minZoom,
                          maxZoom: widget.maxZoom,

                          // Prevent user from panning around the world.
                          cameraConstraint: CameraConstraint.contain(bounds: bounds),
                        ),

                        children: [
                          vt.VectorTileLayer(
                            theme: style.theme,
                            tileProviders: style.providers,
                            sprites: style.sprites,
                            diskCacheMaximumSizeInBytes: 500 * 1024 * 1024,
                            diskCacheTtl: const Duration(days: 31),
                            memoryCacheMaxBytes: 50 * 1024 * 1024,
                            logger: const vt.Logger.console(), // see style warnings in debug
                          ),

                          MapCompass(
                            icon: Transform.rotate(
                              angle: -math.pi / 4,
                              child: Icon(LucideIcons.compass, size: (widget.expandMode) ? 48 : 32, color: Colors.black),
                            ),
                            hideIfRotatedNorth: true,
                          ),

                          if (widget.route.length == 1) ...[
                            MarkerLayer(
                              markers: [
                                Marker(
                                  point: point,
                                  width: 40,
                                  height: 40,
                                  child: Icon(LucideIcons.mapPin, color: Colors.red, size: 32),
                                ),
                              ],
                              rotate: true,
                            ),
                          ] else ...[
                            PolylineLayer(
                              polylines: [
                                Polyline(
                                  points: widget.route,
                                  color: Color(0xFF4529F4),
                                  strokeWidth: widget.routeWidth,
                                  strokeCap: StrokeCap.round,
                                  strokeJoin: StrokeJoin.round,
                                ),
                              ],
                            ),

                            MarkerLayer(markers: _buildMarkers(scheme), rotate: true),
                          ],

                          if (widget.expandMode)
                            RichAttributionWidget(
                              popupBackgroundColor: scheme.surfaceContainer,
                              attributions: [
                                TextSourceAttribution(
                                  'OpenFreeMap',
                                  onTap: () => launchUrl(Uri.parse('https://openfreemap.org'), mode: LaunchMode.externalApplication),
                                ),
                                TextSourceAttribution(
                                  'OpenMapTiles',
                                  onTap: () => launchUrl(Uri.parse('https://www.openmaptiles.org/'), mode: LaunchMode.externalApplication),
                                ),
                                TextSourceAttribution(
                                  'OpenStreetMap (Data)',
                                  onTap: () => launchUrl(Uri.parse('https://www.openstreetmap.org/copyright'), mode: LaunchMode.externalApplication),
                                ),
                              ],
                            ),
                        ],
                      ),

                      if (!widget.expandMode) ...[
                        Positioned(
                          bottom: 12,
                          right: 12,
                          child: CircleIconButton(
                            icon: LucideIcons.maximize2,
                            onTap: () => Navigator.of(context).push(
                              AppRoute(
                                page: FullMapScreen(route: widget.route),
                                transition: AppRouteTransitionType.slideLeft,
                              ),
                            ),
                          ),
                        ),
                      ] else ...[
                        Positioned(
                          top: 12,
                          left: 12,
                          child: CircleIconButton(icon: LucideIcons.chevronLeft, onTap: () => Navigator.pop(context)),
                        ),
                      ],
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      ],
    );
  }

  /// Builds the markers displayed on top of the route.
  ///
  /// The first route point receives a pin marker, intermediate points receive
  /// flag markers, and the final point receives a map-pin marker when
  /// [TileMapViewer.showEndMarker] is enabled.
  ///
  /// Marker colors are derived from the supplied [ColorScheme] so that they
  /// remain consistent with the application's current theme.
  List<Marker> _buildMarkers(ColorScheme scheme) {
    final markers = <Marker>[];

    markers.add(
      Marker(
        point: widget.route.first,
        width: 40,
        height: 40,
        alignment: Alignment.topCenter,
        child: Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.green, width: 2),
          ),
          child: Icon(LucideIcons.pin, color: Colors.green, size: 28),
        ),
      ),
    );

    List<LatLng> remaining = widget.route.sublist(1, widget.route.length - 1);
    for (var pin in remaining) {
      markers.add(
        Marker(
          point: pin,
          width: 28,
          height: 28,
          alignment: Alignment.topCenter,
          child: Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.black, width: 2),
            ),
            child: Icon(LucideIcons.flag, color: Colors.black, size: 16),
          ),
        ),
      );
    }

    if (widget.showEndMarker) {
      markers.add(
        Marker(
          point: widget.route.last,
          width: 40,
          height: 40,
          alignment: Alignment.topCenter,
          child: Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.red, width: 2),
            ),
            child: Icon(LucideIcons.mapPin, color: Colors.red, size: 28),
          ),
        ),
      );
    }

    return markers;
  }
}
