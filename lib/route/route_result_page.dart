import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import '../models/route_data.dart';
import 'journey_tracking_screen.dart';

class RouteResultPage extends StatefulWidget {
  final String from;
  final String to;
  final String vehicle;
  final int ecoPoints;
  final LatLng fromLocation;
  final LatLng toLocation;

  const RouteResultPage({
    super.key,
    required this.from,
    required this.to,
    required this.vehicle,
    required this.ecoPoints,
    required this.fromLocation,
    required this.toLocation,
  });

  @override
  State<RouteResultPage> createState() => _RouteResultPageState();
}

class _RouteResultPageState extends State<RouteResultPage> {
  // Properties
  late Future<RouteData> _routeData;
  final MapController _mapController = MapController();
  late LatLng _mapCenter;
  late double _mapZoom;

  // Lifecycle Methods
  @override
  void initState() {
    super.initState();
    _initializeMap();
    _fetchInitialRouteData();
  }

  void _initializeMap() {
    _mapCenter = LatLng(
      (widget.fromLocation.latitude + widget.toLocation.latitude) / 2,
      (widget.fromLocation.longitude + widget.toLocation.longitude) / 2,
    );
    _mapZoom = 5.0;
  }

  void _fetchInitialRouteData() {
    _routeData = _fetchRouteData();
  }

  // Route Data Methods
  Future<RouteData> _fetchRouteData() async {
    try {
      _logRouteFetchStart();
      final routeData = await _fetchRouteFromOSRM();
      _adjustMapToRoute(routeData.points);
      return routeData;
    } catch (e) {
      _logRouteFetchError(e);
      return _createFallbackRoute();
    }
  }

  void _logRouteFetchStart() {
    if (!kDebugMode) return;
    debugPrint('Fetching route from OSRM API...');
    debugPrint(
      'From: ${widget.fromLocation.latitude}, ${widget.fromLocation.longitude}',
    );
    debugPrint(
      'To: ${widget.toLocation.latitude}, ${widget.toLocation.longitude}',
    );
  }

