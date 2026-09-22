import 'dart:async';
import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:still_alive/services/location_service.dart';
import 'package:still_alive/views/widgets/tile_map_viewer.dart';

import '../../../widgets/primitives.dart';

/// A full-screen map view that displays a route.
///
/// The route can be provided initially through [route] and is subsequently
/// updated whenever [LocationService] emits a new route.
class FullMapScreen extends StatefulWidget {
  const FullMapScreen({super.key, required this.route});

  final List<LatLng> route;

  @override
  State<FullMapScreen> createState() => _FullMapScreenState();
}

/// State implementation for [FullMapScreen].
///
/// Listens to [LocationService] for route updates and refreshes the map
/// whenever a new route is received.
class _FullMapScreenState extends State<FullMapScreen> {
  List<LatLng> _route = [];
  StreamSubscription<List<LatLng>>? _routeSubscription;

  @override
  void initState() {
    super.initState();

    _route = widget.route;

    _routeSubscription = LocationService.instance.routeStream.listen((route) {
      if (mounted) {
        setState(() {
          _route = route;
        });
      }
    });
  }

  @override
  void dispose() {
    _routeSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScreenBase(
      noSpacing: true,
      child: TileMapViewer(route: _route, height: MediaQuery.of(context).size.height - 80, expandMode: true),
    );
  }
}
