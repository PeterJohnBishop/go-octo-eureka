import 'dart:convert';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_octo_eureka/maps/gtfsTypes.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

class Dataservice {
  static const String baseUrl =
      "https://go-octo-eureka-b5f27b3f9a5c.herokuapp.com/gtfs";

  Future<dynamic> _get(String endpoint) async {
    final url = Uri.parse('$baseUrl$endpoint');
    try {
      final response = await http.get(url);

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        throw Exception('Failed to load $endpoint: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error connecting to server: $e');
    }
  }

  Future<List<AlertEntity>> fetchAlerts() async {
    final data = await _get('/alerts');
    return (data as List).map((json) => AlertEntity.fromJson(json)).toList();
  }

  Future<List<TripUpdateEntity>> fetchTripUpdates() async {
    final data = await _get('/tripupdates');
    return (data as List)
        .map((json) => TripUpdateEntity.fromJson(json))
        .toList();
  }

  Future<List<VehiclePositionEntity>> fetchVehiclePositions() async {
    final data = await _get('/vehiclepositions');
    return (data as List)
        .map((json) => VehiclePositionEntity.fromJson(json))
        .toList();
  }

  // SHAPES
  Future<List<Shape>> fetchShapeById(String id) async {
    final data = await _get('/shapes/$id');
    return (data as List).map((json) => Shape.fromJson(json)).toList();
  }

  // ROUTES
  Future<gtfsRoute> fetchRouteById(String id) async {
    final data = await _get('/routes/$id');
    return gtfsRoute.fromJson(data);
  }

