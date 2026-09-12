class Transaction {
  const Transaction({
    required this.id,
    required this.userId,
    required this.amount,
    required this.type,
    required this.status,
    required this.createdAt,
  });

  final String id;
  final String userId;
  final double amount;
  final String type; // 'credit' or 'debit'
  final String status; // 'success' or 'failed'
  final DateTime createdAt;

  factory Transaction.fromMap(Map<String, dynamic> map) {
    return Transaction(
      id: map['id'] as String,
      userId: map['user_id'] as String,
      amount: (map['amount'] as num).toDouble(),
      type: map['type'] as String? ?? 'debit',
      status: map['status'] as String? ?? 'success',
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'user_id': userId,
      'amount': amount,
      'type': type,
      'status': status,
    };
  }
}
