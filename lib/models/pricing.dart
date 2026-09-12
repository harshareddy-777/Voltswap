class Pricing {
  const Pricing({required this.id, required this.swapPrice});

  final int id;
  final double swapPrice;

  factory Pricing.fromMap(Map<String, dynamic> map) {
    return Pricing(
      id: map['id'] as int,
      swapPrice: (map['swap_price'] as num).toDouble(),
    );
  }

  Map<String, dynamic> toMap() {
    return {'id': id, 'swap_price': swapPrice};
  }
}