  Future<List<gtfsRoute>> loadVehicleRoutes(
    List<VehiclePositionEntity> vehicles,
  ) async {
    final Set<String> uniqueRouteIds = vehicles
        .map((v) => v.vehicle.trip.routeId)
        .where((id) => id != null)
        .cast<String>()
        .toSet();

    Future<gtfsRoute?> safeFetchRoute(String id) async {
      try {
        return await fetchRouteById(id);
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

  // STOPS
  Future<Stop> fetchStopById(String id) async {
    final data = await _get('/stops/$id');
    return Stop.fromJson(data);
  }

  // TRIPS
  Future<Trip> fetchTripById(String id) async {
    final data = await _get('/trips/$id');
    return Trip.fromJson(data);
  }

  Future<List<Trip>> loadVehicleTrips(
    List<VehiclePositionEntity> vehicles,
  ) async {
    final Set<String> uniqueTripIds = vehicles
        .map((v) => v.vehicle.trip.tripId)
        .where((id) => id != null)
        .cast<String>()
        .toSet();

    Future<Trip?> safeFetchTrip(String id) async {
      try {
        return await fetchTripById(id);
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

  // STOP TIMES
  Future<List<StopTime>> fetchStopTimesByTripId(String tripId) async {
    final data = await _get('/stoptimes/trip/$tripId');
    return (data as List).map((json) => StopTime.fromJson(json)).toList();
  }

  Future<StopTime> fetchStopTimeByIds(String tripId, String stopId) async {
    final data = await _get('/stoptimes/trip/$tripId/stop/$stopId');
    return StopTime.fromJson(data);
  }

  Future<List<RouteTripShape>> fetchRouteTripShapes(double lat, double lon, double radius) async {
    final data = await _get('/routes/lat/$lat/lon/$lon/radius/$radius');
    return (data as List).map((json) => RouteTripShape.fromJson(json)).toList();
  }


  DateTime parseGtfsTime(String timeString) {
  if (timeString.isEmpty) return DateTime.now();
  
  final parts = timeString.split(':');
  final now = DateTime.now();
  int h = int.parse(parts[0]);
  int m = int.parse(parts[1]);
  int s = int.parse(parts[2]);

  int dayOffset = 0;
  if (h >= 24) {
    h -= 24;
    dayOffset = 1;
  }
  
  return DateTime(now.year, now.month, now.day + dayOffset, h, m, s);
}

  double calculateScheduledSpeedMPH(
    VehiclePositionEntity vehicle,
    List<StopTime> stopTimes,
    List<Stop> stops,
  ) {
    final String nextStopId = vehicle.vehicle.stopId;
    final StopTime? nextStopTime = stopTimes.firstWhere(
      (st) => st.stopId == nextStopId,
      orElse: () => StopTime.empty(),
    );

    if (nextStopTime == null || nextStopTime.stopSequence <= 1) {
      return 99.0;
    }

    final StopTime? prevStopTime = stopTimes.firstWhere(
      (st) => st.stopSequence == nextStopTime.stopSequence - 1,
      orElse: () => StopTime.empty(),
    );

    if (prevStopTime == null) return 30.0;

    final Stop? nextStop = stops.firstWhere(
      (s) => s.stopId == nextStopTime.stopId,
      orElse: () => Stop.empty(),
    );
    final Stop? prevStop = stops.firstWhere(
      (s) => s.stopId == prevStopTime.stopId,
      orElse: () => Stop.empty(),
    );

    if (nextStop == null || prevStop == null) return 30.0;

    final Distance distance = const Distance();
    double meters = distance.as(
      LengthUnit.Meter,
      LatLng(prevStop.stopLat, prevStop.stopLon),
      LatLng(nextStop.stopLat, nextStop.stopLon),
    );

    // Track curvature adjustment (1.2x) to account for curved roads and track
    meters = meters * 1.2;

    double miles = meters * 0.000621371;

    final DateTime nextTime = parseGtfsTime(nextStopTime.arrivalTime);
    final DateTime prevTime = parseGtfsTime(prevStopTime.departureTime);

    final int durationSeconds = nextTime.difference(prevTime).inSeconds;

    if (durationSeconds <= 0) return 30.0;

    double hours = durationSeconds / 3600.0;

    return miles / hours;
  }

  // Status Code: 0 = Early, 1 = On Time, 2 = Late, -1 = Unknown
(String, int) calculateDelayStatus(
  VehiclePositionEntity vehicle,
  List<StopTime> tripStopTimes,
  List<Stop> tripStops,
) {
  final String targetStopId = vehicle.vehicle.stopId;
  
  if (targetStopId.isEmpty) return ("N/A", -1);

  final StopTime? targetSchedule = tripStopTimes.firstWhere(
    (st) => st.stopId == targetStopId,
    orElse: () => StopTime.empty(),
  );

  final Stop? targetStopData = tripStops.firstWhere(
    (s) => s.stopId == targetStopId,
    orElse: () => Stop.empty(),
  );

  if (targetSchedule == null || targetStopData == null || targetSchedule.arrivalTime.isEmpty) {
    return ("No Schedule", -1);
  }

  final DateTime scheduledTime = parseGtfsTime(targetSchedule.arrivalTime);

  final Distance distance = const Distance();
  final double metersToStop = distance.as(
    LengthUnit.Meter,
    LatLng(vehicle.vehicle.position.latitude, vehicle.vehicle.position.longitude),
    LatLng(targetStopData.stopLat, targetStopData.stopLon)
  );

  double speedInMph = calculateScheduledSpeedMPH(vehicle, tripStopTimes, tripStops);
  double speedInMps = speedInMph * 0.44704;

  if (speedInMps <= 0) speedInMps = 1.0;

  final int secondsToTravel = (metersToStop / speedInMps).round();

  final DateTime vehicleReportedTime = DateTime.fromMillisecondsSinceEpoch(
    vehicle.vehicle.timestamp * 1000
  );
  final DateTime estimatedArrival = vehicleReportedTime.add(Duration(seconds: secondsToTravel));

  final int diffSeconds = estimatedArrival.difference(scheduledTime).inSeconds;

  if (diffSeconds > 120) {
    final int minLate = (diffSeconds / 60).round();
    return ("$minLate min Late", 2); // 2 = Late
  } else if (diffSeconds < -120) {
    final int minEarly = (diffSeconds.abs() / 60).round();
    return ("$minEarly min Late", 0); // 0 = Early
  } else {
    return ("On Time.", 1); // 1 = On Time
  }
}

(String, int) calculateStopDelayStatus(
  VehiclePositionEntity vehicle,
  List<StopTime> tripStopTimes,
  List<Stop> tripStops,
  String selectedStopId, 
) {
  final String nextStopId = vehicle.vehicle.stopId;
  if (nextStopId.isEmpty) return ("N/A", -1);

  final int nextStopIndex = tripStopTimes.indexWhere((st) => st.stopId == nextStopId);
  final int selectedStopIndex = tripStopTimes.indexWhere((st) => st.stopId == selectedStopId);

  if (nextStopIndex == -1 || selectedStopIndex == -1) {
    return ("Unknown Stop", -1);
  }
  if (nextStopIndex > selectedStopIndex) {
    return ("Departed", -1); 
  }

  final StopTime selectedSchedule = tripStopTimes[selectedStopIndex];
  if (selectedSchedule.arrivalTime.isEmpty) return ("No Schedule", -1);
  final DateTime scheduledTimeAtSelected = parseGtfsTime(selectedSchedule.arrivalTime);

  final Stop? nextStopData = tripStops.firstWhere(
    (s) => s.stopId == nextStopId,
    orElse: () => Stop.empty(),
  );

  if (nextStopData == null || nextStopData.stopId.isEmpty) return ("No Stop Data", -1);

  final Distance distance = const Distance();
  final double distVehicleToNext = distance.as(
    LengthUnit.Meter,
    LatLng(vehicle.vehicle.position.latitude, vehicle.vehicle.position.longitude),
    LatLng(nextStopData.stopLat, nextStopData.stopLon)
  );

  double distBetweenStops = 0.0;

  for (int i = nextStopIndex; i < selectedStopIndex; i++) {
    final String s1Id = tripStopTimes[i].stopId;
    final String s2Id = tripStopTimes[i + 1].stopId;

    final Stop s1 = tripStops.firstWhere((s) => s.stopId == s1Id, orElse: () => Stop.empty());
    final Stop s2 = tripStops.firstWhere((s) => s.stopId == s2Id, orElse: () => Stop.empty());

    if (s1.stopId.isNotEmpty && s2.stopId.isNotEmpty) {
      distBetweenStops += distance.as(
        LengthUnit.Meter,
        LatLng(s1.stopLat, s1.stopLon),
        LatLng(s2.stopLat, s2.stopLon),
      );
    }
  }

  final double totalMeters = distVehicleToNext + distBetweenStops;

  double speedInMph = calculateScheduledSpeedMPH(vehicle, tripStopTimes, tripStops);
  double speedInMps = speedInMph * 0.44704;

  if (speedInMps <= 0.1) speedInMps = 1.0; 

  final int secondsToTravel = (totalMeters / speedInMps).round();

  final DateTime vehicleReportedTime = DateTime.fromMillisecondsSinceEpoch(
    vehicle.vehicle.timestamp * 1000
  );
  
  final DateTime estimatedArrivalAtSelected = vehicleReportedTime.add(Duration(seconds: secondsToTravel));

  final int diffSeconds = estimatedArrivalAtSelected.difference(scheduledTimeAtSelected).inSeconds;

  if (diffSeconds > 120) {
    final int minLate = (diffSeconds / 60).round();
    return ("$minLate min Late", 2); // 2 = Late
  } else if (diffSeconds < -120) {
    final int minEarly = (diffSeconds.abs() / 60).round();
    return ("$minEarly min Early", 0); // 0 = Early
  } else {
    return ("On Time", 1); // 1 = On Time
  }
}
}
