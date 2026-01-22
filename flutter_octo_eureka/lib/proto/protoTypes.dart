import 'dart:convert';

class RouteDetail {
    String routeId;
    String tripId;
    String shapeId;
    String routeShortName;
    String routeLongName;
    String routeColor;
    String routeTextColor;
    String tripHeadsign;
    String encodedPolyline;
    List<Stop> stops;

    RouteDetail({
        required this.routeId,
        required this.tripId,
        required this.shapeId,
        required this.routeShortName,
        required this.routeLongName,
        required this.routeColor,
        required this.routeTextColor,
        required this.tripHeadsign,
        required this.encodedPolyline,
        required this.stops,
    });

    factory RouteDetail.fromRawJson(String str) => RouteDetail.fromJson(json.decode(str));

    String toRawJson() => json.encode(toJson());

    factory RouteDetail.fromJson(Map<String, dynamic> json) => RouteDetail(
        routeId: json["route_id"],
        tripId: json["trip_id"],
        shapeId: json["shape_id"],
        routeShortName: json["route_short_name"],
        routeLongName: json["route_long_name"],
        routeColor: json["route_color"],
        routeTextColor: json["route_text_color"],
        tripHeadsign: json["trip_headsign"],
        encodedPolyline: json["encoded_polyline"],
        stops: List<Stop>.from(json["stops"].map((x) => Stop.fromJson(x))),
    );

    Map<String, dynamic> toJson() => {
        "route_id": routeId,
        "trip_id": tripId,
        "shape_id": shapeId,
        "route_short_name": routeShortName,
        "route_long_name": routeLongName,
        "route_color": routeColor,
        "route_text_color": routeTextColor,
        "trip_headsign": tripHeadsign,
        "encoded_polyline": encodedPolyline,
        "stops": List<dynamic>.from(stops.map((x) => x.toJson())),
    };
}

class Stop {
    String stopId;
    String stopName;
    double stopLat;
    double stopLon;

    Stop({
        required this.stopId,
        required this.stopName,
        required this.stopLat,
        required this.stopLon,
    });

    factory Stop.fromRawJson(String str) => Stop.fromJson(json.decode(str));

    String toRawJson() => json.encode(toJson());

    factory Stop.fromJson(Map<String, dynamic> json) => Stop(
        stopId: json["stop_id"],
        stopName: json["stop_name"],
        stopLat: json["stop_lat"]?.toDouble(),
        stopLon: json["stop_lon"]?.toDouble(),
    );

    Map<String, dynamic> toJson() => {
        "stop_id": stopId,
        "stop_name": stopName,
        "stop_lat": stopLat,
        "stop_lon": stopLon,
    };
}

class RouteItem {
    String routeId;
    String routeShortName;
    String routeLongName;
    String routeColor;
    String routeTextColor;
    int? routeType; 

    RouteItem({
        required this.routeId,
        required this.routeShortName,
        required this.routeLongName,
        required this.routeColor,
        required this.routeTextColor,
        this.routeType, 
    });

    factory RouteItem.fromRawJson(String str) => RouteItem.fromJson(json.decode(str));

    String toRawJson() => json.encode(toJson());

    factory RouteItem.fromJson(Map<String, dynamic> json) => RouteItem(
        routeId: json["route_id"],
        routeShortName: json["route_short_name"],
        routeLongName: json["route_long_name"],
        routeColor: json["route_color"],
        routeTextColor: json["route_text_color"],
        routeType: json["route_type"], 
    );

    Map<String, dynamic> toJson() => {
        "route_id": routeId,
        "route_short_name": routeShortName,
        "route_long_name": routeLongName,
        "route_color": routeColor,
        "route_text_color": routeTextColor,
        "route_type": routeType, 
    };
}
