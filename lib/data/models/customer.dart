class Customer {
  final String id;
  final String name;
  final String? phone;
  final String? email;
  final String? taxNumber;
  final double creditLimit;
  final double currentBalance;
  final int loyaltyPoints;

  const Customer({
    required this.id,
    required this.name,
    this.phone,
    this.email,
    this.taxNumber,
    this.creditLimit = 0.0,
    this.currentBalance = 0.0,
    this.loyaltyPoints = 0,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'phone': phone,
      'email': email,
      'tax_number': taxNumber,
      'credit_limit': creditLimit,
      'current_balance': currentBalance,
      'loyalty_points': loyaltyPoints,
      'created_at': DateTime.now().millisecondsSinceEpoch ~/ 1000,
    };
  }

  factory Customer.fromMap(Map<String, dynamic> map) {
    return Customer(
      id: map['id'] as String,
      name: map['name'] as String,
      phone: map['phone'] as String?,
      email: map['email'] as String?,
      taxNumber: map['tax_number'] as String?,
      creditLimit: (map['credit_limit'] as num? ?? 0.0).toDouble(),
      currentBalance: (map['current_balance'] as num? ?? 0.0).toDouble(),
      loyaltyPoints: map['loyalty_points'] as int? ?? 0,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Customer && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;
}
