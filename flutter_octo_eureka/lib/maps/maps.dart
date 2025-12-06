import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_octo_eureka/maps/gtfsApiService.dart';
import 'package:latlong2/latlong.dart';
import 'package:flutter_octo_eureka/maps/gtfsTypes.dart';

class BaseMapWidget extends StatefulWidget {
  const BaseMapWidget({super.key});

  @override
  State<BaseMapWidget> createState() => _BaseMapWidgetState();
}

class _BaseMapWidgetState extends State<BaseMapWidget> {
  final GtfsApiService gtfs = GtfsApiService();
  List<VehiclePositionEntity> _vehiclePositions = [];
  List<gtfsRoute> _vehicleRoutes = [];
  List<Trip> _vehicleTrips = [];
  List<Stop> _vehicleStops = [];
  List<StopTime> _vehicleStopTimes = [];
  List<Polyline> _vehiclePolylines = [];
  Map<String, gtfsRoute> _routeMap = {};
  List<Marker> _stopMarkers = [];

  bool _isLoading = true;
  var shapeIds = ["1316772", "1317062"];

  @override
  void initState() {
    super.initState();
    _loadVehiclePositions();
  }

  Future<void> _loadVehiclePositions() async {
    try {
      final Future<List<VehiclePositionEntity>> futures = gtfs
          .fetchVehiclePositions();

      final List<VehiclePositionEntity> vehiclePositions = await futures;
      setState(() {
        _vehiclePositions = vehiclePositions;
      });
      await loadVehicleRoutes(vehiclePositions);
      await loadVehicleTrips(vehiclePositions);
    } catch (e) {
      debugPrint("Error fetching vehicle positions: $e");
    }
  }

  Future<void> loadVehicleRoutes(List<VehiclePositionEntity> vehicles) async {
    final Set<String> uniqueRouteIds = vehicles
        .map((v) => v.vehicle?.trip?.routeId)
        .where((id) => id != null)
        .cast<String>()
        .toSet();

    final List<String> idsToFetch = uniqueRouteIds
        .where((id) => !_routeMap.containsKey(id))
        .toList();

    if (idsToFetch.isEmpty) return;

    final List<Future<gtfsRoute>> fetchThese = idsToFetch
        .map((id) => gtfs.fetchRouteById(id))
        .toList();

    try {
      final List<gtfsRoute> fetchedRoutes = await Future.wait(fetchThese);

      _vehicleRoutes.addAll(fetchedRoutes);

      for (var route in fetchedRoutes) {
        _routeMap[route.routeId] = route;
      }
    } catch (e) {
      debugPrint('Error fetching routes: $e');
    }
  }

  Future<void> loadVehicleTrips(List<VehiclePositionEntity> vehicles) async {
    final Set<String> uniqueTripIds = vehicles
        .map((v) => v.vehicle?.trip?.tripId)
        .where((id) => id != null)
        .cast<String>()
        .toSet();

    try {
      final List<Trip> vehicleTrips = await Future.wait(
        uniqueTripIds.map((id) => gtfs.fetchTripById(id)),
      );

      setState(() {
        _vehicleTrips = vehicleTrips;
      });
      await loadVehicleShapes(vehicleTrips);
      await loadRouteStops(vehicleTrips);
    } catch (e) {
      debugPrint("Error fetching trips: $e");
    }
  }

Future<void> loadRouteStops(List<Trip> trips) async {
  try {
    // 1. Fetch StopTimes for all active trips
    final List<Future<List<StopTime>>> stopTimeFutures = trips
        .map((trip) => gtfs.fetchStopTimesByTripId(trip.tripId))
        .toList();

    final List<List<StopTime>> stopTimeResults = await Future.wait(stopTimeFutures);
    
    // Flatten the list of lists into one big list of StopTimes
    final List<StopTime> allStopTimes = stopTimeResults.expand((x) => x).toList();

    // 2. Extract Unique Stop IDs from the StopTimes
    final Set<String> uniqueStopIds = allStopTimes
        .map((st) => st.stopId)
        .toSet();

    if (uniqueStopIds.isEmpty) {
      debugPrint("No stops found for these trips.");
      return;
    }

    // 3. Fetch the actual Stop objects (lat/lon)
    final List<Stop> fetchedStops = await Future.wait(
      uniqueStopIds.map((id) => gtfs.fetchStopById(id)),
    );

    // 4. Update the map
    _processStopData(fetchedStops);

  } catch (e) {
    debugPrint("Error fetching route stops: $e");
  }
}

