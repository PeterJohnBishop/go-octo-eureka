import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_octo_eureka/maps/ApiService.dart';
import 'package:flutter_octo_eureka/maps/dataService.dart';
import 'package:flutter_octo_eureka/maps/gtfsTypes.dart';
import 'package:flutter_octo_eureka/maps/userInterfaceService.dart';
import 'package:intl/intl.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:geolocator/geolocator.dart';

class MapView extends StatefulWidget {
  const MapView({super.key});

  @override
  State<MapView> createState() => _MapViewState();
}

class _MapViewState extends State<MapView> {
  final ApiService api = ApiService();
  final DataService dataService = DataService();
  final UserInterfaceService uiService = UserInterfaceService();
  List<VehiclePositionEntity> _vehiclePositions = [];
  List<VehiclePositionEntity> _selectedVehicles = []; // via dropdown
  List<LatLng> _mappededVehiclePositions = [];
  List<LatLng> _mappedStopPositions = [];
  List<AlertEntity> _alerts = [];
  List<Marker> _vehicleMarkers = [];
  List<gtfsRoute> _routes = [];
  List<AlertEntity> _activeAlerts = [];
  List<Trip> _trips = [];
  List<StopTime> _stopTimes = [];
  List<Stop> _stops = [];
  List<Shape> _shapes = [];
  List<Polyline> _activePolylines = [];
  List<Marker> _activeMarkers = [];
  List<Marker> _stopMarkers = [];
  bool _isLoading = true;
  String? _selectedRouteId;
  String? _selectedVehicleId;
  Timer? _updateTimer;
  MapController _mapController = MapController();
  Marker? _userLocationMarker;
  final LayerHitNotifier<Object> _hitNotifier = ValueNotifier(null);

  @override
  void initState() {
    super.initState();
    _determinePosition();
    Future.delayed(Duration.zero);
    _handleVehiclePositionLoading();
    _startAutoRefresh();
  }

  @override
  void dispose() {
    _updateTimer?.cancel();
    super.dispose();
  }

  void _startAutoRefresh() {
    _updateTimer = Timer.periodic(const Duration(minutes: 2), (timer) async {
      debugPrint("Auto-refreshing GTFS data...");
      await _handleAlertsLoading();
      await Future.delayed(Duration.zero);
      await _handleVehiclePositionLoading();
    });
  }

  // load polylines for routes with stops within 1 mile of the user
  Future<void> _handlePolylineLoading(
    double lat,
    double lon,
    double radius,
  ) async {
    setState(() {
      _activePolylines = [];
    });
    final List<Polyline> tempPolylines = await dataService
        .fetchAndBuildNearPolylines(lat, lon, radius);
    // if (tempPolylines.isEmpty) handle error
    setState(() {
      _activePolylines = tempPolylines;
    });
  }

  // load alerts
  Future<void> _handleAlertsLoading() async {
    setState(() => _isLoading = true);
    _activeAlerts.clear();
    List<AlertEntity> alerts = [];
    List<AlertEntity> activeAlerts = [];
    (alerts, activeAlerts) = await dataService.fetchAlerts(
      _selectedRouteId ?? "",
    );
    // if (alerts.isEmpty || activeAlerts.isEmpty) handle error!!!
    if (mounted) {
      setState(() {
        _alerts = alerts;
        _activeAlerts = activeAlerts;
        _isLoading = false;
      });
    }
  }

  // load vehicle positions
  Future<void> _handleVehiclePositionLoading() async {
    setState(() => _isLoading = true);
    List<VehiclePositionEntity> positions = [];
    List<gtfsRoute> routes = [];
    Map<String, gtfsRoute> uniqueRoutes = {};
    (positions, routes, uniqueRoutes) = await dataService
        .fetchVehiclePositionsData(context);
    // if (positions.isEmpty || routes.isEmpty || menuItems.isEmpty || uniqueRoutes.isEmpty) handle error!!!
    if (mounted) {
      setState(() {
        _vehiclePositions = positions;
        _routes = routes;
        if (_selectedRouteId != null &&
            !uniqueRoutes.containsKey(_selectedRouteId)) {
          _selectedRouteId = null;
          _selectedVehicles = [];
          _vehicleMarkers = [];
          _activePolylines = [];
        }
        _isLoading = false;
      });
    }
  }

