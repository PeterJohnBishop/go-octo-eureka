import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_octo_eureka/maps/gtfsApiService.dart';
import 'package:flutter_octo_eureka/maps/mapService.dart';
import 'package:latlong2/latlong.dart';
import 'package:flutter_octo_eureka/maps/gtfsTypes.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:intl/intl.dart';

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
  List<Polyline> _activePolylines = [];
  List<Marker> _activeMarkers = [];
  String? _selectedVehicleId;

  // auto-refresh
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

  Future<void> _fetchVehiclePositionsData({bool isBackground = false}) async {
    if (!isBackground) {
      setState(() => _isLoading = true); 
    }
    try {
      final positions = await mapService.loadVehiclePositions();
      if (positions.isEmpty) {
        if (!isBackground && mounted) setState(() => _isLoading = false); //
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
          _routeMenuItems = [
            const DropdownMenuItem<String>(
              value: null,
              child: Text(
                "All Routes",
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            ...menuItems,
          ];
          _isLoading = false;
          _refreshMapLayers();
          if (isBackground) {
            debugPrint(
              "Background refresh complete: ${positions.length} vehicles updated.",
            );
          }
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
    List<Marker> stopMarkers = [];
    List<Marker> vehicleMarkers = [];

    final tripToRouteIdMap = {for (var t in _trips) t.tripId: t.routeId};
    final routeTypeMap = {for (var r in _routes) r.routeId: r.routeType};
    final routeColorMap = {for (var r in _routes) r.routeId: r.routeColor};
    final tripHeadsignMap = {for (var t in _trips) t.tripId: t.tripHeadsign};
    final vehicleStatus = {
      for (var v in _vehiclePositions) v.id: v.vehicle.currentStatus,
    };
    final vehicleStop = {
      for (var v in _vehiclePositions) v.id: v.vehicle.stopId,
    };

    final visibleTrips = _selectedRouteId == null
        ? _trips
        : _trips.where((t) => t.routeId == _selectedRouteId).toList();

    for (var trip in visibleTrips) {
      if (_shapeCache.containsKey(trip.shapeId)) {
        final points = _shapeCache[trip.shapeId]!;
        final routeId = trip.routeId;
        final colorHex = routeColorMap[routeId];
        Color polylineColor = (colorHex != null && colorHex.isNotEmpty)
            ? _colorFromHex(colorHex)
            : Colors.grey;

        newPolylines.add(
          Polyline(
            points: points
                .map((p) => LatLng(p.shapePtLat, p.shapePtLon))
                .toList(),
            color: polylineColor,
            strokeWidth: 4.0,
          ),
        );
      }
    }

    final visibleTripIds = visibleTrips.map((t) => t.tripId).toSet();
    final visibleVehicles = _vehiclePositions.where((v) {
      if (_selectedRouteId == null) return true;
      return visibleTripIds.contains(v.vehicle.trip.tripId);
    });

    if (_selectedVehicleId != null) {
      final selectedVehicle = visibleVehicles
          .cast<VehiclePositionEntity?>()
          .firstWhere((v) => v?.id == _selectedVehicleId, orElse: () => null);

      final specificTripId = selectedVehicle?.vehicle.trip.tripId;

      Color routeColor = Colors.grey;
      if (selectedVehicle != null) {
        final tripId = selectedVehicle.vehicle.trip.tripId;
        final routeId = tripToRouteIdMap[tripId];
        final colorHex = routeId != null ? routeColorMap[routeId] : null;
        if (colorHex != null && colorHex.isNotEmpty) {
          routeColor = _colorFromHex(colorHex);
        }
      }

      if (specificTripId != null &&
          _stopTimeCache.containsKey(specificTripId)) {
        final stopTimes = _stopTimeCache[specificTripId]!;

        for (final stopTime in stopTimes) {
          final arrival = stopTime.arrivalTime;
          final departure = stopTime.departureTime;
          final stopId = stopTime.stopId;

          final convertedArrival = formatGtfsTime(arrival);
          final convertedDeparture = formatGtfsTime(departure);

          if (_stopCache.containsKey(stopId)) {
            final stop = _stopCache[stopId]!;

            stopMarkers.add(
              Marker(
                point: LatLng(stop.stopLat, stop.stopLon),
                width: 200.0,
                height: 90.0,
                alignment: Alignment.center,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(6),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.3),
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
                    const SizedBox(height: 2),
                    Container(
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        border: Border.all(color: routeColor, width: 2),
                      ),
                      child: Icon(
                        Icons.nature_people,
                        size: 14,
                        color: routeColor,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }
        }
      }
    }

    for (var v in visibleVehicles) {
      final lat = v.vehicle.position.latitude;
      final lon = v.vehicle.position.longitude;
      final bearing = v.vehicle.position.bearing;
      final double bearingRadians = bearing * (pi / 180);
      final unixTimestamp = v.vehicle.timestamp;
      final DateTime date = DateTime.fromMillisecondsSinceEpoch(
        unixTimestamp * 1000,
      );
      final String formattedTime = DateFormat('h:mm a').format(date);
      final tripId = v.vehicle.trip.tripId;
      final vehicleId = v.id;
      final status = vehicleStatus[vehicleId];
      final stop = vehicleStop[vehicleId];
      final stopDetails = _stopCache[stop];

      if (lat != null && lon != null && tripId != null) {
        final isSelected = _selectedVehicleId == vehicleId;
        final routeId = tripToRouteIdMap[tripId];
        final routeType = routeId != null ? routeTypeMap[routeId] : null;
        final headsign = tripHeadsignMap[tripId] ?? "Unknown";
        IconData iconData;
        Color iconColor;
        final colorHex = routeId != null ? routeColorMap[routeId] : null;
        iconColor = (colorHex != null && colorHex.isNotEmpty)
            ? _colorFromHex(colorHex)
            : Colors.grey;

        if (routeType == 0 || routeType == 2) {
          iconData = Icons.train;
        } else {
          iconData = Icons.directions_bus;
        }

        Widget markerContent = VehiclePinIcon(
          iconColor: iconColor,
          vehicleIconData: iconData,
          size: 45.0,
          bearing: bearingRadians,
        );

        if (isSelected) {
          markerContent = VehicleMarkerMenu(
            isBus: routeType == 0 || routeType == 2 ? false : true,
            headsign: headsign,
            timestamp: formattedTime,
            status: status,
            stop: stopDetails!,
            onCompassPressed: () => debugPrint("Compass tapped for $vehicleId"),
            onWarningPressed: () => debugPrint("Warning tapped for $vehicleId"),
            onInfoPressed: () => debugPrint("Info tapped for $vehicleId"),
            child: markerContent,
          );
        } else {
          markerContent = GestureDetector(
            onTap: () {
              setState(() {
                _selectedRouteId = routeId;
                _selectedVehicleId = vehicleId;
                _refreshMapLayers();
              });
            },
            child: markerContent,
          );
        }

        final double baseSize = isSelected ? 120.0 : 50.0;

        vehicleMarkers.add(
          Marker(
            point: LatLng(lat, lon),
            width: baseSize,
            height: baseSize,
            alignment: Alignment.center,
            child: markerContent,
          ),
        );
      }
    }

    setState(() {
      _activePolylines = newPolylines;
      _activeMarkers = [...stopMarkers, ...vehicleMarkers];
    });
  }

  Color _colorFromHex(String hexColor) {
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

  void _startAutoRefresh() {
    _updateTimer = Timer.periodic(const Duration(minutes: 2), (timer) {
      debugPrint("Auto-refreshing GTFS data...");
      _fetchVehiclePositionsData(isBackground: true);
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
                    _selectedRouteId = null;
                    _selectedVehicleId = null;
                    _refreshMapLayers();
                  });
                }
              },
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.flutter_octo_eureka.app',
              ),
              PolylineLayer(polylines: _activePolylines),
              MarkerLayer(markers: _activeMarkers),
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
                                  _selectedRouteId = value;
                                  _refreshMapLayers();
                                });
                              },
                            ),
                          ),
                        ),

                        Container(
                          width: 1,
                          height: 32,
                          color: Colors.grey.shade300,
                        ),

                        _isLoading ? Padding(
                          padding: EdgeInsets.all(8),
                          child: CircularProgressIndicator()) : IconButton(
                          icon: const Icon(Icons.refresh),
                          color: Colors.grey[700],
                          tooltip: 'Refresh Routes',
                          onPressed: () {
                            setState(() {
                              _fetchVehiclePositionsData(isBackground: false);
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
