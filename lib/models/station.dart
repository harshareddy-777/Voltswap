class Station {
  const Station({
    required this.stationId,
    required this.latitude,
    required this.longitude,
    required this.status,
  });

  final String stationId;
  final double latitude;
  final double longitude;
  final String status;

  bool get isActive => status.toLowerCase() == 'active';

  factory Station.fromMap(Map<String, dynamic> map) {
    return Station(
      stationId: map['station_id'] as String,
      latitude: (map['latitude'] as num).toDouble(),
      longitude: (map['longitude'] as num).toDouble(),
      status: map['status'] as String? ?? 'offline',
    );
  }
}
