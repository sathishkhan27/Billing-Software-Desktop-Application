class PurchaseItem {
  final String id;
  final String purchaseId;
  final String productId;
  final String productName;
  final double quantity;
  final double unitCost;
  final double taxRate;
  final double totalAmount;

  const PurchaseItem({
    required this.id,
    required this.purchaseId,
    required this.productId,
    this.productName = '',
    required this.quantity,
    required this.unitCost,
    this.taxRate = 0.0,
    required this.totalAmount,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'purchase_id': purchaseId,
      'product_id': productId,
      'quantity': quantity,
      'unit_cost': unitCost,
      'tax_rate': taxRate,
      'total_amount': totalAmount,
    };
  }

  factory PurchaseItem.fromMap(Map<String, dynamic> map, {String productName = ''}) {
    return PurchaseItem(
      id: map['id'] as String,
      purchaseId: map['purchase_id'] as String,
      productId: map['product_id'] as String,
      productName: productName,
      quantity: (map['quantity'] as num).toDouble(),
      unitCost: (map['unit_cost'] as num).toDouble(),
      taxRate: (map['tax_rate'] as num? ?? 0.0).toDouble(),
      totalAmount: (map['total_amount'] as num).toDouble(),
    );
  }
}

class Purchase {
  final String id;
  final String vendorName;
  final String? billNumber;
  final int purchaseDate;
  final double subtotal;
  final double taxTotal;
  final double grandTotal;
  final String paymentStatus;
  final String? notes;
  final int createdAt;
  final List<PurchaseItem> items;

  const Purchase({
    required this.id,
    required this.vendorName,
    this.billNumber,
    required this.purchaseDate,
    required this.subtotal,
    this.taxTotal = 0.0,
    required this.grandTotal,
    this.paymentStatus = 'PAID',
    this.notes,
    required this.createdAt,
    this.items = const [],
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'vendor_name': vendorName,
      'bill_number': billNumber,
      'purchase_date': purchaseDate,
      'subtotal': subtotal,
      'tax_total': taxTotal,
      'grand_total': grandTotal,
      'payment_status': paymentStatus,
      'notes': notes,
      'created_at': createdAt,
    };
  }

  factory Purchase.fromMap(Map<String, dynamic> map, {List<PurchaseItem> items = const []}) {
    return Purchase(
      id: map['id'] as String,
      vendorName: map['vendor_name'] as String,
      billNumber: map['bill_number'] as String?,
      purchaseDate: map['purchase_date'] as int,
      subtotal: (map['subtotal'] as num).toDouble(),
      taxTotal: (map['tax_total'] as num? ?? 0.0).toDouble(),
      grandTotal: (map['grand_total'] as num).toDouble(),
      paymentStatus: map['payment_status'] as String? ?? 'PAID',
      notes: map['notes'] as String?,
      createdAt: map['created_at'] as int,
      items: items,
    );
  }
}

class Expense {
  final String id;
  final String title;
  final String category;
  final double amount;
  final int expenseDate;
  final String paymentMethod;
  final String? notes;
  final int createdAt;

  const Expense({
    required this.id,
    required this.title,
    this.category = 'General',
    required this.amount,
    required this.expenseDate,
    this.paymentMethod = 'CASH',
    this.notes,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'category': category,
      'amount': amount,
      'expense_date': expenseDate,
      'payment_method': paymentMethod,
      'notes': notes,
      'created_at': createdAt,
    };
  }

  factory Expense.fromMap(Map<String, dynamic> map) {
    return Expense(
      id: map['id'] as String,
      title: map['title'] as String,
      category: map['category'] as String? ?? 'General',
      amount: (map['amount'] as num).toDouble(),
      expenseDate: map['expense_date'] as int,
      paymentMethod: map['payment_method'] as String? ?? 'CASH',
      notes: map['notes'] as String?,
      createdAt: map['created_at'] as int,
    );
  }
}