  Future<RouteData> _fetchRouteFromOSRM() async {
    final url = _buildOSRMUrl();
    _logOSRMUrl(url);

    final response = await http.get(url).timeout(const Duration(seconds: 10));
    _logResponseStatus(response);

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      return _parseOSRMResponse(data);
    } else {
      throw Exception('OSRM API error: ${response.statusCode}');
    }
  }

  Uri _buildOSRMUrl() {
    return Uri.parse(
      'https://router.project-osrm.org/route/v1/driving/'
      '${widget.fromLocation.longitude},${widget.fromLocation.latitude};'
      '${widget.toLocation.longitude},${widget.toLocation.latitude}'
      '?overview=full&geometries=geojson&steps=true',
    );
  }

  void _logOSRMUrl(Uri url) {
    if (kDebugMode) {
      debugPrint('OSRM URL: $url');
    }
  }

  void _logResponseStatus(http.Response response) {
    if (kDebugMode) {
      debugPrint('Response status: ${response.statusCode}');
    }
  }

  RouteData _parseOSRMResponse(Map<String, dynamic> data) {
    if (kDebugMode) {
      debugPrint('OSRM response received');
    }

    if (data['routes'] == null || data['routes'].isEmpty) {
      throw Exception('No routes found in response');
    }

    final route = data['routes'][0];
    final routePoints = _extractRoutePoints(route['geometry']['coordinates']);
    final distance = _calculateRouteDistance(route['distance']);
    final duration = _calculateRouteDuration(route['duration']);
    final instructions = _extractInstructions(route['legs']);

    _logRouteDetails(distance, duration, routePoints.length);

    return RouteData(
      points: routePoints,
      distance: distance,
      duration: duration,
      instructions: instructions,
    );
  }

  List<LatLng> _extractRoutePoints(List<dynamic> geometry) {
    return geometry.map<LatLng>((coord) {
      return LatLng(coord[1], coord[0]);
    }).toList();
  }

  double _calculateRouteDistance(double distanceInMeters) {
    return distanceInMeters / 1000;
  }

  double _calculateRouteDuration(double durationInSeconds) {
    return durationInSeconds / 60;
  }

  void _logRouteDetails(double distance, double duration, int pointCount) {
    if (!kDebugMode) return;
    debugPrint('Route distance: ${distance.toStringAsFixed(2)} km');
    debugPrint('Route duration: ${duration.toStringAsFixed(0)} min');
    debugPrint('Route has $pointCount points');
  }

  void _logRouteFetchError(Object e) {
    if (kDebugMode) {
      debugPrint('Error fetching route: $e');
    }
  }

  RouteData _createFallbackRoute() {
    final fallbackDistance = _calculateStraightDistance();
    return RouteData(
      points: [widget.fromLocation, widget.toLocation],
      distance: fallbackDistance,
      duration: _calculateEstimatedDuration(fallbackDistance),
      instructions: [],
    );
  }

  List<RouteInstruction> _extractInstructions(List<dynamic>? legs) {
    final instructions = <RouteInstruction>[];
    if (legs == null || legs.isEmpty) return instructions;

    for (var leg in legs) {
      final steps = leg['steps'] as List<dynamic>?;
      if (steps == null) continue;

      for (var step in steps) {
        final maneuver = step['maneuver'] as Map<String, dynamic>?;
        if (maneuver == null) continue;

        final instruction = RouteInstruction(
          distance: (step['distance'] as num).toDouble(),
          duration: (step['duration'] as num).toDouble(),
          instruction: maneuver['instruction']?.toString() ?? 'Continue',
          type: maneuver['type']?.toString() ?? 'turn',
          modifier: maneuver['modifier']?.toString() ?? '',
          location: LatLng(
            (maneuver['location'] as List<dynamic>)[1] as double,
            (maneuver['location'] as List<dynamic>)[0] as double,
          ),
        );
        instructions.add(instruction);
      }
    }
    return instructions;
  }

  // Map Methods
  void _adjustMapToRoute(List<LatLng> points) {
    if (points.isEmpty) return;

    final bounds = _calculateRouteBounds(points);
    final center = _calculateBoundsCenter(bounds);
    final zoom = _calculateZoomLevel(bounds);

    _mapController.move(center, zoom);
  }

  Map<String, double> _calculateRouteBounds(List<LatLng> points) {
    double minLat = points[0].latitude;
    double maxLat = points[0].latitude;
    double minLng = points[0].longitude;
    double maxLng = points[0].longitude;

    for (var point in points) {
      if (point.latitude < minLat) minLat = point.latitude;
      if (point.latitude > maxLat) maxLat = point.latitude;
      if (point.longitude < minLng) minLng = point.longitude;
      if (point.longitude > maxLng) maxLng = point.longitude;
    }

    return {
      'minLat': minLat,
      'maxLat': maxLat,
      'minLng': minLng,
      'maxLng': maxLng,
    };
  }

  LatLng _calculateBoundsCenter(Map<String, double> bounds) {
    return LatLng(
      (bounds['minLat']! + bounds['maxLat']!) / 2,
      (bounds['minLng']! + bounds['maxLng']!) / 2,
    );
  }

  double _calculateZoomLevel(Map<String, double> bounds) {
    final latDiff = bounds['maxLat']! - bounds['minLat']!;
    final lngDiff = bounds['maxLng']! - bounds['minLng']!;
    final maxDiff = latDiff > lngDiff ? latDiff : lngDiff;

    if (maxDiff > 20) return 4.0;
    if (maxDiff > 10) return 5.0;
    if (maxDiff > 5) return 6.0;
    if (maxDiff > 2) return 7.0;
    if (maxDiff > 1) return 8.0;
    if (maxDiff > 0.5) return 9.0;
    if (maxDiff > 0.2) return 10.0;
    if (maxDiff > 0.1) return 11.0;
    return 12.0;
  }

  // Calculation Methods
  double _calculateStraightDistance() {
    final distance = Distance();
    return distance.as(
      LengthUnit.Kilometer,
      widget.fromLocation,
      widget.toLocation,
    );
  }

  double _calculateEstimatedDuration(double distanceInKm) {
    final speed = _getVehicleSpeed(widget.vehicle);
    return (distanceInKm / speed) * 60;
  }

  double _getVehicleSpeed(String vehicle) {
    switch (vehicle.toLowerCase()) {
      case 'car':
        return 80.0;
      case 'bicycle':
        return 20.0;
      case 'walking':
      case 'walk':
        return 5.0;
      default:
        return 60.0;
    }
  }

  // UI Build Methods
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF151717),
      appBar: _buildAppBar(),
      body: _buildBody(),
    );
  }

  AppBar _buildAppBar() {
    return AppBar(
      title: const Text("Route Result", style: TextStyle(color: Colors.white)),
      backgroundColor: Colors.black,
      iconTheme: const IconThemeData(color: Colors.white),
    );
  }

  Widget _buildBody() {
    return FutureBuilder<RouteData>(
      future: _routeData,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return _buildLoadingScreen();
        }

        if (snapshot.hasError) {
          return _buildErrorScreen(snapshot.error.toString());
        }

        final routeData = snapshot.data!;
        return Column(
          children: [
            Expanded(child: _buildMap(routeData.points)),
            _buildInfoPanel(routeData),
          ],
        );
      },
    );
  }

  Widget _buildLoadingScreen() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(color: Colors.green),
          SizedBox(height: 20),
          Text(
            "Calculating optimal route...",
            style: TextStyle(color: Colors.white, fontSize: 16),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorScreen(String error) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, color: Colors.red, size: 64),
            const SizedBox(height: 20),
            const Text(
              "Unable to calculate route",
              style: TextStyle(color: Colors.white, fontSize: 18),
            ),
            const SizedBox(height: 10),
            Text(
              "Error: $error",
              style: const TextStyle(color: Colors.grey, fontSize: 12),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _retryRouteFetch,
              style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
              child: const Text("Try Again"),
            ),
          ],
        ),
      ),
    );
  }

  void _retryRouteFetch() {
    setState(() {
      _routeData = _fetchRouteData();
    });
  }

  Widget _buildMap(List<LatLng> routePoints) {
    return FlutterMap(
      mapController: _mapController,
      options: MapOptions(
        initialCenter: _mapCenter,
        initialZoom: _mapZoom,
        interactionOptions: const InteractionOptions(
          flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
        ),
        onMapReady: () => _onMapReady(routePoints),
      ),
      children: [
        _buildTileLayer(),
        _buildPolylineLayer(routePoints),
        _buildMarkerLayer(),
        _buildMapControls(),
      ],
    );
  }

  void _onMapReady(List<LatLng> routePoints) {
    if (routePoints.length > 2) {
      _adjustMapToRoute(routePoints);
    }
  }

  TileLayer _buildTileLayer() {
    return TileLayer(
      urlTemplate: 'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png',
      subdomains: const ['a', 'b', 'c'],
    );
  }

  PolylineLayer _buildPolylineLayer(List<LatLng> routePoints) {
    return PolylineLayer(
      polylines: [
        Polyline(points: routePoints, color: Colors.green, strokeWidth: 4.0),
      ],
    );
  }

  MarkerLayer _buildMarkerLayer() {
    return MarkerLayer(markers: [_buildStartMarker(), _buildEndMarker()]);
  }

  Marker _buildStartMarker() {
    return Marker(
      point: widget.fromLocation,
      width: 40,
      height: 40,
      child: _buildMarkerContainer(
        color: Colors.green,
        icon: Icons.location_on,
      ),
    );
  }

  Marker _buildEndMarker() {
    return Marker(
      point: widget.toLocation,
      width: 40,
      height: 40,
      child: _buildMarkerContainer(color: Colors.red, icon: Icons.location_on),
    );
  }

  Container _buildMarkerContainer({
    required Color color,
    required IconData icon,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 3),
      ),
      child: Icon(icon, color: Colors.white),
    );
  }

  Widget _buildMapControls() {
    return Align(
      alignment: Alignment.bottomRight,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildZoomInButton(),
            const SizedBox(height: 8),
            _buildZoomOutButton(),
            const SizedBox(height: 8),
            _buildCenterButton(),
          ],
        ),
      ),
    );
  }

  Widget _buildZoomInButton() {
    return _buildMapControlButton(
      icon: Icons.add,
      onPressed: () => _zoomMap(1),
    );
  }

  Widget _buildZoomOutButton() {
    return _buildMapControlButton(
      icon: Icons.remove,
      onPressed: () => _zoomMap(-1),
    );
  }

  Widget _buildCenterButton() {
    return _buildMapControlButton(
      icon: Icons.center_focus_strong,
      onPressed: _centerMapOnRoute,
    );
  }

  Widget _buildMapControlButton({
    required IconData icon,
    required VoidCallback onPressed,
  }) {
    return FloatingActionButton.small(
      onPressed: onPressed,
      // ignore: deprecated_member_use
      backgroundColor: Colors.black.withOpacity(0.7),
      child: Icon(icon, color: Colors.white),
    );
  }

  void _zoomMap(double delta) {
    _mapController.move(
      _mapController.camera.center,
      _mapController.camera.zoom + delta,
    );
  }

  void _centerMapOnRoute() {
    _routeData.then((routeData) {
      _adjustMapToRoute(routeData.points);
    });
  }

  Widget _buildInfoPanel(RouteData routeData) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[900],
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildRouteInfoSection(),
          const Divider(color: Colors.grey, height: 20),
          _buildRouteStatsSection(routeData),
          const SizedBox(height: 20),
          _buildStartJourneyButton(routeData),
        ],
      ),
    );
  }

  Widget _buildRouteInfoSection() {
    return Column(
      children: [
        _buildInfoRow(
          icon: Icons.place,
          title: "From",
          value: widget.from,
          iconColor: Colors.green,
        ),
        _buildInfoRow(
          icon: Icons.flag,
          title: "To",
          value: widget.to,
          iconColor: Colors.red,
        ),
        _buildInfoRow(
          icon: _getVehicleIcon(widget.vehicle),
          title: "Vehicle",
          value: widget.vehicle,
          iconColor: Colors.blue,
        ),
      ],
    );
  }

  Widget _buildInfoRow({
    required IconData icon,
    required String title,
    required String value,
    required Color iconColor,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, color: iconColor, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              title,
              style: const TextStyle(color: Colors.grey, fontSize: 14),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              value,
              style: const TextStyle(color: Colors.white, fontSize: 14),
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRouteStatsSection(RouteData routeData) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: [
        _buildStatCard(
          icon: Icons.directions,
          value: "${routeData.distance.toStringAsFixed(1)} km",
          label: "Distance",
          color: Colors.blue,
        ),
        _buildStatCard(
          icon: Icons.timer,
          value: "${routeData.duration.toStringAsFixed(0)} min",
          label: "Duration",
          color: Colors.orange,
        ),
        _buildStatCard(
          icon: Icons.eco,
          value: "${widget.ecoPoints} pts",
          label: "Eco Points",
          color: Colors.green,
        ),
      ],
    );
  }

  Widget _buildStatCard({
    required IconData icon,
    required String value,
    required String label,
    required Color color,
  }) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            // ignore: deprecated_member_use
            color: color.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: color, size: 20),
        ),
        const SizedBox(height: 5),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(label, style: TextStyle(color: Colors.grey[400], fontSize: 12)),
      ],
    );
  }

  Widget _buildStartJourneyButton(RouteData routeData) {
    return ElevatedButton.icon(
      onPressed: () => _startJourney(routeData),
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.green,
        padding: const EdgeInsets.symmetric(vertical: 15),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
      icon: const Icon(Icons.directions_walk),
      label: const Text(
        "Start Journey",
        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
      ),
    );
  }

  Future<void> _startJourney(RouteData routeData) async {
    final permissionGranted = await _checkLocationPermission();
    if (!permissionGranted) {
      _showLocationPermissionError();
      return;
    }

    _navigateToJourneyTrackingScreen(routeData);
  }

  Future<bool> _checkLocationPermission() async {
    final permission = await Geolocator.checkPermission();

    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      final requestedPermission = await Geolocator.requestPermission();
      return requestedPermission == LocationPermission.whileInUse ||
          requestedPermission == LocationPermission.always;
    }

    return true;
  }

  void _showLocationPermissionError() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Location permission is required for journey tracking'),
        backgroundColor: Colors.red,
      ),
    );
  }

  void _navigateToJourneyTrackingScreen(RouteData routeData) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => JourneyTrackingScreen(
          routeData: routeData,
          from: widget.from,
          to: widget.to,
          vehicle: widget.vehicle,
          ecoPoints: widget.ecoPoints,
          fromLocation: widget.fromLocation,
          toLocation: widget.toLocation,
        ),
      ),
    );
  }

  IconData _getVehicleIcon(String vehicle) {
    switch (vehicle.toLowerCase()) {
      case 'car':
        return Icons.directions_car;
      case 'bicycle':
        return Icons.pedal_bike;
      case 'walking':
      case 'walk':
        return Icons.directions_walk;
      case 'bus':
        return Icons.directions_bus;
      case 'train':
        return Icons.train;
      default:
        return Icons.directions;
    }
  }
}
