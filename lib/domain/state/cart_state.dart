import 'package:uuid/uuid.dart';
import '../../data/models/customer.dart';
import '../../data/models/product.dart';
import '../services/tax_calculator.dart';

class CartLineItem {
  final String id;
  final Product product;
  final double quantity;
  final double freeQuantity;
  final double unitPrice;
  final double mrp;
  final String uom;
  final String? batchNumber;
  final String? expiryDate;
  final double discountAmount;
  final LineTaxResult taxResult;

  CartLineItem({
    String? id,
    required this.product,
    required this.quantity,
    this.freeQuantity = 0.0,
    required this.unitPrice,
    double? mrp,
    String? uom,
    this.batchNumber,
    this.expiryDate,
    this.discountAmount = 0.0,
    required this.taxResult,
  })  : id = id ?? const Uuid().v4(),
        mrp = mrp ?? (product.mrp ?? unitPrice),
        uom = uom ?? product.unitOfMeasure;

  CartLineItem copyWith({
    double? quantity,
    double? freeQuantity,
    double? unitPrice,
    double? mrp,
    String? uom,
    String? batchNumber,
    String? expiryDate,
    double? discountAmount,
  }) {
    final newQty = quantity ?? this.quantity;
    final newPrice = unitPrice ?? this.unitPrice;
    final newDisc = discountAmount ?? this.discountAmount;

    final newTaxResult = TaxCalculator.computeLine(
      product: product,
      quantity: newQty,
      unitPrice: newPrice,
      discountAmount: newDisc,
    );

    return CartLineItem(
      id: id,
      product: product,
      quantity: newQty,
      freeQuantity: freeQuantity ?? this.freeQuantity,
      unitPrice: newPrice,
      mrp: mrp ?? this.mrp,
      uom: uom ?? this.uom,
      batchNumber: batchNumber ?? this.batchNumber,
      expiryDate: expiryDate ?? this.expiryDate,
      discountAmount: newDisc,
      taxResult: newTaxResult,
    );
  }
}

class DraftInvoice {
  final String id;
  final String tokenNumber;
  final DateTime createdAt;
  final Customer? customer;
  final List<CartLineItem> items;
  final double invoiceDiscount;
  final double otherCharges;
  final double cashTendered;
  final String paymentMethod;
  final String invoiceType;
  final String? notes;
  final double grandTotal;

  const DraftInvoice({
    required this.id,
    required this.tokenNumber,
    required this.createdAt,
    this.customer,
    required this.items,
    this.invoiceDiscount = 0.0,
    this.otherCharges = 0.0,
    this.cashTendered = 0.0,
    this.paymentMethod = 'CASH',
    this.invoiceType = 'Local',
    this.notes,
    required this.grandTotal,
  });

  int get itemCount => items.length;
  double get totalUnits => items.fold(0.0, (sum, item) => sum + item.quantity);
}

class CartState {
  final List<CartLineItem> items;
  final int selectedRowIndex;
  final double invoiceDiscount;
  final double otherCharges;
  final double cashTendered;
  final Customer customer;
  final String paymentMethod;
  final String invoiceType;
  final String? notes;
  final String selectedPrintFormat;
  final List<DraftInvoice> heldCarts;

  const CartState({
    this.items = const [],
    this.selectedRowIndex = 0,
    this.invoiceDiscount = 0.0,
    this.otherCharges = 0.0,
    this.cashTendered = 0.0,
    required this.customer,
    this.paymentMethod = 'CASH',
    this.invoiceType = 'Local',
    this.notes,
    this.selectedPrintFormat = '3_INCH',
    this.heldCarts = const [],
  });

  int get totalItemCount => items.length;

  double get totalUnits => items.fold(0.0, (sum, item) => sum + item.quantity);
  double get totalFreeQty => items.fold(0.0, (sum, item) => sum + item.freeQuantity);
  double get totalMrp => items.fold(0.0, (sum, item) => sum + (item.quantity * item.mrp));
  double get totalSellingPrice => items.fold(0.0, (sum, item) => sum + (item.quantity * item.unitPrice));

  Map<String, dynamic> get totals {
    final lineResults = items.map((i) => i.taxResult).toList();
    return TaxCalculator.computeInvoiceTotals(
      lineResults: lineResults,
      invoiceDiscount: invoiceDiscount,
      otherCharges: otherCharges,
    );
  }

  double get subtotal => totals['subtotal'] as double? ?? 0.0;
  double get taxTotal => totals['tax_total'] as double? ?? 0.0;
  double get roundOff => totals['round_off'] as double? ?? 0.0;
  double get grandTotal => totals['grand_total'] as double? ?? 0.0;

  double get refundAmount {
    if (cashTendered <= 0 || grandTotal <= 0) return 0.0;
    final diff = cashTendered - grandTotal;
    return diff > 0 ? double.parse(diff.toStringAsFixed(2)) : 0.0;
  }

  double get itemDiscountsTotal =>
      items.fold(0.0, (sum, i) => sum + i.discountAmount);

  CartState copyWith({
    List<CartLineItem>? items,
    int? selectedRowIndex,
    double? invoiceDiscount,
    double? otherCharges,
    double? cashTendered,
    Customer? customer,
    String? paymentMethod,
    String? invoiceType,
    String? notes,
    String? selectedPrintFormat,
    List<DraftInvoice>? heldCarts,
  }) {
    return CartState(
      items: items ?? this.items,
      selectedRowIndex: selectedRowIndex ?? this.selectedRowIndex,
      invoiceDiscount: invoiceDiscount ?? this.invoiceDiscount,
      otherCharges: otherCharges ?? this.otherCharges,
      cashTendered: cashTendered ?? this.cashTendered,
      customer: customer ?? this.customer,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      invoiceType: invoiceType ?? this.invoiceType,
      notes: notes ?? this.notes,
      selectedPrintFormat: selectedPrintFormat ?? this.selectedPrintFormat,
      heldCarts: heldCarts ?? this.heldCarts,
    );
  }
}
