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

  final Map<String, gtfsRoute> _routeMap = {};
  final Map<String, Trip> _tripMap = {};
  final Map<String, Stop> _stopMap = {};
  final Map<String, List<StopTime>> _stopTimesMap = {};

  final Set<String> _processedShapeIds = {};
  List<Polyline> _vehiclePolylines = [];
  List<Marker> _stopMarkers = [];

  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadVehiclePositions();
  }

  // load vehicle positions for position, route ids, and trip ids
  Future<void> _loadVehiclePositions() async {
    try {
      final List<VehiclePositionEntity> vehiclePositions = await gtfs
          .fetchVehiclePositions();

      if (!mounted) return;

      setState(() {
        _vehiclePositions = vehiclePositions;
      });

      // load routes for line colors
      await loadVehicleRoutes(vehiclePositions);

      // load trips for shape ids
      await loadVehicleTrips(vehiclePositions);
    } catch (e) {
      debugPrint("Error fetching vehicle positions: $e");
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
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

    try {
      final List<Future<gtfsRoute>> fetchThese = idsToFetch
          .map((id) => gtfs.fetchRouteById(id))
          .toList();

      final List<gtfsRoute> fetchedRoutes = await Future.wait(fetchThese);

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

    final List<String> idsToFetch = uniqueTripIds
        .where((id) => !_tripMap.containsKey(id))
        .toList();

    if (idsToFetch.isEmpty) return;

    try {
      final List<Trip> newTrips = await Future.wait(
        idsToFetch.map((id) => gtfs.fetchTripById(id)),
      );

      for (var trip in newTrips) {
        _tripMap[trip.tripId] = trip;
      }

      await loadVehicleShapes(newTrips);
      await loadRouteStops(newTrips);
    } catch (e) {
      debugPrint("Error fetching trips: $e");
    }
  }

  Future<void> loadRouteStops(List<Trip> newTrips) async {
    try {
      final List<Future<List<StopTime>>> stopTimeFutures = newTrips
          .map((trip) => gtfs.fetchStopTimesByTripId(trip.tripId))
          .toList();

      final List<List<StopTime>> stopTimeResults = await Future.wait(
        stopTimeFutures,
      );
      final List<StopTime> allStopTimes = stopTimeResults
          .expand((x) => x)
          .toList();

      for (var stopTime in allStopTimes) {
        if (!_stopTimesMap.containsKey(stopTime.stopId)) {
          _stopTimesMap[stopTime.stopId] = [];
        }
        _stopTimesMap[stopTime.stopId]!.add(stopTime);
      }

      final Set<String> uniqueStopIds = allStopTimes
          .map((st) => st.stopId)
          .toSet();

      final List<String> stopIdsToFetch = uniqueStopIds
          .where((id) => !_stopMap.containsKey(id))
          .toList();

      if (stopIdsToFetch.isNotEmpty) {
        final List<Stop> fetchedStops = await Future.wait(
          stopIdsToFetch.map((id) => gtfs.fetchStopById(id)),
        );

        for (var stop in fetchedStops) {
          _stopMap[stop.stopId] = stop;
        }
      }

      _rebuildStopMarkers();
    } catch (e) {
      debugPrint("Error fetching route stops: $e");
    }
  }

  Future<void> loadVehicleShapes(List<Trip> newTrips) async {
    try {
      final Set<String> uniqueShapeIds = newTrips
          .map((t) => t.shapeId)
          .where((id) => id.isNotEmpty && !_processedShapeIds.contains(id))
          .toSet();

      if (uniqueShapeIds.isEmpty) return;

      final Map<String, String> shapeColorMap = {};
      for (var trip in newTrips) {
        if (!uniqueShapeIds.contains(trip.shapeId)) continue;

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

      _processedShapeIds.addAll(uniqueShapeIds);

      _appendShapeData(coloredShapes);
    } catch (e) {
      debugPrint("Error fetching shapes: $e");
    }
  }

  void _rebuildStopMarkers() {

    final List<Marker> markers = _stopMap.values.map((stop) {
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
          child: const Icon(
            Icons.directions_bus,
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

  void _appendShapeData(List<PolyShape> newData) {
    final Map<String, List<PolyShape>> groupedShapes = {};

    for (var point in newData) {
      final String id = point.shapeId;
      if (!groupedShapes.containsKey(id)) {
        groupedShapes[id] = [];
      }
      groupedShapes[id]!.add(point);
    }

    final List<Polyline> newPolylines = [];

    groupedShapes.forEach((id, points) {
      points.sort((a, b) => a.shapePtSequence.compareTo(b.shapePtSequence));

      final List<LatLng> coordinates = points.map((pt) {
        return LatLng(pt.shapePtLat, pt.shapePtLon);
      }).toList();

      final Color polyColor = points.isNotEmpty
          ? points.first.color
          : Colors.green;

      newPolylines.add(
        Polyline(points: coordinates, strokeWidth: 4.0, color: polyColor),
      );
    });

    if (mounted) {
      setState(() {
        _vehiclePolylines.addAll(newPolylines);
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
              initialZoom: 10,
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
