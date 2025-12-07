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
  final GtfsApiService gtfs = GtfsApiService();
  final MapService mapService = MapService();
  List<VehiclePositionEntity> _vehiclePositions = [];
  Map<String, gtfsRoute> _routeMap = {};
  Map<String, Trip> _tripMap = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchVehiclePositionsData();
    _loadDataSets();
    // user selects a route and is shown current trips on that route
    // user selects a trip and the map draws the route, stops for that trip
  }

  Future<void> _fetchVehiclePositionsData() async {
    setState(() => _isLoading = true);
    try {
      var positions = await mapService.loadVehiclePositions();
      if (positions != []) {
        setState(() {
          _vehiclePositions = positions;
        });
      }
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("Error initializing GTFS data: $e");
    }
  }

  Future<void> _loadDataSets() async {
    setState(() => _isLoading = true);

    Future<T?> safeLoad<T>(Future<T> Function() loader) async {
      try {
        return await loader();
      } catch (e) {
        debugPrint("Partial load error: $e");
        return null;
      }
    }

    final results = await Future.wait([
      safeLoad(() => mapService.loadRoutes()),
      safeLoad(() => mapService.loadTrips()),
    ]);

    if (mounted) {
      setState(() {
        if (results[0] != null) {
          _routeMap = results[0] as Map<String, gtfsRoute>;
        }
        if (results[1] != null) {
          _tripMap = results[1] as Map<String, Trip>;
        }
        _isLoading = false;
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
              interactionOptions: InteractionOptions(
                flags: InteractiveFlag.all,
              ),
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.example.app',
              ),
            ],
          ),
          if (_isLoading) const Center(child: CircularProgressIndicator()),
        ],
      ),
    );
  }
}
