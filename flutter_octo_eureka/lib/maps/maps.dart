import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_octo_eureka/maps/dataService.dart';
import 'package:flutter_octo_eureka/maps/gtfsTypes.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';

class MapView extends StatefulWidget {
  const MapView({super.key});

  @override
  State<MapView> createState() => _MapViewState();
}

class _MapViewState extends State<MapView> {
  final Dataservice dataservice = Dataservice();

  List<VehiclePositionEntity> _vehiclePositions = [];
  List<VehiclePositionEntity> _selectedVehicles = [];
  List<Marker> _vehicleMarkers = [];
  List<gtfsRoute> _routes = [];
  List<DropdownMenuItem<String>> _routeMenuItems = [];
  List<Trip> _trips = [];
  List<StopTime> _stopTimes = [];
  List<Shape> _shapes = [];
  List<Stop> _stops = [];
  List<Polyline> _activePolylines = [];
  List<Marker> _activeMarkers = [];
  List<Marker> _stopMarkers = [];

  bool _isLoading = true;
  String? _selectedRouteId;
  String? _selectedVehicleId;

  Timer? _updateTimer;

  @override
  void initState() {
    super.initState();
    _fetchVehiclePositionsData();
    _startAutoRefresh();
  }

  @override
  void dispose() {
    _updateTimer?.cancel();
    super.dispose();
  }

  void _startAutoRefresh() {
    _updateTimer = Timer.periodic(const Duration(minutes: 2), (timer) {
      debugPrint("Auto-refreshing GTFS data...");
      _fetchVehiclePositionsData();
    });
  }

