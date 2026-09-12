import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/station.dart';
import '../models/station_slot.dart';
import '../services/auth_service.dart';
import '../services/station_service.dart';
import '../services/supabase_service.dart';
import '../services/swap_service.dart';
import 'qr_screen.dart';

class StationDetailsScreen extends StatefulWidget {
  const StationDetailsScreen({super.key, required this.station});

  final Station station;

  @override
  State<StationDetailsScreen> createState() => _StationDetailsScreenState();
}

class _StationDetailsScreenState extends State<StationDetailsScreen> {
  final _stationService = StationService();
  final _client = SupabaseService.client;
  late final SwapService _swapService;
  List<StationSlot>? _slots;
  bool _requesting = false;
  RealtimeChannel? _slotsChannel;

  @override
  void initState() {
    super.initState();
    _swapService = SwapService(
      authService: AuthService(),
      stationService: _stationService,
    );
    _fetchSlots();
    _setupRealtimeListener();
  }

  void _setupRealtimeListener() {
    // Subscribe to slot changes for this specific station
    _slotsChannel = _client
        .channel('station-slots-${widget.station.stationId}')
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'slots',
          callback: (payload) {
            // Check if this is a slot for our station
            if (payload.newRecord['station_id'].toString() ==
                widget.station.stationId) {
              debugPrint('Slots changed for station, refreshing...');
              if (mounted) {
                _fetchSlots();
              }
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

  Future<void> _fetchSlots() async {
    try {
      final fetchedSlots = await _stationService.getSlots(
        widget.station.stationId,
      );
      debugPrint(
        'StationDetails fetched ${fetchedSlots.length} slots for ${widget.station.stationId}',
      );
      if (!mounted) return;
      setState(() {
        _slots = fetchedSlots;
      });
    } catch (e) {
      debugPrint('StationDetails _fetchSlots error: $e');
      if (!mounted) return;
      setState(() {
        _slots = <StationSlot>[];
      });
    }
  }

  Future<void> _requestBattery() async {
    if (_requesting || !_hasRequestableBattery) return;

    setState(() => _requesting = true);
    try {
      final result = await _swapService.createSwapRequest(
        widget.station.stationId,
      );
      if (!mounted) return;
      await Navigator.push<bool>(
        context,
        MaterialPageRoute(builder: (_) => QrScreen(result: result)),
      );
      await _fetchSlots();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.toString())));
    } finally {
      if (mounted) setState(() => _requesting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isOffline = !widget.station.isActive;
    final hasRequestableBattery = _hasRequestableBattery;
    return Scaffold(
      appBar: AppBar(
        title: Text('Station ${widget.station.stationId}'),
        elevation: 0,
        actions: [
          IconButton(
            onPressed: _fetchSlots,
            icon: const Icon(Icons.refresh, size: 22),
            tooltip: 'Refresh slots',
            iconSize: 22,
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Station Info Card
            Container(
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
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
                              'Station ${widget.station.stationId}',
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
                                color: widget.station.isActive
                                    ? const Color(0xFFE8F5E8)
                                    : const Color(0xFFFFEBEE),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                widget.station.isActive ? 'Active' : 'Offline',
                                style: TextStyle(
                                  color: widget.station.isActive
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
                  if (isOffline) ...[
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFEBEE),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Row(
                        children: [
                          Icon(
                            Icons.warning_amber_rounded,
                            color: Color(0xFFF44336),
                            size: 20,
                          ),
                          SizedBox(width: 8),
                          Text(
                            'Station is currently unavailable',
                            style: TextStyle(
                              color: Color(0xFFF44336),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),

            // Slots Section
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  const Icon(
                    Icons.battery_charging_full,
                    color: Color(0xFF1565C0),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Available Slots',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // Slots List
            Expanded(
              child: _slots == null
                  ? const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          CircularProgressIndicator(),
                          SizedBox(height: 16),
                          Text(
                            'Loading slots...',
                            style: TextStyle(color: Colors.grey),
                          ),
                        ],
                      ),
                    )
                  : _slots!.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.power_off,
                            size: 64,
                            color: Colors.grey.shade400,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'No slots available',
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: _fetchSlots,
                      child: ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: _slots!.length,
                        itemBuilder: (context, index) {
                          final slot = _slots![index];
                          return Card(
                            margin: const EdgeInsets.only(bottom: 8),
                            elevation: 2,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: slot.unavailable
                                          ? const Color(0xFFF1F1F1)
                                          : slot.batteryPresent
                                          ? const Color(0xFFE8F5E8)
                                          : const Color(0xFFF5F5F5),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Icon(
                                      slot.batteryPresent && !slot.unavailable
                                          ? Icons.battery_full
                                          : Icons.battery_alert,
                                      color: slot.unavailable
                                          ? Colors.grey
                                          : slot.batteryPresent
                                          ? const Color(0xFF4CAF50)
                                          : Colors.grey,
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Slot ${slot.slotId}',
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w600,
                                            fontSize: 16,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          slot.unavailable
                                              ? 'Currently assigned to another user'
                                              : slot.batteryPresent
                                              ? '${slot.chargePercentage}% charged'
                                              : 'No battery',
                                          style: TextStyle(
                                            color: slot.unavailable
                                                ? Colors.grey.shade600
                                                : slot.batteryPresent
                                                ? const Color(0xFF4CAF50)
                                                : Colors.grey.shade600,
                                            fontSize: 14,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  if (slot.batteryPresent)
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        color: slot.unavailable
                                            ? const Color(0xFFF1F1F1)
                                            : slot.chargePercentage > 50
                                            ? const Color(0xFFE8F5E8)
                                            : const Color(0xFFFFF3E0),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Text(
                                        slot.unavailable
                                            ? 'Unavailable'
                                            : '${slot.chargePercentage}%',
                                        style: TextStyle(
                                          color: slot.unavailable
                                              ? Colors.grey
                                              : slot.chargePercentage > 50
                                              ? const Color(0xFF4CAF50)
                                              : const Color(0xFFFF9800),
                                          fontWeight: FontWeight.w600,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
            ),

            // Request Battery Button
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border(top: BorderSide(color: Colors.grey.shade200)),
              ),
              child: SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: isOffline || _requesting || !hasRequestableBattery
                      ? null
                      : _requestBattery,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isOffline || !hasRequestableBattery
                        ? Colors.grey
                        : const Color(0xFFFC8019),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(
                    _requesting
                        ? 'Requesting Battery...'
                        : !hasRequestableBattery
                        ? 'No Battery Available'
                        : 'Request Battery Swap',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  bool get _hasRequestableBattery => (_slots ?? const <StationSlot>[]).any(
    (slot) => slot.batteryPresent && !slot.unavailable,
  );
}
