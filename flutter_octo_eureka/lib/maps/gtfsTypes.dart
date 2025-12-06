
import 'dart:ui';

class Trip {
  final String routeId;
  final String serviceId;
  final String tripId;
  final String tripHeadsign;
  final int directionId;
  final String blockId;
  final String shapeId;

  Trip({
    required this.routeId,
    required this.serviceId,
    required this.tripId,
    required this.tripHeadsign,
    required this.directionId,
    required this.blockId,
    required this.shapeId,
  });

  factory Trip.fromJson(Map<String, dynamic> json) {
    return Trip(
      routeId: json['route_id'] ?? '',
      serviceId: json['service_id'] ?? '',
      tripId: json['trip_id'] ?? '',
      tripHeadsign: json['trip_headsign'] ?? '',
      directionId: json['direction_id'] ?? 0,
      blockId: json['block_id'] ?? '',
      shapeId: json['shape_id'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'route_id': routeId,
      'service_id': serviceId,
      'trip_id': tripId,
      'trip_headsign': tripHeadsign,
      'direction_id': directionId,
      'block_id': blockId,
      'shape_id': shapeId,
    };
  }
}

class gtfsRoute {
  final String routeId;
  final String agencyId;
  final String routeShortName;
  final String routeLongName;
  final String routeDesc;
  final int routeType;
  final String routeUrl;
  final String routeColor;
  final String routeTextColor;

  gtfsRoute({
    required this.routeId,
    required this.agencyId,
    required this.routeShortName,
    required this.routeLongName,
    required this.routeDesc,
    required this.routeType,
    required this.routeUrl,
    required this.routeColor,
    required this.routeTextColor,
  });

  factory gtfsRoute.fromJson(Map<String, dynamic> json) {
    return gtfsRoute(
      routeId: json['route_id'] ?? '',
      agencyId: json['agency_id'] ?? '',
      routeShortName: json['route_short_name'] ?? '',
      routeLongName: json['route_long_name'] ?? '',
      routeDesc: json['route_desc'] ?? '',
      routeType: json['route_type'] ?? 0,
      routeUrl: json['route_url'] ?? '',
      routeColor: json['route_color'] ?? '',
      routeTextColor: json['route_text_color'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'route_id': routeId,
      'agency_id': agencyId,
      'route_short_name': routeShortName,
      'route_long_name': routeLongName,
      'route_desc': routeDesc,
      'route_type': routeType,
      'route_url': routeUrl,
      'route_color': routeColor,
      'route_text_color': routeTextColor,
    };
  }
}

class Shape {
  final String shapeId;
  final double shapePtLat;
  final double shapePtLon;
  final int shapePtSequence;
  final double shapeDistTraveled;

  Shape({
    required this.shapeId,
    required this.shapePtLat,
    required this.shapePtLon,
    required this.shapePtSequence,
    required this.shapeDistTraveled,
  });

  factory Shape.fromJson(Map<String, dynamic> json) {
    return Shape(
      shapeId: json['shape_id'] ?? '',
      shapePtLat: (json['shape_pt_lat'] as num?)?.toDouble() ?? 0.0,
      shapePtLon: (json['shape_pt_lon'] as num?)?.toDouble() ?? 0.0,
      shapePtSequence: json['shape_pt_sequence'] ?? 0,
      shapeDistTraveled: (json['shape_dist_traveled'] as num?)?.toDouble() ?? 0.0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'shape_id': shapeId,
      'shape_pt_lat': shapePtLat,
      'shape_pt_lon': shapePtLon,
      'shape_pt_sequence': shapePtSequence,
      'shape_dist_traveled': shapeDistTraveled,
    };
  }
}

class PolyShape {
  final String shapeId;
  final double shapePtLat;
  final double shapePtLon;
  final int shapePtSequence;
  final double shapeDistTraveled;
  final String? routeColor; // Field for the color string (e.g., "0076CE")

  PolyShape({
    required this.shapeId,
    required this.shapePtLat,
    required this.shapePtLon,
    required this.shapePtSequence,
    required this.shapeDistTraveled,
    this.routeColor,
  });

  // Helper to get the actual Flutter Color object
  Color get color {
    if (routeColor == null || routeColor!.isEmpty) {
      return const Color(0xFF000000); // Default to black if no color
    }
    try {
      // GTFS colors are usually 6-character hex strings (e.g., "0076CE")
      // We need to prefix "0xFF" for full opacity
      return Color(int.parse("0xFF$routeColor"));
    } catch (e) {
      return const Color(0xFF000000);
    }
  }

