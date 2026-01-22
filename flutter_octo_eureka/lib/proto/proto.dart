import 'dart:convert';

import 'package:flutter_octo_eureka/maps/gtfsTypes.dart';
import 'package:flutter_octo_eureka/proto/protoTypes.dart';
import 'package:http/http.dart' as http;

class ProtoService {

  static const String baseUrl = "http://localhost:8080";

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

  Future<List<RouteDetail>> fetchRouteDetailsByRouteId(String routeId) async {
    final data = await _get('/routes/$routeId');
    return (data as List)
    .map((json) => RouteDetail.fromJson(json))
    .toList();
  }

  Future<List<RouteDetail>> fetchRouteDetailsByTripId(String tripId) async {
    final data = await _get('/trips/$tripId');
    return (data as List)
    .map((json) => RouteDetail.fromJson(json))
    .toList();
  }

  Future<List<RouteItem>> fetchRouteMenuItems() async {
    final data = await _get('/routes');
    return (data as List)
    .map((json) => RouteItem.fromJson(json))
    .toList();
  }
}
