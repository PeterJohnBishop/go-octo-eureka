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

  bool _isLoading = true;
  String? _selectedRouteId;
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
  Future<void> _loadTripDetails(String tripId) async {
    setState(() => _isLoading = true);
    try {
      final List<StopTime> stopTimes = await dataservice.fetchStopTimesByTripId(
        tripId,
      );
      final List<Shape> shapes = await dataservice.fetchShapeById(tripId);
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
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("Error loading trip details: $e");
      if (mounted) setState(() => _isLoading = false);
    }
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

      Widget markerContent = VehiclePinIcon(
        iconColor: dataservice.colorFromHex(route.routeColor),
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
          child: markerContent,
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
                // if (_selectedVehicleId != null) {
                //   setState(() {
                //     _selectedRouteId = null;
                //     _selectedVehicleId = null;
                //     _refreshMapLayers();
                //   });
                // }
              },
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.flutter_octo_eureka.app',
              ),
              // PolylineLayer(polylines: _activePolylines),
              _vehicleMarkers.isNotEmpty
                  ? MarkerLayer(markers: _vehicleMarkers)
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
