class InvoiceItem {
  final String id;
  final String invoiceId;
  final String productId;
  final String productName;
  final String? barcode;
  final double quantity;
  final double freeQuantity;
  final double unitPrice;
  final double mrp;
  final String uom;
  final String? batchNumber;
  final String? expiryDate;
  final double discountAmount;
  final double taxableAmount;
  final double taxRate;
  final double taxAmount;
  final double totalLineAmount;

  const InvoiceItem({
    required this.id,
    required this.invoiceId,
    required this.productId,
    required this.productName,
    this.barcode,
    required this.quantity,
    this.freeQuantity = 0.0,
    required this.unitPrice,
    this.mrp = 0.0,
    this.uom = 'PCS',
    this.batchNumber,
    this.expiryDate,
    this.discountAmount = 0.0,
    required this.taxableAmount,
    required this.taxRate,
    required this.taxAmount,
    required this.totalLineAmount,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'invoice_id': invoiceId,
      'product_id': productId,
      'quantity': quantity,
      'free_quantity': freeQuantity,
      'unit_price': unitPrice,
      'mrp': mrp,
      'uom': uom,
      'batch_number': batchNumber,
      'expiry_date': expiryDate,
      'discount_amount': discountAmount,
      'taxable_amount': taxableAmount,
      'tax_rate': taxRate,
      'tax_amount': taxAmount,
      'total_line_amount': totalLineAmount,
    };
  }

  factory InvoiceItem.fromMap(Map<String, dynamic> map, {String productName = '', String? barcode}) {
    return InvoiceItem(
      id: map['id'] as String,
      invoiceId: map['invoice_id'] as String,
      productId: map['product_id'] as String,
      productName: productName,
      barcode: barcode,
      quantity: (map['quantity'] as num).toDouble(),
      freeQuantity: (map['free_quantity'] as num? ?? 0.0).toDouble(),
      unitPrice: (map['unit_price'] as num).toDouble(),
      mrp: (map['mrp'] as num? ?? (map['unit_price'] as num)).toDouble(),
      uom: map['uom'] as String? ?? 'PCS',
      batchNumber: map['batch_number'] as String?,
      expiryDate: map['expiry_date'] as String?,
      discountAmount: (map['discount_amount'] as num? ?? 0.0).toDouble(),
      taxableAmount: (map['taxable_amount'] as num).toDouble(),
      taxRate: (map['tax_rate'] as num).toDouble(),
      taxAmount: (map['tax_amount'] as num).toDouble(),
      totalLineAmount: (map['total_line_amount'] as num).toDouble(),
    );
  }
}

class Invoice {
  final String id;
  final String companyId;
  final String? templateId;
  final String invoiceNumber;
  final String counterId;
  final String cashierName;
  final String? customerId;
  final String customerName;
  final String? customerPhone;
  final double subtotal;
  final double itemDiscountTotal;
  final double invoiceDiscountTotal;
  final double otherCharges;
  final double taxTotal;
  final double roundOff;
  final double grandTotal;
  final double cashTendered;
  final double changeAmount;
  final String paymentStatus;
  final String paymentMethod;
  final String invoiceType;
  final String? notes;
  final int createdAt;
  final List<InvoiceItem> items;

  const Invoice({
    required this.id,
    required this.companyId,
    this.templateId,
    required this.invoiceNumber,
    required this.counterId,
    required this.cashierName,
    this.customerId,
    this.customerName = 'Walk-in Customer',
    this.customerPhone,
    required this.subtotal,
    this.itemDiscountTotal = 0.0,
    this.invoiceDiscountTotal = 0.0,
    this.otherCharges = 0.0,
    required this.taxTotal,
    this.roundOff = 0.0,
    required this.grandTotal,
    this.cashTendered = 0.0,
    this.changeAmount = 0.0,
    this.paymentStatus = 'PAID',
    this.paymentMethod = 'CASH',
    this.invoiceType = 'Local',
    this.notes,
    required this.createdAt,
    this.items = const [],
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'company_id': companyId,
      'template_id': templateId,
      'invoice_number': invoiceNumber,
      'counter_id': counterId,
      'cashier_name': cashierName,
      'customer_id': customerId,
      'subtotal': subtotal,
      'item_discount_total': itemDiscountTotal,
      'invoice_discount_total': invoiceDiscountTotal,
      'other_charges': otherCharges,
      'tax_total': taxTotal,
      'round_off': roundOff,
      'grand_total': grandTotal,
      'cash_tendered': cashTendered,
      'change_amount': changeAmount,
      'payment_status': paymentStatus,
      'payment_method': paymentMethod,
      'invoice_type': invoiceType,
      'notes': notes,
      'created_at': createdAt,
    };
  }

  factory Invoice.fromMap(Map<String, dynamic> map, {List<InvoiceItem> items = const [], String customerName = 'Walk-in Customer', String? customerPhone}) {
    return Invoice(
      id: map['id'] as String,
      companyId: map['company_id'] as String,
      templateId: map['template_id'] as String?,
      invoiceNumber: map['invoice_number'] as String,
      counterId: map['counter_id'] as String? ?? 'POS-1',
      cashierName: map['cashier_name'] as String? ?? 'Cashier',
      customerId: map['customer_id'] as String?,
      customerName: customerName,
      customerPhone: customerPhone,
      subtotal: (map['subtotal'] as num).toDouble(),
      itemDiscountTotal: (map['item_discount_total'] as num? ?? 0.0).toDouble(),
      invoiceDiscountTotal: (map['invoice_discount_total'] as num? ?? 0.0).toDouble(),
      otherCharges: (map['other_charges'] as num? ?? 0.0).toDouble(),
      taxTotal: (map['tax_total'] as num).toDouble(),
      roundOff: (map['round_off'] as num? ?? 0.0).toDouble(),
      grandTotal: (map['grand_total'] as num).toDouble(),
      cashTendered: (map['cash_tendered'] as num? ?? 0.0).toDouble(),
      changeAmount: (map['change_amount'] as num? ?? 0.0).toDouble(),
      paymentStatus: map['payment_status'] as String? ?? 'PAID',
      paymentMethod: map['payment_method'] as String? ?? 'CASH',
      invoiceType: map['invoice_type'] as String? ?? 'Local',
      notes: map['notes'] as String?,
      createdAt: map['created_at'] as int,
      items: items,
    );
  }
}
