import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_octo_eureka/maps/gtfsTypes.dart';
import 'package:latlong2/latlong.dart';

class UserInterfaceService {
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

  List<DropdownMenuItem<String>> buildRouteDropdownItems(
    BuildContext context,
    List<gtfsRoute> routes,
    List<AlertEntity> alerts,
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

      return DropdownMenuItem<String>(
        value: route.routeId,
        child: Row(
          children: [
            Container(
              width: 14,
              height: 14,
              decoration: BoxDecoration(
                color: routeColor,
                shape: BoxShape.circle,
              ),
            ),

            const SizedBox(width: 8),

            // Alert Icon (Only shows if active alerts exist)
            if (hasAlerts)
              GestureDetector(
                onTap: () {
                  final routeAlerts = alerts.where((alert) {
                    return alert.alert.informedEntity.any(
                      (entity) => entity.routeId == route.routeId,
                    );
                  }).toList();

                  _showRouteAlertsDialog(context, route, routeAlerts);
                },
                child: Padding(
                  padding: const EdgeInsets.only(right: 8.0),
                  child: Icon(
                    Icons.warning_amber_rounded,
                    color: Colors.amber,
                    size: 20,
                  ),
                ),
              ),

            Expanded(
              child: Text(
                "${route.routeShortName}: ${route.routeLongName}",
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 14),
              ),
            ),
          ],
        ),
      );
    }).toList();
  }

  void _showRouteAlertsDialog(
    BuildContext context,
    gtfsRoute route,
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
    List<Shape> shapes,
    Color colorFromHex,
  ) {
    shapes.sort((a, b) => a.shapePtSequence.compareTo(b.shapePtSequence));

    final points = shapes
        .map((s) => LatLng(s.shapePtLat, s.shapePtLon))
        .toList();

    final polyline = Polyline(
      points: points,
      strokeWidth: 4.0,
      color: colorFromHex,
    );

    return [polyline];
  }

  List<Marker> buildStopMarkers(
    List<StopTime> stopTimes,
    List<Stop> stops,
    Color colorFromHex,
  ) {
    List<Marker> newStopMarkers = [];

    for (var stop in stops) {
      final vehicleStopTime = stopTimes.firstWhere(
        (s) => s.stopId == stop.stopId,
        orElse: () => StopTime(
          tripId: '',
          arrivalTime: 'N/A',
          departureTime: 'N/A',
          stopId: '',
          stopSequence: 0,
          stopHeadsign: '',
          pickupType: 0,
          dropOffType: 0,
          shapeDistTraveled: 0.0,
          timepoint: 0,
        ),
      );

      final convertedArrival = formatGtfsTime(vehicleStopTime.arrivalTime);
      final convertedDeparture = formatGtfsTime(vehicleStopTime.departureTime);

      newStopMarkers.add(
        Marker(
          point: LatLng(stop.stopLat, stop.stopLon),
          width: 200.0,
          height: 175.0,
          alignment: Alignment.center,
          child: StopMarkerPopup(
            stopName: stop.stopName,
            arrivalTime: convertedArrival,
            departureTime: convertedDeparture,
            color: colorFromHex,
          ),
        ),
      );
    }

    return newStopMarkers;
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

  Widget buildAlertButton({required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(8),
        child: Icon(Icons.warning_amber_rounded, color: Colors.amber, size: 24),
      ),
    );
  }

  Widget _buildMenuButton({
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
    required double size,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(8.0),
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(16)),
        child: Icon(icon, color: color, size: 24),
      ),
    );
  }
}

class VehiclePinIcon extends StatelessWidget {
  final Color iconColor;
  final IconData vehicleIconData;
  final double size;
  final double bearing;

  const VehiclePinIcon({
    super.key,
    required this.iconColor,
    required this.vehicleIconData,
    this.size = 40.0,
    required this.bearing,
  });

