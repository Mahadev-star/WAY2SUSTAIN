import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/route_data.dart';

class JourneyTrackingScreen extends StatefulWidget {
  final RouteData routeData;
  final String from;
  final String to;
  final String vehicle;
  final int ecoPoints;
  final LatLng fromLocation;
  final LatLng toLocation;

  const JourneyTrackingScreen({
    super.key,
    required this.routeData,
    required this.from,
    required this.to,
    required this.vehicle,
    required this.ecoPoints,
    required this.fromLocation,
    required this.toLocation,
  });

  @override
  State<JourneyTrackingScreen> createState() => _JourneyTrackingScreenState();
}

class _JourneyTrackingScreenState extends State<JourneyTrackingScreen> {
  // Location tracking
  StreamSubscription<Position>? _positionStream;
  LatLng? _currentLocation;

  // Journey statistics
  double _distanceTraveled = 0.0;
  double _progress = 0.0;
  DateTime? _journeyStartTime;
  double _averageSpeed = 0.0;
  double _maxSpeed = 0.0;
  int _caloriesBurned = 0;
  double _co2Saved = 0.0;

  // Navigation
  final List<Position> _positionHistory = [];
  int _currentInstructionIndex = 0;
  bool _isJourneyComplete = false;
  bool _isPaused = false;

  // Map
  final MapController _mapController = MapController();
  final List<LatLng> _traveledRoute = [];

  // Timer
  Timer? _journeyTimer;
  Duration _elapsedTime = Duration.zero;

  // Notifications
  final List<String> _milestoneMessages = [
    "Great start! 🚀",
    "You're 25% there! 🌟",
    "Halfway there! Keep going! 🎯",
    "Almost there! 75% complete! ⚡",
    "Destination reached! 🎉",
  ];

  @override
  void initState() {
    super.initState();
    _startJourney();
  }

  @override
  void dispose() {
    _stopJourneyTracking();
    _journeyTimer?.cancel();
    super.dispose();
  }

  void _startJourney() async {
    _journeyStartTime = DateTime.now();
    _startTimer();
    await _startLocationTracking();

    // Initial notification
    _showNotification("Journey Started!", "Head towards ${widget.to}");
  }

