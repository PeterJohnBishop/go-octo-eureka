import 'dart:async';

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
      setState(() => _isLoading = true); //
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
    
    // Z-Index control: Stops on bottom, Vehicles on top
    List<Marker> stopMarkers = [];
    List<Marker> vehicleMarkers = [];

    // --- 1. DATA PREP ---
    final tripToRouteIdMap = {for (var t in _trips) t.tripId: t.routeId};
    final routeTypeMap = {for (var r in _routes) r.routeId: r.routeType};
    final routeColorMap = {for (var r in _routes) r.routeId: r.routeColor};
    // RESTORED: Headsign map
    final tripHeadsignMap = {for (var t in _trips) t.tripId: t.tripHeadsign};

    final visibleTrips = _selectedRouteId == null
        ? _trips
        : _trips.where((t) => t.routeId == _selectedRouteId).toList();

    // --- 2. BUILD POLYLINES ---
    for (var trip in visibleTrips) {
      if (trip.shapeId != null && _shapeCache.containsKey(trip.shapeId)) {
        final points = _shapeCache[trip.shapeId]!;
        final routeId = trip.routeId;
        final colorHex = routeId != null ? routeColorMap[routeId] : null;
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

    // --- PREPARE VEHICLE DATA ---
    final visibleTripIds = visibleTrips.map((t) => t.tripId).toSet();
    final visibleVehicles = _vehiclePositions.where((v) {
      if (_selectedRouteId == null) return true;
      return visibleTripIds.contains(v.vehicle?.trip?.tripId);
    });

    // --- 3. BUILD STOP MARKERS (Bottom Layer) ---
    if (_selectedVehicleId != null) {
      final selectedVehicle = visibleVehicles
          .cast<VehiclePositionEntity?>()
          .firstWhere(
            (v) => v?.id == _selectedVehicleId,
            orElse: () => null,
          );

      final specificTripId = selectedVehicle?.vehicle?.trip?.tripId;
      
      Color routeColor = Colors.grey;
      if (selectedVehicle != null) {
         final tripId = selectedVehicle.vehicle?.trip?.tripId;
         final routeId = tripToRouteIdMap[tripId];
         final colorHex = routeId != null ? routeColorMap[routeId] : null;
         if (colorHex != null && colorHex.isNotEmpty) {
           routeColor = _colorFromHex(colorHex);
         }
      }

      if (specificTripId != null && _stopTimeCache.containsKey(specificTripId)) {
        final stopTimes = _stopTimeCache[specificTripId]!;
        
        for (final stopTime in stopTimes) {
          final stopId = stopTime.stopId;
          
          if (stopId != null && _stopCache.containsKey(stopId)) {
            final stop = _stopCache[stopId]!;
            
            stopMarkers.add(
              Marker(
                point: LatLng(stop.stopLat, stop.stopLon),
                width: 150.0, 
                height: 80.0, 
                alignment: Alignment.center, 
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(6),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.3),
                            blurRadius: 2,
                            offset: const Offset(0, 1),
                          )
                        ],
                      ),
                      child: Text(
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

    // --- 4. BUILD VEHICLE MARKERS (Top Layer) ---
    for (var v in visibleVehicles) {
      final lat = v.vehicle?.position?.latitude;
      final lon = v.vehicle?.position?.longitude;
      final tripId = v.vehicle?.trip?.tripId;
      final vehicleId = v.id;

      if (lat != null && lon != null && tripId != null) {
        final isSelected = _selectedVehicleId == vehicleId;
        final routeId = tripToRouteIdMap[tripId];
        final routeType = routeId != null ? routeTypeMap[routeId] : null;
        
        // Get Headsign (only show if route is selected, per previous request? 
        // Or always show if selected? The prompt implies replacing the button 
        // which only appears when selected.)
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
        );

        if (isSelected) {
          markerContent = VehicleMarkerMenu(
            child: markerContent,
            headsign: headsign, // Passing headsign here
            onCompassPressed: () => debugPrint("Compass tapped for $vehicleId"),
            onWarningPressed: () => debugPrint("Warning tapped for $vehicleId"),
            onInfoPressed: () => debugPrint("Info tapped for $vehicleId"),
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

        // Expanded size to accommodate the menu + new text
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
