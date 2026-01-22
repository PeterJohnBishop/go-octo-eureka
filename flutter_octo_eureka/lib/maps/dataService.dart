// import 'package:flutter/material.dart';
// import 'package:flutter_map/flutter_map.dart';
// import 'package:flutter_octo_eureka/maps/ApiService.dart';
// import 'package:flutter_octo_eureka/maps/gtfsTypes.dart';
// import 'package:flutter_octo_eureka/maps/userInterfaceService.dart';
// import 'package:intl/intl.dart';
// import 'package:latlong2/latlong.dart';

// class DataService {
//   ApiService api = ApiService();
//   UserInterfaceService ui = UserInterfaceService();

//   Future<List<Polyline>> fetchAndBuildNearPolylines(
//     double lat,
//     double lon,
//     double radius,
//   ) async {
//     try {
//       final data = await api.fetchRouteTripShapes(lat, lon, radius);
//       if (data.isEmpty) return [];

//       final uniqueRouteIds = data.map((d) => d.routeId).toSet();
//       final uniqueShapeIds = data.map((d) => d.shapeId).toSet();

//       debugPrint("DEBUG: Shape IDs found: $uniqueShapeIds");

//       final results = await Future.wait([
//         Future.wait(uniqueRouteIds.map((id) => api.fetchRouteById(id))),
//         Future.wait(uniqueShapeIds.map((id) => api.fetchShapeById(id))),
//       ]);

//       final routesList = results[0] as List<gtfsRoute>;
//       final shapesList = results[1] as List<List<Shape>>;

//       final routeMap = {for (var r in routesList) r.routeId: r};

//       final shapeMap = <String, List<Shape>>{};
//       for (var list in shapesList) {
//         if (list.isNotEmpty) {
//           shapeMap[list.first.shapeId] = list;
//         }
//       }

//       final List<Polyline> tempPolylines = [];

//       for (var d in data) {
//         final route = routeMap[d.routeId];
//         final List<Shape>? shapePoints = shapeMap[d.shapeId];

//         if (route != null && shapePoints != null && shapePoints.isNotEmpty) {
//           final color = ui.colorFromHex(route.routeColor);

//           tempPolylines.addAll(
//             ui.buildTripPolyline(route.routeId, shapePoints, color),
//           );
//         }
//       }

//       return tempPolylines;
//     } catch (e) {
//       debugPrint("Error processing polylines: $e");
//       return [];
//     }
//   }

//   Future<(List<AlertEntity>, List<AlertEntity>)> fetchAlerts(
//     String selectedRouteId,
//   ) async {
//     List<AlertEntity> selectedAlerts = [];
//     try {
//       final alerts = await api.fetchAlerts();
//       if (alerts.isEmpty) return (<AlertEntity>[], <AlertEntity>[]);
//       for (var alert in alerts) {
//         for (var r in alert.alert.informedEntity) {
//           if (r.routeId == selectedRouteId) {
//             selectedAlerts.add(alert);
//           }
//         }
//       }
//       return (alerts, selectedAlerts);
//     } catch (e) {
//       debugPrint("Error loading alerts: $e");
//       return (<AlertEntity>[], <AlertEntity>[]);
//     }
//   }

//   Future<
//     (
//       List<VehiclePositionEntity>,
//       List<gtfsRoute>,
//       Map<String, gtfsRoute>,
//     )
//   >
//   fetchVehiclePositionsData(
//     BuildContext context,
//   ) async {
//     try {
//       final positions = await api.fetchVehiclePositions();
//       if (positions.isEmpty) {
//         return (
//           <VehiclePositionEntity>[],
//           <gtfsRoute>[],
//           <String, gtfsRoute>{},
//         );
//       }

//       final List<gtfsRoute> rawRoutes = await api.loadVehicleRoutes(positions);

//       final uniqueRoutes = <String, gtfsRoute>{};
//       for (var route in rawRoutes) {
//         if (!uniqueRoutes.containsKey(route.routeId)) {
//           uniqueRoutes[route.routeId] = route;
//         }
//       }
//       final cleanRoutesList = uniqueRoutes.values.toList();

//       cleanRoutesList.sort((a, b) {
//         String getKey(String fullString) {
//           if (fullString.isEmpty) return "";
//           final index = fullString.indexOf(':');
//           if (index == -1) return fullString.trim();
//           return fullString.substring(0, index).trim();
//         }

//         bool isNumeric(String s) => RegExp(r'^\d').hasMatch(s);
//         bool isSingleLetter(String s) => s.length == 1 && !isNumeric(s);

//         int getRank(String key) {
//           if (isSingleLetter(key)) return 2;
//           if (isNumeric(key)) return 1;
//           return 0;
//         }

