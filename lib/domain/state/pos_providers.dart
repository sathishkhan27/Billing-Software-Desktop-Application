import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../data/models/company_profile.dart';
import '../../data/models/customer.dart';
import '../../data/models/invoice.dart';
import '../../data/models/invoice_template.dart';
import '../../data/models/product.dart';
import '../../data/models/purchase.dart';
import '../../data/repositories/company_repository.dart';
import '../../data/repositories/customer_repository.dart';
import '../../data/repositories/dashboard_repository.dart';
import '../../data/repositories/invoice_repository.dart';
import '../../data/repositories/product_repository.dart';
import '../../data/repositories/purchase_repository.dart';
import '../../data/repositories/template_repository.dart';
import '../services/tax_calculator.dart';
import 'cart_state.dart';

// Repositories
final companyRepositoryProvider = Provider((ref) => CompanyRepository());
final templateRepositoryProvider = Provider((ref) => TemplateRepository());
final productRepositoryProvider = Provider((ref) => ProductRepository());
final invoiceRepositoryProvider = Provider((ref) => InvoiceRepository());
final customerRepositoryProvider = Provider((ref) => CustomerRepository());
final purchaseRepositoryProvider = Provider((ref) => PurchaseRepository());
final dashboardRepositoryProvider = Provider((ref) => DashboardRepository());

// Default Walk-in Customer
final defaultCustomer = Customer(
  id: 'cust_walkin',
  name: 'Walk-in Customer',
  phone: null,
  loyaltyPoints: 0,
);

// Async Providers
final companyProfileProvider = FutureProvider<CompanyProfile>((ref) async {
  final repo = ref.watch(companyRepositoryProvider);
  final profile = await repo.getDefaultCompany();
  if (profile == null) {
    throw Exception('No company profile found in database');
  }
  return profile;
});

final currencySymbolProvider = Provider<String>((ref) {
  final company = ref.watch(companyProfileProvider).value;
  return company?.currencySymbol ?? '₹';
});

final activeTemplateProvider = FutureProvider<InvoiceTemplate>((ref) async {
  final company = await ref.watch(companyProfileProvider.future);
  final repo = ref.watch(templateRepositoryProvider);
  final tmpl = await repo.getDefaultTemplate(company.id);
  if (tmpl == null) {
    throw Exception('No invoice template found');
  }
  return tmpl;
});

final productsProvider = FutureProvider<List<Product>>((ref) async {
  final repo = ref.watch(productRepositoryProvider);
  return await repo.getAllProducts();
});

final customersProvider = FutureProvider<List<Customer>>((ref) async {
  final repo = ref.watch(customerRepositoryProvider);
  return await repo.getAllCustomers();
});

final purchasesProvider = FutureProvider<List<Purchase>>((ref) async {
  final repo = ref.watch(purchaseRepositoryProvider);
  return await repo.getAllPurchases();
});

final dashboardMetricsProvider = FutureProvider<DashboardMetrics>((ref) async {
  final repo = ref.watch(dashboardRepositoryProvider);
  return await repo.getMetrics();
});

final taxSlabsProvider = FutureProvider<List<TaxSlab>>((ref) async {
  final repo = ref.watch(productRepositoryProvider);
  return await repo.getAllTaxSlabs();
});

final categoriesProvider = FutureProvider<List<Map<String, String>>>((ref) async {
  final repo = ref.watch(productRepositoryProvider);
  return await repo.getAllCategories();
});

// Cart Notifier
class CartNotifier extends StateNotifier<CartState> {
  final Ref ref;

  CartNotifier(this.ref) : super(CartState(customer: defaultCustomer));

  void addOrIncrementProduct(Product product) {
    final existingIndex = state.items.indexWhere((item) => item.product.id == product.id);

    if (existingIndex >= 0) {
      final existing = state.items[existingIndex];
      final updated = existing.copyWith(quantity: existing.quantity + 1.0);
      final newItems = List<CartLineItem>.from(state.items);
      newItems[existingIndex] = updated;
      state = state.copyWith(items: newItems, selectedRowIndex: existingIndex);
    } else {
      final taxResult = TaxCalculator.computeLine(
        product: product,
        quantity: 1.0,
        unitPrice: product.sellingPrice,
        discountAmount: 0.0,
      );

      final newItem = CartLineItem(
        product: product,
        quantity: 1.0,
        unitPrice: product.sellingPrice,
        discountAmount: 0.0,
        taxResult: taxResult,
      );

      final newItems = [...state.items, newItem];
      state = state.copyWith(items: newItems, selectedRowIndex: newItems.length - 1);
    }
  }

