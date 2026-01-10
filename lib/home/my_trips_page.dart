import 'package:flutter/material.dart';

class MyTripsPage extends StatelessWidget {
  const MyTripsPage({super.key});

  @override
  Widget build(BuildContext context) {
    const Color brandGreen = Color(0xFF43A047);
    const Color backgroundColor = Color(0xFF151717);

    final List<Trip> trips = [
      Trip(
        date: "Today",
        from: "Home",
        to: "Work",
        distance: "5.2 km",
        co2Saved: "1.2 kg",
        points: 10,
        transportMode: Icons.directions_bike,
        transportColor: Colors.green,
      ),
      Trip(
        date: "Yesterday",
        from: "Office",
        to: "Gym",
        distance: "3.8 km",
        co2Saved: "0.8 kg",
        points: 8,
        transportMode: Icons.directions_walk,
        transportColor: Colors.blue,
      ),
      Trip(
        date: "Dec 10, 2024",
        from: "City Center",
        to: "Airport",
        distance: "25.4 km",
        co2Saved: "4.5 kg",
        points: 45,
        transportMode: Icons.directions_bus,
        transportColor: Colors.orange,
      ),
      Trip(
        date: "Dec 8, 2024",
        from: "Home",
        to: "Supermarket",
        distance: "2.1 km",
        co2Saved: "0.4 kg",
        points: 4,
        transportMode: Icons.directions_walk,
        transportColor: Colors.blue,
      ),
    ];

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
        title: const Text(
          "My Trips",
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.filter_list, color: Colors.white),
            onPressed: () {},
          ),
        ],
      ),
      body: Column(
        children: [
          // Stats Overview
          Container(
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              // ignore: deprecated_member_use
              color: brandGreen.withOpacity(0.1),
              borderRadius: BorderRadius.circular(16),
              // ignore: deprecated_member_use
              border: Border.all(color: brandGreen.withOpacity(0.3)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildTotalStat("Total Trips", "4", Icons.list),
                _buildTotalStat("Total Distance", "36.5 km", Icons.map),
                _buildTotalStat("CO₂ Saved", "6.9 kg", Icons.eco),
              ],
            ),
          ),

          // Trips List
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: trips.length,
              itemBuilder: (context, index) {
                final trip = trips[index];
                return _buildTripCard(trip);
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          // Navigate to new trip planning
        },
        backgroundColor: brandGreen,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  Widget _buildTotalStat(String title, String value, IconData icon) {
    return Column(
      children: [
        Icon(icon, color: Colors.white, size: 24),
        const SizedBox(height: 8),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        Text(title, style: TextStyle(color: Colors.grey[400], fontSize: 12)),
      ],
    );
  }

  Widget _buildTripCard(Trip trip) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        // ignore: deprecated_member_use
        color: Colors.grey[900]!.withOpacity(0.5),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey[800]!),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                trip.date,
                style: TextStyle(color: Colors.grey[400], fontSize: 12),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  // ignore: deprecated_member_use
                  color: const Color(0xFF43A047).withOpacity(0.2),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.eco, color: Colors.orange, size: 12),
                    const SizedBox(width: 4),
                    Text(
                      "${trip.points} pts",
                      style: const TextStyle(
                        color: Colors.orange,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  // ignore: deprecated_member_use
                  color: trip.transportColor.withOpacity(0.2),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  trip.transportMode,
                  color: trip.transportColor,
                  size: 20,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.circle, color: Colors.green, size: 8),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            trip.from,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                            ),
                          ),
                        ),
                      ],
                    ),
                    Padding(
                      padding: const EdgeInsets.only(left: 4),
                      child: Container(
                        height: 20,
                        width: 1,
                        color: Colors.grey[700],
                        margin: const EdgeInsets.symmetric(vertical: 2),
                      ),
                    ),
                    Row(
                      children: [
                        const Icon(Icons.circle, color: Colors.red, size: 8),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            trip.to,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.place, color: Colors.grey, size: 12),
                      const SizedBox(width: 4),
                      Text(
                        trip.distance,
                        style: TextStyle(color: Colors.grey[300], fontSize: 12),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(Icons.co2, color: Colors.green, size: 12),
                      const SizedBox(width: 4),
                      Text(
                        trip.co2Saved,
                        style: TextStyle(
                          color: Colors.green[300],
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                icon: const Icon(Icons.share, color: Colors.grey, size: 20),
                onPressed: () {},
              ),
              IconButton(
                icon: const Icon(Icons.details, color: Colors.grey, size: 20),
                onPressed: () {},
              ),
              IconButton(
                icon: const Icon(
                  Icons.delete_outline,
                  color: Colors.grey,
                  size: 20,
                ),
                onPressed: () {},
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class Trip {
  final String date;
  final String from;
  final String to;
  final String distance;
  final String co2Saved;
  final int points;
  final IconData transportMode;
  final Color transportColor;

  Trip({
    required this.date,
    required this.from,
    required this.to,
    required this.distance,
    required this.co2Saved,
    required this.points,
    required this.transportMode,
    required this.transportColor,
  });
}