  // Mapper to create PolyShape from existing Shape + Color
  factory PolyShape.fromShape(Shape shape, String? color) {
    return PolyShape(
      shapeId: shape.shapeId,
      shapePtLat: shape.shapePtLat,
      shapePtLon: shape.shapePtLon,
      shapePtSequence: shape.shapePtSequence,
      shapeDistTraveled: shape.shapeDistTraveled,
      routeColor: color,
    );
  }

  factory PolyShape.fromJson(Map<String, dynamic> json) {
    return PolyShape(
      shapeId: json['shape_id'] ?? '',
      shapePtLat: (json['shape_pt_lat'] as num?)?.toDouble() ?? 0.0,
      shapePtLon: (json['shape_pt_lon'] as num?)?.toDouble() ?? 0.0,
      shapePtSequence: json['shape_pt_sequence'] ?? 0,
      shapeDistTraveled:
          (json['shape_dist_traveled'] as num?)?.toDouble() ?? 0.0,
      routeColor: json['route_color'],
    );
  }
}

class StopTime {
  final String tripId;
  final String arrivalTime;
  final String departureTime;
  final String stopId;
  final int stopSequence;
  final String stopHeadsign;
  final int pickupType;
  final int dropOffType;
  final double shapeDistTraveled;
  final int timepoint;

  StopTime({
    required this.tripId,
    required this.arrivalTime,
    required this.departureTime,
    required this.stopId,
    required this.stopSequence,
    required this.stopHeadsign,
    required this.pickupType,
    required this.dropOffType,
    required this.shapeDistTraveled,
    required this.timepoint,
  });

  factory StopTime.fromJson(Map<String, dynamic> json) {
    return StopTime(
      tripId: json['trip_id'] ?? '',
      arrivalTime: json['arrival_time'] ?? '',
      departureTime: json['departure_time'] ?? '',
      stopId: json['stop_id'] ?? '',
      stopSequence: json['stop_sequence'] ?? 0,
      stopHeadsign: json['stop_headsign'] ?? '',
      pickupType: json['pickup_type'] ?? 0,
      dropOffType: json['drop_off_type'] ?? 0,
      shapeDistTraveled: (json['shape_dist_traveled'] as num?)?.toDouble() ?? 0.0,
      timepoint: json['timepoint'] ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'trip_id': tripId,
      'arrival_time': arrivalTime,
      'departure_time': departureTime,
      'stop_id': stopId,
      'stop_sequence': stopSequence,
      'stop_headsign': stopHeadsign,
      'pickup_type': pickupType,
      'drop_off_type': dropOffType,
      'shape_dist_traveled': shapeDistTraveled,
      'timepoint': timepoint,
    };
  }
}

class Stop {
  final String stopId;
  final String stopCode;
  final String stopName;
  final String stopDesc;
  final double stopLat;
  final double stopLon;
  final String zoneId;
  final String stopUrl;
  final int locationType;
  final String parentStation;
  final String stopTimezone;
  final int wheelchairBoarding;

  Stop({
    required this.stopId,
    required this.stopCode,
    required this.stopName,
    required this.stopDesc,
    required this.stopLat,
    required this.stopLon,
    required this.zoneId,
    required this.stopUrl,
    required this.locationType,
    required this.parentStation,
    required this.stopTimezone,
    required this.wheelchairBoarding,
  });

  factory Stop.fromJson(Map<String, dynamic> json) {
    return Stop(
      stopId: json['stop_id'] ?? '',
      stopCode: json['stop_code'] ?? '',
      stopName: json['stop_name'] ?? '',
      stopDesc: json['stop_desc'] ?? '',
      stopLat: (json['stop_lat'] as num?)?.toDouble() ?? 0.0,
      stopLon: (json['stop_lon'] as num?)?.toDouble() ?? 0.0,
      zoneId: json['zone_id'] ?? '',
      stopUrl: json['stop_url'] ?? '',
      locationType: json['location_type'] ?? 0,
      parentStation: json['parent_station'] ?? '',
      stopTimezone: json['stop_timezone'] ?? '',
      wheelchairBoarding: json['wheelchair_boarding'] ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'stop_id': stopId,
      'stop_code': stopCode,
      'stop_name': stopName,
      'stop_desc': stopDesc,
      'stop_lat': stopLat,
      'stop_lon': stopLon,
      'zone_id': zoneId,
      'stop_url': stopUrl,
      'location_type': locationType,
      'parent_station': parentStation,
      'stop_timezone': stopTimezone,
      'wheelchair_boarding': wheelchairBoarding,
    };
  }
}

class AlertEntity {
  final String id;
  final Alert alert;

  AlertEntity({
    required this.id,
    required this.alert,
  });

