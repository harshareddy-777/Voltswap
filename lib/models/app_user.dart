class AppUser {
  const AppUser({
    required this.id,
    required this.email,
    required this.name,
    required this.phone,
    required this.vehicleNumber,
    required this.aadharNumber,
    this.batteryType,
    this.currentBatterySlotId,
    this.currentStationId,
    this.assignedBatteryId,
    this.batteryStatus,
    this.walletBalance = 0.0,
  });

  final String id;
  final String email;
  final String name;
  final String phone;
  final String vehicleNumber;
  final String aadharNumber;
  final String? batteryType;
  final int? currentBatterySlotId;
  final String? currentStationId;
  final int? assignedBatteryId;
  final String? batteryStatus;
  final double walletBalance;

  factory AppUser.fromMap(Map<String, dynamic> map) {
    return AppUser(
      id: map['id'] as String,
      email: map['email'] as String? ?? '',
      name: map['name'] as String? ?? '',
      phone: map['phone'] as String? ?? '',
      vehicleNumber: map['vehicle_number'] as String? ?? '',
      aadharNumber: map['aadhar_number'] as String? ?? '',
      batteryType: map['battery_type'] as String?,
      currentBatterySlotId: map['current_battery_slot_id'] as int?,
      currentStationId: map['current_station_id'] as String?,
      assignedBatteryId: map['assigned_battery_id'] as int?,
      batteryStatus: map['battery_status'] as String? ?? 'none',
      walletBalance: (map['wallet_balance'] as num?)?.toDouble() ?? 0.0,
    );
  }
}
