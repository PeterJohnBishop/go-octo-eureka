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

    List<Polyline<Object>> buildTripPolyline(List<Shape> shapes, Color colorFromHex) {
    shapes.sort((a, b) => a.shapePtSequence.compareTo(b.shapePtSequence));

    final points = shapes
        .map((s) => LatLng(s.shapePtLat, s.shapePtLon))
        .toList();

    final polyline = Polyline(
      points: points,
      strokeWidth: 4.0,
      color: colorFromHex,
    );

    return [polyline];
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

  List<Marker> buildStopMarkers(List<StopTime> stopTimes, List<Stop> stops, Color colorFromHex) {
    List<Marker> newStopMarkers = [];

    for (var stop in stops) {
      final vehicleStopTime = stopTimes.firstWhere((s) {
        return s.stopId == stop.stopId;
      });
      final convertedArrival = formatGtfsTime(
        vehicleStopTime.arrivalTime,
      );
      final convertedDeparture = formatGtfsTime(
        vehicleStopTime.departureTime,
      );

      newStopMarkers.add(
        Marker(
          point: LatLng(stop.stopLat, stop.stopLon),
          width: 200.0,
          height: 175.0,
          alignment: Alignment.center,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(6),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.3),
                      blurRadius: 2,
                      offset: const Offset(0, 1),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Text(
                      stop.stopName,
                      style: const TextStyle(
                        color: Colors.black,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      "Scheduled",
                      style: const TextStyle(
                        color: Colors.black,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      "arrival: $convertedArrival,",
                      style: const TextStyle(
                        color: Colors.black,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      "departure: $convertedDeparture",
                      style: const TextStyle(
                        color: Colors.black,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  border: Border.all(color: colorFromHex, width: 2),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.2),
                      blurRadius: 2,
                      offset: const Offset(0, 1),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    }

    return newStopMarkers;

  }

  Color colorFromHex(String hexColor) {
    String color = hexColor.toUpperCase().replaceAll('#', '');
    if (color.length == 6) {
      color = 'FF$color';
    }
    try {
      return Color(int.parse(color, radix: 16));
    } catch (e) {
      return Colors.blue;
    }
  }

  String formatGtfsTime(String time24) {
    if (time24.isEmpty) return "";

    // Split "23:01:00" into ["23", "01", "00"]
    final parts = time24.split(':');
    if (parts.length < 2) return time24;
    int hours = int.tryParse(parts[0]) ?? 0;
    final String minutes = parts[1];

    // Handle GTFS 24+ times (like 25:00 = 1:00 AM)
    hours = hours % 24;

    // Determine AM or PM
    final String period = hours >= 12 ? 'PM' : 'AM';

    // Convert 24h to 12h
    hours = hours % 12;
    // If hours is 0 (midnight or noon), show as 12
    if (hours == 0) hours = 12;

    return "$hours:$minutes $period";
  }

}

class VehiclePinIcon extends StatelessWidget {
  final Color iconColor;
  final IconData vehicleIconData;
  final double size;
  final double bearing;

  const VehiclePinIcon({
    super.key,
    required this.iconColor,
    required this.vehicleIconData,
    this.size = 40.0,
    required this.bearing,
  });

  @override
  Widget build(BuildContext context) {
    final double whiteCircleSize = size * 0.6;
    final double innerIconSize = size * 0.4;

    // Adjust this to push the arrow further out or pull it in
    final double arrowVerticalShift = -size * 0.25;

    return Transform.rotate(
      angle: bearing,
      child: SizedBox(
        width: size,
        height: size,
        child: Stack(
          alignment: Alignment.center,
          clipBehavior: Clip.none,
          children: [
            Transform.translate(
              offset: Offset(0, arrowVerticalShift),
              child: Icon(
                Icons.keyboard_arrow_up_sharp,
                color: Colors.red,
                size: size,
                shadows: [
                  Shadow(
                    blurRadius: 2.0,
                    color: Colors.black.withOpacity(0.3),
                    offset: const Offset(0, 1),
                  ),
                ],
              ),
            ),
            Container(
              width: whiteCircleSize,
              height: whiteCircleSize,
              decoration: const BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: Icon(
                vehicleIconData,
                color: iconColor,
                size: innerIconSize,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class VehicleMarkerMenu extends StatelessWidget {
  final Widget child;
  final bool isBus;
  final int? status;
  final Stop? stop;
  final String? headsign;
  final String? timestamp;
  final VoidCallback onCompassPressed;
  final VoidCallback onWarningPressed;
  final VoidCallback onInfoPressed;

  const VehicleMarkerMenu({
    super.key,
    required this.child,
    required this.isBus,
    required this.headsign,
    required this.timestamp,
    required this.status,
    required this.stop,
    required this.onCompassPressed,
    required this.onWarningPressed,
    required this.onInfoPressed,
  });

  @override
  Widget build(BuildContext context) {
    const double buttonSize = 40.0;
    String statusString;
    if (status == 0) {
      statusString = "Arriving at";
    } else if (status == 1) {
      statusString = "Stopped at";
    } else {
      statusString = "In transit to";
    }

    return Stack(
      alignment: Alignment.center,
      clipBehavior: Clip.none,
      children: [
        child,
        Positioned(
          top: 75,

          child: Container(
            padding: const EdgeInsets.all(8.0),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: .2),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 10.0, sigmaY: 10.0),
                child: Container(
                  color: Colors.white.withValues(alpha: 0.4),
                  padding: const EdgeInsets.symmetric(
                    vertical: 8,
                    horizontal: 4,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      headsign != null && headsign!.isNotEmpty
                          ? Container(
                              padding: const EdgeInsets.all(8.0),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Text(
                                isBus
                                    ? "${headsign!} bus"
                                    : "${headsign!} train",
                                style: const TextStyle(
                                  color: Colors.black,
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                ),
                                textAlign: TextAlign.center,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            )
                          : SizedBox(),
                      Text(
                        statusString,
                        style: const TextStyle(
                          color: Colors.black,
                          fontSize: 12,
                        ),
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                              stop?.stopName ?? "loading stop...",
                              style: const TextStyle(
                                color: Colors.black,
                                fontSize: 12,
                              ),
                              textAlign: TextAlign.center,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            )
                          ,
                      Text(
                        "Status updated at $timestamp",
                        style: const TextStyle(
                          color: Colors.black,
                          fontSize: 10,
                        ),
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ),
            ),
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
        padding: const EdgeInsets.all(8.0),
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(16)),
        child: Icon(icon, color: color, size: 24),
      ),
    );
  }
}