import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_octo_eureka/maps/gtfsApiService.dart';
import 'package:latlong2/latlong.dart';
import 'package:flutter_octo_eureka/maps/gtfsTypes.dart';

class BaseMapWidget extends StatefulWidget {
  const BaseMapWidget({super.key});

  @override
  State<BaseMapWidget> createState() => _BaseMapWidgetState();
}

class _BaseMapWidgetState extends State<BaseMapWidget> {
  final GtfsApiService gtfs = GtfsApiService();
  List<Polyline> _polylines = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadAndProcessShapes(["1316772", "1317062"]);
  }

  Future<void> _loadAndProcessShapes(List<String> shapeIds) async {
    try {
      final List<Future<List<Shape>>> futures =
          shapeIds.map((id) => gtfs.fetchShapeById(id)).toList();

      final List<List<Shape>> results = await Future.wait(futures);

      final List<Shape> allShapes = results.expand((shapes) => shapes).toList();

      _processShapeData(allShapes);
    } catch (e) {
      debugPrint("Error fetching shapes: $e");
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _processShapeData(List<Shape> data) {
    final Map<String, List<Shape>> groupedShapes = {};

    for (var point in data) {
      final String id = point.shapeId;

      if (!groupedShapes.containsKey(id)) {
        groupedShapes[id] = [];
      }
      groupedShapes[id]!.add(point);
    }

    final List<Polyline> newPolylines = [];

    groupedShapes.forEach((id, points) {
      points.sort((a, b) => a.shapePtSequence.compareTo(b.shapePtSequence));

      final List<LatLng> coordinates = points.map((pt) {
        return LatLng(
          pt.shapePtLat,
          pt.shapePtLon,
        );
      }).toList();

      newPolylines.add(
        Polyline(
          points: coordinates,
          strokeWidth: 4.0,
          color: Colors.green, 
        ),
      );
    });

    if (mounted) {
      setState(() {
        _polylines = newPolylines;
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
              initialZoom: 9.2,
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.example.app',
              ),
              PolylineLayer(
                polylines: _polylines,
              ),
            ],
          ),
          if (_isLoading)
            const Center(
              child: CircularProgressIndicator(),
            ),
        ],
      ),
    );
  }
}