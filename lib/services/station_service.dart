import '../models/station.dart';
import '../models/station_slot.dart';
import 'supabase_service.dart';
import 'package:flutter/foundation.dart';

class StationService {
  final _client = SupabaseService.client;

  Stream<List<Station>> watchStations() {
    try {
      return _client
          .from('stations')
          .stream(primaryKey: ['station_id'])
          .order('station_id')
          .map((rows) => rows.map(Station.fromMap).toList());
    } catch (e, st) {
      debugPrint('StationService.watchStations error: $e\n$st');
      return Stream.value([]);
    }
  }

  Future<List<Station>> getStations() async {
    try {
      final response = await _client
          .from('stations')
          .select()
          .order('station_id');
      return (response as List<dynamic>)
          .map((row) => Station.fromMap(row as Map<String, dynamic>))
          .toList();
    } catch (e, st) {
      debugPrint('StationService.getStations error: $e\n$st');
      return [];
    }
  }

  Future<List<StationSlot>> getSlots(String stationId) async {
    try {
      final normalizedStationId = stationId.trim();
      final response = await _client
          .from('slots')
          .select()
          .eq('station_id', normalizedStationId);
      final slots = (response as List<dynamic>)
          .map((row) => StationSlot.fromMap(row as Map<String, dynamic>))
          .toList();

      final assignedResponse = await _client
          .from('users')
          .select('current_battery_slot_id, current_station_id');
      final assignedKeys = (assignedResponse as List<dynamic>)
          .map((row) => row as Map<String, dynamic>)
          .where(
            (row) =>
                row['current_battery_slot_id'] != null &&
                row['current_station_id']?.toString() == normalizedStationId,
          )
          .map(
            (row) =>
                '${row['current_station_id']}:${row['current_battery_slot_id']}',
          )
          .toSet();

      return slots
          .map(
            (slot) => slot.copyWith(
              unavailable: assignedKeys.contains(
                '${slot.stationId}:${slot.slotId}',
              ),
            ),
          )
          .toList();
    } catch (e, st) {
      debugPrint('StationService.getSlots error: $e\n$st');
      return [];
    }
  }

  Stream<List<StationSlot>> watchSlots(String stationId) {
    try {
      final normalizedStationId = stationId.trim();
      return _client
          .from('slots')
          .stream(primaryKey: ['slot_id'])
          .eq('station_id', normalizedStationId)
          .order('slot_id')
          .map((rows) {
            debugPrint('watchSlots($normalizedStationId) rows: $rows');
            return rows.map(StationSlot.fromMap).toList();
          });
    } catch (e, st) {
      debugPrint('StationService.watchSlots error: $e\n$st');
      return Stream.value([]);
    }
  }

  Future<void> addStation({
    required String stationId,
    required double latitude,
    required double longitude,
  }) async {
    try {
      final normalizedStationId = stationId.trim();
      await _client.from('stations').insert({
        'station_id': normalizedStationId,
        'latitude': latitude,
        'longitude': longitude,
        'status': 'active',
      });
    } catch (e, st) {
      debugPrint('StationService.addStation error: $e\n$st');
      rethrow;
    }
  }

  Future<void> setStationStatus({
    required String stationId,
    required String status,
  }) async {
    try {
      final normalizedStationId = stationId.trim();
      await _client
          .from('stations')
          .update({'status': status})
          .eq('station_id', normalizedStationId);
    } catch (e, st) {
      debugPrint('StationService.setStationStatus error: $e\n$st');
      rethrow;
    }
  }

  Future<void> addSlot({
    required String stationId,
    required String slotId,
    required int chargePercentage,
    required bool batteryPresent,
    String? batteryType,
  }) async {
    try {
      final normalizedStationId = stationId.trim();
      final normalizedSlotId = slotId.trim();
      await _client.from('slots').upsert({
        'slot_id': normalizedSlotId,
        'station_id': normalizedStationId,
        'charge_percentage': chargePercentage,
        'battery_present': batteryPresent,
        'battery_type': batteryType,
      });
    } catch (e, st) {
      debugPrint('StationService.addSlot error: $e\n$st');
      rethrow;
    }
  }

  Future<void> deleteSlot({
    required String stationId,
    required String slotId,
  }) async {
    try {
      await _client
          .from('slots')
          .delete()
          .eq('station_id', stationId.trim())
          .eq('slot_id', slotId.trim());
    } catch (e, st) {
      debugPrint('StationService.deleteSlot error: $e\n$st');
      rethrow;
    }
  }

  Future<void> updateSlot({
    required String stationId,
    required String oldSlotId,
    required String newSlotId,
    required int chargePercentage,
    required bool batteryPresent,
    String? batteryType,
  }) async {
    try {
      final normalizedStationId = stationId.trim();
      final normalizedOldSlotId = oldSlotId.trim();
      final normalizedNewSlotId = newSlotId.trim();

      if (normalizedOldSlotId != normalizedNewSlotId) {
        // If slot ID is changing, we need to handle it carefully
        // First, insert/update the new slot
        await _client.from('slots').upsert({
          'slot_id': normalizedNewSlotId,
          'station_id': normalizedStationId,
          'charge_percentage': chargePercentage,
          'battery_present': batteryPresent,
          'battery_type': batteryType,
        });
        // Then delete the old slot (only if it's different from the new one)
        if (normalizedOldSlotId != normalizedNewSlotId) {
          await _client
              .from('slots')
              .delete()
              .eq('station_id', normalizedStationId)
              .eq('slot_id', normalizedOldSlotId);
        }
      } else {
        // Just update the existing slot
        await _client
            .from('slots')
            .update({
              'charge_percentage': chargePercentage,
              'battery_present': batteryPresent,
              'battery_type': batteryType,
            })
            .eq('station_id', normalizedStationId)
            .eq('slot_id', normalizedOldSlotId);
      }
    } catch (e, st) {
      debugPrint('StationService.updateSlot error: $e\n$st');
      rethrow;
    }
  }
}
