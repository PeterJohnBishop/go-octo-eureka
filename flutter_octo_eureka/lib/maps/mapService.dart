import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_octo_eureka/maps/gtfsApiService.dart';
import 'package:flutter_octo_eureka/maps/gtfsTypes.dart';
import 'package:latlong2/latlong.dart';

class MapService {
  final GtfsApiService gtfs = GtfsApiService();

  Future<List<VehiclePositionEntity>> loadVehiclePositions() async {
    final vehiclePositions = await gtfs.fetchVehiclePositions();
    return vehiclePositions;
  }

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

  Future<List<Shape>> loadTripShapes(String shapeId) async {
    final shapes = await gtfs.fetchShapeById(shapeId);
    return shapes;
  }

  Future<List<StopTime>> loadTripStopTimes(String tripId) async {
    final stopTimes = await gtfs.fetchStopTimesByTripId(tripId);
    return stopTimes;
  }

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
