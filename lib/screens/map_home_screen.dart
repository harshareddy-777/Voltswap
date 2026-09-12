import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/station.dart';
import '../services/station_service.dart';
import '../services/supabase_service.dart';
import 'station_details_screen.dart';

class MapHomeScreen extends StatefulWidget {
  const MapHomeScreen({super.key});

  @override
  State<MapHomeScreen> createState() => _MapHomeScreenState();
}

class _MapHomeScreenState extends State<MapHomeScreen> {
  final _stationService = StationService();
  final _client = SupabaseService.client;
  static const LatLng _fallback = LatLng(17.3850, 78.4867);
  final MapController _mapController = MapController();

  LatLng? _currentCenter;
  bool _checkingLocation = true;
  bool _isRefreshing = false;
  RealtimeChannel? _slotsChannel;

  Future<void> _refreshMap() async {
    setState(() => _isRefreshing = true);
    try {
      await _stationService.getStations();
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Refreshed stations')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to refresh stations: $e')));
    } finally {
      if (mounted) setState(() => _isRefreshing = false);
    }
  }

  String? _locationBanner;

  @override
  void initState() {
    super.initState();
    _loadUserLocation();
    _setupRealtimeListener();
  }

  void _setupRealtimeListener() {
    // Subscribe to changes in slots table (battery allocations)
    _slotsChannel = _client
        .channel('map-updates')
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'slots',
          callback: (payload) {
            debugPrint('Slot update detected, refreshing map...');
            if (mounted) {
              _refreshMap();
            }
          },
        )
        .subscribe();
  }

  @override
  void dispose() {
    _slotsChannel?.unsubscribe();
    super.dispose();
  }

  Future<void> _loadUserLocation() async {
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (!mounted) return;
        setState(() {
          _currentCenter = _fallback;
          _checkingLocation = false;
          _locationBanner = 'Location services are off. Showing default map.';
        });
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.deniedForever) {
        if (!mounted) return;
        setState(() {
          _currentCenter = _fallback;
          _checkingLocation = false;
          _locationBanner =
              'Location permission permanently denied. Enable it in Settings.';
        });
        return;
      }

      if (permission == LocationPermission.denied) {
        if (!mounted) return;
        setState(() {
          _currentCenter = _fallback;
          _checkingLocation = false;
          _locationBanner = 'Location permission denied. Showing default map.';
        });
        return;
      }

      final current = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );
      if (!mounted) return;
      setState(() {
        _currentCenter = LatLng(current.latitude, current.longitude);
        _checkingLocation = false;
      });

      // Move map after first build paints.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final target = _currentCenter ?? _fallback;
        _mapController.move(target, 13);
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _currentCenter = _fallback;
        _checkingLocation = false;
        _locationBanner = 'Unable to get location. Showing default map.';
      });
    }
  }

  Future<void> _navigateToStation(Station station) async {
    final currentLocation = _currentCenter;
    if (currentLocation == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Current location not available')),
      );
      return;
    }

    final origin = '${currentLocation.latitude},${currentLocation.longitude}';
    final destination = '${station.latitude},${station.longitude}';
    final url =
        'https://www.google.com/maps/dir/?api=1&origin=$origin&destination=$destination&travelmode=driving';

    try {
      final uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open maps application')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Error opening navigation')));
    }
  }

  void _openStationCard(Station station) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE3F2FD),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.ev_station,
                      color: Color(0xFF1565C0),
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Station ${station.stationId}',
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: station.isActive
                                ? const Color(0xFFE8F5E8)
                                : const Color(0xFFFFEBEE),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            station.isActive ? 'Active' : 'Offline',
                            style: TextStyle(
                              color: station.isActive
                                  ? const Color(0xFF4CAF50)
                                  : const Color(0xFFF44336),
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => _navigateToStation(station),
                      icon: const Icon(Icons.navigation_outlined),
                      label: const Text('Navigate'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFFC8019),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        Navigator.pop(context);
                        Navigator.push(
                          this.context,
                          MaterialPageRoute(
                            builder: (_) =>
                                StationDetailsScreen(station: station),
                          ),
                        );
                      },
                      icon: const Icon(Icons.info_outline),
                      label: const Text('View Details'),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Color(0xFF1565C0)),
                        foregroundColor: const Color(0xFF1565C0),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Station>>(
      stream: _stationService.watchStations(),
      builder: (context, snapshot) {
        final stations = snapshot.data ?? [];
        final center = _currentCenter ?? _fallback;

        final markers = [
          // User location marker
          if (_currentCenter != null)
            Marker(
              point: _currentCenter!,
              width: 52,
              height: 52,
              child: GestureDetector(
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.blue,
                    borderRadius: BorderRadius.circular(26),
                    border: Border.all(color: Colors.white, width: 2),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x33000000),
                        blurRadius: 8,
                        offset: Offset(0, 2),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.my_location,
                    color: Colors.white,
                    size: 24,
                  ),
                ),
              ),
            ),
          // Station markers
          ...stations.map(
            (station) => Marker(
              point: LatLng(station.latitude, station.longitude),
              width: 52,
              height: 52,
              child: GestureDetector(
                onTap: () => _openStationCard(station),
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(26),
                    border: Border.all(color: Colors.orange.shade400, width: 2),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x22000000),
                        blurRadius: 6,
                        offset: Offset(0, 2),
                      ),
                    ],
                  ),
                  child: const Icon(Icons.ev_station, color: Color(0xFFFC8019)),
                ),
              ),
            ),
          ),
        ];

        return Scaffold(
          appBar: AppBar(
            title: const Text('Station Map'),
            actions: [
              IconButton(
                onPressed: _isRefreshing ? null : _refreshMap,
                icon: const Icon(Icons.refresh),
                tooltip: 'Refresh stations',
              ),
            ],
          ),
          body: Column(
            children: [
              Expanded(
                child: Stack(
                  children: [
                    if (_checkingLocation && _currentCenter == null)
                      const Center(child: CircularProgressIndicator())
                    else
                      FlutterMap(
                        mapController: _mapController,
                        options: MapOptions(
                          initialCenter: center,
                          initialZoom: 13,
                        ),
                        children: [
                          TileLayer(
                            urlTemplate:
                                'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                            userAgentPackageName: 'com.voltswap.app',
                          ),
                          MarkerLayer(markers: markers),
                        ],
                      ),
                    if (_locationBanner != null)
                      Positioned(
                        top: 12,
                        left: 16,
                        right: 16,
                        child: Card(
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Text(
                              _locationBanner ?? '',
                              style: TextStyle(
                                color: Colors.blue.shade800,
                                fontWeight: FontWeight.w600,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ),
                      ),
                    if (stations.isEmpty)
                      const Positioned(
                        top: 80,
                        left: 16,
                        right: 16,
                        child: Card(
                          child: Padding(
                            padding: EdgeInsets.all(14),
                            child: Text(
                              'No stations available',
                              style: TextStyle(
                                color: Colors.blue,
                                fontWeight: FontWeight.w600,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