//         String keyA = getKey(a.routeShortName);
//         String keyB = getKey(b.routeShortName);

//         int rankA = getRank(keyA);
//         int rankB = getRank(keyB);

//         if (rankA != rankB) {
//           return rankA.compareTo(rankB);
//         }

//         if (rankA == 1) {
//           int getNumber(String s) {
//             final match = RegExp(r'^\d+').firstMatch(s);
//             return match != null ? int.parse(match.group(0)!) : 0;
//           }

//           int diff = getNumber(keyA).compareTo(getNumber(keyB));
//           return diff == 0 ? keyA.compareTo(keyB) : diff;
//         } else {
//           return keyA.compareTo(keyB);
//         }
//       });

//       return (positions, cleanRoutesList, uniqueRoutes);
//     } catch (e) {
//       debugPrint("Error initializing GTFS data: $e");
//       return (
//         <VehiclePositionEntity>[],
//         <gtfsRoute>[],
//         <String, gtfsRoute>{},
//       );
//     }
//   }

//   Future<(List<VehiclePositionEntity>, List<Trip>)> fetchSelectedVehicles(
//     List<VehiclePositionEntity> vehicles,
//     String selectedRouteId,
//   ) async {
//     final selectedVehicles = vehicles.where((entity) {
//       return entity.vehicle.trip.routeId == selectedRouteId;
//     }).toList();
//     if (selectedVehicles.isEmpty) {
//       return (<VehiclePositionEntity>[], <Trip>[]);
//     }
//     try {
//       final results = await Future.wait(
//         selectedVehicles.map((v) => api.fetchTripById(v.vehicle.trip.tripId)),
//       );
//       if (results.isEmpty) {
//         return (<VehiclePositionEntity>[], <Trip>[]);
//       }
//       final trips = results.whereType<Trip>().toList();

//       return (selectedVehicles, trips);
//     } catch (e) {
//       debugPrint("Error loading trips: $e");
//       return (<VehiclePositionEntity>[], <Trip>[]);
//     }
//   }

//   Future<(List<StopTime>, List<Stop>, Map<String, List<Shape>>)> fetchRouteTripDetails(List<gtfsRoute> routes, List<Trip> trips, String routeId, Color colorFromHex) async {

//     try {
//       final uniqueShapeIds = trips.map((t) => t.shapeId).toSet().toList();
//       final Map<String, List<Shape>> shapeMap = {};

//       for (var i = 0; i < uniqueShapeIds.length; i += 10) {
//         final end = (i + 10 < uniqueShapeIds.length)
//             ? i + 10
//             : uniqueShapeIds.length;
//         final batch = uniqueShapeIds.sublist(i, end);

//         await Future.wait(
//           batch.map((shapeId) async {
//             final fetchedShapes = await api.fetchShapeById(shapeId);

//             List<Shape> optimizedShapes = fetchedShapes;
//             if (fetchedShapes.length > 500) {
//               optimizedShapes = [];
//               for (int k = 0; k < fetchedShapes.length; k++) {
//                 if (k == 0 || k == fetchedShapes.length - 1 || k % 3 == 0) {
//                   optimizedShapes.add(fetchedShapes[k]);
//                 }
//               }
//             }
//             shapeMap[shapeId] = optimizedShapes;
//           }),
//         );
//       }

//       final List<StopTime> allStopTimes = [];

//       for (var i = 0; i < trips.length; i += 20) {
//         final end = (i + 20 < trips.length) ? i + 20 : trips.length;
//         final batch = trips.sublist(i, end);

//         final batchResults = await Future.wait(
//           batch.map((t) => api.fetchStopTimesByTripId(t.tripId)),
//         );

//         allStopTimes.addAll(batchResults.expand((x) => x));
//       }

//       final uniqueStopIds = allStopTimes
//           .map((st) => st.stopId)
//           .toSet()
//           .toList();
//       final List<Stop> allStops = [];

//       // Process stops in batches of 20
//       for (var i = 0; i < uniqueStopIds.length; i += 20) {
//         final end = (i + 20 < uniqueStopIds.length)
//             ? i + 20
//             : uniqueStopIds.length;
//         final batch = uniqueStopIds.sublist(i, end);

//         final batchResults = await Future.wait(
//           batch.map((id) => api.fetchStopById(id)),
//         );
//         allStops.addAll(batchResults);
//       }

//       return (allStopTimes, allStops, shapeMap);
//     } catch (e) {
//       debugPrint("Error loading trip details: $e");
//       return (<StopTime>[], <Stop>[], <String, List<Shape>>{});
//     }
//   }

//   Future<(List<Shape>, List<StopTime>, List<Stop>)> fetchTripDetails(List<Trip> trips, String tripId) async {
//     try {
//       final trip = trips.firstWhere((t) => t.tripId == tripId);

