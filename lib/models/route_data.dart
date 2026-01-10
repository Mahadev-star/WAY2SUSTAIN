import 'package:latlong2/latlong.dart';

class RouteData {
  final List<LatLng> points;
  final double distance;
  final double duration;
  final List<RouteInstruction> instructions;

  RouteData({
    required this.points,
    required this.distance,
    required this.duration,
    this.instructions = const [],
  });
}

class RouteInstruction {
  final double distance;
  final double duration;
  final String instruction;
  final String type;
  final String modifier;
  final LatLng location;

  RouteInstruction({
    required this.distance,
    required this.duration,
    required this.instruction,
    required this.type,
    required this.modifier,
    required this.location,
  });
}
