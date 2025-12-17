import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_octo_eureka/maps/ApiService.dart';
import 'package:flutter_octo_eureka/maps/gtfsTypes.dart';
import 'package:flutter_octo_eureka/maps/userInterfaceService.dart';

class DataService {
  ApiService api = ApiService();
  UserInterfaceService ui = UserInterfaceService();

  Future<List<Polyline>> fetchAndBuildNearPolylines(
    double lat,
    double lon,
    double radius,
  ) async {
    try {
      final data = await api.fetchRouteTripShapes(lat, lon, radius);
      if (data.isEmpty) return [];

      final uniqueRouteIds = data.map((d) => d.routeId).toSet();
      final uniqueShapeIds = data.map((d) => d.shapeId).toSet();

      debugPrint("DEBUG: Shape IDs found: $uniqueShapeIds");

      final results = await Future.wait([
        Future.wait(uniqueRouteIds.map((id) => api.fetchRouteById(id))),
        Future.wait(uniqueShapeIds.map((id) => api.fetchShapeById(id))),
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
          final color = ui.colorFromHex(route.routeColor);

          tempPolylines.addAll(
            ui.buildTripPolyline(route.routeId, shapePoints, color),
          );
        }
      }

      return tempPolylines;
    } catch (e) {
      debugPrint("Error processing polylines: $e");
      return [];
    }
  }

  Future<(List<AlertEntity>, List<AlertEntity>)> fetchAlerts(
    String selectedRouteId,
  ) async {
    List<AlertEntity> selectedAlerts = [];
    try {
      final alerts = await api.fetchAlerts();
      if (alerts.isEmpty) return (<AlertEntity>[], <AlertEntity>[]);
      for (var alert in alerts) {
        for (var r in alert.alert.informedEntity) {
          if (r.routeId == selectedRouteId) {
            selectedAlerts.add(alert);
          }
        }
      }
      return (alerts, selectedAlerts);
    } catch (e) {
      debugPrint("Error loading alerts: $e");
      return (<AlertEntity>[], <AlertEntity>[]);
    }
  }

  Future<
    (
      List<VehiclePositionEntity>,
      List<AlertEntity>,
      List<gtfsRoute>,
      List<DropdownMenuItem<String>>,
      Map<String, gtfsRoute>,
    )
  >
  fetchVehiclePositionsData(
    BuildContext context,
    List<AlertEntity> alerts,
  ) async {
    try {
      final positions = await api.fetchVehiclePositions();
      if (positions.isEmpty) {
        return (
          <VehiclePositionEntity>[],
          <AlertEntity>[],
          <gtfsRoute>[],
          <DropdownMenuItem<String>>[],
          <String, gtfsRoute>{},
        );
      }

      final List<gtfsRoute> rawRoutes = await api.loadVehicleRoutes(positions);

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

      final menuItems = ui.buildRouteDropdownItems(
        context,
        cleanRoutesList,
        alerts,
      );

      return (positions, alerts, cleanRoutesList, menuItems, uniqueRoutes);
    } catch (e) {
      debugPrint("Error initializing GTFS data: $e");
      return (
        <VehiclePositionEntity>[],
        <AlertEntity>[],
        <gtfsRoute>[],
        <DropdownMenuItem<String>>[],
        <String, gtfsRoute>{},
      );
    }
  }
}
