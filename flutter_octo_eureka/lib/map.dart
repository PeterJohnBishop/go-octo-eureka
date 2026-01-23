import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_octo_eureka/maps/gtfsTypes.dart';
import 'package:flutter_octo_eureka/maps/userInterfaceService.dart';
import 'package:flutter_octo_eureka/proto/proto.dart';
import 'package:flutter_octo_eureka/proto/protoTypes.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_polyline_algorithm/google_polyline_algorithm.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';

class MapView extends StatefulWidget {
  const MapView({super.key});

  @override
  State<MapView> createState() => _MapViewState();
}

class _MapViewState extends State<MapView> {
  final ProtoService proto = ProtoService();
  final UserInterfaceService ui = UserInterfaceService();
  bool _isLoading = true;
  List<RouteItem> _menuItems = [];
  List<RouteDetail> _activeRouteDetails = [];
  List<VehiclePositionEntity> _vehiclePositions = [];
  List<AlertEntity> _activeAlerts = [];
  List<TripUpdateEntity> _tripUpdates = [];
  List<Polyline> _activePolylines = [];
  MapController _mapController = MapController();
  SearchController _searchController = SearchController();
  Marker? _userLocationMarker;
  Timer? _updateTimer;
  String? _selectedRouteId;

  @override
  void initState() {
    super.initState();
    _determinePosition();
    _handleRouteMenuLoading();
    _handleVehiclePositionLoading();
    _handleActiveAlertsLoading();
    _handleTripUpdatesLoading();
    _startAutoRefresh();
  }