  @override
  Widget build(BuildContext context) {
    final double whiteCircleSize = size * 0.6;
    final double innerIconSize = size * 0.4;
    final double arrowVerticalShift = -size * 0.275;

    return Transform.rotate(
      angle: bearing,
      child: SizedBox(
        width: size,
        height: size,
        child: Stack(
          alignment: Alignment.center,
          clipBehavior: Clip.none,
          children: [
            Transform.translate(
              offset: Offset(0, arrowVerticalShift),
              child: Icon(
                Icons.keyboard_arrow_up_sharp,
                color: Colors.red,
                size: size,
                shadows: [
                  Shadow(
                    blurRadius: 2.0,
                    color: Colors.black.withValues(alpha: 0.3),
                    offset: const Offset(0, 1),
                  ),
                ],
              ),
            ),
            Container(
              width: whiteCircleSize,
              height: whiteCircleSize,
              decoration: const BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: Icon(
                vehicleIconData,
                color: iconColor,
                size: innerIconSize,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class VehicleMarkerMenu extends StatefulWidget {
  final Widget child;
  final bool isBus;
  final int? status;
  final Stop? stop;
  final String? headsign;
  final String? timestamp;
  final VoidCallback onCompassPressed;
  final VoidCallback onWarningPressed;
  final VoidCallback onInfoPressed;

  const VehicleMarkerMenu({
    super.key,
    required this.child,
    required this.isBus,
    required this.headsign,
    required this.timestamp,
    required this.status,
    required this.stop,
    required this.onCompassPressed,
    required this.onWarningPressed,
    required this.onInfoPressed,
  });

  @override
  State<VehicleMarkerMenu> createState() => _VehicleMarkerMenuState();
}

class _VehicleMarkerMenuState extends State<VehicleMarkerMenu> {
  bool _showDetail = false;

  @override
  Widget build(BuildContext context) {
    const double buttonSize = 40.0; // for buttons
    String statusString;
    if (widget.status == 0) {
      statusString = "Arriving at";
    } else if (widget.status == 1) {
      statusString = "Stopped at";
    } else {
      statusString = "In transit to";
    }

    return SizedBox(
      width: double.infinity,
      height: double.infinity,
      child: Stack(
        alignment: Alignment.center,
        clipBehavior: Clip.none,
        children: [
          GestureDetector(
            onTap: () {
              setState(() {
                _showDetail = !_showDetail;
              });
            },

            child: widget.child,
          ),

          if (_showDetail)
            Positioned(
              top: 75,
              child: GestureDetector(
                onTap: () {
                  setState(() {
                    _showDetail = false;
                  });
                },
                child: Container(
                  padding: const EdgeInsets.all(8.0),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: .2),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 10.0, sigmaY: 10.0),
                      child: Container(
                        color: Colors.white.withValues(alpha: 0.4),
                        padding: const EdgeInsets.symmetric(
                          vertical: 8,
                          horizontal: 4,
                        ),
                        constraints: const BoxConstraints(maxWidth: 180),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            widget.headsign != null &&
                                    widget.headsign!.isNotEmpty
                                ? Container(
                                    padding: const EdgeInsets.all(8.0),
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                    child: Text(
                                      widget.isBus
                                          ? "${widget.headsign!} bus"
                                          : "${widget.headsign!} train",
                                      style: const TextStyle(
                                        color: Colors.black,
                                        fontSize: 14,
                                        fontWeight: FontWeight.bold,
                                      ),
                                      textAlign: TextAlign.center,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  )
                                : const SizedBox(),
                            Text(
                              statusString,
                              style: const TextStyle(
                                color: Colors.black,
                                fontSize: 12,
                              ),
                              textAlign: TextAlign.center,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              widget.stop?.stopName ?? "loading stop...",
                              style: const TextStyle(
                                color: Colors.black,
                                fontSize: 12,
                              ),
                              textAlign: TextAlign.center,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              "Status updated at ${widget.timestamp}",
                              style: const TextStyle(
                                color: Colors.black,
                                fontSize: 10,
                              ),
                              textAlign: TextAlign.center,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class StopMarkerPopup extends StatefulWidget {
  final String stopName;
  final String arrivalTime;
  final String departureTime;
  final Color color;

  const StopMarkerPopup({
    super.key,
    required this.stopName,
    required this.arrivalTime,
    required this.departureTime,
    required this.color,
  });

  @override
  State<StopMarkerPopup> createState() => _StopMarkerPopupState();
}

class _StopMarkerPopupState extends State<StopMarkerPopup> {
  bool _showDetail = false;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final double bottomSpacer = (constraints.maxHeight / 2) - 7.0;

        return Container(
          width: double.infinity,
          height: double.infinity,
          alignment: Alignment.bottomCenter,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.end,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_showDetail)
                GestureDetector(
                  onTap: () {
                    setState(() {
                      _showDetail = false;
                    });
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 3,
                    ),
                    margin: const EdgeInsets.only(bottom: 5),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      border: Border.all(color: widget.color, width: 1.5),
                      borderRadius: BorderRadius.circular(6),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.3),
                          blurRadius: 2,
                          offset: const Offset(0, 1),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        Text(
                          widget.stopName,
                          style: const TextStyle(
                            color: Colors.black,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const Text(
                          "Scheduled",
                          style: TextStyle(
                            color: Colors.black,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          "arrival: ${widget.arrivalTime},",
                          style: const TextStyle(
                            color: Colors.black,
                            fontSize: 10,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        Text(
                          "departure: ${widget.departureTime}",
                          style: const TextStyle(
                            color: Colors.black,
                            fontSize: 10,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ),

              GestureDetector(
                onTap: () {
                  setState(() {
                    _showDetail = !_showDetail;
                  });
                },
                child: Container(
                  width: 14,
                  height: 14,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    border: Border.all(color: widget.color, width: 3),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.2),
                        blurRadius: 2,
                        offset: const Offset(0, 1),
                      ),
                    ],
                  ),
                ),
              ),
              SizedBox(height: bottomSpacer),
            ],
          ),
        );
      },
    );
  }
}