//       final List<Shape> shapes = await api.fetchShapeById(trip.shapeId);

//       final List<StopTime> stopTimes = await api.fetchStopTimesByTripId(tripId);

//       var stops = <Stop>[];
//       if (stopTimes.isNotEmpty) {
//         final uniqueStopIds = stopTimes.map((st) => st.stopId).toSet().toList();

//         for (var i = 0; i < uniqueStopIds.length; i += 20) {
//           final end = (i + 20 < uniqueStopIds.length)
//               ? i + 20
//               : uniqueStopIds.length;
//           final batch = uniqueStopIds.sublist(i, end);

//           final batchResults = await Future.wait(
//             batch.map((id) => api.fetchStopById(id)),
//           );
//           stops.addAll(batchResults);
//         }
//       }

//       List<Shape> optimizedShapes = shapes;
//           if (shapes.length > 500) {
//             optimizedShapes = [];
//             for (int i = 0; i < shapes.length; i++) {
//               if (i == 0 || i == shapes.length - 1 || i % 3 == 0) {
//                 optimizedShapes.add(shapes[i]);
//               }
//             }
//           }

//       return (
//         optimizedShapes,
//         stopTimes,
//         stops,
//         );
      
//     } catch (e) {
//       debugPrint("Error loading single trip details: $e");
//       return (<Shape>[], <StopTime>[], <Stop>[]);
//     }
//   }

//   (List<Marker>, List<LatLng>) fetchVehicleMarkers({
//   required List<VehiclePositionEntity> selectedVehicles,
//   required List<gtfsRoute> routes,
//   required List<Trip> trips,
//   required List<Stop> stops,
//   required List<StopTime> stopTimes,
//   required String? selectedRouteId,
//   required String? selectedVehicleId,
//   required Function(dynamic vehicle, Color routeColor) onVehicleTap,
// }) {
//   final List<Marker> vehicleMarkers = [];
//   final List<LatLng> mappedPositions = [];
//   final UserInterfaceService uiService = UserInterfaceService();

//   final route = routes.firstWhere(
//     (r) => r.routeId == selectedRouteId,
//     orElse: () => routes.first,
//   );
//   final Color iconColor = uiService.colorFromHex(route.routeColor);

//   for (var vehicle in selectedVehicles) {
//     final lat = vehicle.vehicle.position.latitude;
//     final lon = vehicle.vehicle.position.longitude;
//     final latLng = LatLng(lat, lon);
//     mappedPositions.add(latLng);

//     final bool isSelected = selectedVehicleId == vehicle.id;
//     final double bearing = vehicle.vehicle.position.bearing;
    
//     final IconData iconData = (route.routeType == 0 || route.routeType == 2)
//         ? Icons.train
//         : Icons.directions_bus;

//     final String formattedTime = DateFormat('h:mm a').format(
//       DateTime.fromMillisecondsSinceEpoch(vehicle.vehicle.timestamp * 1000),
//     );

//     Widget markerContent = VehiclePinIcon(
//       iconColor: iconColor,
//       vehicleIconData: iconData,
//       size: 45.0,
//       bearing: bearing * (3.1415926535897932 / 180), 
//     );

//     if (isSelected) {
//       final trip = trips.firstWhere(
//         (t) => t.tripId == vehicle.vehicle.trip.tripId,
//         orElse: () => trips.first,
//       );

//       final currentStop = stops.cast<Stop?>().firstWhere(
//         (s) => s?.stopId == vehicle.vehicle.stopId,
//         orElse: () => null,
//       );

//       markerContent = VehicleMarkerMenu(
//         isBus: !(route.routeType == 0 || route.routeType == 2),
//         headsign: trip.tripHeadsign,
//         timestamp: formattedTime,
//         status: vehicle.vehicle.currentStatus,
//         stop: currentStop,
//         vehicle: vehicle,
//         stopTimes: stopTimes,
//         stops: stops,
//         onCompassPressed: () => debugPrint("Compass tapped"),
//         onWarningPressed: () => debugPrint("Warning tapped"),
//         onInfoPressed: () => debugPrint("Info tapped"),
//         child: markerContent,
//       );
//     } else {
//       markerContent = GestureDetector(
//         onTap: () => onVehicleTap(vehicle, iconColor),
//         child: markerContent,
//       );
//     }

//     vehicleMarkers.add(
//       Marker(
//         point: latLng,
//         width: isSelected ? 120.0 : 50.0,
//         height: isSelected ? 120.0 : 50.0,
//         alignment: Alignment.center,
//         child: markerContent,
//       ),
//     );
//   }

//   return (vehicleMarkers, mappedPositions);
// }

// }

