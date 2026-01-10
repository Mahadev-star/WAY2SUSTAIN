import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
// ignore: depend_on_referenced_packages
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:sustainable_travel_app/route/route_result_page.dart';
// Import the map screen
import 'package:sustainable_travel_app/map/map_selection_screen.dart';

class SelectLocationPage extends StatefulWidget {
  const SelectLocationPage({super.key});

  @override
  State<SelectLocationPage> createState() => _SelectLocationPageState();
}

class _SelectLocationPageState extends State<SelectLocationPage> {
  final TextEditingController fromController = TextEditingController();
  final TextEditingController toController = TextEditingController();

  LatLng? fromLatLng;
  LatLng? toLatLng;

  List<Map<String, dynamic>> fromSuggestions = [];
  List<Map<String, dynamic>> toSuggestions = [];

  String selectedTravelMode = "";
  DateTime? selectedDateTime;

  Timer? _debounce;
  bool _isSearchingFrom = false;
  bool _isSearchingTo = false;

  static const Color brandGreen = Color(0xFF43A047);
  static const Color backgroundColor = Color(0xFF151717);
  static const Color darkGreen = Color(0xFF0A3D0A);

  // ---------------- SWAP LOCATIONS ----------------
  void _swapLocations() {
    setState(() {
      // Swap text
      final tempText = fromController.text;
      fromController.text = toController.text;
      toController.text = tempText;

      // Swap coordinates
      final tempLatLng = fromLatLng;
      fromLatLng = toLatLng;
      toLatLng = tempLatLng;

      // Swap suggestions
      final tempSuggestions = fromSuggestions;
      fromSuggestions = toSuggestions;
      toSuggestions = tempSuggestions;
    });

    _showSnackBar("Locations swapped");
  }

  // ---------------- OPEN MAP FOR LOCATION SELECTION ----------------
  void _openMapForLocation(bool isFromField) async {
    final result = await Navigator.push<LatLng?>(
      context,
      MaterialPageRoute(
        builder: (context) => MapSelectionScreen(
          isFromField: isFromField,
          initialLocation: isFromField ? fromLatLng : toLatLng,
        ),
      ),
    );

    if (!mounted) return;

    if (result != null) {
      setState(() {
        if (isFromField) {
          fromLatLng = result;
          // You might want to reverse geocode here to get address name
          fromController.text = _formatCoordinates(result);
        } else {
          toLatLng = result;
          toController.text = _formatCoordinates(result);
        }
      });
      _showSnackBar("Location selected from map");
    }
  }

  String _formatCoordinates(LatLng latLng) {
    return "${latLng.latitude.toStringAsFixed(4)}, ${latLng.longitude.toStringAsFixed(4)}";
  }