  Future<void> loadVehicleShapes(List<Trip> uniqueTrips) async {
    try {
      final Set<String> uniqueShapeIds = uniqueTrips
          .map((t) => t.shapeId)
          .toSet();

      if (uniqueShapeIds.isEmpty) return;

      final Map<String, String> shapeColorMap = {};

      for (var trip in uniqueTrips) {
        if (trip.shapeId.isEmpty) continue;

        final route = _routeMap[trip.routeId];

        final String color = (route != null && route.routeColor.isNotEmpty)
            ? route.routeColor
            : "0076CE";

        shapeColorMap[trip.shapeId] = color;
      }

      final List<Future<List<Shape>>> shapeFutures = uniqueShapeIds
          .map((id) => gtfs.fetchShapeById(id))
          .toList();

      final List<List<Shape>> results = await Future.wait(shapeFutures);
      final List<Shape> allRawShapes = results.expand((s) => s).toList();

      final List<PolyShape> coloredShapes = allRawShapes.map((shape) {
        final color = shapeColorMap[shape.shapeId];
        return PolyShape.fromShape(shape, color);
      }).toList();

      _processShapeData(coloredShapes);
    } catch (e) {
      debugPrint("Error fetching shapes: $e");
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _processStopData(List<Stop> data) {
            print("generating stop markers for ${data.length} stops");

    final List<Marker> markers = data.map((stop) {
      return Marker(
        point: LatLng(stop.stopLat, stop.stopLon),
        width: 30.0,
        height: 30.0,
        // Using a child (flutter_map v6+) or builder (older versions)
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.blueAccent, width: 2),
            boxShadow: [
              BoxShadow(
                color: Colors.black26,
                blurRadius: 4,
                offset: Offset(0, 2),
              ),
            ],
          ),
          child: const Icon(
            Icons.directions_bus, // Or Icons.stop_circle
            color: Colors.red,
            size: 18.0,
          ),
        ),
      );
    }).toList();

    if (mounted) {
      setState(() {
        _stopMarkers = markers;
      });
    }
  }

  void _processShapeData(List<PolyShape> data) {
    final Map<String, List<PolyShape>> groupedShapes = {};

    for (var point in data) {
      final String id = point.shapeId;
      if (!groupedShapes.containsKey(id)) {
        groupedShapes[id] = [];
      }
      groupedShapes[id]!.add(point);
    }

    final List<Polyline> vehiclePolylines = [];

    groupedShapes.forEach((id, points) {
      points.sort((a, b) => a.shapePtSequence.compareTo(b.shapePtSequence));

      final List<LatLng> coordinates = points.map((pt) {
        return LatLng(pt.shapePtLat, pt.shapePtLon);
      }).toList();

      final Color polyColor = points.isNotEmpty
          ? points.first.color
          : Colors.green;

      vehiclePolylines.add(
        Polyline(points: coordinates, strokeWidth: 4.0, color: polyColor),
      );
    });

    if (mounted) {
      setState(() {
        _vehiclePolylines = vehiclePolylines;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          FlutterMap(
            options: MapOptions(
              initialCenter: const LatLng(39.7392, -104.9903),
              initialZoom: 9.2,
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.example.app',
              ),
              PolylineLayer(polylines: _vehiclePolylines),
              MarkerLayer(markers: _stopMarkers),
            ],
          ),
          if (_isLoading) const Center(child: CircularProgressIndicator()),
        ],
      ),
    );
  }
}