  void addItemDetailed({
    required Product product,
    required double quantity,
    double freeQuantity = 0.0,
    required double unitPrice,
    double? mrp,
    String? uom,
    double discountAmount = 0.0,
    String? batchNumber,
    String? expiryDate,
  }) {
    final taxResult = TaxCalculator.computeLine(
      product: product,
      quantity: quantity,
      unitPrice: unitPrice,
      discountAmount: discountAmount,
    );

    final newItem = CartLineItem(
      product: product,
      quantity: quantity,
      freeQuantity: freeQuantity,
      unitPrice: unitPrice,
      mrp: mrp ?? (product.mrp ?? unitPrice),
      uom: uom ?? product.unitOfMeasure,
      batchNumber: batchNumber,
      expiryDate: expiryDate,
      discountAmount: discountAmount,
      taxResult: taxResult,
    );

    final newItems = [...state.items, newItem];
    state = state.copyWith(items: newItems, selectedRowIndex: newItems.length - 1);
  }

  void incrementSelected() {
    if (state.items.isEmpty) return;
    final idx = state.selectedRowIndex.clamp(0, state.items.length - 1);
    final item = state.items[idx];
    final updated = item.copyWith(quantity: item.quantity + 1.0);
    final newItems = List<CartLineItem>.from(state.items);
    newItems[idx] = updated;
    state = state.copyWith(items: newItems);
  }

  void decrementSelected() {
    if (state.items.isEmpty) return;
    final idx = state.selectedRowIndex.clamp(0, state.items.length - 1);
    final item = state.items[idx];
    if (item.quantity > 1.0) {
      final updated = item.copyWith(quantity: item.quantity - 1.0);
      final newItems = List<CartLineItem>.from(state.items);
      newItems[idx] = updated;
      state = state.copyWith(items: newItems);
    } else {
      removeSelected();
    }
  }

  void removeSelected() {
    if (state.items.isEmpty) return;
    final idx = state.selectedRowIndex.clamp(0, state.items.length - 1);
    final newItems = List<CartLineItem>.from(state.items)..removeAt(idx);
    final newIdx = (idx - 1).clamp(0, newItems.isEmpty ? 0 : newItems.length - 1);
    state = state.copyWith(items: newItems, selectedRowIndex: newIdx);
  }

  void setSelectedRow(int index) {
    if (index >= 0 && index < state.items.length) {
      state = state.copyWith(selectedRowIndex: index);
    }
  }

  void updateItemQuantity(int index, double newQty) {
    if (index < 0 || index >= state.items.length) return;
    if (newQty <= 0) {
      removeItemAt(index);
      return;
    }
    final item = state.items[index];
    final updated = item.copyWith(quantity: newQty);
    final newItems = List<CartLineItem>.from(state.items);
    newItems[index] = updated;
    state = state.copyWith(items: newItems);
  }

  void updateItemPrice(int index, double newPrice) {
    if (index < 0 || index >= state.items.length) return;
    if (newPrice < 0) return;
    final item = state.items[index];
    final updated = item.copyWith(unitPrice: newPrice);
    final newItems = List<CartLineItem>.from(state.items);
    newItems[index] = updated;
    state = state.copyWith(items: newItems);
  }

  void removeItemAt(int index) {
    if (index < 0 || index >= state.items.length) return;
    final newItems = List<CartLineItem>.from(state.items)..removeAt(index);
    final newIdx = (index - 1).clamp(0, newItems.isEmpty ? 0 : newItems.length - 1);
    state = state.copyWith(items: newItems, selectedRowIndex: newIdx);
  }

  void setInvoiceDiscount(double discount) {
    state = state.copyWith(invoiceDiscount: discount);
  }

  void setOtherCharges(double charges) {
    state = state.copyWith(otherCharges: charges);
  }

  void setCashTendered(double tendered) {
    state = state.copyWith(cashTendered: tendered);
  }

  void setInvoiceType(String type) {
    state = state.copyWith(invoiceType: type);
  }

  void setNotes(String? notes) {
    state = state.copyWith(notes: notes);
  }

  void setPrintFormat(String format) {
    state = state.copyWith(selectedPrintFormat: format);
  }

  void setCustomer(Customer customer) {
    state = state.copyWith(customer: customer);
  }

  void setPaymentMethod(String method) {
    state = state.copyWith(paymentMethod: method);
  }

