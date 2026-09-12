class SwapRequest {
  const SwapRequest({
    required this.id,
    required this.userId,
    required this.stationId,
    required this.slotId,
    required this.status,
    required this.createdAt,
  });

  final String id;
  final String userId;
  final String stationId;
  final String slotId;
  final String status;
  final DateTime createdAt;

  factory SwapRequest.fromMap(Map<String, dynamic> map) {
    // Handle slot_id as either int or String
    final slotIdValue = map['slot_id'];
    final slotId = slotIdValue is int
        ? slotIdValue.toString()
        : slotIdValue as String;

    return SwapRequest(
      id: map['id'].toString(),
      userId: map['user_id'] as String? ?? '',
      stationId: map['station_id'] as String? ?? '',
      slotId: slotId,
      status: map['status'] as String? ?? 'pending',
      createdAt:
          DateTime.tryParse(map['created_at'] as String? ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
    );
  }
}
