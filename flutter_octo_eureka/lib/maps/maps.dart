import 'dart:async';
import 'dart:math';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
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
  final Dataservice dataservice = Dataservice();
  final UserInterfaceService uiService = UserInterfaceService();
  List<VehiclePositionEntity> _vehiclePositions = [];
  List<VehiclePositionEntity> _selectedVehicles = []; // via dropdown
  List<LatLng> _mappededVehiclePositions = [];
  List<LatLng> _mappedStopPositions = [];
  List<AlertEntity> _alerts = [];
  List<Marker> _vehicleMarkers = [];
  List<gtfsRoute> _routes = [];
  List<DropdownMenuItem<String>> _routeMenuItems = [];
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

  @override
  void initState() {
    super.initState();
    _determinePosition();
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
      _fetchAlerts();
    });
  }

  Future<void> _fetchAndBuildNearPolylines(double lat, double lon) async {
    try {
      final data = await dataservice.fetchRouteTripShapes(lat, lon);
      if (data.isEmpty) return;

      final uniqueRouteIds = data.map((d) => d.routeId).toSet();
      final uniqueShapeIds = data.map((d) => d.shapeId).toSet();

      debugPrint("DEBUG: Shape IDs found: $uniqueShapeIds");

      final results = await Future.wait([
        Future.wait(uniqueRouteIds.map((id) => dataservice.fetchRouteById(id))),
        Future.wait(uniqueShapeIds.map((id) => dataservice.fetchShapeById(id))),
      ]);

      final routesList = results[0] as List<gtfsRoute>;
      final shapesList = results[1] as List<List<Shape>>;

      final routeMap = {for (var r in routesList) r.routeId: r};

      final shapeMap = <String, List<Shape>>{};
      for (var list in shapesList) {
        if (list.isNotEmpty) {
          shapeMap[list.first.shapeId] = list;
        }
      }

      final List<Polyline> tempPolylines = [];

      for (var d in data) {
        final route = routeMap[d.routeId];
        final List<Shape>? shapePoints = shapeMap[d.shapeId];

        if (route != null && shapePoints != null && shapePoints.isNotEmpty) {
          final color = uiService.colorFromHex(route.routeColor);

          tempPolylines.addAll(uiService.buildTripPolyline(shapePoints, color));
        }
      }

      if (mounted) {
        setState(() {
          _activePolylines = tempPolylines;
        });
      }
    } catch (e) {
      debugPrint("Error processing polylines: $e");
    }
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

      await _fetchAlerts();
      await Future.delayed(Duration.zero);

      final List<gtfsRoute> rawRoutes = await dataservice.loadVehicleRoutes(
        positions,
      );

      final uniqueRoutes = <String, gtfsRoute>{};
      for (var route in rawRoutes) {
        if (!uniqueRoutes.containsKey(route.routeId)) {
          uniqueRoutes[route.routeId] = route;
        }
      }
      final cleanRoutesList = uniqueRoutes.values.toList();

      cleanRoutesList.sort((a, b) {
        String getKey(String fullString) {
          if (fullString.isEmpty) return "";
          final index = fullString.indexOf(':');
          if (index == -1) return fullString.trim();
          return fullString.substring(0, index).trim();
        }

        bool isNumeric(String s) => RegExp(r'^\d').hasMatch(s);
        bool isSingleLetter(String s) => s.length == 1 && !isNumeric(s);

        int getRank(String key) {
          if (isSingleLetter(key)) return 2;
          if (isNumeric(key)) return 1;
          return 0;
        }

        String keyA = getKey(a.routeShortName);
        String keyB = getKey(b.routeShortName);

        int rankA = getRank(keyA);
        int rankB = getRank(keyB);

        if (rankA != rankB) {
          return rankA.compareTo(rankB);
        }

        if (rankA == 1) {
          int getNumber(String s) {
            final match = RegExp(r'^\d+').firstMatch(s);
            return match != null ? int.parse(match.group(0)!) : 0;
          }

          int diff = getNumber(keyA).compareTo(getNumber(keyB));
          return diff == 0 ? keyA.compareTo(keyB) : diff;
        } else {
          return keyA.compareTo(keyB);
        }
      });

      final menuItems = uiService.buildRouteDropdownItems(
        context,
        cleanRoutesList,
        _alerts,
      );

      if (mounted) {
        setState(() {
          _vehiclePositions = positions;
          _routes = cleanRoutesList;
          _routeMenuItems = menuItems;

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
    } catch (e) {
      debugPrint("Error initializing GTFS data: $e");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // fetch alerts for selected route
  Future<void> _fetchAlerts() async {
    _activeAlerts.clear();
    List<AlertEntity> selectedAlerts = [];
    try {
      final alerts = await dataservice.fetchAlerts();
      if (alerts.isEmpty) return;
      for (var alert in alerts) {
        for (var r in alert.alert.informedEntity) {
          if (r.routeId == _selectedRouteId) {
            selectedAlerts.add(alert);
          }
        }
      }
      setState(() {
        _alerts = alerts;
        _activeAlerts = selectedAlerts;
      });
    } catch (e) {
      debugPrint("Error loading alerts: $e");
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

  // if vehicle tapped, load trip details
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

      _mappedStopPositions.clear();
      for (var shape in shapes) {
        _mappedStopPositions.add(LatLng(shape.shapePtLat, shape.shapePtLon));
      }

      var stops = <Stop>[];
      if (stopTimes.isNotEmpty) {
        stops = await Future.wait(
          stopTimes.map((st) => dataservice.fetchStopById(st.stopId)),
        );
      }

      var selectedVehicle = _selectedVehicles.firstWhere((v) {
        return v.id == _selectedVehicleId;
      });

      if (mounted) {
        setState(() {
          _stopTimes = stopTimes;
          List<Shape> optimizedShapes = shapes;
          if (shapes.length > 500) {
            optimizedShapes = [];
            for (int i = 0; i < shapes.length; i++) {
              // Keep first, last, and every nth point
              if (i == 0 || i == shapes.length - 1 || i % 3 == 0) {
                optimizedShapes.add(shapes[i]);
              }
            }
          }
          _shapes = optimizedShapes;
          _stops = stops;
          _activePolylines = uiService.buildTripPolyline(shapes, colorFromHex);

          _stopMarkers = uiService.buildStopMarkers(
            selectedVehicle,
            _stopTimes,
            stops,
            colorFromHex,
          );
          // _zoomToFit(_mappedStopPositions);
          _isLoading = false;
        });
        _showVehicles();
      }
    } catch (e) {
      debugPrint("Error loading trip details: $e");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showVehicles() {
    _vehicleMarkers.clear();
    _mappededVehiclePositions.clear();

    VehiclePositionEntity? targetVehicleToZoom;

    for (var vehicle in _selectedVehicles) {
      final lat = vehicle.vehicle.position.latitude;
      final lon = vehicle.vehicle.position.longitude;
      _mappededVehiclePositions.add(LatLng(lat, lon));

      final bool isSelectedCurrent = _selectedVehicleId == vehicle.id;

      if (isSelectedCurrent) {
        targetVehicleToZoom = vehicle;
      }

      final route = _routes.firstWhere(
        (route) => route.routeId == _selectedRouteId,
        orElse: () => _routes.first,
      );

      IconData iconData;
      if (route.routeType == 0 || route.routeType == 2) {
        iconData = Icons.train;
      } else {
        iconData = Icons.directions_bus;
      }

      final bearing = vehicle.vehicle.position.bearing;
      final double bearingRadians = bearing * (pi / 180);
      final Color iconColor = uiService.colorFromHex(route.routeColor);

      final unixTimestamp = vehicle.vehicle.timestamp;
      final DateTime date = DateTime.fromMillisecondsSinceEpoch(
        unixTimestamp * 1000,
      );
      final String formattedTime = DateFormat('h:mm a').format(date);

      Widget markerContent = VehiclePinIcon(
        iconColor: iconColor,
        vehicleIconData: iconData,
        size: 45.0,
        bearing: bearingRadians,
      );

      if (isSelectedCurrent) {
        final trip = _trips.firstWhere(
          (t) => t.tripId == vehicle.vehicle.trip.tripId,
          orElse: () => _trips.first,
        );

        Stop? currentStop;
        try {
          currentStop = _stops.firstWhere(
            (s) => s.stopId == vehicle.vehicle.stopId,
          );
        } catch (e) {
          currentStop = null;
        }

        markerContent = VehicleMarkerMenu(
          isBus: route.routeType == 0 || route.routeType == 2 ? false : true,
          headsign: trip.tripHeadsign,
          timestamp: formattedTime,
          status: vehicle.vehicle.currentStatus,
          stop: currentStop,
          onCompassPressed: () => debugPrint("Compass tapped"),
          onWarningPressed: () => debugPrint("Warning tapped"),
          onInfoPressed: () => debugPrint("Info tapped"),
          vehicle: vehicle,
          stopTimes: _stopTimes,
          stops: _stops,
          child: markerContent,
        );
      } else {
        markerContent = GestureDetector(
          onTap: () {
            setState(() {
              _selectedVehicleId = vehicle.id;
              _stopTimes = [];
              _shapes = [];
              _stops = [];
              _stopMarkers = [];
            });

            _showVehicles();
            _loadTripDetails(vehicle.vehicle.trip.tripId, iconColor);
          },
          child: markerContent,
        );
      }

      final double baseSize = isSelectedCurrent ? 120.0 : 50.0;

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
      _activeMarkers = [..._stopMarkers, ..._vehicleMarkers];

      if (targetVehicleToZoom != null) {
        var vlong = targetVehicleToZoom!.vehicle.position.longitude;
        var vlat = targetVehicleToZoom!.vehicle.position.latitude;

        _mapController.move(LatLng(vlat, vlong), 14.0);
      } else {
        _zoomToFit(_mappededVehiclePositions);
      }
      _isLoading = false;
    });
  }

  Future<void> _determinePosition() async {
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

    var position = await Geolocator.getCurrentPosition();
    _updateUserMarker(position);
    _fetchAndBuildNearPolylines(position.latitude, position.longitude);
  }

  void _updateUserMarker(Position position) {
    setState(() {
      _userLocationMarker = Marker(
        point: LatLng(position.latitude, position.longitude),
        width: 35.0,
        height: 35.0,
        child: const Icon(
          Icons.person_pin_circle_sharp,
          color: Colors.blue,
          size: 35.0,
        ),
      );
      _mapController.move(LatLng(position.latitude, position.longitude), 15.0);
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
              setState(() => _isLoading = true);
              await _determinePosition();
              setState(() => _isLoading = false);
            },
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 5, horizontal: 5),
              child: const Icon(
                Icons.person_pin_circle_sharp,
                color: Colors.blue,
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
                  ? PolylineLayer(
                      polylines: _activePolylines,
                      cullingMargin: 50.0,
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
                              borderRadius: BorderRadius.circular(20),
                              isExpanded: true,
                              itemHeight: null,
                              hint: const Text("Select Route"),
                              value:
                                  _routeMenuItems.any(
                                    (item) => item.value == _selectedRouteId,
                                  )
                                  ? _selectedRouteId
                                  : null,
                              items: _routeMenuItems,
                              underline: Container(),
                              onChanged: (value) {
                                setState(() {
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