  String? holdCurrentBill({String? note}) {
    if (state.items.isEmpty) return null;

    final token = 'Draft #${state.heldCarts.length + 1}';
    final draft = DraftInvoice(
      id: const Uuid().v4(),
      tokenNumber: token,
      createdAt: DateTime.now(),
      customer: state.customer,
      items: List.from(state.items),
      invoiceDiscount: state.invoiceDiscount,
      otherCharges: state.otherCharges,
      cashTendered: state.cashTendered,
      paymentMethod: state.paymentMethod,
      invoiceType: state.invoiceType,
      notes: note ?? state.notes,
      grandTotal: state.grandTotal,
    );

    final newHeld = [...state.heldCarts, draft];
    state = CartState(
      customer: defaultCustomer,
      heldCarts: newHeld,
    );
    return token;
  }

  void recallHeldBill([String? draftId]) {
    if (state.heldCarts.isEmpty) return;

    final targetIndex = draftId != null
        ? state.heldCarts.indexWhere((d) => d.id == draftId)
        : state.heldCarts.length - 1;

    if (targetIndex < 0 || targetIndex >= state.heldCarts.length) return;

    final recalled = state.heldCarts[targetIndex];
    final remaining = List<DraftInvoice>.from(state.heldCarts)..removeAt(targetIndex);

    state = state.copyWith(
      items: List.from(recalled.items),
      selectedRowIndex: recalled.items.isNotEmpty ? recalled.items.length - 1 : 0,
      customer: recalled.customer,
      invoiceDiscount: recalled.invoiceDiscount,
      otherCharges: recalled.otherCharges,
      cashTendered: recalled.cashTendered,
      paymentMethod: recalled.paymentMethod,
      invoiceType: recalled.invoiceType,
      notes: recalled.notes,
      heldCarts: remaining,
    );
  }

  void discardDraftBill(String draftId) {
    final remaining = state.heldCarts.where((d) => d.id != draftId).toList();
    state = state.copyWith(heldCarts: remaining);
  }

  void clearAllDrafts() {
    state = state.copyWith(heldCarts: const []);
  }

  void clearCart() {
    state = CartState(
      customer: defaultCustomer,
      heldCarts: state.heldCarts,
    );
  }

  Future<Invoice> finalizeAndSaveBill({
    required CompanyProfile company,
    required InvoiceTemplate template,
    String cashierName = 'Cashier',
    String counterId = 'Counter 1',
  }) async {
    if (state.items.isEmpty) {
      throw Exception('Cannot finalize an empty cart');
    }

    final companyRepo = ref.read(companyRepositoryProvider);
    final invoiceRepo = ref.read(invoiceRepositoryProvider);

    final nextSeq = await companyRepo.getAndIncrementNextInvoiceSeq(company.id);
    final invNumber = '${company.invoicePrefix}$nextSeq';
    final invId = const Uuid().v4();
    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;

    final invoiceItems = state.items.map((cartItem) {
      return InvoiceItem(
        id: const Uuid().v4(),
        invoiceId: invId,
        productId: cartItem.product.id,
        productName: cartItem.product.name,
        barcode: cartItem.product.barcode,
        quantity: cartItem.quantity,
        freeQuantity: cartItem.freeQuantity,
        unitPrice: cartItem.unitPrice,
        mrp: cartItem.mrp,
        uom: cartItem.uom,
        batchNumber: cartItem.batchNumber,
        expiryDate: cartItem.expiryDate,
        discountAmount: cartItem.discountAmount,
        taxableAmount: cartItem.taxResult.taxableAmount,
        taxRate: cartItem.product.taxSlab?.ratePercent ?? 0.0,
        taxAmount: cartItem.taxResult.taxAmount,
        totalLineAmount: cartItem.taxResult.totalLineAmount,
      );
    }).toList();

    final invoice = Invoice(
      id: invId,
      companyId: company.id,
      templateId: template.id,
      invoiceNumber: invNumber,
      counterId: counterId,
      cashierName: cashierName,
      customerId: state.customer.id,
      customerName: state.customer.name,
      customerPhone: state.customer.phone,
      subtotal: state.subtotal,
      itemDiscountTotal: state.itemDiscountsTotal,
      invoiceDiscountTotal: state.invoiceDiscount,
      otherCharges: state.otherCharges,
      taxTotal: state.taxTotal,
      roundOff: state.roundOff,
      grandTotal: state.grandTotal,
      cashTendered: state.cashTendered,
      changeAmount: state.refundAmount,
      paymentStatus: 'PAID',
      paymentMethod: state.paymentMethod,
      invoiceType: state.invoiceType,
      notes: state.notes,
      createdAt: now,
      items: invoiceItems,
    );

    await invoiceRepo.saveInvoice(invoice);

    // Refresh products list in background to reflect updated inventory
    ref.invalidate(productsProvider);

    // Reset current active cart
    clearCart();

    return invoice;
  }
}

final cartNotifierProvider =
    StateNotifierProvider<CartNotifier, CartState>((ref) {
  return CartNotifier(ref);
});