  void _startTimer() {
    _journeyTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!_isPaused && !_isJourneyComplete) {
        setState(() {
          _elapsedTime = _elapsedTime + const Duration(seconds: 1);
        });
      }
    });
  }

  Future<void> _startLocationTracking() async {
    _positionStream =
        Geolocator.getPositionStream(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.high,
            distanceFilter: 5,
          ),
        ).listen((Position position) {
          _updateLocation(position);
        });
  }

  void _updateLocation(Position position) {
    if (_isJourneyComplete || _isPaused) return;

    setState(() {
      _currentLocation = LatLng(position.latitude, position.longitude);
      _positionHistory.add(position);

      // Add to traveled route
      _traveledRoute.add(_currentLocation!);

      // Update statistics
      _updateStatistics(position);

      // Update progress
      _updateProgress();

      // Check for milestones
      _checkMilestones();

      // Update navigation instructions
      _updateNavigationInstructions();

      // Check if destination reached
      _checkDestinationReached();
    });
  }

  void _updateStatistics(Position position) {
    // Calculate distance from last position
    if (_positionHistory.length > 1) {
      final lastPosition = _positionHistory[_positionHistory.length - 2];
      final distance = Geolocator.distanceBetween(
        lastPosition.latitude,
        lastPosition.longitude,
        position.latitude,
        position.longitude,
      );
      _distanceTraveled += distance / 1000;
    }

    // Update speed
    if (position.speed > 0) {
      _averageSpeed =
          ((_averageSpeed * (_positionHistory.length - 1)) +
              position.speed * 3.6) /
          _positionHistory.length;
      _maxSpeed = max(_maxSpeed, position.speed * 3.6);
    }

    // Calculate calories
    if (widget.vehicle.toLowerCase() == 'walking' ||
        widget.vehicle.toLowerCase() == 'walk') {
      _caloriesBurned = (_distanceTraveled * 70).round();
    } else if (widget.vehicle.toLowerCase() == 'bicycle') {
      _caloriesBurned = (_distanceTraveled * 30).round();
    }

    // Calculate CO2 saved
    _co2Saved = _distanceTraveled * 0.12;
  }

  void _updateProgress() {
    if (_currentLocation == null) return;

    // Find nearest point on route
    double minDistance = double.infinity;
    for (var point in widget.routeData.points) {
      final distance = Geolocator.distanceBetween(
        _currentLocation!.latitude,
        _currentLocation!.longitude,
        point.latitude,
        point.longitude,
      );
      minDistance = min(minDistance, distance);
    }

    // Simple progress calculation
    _progress = min(_distanceTraveled / widget.routeData.distance, 1.0);
  }

  void _checkMilestones() {
    final milestones = [0.25, 0.5, 0.75, 1.0];
    for (int i = 0; i < milestones.length; i++) {
      if (_progress >= milestones[i] && (_progress - milestones[i]) < 0.01) {
        _showMilestoneNotification(i);
        break;
      }
    }
  }

  void _showMilestoneNotification(int milestoneIndex) {
    if (milestoneIndex < _milestoneMessages.length) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_milestoneMessages[milestoneIndex]),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  void _updateNavigationInstructions() {
    if (widget.routeData.instructions.isEmpty || _currentLocation == null) {
      return;
    }

    // Find closest instruction
    double minDistance = double.infinity;
    int closestIndex = _currentInstructionIndex;

    for (
      int i = _currentInstructionIndex;
      i < widget.routeData.instructions.length;
      i++
    ) {
      final instruction = widget.routeData.instructions[i];
      final distance = Geolocator.distanceBetween(
        _currentLocation!.latitude,
        _currentLocation!.longitude,
        instruction.location.latitude,
        instruction.location.longitude,
      );

      if (distance < minDistance) {
        minDistance = distance;
        closestIndex = i;
      }
    }

    if (closestIndex != _currentInstructionIndex && minDistance < 50) {
      setState(() {
        _currentInstructionIndex = closestIndex;
      });

      final instruction = widget.routeData.instructions[closestIndex];
      _showNotification(
        "Next: ${instruction.instruction}",
        "In ${(instruction.distance / 1000).toStringAsFixed(1)} km",
      );
    }
  }

  void _checkDestinationReached() {
    if (_currentLocation == null) return;

    final distanceToDestination = Geolocator.distanceBetween(
      _currentLocation!.latitude,
      _currentLocation!.longitude,
      widget.toLocation.latitude,
      widget.toLocation.longitude,
    );

    if (distanceToDestination < 50) {
      _completeJourney();
    }
  }

  void _completeJourney() {
    setState(() {
      _isJourneyComplete = true;
      _progress = 1.0;
    });

    _stopJourneyTracking();
    _journeyTimer?.cancel();

    // Show completion
    _showJourneyCompletionDialog();

    // Save journey
    _saveJourney();
  }

  void _stopJourneyTracking() {
    _positionStream?.cancel();
  }

  void _togglePause() {
    setState(() {
      _isPaused = !_isPaused;
    });

    if (_isPaused) {
      _positionStream?.pause();
    } else {
      _positionStream?.resume();
    }
  }

  void _showNotification(String title, String body) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
            Text(body, style: const TextStyle(fontSize: 12)),
          ],
        ),
        backgroundColor: Color.fromRGBO(55, 71, 79, 1), // blueGrey[800]
        duration: const Duration(seconds: 3),
      ),
    );
  }

  Future<void> _saveJourney() async {
    final prefs = await SharedPreferences.getInstance();
    final journeyData = {
      'date': DateFormat('yyyy-MM-dd HH:mm').format(_journeyStartTime!),
      'from': widget.from,
      'to': widget.to,
      'vehicle': widget.vehicle,
      'distance': _distanceTraveled.toStringAsFixed(2),
      'duration': _formatDuration(_elapsedTime),
      'ecoPoints': widget.ecoPoints.toString(),
      'calories': _caloriesBurned.toString(),
      'co2Saved': _co2Saved.toStringAsFixed(2),
    };

    final journeys = prefs.getStringList('journey_history') ?? [];
    journeys.add(json.encode(journeyData));
    await prefs.setStringList('journey_history', journeys);

    final totalPoints = prefs.getInt('total_eco_points') ?? 0;
    await prefs.setInt('total_eco_points', totalPoints + widget.ecoPoints);
  }

  void _showJourneyCompletionDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey[900],
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          "🎉 Journey Complete!",
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          textAlign: TextAlign.center,
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildStatItem(
                Icons.directions,
                "Distance",
                "${_distanceTraveled.toStringAsFixed(2)} km",
              ),
              _buildStatItem(
                Icons.timer,
                "Time",
                _formatDuration(_elapsedTime),
              ),
              _buildStatItem(
                Icons.speed,
                "Avg Speed",
                "${_averageSpeed.toStringAsFixed(1)} km/h",
              ),
              _buildStatItem(
                Icons.fireplace,
                "Calories",
                "$_caloriesBurned cal",
              ),
              _buildStatItem(
                Icons.eco,
                "CO₂ Saved",
                "${_co2Saved.toStringAsFixed(2)} kg",
              ),
              _buildStatItem(
                Icons.workspace_premium,
                "Eco Points Earned",
                "+${widget.ecoPoints} pts",
              ),
              const SizedBox(height: 20),
              const Text(
                "Congratulations on your sustainable journey!",
                style: TextStyle(color: Colors.green, fontSize: 12),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              "CONTINUE",
              style: TextStyle(
                color: Colors.green,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, color: Colors.green, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(color: Colors.grey, fontSize: 14),
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  String _formatDuration(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    final seconds = duration.inSeconds.remainder(60);

    if (hours > 0) {
      return '${hours}h ${minutes}m ${seconds}s';
    } else if (minutes > 0) {
      return '${minutes}m ${seconds}s';
    } else {
      return '${seconds}s';
    }
  }

  // Custom Progress Bar Widget
  Widget _buildProgressBar(double progress) {
    return Container(
      height: 20,
      decoration: BoxDecoration(
        color: Colors.grey[800],
        borderRadius: BorderRadius.circular(10),
      ),
      child: Stack(
        children: [
          // Background
          Container(
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(10)),
          ),
          // Progress
          FractionallySizedBox(
            widthFactor: progress,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.green,
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
          // Percentage Text
          Center(
            child: Text(
              "${(progress * 100).toStringAsFixed(0)}%",
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF151717),
      appBar: AppBar(
        title: Text(
          _isJourneyComplete ? "Journey Complete" : "Tracking Journey",
          style: const TextStyle(color: Colors.white),
        ),
        backgroundColor: Colors.black,
        actions: [
          IconButton(
            icon: Icon(
              _isPaused ? Icons.play_arrow : Icons.pause,
              color: Colors.white,
            ),
            onPressed: _isJourneyComplete ? null : _togglePause,
          ),
        ],
      ),
      body: Column(
        children: [
          // Progress Section
          Container(
            padding: const EdgeInsets.all(20),
            color: Colors.grey[900],
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.from,
                          style: const TextStyle(
                            color: Colors.green,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 5),
                        Text(
                          "To ${widget.to}",
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          "${(_progress * 100).toStringAsFixed(0)}%",
                          style: const TextStyle(
                            color: Colors.green,
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          "${_distanceTraveled.toStringAsFixed(1)} / ${widget.routeData.distance.toStringAsFixed(1)} km",
                          style: const TextStyle(
                            color: Colors.grey,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                _buildProgressBar(_progress),
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      "Time: ${_formatDuration(_elapsedTime)}",
                      style: const TextStyle(color: Colors.grey),
                    ),
                    Text(
                      "Speed: ${_averageSpeed.toStringAsFixed(1)} km/h",
                      style: const TextStyle(color: Colors.grey),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Map Section
          Expanded(
            child: Stack(
              children: [
                FlutterMap(
                  mapController: _mapController,
                  options: MapOptions(
                    // ignore: deprecated_member_use
                    center: widget.fromLocation,
                    // ignore: deprecated_member_use
                    zoom: 13.0,
                    // ignore: deprecated_member_use
                    interactiveFlags:
                        InteractiveFlag.all & ~InteractiveFlag.rotate,
                    onMapReady: () {
                      if (_currentLocation != null) {
                        _mapController.move(_currentLocation!, 13.0);
                      }
                    },
                  ),
                  children: [
                    TileLayer(
                      urlTemplate:
                          'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png',
                      subdomains: const ['a', 'b', 'c'],
                    ),
                    // Original route
                    PolylineLayer(
                      polylines: [
                        Polyline(
                          points: widget.routeData.points,
                          color: const Color.fromRGBO(128, 128, 128, 0.5),
                          strokeWidth: 3.0,
                        ),
                      ],
                    ),
                    // Traveled route
                    if (_traveledRoute.length > 1)
                      PolylineLayer(
                        polylines: [
                          Polyline(
                            points: _traveledRoute,
                            color: Colors.green,
                            strokeWidth: 4.0,
                          ),
                        ],
                      ),
                    // Start and end markers
                    MarkerLayer(
                      markers: [
                        Marker(
                          point: widget.fromLocation,
                          width: 40,
                          height: 40,
                          child: Container(
                            decoration: BoxDecoration(
                              color: Colors.green,
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 3),
                            ),
                            child: const Icon(
                              Icons.location_on,
                              color: Colors.white,
                            ),
                          ),
                        ),
                        Marker(
                          point: widget.toLocation,
                          width: 40,
                          height: 40,
                          child: Container(
                            decoration: BoxDecoration(
                              color: Colors.red,
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 3),
                            ),
                            child: const Icon(
                              Icons.location_on,
                              color: Colors.white,
                            ),
                          ),
                        ),
                        // Current location marker
                        if (_currentLocation != null)
                          Marker(
                            point: _currentLocation!,
                            width: 50,
                            height: 50,
                            child: Container(
                              decoration: BoxDecoration(
                                color: Colors.blue,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: Colors.white,
                                  width: 3,
                                ),
                              ),
                              child: const Icon(
                                Icons.navigation,
                                color: Colors.white,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),

                // Navigation Instruction Card
                if (widget.routeData.instructions.isNotEmpty &&
                    _currentInstructionIndex <
                        widget.routeData.instructions.length)
                  Positioned(
                    top: 10,
                    left: 10,
                    right: 10,
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.black.withAlpha(204), // 0.8 opacity
                        borderRadius: BorderRadius.circular(15),
                        border: Border.all(color: Colors.green, width: 2),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              _getInstructionIcon(
                                widget
                                    .routeData
                                    .instructions[_currentInstructionIndex]
                                    .type,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  widget
                                      .routeData
                                      .instructions[_currentInstructionIndex]
                                      .instruction,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 5),
                          Text(
                            "In ${(widget.routeData.instructions[_currentInstructionIndex].distance / 1000).toStringAsFixed(1)} km",
                            style: const TextStyle(color: Colors.grey),
                          ),
                        ],
                      ),
                    ),
                  ),

                // Current Stats Card
                Positioned(
                  bottom: 10,
                  left: 10,
                  right: 10,
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.black.withAlpha(204), // 0.8 opacity
                      borderRadius: BorderRadius.circular(15),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _buildLiveStat(
                          Icons.directions_walk,
                          "${_distanceTraveled.toStringAsFixed(1)} km",
                          "Distance",
                        ),
                        _buildLiveStat(
                          Icons.speed,
                          "${_averageSpeed.toStringAsFixed(1)} km/h",
                          "Speed",
                        ),
                        _buildLiveStat(
                          Icons.fireplace,
                          "$_caloriesBurned",
                          "Calories",
                        ),
                        _buildLiveStat(
                          Icons.eco,
                          "${_co2Saved.toStringAsFixed(2)} kg",
                          "CO₂ Saved",
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Action Buttons
          if (!_isJourneyComplete)
            Container(
              padding: const EdgeInsets.all(16),
              color: Colors.grey[900],
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  ElevatedButton.icon(
                    onPressed: _togglePause,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _isPaused ? Colors.green : Colors.orange,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 12,
                      ),
                    ),
                    icon: Icon(_isPaused ? Icons.play_arrow : Icons.pause),
                    label: Text(_isPaused ? "Resume" : "Pause"),
                  ),
                  ElevatedButton.icon(
                    onPressed: () => _completeJourney(),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 12,
                      ),
                    ),
                    icon: const Icon(Icons.flag),
                    label: const Text("End Journey"),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildLiveStat(IconData icon, String value, String label) {
    return Column(
      children: [
        Icon(icon, color: Colors.green, size: 20),
        const SizedBox(height: 5),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(label, style: const TextStyle(color: Colors.grey, fontSize: 10)),
      ],
    );
  }

  Widget _getInstructionIcon(String type) {
    switch (type) {
      case 'turn':
      case 'fork':
        return const Icon(Icons.turn_right, color: Colors.green);
      case 'new name':
        return const Icon(Icons.straight, color: Colors.blue);
      case 'depart':
      case 'arrive':
        return const Icon(Icons.flag, color: Colors.red);
      default:
        return const Icon(Icons.navigation, color: Colors.white);
    }
  }
}
