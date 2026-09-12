import 'package:flutter/material.dart';

import '../models/station.dart';
import '../services/admin_session_service.dart';
import '../services/station_service.dart';
import 'add_station_screen.dart';
import 'advanced_options_screen.dart';
import 'auth_gate_screen.dart';
import 'manage_station_screen.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});
  static const routeName = '/admin-dashboard';

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  final _adminSessionService = AdminSessionService();
  final _stationService = StationService();
  bool _isRefreshing = false;

  Future<void> _refreshStations() async {
    setState(() => _isRefreshing = true);
    try {
      await _stationService.getStations();
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Stations refreshed')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to refresh stations: $e')));
    } finally {
      if (mounted) setState(() => _isRefreshing = false);
    }
  }

  Future<void> _logoutAdmin() async {
    await _adminSessionService.setAdminLoggedIn(false);
    if (!mounted) return;
    Navigator.pushNamedAndRemoveUntil(
      context,
      AuthGateScreen.routeName,
      (_) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final stationService = StationService();
    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin Dashboard'),
        actions: [
          IconButton(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const AdvancedOptionsScreen()),
            ),
            icon: const Icon(Icons.settings_outlined),
            tooltip: 'Advanced Options',
          ),
          IconButton(
            onPressed: _isRefreshing ? null : _refreshStations,
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh stations',
          ),
          IconButton(
            onPressed: _logoutAdmin,
            icon: const Icon(Icons.logout),
            tooltip: 'Logout',
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const AddStationScreen()),
        ),
        icon: const Icon(Icons.add_business_outlined),
        label: const Text('Add Station'),
      ),
      body: RefreshIndicator(
        onRefresh: _refreshStations,
        child: StreamBuilder<List<Station>>(
          stream: stationService.watchStations(),
          builder: (context, snapshot) {
            final stations = snapshot.data ?? [];
            if (stations.isEmpty) {
              return ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: const [
                  SizedBox(height: 120),
                  Center(child: Text('No stations created yet')),
                ],
              );
            }
            return ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: stations.length,
              itemBuilder: (context, index) {
                final station = stations[index];
                return Card(
                  child: ListTile(
                    title: Text('Station ${station.stationId}'),
                    subtitle: Text('Status: ${station.status}'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ManageStationScreen(station: station),
                      ),
                    ),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}