  // load trips for selected route
  Future<void> _handleVehicleTripLoading(
    List<VehiclePositionEntity> vehicles,
    String selectedRouteId,
  ) async {
    setState(() => _isLoading = true);
    List<VehiclePositionEntity> selectedVehicles = [];
    List<Trip> trips = [];
    (selectedVehicles, trips) = await dataService.fetchSelectedVehicles(
      vehicles,
      selectedRouteId,
    );
    // if (selectedVehicles.isEmpty || trips.isEmpty) handle error!!!
    if (mounted) {
      setState(() {
        _selectedVehicles = selectedVehicles;
        _trips = trips;
      });
    }
    if (_selectedRouteId != null) {
      await _handleRouteTripDetailLoading(trips, _selectedRouteId!);
    }
    _handleVehicleMarkers();
  }

  Future<void> _handleRouteTripDetailLoading(
    List<Trip> trips,
    String routeId,
  ) async {
    setState(() => _isLoading = true);
    var route = _routes.firstWhere((r) => r.routeId == routeId);
    final colorFromHex = uiService.colorFromHex(route.routeColor);
    List<StopTime> allStopTimes = [];
    List<Stop> allStops = [];
    Map<String, List<Shape>> allShapes = {};
    (allStopTimes, allStops, allShapes) = await dataService
        .fetchRouteTripDetails(_routes, trips, routeId, colorFromHex);
    // if (allStopTimes.isEmpty || allStops.isEmpty || allShapes.isEmpty) handle error!!!
    _mappedStopPositions.clear();
    for (var shapeList in allShapes.values) {
      for (var s in shapeList) {
        _mappedStopPositions.add(LatLng(s.shapePtLat, s.shapePtLon));
      }
    }
    if (mounted) {
      setState(() {
        _stopTimes = allStopTimes;
        _stops = allStops;
        _shapes = allShapes.values.expand((x) => x).toList();

        _activePolylines = [];
        allShapes.forEach((id, shapeList) {
          _activePolylines.addAll(
            uiService.buildTripPolyline(null, shapeList, colorFromHex),
          );
        });
        _stopMarkers = uiService.buildSimpleStopMarkers(_stops, colorFromHex);
        _zoomToFit(_mappedStopPositions);
        _isLoading = false;
      });
      _handleVehicleMarkers();
    }
  }

  Future<void> _handleTripDetailLoading(
    String tripId,
    Color colorFromHex,
  ) async {
    setState(() => _isLoading = true);
    List<Shape> shapes = [];
    List<StopTime> stopTimes = [];
    List<Stop> stops = [];
    VehiclePositionEntity selectedVehicle = _selectedVehicles.firstWhere(
      (v) => v.id == _selectedVehicleId,
      orElse: () => _selectedVehicles.first,
    );

    (shapes, stopTimes, stops) = await dataService.fetchTripDetails(
      _trips,
      tripId,
    );
    // if (shapes.isEmpty || stopTimes.isEmpty || stops.isEmpty) handle error!!!
    if (mounted) {
      _mappedStopPositions.clear();
      for (var shape in shapes) {
        _mappedStopPositions.add(LatLng(shape.shapePtLat, shape.shapePtLon));
      }
      setState(() {
        _shapes = shapes;
        _stopTimes = stopTimes;
        _stops = stops;
      });
      _activePolylines = uiService.buildTripPolyline(
        null, // Hit value can be null or tripId
        shapes,
        colorFromHex,
      );
      _stopMarkers = uiService.buildStopMarkers(
        selectedVehicle,
        _stopTimes,
        stops,
        colorFromHex,
      );
      _handleVehicleMarkers();
      _isLoading = false;
    }
  }

