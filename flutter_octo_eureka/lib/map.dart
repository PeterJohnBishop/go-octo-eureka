import 'package:flutter/material.dart';
import 'package:flutter_octo_eureka/maps/gtfsTypes.dart';
import 'package:flutter_octo_eureka/proto/proto.dart';
import 'package:flutter_octo_eureka/proto/protoTypes.dart';

class MapView extends StatefulWidget {
  const MapView({super.key});

  @override
  State<MapView> createState() => _MapViewState();
}

class _MapViewState extends State<MapView> {
  final ProtoService proto = ProtoService();
  bool _isLoading = true;
  List<RouteItem> _menuItems = [];
  List<VehiclePositionEntity> _vehiclePositions = [];
  List<AlertEntity> _activeAlerts = [];
  List<TripUpdateEntity> _tripUpdates = [];

  @override
  void initState() {
    super.initState();
    _handleRouteMenuLoading();
    _handleVehiclePositionLoading();
    _handleActiveAlertsLoading();
    _handleTripUpdatesLoading();
  }

  @override
  Widget build(BuildContext context) {
    return const Placeholder();
  }

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
}