  factory AlertEntity.fromJson(Map<String, dynamic> json) {
    return AlertEntity(
      id: json['id'] ?? '',
      alert: Alert.fromJson(json['alert'] ?? {}),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'alert': alert.toJson(),
    };
  }
}

class Alert {
  final List<ActivePeriod> activePeriod;
  final List<InformedEntity> informedEntity;
  final int cause;
  final int effect;
  final TranslatedString headerText;
  final TranslatedString descriptionText;

  Alert({
    required this.activePeriod,
    required this.informedEntity,
    required this.cause,
    required this.effect,
    required this.headerText,
    required this.descriptionText,
  });

  factory Alert.fromJson(Map<String, dynamic> json) {
    return Alert(
      activePeriod: (json['active_period'] as List?)
              ?.map((i) => ActivePeriod.fromJson(i))
              .toList() ??
          [],
      informedEntity: (json['informed_entity'] as List?)
              ?.map((i) => InformedEntity.fromJson(i))
              .toList() ??
          [],
      cause: json['cause'] ?? 0,
      effect: json['effect'] ?? 0,
      headerText: TranslatedString.fromJson(json['header_text'] ?? {}),
      descriptionText:
          TranslatedString.fromJson(json['description_text'] ?? {}),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'active_period': activePeriod.map((v) => v.toJson()).toList(),
      'informed_entity': informedEntity.map((v) => v.toJson()).toList(),
      'cause': cause,
      'effect': effect,
      'header_text': headerText.toJson(),
      'description_text': descriptionText.toJson(),
    };
  }
}

class ActivePeriod {
  final int start;
  final int? end;

  ActivePeriod({required this.start, this.end});

  factory ActivePeriod.fromJson(Map<String, dynamic> json) {
    return ActivePeriod(
      start: json['start'] ?? 0,
      end: json['end'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'start': start,
      if (end != null) 'end': end,
    };
  }
}

class InformedEntity {
  final String agencyId;
  final String routeId;
  final int routeType;
  final String stopId;

  InformedEntity({
    required this.agencyId,
    required this.routeId,
    required this.routeType,
    required this.stopId,
  });

  factory InformedEntity.fromJson(Map<String, dynamic> json) {
    return InformedEntity(
      agencyId: json['agency_id'] ?? '',
      routeId: json['route_id'] ?? '',
      routeType: json['route_type'] ?? 0,
      stopId: json['stop_id'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'agency_id': agencyId,
      'route_id': routeId,
      'route_type': routeType,
      'stop_id': stopId,
    };
  }
}

class TranslatedString {
  final List<Translation> translation;

  TranslatedString({required this.translation});

  factory TranslatedString.fromJson(Map<String, dynamic> json) {
    return TranslatedString(
      translation: (json['translation'] as List?)
              ?.map((i) => Translation.fromJson(i))
              .toList() ??
          [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'translation': translation.map((v) => v.toJson()).toList(),
    };
  }

  // Helper to quickly get English text
  String get text {
    if (translation.isEmpty) return '';
    try {
      return translation.firstWhere((t) => t.language == 'en').text;
    } catch (e) {
      return translation.first.text;
    }
  }
}

class Translation {
  final String text;
  final String language;

  Translation({required this.text, required this.language});

  factory Translation.fromJson(Map<String, dynamic> json) {
    return Translation(
      text: json['text'] ?? '',
      language: json['language'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'text': text,
      'language': language,
    };
  }
}

class TripUpdateEntity {
  final String id;
  final TripUpdate tripUpdate;

  TripUpdateEntity({
    required this.id,
    required this.tripUpdate,
  });

  factory TripUpdateEntity.fromJson(Map<String, dynamic> json) {
    return TripUpdateEntity(
      id: json['id'] ?? '',
      tripUpdate: TripUpdate.fromJson(json['trip_update'] ?? {}),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'trip_update': tripUpdate.toJson(),
    };
  }
}

class TripUpdate {
  final TripDescriptor trip;
  final VehicleDescriptor vehicle;
  final List<StopTimeUpdate> stopTimeUpdate;
  final int timestamp;

  TripUpdate({
    required this.trip,
    required this.vehicle,
    required this.stopTimeUpdate,
    required this.timestamp,
  });

  factory TripUpdate.fromJson(Map<String, dynamic> json) {
    return TripUpdate(
      trip: TripDescriptor.fromJson(json['trip'] ?? {}),
      vehicle: VehicleDescriptor.fromJson(json['vehicle'] ?? {}),
      stopTimeUpdate: (json['stop_time_update'] as List?)
              ?.map((i) => StopTimeUpdate.fromJson(i))
              .toList() ??
          [],
      timestamp: json['timestamp'] ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'trip': trip.toJson(),
      'vehicle': vehicle.toJson(),
      'stop_time_update': stopTimeUpdate.map((v) => v.toJson()).toList(),
      'timestamp': timestamp,
    };
  }
}

class TripDescriptor {
  final String tripId;
  final String routeId;
  final int directionId;
  final int scheduleRelationship;