  void _handleVehicleMarkers() {
    final (newMarkers, newPositions) = dataService.fetchVehicleMarkers(
      selectedVehicles: _selectedVehicles,
      routes: _routes,
      trips: _trips,
      stops: _stops,
      stopTimes: _stopTimes,
      selectedRouteId: _selectedRouteId,
      selectedVehicleId: _selectedVehicleId,
      onVehicleTap: (vehicle, iconColor) {
        setState(() {
          _selectedVehicleId = vehicle.id;
          _stopTimes = [];
          _shapes = [];
          _stops = [];
          _stopMarkers = [];
          _activePolylines = [];
        });
        _handleVehicleMarkers();
        _handleTripDetailLoading(vehicle.vehicle.trip.tripId, iconColor);
      },
    );

    setState(() {
      _vehicleMarkers = newMarkers;
      _mappededVehiclePositions = newPositions;
      _activeMarkers = [..._stopMarkers, ..._vehicleMarkers];
    });
  }

  Future<void> _determinePosition() async {
    // 1. Define Denver constants
    const double denverLat = 39.7452;
    const double denverLon = -104.9922;
    const double hundredMilesInMeters = 160934.0;

    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      debugPrint('Location services are disabled.');
      return;
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        debugPrint('Location permissions are denied');
        return;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      debugPrint('Location permissions are permanently denied.');
      return;
    }

    Position position = await Geolocator.getCurrentPosition();

    // Calculate distance from Denver
    double distanceInMeters = Geolocator.distanceBetween(
      position.latitude,
      position.longitude,
      denverLat,
      denverLon,
    );

    double finalLat = position.latitude;
    double finalLon = position.longitude;

    if (distanceInMeters > hundredMilesInMeters) {
      debugPrint('User is > 100 miles from Denver');
      finalLat = denverLat;
      finalLon = denverLon;

      position = Position(
        latitude: denverLat,
        longitude: denverLon,
        timestamp: DateTime.now(),
        accuracy: 0.0,
        altitude: 0.0,
        heading: 0.0,
        speed: 0.0,
        speedAccuracy: 0.0,
        altitudeAccuracy: 0.0,
        headingAccuracy: 0.0,
      );
    }

