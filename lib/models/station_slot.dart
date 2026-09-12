class StationSlot {
  const StationSlot({
    required this.slotId,
    required this.stationId,
    required this.chargePercentage,
    required this.batteryPresent,
    required this.unavailable,
    this.batteryType,
  });

  final String slotId;
  final String stationId;
  final int chargePercentage;
  final bool batteryPresent;
  final bool unavailable;
  final String? batteryType;

  factory StationSlot.fromMap(Map<String, dynamic> map) {
    // Handle slot_id as either int or String
    final slotIdValue = map['slot_id'];
    final slotId = slotIdValue is int
        ? slotIdValue.toString()
        : slotIdValue as String;

    // Handle station_id as either int or String
    final stationIdValue = map['station_id'];
    final stationId = stationIdValue is int
        ? stationIdValue.toString()
        : stationIdValue as String;

    return StationSlot(
      slotId: slotId,
      stationId: stationId,
      chargePercentage: map['charge_percentage'] as int? ?? 0,
      batteryPresent: map['battery_present'] as bool? ?? false,
      unavailable: map['unavailable'] as bool? ?? false,
      batteryType: map['battery_type'] as String?,
    );
  }

  StationSlot copyWith({
    String? slotId,
    String? stationId,
    int? chargePercentage,
    bool? batteryPresent,
    bool? unavailable,
    String? batteryType,
  }) {
    return StationSlot(
      slotId: slotId ?? this.slotId,
      stationId: stationId ?? this.stationId,
      chargePercentage: chargePercentage ?? this.chargePercentage,
      batteryPresent: batteryPresent ?? this.batteryPresent,
      unavailable: unavailable ?? this.unavailable,
      batteryType: batteryType ?? this.batteryType,
    );
  }
}
