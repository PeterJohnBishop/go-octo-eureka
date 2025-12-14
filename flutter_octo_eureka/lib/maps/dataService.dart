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
}