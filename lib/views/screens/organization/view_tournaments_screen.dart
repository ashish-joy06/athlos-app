import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:intl/intl.dart';
import 'package:latlong2/latlong.dart';

class ViewTournamentsScreen extends StatefulWidget {
  const ViewTournamentsScreen({super.key});

  @override
  State<ViewTournamentsScreen> createState() => _ViewTournamentsScreenState();
}

class _ViewTournamentsScreenState extends State<ViewTournamentsScreen> {
  final MapController _mapController = MapController();
  List<Marker> _markers = [];
  Map<String, dynamic>? _selectedTournament;

  final CollectionReference tournamentsRef =
      FirebaseFirestore.instance.collection('tournaments');

  String? organizationSport;

  @override
  void initState() {
    super.initState();
    fetchOrganizationSport();
  }

  Future<void> fetchOrganizationSport() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final userDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .get();
    final userData = userDoc.data() as Map<String, dynamic>?;

    if (userData == null) {
      debugPrint('User data is null.');
      return;
    }

    final sport = userData['sport'];
    if (sport != null && mounted) {
      setState(() {
        organizationSport = sport;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (organizationSport == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Tournaments Map')),
      body: Stack(
        children: [
          // StreamBuilder drives the markers
          StreamBuilder<QuerySnapshot>(
            stream: tournamentsRef
                .where('sport', isEqualTo: organizationSport)
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.hasData) {
                final docs = snapshot.data!.docs;
                final updatedMarkers = docs.map((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  final location = data['location'] ?? {};
                  final lat = (location['lat'] ?? 0).toDouble();
                  final lng = (location['lng'] ?? 0).toDouble();
                  return Marker(
                    point: LatLng(lat, lng),
                    width: 44,
                    height: 44,
                    child: GestureDetector(
                      onTap: () {
                        _mapController.move(LatLng(lat, lng), 14);
                        setState(() => _selectedTournament = data);
                      },
                      child: const Icon(
                        Icons.location_on,
                        color: Colors.red,
                        size: 40,
                      ),
                    ),
                  );
                }).toList();

                // Update state after the frame to avoid setState during build.
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (!mounted) return;
                  if (_markers.length != updatedMarkers.length) {
                    setState(() => _markers = updatedMarkers);
                  }
                });
              }
              return const SizedBox.shrink();
            },
          ),

          // Map always visible
          FlutterMap(
            mapController: _mapController,
            options: const MapOptions(
              initialCenter: LatLng(20.5937, 78.9629), // India
              initialZoom: 4,
            ),
            children: [
              TileLayer(
                urlTemplate:
                    'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.athlos.app',
              ),
              MarkerLayer(markers: _markers),
              const RichAttributionWidget(
                attributions: [
                  TextSourceAttribution('OpenStreetMap contributors'),
                ],
              ),
            ],
          ),

          // Tournament detail card
          if (_selectedTournament != null)
            Center(
              child: _TournamentDetailCard(
                data: _selectedTournament!,
                onClose: () => setState(() => _selectedTournament = null),
              ),
            ),
        ],
      ),
    );
  }
}

// Tournament detail card widget (unchanged)
class _TournamentDetailCard extends StatelessWidget {
  final Map<String, dynamic> data;
  final VoidCallback onClose;

  const _TournamentDetailCard({
    required this.data,
    required this.onClose,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final location = data['location'];
    return Material(
      color: Colors.transparent,
      child: Center(
        child: Container(
          width: MediaQuery.of(context).size.width * 0.85,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.12),
                blurRadius: 24,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Stack(
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 8, right: 8),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.emoji_events,
                            color: Colors.deepPurple, size: 28),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            data['name'] ?? '',
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: Colors.black87,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        const Icon(Icons.sports,
                            color: Colors.blueAccent, size: 20),
                        const SizedBox(width: 8),
                        Text(
                          data['sport'] ?? '',
                          style: const TextStyle(
                              fontSize: 16, fontWeight: FontWeight.w500),
                        ),
                        const Spacer(),
                        const Icon(Icons.flag,
                            color: Colors.orange, size: 20),
                        const SizedBox(width: 4),
                        Text(
                          data['level'] ?? '',
                          style: const TextStyle(fontSize: 16),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        const Icon(Icons.calendar_today,
                            color: Colors.teal, size: 18),
                        const SizedBox(width: 8),
                        Text(
                          DateFormat('yyyy-MM-dd').format(
                              (data['date'] as Timestamp).toDate()),
                          style: const TextStyle(fontSize: 15),
                        ),
                        const Spacer(),
                        const Icon(Icons.access_time,
                            color: Colors.purple, size: 18),
                        const SizedBox(width: 4),
                        Text(
                          data['time'],
                          style: const TextStyle(fontSize: 15),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.location_on,
                            color: Colors.redAccent, size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            location['address'] ?? '',
                            style: const TextStyle(fontSize: 15),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Positioned(
                top: 0,
                right: 0,
                child: IconButton(
                  icon: const Icon(Icons.close,
                      color: Colors.grey, size: 24),
                  onPressed: onClose,
                  tooltip: "Close",
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}