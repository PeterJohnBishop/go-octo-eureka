import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_octo_eureka/maps/gtfsApiService.dart';
import 'package:flutter_octo_eureka/maps/gtfsTypes.dart';
import 'package:latlong2/latlong.dart';

class MapService {
  // for api requests through the Go server
  final GtfsApiService gtfs = GtfsApiService();

  // load real-time vehicle position data
  Future<List<VehiclePositionEntity>> loadVehiclePositions() async {
    final vehiclePositions = await gtfs.fetchVehiclePositions();
    return vehiclePositions;
  }

  // load all active routes
  Future<List<gtfsRoute>> loadVehicleRoutes(
    List<VehiclePositionEntity> vehicles,
  ) async {
    final Set<String> uniqueRouteIds = vehicles
        .map((v) => v.vehicle?.trip?.routeId)
        .where((id) => id != null)
        .cast<String>()
        .toSet();

    Future<gtfsRoute?> safeFetchRoute(String id) async {
      try {
        return await gtfs.fetchRouteById(id);
      } catch (e) {
        print("Warning: Route $id not found. Skipping.");
        return null;
      }
    }

    final results = await Future.wait(
      uniqueRouteIds.map((id) => safeFetchRoute(id)),
    );

    return results.whereType<gtfsRoute>().toList();
  }

  // load all active trips
  Future<List<Trip>> loadVehicleTrips(
    List<VehiclePositionEntity> vehicles,
  ) async {
    final Set<String> uniqueTripIds = vehicles
        .map((v) => v.vehicle?.trip?.tripId)
        .where((id) => id != null)
        .cast<String>()
        .toSet();

    Future<Trip?> safeFetchTrip(String id) async {
      try {
        return await gtfs.fetchTripById(id);
      } catch (e) {
        print("Warning: Trip $id not found (404). Skipping.");
        return null;
      }
    }

    final List<Trip?> results = await Future.wait(
      uniqueTripIds.map((id) => safeFetchTrip(id)),
    );

    return results.whereType<Trip>().toList();
  }

  // load Shape data for each trip
  Future<List<Shape>> loadTripShapes(String shapeId) async {
    final shapes = await gtfs.fetchShapeById(shapeId);
    return shapes;
  }

  // load trip stop times
  Future<List<StopTime>> loadTripStopTimes(String tripId) async {
    final stopTimes = await gtfs.fetchStopTimesByTripId(tripId);
    return stopTimes;
  }

  // load trip stops
  Future<List<Stop>> loadTripStops(List<StopTime> stopTimes) async {
    final Set<String> uniqueStopIds = stopTimes.map((s) => s.stopId).toSet();

    if (uniqueStopIds.isEmpty) return [];

    try {
      final List<Stop> fetchedStops = await Future.wait(
        uniqueStopIds.map((id) => gtfs.fetchStopById(id)),
      );
      return fetchedStops;
    } catch (e) {
      debugPrint("Error fetching trip stops: $e");
      return [];
    }
  }

  Future<Stop> loadStop(String stopId) async {
    var stop = gtfs.fetchStopById(stopId);
    return stop;
  }