    _updateUserMarker(position);
    _handlePolylineLoading(finalLat, finalLon, 1.0);
  }

  void _updateUserMarker(Position position) {
    setState(() {
      _userLocationMarker = Marker(
        point: LatLng(position.latitude, position.longitude),
        width: 35.0,
        height: 35.0,
        child: Icon(
                Icons.person_pin_circle_sharp,
                color: Colors.yellow[900],
                size: 40.0,
              ),
      );
      _mapController.move(LatLng(position.latitude, position.longitude), 13.0);
    });
  }

  void _zoomIn() {
    final currentZoom = _mapController.camera.zoom;
    _mapController.move(_mapController.camera.center, currentZoom + 1);
  }

  void _zoomOut() {
    final currentZoom = _mapController.camera.zoom;
    _mapController.move(_mapController.camera.center, currentZoom - 1);
  }

  void _zoomToFit(List<LatLng> positions) {
    if (positions.isEmpty) return;

    if (positions.length == 1 ||
        positions.every(
          (p) =>
              p.latitude == positions.first.latitude &&
              p.longitude == positions.first.longitude,
        )) {
      _mapController.move(positions.first, 14.0);
      return;
    }
    try {
      final bounds = LatLngBounds.fromPoints(positions);
      _mapController.fitCamera(
        CameraFit.bounds(bounds: bounds, padding: const EdgeInsets.all(50.0)),
      );
    } catch (e) {
      debugPrint("Zoom error: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          FloatingActionButton.small(
            heroTag: "zoom_in",
            onPressed: _zoomIn,
            backgroundColor: Colors.white,
            foregroundColor: Colors.black,
            child: const Icon(Icons.add),
          ),
          const SizedBox(height: 8),
          FloatingActionButton.small(
            heroTag: "zoom_out",
            onPressed: _zoomOut,
            backgroundColor: Colors.white,
            foregroundColor: Colors.black,
            child: const Icon(Icons.remove),
          ),
          const SizedBox(height: 16),
          FloatingActionButton.small(
            elevation: 4,
            backgroundColor: Colors.white,
            onPressed: () async {
              setState(() {
                _selectedRouteId = null;
                _selectedVehicleId = null;
                _activePolylines = [];
                _activeMarkers = [];
                _vehicleMarkers = [];
                _stopMarkers = [];
                _stopTimes = [];
                _shapes = [];
                _stops = [];
              });
              await _determinePosition();
              setState(() => _isLoading = false);
            },
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 5, horizontal: 5),
              child: Icon(
                Icons.person_pin_circle_sharp,
                color: Colors.yellow[900],
                size: 28.0,
              ),
            ),
          ),
        ],
      ),

      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: LatLng(39.747538, -104.866624),
              initialZoom: 12,
              interactionOptions: InteractionOptions(
                flags: InteractiveFlag.all,
              ),
              onTap: (tapPosition, point) {
                setState(() {
                  _selectedRouteId = null;
                  _selectedVehicleId = null;
                  _activePolylines = [];
                  _activeMarkers = [];
                  _vehicleMarkers = [];
                  _stopMarkers = [];
                  _stopTimes = [];
                  _shapes = [];
                  _stops = [];
                });
                // _loadTrips(_vehiclePositions);
                _determinePosition();
              },
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.flutter_octo_eureka.app',
              ),
              _activePolylines.isNotEmpty
                  ? GestureDetector(
                      onTap: () {
                        final hitResult = _hitNotifier.value;
                        if (hitResult != null) {
                          final hitValues = hitResult.hitValues;
                          if (hitValues.isNotEmpty) {
                            final tappedData = hitValues.first;
                            setState(() {
                              _selectedVehicles = [];
                              _trips = [];
                              _stopTimes = [];
                              _shapes = [];
                              _stops = [];
                              _activePolylines = [];
                              _activeMarkers = [];
                              _vehicleMarkers = [];
                              _stopMarkers = [];
                              _selectedRouteId = "$tappedData";
                            });
                            _handleVehicleTripLoading(
                              _vehiclePositions,
                              "$tappedData",
                            );
                          }
                        }
                      },
                      child: PolylineLayer(
                        hitNotifier: _hitNotifier,
                        polylines: _activePolylines,
                        cullingMargin: 50.0,
                      ),
                    )
                  : Container(),
              _vehicleMarkers.isNotEmpty
                  ? MarkerLayer(
                      markers: [
                        ..._activeMarkers,
                        if (_userLocationMarker != null) _userLocationMarker!,
                      ],
                    )
                  : _userLocationMarker != null
                  ? MarkerLayer(markers: [_userLocationMarker!])
                  : Container(),
              RichAttributionWidget(
                alignment: AttributionAlignment.bottomLeft,
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
                  padding: EdgeInsets.all(8),
                  child: SearchAnchor(
                    builder: (context, controller) {
                      return SearchBar(
                        controller: controller,
                        hintText: "Search for a route...",
                        onTap: () => controller.openView(),
                        onChanged: (_) => controller.openView(),
                        leading: const Icon(Icons.search),
                      );
                    },
                    suggestionsBuilder: (context, controller) {
                      final keyword = controller.text.toLowerCase();

                      final filteredRoutes = _routes.where((route) {
                        final name =
                            "${route.routeShortName} ${route.routeLongName}"
                                .toLowerCase();
                        return name.contains(keyword);
                      }).toList();

                      
                      return uiService.buildSearchListTiles(
                        context,
                        filteredRoutes,
                        _alerts,
                        (selectedRoute) {
                        
                          controller.closeView(selectedRoute);

                          WidgetsBinding.instance.addPostFrameCallback((_) {
                            if (!mounted) return;

                            setState(() {
                              _selectedVehicles = [];
                              _trips = [];
                              _stopTimes = [];
                              _shapes = [];
                              _stops = [];
                              _activePolylines = [];
                              _activeMarkers = [];
                              _vehicleMarkers = [];
                              _stopMarkers = [];
                              _selectedRouteId = selectedRoute;
          
                              if (selectedRoute != null) {
                                _handleVehicleTripLoading(
                                  _vehiclePositions,
                                  selectedRoute,
                                );
                              }
                              ;
                            });
                          });
                        },
                      );
                    },
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
