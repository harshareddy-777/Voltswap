import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../services/station_service.dart';

class AddStationScreen extends StatefulWidget {
  const AddStationScreen({super.key});

  @override
  State<AddStationScreen> createState() => _AddStationScreenState();
}

class _AddStationScreenState extends State<AddStationScreen> {
  final _stationService = StationService();
  final _stationIdController = TextEditingController();
  final _latController = TextEditingController();
  final _lngController = TextEditingController();
  LatLng? _selectedLocation;

  @override
  void dispose() {
    _stationIdController.dispose();
    _latController.dispose();
    _lngController.dispose();
    super.dispose();
  }

  Future<void> _saveStation() async {
    final stationId = _stationIdController.text.trim();
    final lat = double.tryParse(_latController.text.trim());
    final lng = double.tryParse(_lngController.text.trim());
    if (stationId.isEmpty || lat == null || lng == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter station id and valid lat/lng')),
      );
      return;
    }
    try {
      await _stationService.addStation(
        stationId: stationId,
        latitude: lat,
        longitude: lng,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Station added')));
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  @override
  Widget build(BuildContext context) {
    const defaultPos = LatLng(17.3850, 78.4867);
    final markerPoint = _selectedLocation;
    return Scaffold(
      appBar: AppBar(title: const Text('Add Station')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            controller: _stationIdController,
            decoration: const InputDecoration(labelText: 'station_id'),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _latController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'latitude'),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _lngController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'longitude'),
          ),
          const SizedBox(height: 12),
          const Text('Pick location from map (optional)'),
          const SizedBox(height: 8),
          SizedBox(
            height: 280,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: FlutterMap(
                options: MapOptions(
                  initialCenter: defaultPos,
                  initialZoom: 11,
                  onTap: (tapPosition, point) {
                    setState(() {
                      _selectedLocation = point;
                      _latController.text = point.latitude.toStringAsFixed(6);
                      _lngController.text = point.longitude.toStringAsFixed(6);
                    });
                  },
                ),
                children: [
                  TileLayer(
                    urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                    userAgentPackageName: 'com.voltswap.app',
                  ),
                  if (markerPoint != null)
                    MarkerLayer(
                      markers: [
                        Marker(
                          point: markerPoint,
                          width: 44,
                          height: 44,
                          child: const Icon(
                            Icons.location_on,
                            color: Color(0xFF1565C0),
                            size: 40,
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
          ElevatedButton(
            onPressed: _saveStation,
            child: const Text('Save Station'),
          ),
        ],
      ),
    );
  }
}