  // build route dropdown items
  List<DropdownMenuItem<String>> buildRouteDropdownItems(
    List<gtfsRoute> routes,
  ) {
    return routes.map((route) {
      Color routeColor = Colors.black;
      if (route.routeColor.isNotEmpty) {
        try {
          final hex = route.routeColor.replaceAll('#', '');
          routeColor = Color(int.parse("0xFF$hex"));
        } catch (_) {
          // Keep default black on error
        }
      }

      return DropdownMenuItem<String>(
        value: route.routeId,
        child: Row(
          children: [
            Container(
              width: 14,
              height: 14,
              decoration: BoxDecoration(
                color: routeColor,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                "${route.routeShortName}: ${route.routeLongName}",
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 14),
              ),
            ),
          ],
        ),
      );
    }).toList();
  }

  Future<List<Polyline>> buildPolylinesForRoute(
    List<Shape> shapePoints,
    String hexColor,
  ) async {
    Color routeColor;
    try {
      final cleanHex = hexColor.replaceAll('#', '');
      routeColor = Color(int.parse("0xFF$cleanHex"));
    } catch (e) {
      debugPrint("Invalid color format '$hexColor', defaulting to blue.");
      routeColor = Colors.blueAccent;
    }

    final Map<String, List<Shape>> groupedShapes = {};
    for (var point in shapePoints) {
      if (!groupedShapes.containsKey(point.shapeId)) {
        groupedShapes[point.shapeId] = [];
      }
      groupedShapes[point.shapeId]!.add(point);
    }

    final List<Polyline> polylines = [];

    groupedShapes.forEach((id, points) {
      points.sort((a, b) => a.shapePtSequence.compareTo(b.shapePtSequence));

      final List<LatLng> latLngPoints = points
          .map((point) => LatLng(point.shapePtLat, point.shapePtLon))
          .toList();

      polylines.add(
        Polyline(points: latLngPoints, strokeWidth: 4.0, color: routeColor),
      );
    });

    return polylines;
  }

  Marker buildStop(Stop stop) {
    return Marker(
      point: LatLng(stop.stopLat, stop.stopLon),
      width: 30.0,
      height: 30.0,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
          border: Border.all(color: Colors.blueAccent, width: 2),
          boxShadow: const [
            BoxShadow(
              color: Colors.black26,
              blurRadius: 4,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: const Icon(Icons.directions_bus, color: Colors.red, size: 18.0),
      ),
    );
  }
}

class VehiclePinIcon extends StatelessWidget {
  final Color iconColor;
  final IconData vehicleIconData;
  final double size;

  const VehiclePinIcon({
    Key? key,
    required this.iconColor,
    required this.vehicleIconData,
    this.size = 40.0,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final double whiteCircleSize = size * 0.6;  
    final double innerIconSize = size * 0.4;   
    final double topOffset = size * 0.1;        

    return Stack(
      alignment: Alignment.topCenter,
      children: [
        Icon(
          Icons.place, 
          color: iconColor,
          size: size,
          shadows: [
            Shadow(
              blurRadius: 2.0,
              color: Colors.black.withOpacity(0.3),
              offset: const Offset(0, 1),
            ),
          ],
        ),

        Padding(
          padding: EdgeInsets.only(top: topOffset),
          child: Stack(
            alignment: Alignment.center,
            children: [
              Container(
                width: whiteCircleSize,
                height: whiteCircleSize,
                decoration: const BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                ),
              ),
              Icon(
                vehicleIconData,
                color: iconColor,
                size: innerIconSize,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class VehicleMarkerMenu extends StatelessWidget {
  final Widget child; // The original VehiclePinIcon
  final VoidCallback onCompassPressed;
  final VoidCallback onWarningPressed;
  final VoidCallback onInfoPressed;
  final VoidCallback onStopsPressed;

  const VehicleMarkerMenu({
    super.key,
    required this.child,
    required this.onCompassPressed,
    required this.onWarningPressed,
    required this.onInfoPressed,
    required this.onStopsPressed
  });

  @override
  Widget build(BuildContext context) {
    const double buttonSize = 40.0;
    
    return Stack(
      alignment: Alignment.center,
      clipBehavior: Clip.none, 
      children: [
        child,

        // reorient the map to match the bearing of the vehicle 
        Positioned(
          left: 0,
          child: _buildMenuButton(
            icon: Icons.explore,
            color: Colors.black,
            onTap: onCompassPressed,
            size: buttonSize,
          ),
        ),

        // tap to show service alerts
        Positioned(
          top: 0,
          child: _buildMenuButton(
            icon: Icons.warning_amber_rounded,
            color: Colors.orange,
            onTap: onWarningPressed,
            size: buttonSize,
          ),
        ),

        // tap for vehicle info (status, capacity, headsign)
        Positioned(
          right: 0,
          child: _buildMenuButton(
            icon: Icons.info_outline,
            color: Colors.teal,
            onTap: onInfoPressed,
            size: buttonSize,
          ),
        ),

        Positioned(
          bottom: 0,
          child: _buildMenuButton(
            icon: Icons.list_outlined,
            color: Colors.red,
            onTap: onStopsPressed,
            size: buttonSize,
          ),
        ),
      ],
    );
  }

  Widget _buildMenuButton({
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
    required double size,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(blurRadius: 4, color: Colors.black26, offset: Offset(0, 2))
          ],
        ),
        child: Icon(icon, color: color, size: 24),
      ),
    );
  }
}