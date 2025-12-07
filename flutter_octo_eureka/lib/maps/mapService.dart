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

  Future<Map<String, gtfsRoute>> loadRoutes() async {
    final routes = await gtfs.fetchRoutes();
    final routeMap = {for (var route in routes) route.routeId: route};
    return routeMap;
  }
  // {
  //   "route_id": "40",
  //   "agency_id": "RTD",
  //   "route_short_name": "40",
  //   "route_long_name": "Colorado Boulevard",
  //   "route_desc": "This Route Travels Northbound & Southbound",
  //   "route_type": 3,
  //   "route_url": "http://www.rtd-denver.com/Schedules.shtml",
  //   "route_color": "0076CE",
  //   "route_text_color": "FFFFFF"
  // }

  Future<Map<String, Trip>> loadTrips() async {
    final trips = await gtfs.fetchTrips();
    final tripMap = {for (var trip in trips) trip.tripId: trip};
    return tripMap;
  }
  // {
  //   "route_id": "40",
  //   "service_id": "WK",
  //   "trip_id": "115551400",
  //   "trip_headsign": "40th & Colorado Stn via Colorado Blvd",
  //   "direction_id": 0,
  //   "block_id": "40  1",
  //   "shape_id": "1317039"
  // }

  Future<List<Shape>> loadShapePoints(String shapeId) async {
    final shapePoints = await gtfs.fetchShapeById(shapeId);
    return shapePoints;
  }
  // [
  //   {
  //       "shape_id": "1317039",
  //       "shape_pt_lat": 39.648763,
  //       "shape_pt_lon": -104.915242,
  //       "shape_pt_sequence": 1,
  //       "shape_dist_traveled": 0
  //   },
  //   {...}
  // ]

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

  Future<Map<String, List<StopTime>>> loadTripStopTimes(String tripId) async {
    final stopTimes = await gtfs.fetchStopTimesByTripId(tripId);
    final stopTimesMap = <String, List<StopTime>>{};
    for (var stopTime in stopTimes) {
      stopTimesMap.putIfAbsent(stopTime.tripId, () => []).add(stopTime);
    }
    return stopTimesMap;
  }
  // [
  //   {
  //       "trip_id": "115551400",
  //       "arrival_time": "23:01:00",
  //       "departure_time": "23:01:00",
  //       "stop_id": "26312",
  //       "stop_sequence": 1,
  //       "stop_headsign": "",
  //       "pickup_type": 0,
  //       "drop_off_type": 1,
  //       "shape_dist_traveled": 0,
  //       "timepoint": 0
  //   },
  //   {...}
  // ]

  Future<Map<String, Stop>> loadTripStops(
    Map<String, List<StopTime>> stopTimesMap,
  ) async {
    final Set<String> uniqueStopIds = stopTimesMap.values
        .expand((list) => list)
        .map((stopTime) => stopTime.stopId)
        .toSet();

    if (uniqueStopIds.isEmpty) return {};

    try {
      final List<Stop> fetchedStops = await Future.wait(
        uniqueStopIds.map((id) => gtfs.fetchStopById(id)),
      );
      final Map<String, Stop> stopMap = {
        for (var stop in fetchedStops) stop.stopId: stop,
      };
      return stopMap;
    } catch (e) {
      debugPrint("Error fetching trip stops: $e");
      return {};
    }
  }
  // {
  //   "stop_id": "13140",
  //   "stop_code": "13140",
  //   "stop_name": "S Colorado Blvd & Ohio Ave",
  //   "stop_desc": "Vehicles Travelling North",
  //   "stop_lat": 39.70235,
  //   "stop_lon": -104.940514,
  //   "zone_id": "",
  //   "stop_url": "",
  //   "location_type": 0,
  //   "parent_station": "",
  //   "stop_timezone": "",
  //   "wheelchair_boarding": 0
  // }

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