  Future<void> _useCurrentLocationForTo() async {
    try {
      LocationPermission permission = await Geolocator.requestPermission();

      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        _showSnackBar("Location permission denied");
        return;
      }

      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      setState(() {
        toLatLng = LatLng(pos.latitude, pos.longitude);
        toController.text = "Current Location";
        toSuggestions.clear();
      });

      _showSnackBar("To location set to current location");
    } catch (e) {
      _showSnackBar("Unable to fetch location");
    }
  }

  // ---------------- IMPROVED AUTOCOMPLETE ----------------
  Future<List<Map<String, dynamic>>> fetchLocations(String query) async {
    if (query.trim().isEmpty) return [];

    debugPrint("🔍 Searching for: $query");

    // First check local suggestions for instant response
    final localResults = _getLocalSuggestions(query);
    if (localResults.isNotEmpty) {
      return localResults;
    }

    // Then try API
    try {
      final uri = Uri.https('nominatim.openstreetmap.org', '/search', {
        'q': query,
        'format': 'json',
        'limit': '5',
        'addressdetails': '1',
      });

      final response = await http
          .get(
            uri,
            headers: {
              'User-Agent': 'SustainableTravelApp/1.0',
              'Accept': 'application/json',
            },
          )
          .timeout(const Duration(seconds: 3));

      if (response.statusCode == 200) {
        final List data = json.decode(response.body);
        debugPrint("✅ API found ${data.length} results");

        return data.map((item) {
          return {
            'name': item['display_name'] ?? query,
            'lat': double.tryParse(item['lat'].toString()) ?? 0.0,
            'lon': double.tryParse(item['lon'].toString()) ?? 0.0,
          };
        }).toList();
      } else {
        debugPrint("❌ API error: ${response.statusCode}");
        return _getLocalSuggestions(query); // Fallback to local
      }
    } catch (e) {
      debugPrint("❌ fetchLocations error: $e");
      return _getLocalSuggestions(query); // Fallback to local
    }
  }

  List<Map<String, dynamic>> _getLocalSuggestions(String query) {
    final queryLower = query.toLowerCase();
    final commonPlaces = [
      {'name': 'New York City, USA', 'lat': 40.7128, 'lon': -74.0060},
      {'name': 'London, UK', 'lat': 51.5074, 'lon': -0.1278},
      {'name': 'Tokyo, Japan', 'lat': 35.6762, 'lon': 139.6503},
      {'name': 'Paris, France', 'lat': 48.8566, 'lon': 2.3522},
      {'name': 'Sydney, Australia', 'lat': -33.8688, 'lon': 151.2093},
      {'name': 'Delhi, India', 'lat': 28.6139, 'lon': 77.2090},
      {'name': 'Mumbai, India', 'lat': 19.0760, 'lon': 72.8777},
      {'name': 'Bangalore, India', 'lat': 12.9716, 'lon': 77.5946},
      {'name': 'Chennai, India', 'lat': 13.0827, 'lon': 80.2707},
      {'name': 'Kolkata, India', 'lat': 22.5726, 'lon': 88.3639},
      {'name': 'Dubai, UAE', 'lat': 25.2048, 'lon': 55.2708},
      {'name': 'Singapore', 'lat': 1.3521, 'lon': 103.8198},
    ];

    return commonPlaces.where((place) {
      final name = place['name'].toString().toLowerCase();
      return name.contains(queryLower) ||
          queryLower.split(' ').any((word) => name.contains(word));
    }).toList();
  }

  // ---------------- DEBOUNCED SEARCH ----------------
  void onSearchChanged(String value, bool isFromField) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();

    setState(() {
      if (isFromField) {
        _isSearchingFrom = value.isNotEmpty;
        if (value.isEmpty) fromSuggestions = [];
      } else {
        _isSearchingTo = value.isNotEmpty;
        if (value.isEmpty) toSuggestions = [];
      }
    });

    if (value.isEmpty) return;

    // First, show local suggestions immediately
    final localResults = _getLocalSuggestions(value);
    if (localResults.isNotEmpty) {
      setState(() {
        if (isFromField) {
          fromSuggestions = localResults;
        } else {
          toSuggestions = localResults;
        }
      });
    }

    // Then try API with debounce
    _debounce = Timer(const Duration(milliseconds: 300), () async {
      final results = await fetchLocations(value);

      if (!mounted) return;

      setState(() {
        if (isFromField) {
          fromSuggestions = results;
          _isSearchingFrom = false;
        } else {
          toSuggestions = results;
          _isSearchingTo = false;
        }
      });
    });
  }

  // ---------------- USE CURRENT LOCATION ----------------
  Future<void> _useCurrentLocation() async {
    try {
      LocationPermission permission = await Geolocator.requestPermission();

      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        _showSnackBar("Location permission denied");
        return;
      }

      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      setState(() {
        fromLatLng = LatLng(pos.latitude, pos.longitude);
        fromController.text = "Current Location";
        fromSuggestions.clear();
      });

      _showSnackBar("Location selected");
    } catch (e) {
      _showSnackBar("Unable to fetch location");
    }
  }

  // ---------------- DATE & TIME ----------------
  Future<void> pickDateTime() async {
    DateTime? date = await showDatePicker(
      context: context,
      firstDate: DateTime.now(),
      lastDate: DateTime(2030),
      initialDate: DateTime.now(),
      builder: (context, child) => Theme(
        data: ThemeData.dark().copyWith(
          colorScheme: const ColorScheme.dark(primary: brandGreen),
        ),
        child: child!,
      ),
    );

    if (date == null) return;

    TimeOfDay? time = await showTimePicker(
      // ignore: use_build_context_synchronously
      context: context,
      initialTime: TimeOfDay.now(),
      builder: (context, child) => Theme(
        data: ThemeData.dark().copyWith(
          colorScheme: const ColorScheme.dark(primary: brandGreen),
        ),
        child: child!,
      ),
    );

    if (time == null) return;

    setState(() {
      selectedDateTime = DateTime(
        date.year,
        date.month,
        date.day,
        time.hour,
        time.minute,
      );
    });
  }

  // ---------------- TRAVEL MODE ICON ----------------
  Widget travelModeIcon(String name, String emoji, String description) {
    bool selected = selectedTravelMode == name;
    return GestureDetector(
      onTap: () => setState(() => selectedTravelMode = name),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: selected ? brandGreen : Colors.grey[700],
              boxShadow: selected
                  ? [BoxShadow(color: brandGreen.withAlpha(77), blurRadius: 10)]
                  : null,
            ),
            child: Text(emoji, style: const TextStyle(fontSize: 28)),
          ),
          const SizedBox(height: 8),
          Text(
            name,
            style: TextStyle(
              color: selected ? brandGreen : Colors.grey[400],
              fontWeight: FontWeight.w600,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            description,
            style: TextStyle(
              color: Colors.grey[500] ?? Colors.grey,
              fontSize: 10,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  // ---------------- FIND ROUTE ----------------
  void _findSustainableRoute() {
    if (fromLatLng == null || toLatLng == null) {
      _showSnackBar("Please select valid locations");
      return;
    }

    if (selectedTravelMode.isEmpty) {
      _showSnackBar("Please select a travel mode");
      return;
    }

    int ecoPoints = switch (selectedTravelMode) {
      "Electric Car" => 50,
      "Petrol Car" => 20,
      "Bicycle" => 80,
      "Walking" => 100,
      _ => 0,
    };

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => RouteResultPage(
          from: fromController.text,
          to: toController.text,
          vehicle: selectedTravelMode,
          ecoPoints: ecoPoints,
          fromLocation: fromLatLng!,
          toLocation: toLatLng!,
        ),
      ),
    );
  }

  // ---------------- UI ----------------
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundColor,
      body: Stack(
        children: [
          Positioned.fill(
            child: Container(
              decoration: const BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment.topRight,
                  radius: 1.5,
                  colors: [darkGreen, backgroundColor],
                ),
              ),
            ),
          ),
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.arrow_back, color: Colors.white70),
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    "Plan Your Journey",
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 30),

                  _cardContainer(
                    child: Column(
                      children: [
                        // FROM FIELD
                        Stack(
                          children: [
                            _styledField(
                              controller: fromController,
                              hint: "From (address, city, landmark)",
                              onChanged: (v) => onSearchChanged(v, true),
                              suffixIcon: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    icon: const Icon(
                                      Icons.map_outlined,
                                      color: Colors.white,
                                      size: 20,
                                    ),
                                    onPressed: () => _openMapForLocation(true),
                                    tooltip: "Select from map",
                                  ),
                                  IconButton(
                                    icon: const Icon(
                                      Icons.my_location,
                                      color: Colors.white,
                                      size: 20,
                                    ),
                                    onPressed: _useCurrentLocation,
                                    tooltip: "Use current location",
                                  ),
                                ],
                              ),
                            ),
                            if (_isSearchingFrom)
                              Positioned(
                                right: 8,
                                top: 0,
                                bottom: 0,
                                child: Center(
                                  child: SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: brandGreen,
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                        if (fromSuggestions.isNotEmpty)
                          _buildSuggestionList(fromSuggestions, (place) {
                            setState(() {
                              fromController.text = place['name'];
                              fromLatLng = LatLng(place['lat'], place['lon']);
                              fromSuggestions.clear();
                              _isSearchingFrom = false;
                            });
                          }),

                        const SizedBox(height: 20),

                        // SWAP BUTTON
                        Center(
                          child: Container(
                            width: 50,
                            height: 50,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: brandGreen,
                              boxShadow: [
                                BoxShadow(
                                  color: brandGreen.withAlpha(77),
                                  blurRadius: 10,
                                ),
                              ],
                            ),
                            child: IconButton(
                              icon: const Icon(
                                Icons.swap_vert,
                                color: Colors.white,
                                size: 24,
                              ),
                              onPressed: _swapLocations,
                              tooltip: "Swap locations",
                            ),
                          ),
                        ),

                        const SizedBox(height: 20),

                        // TO FIELD
                        Stack(
                          children: [
                            _styledField(
                              controller: toController,
                              hint: "To (address, city, landmark)",
                              onChanged: (v) => onSearchChanged(v, false),
                              suffixIcon: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    icon: const Icon(
                                      Icons.map_outlined,
                                      color: Colors.white,
                                      size: 20,
                                    ),
                                    onPressed: () => _openMapForLocation(false),
                                    tooltip: "Select from map",
                                  ),
                                  IconButton(
                                    icon: const Icon(
                                      Icons.my_location,
                                      color: Colors.white,
                                      size: 20,
                                    ),
                                    onPressed: _useCurrentLocationForTo,
                                    tooltip: "Use current location",
                                  ),
                                ],
                              ),
                            ),
                            if (_isSearchingTo)
                              Positioned(
                                right: 8,
                                top: 0,
                                bottom: 0,
                                child: Center(
                                  child: SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: brandGreen,
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                        if (toSuggestions.isNotEmpty)
                          _buildSuggestionList(toSuggestions, (place) {
                            setState(() {
                              toController.text = place['name'];
                              toLatLng = LatLng(place['lat'], place['lon']);
                              toSuggestions.clear();
                              _isSearchingTo = false;
                            });
                          }),

                        const SizedBox(height: 30),

                        const Text(
                          "Select Travel Mode",
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 10),
                        const Text(
                          "Choose how you want to travel",
                          style: TextStyle(color: Colors.grey, fontSize: 12),
                        ),
                        const SizedBox(height: 20),

                        Wrap(
                          spacing: 20,
                          runSpacing: 20,
                          alignment: WrapAlignment.spaceEvenly,
                          children: [
                            travelModeIcon("Electric Car", "🚗", "Most Eco"),
                            travelModeIcon("Petrol Car", "⛽", "Less Eco"),
                            travelModeIcon("Bicycle", "🚲", "Very Eco"),
                            travelModeIcon("Walking", "🚶", "Zero Carbon"),
                          ],
                        ),

                        const SizedBox(height: 30),

                        GestureDetector(
                          onTap: pickDateTime,
                          child: _dateTimeBox(),
                        ),

                        const SizedBox(height: 30),

                        SizedBox(
                          width: double.infinity,
                          height: 56,
                          child: ElevatedButton(
                            onPressed: _findSustainableRoute,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: brandGreen,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: const Text(
                              "Find Sustainable Route",
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ---------------- HELPERS ----------------
  Widget _styledField({
    required TextEditingController controller,
    required String hint,
    required Function(String) onChanged,
    Widget? suffixIcon,
  }) {
    return TextField(
      controller: controller,
      onChanged: onChanged,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: Color(0xFF9E9E9E)),
        filled: true,
        fillColor: Colors.grey[900],
        prefixIcon: Icon(Icons.location_on, color: brandGreen),
        suffixIcon: suffixIcon,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: brandGreen, width: 2),
        ),
      ),
    );
  }

  Widget _cardContainer({required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color.fromRGBO(0, 0, 0, 0.3),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color.fromRGBO(255, 255, 255, 0.1)),
      ),
      child: child,
    );
  }

  Widget _dateTimeBox() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[900],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[700] ?? Colors.grey),
      ),
      child: Row(
        children: [
          Icon(Icons.schedule, color: brandGreen),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              selectedDateTime == null
                  ? "Select Date & Time (Optional)"
                  : selectedDateTime!.toLocal().toString().split('.')[0],
              style: const TextStyle(color: Colors.white),
            ),
          ),
          Icon(Icons.arrow_drop_down, color: brandGreen),
        ],
      ),
    );
  }

  Widget _buildSuggestionList(
    List<Map<String, dynamic>> list,
    Function(Map<String, dynamic>) onTap,
  ) {
    return Container(
      margin: const EdgeInsets.only(top: 8),
      decoration: BoxDecoration(
        color: Colors.grey[900],
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey[700] ?? Colors.grey),
        boxShadow: const [
          BoxShadow(
            color: Color.fromRGBO(0, 0, 0, 0.3),
            blurRadius: 10,
            spreadRadius: 2,
          ),
        ],
      ),
      constraints: const BoxConstraints(maxHeight: 200),
      child: list.isEmpty
          ? const Padding(
              padding: EdgeInsets.all(16),
              child: Center(
                child: Text(
                  "No results found",
                  style: TextStyle(color: Colors.grey),
                ),
              ),
            )
          : ListView.builder(
              shrinkWrap: true,
              physics: const BouncingScrollPhysics(),
              padding: EdgeInsets.zero,
              itemCount: list.length,
              itemBuilder: (_, i) => ListTile(
                leading: Icon(Icons.location_on, color: brandGreen, size: 20),
                title: Text(
                  list[i]['name'],
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                onTap: () => onTap(list[i]),
              ),
            ),
    );
  }

  void _showSnackBar(String msg) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: brandGreen,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}
