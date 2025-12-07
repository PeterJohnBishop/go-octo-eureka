import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_octo_eureka/maps/gtfsApiService.dart';
import 'package:flutter_octo_eureka/maps/mapService.dart';
import 'package:latlong2/latlong.dart';
import 'package:flutter_octo_eureka/maps/gtfsTypes.dart';

class BaseMapWidget extends StatefulWidget {
  const BaseMapWidget({super.key});

  @override
  State<BaseMapWidget> createState() => _BaseMapWidgetState();
}

class _BaseMapWidgetState extends State<BaseMapWidget> {
  // Services
  final GtfsApiService gtfs = GtfsApiService();
  final MapService mapService = MapService();

  // Core Data
  List<VehiclePositionEntity> _vehiclePositions = [];
  List<gtfsRoute> _routes = [];
  List<Trip> _trips = [];

  // Data Caches
  final Map<String, List<Shape>> _shapeCache = {};
  final Map<String, List<StopTime>> _stopTimeCache = {};
  final Map<String, Stop> _stopCache = {};

  // UI State
  bool _isLoading = true;
  String? _selectedRouteId;
  List<DropdownMenuItem<String>> _routeMenuItems = [];

  // Map Display Lists
  List<Polyline> _activePolylines = [];
  List<Marker> _activeMarkers = [];

  @override
  void initState() {
    super.initState();
    _fetchVehiclePositionsData();
  }

  Future<void> _fetchVehiclePositionsData() async {
    setState(() => _isLoading = true);
    try {
      final positions = await mapService.loadVehiclePositions();
      if (positions.isEmpty) {
        if (mounted) setState(() => _isLoading = false);
        return;
      }

      final results = await Future.wait([
        mapService.loadVehicleRoutes(positions),
        mapService.loadVehicleTrips(positions),
      ]);

      final List<gtfsRoute> routes = results[0] as List<gtfsRoute>;
      final List<Trip> trips = results[1] as List<Trip>;
      final menuItems = mapService.buildRouteDropdownItems(routes);

      await _loadAllActiveData(trips);

      if (mounted) {
        setState(() {
          _vehiclePositions = positions;
          _routes = routes;
          _trips = trips;
          _routeMenuItems = menuItems;
          _isLoading = false;

          _refreshMapLayers();
        });
      }
    } catch (e) {
      debugPrint("Error initializing GTFS data: $e");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _loadAllActiveData(List<Trip> activeTrips) async {
    final shapeLoadFuture = Future(() async {
      final neededShapeIds = activeTrips
          .map((t) => t.shapeId)
          .where((id) => id != null)
          .cast<String>()
          .toSet();

      for (var shapeId in neededShapeIds) {
        if (_shapeCache.containsKey(shapeId)) continue;

        try {
          final shapes = await mapService.loadTripShapes(shapeId);
          _shapeCache[shapeId] = shapes;
        } catch (e) {
          debugPrint("SafeFetch: Error loading shape $shapeId: $e");
        }
      }
    });

    final stopLoadFuture = Future(() async {
      final neededTripIds = activeTrips
          .map((t) => t.tripId)
          .where((id) => id != null)
          .cast<String>()
          .toSet();

      Set<String> foundStopIds = {};

      for (var tripId in neededTripIds) {
        if (_stopTimeCache.containsKey(tripId)) continue;
        try {
          final times = await mapService.loadTripStopTimes(tripId);
          _stopTimeCache[tripId] = times;

          foundStopIds.addAll(times.map((t) => t.stopId).whereType<String>());
        } catch (e) {
          debugPrint("SafeFetch: Error loading stopTimes for $tripId: $e");
        }
      }

      for (var stopId in foundStopIds) {
        if (_stopCache.containsKey(stopId)) continue;
        try {
          final stop = await mapService.loadStop(stopId);
          _stopCache[stopId] = stop;
        } catch (e) {
          debugPrint("SafeFetch: Error loading stop $stopId: $e");
        }
      }
    });

    await Future.wait([shapeLoadFuture, stopLoadFuture]);
  }

  void _refreshMapLayers() {
    if (!mounted) return;

    List<Polyline> newPolylines = [];
    List<Marker> newMarkers = [];

    final visibleTrips = _selectedRouteId == null
        ? _trips
        : _trips.where((t) => t.routeId == _selectedRouteId).toList();

    for (var trip in visibleTrips) {
      if (trip.shapeId != null && _shapeCache.containsKey(trip.shapeId)) {
        final points = _shapeCache[trip.shapeId]!;
        final color = Colors.blue;

        newPolylines.add(
          Polyline(
            points: points
                .map((p) => LatLng(p.shapePtLat, p.shapePtLon))
                .toList(),
            color: color,
            strokeWidth: 4.0,
          ),
        );
      }
    }

    final visibleTripIds = visibleTrips.map((t) => t.tripId).toSet();

    final visibleVehicles = _vehiclePositions.where((v) {
      if (_selectedRouteId == null) return true;
      return visibleTripIds.contains(v.vehicle?.trip?.tripId);
    });

    for (var v in visibleVehicles) {
      final lat = v.vehicle?.position?.latitude;
      final lon = v.vehicle?.position?.longitude;

      if (lat != null && lon != null) {
        newMarkers.add(
          Marker(
            point: LatLng(lat, lon),
            width: 30,
            height: 30,
            child: const Icon(Icons.directions_bus, color: Colors.red),
          ),
        );
      }
    }

    setState(() {
      _activePolylines = newPolylines;
      _activeMarkers = newMarkers;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          FlutterMap(
            options: const MapOptions(
              initialCenter: LatLng(39.7392, -104.9903),
              initialZoom: 12,
              interactionOptions: InteractionOptions(
                flags: InteractiveFlag.all,
              ),
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.flutter_octo_eureka.app',
              ),
              PolylineLayer(polylines: _activePolylines),
              MarkerLayer(markers: _activeMarkers),
            ],
          ),

          SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Card(
                    elevation: 4,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12.0,
                        vertical: 4.0,
                      ),
                      child: DropdownButton<String>(
                        isExpanded: true,
                        hint: const Text("Select Route"),
                        value: _selectedRouteId,
                        items: _routeMenuItems,
                        underline: Container(),
                        onChanged: (value) {
                          setState(() {
                            _selectedRouteId = value;
                            _refreshMapLayers();
                          });
                        },
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          if (_isLoading)
            Container(
              color: Colors.black26,
              child: const Center(child: CircularProgressIndicator()),
            ),
        ],
      ),
    );
  }
}