  TripDescriptor({
    required this.tripId,
    required this.routeId,
    required this.directionId,
    required this.scheduleRelationship,
  });

  factory TripDescriptor.fromJson(Map<String, dynamic> json) {
    return TripDescriptor(
      tripId: json['trip_id'] ?? '',
      routeId: json['route_id'] ?? '',
      directionId: json['direction_id'] ?? 0,
      scheduleRelationship: json['schedule_relationship'] ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'trip_id': tripId,
      'route_id': routeId,
      'direction_id': directionId,
      'schedule_relationship': scheduleRelationship,
    };
  }
}

class VehicleDescriptor {
  final String id;
  final String label;

  VehicleDescriptor({required this.id, required this.label});

  factory VehicleDescriptor.fromJson(Map<String, dynamic> json) {
    return VehicleDescriptor(
      id: json['id'] ?? '',
      label: json['label'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'label': label,
    };
  }
}

class StopTimeUpdate {
  final int stopSequence;
  final String stopId;
  final StopTimeEvent arrival;
  final StopTimeEvent departure;
  final int scheduleRelationship;

  StopTimeUpdate({
    required this.stopSequence,
    required this.stopId,
    required this.arrival,
    required this.departure,
    required this.scheduleRelationship,
  });

  factory StopTimeUpdate.fromJson(Map<String, dynamic> json) {
    return StopTimeUpdate(
      stopSequence: json['stop_sequence'] ?? 0,
      stopId: json['stop_id'] ?? '',
      arrival: StopTimeEvent.fromJson(json['arrival'] ?? {}),
      departure: StopTimeEvent.fromJson(json['departure'] ?? {}),
      scheduleRelationship: json['schedule_relationship'] ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'stop_sequence': stopSequence,
      'stop_id': stopId,
      'arrival': arrival.toJson(),
      'departure': departure.toJson(),
      'schedule_relationship': scheduleRelationship,
    };
  }
}

class StopTimeEvent {
  final int time;

  StopTimeEvent({required this.time});

  factory StopTimeEvent.fromJson(Map<String, dynamic> json) {
    return StopTimeEvent(
      time: json['time'] ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'time': time,
    };
  }
}

class VehiclePositionEntity {
  final String id;
  final VehiclePosition vehicle;

  VehiclePositionEntity({
    required this.id,
    required this.vehicle,
  });

  factory VehiclePositionEntity.fromJson(Map<String, dynamic> json) {
    return VehiclePositionEntity(
      id: json['id'] ?? '',
      vehicle: VehiclePosition.fromJson(json['vehicle'] ?? {}),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'vehicle': vehicle.toJson(),
    };
  }
}

class VehiclePosition {
  final TripDescriptor trip;
  final VehicleDescriptor vehicle;
  final GeoPosition position;
  final String stopId;
  final int currentStatus;
  final int timestamp;
  final int occupancyStatus;

  VehiclePosition({
    required this.trip,
    required this.vehicle,
    required this.position,
    required this.stopId,
    required this.currentStatus,
    required this.timestamp,
    required this.occupancyStatus,
  });

  factory VehiclePosition.fromJson(Map<String, dynamic> json) {
    return VehiclePosition(
      trip: TripDescriptor.fromJson(json['trip'] ?? {}),
      vehicle: VehicleDescriptor.fromJson(json['vehicle'] ?? {}),
      position: GeoPosition.fromJson(json['position'] ?? {}),
      stopId: json['stop_id'] ?? '',
      currentStatus: json['current_status'] ?? 0,
      timestamp: json['timestamp'] ?? 0,
      occupancyStatus: json['occupancy_status'] ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'trip': trip.toJson(),
      'vehicle': vehicle.toJson(),
      'position': position.toJson(),
      'stop_id': stopId,
      'current_status': currentStatus,
      'timestamp': timestamp,
      'occupancy_status': occupancyStatus,
    };
  }
}

class GeoPosition {
  final double latitude;
  final double longitude;
  final double bearing;

  GeoPosition({
    required this.latitude,
    required this.longitude,
    required this.bearing,
  });

  factory GeoPosition.fromJson(Map<String, dynamic> json) {
    return GeoPosition(
      latitude: (json['latitude'] as num?)?.toDouble() ?? 0.0,
      longitude: (json['longitude'] as num?)?.toDouble() ?? 0.0,
      bearing: (json['bearing'] as num?)?.toDouble() ?? 0.0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'latitude': latitude,
      'longitude': longitude,
      'bearing': bearing,
    };
  }
}