  @override
  void dispose() {
    _updateTimer?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _determinePosition() async {
    // default to Denver if user location is 150+ miles away from Denver
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
  }

  // aut0o-refresh data
  void _startAutoRefresh() {
    _updateTimer = Timer.periodic(const Duration(minutes: 2), (timer) async {
      debugPrint("Auto-refreshing GTFS data...");
      await _handleVehiclePositionLoading();
      await _handleActiveAlertsLoading();
      await _handleTripUpdatesLoading();
      await _handleRouteMenuLoading();
    });
  }

  // load basic route protobuf data for search menu
  Future<void> _handleRouteMenuLoading() async {
    setState(() => _isLoading = true);
    List<RouteItem> menuItems = [];
    menuItems = await proto.fetchRouteMenuItems();
    if (mounted) {
      setState(() {
        _menuItems = menuItems;
        _isLoading = false;
      });
    }
  }

  // load vehicle position entity protobuf data from gtfs-rt feed
  Future<void> _handleVehiclePositionLoading() async {
    setState(() => _isLoading = true);
    List<VehiclePositionEntity> positions = [];
    positions = await proto.fetchVehiclePositions();
    if (mounted) {
      setState(() {
        _vehiclePositions = positions;
        _isLoading = false;
      });
    }
  }

  // load active alert entity protobuf data from gtfs-rt feed
  Future<void> _handleActiveAlertsLoading() async {
    setState(() => _isLoading = true);
    List<AlertEntity> alerts = [];
    alerts = await proto.fetchAlerts();
    if (mounted) {
      setState(() {
        _activeAlerts = alerts;
        _isLoading = false;
      });
    }
  }

  // load active trip update entity protobuf data from gtfs-rt feed
  Future<void> _handleTripUpdatesLoading() async {
    setState(() => _isLoading = true);
    List<TripUpdateEntity> updates = [];
    updates = await proto.fetchTripUpdates();
    if (mounted) {
      setState(() {
        _tripUpdates = updates;
        _isLoading = false;
      });
    }
  }

  Future<void> _handleRouteLoading(String routeId) async {
    setState(() => _isLoading = true);
    List<RouteDetail> routeDetail = [];
    routeDetail = await proto.fetchRouteDetailsByRouteId(routeId);
    List<LatLng> routePoints = []; 
    Color routeColor = Color.fromARGB(0, 0, 0, 0);
    
      routePoints.addAll(_decodePolyline(routeDetail[0].encodedPolyline));
      routeColor = ui.colorFromHex(routeDetail[0].routeColor);
    
    List<Polyline> routePolylines = ui.buildTripPolyline(routeId, routePoints, routeColor);
    if (mounted) {
      setState(() {
        _activeRouteDetails = routeDetail;
        _activePolylines = routePolylines;
        _isLoading = false;
        _zoomToFit(routePoints);
      });
    }
  }

  List<LatLng> _decodePolyline(String encoded) {
    final List<List<num>> points = decodePolyline(encoded);
    return points
        .map((point) => LatLng(point[0].toDouble(), point[1].toDouble()))
        .toList();
  }

  void _updateUserMarker(Position position) {
    setState(() {
      _userLocationMarker = Marker(
        point: LatLng(position.latitude, position.longitude),
        width: 35.0,
        height: 35.0,
        child: Icon(Icons.man_3, color: Colors.yellow[900], size: 40.0),
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
        CameraFit.bounds(bounds: bounds, padding: const EdgeInsets.all(75.0)),
      );
    } catch (e) {
      debugPrint("Zoom error: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    var size = MediaQuery.sizeOf(context);
    var isPortrait = size.height > size.width;

    return Scaffold(
      appBar: AppBar(
        title: const Text('GoFind', style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.black,
        elevation: 4,
        shadowColor: Colors.black.withValues(alpha: 4),
        actions: <Widget>[],
      ),
      floatingActionButton: Column(
        mainAxisAlignment: isPortrait
            ? MainAxisAlignment.center
            : MainAxisAlignment.end,
        children: [
          FloatingActionButton.small(
            elevation: 10,
            backgroundColor: Colors.white,
            onPressed: () async {
              // TBD
            },
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 5, horizontal: 5),
              child: Icon(
                Icons.transform_outlined,
                color: Colors.yellow[900],
                size: 28.0,
              ),
            ),
          ),

          const SizedBox(height: 16),
          FloatingActionButton.small(
            heroTag: "zoom_in",
            onPressed: _zoomIn,
            backgroundColor: Colors.white,
            foregroundColor: Colors.black,
            child: const Icon(Icons.add),
          ),
          const SizedBox(height: 16),
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
              // TBD
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
                // TBD
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
              _userLocationMarker != null 
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
                    searchController: _searchController,
                    builder: (context, controller) {
                      RouteItem? route;
                      if (_selectedRouteId != null && _menuItems.isNotEmpty) {
                        try {
                          route = _menuItems.firstWhere(
                            (r) => r.routeId == _selectedRouteId,
                          );
                        } catch (_) {
                          route = null;
                        }
                      }

                      if (route != null) {
                        final bool hasAlerts = ui.checkRouteAlerts(
                          _activeAlerts,
                          route.routeId,
                        );
                        return Container(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          child: Card(
                            elevation: 2,
                            clipBehavior: Clip.antiAlias,
                            child: InkWell(
                              onTap: () => controller.openView(),
                              child: ListTile(
                                leading: Icon(
                                  (route.routeType == null ||
                                          route.routeType == 2)
                                      ? Icons.train
                                      : Icons.directions_bus,
                                  color: ui.colorFromHex(route.routeColor),
                                  size: 24,
                                ),
                                title: Text(
                                  "${route.routeShortName}: ${route.routeLongName}",
                                  style: const TextStyle(fontSize: 14),
                                  softWrap: true, // Allow wrapping
                                  maxLines: 2,
                                ),
                                trailing: hasAlerts
                                    ? GestureDetector(
                                        onTap: () {
                                          final routeAlerts = _activeAlerts
                                              .where((alert) {
                                                return alert
                                                    .alert
                                                    .informedEntity
                                                    .any(
                                                      (entity) =>
                                                          entity.routeId ==
                                                          route!.routeId,
                                                    );
                                              })
                                              .toList();

                                          ui.showRouteAlertsDialog(
                                            context,
                                            route!,
                                            routeAlerts,
                                          );
                                        },
                                        child: Padding(
                                          padding: const EdgeInsets.only(
                                            left: 8.0,
                                          ),
                                          child: Icon(
                                            Icons.warning_amber_rounded,
                                            color: Colors.amber,
                                            size: 20,
                                          ),
                                        ),
                                      )
                                    : null,
                              ),
                            ),
                          ),
                        );
                      }

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

                      final filteredRoutes = _menuItems.where((route) {
                        final name =
                            "${route.routeShortName} ${route.routeLongName}"
                                .toLowerCase();
                        return name.contains(keyword);
                      }).toList();

                      return ui.buildSearchListTiles(
                        context,
                        filteredRoutes,
                        _activeAlerts,
                        (selectedRoute) {
                          controller.closeView(selectedRoute);

                          WidgetsBinding.instance.addPostFrameCallback((_) {
                            if (!mounted) return;

                            setState(() {
                              // clear previous selections and markers
                              if (selectedRoute != null) {
                                _handleRouteLoading(selectedRoute);
                                // draw route lines
                              }
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
