import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../../services/api_service.dart';
import '../../services/location_service.dart';
import '../../config/theme.dart';

class TrackingScreen extends StatefulWidget {
  const TrackingScreen({super.key});

  @override
  State<TrackingScreen> createState() => _TrackingScreenState();
}

class _TrackingScreenState extends State<TrackingScreen> with SingleTickerProviderStateMixin {
  late TabController _tabs;
  GoogleMapController? _mapController;
  Set<Marker> _markers = {};
  List<Map<String, dynamic>> _officers = [];
  bool _loading = true;
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
    _loadLiveLocations();
    _refreshTimer = Timer.periodic(const Duration(seconds: 30), (_) => _loadLiveLocations());
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _tabs.dispose();
    super.dispose();
  }

  Future<void> _loadLiveLocations() async {
    try {
      final data = await ApiService.getLiveLocations();
      final locations = List<Map<String, dynamic>>.from(data['locations'] ?? []);
      setState(() {
        _officers = locations;
        _markers = locations.map((o) => Marker(
          markerId: MarkerId(o['user_id']),
          position: LatLng(double.parse(o['latitude'].toString()), double.parse(o['longitude'].toString())),
          infoWindow: InfoWindow(
            title: o['full_name'],
            snippet: 'Updated: ${_timeAgo(o['recorded_at'])}',
          ),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
        )).toSet();
        _loading = false;
      });
    } catch (_) {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Team Tracking'),
        bottom: TabBar(
          controller: _tabs,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          indicatorColor: Colors.white,
          tabs: const [
            Tab(icon: Icon(Icons.map), text: 'Live Map'),
            Tab(icon: Icon(Icons.list), text: 'Officer List'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabs,
        children: [
          // ── MAP TAB ──
          _loading
              ? const Center(child: CircularProgressIndicator())
              : Stack(
                  children: [
                    GoogleMap(
                      initialCameraPosition: const CameraPosition(
                        target: LatLng(20.5937, 78.9629), // India center
                        zoom: 5,
                      ),
                      markers: _markers,
                      onMapCreated: (c) => _mapController = c,
                      myLocationEnabled: true,
                      myLocationButtonEnabled: true,
                    ),
                    Positioned(
                      top: 12, left: 12,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 4)],
                        ),
                        child: Row(children: [
                          const Icon(Icons.circle, color: Colors.green, size: 10),
                          const SizedBox(width: 6),
                          Text('${_officers.length} officers online', style: const TextStyle(fontWeight: FontWeight.w600)),
                        ]),
                      ),
                    ),
                  ],
                ),

          // ── LIST TAB ──
          ListView.builder(
            itemCount: _officers.length,
            itemBuilder: (ctx, i) {
              final o = _officers[i];
              return ListTile(
                leading: CircleAvatar(
                  backgroundColor: AppTheme.primary.withOpacity(0.1),
                  child: Text(
                    (o['full_name'] as String? ?? 'U')[0].toUpperCase(),
                    style: const TextStyle(color: AppTheme.primary, fontWeight: FontWeight.bold),
                  ),
                ),
                title: Text(o['full_name'] ?? ''),
                subtitle: Text('Updated ${_timeAgo(o['recorded_at'])}'),
                trailing: IconButton(
                  icon: const Icon(Icons.location_on, color: AppTheme.primary),
                  onPressed: () {
                    _tabs.animateTo(0);
                    _mapController?.animateCamera(CameraUpdate.newLatLngZoom(
                      LatLng(double.parse(o['latitude'].toString()), double.parse(o['longitude'].toString())),
                      15,
                    ));
                  },
                ),
              );
            },
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _loadLiveLocations,
        icon: const Icon(Icons.refresh),
        label: const Text('Refresh'),
      ),
    );
  }

  String _timeAgo(String? dateStr) {
    if (dateStr == null) return 'unknown';
    final dt = DateTime.tryParse(dateStr);
    if (dt == null) return 'unknown';
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    return '${diff.inHours}h ago';
  }
}
