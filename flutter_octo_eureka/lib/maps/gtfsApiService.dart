import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_octo_eureka/maps/gtfsTypes.dart';


class GtfsApiService {

  static const String baseUrl = "http://localhost:8080/gtfs"; 

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
    return (data as List).map((json) => TripUpdateEntity.fromJson(json)).toList();
  }

  Future<List<VehiclePositionEntity>> fetchVehiclePositions() async {
    final data = await _get('/vehiclepositions');
    return (data as List).map((json) => VehiclePositionEntity.fromJson(json)).toList();
  }

  Future<List<gtfsRoute>> fetchRoutes() async {
    final data = await _get('/routes');
    return (data as List).map((json) => gtfsRoute.fromJson(json)).toList();
  }

  Future<List<Stop>> fetchStops() async {
    final data = await _get('/stops');
    return (data as List).map((json) => Stop.fromJson(json)).toList();
  }

  Future<List<Trip>> fetchTrips() async {
    final data = await _get('/trips');
    return (data as List).map((json) => Trip.fromJson(json)).toList();
  }

  Future<List<Shape>> fetchShapeById(String id) async {
    final data = await _get('/shapes/$id');
    return (data as List).map((json) => Shape.fromJson(json)).toList();
  }

  Future<gtfsRoute> fetchRouteById(String id) async {
    final data = await _get('/routes/$id');
    return gtfsRoute.fromJson(data);
  }

  Future<Stop> fetchStopById(String id) async {
    final data = await _get('/stops/$id');
    return Stop.fromJson(data);
  }

  Future<Trip> fetchTripById(String id) async {
    final data = await _get('/trips/$id');
    return Trip.fromJson(data);
  }

  Future<List<StopTime>> fetchStopTimesByTripId(String tripId) async {
    final data = await _get('/stoptimes/trip/$tripId');
    return (data as List).map((json) => StopTime.fromJson(json)).toList();
  }

  Future<StopTime> fetchStopTimeByIds(String tripId, String stopId) async {
    final data = await _get('/stoptimes/trip/$tripId/stop/$stopId');
    return StopTime.fromJson(data);
  }
}