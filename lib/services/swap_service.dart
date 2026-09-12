import '../models/station_slot.dart';
import '../models/swap_request.dart';
import 'package:flutter/foundation.dart';
import 'auth_service.dart';
import 'station_service.dart';
import 'supabase_service.dart';

class SwapResult {
  const SwapResult({
    required this.requestId,
    required this.stationId,
    required this.slotId,
    required this.chargePercentage,
  });

  final String requestId;
  final String stationId;
  final String slotId;
  final int chargePercentage;
}

class SwapService {
  SwapService({
    required AuthService authService,
    required StationService stationService,
  }) : _authService = authService,
       _stationService = stationService;

  final _client = SupabaseService.client;
  final AuthService _authService;
  final StationService _stationService;

  Future<SwapResult> createSwapRequest(String stationId) async {
    try {
      final user = _authService.currentAuthUser;
      if (user == null) throw Exception('Please login first.');

      final station = await _client
          .from('stations')
          .select()
          .eq('station_id', stationId)
          .maybeSingle();
      if (station == null ||
          (station['status'] as String? ?? 'offline') != 'active') {
        throw Exception('Station unavailable.');
      }

      final slots = await _stationService.getSlots(stationId);
      final available =
          slots
              .where((slot) => slot.batteryPresent && !slot.unavailable)
              .toList()
            ..sort((a, b) => b.chargePercentage.compareTo(a.chargePercentage));

      if (available.isEmpty) {
        throw Exception('No battery available in this station.');
      }

      final StationSlot bestSlot = available.first;
      final swapRequest = await _client
          .from('swap_requests')
          .insert({
            'user_id': user.id,
            'station_id': stationId,
            'slot_id': int.parse(bestSlot.slotId),
            'status': 'pending',
          })
          .select('id')
          .single();

      return SwapResult(
        requestId: swapRequest['id'].toString(),
        stationId: stationId,
        slotId: bestSlot.slotId,
        chargePercentage: bestSlot.chargePercentage,
      );
    } catch (e, st) {
      debugPrint('SwapService.createSwapRequest error: $e\n$st');
      rethrow;
    }
  }

  Future<List<SwapRequest>> getMySwaps() async {
    try {
      final user = _authService.currentAuthUser;
      if (user == null) return [];
      final userId = user.id;

      final response = await _client
          .from('swap_requests')
          .select()
          .eq('user_id', userId)
          .order('created_at', ascending: false);
      return (response as List<dynamic>)
          .map((row) => SwapRequest.fromMap(row as Map<String, dynamic>))
          .toList();
    } catch (e, st) {
      debugPrint('SwapService.getMySwaps error: $e\n$st');
      return [];
    }
  }

  Future<void> markSwapSuccessful({
    required String requestId,
    required String stationId,
    required String slotId,
  }) async {
    try {
      final user = _authService.currentAuthUser;
      if (user == null) throw Exception('Please login first.');

      debugPrint('=== SWAP SUCCESS START ===');
      debugPrint('Request ID: $requestId');
      debugPrint('Station: $stationId, Slot: $slotId');

      final swapRequest = await _client
          .from('swap_requests')
          .select('id, status')
          .eq('id', requestId)
          .eq('user_id', user.id)
          .maybeSingle();
      if (swapRequest == null) {
        throw Exception('Swap request not found.');
      }

      final status = swapRequest['status'] as String? ?? 'pending';
      if (status == 'success') {
        debugPrint('Swap already marked as success');
        return;
      }
      if (status == 'failed') {
        throw Exception('This swap request has already failed.');
      }

      debugPrint('Updating user battery assignment...');
      // Update user with assigned battery
      await _authService.updateCurrentBattery(
        slotId: int.parse(slotId),
        stationId: stationId,
      );

      debugPrint('Marking slot as taken...');
      // Mark slot as taken (battery removed from slot)
      await _client
          .from('slots')
          .update({'battery_present': false})
          .eq('station_id', stationId)
          .eq('slot_id', int.parse(slotId));

      debugPrint('Marking swap request as success...');
      // Mark swap request as success
      await _client
          .from('swap_requests')
          .update({'status': 'success'})
          .eq('id', requestId)
          .eq('user_id', user.id);

      debugPrint('=== SWAP SUCCESS COMPLETE ===');
    } catch (e, st) {
      debugPrint('=== SWAP SUCCESS ERROR ===');
      debugPrint('SwapService.markSwapSuccessful error: $e\n$st');
      rethrow;
    }
  }

  Future<void> markSwapFailed(String requestId) async {
    try {
      final user = _authService.currentAuthUser;
      if (user == null) return;

      await _client
          .from('swap_requests')
          .update({'status': 'failed'})
          .eq('id', requestId)
          .eq('user_id', user.id)
          .eq('status', 'pending');
    } catch (e, st) {
      debugPrint('SwapService.markSwapFailed error: $e\n$st');
    }
  }
}
