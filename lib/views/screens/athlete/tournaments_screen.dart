import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

class TournamentsScreen extends StatefulWidget {
  const TournamentsScreen({super.key});

  @override
  State<TournamentsScreen> createState() => _TournamentsScreenState();
}

class _TournamentsScreenState extends State<TournamentsScreen> {
  late Future<List<Tournament>> _tournaments;

  @override
  void initState() {
    super.initState();
    _tournaments = _fetchTournaments();
  }

  Future<List<Tournament>> _fetchTournaments() async {
    final uid = FirebaseAuth.instance.currentUser!.uid;

    final userDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .get();

    final userSport = (userDoc.data()?['sport'] ?? '').toString();
    if (userSport.isEmpty) return [];

    final now = Timestamp.now();

    final snapshot = await FirebaseFirestore.instance
        .collection('tournaments')
        .where('sport', isEqualTo: userSport)
        .where('date', isGreaterThanOrEqualTo: now)
        .orderBy('date')
        .get();

    return snapshot.docs.map((doc) => Tournament.fromDocument(doc)).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Tournaments')),
      body: FutureBuilder<List<Tournament>>(
        future: _tournaments,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'Could not load tournaments.\nPlease try again later.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.grey),
                ),
              ),
            );
          }

          final tournaments = snapshot.data ?? [];

          if (tournaments.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'No tournaments found.\nCheck back later.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey),
                ),
              ),
            );
          }

          // Center the map on the first tournament
          final firstLatLng = LatLng(
            tournaments.first.lat,
            tournaments.first.lng,
          );

          return Stack(
            children: [
              FlutterMap(
                options: MapOptions(
                  initialCenter: firstLatLng,
                  initialZoom: 10,
                ),
                children: [
                  TileLayer(
                    urlTemplate:
                        'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                    userAgentPackageName: 'com.athlos.app',
                  ),
                  MarkerLayer(
                    markers: tournaments.map((t) {
                      return Marker(
                        point: LatLng(t.lat, t.lng),
                        width: 40,
                        height: 40,
                        child: GestureDetector(
                          onTap: () => _showTournamentDialog(context, t),
                          child: const Icon(
                            Icons.location_on,
                            color: Colors.red,
                            size: 36,
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const RichAttributionWidget(
                    attributions: [
                      TextSourceAttribution('OpenStreetMap contributors'),
                    ],
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }

  void _showTournamentDialog(BuildContext context, Tournament t) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: Text(
          t.name,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 8),
            _buildInfoRow("Level", t.level),
            const SizedBox(height: 6),
            _buildInfoRow("Sport", t.sport),
            const SizedBox(height: 6),
            _buildInfoRow("Date", t.dateString),
            const SizedBox(height: 6),
            _buildInfoRow("Time", t.time),
            const SizedBox(height: 12),
            const Text(
              "Address:",
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 14,
                color: Colors.black87,
              ),
            ),
            Text(
              t.address,
              style: const TextStyle(
                fontSize: 14,
                color: Colors.black54,
              ),
            ),
          ],
        ),
        actions: [
          Center(
            child: TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text(
                'Close',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Colors.blue,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String title, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "$title: ",
          style: const TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 14,
            color: Colors.black87,
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
              fontSize: 14,
              color: Colors.black54,
            ),
          ),
        ),
      ],
    );
  }
}

class Tournament {
  final String id;
  final String name;
  final String level;
  final String sport;
  final String dateString;
  final String time;
  final String address;
  final double lat;
  final double lng;

  Tournament({
    required this.id,
    required this.name,
    required this.level,
    required this.sport,
    required this.dateString,
    required this.time,
    required this.address,
    required this.lat,
    required this.lng,
  });

  factory Tournament.fromDocument(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;

    final Timestamp? dateTs = data['date'];
    final String dateStr = dateTs != null
        ? dateTs.toDate().toLocal().toString().split(' ')[0]
        : '';

    final loc = data['location'] ?? {};

    return Tournament(
      id: doc.id,
      name: data['name'] ?? '',
      level: data['level'] ?? '',
      sport: data['sport'] ?? '',
      dateString: dateStr,
      time: data['time'] ?? '',
      address: loc['address'] ?? '',
      lat: (loc['lat'] ?? 0).toDouble(),
      lng: (loc['lng'] ?? 0).toDouble(),
    );
  }
}