  // fetch real time vehicle data
  // provides route_id to populate the inital route menu
  // provides trip_id to populate stop, stop time, and shape data
  Future<void> _fetchVehiclePositionsData() async {
    setState(() => _isLoading = true);
    try {
      final positions = await dataservice.fetchVehiclePositions();
      if (positions.isEmpty) {
        if (mounted) setState(() => _isLoading = false);
        return;
      }
      final List<gtfsRoute> routes = await dataservice.loadVehicleRoutes(
        positions,
      );
      final menuItems = dataservice.buildRouteDropdownItems(routes);
      if (mounted) {
        setState(() {
          _vehiclePositions = positions;
          _routes = routes;
          _routeMenuItems = menuItems;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("Error initializing GTFS data: $e");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // load trips for selected route to draw vehicles
  Future<void> _loadTrips(List<VehiclePositionEntity> vehicles) async {
    setState(() => _isLoading = true);
    final selectedVehicles = vehicles.where((entity) {
      return entity.vehicle.trip.routeId == _selectedRouteId;
    }).toList();
    if (selectedVehicles.isEmpty) return;
    try {
      final results = await Future.wait(
        selectedVehicles.map(
          (v) => dataservice.fetchTripById(v.vehicle.trip.tripId),
        ),
      );
      if (results.isEmpty) return;
      final trips = results.whereType<Trip>().toList();
      if (trips.isEmpty) return;
      if (mounted) {
        setState(() {
          _selectedVehicles = selectedVehicles;
          _trips = trips;
          _isLoading = false;
        });
        _showVehicles();
      }
    } catch (e) {
      debugPrint("Error loading trips: $e");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // if vehicle tapped, draw trip details
  Future<void> _loadTripDetails(String tripId, Color colorFromHex) async {
    setState(() => _isLoading = true);
    final trip = _trips.firstWhere((t) {
      return t.tripId == tripId;
    });
    try {
      final List<Shape> shapes = await dataservice.fetchShapeById(trip.shapeId);
      final List<StopTime> stopTimes = await dataservice.fetchStopTimesByTripId(
        tripId,
      );

      var stops = <Stop>[];
      if (stopTimes.isNotEmpty) {
        stops = await Future.wait(
          stopTimes.map((st) => dataservice.fetchStopById(st.stopId)),
        );
      }

      if (mounted) {
        setState(() {
          _stopTimes = stopTimes;
          _shapes = shapes;
          _stops = stops;
          _buildTripPolyline(shapes, colorFromHex);
          _buildStopMarkers(stops);
          _activeMarkers = [..._vehicleMarkers, ..._stopMarkers];
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("Error loading trip details: $e");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _buildTripPolyline(List<Shape> shapes, Color colorFromHex) {
    shapes.sort((a, b) => a.shapePtSequence.compareTo(b.shapePtSequence));

    final points = shapes
        .map((s) => LatLng(s.shapePtLat, s.shapePtLon))
        .toList();

    final polyline = Polyline(
      points: points,
      strokeWidth: 4.0,
      color: colorFromHex,
    );

    setState(() {
      _activePolylines = [polyline];
    });
  }

  void _buildStopMarkers(List<Stop> stops) {
    List<Marker> newStopMarkers = [];

    for (var stop in stops) {
      newStopMarkers.add(
        Marker(
          point: LatLng(stop.stopLat, stop.stopLon),
          width: 16.0,
          height: 16.0,
          alignment: Alignment.center,
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.black, width: 2),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.2),
                  blurRadius: 2,
                  offset: const Offset(0, 1),
                ),
              ],
            ),
            child: Center(
              child: Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  color: Colors.black,
                  shape: BoxShape.circle,
                ),
              ),
            ),
          ),
        ),
      );
    }

    setState(() {
      _stopMarkers = newStopMarkers;
    });
  }

  void _showVehicles() {
    setState(() => _isLoading = true);
    for (var vehicle in _selectedVehicles) {
      final lat = vehicle.vehicle.position.latitude;
      final lon = vehicle.vehicle.position.longitude;
      final route = _routes.firstWhere(
        (route) => route.routeId == _selectedRouteId,
      );
      IconData iconData;
      if (route.routeType == 0 || route.routeType == 2) {
        iconData = Icons.train;
      } else {
        iconData = Icons.directions_bus;
      }
      final bearing = vehicle.vehicle.position.bearing;
      final double bearingRadians = bearing * (pi / 180);
      final double baseSize = 50.0;
      final Color iconColor = dataservice.colorFromHex(route.routeColor);

      Widget markerContent = VehiclePinIcon(
        iconColor: iconColor,
        vehicleIconData: iconData,
        size: 45.0,
        bearing: bearingRadians,
      );

      _vehicleMarkers.add(
        Marker(
          point: LatLng(lat, lon),
          width: baseSize,
          height: baseSize,
          alignment: Alignment.center,
          child: GestureDetector(
            onTap: () {
              setState(() {
                _selectedVehicleId = vehicle.id;
              });
              _loadTripDetails(vehicle.vehicle.trip.tripId, iconColor);
            },
            child: markerContent,
          ),
        ),
      );
    }
    setState(() {
      _activeMarkers = [..._vehicleMarkers];
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          FlutterMap(
            options: MapOptions(
              initialCenter: LatLng(39.7392, -104.9903),
              initialZoom: 12,
              interactionOptions: InteractionOptions(
                flags: InteractiveFlag.all,
              ),
              onTap: (tapPosition, point) {
                if (_selectedVehicleId != null) {
                  setState(() {
                    _selectedVehicleId = null;
                    _activePolylines = [];
                    _activeMarkers = [];
                    _vehicleMarkers = [];
                    _stopMarkers = [];
                    _stopTimes = [];
                    _shapes = [];
                    _stops = [];
                    _loadTrips(_vehiclePositions);
                  });
                }
              },
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.flutter_octo_eureka.app',
              ),
              _activePolylines.isNotEmpty
                  ? PolylineLayer(polylines: _activePolylines)
                  : Container(),
              // PolylineLayer(polylines: _activePolylines),
              _vehicleMarkers.isNotEmpty
                  ? MarkerLayer(markers: _activeMarkers)
                  : Container(),
              RichAttributionWidget(
                attributions: [
                  TextSourceAttribution(
                    'OpenStreetMap contributors',
                    onTap: () => launchUrl(
                      Uri.parse('https://openstreetmap.org/copyright'),
                    ),
                  ),
                ],
              ),
            ],
          ),
          SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Card(
                    elevation: 4,
                    child: Row(
                      children: [
                        Expanded(
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
                                  // clear any previous selections
                                  _selectedVehicles = [];
                                  _trips = [];
                                  _stopTimes = [];
                                  _shapes = [];
                                  _stops = [];
                                  _activePolylines = [];
                                  _activeMarkers = [];
                                  _vehicleMarkers = [];
                                  // set selected route
                                  _selectedRouteId = value;
                                });
                                _loadTrips(_vehiclePositions);
                              },
                            ),
                          ),
                        ),

                        Container(
                          width: 1,
                          height: 32,
                          color: Colors.grey.shade300,
                        ),

                        _isLoading
                            ? Padding(
                                padding: EdgeInsets.all(8),
                                child: CircularProgressIndicator(),
                              )
                            : IconButton(
                                icon: const Icon(Icons.refresh),
                                color: Colors.grey[700],
                                tooltip: 'Refresh Routes',
                                onPressed: () {
                                  setState(() {
                                    _fetchVehiclePositionsData();
                                  });
                                },
                              ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
