import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_octo_eureka/maps/gtfsTypes.dart';
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
  bool _isLoading = true;
  List<RouteItem> _menuItems = [];
  List<RouteDetail> _tripMenuItems = [];
  List<RouteDetail> _activeRouteDetails = [];
  List<Marker> _stopMarkers = [];
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

  // request route details and draw route line when selected
  Future<void> _handleRouteLoading(String routeId) async {
    setState(() => _isLoading = true);

    try {
      List<RouteDetail> routeDetails = await proto.fetchRouteDetailsByRouteId(
        routeId,
      );

      if (routeDetails.isEmpty) {
        debugPrint("No details found for route $routeId");
        if (mounted) setState(() => _isLoading = false);
        return;
      }

      final uniqueDetails = <RouteDetail>[];
      final seenHeadsigns = <String>{};

      RouteItem result = _menuItems.firstWhere((item) => item.routeId == routeId);

      for (var detail in routeDetails) {
        final key = detail.tripHeadsign.isNotEmpty
            ? detail.tripHeadsign
            : detail.tripId;

        if (!seenHeadsigns.contains(key)) {
          seenHeadsigns.add(key);
          uniqueDetails.add(detail);
        }
      }

      if (mounted) {
        setState(() {
          _tripMenuItems = uniqueDetails;
        });

        if (uniqueDetails.isNotEmpty) {
          _processRouteData(uniqueDetails.first);
        }
      }
    } catch (e) {
      debugPrint("Error loading route: $e");
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  List<Marker> _buildBasicStopMarkers(List<Stop> stops, Color colorFromHex) {
    List<Marker> newStopMarkers = [];

    for (var stop in stops) {
      newStopMarkers.add(
        Marker(
          height: 14,
          width: 14,
          alignment: Alignment.center,
          point: LatLng(stop.stopLat, stop.stopLon),
          child: Tooltip(
            message: stop.stopName,
            triggerMode: TooltipTriggerMode.tap, 
            preferBelow: false, 
            verticalOffset: 15, 
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.8),
              borderRadius: BorderRadius.circular(6),
            ),
            textStyle: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
            child: Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: colorFromHex,
                border: Border.all(color: Colors.white, width: 2),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.3),
                    blurRadius: 3,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return newStopMarkers;
  }

  void _processRouteData(RouteDetail detail) {
    List<LatLng> routePoints = [];
    List<Marker> stopMarkers = [];
    Color routeColor = const Color.fromARGB(0, 0, 0, 0);

    routePoints.addAll(_decodePolyline(detail.encodedPolyline));
    routeColor = colorFromHex(detail.routeColor);

    // build polylines
    List<Polyline> routePolylines = buildTripPolyline(
      detail.routeId,
      routePoints,
      routeColor,
    );

    // build stop markers
    stopMarkers = _buildBasicStopMarkers(detail.stops, routeColor);

    setState(() {
      _activeRouteDetails = [detail];
      _activePolylines = routePolylines;
      _stopMarkers = stopMarkers;
      _zoomToFit(routePoints);
    });
  }

  // decode polyline string
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

  List<ListTile> buildSearchListTiles(
    BuildContext context,
    List<RouteItem> routes,
    List<AlertEntity> alerts,
    Function(String?) onTap,
  ) {
    return routes.map((route) {
      Color routeColor = Colors.black;
      if (route.routeColor.isNotEmpty) {
        try {
          final hex = route.routeColor.replaceAll('#', '');
          routeColor = Color(int.parse("0xFF$hex"));
        } catch (_) {
          // Keep default
        }
      }

      final bool hasAlerts = checkRouteAlerts(alerts, route.routeId);

      return ListTile(
        leading: Icon(
          (route.routeType == 0 || route.routeType == 2)
              ? Icons.train
              : Icons.directions_bus,
          color: routeColor,
          size: 24,
        ),
        title: Text(
          "${route.routeShortName}: ${route.routeLongName}",
          softWrap: true, // Allow wrapping
          maxLines: 2,
        ),
        onTap: () => onTap(route.routeId),
        trailing: hasAlerts
            ? GestureDetector(
                onTap: () {
                  final routeAlerts = alerts.where((alert) {
                    return alert.alert.informedEntity.any(
                      (entity) => entity.routeId == route.routeId,
                    );
                  }).toList();
                  showRouteAlertsDialog(context, route, routeAlerts);
                },
                child: Padding(
                  padding: const EdgeInsets.only(right: 8.0),
                  child: Icon(
                    Icons.warning_amber_rounded,
                    color: Colors.amber,
                    size: 20,
                  ),
                ),
              )
            : null,
      );
    }).toList();
  }

  void showRouteAlertsDialog(
    BuildContext context,
    RouteItem route,
    List<AlertEntity> alerts,
  ) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(
            "Alerts for ${route.routeShortName}",
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          content: SizedBox(
            width: double.maxFinite,
            child: alerts.isEmpty
                ? const Text("No details available.")
                : ListView.builder(
                    shrinkWrap: true,
                    itemCount: alerts.length,
                    itemBuilder: (context, index) {
                      final alertData = alerts[index].alert;

                      String getTranslation(TranslatedString? ts) {
                        if (ts == null || ts.translation.isEmpty) return "";
                        return ts.translation
                            .firstWhere(
                              (t) => t.language == 'en',
                              orElse: () => ts.translation.first,
                            )
                            .text;
                      }

                      final header = getTranslation(alertData.headerText);
                      final desc = getTranslation(alertData.descriptionText);

                      return Card(
                        elevation: 2,
                        margin: const EdgeInsets.symmetric(vertical: 8),
                        child: Padding(
                          padding: const EdgeInsets.all(12.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (header.isNotEmpty)
                                Text(
                                  header,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.redAccent,
                                  ),
                                ),
                              if (header.isNotEmpty) const SizedBox(height: 8),
                              Text(desc),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text("Close"),
            ),
          ],
        );
      },
    );
  }

  List<Polyline<Object>> buildTripPolyline(
    String? routeId,
    List<LatLng> points,
    Color colorFromHex,
  ) {
    final polyline = Polyline<Object>(
      points: points,
      strokeWidth: 4.0,
      color: colorFromHex,
      useStrokeWidthInMeter: false,
      hitValue: routeId,
    );

    return [polyline];
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

  bool checkRouteAlerts(List<AlertEntity> alerts, String routeId) {
    for (var alert in alerts) {
      for (var r in alert.alert.informedEntity) {
        if (r.routeId == routeId) {
          return true;
        }
      }
    }
    return false;
  }

  // onscreen map control
  void _zoomIn() {
    final currentZoom = _mapController.camera.zoom;
    _mapController.move(_mapController.camera.center, currentZoom + 1);
  }

  // onscreen map control
  void _zoomOut() {
    final currentZoom = _mapController.camera.zoom;
    _mapController.move(_mapController.camera.center, currentZoom - 1);
  }

  // used to move the map to focus on a selected point or route
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

    
    RouteDetail? currentDropdownValue;
    if (_activeRouteDetails.isNotEmpty && _tripMenuItems.isNotEmpty) {
      try {
        currentDropdownValue = _tripMenuItems.firstWhere(
          (t) => t.tripId == _activeRouteDetails.first.tripId,
        );
      } catch (_) {
        currentDropdownValue = null;
      }
    }

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
              // show routes near the center of the map at any time
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
              // show the user location and routes near the user at any time
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
                // clear selections
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
              _stopMarkers.isNotEmpty
                  ? MarkerLayer(
                      markers: [
                        ..._stopMarkers,
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
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.all(8),
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
                        final bool hasAlerts = checkRouteAlerts(
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
                                  color: colorFromHex(route.routeColor),
                                  size: 24,
                                ),
                                title: Text(
                                  "${route.routeShortName}: ${route.routeLongName}",
                                  style: const TextStyle(fontSize: 14),
                                  softWrap: true,
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

                                          showRouteAlertsDialog(
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

                      return buildSearchListTiles(
                        context,
                        filteredRoutes,
                        _activeAlerts,
                        (selectedRoute) {
                          controller.closeView(selectedRoute);

                          // FIX: Use addPostFrameCallback, but do NOT wrap the function call in setState.
                          // _handleRouteLoading handles its own setState internally.
                          WidgetsBinding.instance.addPostFrameCallback((_) {
                            if (!mounted) return;

                            if (selectedRoute != null) {
                              _handleRouteLoading(selectedRoute);
                            }
                          });
                        },
                      );
                    },
                  ),
                ),
                // NEW DROPDOWN MENU - Only shows when we have specific trip options
                if (_tripMenuItems.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12.0),
                    child: Card(
                      color: Colors.white.withOpacity(0.95),
                      elevation: 4,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(25.0),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16.0,
                          vertical: 2.0,
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<RouteDetail>(
                            isExpanded: true,
                            hint: const Text("Select Direction/Trip"),
                            value: currentDropdownValue,
                            icon: const Icon(Icons.alt_route_rounded),
                            items: _tripMenuItems.map((RouteDetail trip) {
                              RouteItem result = _menuItems.firstWhere((item) => item.routeId == trip.routeId);
                              return DropdownMenuItem<RouteDetail>(
                                value: trip,
                                child: Text(
                                  trip.tripHeadsign.isNotEmpty
                                      ? result.routeType == 3 ? "${result.routeShortName}: ${result.routeLongName} - ${trip.tripHeadsign}" : trip.tripHeadsign
                                      : "Trip ${trip.tripId}",
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              );
                            }).toList(),
                            onChanged: (RouteDetail? newTrip) {
                              if (newTrip != null) {
                                _processRouteData(newTrip);
                              }
                            },
                          ),
                        ),
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
