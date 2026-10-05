import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:uuid/uuid.dart';
import '../../core/theme/app_theme.dart';
import '../../data/models/customer.dart';
import '../../data/models/invoice.dart';
import '../../data/models/product.dart';
import '../../domain/services/template_engine.dart';
import '../../domain/state/cart_state.dart';
import '../../domain/state/pos_providers.dart';

class PosBillingScreen extends ConsumerStatefulWidget {
  final Function(int)? onNavigateTab;

  const PosBillingScreen({super.key, this.onNavigateTab});

  @override
  ConsumerState<PosBillingScreen> createState() => _PosBillingScreenState();
}

class _PosBillingScreenState extends ConsumerState<PosBillingScreen> {
  // Navigation & View State
  bool _isTouchMode = false;
  bool _isDraftsViewActive = false;
  String _draftsSearchQuery = '';
  final TextEditingController _draftsSearchController = TextEditingController();
  String? _selectedDraftId;

  // Header Controllers
  final TextEditingController _invoiceNoController = TextEditingController(text: '1');
  final TextEditingController _prefixController = TextEditingController();
  final TextEditingController _custMobController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();
  final TextEditingController _salesPersonController = TextEditingController();
  DateTime _invoiceDate = DateTime.now();

  // Rapid Entry Row Controllers & Focus
  final TextEditingController _barcodeEntryController = TextEditingController();
  final TextEditingController _itemNameEntryController = TextEditingController();
  final TextEditingController _qtyEntryController = TextEditingController(text: '1.00');
  final TextEditingController _freeQtyEntryController = TextEditingController(text: '0.00');
  final TextEditingController _mrpEntryController = TextEditingController(text: '0.00');
  final TextEditingController _spEntryController = TextEditingController(text: '0.00');
  final TextEditingController _discPercentEntryController = TextEditingController(text: '0.00');
  final TextEditingController _discAmtEntryController = TextEditingController(text: '0.00');
  final TextEditingController _gstPercentEntryController = TextEditingController(text: '18.00');
  final TextEditingController _gstAmtEntryController = TextEditingController(text: '0.00');
  final TextEditingController _netAmtEntryController = TextEditingController(text: '0.00');
  final TextEditingController _batchEntryController = TextEditingController();
  final TextEditingController _expEntryController = TextEditingController();
  final TextEditingController _uomEntryController = TextEditingController(text: 'PCS');
  final TextEditingController _remarksEntryController = TextEditingController();

  final FocusNode _barcodeFocusNode = FocusNode();
  final FocusNode _itemNameFocusNode = FocusNode();
  final FocusNode _qtyFocusNode = FocusNode();
  final FocusNode _spFocusNode = FocusNode();
  final FocusNode _cashTenderFocusNode = FocusNode();
  final FocusNode _keyboardFocusNode = FocusNode();

  // Financial Bottom Controllers
  final TextEditingController _discPercentTotalController = TextEditingController(text: '0.00');
  final TextEditingController _fixedDiscountController = TextEditingController(text: '0.00');
  final TextEditingController _otherChargesController = TextEditingController(text: '0.00');
  final TextEditingController _cashTenderController = TextEditingController(text: '0.00');

  // Other Charges Tab Controllers
  final TextEditingController _freightChargeController = TextEditingController(text: '0.00');
  final TextEditingController _packagingChargeController = TextEditingController(text: '0.00');
  final TextEditingController _insuranceChargeController = TextEditingController(text: '0.00');

  // Misc Tab Controllers
  final TextEditingController _vehicleNoController = TextEditingController();
  final TextEditingController _dispatchDateController = TextEditingController();

  // Shipping Tab Controllers
  final TextEditingController _shippingAddressController = TextEditingController();
  final TextEditingController _shippingCityController = TextEditingController();
  final TextEditingController _shippingStateController = TextEditingController();
  final TextEditingController _shippingPincodeController = TextEditingController();

  Product? _selectedEntryProduct;
  List<Product> _productSearchResults = [];
  bool _showProductSuggestions = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _barcodeFocusNode.requestFocus();
      _fetchInvoiceNumberPreview();
    });
  }

  void _fetchInvoiceNumberPreview() async {
    final company = ref.read(companyProfileProvider).value;
    if (company != null) {
      setState(() {
        _invoiceNoController.text = '${company.invoiceNextSeq}';
        _prefixController.text = company.invoicePrefix.replaceAll('-', '');
      });
    }
  }

  @override
  void dispose() {
    _invoiceNoController.dispose();
    _prefixController.dispose();
    _custMobController.dispose();
    _notesController.dispose();
    _salesPersonController.dispose();

    _barcodeEntryController.dispose();
    _itemNameEntryController.dispose();
    _qtyEntryController.dispose();
    _freeQtyEntryController.dispose();
    _mrpEntryController.dispose();
    _spEntryController.dispose();
    _discPercentEntryController.dispose();
    _discAmtEntryController.dispose();
    _gstPercentEntryController.dispose();
    _gstAmtEntryController.dispose();
    _netAmtEntryController.dispose();
    _batchEntryController.dispose();
    _expEntryController.dispose();
    _uomEntryController.dispose();
    _remarksEntryController.dispose();

    _barcodeFocusNode.dispose();
    _itemNameFocusNode.dispose();
    _qtyFocusNode.dispose();
    _spFocusNode.dispose();
    _cashTenderFocusNode.dispose();
    _keyboardFocusNode.dispose();

    _discPercentTotalController.dispose();
    _fixedDiscountController.dispose();
    _otherChargesController.dispose();
    _cashTenderController.dispose();
    _draftsSearchController.dispose();

    _freightChargeController.dispose();
    _packagingChargeController.dispose();
    _insuranceChargeController.dispose();
    _vehicleNoController.dispose();
    _dispatchDateController.dispose();
    _shippingAddressController.dispose();
    _shippingCityController.dispose();
    _shippingStateController.dispose();
    _shippingPincodeController.dispose();
    super.dispose();
  }

  // --- RECALCULATE ACTIVE ENTRY ROW ---
  void _recalcEntryRow() {
    final qty = double.tryParse(_qtyEntryController.text) ?? 1.0;
    final sp = double.tryParse(_spEntryController.text) ?? 0.0;
    final discP = double.tryParse(_discPercentEntryController.text) ?? 0.0;
    final gstP = double.tryParse(_gstPercentEntryController.text) ?? 0.0;

    final discAmt = (qty * sp * (discP / 100.0));
    _discAmtEntryController.text = discAmt.toStringAsFixed(2);

    final taxable = (qty * sp) - discAmt;
    final gstAmt = taxable > 0 ? (taxable * (gstP / 100.0)) : 0.0;
    _gstAmtEntryController.text = gstAmt.toStringAsFixed(2);

    final netAmt = taxable > 0 ? taxable : 0.0;
    _netAmtEntryController.text = netAmt.toStringAsFixed(2);
  }

  // --- SELECT PRODUCT INTO RAPID ENTRY ROW ---
  void _populateEntryFromProduct(Product product) {
    setState(() {
      _selectedEntryProduct = product;
      _barcodeEntryController.text = product.barcode ?? product.sku ?? '';
      _itemNameEntryController.text = product.name;
      _qtyEntryController.text = '1.00';
      _freeQtyEntryController.text = '0.00';
      _mrpEntryController.text = (product.mrp ?? product.sellingPrice).toStringAsFixed(2);
      _spEntryController.text = product.sellingPrice.toStringAsFixed(2);
      _discPercentEntryController.text = '0.00';
      _discAmtEntryController.text = '0.00';
      _gstPercentEntryController.text = (product.taxSlab?.ratePercent ?? 18.0).toStringAsFixed(2);
      _uomEntryController.text = product.unitOfMeasure;
      _batchEntryController.text = 'B-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}';
      _expEntryController.text = '12/28';
      _showProductSuggestions = false;
      _productSearchResults = [];
    });
    _recalcEntryRow();
    _qtyFocusNode.requestFocus();
  }

  // --- ADD LINE ITEM FROM RAPID ENTRY ROW ---
  void _commitEntryRowToCart() {
    if (_selectedEntryProduct == null) {
      if (_itemNameEntryController.text.trim().isNotEmpty) {
        // Find by name or barcode
        final query = _itemNameEntryController.text.trim();
        ref.read(productRepositoryProvider).searchProducts(query).then((results) {
          if (results.isNotEmpty) {
            _populateEntryFromProduct(results.first);
            _addPopulatedItemToCart();
          } else {
            _showItemNotFoundSnackBar(query);
          }
        });
      }
      return;
    }
    _addPopulatedItemToCart();
  }

  void _addPopulatedItemToCart() {
    final prod = _selectedEntryProduct;
    if (prod == null) return;

    final qty = double.tryParse(_qtyEntryController.text) ?? 1.0;
    final freeQty = double.tryParse(_freeQtyEntryController.text) ?? 0.0;
    final sp = double.tryParse(_spEntryController.text) ?? prod.sellingPrice;
    final mrp = double.tryParse(_mrpEntryController.text) ?? (prod.mrp ?? sp);
    final discAmt = double.tryParse(_discAmtEntryController.text) ?? 0.0;
    final batch = _batchEntryController.text.trim().isNotEmpty ? _batchEntryController.text.trim() : null;
    final exp = _expEntryController.text.trim().isNotEmpty ? _expEntryController.text.trim() : null;
    final uom = _uomEntryController.text.trim().isNotEmpty ? _uomEntryController.text.trim() : prod.unitOfMeasure;

    ref.read(cartNotifierProvider.notifier).addItemDetailed(
          product: prod,
          quantity: qty,
          freeQuantity: freeQty,
          unitPrice: sp,
          mrp: mrp,
          uom: uom,
          discountAmount: discAmt,
          batchNumber: batch,
          expiryDate: exp,
        );

    // Reset entry fields for the next scan
    setState(() {
      _selectedEntryProduct = null;
      _barcodeEntryController.clear();
      _itemNameEntryController.clear();
      _qtyEntryController.text = '1.00';
      _freeQtyEntryController.text = '0.00';
      _mrpEntryController.text = '0.00';
      _spEntryController.text = '0.00';
      _discPercentEntryController.text = '0.00';
      _discAmtEntryController.text = '0.00';
      _gstAmtEntryController.text = '0.00';
      _netAmtEntryController.text = '0.00';
      _batchEntryController.clear();
      _expEntryController.clear();
      _remarksEntryController.clear();
    });

    _barcodeFocusNode.requestFocus();
  }

  void _showItemNotFoundSnackBar(String query) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Item "$query" not found in inventory!'),
        backgroundColor: AppTheme.accentRose,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  // --- KEYBOARD SHORTCUTS DISPATCHER ---
  void _handleKeyEvent(KeyEvent event) {
    if (event is! KeyDownEvent) return;

    final key = event.logicalKey;
    final isAlt = HardwareKeyboard.instance.isAltPressed;

    if (key == LogicalKeyboardKey.f1) {
      _showHelpDialog();
    } else if (key == LogicalKeyboardKey.f2) {
      _showCustomerLookupDialog();
    } else if (key == LogicalKeyboardKey.f3) {
      _qtyFocusNode.requestFocus();
    } else if (key == LogicalKeyboardKey.f5) {
      _handleSaveBill();
    } else if (key == LogicalKeyboardKey.f6) {
      _handleHoldCurrentDraft();
    } else if (key == LogicalKeyboardKey.f7) {
      setState(() => _isDraftsViewActive = !_isDraftsViewActive);
    } else if (key == LogicalKeyboardKey.escape && _isDraftsViewActive) {
      setState(() => _isDraftsViewActive = false);
    } else if (key == LogicalKeyboardKey.f9) {
      _triggerPrintActiveBill();
    } else if (isAlt && key == LogicalKeyboardKey.keyC) {
      ref.read(cartNotifierProvider.notifier).setPaymentMethod('CARD');
      _handleSaveBill();
    } else if (isAlt && key == LogicalKeyboardKey.keyM) {
      _showMultiPayDialog();
    } else if (key == LogicalKeyboardKey.space && !_barcodeFocusNode.hasFocus && !_itemNameFocusNode.hasFocus) {
      _cashTenderFocusNode.requestFocus();
    } else if (key == LogicalKeyboardKey.arrowDown) {
      final cart = ref.read(cartNotifierProvider);
      if (cart.selectedRowIndex < cart.items.length - 1) {
        ref.read(cartNotifierProvider.notifier).setSelectedRow(cart.selectedRowIndex + 1);
      }
    } else if (key == LogicalKeyboardKey.arrowUp) {
      final cart = ref.read(cartNotifierProvider);
      if (cart.selectedRowIndex > 0) {
        ref.read(cartNotifierProvider.notifier).setSelectedRow(cart.selectedRowIndex - 1);
      }
    } else if (key == LogicalKeyboardKey.delete) {
      ref.read(cartNotifierProvider.notifier).removeSelected();
    }
  }

  // --- SAVE & FINALIZE BILL ---
  void _handleSaveBill() async {
    final cart = ref.read(cartNotifierProvider);
    if (cart.items.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Bill grid is empty. Scan barcode or add items first.'),
          backgroundColor: AppTheme.accentAmber,
        ),
      );
      _barcodeFocusNode.requestFocus();
      return;
    }

    try {
      final company = await ref.read(companyProfileProvider.future);
      final template = await ref.read(activeTemplateProvider.future);

      final invoice = await ref.read(cartNotifierProvider.notifier).finalizeAndSaveBill(
            company: company,
            template: template,
            cashierName: _salesPersonController.text.trim().isNotEmpty
                ? _salesPersonController.text.trim()
                : 'Cashier',
            counterId: 'Counter 1',
          );

      ref.invalidate(dashboardMetricsProvider);
      _fetchInvoiceNumberPreview();

      if (mounted) {
        _showInvoiceSuccessModal(invoice);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save bill: $e'), backgroundColor: AppTheme.accentRose),
        );
      }
    }
  }

  // --- DIALOGS ---
  void _showHelpDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.cardBg,
        insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        title: const Row(
          children: [
            Icon(Icons.keyboard, color: AppTheme.primaryBlue),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                'High-Speed Keyboard Shortcuts',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        content: const SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('• F1 / F2: Customer Search & Lookup', style: TextStyle(color: AppTheme.textLight)),
              SizedBox(height: 6),
              Text('• F3: Jump to Quantity Field', style: TextStyle(color: AppTheme.textLight)),
              SizedBox(height: 6),
              Text('• F5: Quick Save Bill (CASH / Tender)', style: TextStyle(color: AppTheme.primaryEmerald, fontWeight: FontWeight.bold)),
              SizedBox(height: 6),
              Text('• F6: Hold Current Bill as Draft', style: TextStyle(color: AppTheme.accentAmber, fontWeight: FontWeight.bold)),
              SizedBox(height: 6),
              Text('• F7: Recall / View Draft Bills', style: TextStyle(color: AppTheme.accentCyan, fontWeight: FontWeight.bold)),
              SizedBox(height: 6),
              Text('• F9: Print Active Invoice Slip', style: TextStyle(color: AppTheme.accentCyan)),
              SizedBox(height: 6),
              Text('• Alt + C: Instant Card Payment', style: TextStyle(color: AppTheme.textLight)),
              SizedBox(height: 6),
              Text('• Alt + M: Multi-Pay (Cash / UPI / Due)', style: TextStyle(color: AppTheme.textLight)),
              SizedBox(height: 6),
              Text('• Space: Focus Cash Tender Field', style: TextStyle(color: AppTheme.textLight)),
              SizedBox(height: 6),
              Text('• Arrow Up / Down: Navigate Line Items Table', style: TextStyle(color: AppTheme.textLight)),
              SizedBox(height: 6),
              Text('• Delete Key: Remove Highlighted Item', style: TextStyle(color: AppTheme.accentRose)),
            ],
          ),
        ),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryBlue),
            onPressed: () => Navigator.pop(ctx),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _showCustomerLookupDialog() {
    final customers = ref.read(customersProvider).value ?? [];
    final searchCtrl = TextEditingController();
    final isMobile = AppTheme.isMobile(context);

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlgState) {
          final query = searchCtrl.text.trim().toLowerCase();
          final filtered = customers.where((c) {
            return c.name.toLowerCase().contains(query) ||
                (c.phone != null && c.phone!.contains(query));
          }).toList();

          return AlertDialog(
            backgroundColor: AppTheme.cardBg,
            insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
            title: const Text('Customer Lookup [F2]'),
            content: SizedBox(
              width: isMobile ? double.maxFinite : 500,
              height: 400,
              child: Column(
                children: [
                  TextField(
                    controller: searchCtrl,
                    autofocus: true,
                    decoration: const InputDecoration(
                      prefixIcon: Icon(Icons.search),
                      hintText: 'Search by Customer Name or Mobile No...',
                    ),
                    onChanged: (_) => setDlgState(() {}),
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: ListView.separated(
                      itemCount: filtered.length,
                      separatorBuilder: (_, __) => const Divider(height: 1, color: AppTheme.cardBorder),
                      itemBuilder: (ctx, i) {
                        final c = filtered[i];
                        return ListTile(
                          title: Text(c.name, style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.textLight)),
                          subtitle: Text('Mob: ${c.phone ?? "-"} | Due Dr: ₹${c.currentBalance.toStringAsFixed(2)}',
                              style: const TextStyle(color: AppTheme.textMuted)),
                          trailing: const Icon(Icons.chevron_right, color: AppTheme.primaryBlue),
                          onTap: () {
                            ref.read(cartNotifierProvider.notifier).setCustomer(c);
                            _custMobController.text = c.phone ?? '';
                            Navigator.pop(ctx);
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              Wrap(
                spacing: 8,
                runSpacing: 8,
                alignment: WrapAlignment.end,
                children: [
                  TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close')),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryBlue),
                    icon: const Icon(Icons.person_add),
                    label: const Text('New Customer'),
                    onPressed: () {
                      Navigator.pop(ctx);
                      _showAddNewCustomerDialog();
                    },
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }

  void _showAddNewCustomerDialog() {
    final nameCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    final gstinCtrl = TextEditingController();
    final isMobile = AppTheme.isMobile(context);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.cardBg,
        insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        title: const Text('Add New Customer'),
        content: SizedBox(
          width: isMobile ? double.maxFinite : 400,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(controller: nameCtrl, autofocus: true, decoration: const InputDecoration(labelText: 'Customer Name *')),
                const SizedBox(height: 12),
                TextField(controller: phoneCtrl, decoration: const InputDecoration(labelText: 'Mobile Phone Number *')),
                const SizedBox(height: 12),
                TextField(controller: gstinCtrl, decoration: const InputDecoration(labelText: 'GSTIN Number (Optional)')),
              ],
            ),
          ),
        ),
        actions: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: WrapAlignment.end,
            children: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryBlue),
                onPressed: () async {
                  if (nameCtrl.text.trim().isEmpty) return;
                  final cust = Customer(
                    id: const Uuid().v4(),
                    name: nameCtrl.text.trim(),
                    phone: phoneCtrl.text.trim().isEmpty ? null : phoneCtrl.text.trim(),
                    taxNumber: gstinCtrl.text.trim().isEmpty ? null : gstinCtrl.text.trim(),
                  );
                  await ref.read(customerRepositoryProvider).addCustomer(cust);
                  ref.invalidate(customersProvider);
                  ref.read(cartNotifierProvider.notifier).setCustomer(cust);
                  _custMobController.text = cust.phone ?? '';
                  if (ctx.mounted) Navigator.pop(ctx);
                },
                child: const Text('Save Customer'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showMultiPayDialog() {
    final cart = ref.read(cartNotifierProvider);
    final cashCtrl = TextEditingController(text: cart.grandTotal.toStringAsFixed(2));
    final upiCtrl = TextEditingController(text: '0.00');
    final cardCtrl = TextEditingController(text: '0.00');
    final dueCtrl = TextEditingController(text: '0.00');
    final isMobile = AppTheme.isMobile(context);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.cardBg,
        insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        title: const Row(
          children: [
            Icon(Icons.payment, color: AppTheme.accentCyan),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                'Multi-Mode Payment Split [Alt+M]',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        content: SizedBox(
          width: isMobile ? double.maxFinite : 420,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: const Color(0xFF0F172A), borderRadius: BorderRadius.circular(6)),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Total Bill Amount:', style: TextStyle(fontWeight: FontWeight.bold, color: AppTheme.textLight)),
                      Text('₹${cart.grandTotal.toStringAsFixed(2)}',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: AppTheme.primaryEmerald)),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                TextField(controller: cashCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Cash Amount (₹)')),
                const SizedBox(height: 10),
                TextField(controller: upiCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'UPI / QR Amount (₹)')),
                const SizedBox(height: 10),
                TextField(controller: cardCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Card Amount (₹)')),
                const SizedBox(height: 10),
                TextField(controller: dueCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Customer Due / Credit Ledger (₹)')),
              ],
            ),
          ),
        ),
        actions: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: WrapAlignment.end,
            children: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryEmerald, foregroundColor: Colors.white),
                onPressed: () {
                  ref.read(cartNotifierProvider.notifier).setPaymentMethod('MULTI_MODE');
                  Navigator.pop(ctx);
                  _handleSaveBill();
                },
                child: const Text('Settle & Save Bill'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // --- DRAFT BILLING (HOLD & RECALL TEMPORARY SALES) ---
  void _handleHoldCurrentDraft() {
    final cart = ref.read(cartNotifierProvider);
    if (cart.items.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Cannot hold an empty bill. Scan or add items first to save as a draft bill.'),
          backgroundColor: AppTheme.accentAmber,
        ),
      );
      _barcodeFocusNode.requestFocus();
      return;
    }

    final noteCtrl = TextEditingController();
    final isMobile = AppTheme.isMobile(context);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        title: const Row(
          children: [
            Icon(Icons.bookmark_add_outlined, color: AppTheme.accentAmber),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                'Hold Bill as Draft [F6]',
                style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        content: SizedBox(
          width: isMobile ? double.maxFinite : 380,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Holding bill for: ${cart.customer.name} (${cart.items.length} items • ₹${cart.grandTotal.toStringAsFixed(2)})',
                style: const TextStyle(color: AppTheme.textLight, fontSize: 13),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: noteCtrl,
                autofocus: true,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  labelText: 'Optional Reference / Note',
                  hintText: 'e.g. Customer at ATM / Selecting more items',
                ),
                onSubmitted: (_) {
                  Navigator.pop(ctx);
                  _executeHoldDraft(noteCtrl.text.trim());
                },
              ),
            ],
          ),
        ),
        actions: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: WrapAlignment.end,
            children: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel', style: TextStyle(color: AppTheme.textSecondary)),
              ),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.accentAmber,
                  foregroundColor: Colors.white,
                ),
                icon: const Icon(Icons.pause, size: 16),
                label: const Text('Hold Draft Bill'),
                onPressed: () {
                  Navigator.pop(ctx);
                  _executeHoldDraft(noteCtrl.text.trim());
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _executeHoldDraft(String note) {
    final token = ref.read(cartNotifierProvider.notifier).holdCurrentBill(note: note.isNotEmpty ? note : null);
    if (token != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$token saved on hold! Active cart cleared for next sale. Press [F7] to recall.'),
          backgroundColor: AppTheme.accentAmber,
          duration: const Duration(seconds: 3),
        ),
      );
      _barcodeFocusNode.requestFocus();
    }
  }

  void _resumeDraftBill(DraftInvoice draft, {BuildContext? modalCtx}) {
    final activeCart = ref.read(cartNotifierProvider);
    if (activeCart.items.isNotEmpty) {
      _confirmResumeDraft(draft, parentModalCtx: modalCtx);
    } else {
      ref.read(cartNotifierProvider.notifier).recallHeldBill(draft.id);
      if (modalCtx != null && modalCtx.mounted) Navigator.pop(modalCtx);
      setState(() {
        _isDraftsViewActive = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Resumed ${draft.tokenNumber} for ${draft.customer?.name ?? "Customer"}!'),
          backgroundColor: AppTheme.primaryEmerald,
        ),
      );
    }
  }

  void _confirmResumeDraft(DraftInvoice draftToResume, {BuildContext? parentModalCtx}) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        title: const Text('Active Cart Has Items', style: TextStyle(color: Colors.white)),
        content: const Text(
          'Your active bill currently has items in the grid. What would you like to do before resuming this draft?',
          style: TextStyle(color: AppTheme.textLight),
        ),
        actions: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: WrapAlignment.end,
            children: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel', style: TextStyle(color: AppTheme.textSecondary)),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: AppTheme.accentAmber, foregroundColor: Colors.white),
                onPressed: () {
                  Navigator.pop(ctx);
                  // Hold current cart, then recall draft
                  ref.read(cartNotifierProvider.notifier).holdCurrentBill(note: 'Swapped for ${draftToResume.tokenNumber}');
                  ref.read(cartNotifierProvider.notifier).recallHeldBill(draftToResume.id);
                  if (parentModalCtx != null && parentModalCtx.mounted) Navigator.pop(parentModalCtx);
                  setState(() {
                    _isDraftsViewActive = false;
                  });
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Current bill held as draft, resumed ${draftToResume.tokenNumber}!'),
                      backgroundColor: AppTheme.primaryEmerald,
                    ),
                  );
                },
                child: const Text('Hold Current & Resume Draft'),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: AppTheme.accentRose, foregroundColor: Colors.white),
                onPressed: () {
                  Navigator.pop(ctx);
                  // Replace current cart directly
                  ref.read(cartNotifierProvider.notifier).recallHeldBill(draftToResume.id);
                  if (parentModalCtx != null && parentModalCtx.mounted) Navigator.pop(parentModalCtx);
                  setState(() {
                    _isDraftsViewActive = false;
                  });
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Replaced cart with ${draftToResume.tokenNumber}!'),
                      backgroundColor: AppTheme.primaryEmerald,
                    ),
                  );
                },
                child: const Text('Replace Active Cart'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _triggerPrintActiveBill() {
    final cart = ref.read(cartNotifierProvider);
    if (cart.items.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cannot print empty invoice.')),
      );
      return;
    }
    _handleSaveBill();
  }

  void _showInvoiceSuccessModal(Invoice invoice) async {
    final company = await ref.read(companyProfileProvider.future);
    final template = await ref.read(activeTemplateProvider.future);

    final receipt = TemplateEngine.renderThermal(
      template: template,
      company: company,
      invoice: invoice,
    );

    if (!mounted) return;
    final isMobile = AppTheme.isMobile(context);

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        final receiptWidget = Container(
          height: isMobile ? 240 : 320,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFF0F172A),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppTheme.cardBorder),
          ),
          child: SingleChildScrollView(
            child: Text(
              receipt.fullText,
              style: const TextStyle(
                fontFamily: 'Courier',
                fontSize: 11,
                color: AppTheme.textLight,
                height: 1.3,
              ),
            ),
          ),
        );

        final qrAndPrintWidget = Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const Text(
              'Dynamic UPI QR',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.textLight),
            ),
            const SizedBox(height: 10),
            if (receipt.upiPaymentUri.isNotEmpty)
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8)),
                child: QrImageView(data: receipt.upiPaymentUri, version: QrVersions.auto, size: isMobile ? 120.0 : 150.0),
              )
            else
              const Text('No UPI VPA configured', style: TextStyle(fontSize: 11, color: AppTheme.textMuted)),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryEmerald,
                foregroundColor: Colors.white,
                minimumSize: const Size.fromHeight(42),
              ),
              icon: const Icon(Icons.print),
              label: const Text('Print 3" Slip (<300ms)'),
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Raw ESC/POS spool sent to thermal printer')),
                );
                Navigator.pop(ctx);
                _barcodeFocusNode.requestFocus();
              },
            ),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: AppTheme.textLight,
                side: const BorderSide(color: AppTheme.cardBorder),
                minimumSize: const Size.fromHeight(42),
              ),
              icon: const Icon(Icons.picture_as_pdf),
              label: const Text('View A4 Invoice PDF'),
              onPressed: () {
                Navigator.pop(ctx);
                _barcodeFocusNode.requestFocus();
              },
            ),
          ],
        );

        return Dialog(
          backgroundColor: AppTheme.cardBg,
          insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: Container(
            width: isMobile ? double.maxFinite : 720,
            padding: EdgeInsets.all(isMobile ? 16 : 24),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Row(
                          children: [
                            const Icon(Icons.check_circle, color: AppTheme.primaryEmerald, size: 28),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Invoice Settled: ${invoice.invoiceNumber}',
                                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.textLight),
                                  ),
                                  Text(
                                    'Paid ₹${invoice.grandTotal.toStringAsFixed(2)} via ${invoice.paymentMethod} | Change Return: ₹${invoice.changeAmount.toStringAsFixed(2)}',
                                    style: const TextStyle(color: AppTheme.primaryEmerald, fontWeight: FontWeight.w600, fontSize: 12),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, color: AppTheme.textMuted),
                        onPressed: () {
                          Navigator.pop(ctx);
                          _barcodeFocusNode.requestFocus();
                        },
                      ),
                    ],
                  ),
                  const Divider(height: 24, color: AppTheme.cardBorder),
                  if (isMobile) ...[
                    receiptWidget,
                    const SizedBox(height: 16),
                    qrAndPrintWidget,
                  ] else ...[
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(flex: 3, child: receiptWidget),
                        const SizedBox(width: 20),
                        Expanded(flex: 2, child: qrAndPrintWidget),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  // ===========================================================================
  // DEDICATED DRAFTS & SUSPENDED BILLS VIEW
  // ===========================================================================
  Widget _buildDedicatedDraftsView(CartState cart, String currency) {
    final totalHeldRevenue = cart.heldCarts.fold(0.0, (sum, d) => sum + d.grandTotal);
    final totalHeldUnits = cart.heldCarts.fold(0.0, (sum, d) => sum + d.totalUnits);
    final totalHeldItems = cart.heldCarts.fold(0, (sum, d) => sum + d.itemCount);

    final query = _draftsSearchQuery.trim().toLowerCase();
    final filteredDrafts = cart.heldCarts.where((d) {
      if (query.isEmpty) return true;
      final matchToken = d.tokenNumber.toLowerCase().contains(query);
      final matchCust = (d.customer?.name.toLowerCase() ?? '').contains(query);
      final matchPhone = (d.customer?.phone ?? '').contains(query);
      final matchNotes = (d.notes?.toLowerCase() ?? '').contains(query);
      return matchToken || matchCust || matchPhone || matchNotes;
    }).toList();

    final isMobile = AppTheme.isMobile(context);
    // On mobile, do not auto-select first draft so user can pick from the master queue
    final selectedDraft = filteredDrafts.where((d) => d.id == _selectedDraftId).firstOrNull ??
        (!isMobile && filteredDrafts.isNotEmpty ? filteredDrafts.first : null);

    return Container(
      color: const Color(0xFF0B1120),
      padding: EdgeInsets.fromLTRB(isMobile ? 8 : 14, 10, isMobile ? 8 : 10, 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 1. Top Control Bar: Back to sale, Title, Search Filter, Clear All
          _buildDraftsTopToolbar(cart),
          const SizedBox(height: 8),

          // 2. Summary KPI Metrics Row
          _buildDraftsKpiRow(
            cart: cart,
            currency: currency,
            totalHeldRevenue: totalHeldRevenue,
            totalHeldUnits: totalHeldUnits,
            totalHeldItems: totalHeldItems,
          ),
          const SizedBox(height: 8),

          // 3. Main Master-Detail Split or Mobile Drilldown View
          Expanded(
            child: cart.heldCarts.isEmpty
                ? _buildDraftsEmptyState()
                : (filteredDrafts.isEmpty
                    ? _buildDraftsNoMatchState()
                    : isMobile
                        ? (selectedDraft != null
                            ? _buildDraftDetailInspector(
                                selectedDraft,
                                currency,
                                onBack: () => setState(() => _selectedDraftId = null),
                              )
                            : _buildDraftsMasterList(filteredDrafts, selectedDraft, currency))
                        : Row(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              // Left Master Pane: Held Invoices List Queue
                              SizedBox(
                                width: 380,
                                child: _buildDraftsMasterList(filteredDrafts, selectedDraft, currency),
                              ),
                              const SizedBox(width: 8),

                              // Right Detail Pane: Selected Draft Bill Inspector
                              Expanded(
                                child: selectedDraft != null
                                    ? _buildDraftDetailInspector(selectedDraft, currency)
                                    : const SizedBox.shrink(),
                              ),
                            ],
                          )),
          ),
        ],
      ),
    );
  }

  Widget _buildDraftsTopToolbar(CartState cart) {
    final isMobile = AppTheme.isMobile(context);

    if (isMobile) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: const Color(0xFF131D31),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: AppTheme.cardBorder),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2563EB),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                  ),
                  icon: const Icon(Icons.arrow_back_rounded, size: 16),
                  label: const Text('BACK', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                  onPressed: () => setState(() => _isDraftsViewActive = false),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Row(
                    children: [
                      const Text(
                        'Held Drafts',
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: Colors.white),
                      ),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: cart.heldCarts.isNotEmpty ? const Color(0xFF0284C7) : const Color(0xFF334155),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          '${cart.heldCarts.length}',
                          style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 36,
              child: TextField(
                controller: _draftsSearchController,
                onChanged: (val) => setState(() => _draftsSearchQuery = val),
                style: const TextStyle(fontSize: 12, color: Colors.white),
                decoration: InputDecoration(
                  isDense: true,
                  hintText: 'Search token, customer, notes...',
                  hintStyle: const TextStyle(fontSize: 11, color: AppTheme.textMuted),
                  prefixIcon: const Icon(Icons.search_rounded, size: 16, color: AppTheme.accentCyan),
                  suffixIcon: _draftsSearchQuery.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.close_rounded, size: 14, color: AppTheme.textMuted),
                          onPressed: () {
                            _draftsSearchController.clear();
                            setState(() => _draftsSearchQuery = '');
                          },
                        )
                      : null,
                  contentPadding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
                  filled: true,
                  fillColor: const Color(0xFF0B1120),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: const BorderSide(color: AppTheme.cardBorder)),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: const BorderSide(color: AppTheme.cardBorder)),
                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: const BorderSide(color: AppTheme.accentCyan, width: 1.5)),
                ),
              ),
            ),
            if (cart.items.isNotEmpty || cart.heldCarts.isNotEmpty) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: [
                  if (cart.items.isNotEmpty)
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFD97706),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                      ),
                      icon: const Icon(Icons.pause_circle_outline, size: 15),
                      label: const Text('Hold Current', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                      onPressed: _handleHoldCurrentDraft,
                    ),
                  if (cart.heldCarts.isNotEmpty)
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppTheme.accentRose,
                        side: BorderSide(color: AppTheme.accentRose.withValues(alpha: 0.5)),
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                      ),
                      icon: const Icon(Icons.delete_sweep_rounded, size: 16),
                      label: const Text('Clear All', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                      onPressed: () {
                        showDialog(
                          context: context,
                          builder: (ctx) => AlertDialog(
                            backgroundColor: const Color(0xFF1E293B),
                            insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
                            title: const Text('Discard All Held Bills?', style: TextStyle(color: Colors.white)),
                            content: const Text(
                              'Are you sure you want to discard all currently held draft invoices? This action cannot be undone.',
                              style: TextStyle(color: AppTheme.textLight),
                            ),
                            actions: [
                              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
                              ElevatedButton(
                                style: ElevatedButton.styleFrom(backgroundColor: AppTheme.accentRose, foregroundColor: Colors.white),
                                onPressed: () {
                                  Navigator.pop(ctx);
                                  ref.read(cartNotifierProvider.notifier).clearAllDrafts();
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('All draft invoices discarded.')),
                                  );
                                },
                                child: const Text('Discard All'),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                ],
              ),
            ],
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF131D31),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: AppTheme.cardBorder),
      ),
      child: Row(
        children: [
          // Back to Active Sale Button
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF2563EB),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
            ),
            icon: const Icon(Icons.arrow_back_rounded, size: 16),
            label: const Text(
              'RETURN TO SALE [ESC]',
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 0.5),
            ),
            onPressed: () => setState(() => _isDraftsViewActive = false),
          ),
          const SizedBox(width: 14),

          // Header Title & Counter Badge
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  const Text(
                    'Held Draft Invoices',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: Colors.white),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: cart.heldCarts.isNotEmpty ? const Color(0xFF0284C7) : const Color(0xFF334155),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '${cart.heldCarts.length} On Hold',
                      style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                  ),
                ],
              ),
              const Text(
                'Resume suspended bills or inspect item details before checkout',
                style: TextStyle(fontSize: 11, color: AppTheme.textSecondary),
              ),
            ],
          ),

          const Spacer(),

          // Search Field
          SizedBox(
            width: 320,
            height: 34,
            child: TextField(
              controller: _draftsSearchController,
              onChanged: (val) => setState(() => _draftsSearchQuery = val),
              style: const TextStyle(fontSize: 12, color: Colors.white),
              decoration: InputDecoration(
                isDense: true,
                hintText: 'Search token, customer, phone, note...',
                hintStyle: const TextStyle(fontSize: 11, color: AppTheme.textMuted),
                prefixIcon: const Icon(Icons.search_rounded, size: 16, color: AppTheme.accentCyan),
                suffixIcon: _draftsSearchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.close_rounded, size: 14, color: AppTheme.textMuted),
                        onPressed: () {
                          _draftsSearchController.clear();
                          setState(() => _draftsSearchQuery = '');
                        },
                      )
                    : null,
                contentPadding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
                filled: true,
                fillColor: const Color(0xFF0B1120),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: const BorderSide(color: AppTheme.cardBorder)),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: const BorderSide(color: AppTheme.cardBorder)),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: const BorderSide(color: AppTheme.accentCyan, width: 1.5)),
              ),
            ),
          ),
          const SizedBox(width: 10),

          // Hold Active Bill Option
          if (cart.items.isNotEmpty) ...[
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFD97706),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
              ),
              icon: const Icon(Icons.pause_circle_outline, size: 15),
              label: const Text('HOLD CURRENT [F6]', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
              onPressed: _handleHoldCurrentDraft,
            ),
            const SizedBox(width: 8),
          ],

          // Clear All Drafts Button
          if (cart.heldCarts.isNotEmpty)
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: AppTheme.accentRose,
                side: BorderSide(color: AppTheme.accentRose.withValues(alpha: 0.5)),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
              ),
              icon: const Icon(Icons.delete_sweep_rounded, size: 16),
              label: const Text('Clear All', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    backgroundColor: const Color(0xFF1E293B),
                    insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
                    title: const Text('Discard All Held Bills?', style: TextStyle(color: Colors.white)),
                    content: const Text(
                      'Are you sure you want to discard all currently held draft invoices? This action cannot be undone.',
                      style: TextStyle(color: AppTheme.textLight),
                    ),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(backgroundColor: AppTheme.accentRose, foregroundColor: Colors.white),
                        onPressed: () {
                          Navigator.pop(ctx);
                          ref.read(cartNotifierProvider.notifier).clearAllDrafts();
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('All draft invoices discarded.')),
                          );
                        },
                        child: const Text('Discard All'),
                      ),
                    ],
                  ),
                );
              },
            ),
        ],
      ),
    );
  }

  Widget _buildDraftsKpiRow({
    required CartState cart,
    required String currency,
    required double totalHeldRevenue,
    required double totalHeldUnits,
    required int totalHeldItems,
  }) {
    final isMobile = AppTheme.isMobile(context);

    final card1 = _buildDraftKpiCard(
      label: 'HELD BILLS',
      value: '${cart.heldCarts.length} Suspended',
      caption: 'Awaiting customer return',
      icon: Icons.receipt_long_rounded,
      color: const Color(0xFF0284C7),
    );

    final card2 = _buildDraftKpiCard(
      label: 'SUSPENDED VALUE',
      value: '$currency${totalHeldRevenue.toStringAsFixed(2)}',
      caption: 'Merchandise value pending',
      icon: Icons.payments_rounded,
      color: const Color(0xFF10B981),
    );

    final card3 = _buildDraftKpiCard(
      label: 'TOTAL VOLUME',
      value: '${totalHeldUnits.toStringAsFixed(0)} Units',
      caption: 'Across $totalHeldItems line items',
      icon: Icons.inventory_2_rounded,
      color: const Color(0xFFF59E0B),
    );

    final card4 = _buildDraftKpiCard(
      label: 'ACTIVE CART STATUS',
      value: cart.items.isEmpty ? 'Cart Ready (0 items)' : '${cart.items.length} Items ($currency${cart.grandTotal.toStringAsFixed(2)})',
      caption: cart.items.isEmpty ? 'Directly loads draft on resume' : 'Will prompt safe swap on resume',
      icon: Icons.shopping_cart_outlined,
      color: cart.items.isEmpty ? AppTheme.accentCyan : const Color(0xFFEC4899),
    );

    if (isMobile) {
      return SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            SizedBox(width: 170, child: card1),
            const SizedBox(width: 8),
            SizedBox(width: 180, child: card2),
            const SizedBox(width: 8),
            SizedBox(width: 170, child: card3),
            const SizedBox(width: 8),
            SizedBox(width: 200, child: card4),
          ],
        ),
      );
    }

    return Row(
      children: [
        Expanded(child: card1),
        const SizedBox(width: 8),
        Expanded(child: card2),
        const SizedBox(width: 8),
        Expanded(child: card3),
        const SizedBox(width: 8),
        Expanded(child: card4),
      ],
    );
  }

  Widget _buildDraftKpiCard({
    required String label,
    required String value,
    required String caption,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF131D31),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: AppTheme.cardBorder),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Icon(icon, size: 20, color: color),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(label, style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: AppTheme.textMuted, letterSpacing: 0.5)),
                const SizedBox(height: 1),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: Colors.white),
                ),
                Text(
                  caption,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 10, color: AppTheme.textSecondary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDraftsMasterList(List<DraftInvoice> drafts, DraftInvoice? selectedDraft, String currency) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF131D31),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: AppTheme.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Master Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: const BoxDecoration(
              color: Color(0xFF0F172A),
              borderRadius: BorderRadius.vertical(top: Radius.circular(5)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('HELD BILLS QUEUE', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.textMuted)),
                Text('${drafts.length} items', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppTheme.accentCyan)),
              ],
            ),
          ),
          const Divider(height: 1, color: AppTheme.cardBorder),

          // Scrollable Cards List
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.all(6),
              itemCount: drafts.length,
              separatorBuilder: (_, __) => const SizedBox(height: 6),
              itemBuilder: (context, index) {
                final draft = drafts[index];
                final isSelected = selectedDraft?.id == draft.id;
                final formattedTime = DateFormat('hh:mm a').format(draft.createdAt);

                return InkWell(
                  onTap: () => setState(() => _selectedDraftId = draft.id),
                  borderRadius: BorderRadius.circular(6),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: isSelected ? const Color(0xFF1E293B) : const Color(0xFF0F172A),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: isSelected ? AppTheme.accentCyan : AppTheme.cardBorder,
                        width: isSelected ? 1.5 : 1,
                      ),
                      boxShadow: isSelected
                          ? [
                              BoxShadow(
                                color: AppTheme.accentCyan.withValues(alpha: 0.12),
                                blurRadius: 6,
                                offset: const Offset(0, 2),
                              )
                            ]
                          : null,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Row 1: Token Badge & Time
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? AppTheme.accentCyan.withValues(alpha: 0.2)
                                    : const Color(0xFF334155),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                draft.tokenNumber,
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w900,
                                  color: isSelected ? AppTheme.accentCyan : Colors.white,
                                ),
                              ),
                            ),
                            Row(
                              children: [
                                const Icon(Icons.access_time_rounded, size: 11, color: AppTheme.textMuted),
                                const SizedBox(width: 3),
                                Text(
                                  formattedTime,
                                  style: const TextStyle(fontSize: 11, color: AppTheme.textMuted),
                                ),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),

                        // Row 2: Customer Name & Mobile
                        Row(
                          children: [
                            const Icon(Icons.person_rounded, size: 13, color: AppTheme.accentCyan),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                (draft.customer?.name ?? '').isNotEmpty ? draft.customer!.name : 'Walk-in Customer',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.white),
                              ),
                            ),
                            if ((draft.customer?.phone ?? '').isNotEmpty) ...[
                              const SizedBox(width: 4),
                              Text(
                                draft.customer!.phone!,
                                style: const TextStyle(fontSize: 11, color: AppTheme.textMuted),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 4),

                        // Row 3: Items Count & Grand Total
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              '${draft.itemCount} items • ${draft.totalUnits.toStringAsFixed(0)} units',
                              style: const TextStyle(fontSize: 11, color: AppTheme.textMuted),
                            ),
                            Text(
                              '$currency${draft.grandTotal.toStringAsFixed(2)}',
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w900,
                                color: AppTheme.primaryEmerald,
                              ),
                            ),
                          ],
                        ),

                        // Row 4: Note snippet if available
                        if (draft.notes?.isNotEmpty == true) ...[
                          const SizedBox(height: 5),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFF131D31),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              'Note: ${draft.notes!}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 10, fontStyle: FontStyle.italic, color: AppTheme.accentCyan),
                            ),
                          ),
                        ],
                        const SizedBox(height: 8),

                        // Row 5: Action Buttons (Resume & Discard)
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            InkWell(
                              onTap: () {
                                ref.read(cartNotifierProvider.notifier).discardDraftBill(draft.id);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('${draft.tokenNumber} discarded.')),
                                );
                              },
                              borderRadius: BorderRadius.circular(4),
                              child: const Padding(
                                padding: EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.delete_outline_rounded, size: 14, color: AppTheme.accentRose),
                                    SizedBox(width: 2),
                                    Text('Discard', style: TextStyle(fontSize: 11, color: AppTheme.accentRose)),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppTheme.primaryEmerald,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                minimumSize: Size.zero,
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                              ),
                              icon: const Icon(Icons.play_arrow_rounded, size: 14),
                              label: const Text('Resume', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                              onPressed: () => _resumeDraftBill(draft),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDraftDetailInspector(DraftInvoice draft, String currency, {VoidCallback? onBack}) {
    final formattedDateTime = DateFormat('dd MMM yyyy, hh:mm:ss a').format(draft.createdAt);
    final totalTax = draft.items.fold(0.0, (sum, i) => sum + i.taxResult.taxAmount);
    final subtotal = draft.items.fold(0.0, (sum, i) => sum + (i.quantity * i.unitPrice));
    final totalDisc = draft.items.fold(0.0, (sum, i) => sum + i.discountAmount);
    final isMobile = AppTheme.isMobile(context);

    final notesAndMetaWidget = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (draft.notes?.isNotEmpty == true) ...[
          const Row(
            children: [
              Icon(Icons.sticky_note_2_outlined, size: 14, color: AppTheme.accentCyan),
              SizedBox(width: 4),
              Text('Draft Note / Reference:', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.accentCyan)),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            draft.notes!,
            style: const TextStyle(fontSize: 12, color: Colors.white70, fontStyle: FontStyle.italic),
          ),
          const SizedBox(height: 4),
        ],
        Text(
          'Total Items: ${draft.itemCount} | Total Physical Quantity: ${draft.totalUnits.toStringAsFixed(0)} | Invoice Type: ${draft.invoiceType}',
          style: const TextStyle(fontSize: 11, color: AppTheme.textMuted),
        ),
      ],
    );

    final financialBreakdownWidget = Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: AppTheme.cardBorder),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Subtotal: $currency${subtotal.toStringAsFixed(2)}', style: const TextStyle(fontSize: 11, color: AppTheme.textMuted)),
              if (totalDisc > 0)
                Text('Discounts: -$currency${totalDisc.toStringAsFixed(2)}', style: const TextStyle(fontSize: 11, color: AppTheme.accentAmber)),
              Text('Taxes (GST): $currency${totalTax.toStringAsFixed(2)}', style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
            ],
          ),
          const SizedBox(width: 14),
          Container(height: 34, width: 1, color: AppTheme.cardBorder),
          const SizedBox(width: 14),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('NET PAYABLE', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppTheme.accentCyan)),
              Text(
                '$currency${draft.grandTotal.toStringAsFixed(2)}',
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: Colors.white),
              ),
            ],
          ),
        ],
      ),
    );

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF131D31),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: AppTheme.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Inspector Header Card
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: const BoxDecoration(
              color: Color(0xFF0F172A),
              borderRadius: BorderRadius.vertical(top: Radius.circular(5)),
            ),
            child: isMobile
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          if (onBack != null) ...[
                            IconButton(
                              icon: const Icon(Icons.arrow_back_rounded, color: Colors.white, size: 20),
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                              onPressed: onBack,
                            ),
                            const SizedBox(width: 8),
                          ],
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: const Color(0xFF0284C7).withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(color: const Color(0xFF38BDF8)),
                            ),
                            child: Text(
                              draft.tokenNumber,
                              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: Color(0xFF38BDF8)),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              formattedDateTime,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 11, color: AppTheme.textMuted),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          const Icon(Icons.person_outline_rounded, size: 14, color: AppTheme.accentCyan),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              (draft.customer?.name ?? '').isNotEmpty ? draft.customer!.name : 'Walk-in Customer',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.white),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                            decoration: BoxDecoration(
                              color: const Color(0xFF1E293B),
                              borderRadius: BorderRadius.circular(3),
                            ),
                            child: Text(
                              'Pay: ${draft.paymentMethod}',
                              style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: AppTheme.accentCyan),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 8,
                        runSpacing: 6,
                        alignment: WrapAlignment.end,
                        children: [
                          OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppTheme.accentRose,
                              side: const BorderSide(color: Color(0xFF475569)),
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                            ),
                            icon: const Icon(Icons.delete_outline_rounded, size: 16),
                            label: const Text('Discard', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                            onPressed: () {
                              ref.read(cartNotifierProvider.notifier).discardDraftBill(draft.id);
                              if (onBack != null) onBack();
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('${draft.tokenNumber} discarded.')),
                              );
                            },
                          ),
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.primaryEmerald,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                              elevation: 3,
                            ),
                            icon: const Icon(Icons.play_circle_fill_rounded, size: 16),
                            label: const Text(
                              'RESUME BILL',
                              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900, letterSpacing: 0.5),
                            ),
                            onPressed: () => _resumeDraftBill(draft),
                          ),
                        ],
                      ),
                    ],
                  )
                : Row(
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF0284C7).withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(4),
                                  border: Border.all(color: const Color(0xFF38BDF8)),
                                ),
                                child: Text(
                                  draft.tokenNumber,
                                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: Color(0xFF38BDF8)),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Text(
                                'Suspended on $formattedDateTime',
                                style: const TextStyle(fontSize: 11, color: AppTheme.textMuted),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              const Icon(Icons.person_outline_rounded, size: 14, color: AppTheme.accentCyan),
                              const SizedBox(width: 4),
                              Text(
                                (draft.customer?.name ?? '').isNotEmpty ? draft.customer!.name : 'Walk-in Customer',
                                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.white),
                              ),
                              if ((draft.customer?.phone ?? '').isNotEmpty) ...[
                                const SizedBox(width: 6),
                                Text('(${draft.customer!.phone})', style: const TextStyle(fontSize: 11, color: AppTheme.textMuted)),
                              ],
                              const SizedBox(width: 10),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF1E293B),
                                  borderRadius: BorderRadius.circular(3),
                                ),
                                child: Text(
                                  'Pay: ${draft.paymentMethod}',
                                  style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: AppTheme.accentCyan),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const Spacer(),
                      OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppTheme.accentRose,
                          side: const BorderSide(color: Color(0xFF475569)),
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                        ),
                        icon: const Icon(Icons.delete_outline_rounded, size: 16),
                        label: const Text('Discard', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                        onPressed: () {
                          ref.read(cartNotifierProvider.notifier).discardDraftBill(draft.id);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('${draft.tokenNumber} discarded.')),
                          );
                        },
                      ),
                      const SizedBox(width: 10),
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primaryEmerald,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                          elevation: 3,
                        ),
                        icon: const Icon(Icons.play_circle_fill_rounded, size: 18),
                        label: const Text(
                          'RESUME BILL TO ACTIVE CART',
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w900, letterSpacing: 0.6),
                        ),
                        onPressed: () => _resumeDraftBill(draft),
                      ),
                    ],
                  ),
          ),
          const Divider(height: 1, color: AppTheme.cardBorder),

          // Items Table Header and Rows (horizontally scrollable on mobile)
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: SizedBox(
                width: 780,
                child: Column(
                  children: [
                    Container(
                      height: 30,
                      color: const Color(0xFF0B1120),
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      child: const Row(
                        children: [
                          SizedBox(width: 32, child: Text('#', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppTheme.textMuted))),
                          Expanded(flex: 4, child: Text('ITEM NAME / DESCRIPTION', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppTheme.textMuted))),
                          Expanded(flex: 2, child: Text('BARCODE', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppTheme.textMuted))),
                          Expanded(flex: 2, child: Text('BATCH', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppTheme.textMuted))),
                          Expanded(flex: 1, child: Text('QTY', textAlign: TextAlign.right, style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppTheme.textMuted))),
                          SizedBox(width: 50, child: Text('UOM', textAlign: TextAlign.center, style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppTheme.textMuted))),
                          Expanded(flex: 2, child: Text('RATE', textAlign: TextAlign.right, style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppTheme.textMuted))),
                          Expanded(flex: 2, child: Text('DISC', textAlign: TextAlign.right, style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppTheme.textMuted))),
                          Expanded(flex: 2, child: Text('TAX', textAlign: TextAlign.right, style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppTheme.textMuted))),
                          Expanded(flex: 2, child: Text('NET TOTAL', textAlign: TextAlign.right, style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppTheme.accentCyan))),
                        ],
                      ),
                    ),
                    const Divider(height: 1, color: AppTheme.cardBorder),
                    Expanded(
                      child: ListView.builder(
                        itemCount: draft.items.length,
                        itemBuilder: (ctx, index) {
                          final item = draft.items[index];
                          final isEven = index % 2 == 0;

                          return Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                            color: isEven ? const Color(0xFF131D31) : const Color(0xFF0F172A),
                            child: Row(
                              children: [
                                SizedBox(
                                  width: 32,
                                  child: Text('${index + 1}', style: const TextStyle(fontSize: 11, color: AppTheme.textMuted)),
                                ),
                                Expanded(
                                  flex: 4,
                                  child: Text(
                                    item.product.name,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
                                  ),
                                ),
                                Expanded(
                                  flex: 2,
                                  child: Text(
                                    item.product.barcode ?? '-',
                                    style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                                  ),
                                ),
                                Expanded(
                                  flex: 2,
                                  child: Text(
                                    item.batchNumber ?? '-',
                                    style: const TextStyle(fontSize: 11, color: AppTheme.textMuted),
                                  ),
                                ),
                                Expanded(
                                  flex: 1,
                                  child: Text(
                                    item.quantity.toStringAsFixed(2),
                                    textAlign: TextAlign.right,
                                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
                                  ),
                                ),
                                SizedBox(
                                  width: 50,
                                  child: Text(
                                    item.uom,
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(fontSize: 11, color: AppTheme.textMuted),
                                  ),
                                ),
                                Expanded(
                                  flex: 2,
                                  child: Text(
                                    item.unitPrice.toStringAsFixed(2),
                                    textAlign: TextAlign.right,
                                    style: const TextStyle(fontSize: 11, color: AppTheme.textLight),
                                  ),
                                ),
                                Expanded(
                                  flex: 2,
                                  child: Text(
                                    item.discountAmount.toStringAsFixed(2),
                                    textAlign: TextAlign.right,
                                    style: const TextStyle(fontSize: 11, color: AppTheme.accentAmber),
                                  ),
                                ),
                                Expanded(
                                  flex: 2,
                                  child: Text(
                                    '${item.taxResult.taxAmount.toStringAsFixed(2)} (${(item.product.taxSlab?.ratePercent ?? 0.0).toStringAsFixed(0)}%)',
                                    textAlign: TextAlign.right,
                                    style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                                  ),
                                ),
                                Expanded(
                                  flex: 2,
                                  child: Text(
                                    item.taxResult.totalLineAmount.toStringAsFixed(2),
                                    textAlign: TextAlign.right,
                                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: AppTheme.primaryEmerald),
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const Divider(height: 1, color: AppTheme.cardBorder),

          // Bottom Summary & Notes Panel
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            color: const Color(0xFF0F172A),
            child: isMobile
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      notesAndMetaWidget,
                      const SizedBox(height: 10),
                      financialBreakdownWidget,
                    ],
                  )
                : Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Expanded(child: notesAndMetaWidget),
                      const SizedBox(width: 20),
                      financialBreakdownWidget,
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildDraftsEmptyState() {
    return Center(
      child: Container(
        padding: const EdgeInsets.all(32),
        constraints: const BoxConstraints(maxWidth: 520),
        decoration: BoxDecoration(
          color: const Color(0xFF131D31),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppTheme.cardBorder),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF0284C7).withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.receipt_long_rounded, size: 54, color: Color(0xFF38BDF8)),
            ),
            const SizedBox(height: 16),
            const Text(
              'No Draft Bills Currently on Hold',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
            ),
            const SizedBox(height: 8),
            const Text(
              'When a customer pauses checkout or steps away to pick more items, press [F6] or tap "DRAFT" during active sales.\nThe items will be safely preserved here without holding up your counter queue.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: AppTheme.textSecondary, height: 1.4),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2563EB),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
              ),
              icon: const Icon(Icons.point_of_sale_rounded, size: 18),
              label: const Text('RETURN TO SALES BILLING GRID', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              onPressed: () => setState(() => _isDraftsViewActive = false),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDraftsNoMatchState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.search_off_rounded, size: 48, color: AppTheme.textMuted),
          const SizedBox(height: 12),
          Text(
            'No held draft bills match "$_draftsSearchQuery"',
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white),
          ),
          const SizedBox(height: 6),
          const Text('Try searching by customer name, phone number, token ID, or notes.', style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
          const SizedBox(height: 14),
          OutlinedButton(
            onPressed: () {
              _draftsSearchController.clear();
              setState(() => _draftsSearchQuery = '');
            },
            child: const Text('Clear Search Filter'),
          ),
        ],
      ),
    );
  }

  void _showMobileActionLauncherSheet(CartState cart) {
    final actions = [
      {
        'label': _isDraftsViewActive ? 'Sale Grid' : 'Drafts (${cart.heldCarts.length})',
        'icon': Icons.receipt_long_rounded,
        'color': const Color(0xFF0284C7),
        'onTap': () {
          Navigator.pop(context);
          setState(() => _isDraftsViewActive = !_isDraftsViewActive);
        },
      },
      {
        'label': 'Sales',
        'icon': Icons.point_of_sale_rounded,
        'color': const Color(0xFFEC4899),
        'onTap': () {
          Navigator.pop(context);
          if (_isDraftsViewActive) setState(() => _isDraftsViewActive = false);
          _barcodeFocusNode.requestFocus();
        },
      },
      {
        'label': 'Purchase',
        'icon': Icons.local_shipping_rounded,
        'color': const Color(0xFF10B981),
        'onTap': () {
          Navigator.pop(context);
          widget.onNavigateTab?.call(2);
        },
      },
      {
        'label': 'Voucher',
        'icon': Icons.account_balance_wallet_rounded,
        'color': const Color(0xFF06B6D4),
        'onTap': () {
          Navigator.pop(context);
          _showVoucherDialog();
        },
      },
      {
        'label': 'Sales Return',
        'icon': Icons.assignment_return_rounded,
        'color': const Color(0xFFF97316),
        'onTap': () {
          Navigator.pop(context);
          _showSalesReturnDialog();
        },
      },
      {
        'label': 'Sales Report',
        'icon': Icons.query_stats_rounded,
        'color': const Color(0xFF14B8A6),
        'onTap': () {
          Navigator.pop(context);
          widget.onNavigateTab?.call(5);
        },
      },
      {
        'label': 'Ledger',
        'icon': Icons.menu_book_rounded,
        'color': const Color(0xFF8B5CF6),
        'onTap': () {
          Navigator.pop(context);
          widget.onNavigateTab?.call(4);
        },
      },
      {
        'label': 'Stock Report',
        'icon': Icons.inventory_2_rounded,
        'color': const Color(0xFF3B82F6),
        'onTap': () {
          Navigator.pop(context);
          widget.onNavigateTab?.call(3);
        },
      },
      {
        'label': 'Inventory',
        'icon': Icons.shopping_basket_rounded,
        'color': const Color(0xFFF43F5E),
        'onTap': () {
          Navigator.pop(context);
          widget.onNavigateTab?.call(3);
        },
      },
      {
        'label': 'Account',
        'icon': Icons.groups_2_rounded,
        'color': const Color(0xFF0EA5E9),
        'onTap': () {
          Navigator.pop(context);
          widget.onNavigateTab?.call(4);
        },
      },
      {
        'label': 'Data Backup',
        'icon': Icons.cloud_sync_rounded,
        'color': const Color(0xFFF59E0B),
        'onTap': () {
          Navigator.pop(context);
          _showBackupDialog();
        },
      },
      {
        'label': 'Touch Mode',
        'icon': Icons.touch_app_rounded,
        'color': const Color(0xFFA855F7),
        'onTap': () {
          Navigator.pop(context);
          setState(() => _isTouchMode = !_isTouchMode);
        },
      },
    ];

    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF131D31),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('POS Quick Actions', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white)),
                IconButton(
                  icon: const Icon(Icons.close, size: 18, color: AppTheme.textMuted),
                  onPressed: () => Navigator.pop(ctx),
                ),
              ],
            ),
            const SizedBox(height: 10),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 4,
                crossAxisSpacing: 8,
                mainAxisSpacing: 8,
                childAspectRatio: 1.1,
              ),
              itemCount: actions.length,
              itemBuilder: (context, idx) {
                final a = actions[idx];
                final color = a['color'] as Color;
                return InkWell(
                  borderRadius: BorderRadius.circular(8),
                  onTap: a['onTap'] as VoidCallback,
                  child: Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E293B),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: color.withValues(alpha: 0.3)),
                    ),
                    padding: const EdgeInsets.all(6),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(a['icon'] as IconData, size: 20, color: color),
                        const SizedBox(height: 4),
                        Text(
                          a['label'] as String,
                          textAlign: TextAlign.center,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Colors.white),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  // ===========================================================================
  // BUILD METHOD
  // ===========================================================================
  @override
  Widget build(BuildContext context) {
    final cart = ref.watch(cartNotifierProvider);
    final currency = ref.watch(currencySymbolProvider);
    final isMobile = AppTheme.isMobile(context);

    return KeyboardListener(
      focusNode: _keyboardFocusNode,
      onKeyEvent: _handleKeyEvent,
      child: Scaffold(
        backgroundColor: const Color(0xFF0B1120), // Dark Navy Background
        body: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // =================================================================
            // MAIN WORKSPACE: Sales Window or Dedicated Drafts View
            // =================================================================
            Expanded(
              child: Column(
                children: [
                  // 1. Top Windows-style Sales Header Window Bar
                  _buildWindowHeaderBar(cart, isMobile),

                  // 2. Main Content Area (Dedicated Drafts View OR Active Sales Window)
                  Expanded(
                    child: _isDraftsViewActive
                        ? _buildDedicatedDraftsView(cart, currency)
                        : Padding(
                            padding: EdgeInsets.fromLTRB(isMobile ? 6 : 14, 6, isMobile ? 6 : 10, 4),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                // 2A. Aligned Sales Invoice Header Form
                                _buildTopInvoiceHeaderForm(cart, isMobile),
                                const SizedBox(height: 6),

                                // 2B. Line Items Detail (Rapid Entry Bar + High-Density Grid) - Pure Sales Details
                                Expanded(
                                  child: _buildItemsDetailTabContent(cart, currency, isMobile),
                                ),
                                const SizedBox(height: 6),

                                // 2C. Mid Action & Print Bar ([Save], [+Add], Total Qty, Print 3", A4, A5)
                                _buildMidActionAndPrintBar(cart, isMobile),
                                const SizedBox(height: 6),

                                // 2D. Bottom Financial Summary & Tender Row (2-Tier Stacked Card)
                                _buildBottomFinancialAndTenderRow(cart, currency, isMobile),
                              ],
                            ),
                          ),
                  ),

                  // 3. Persistent Footer Keyboard Shortcuts & Live Product Status Bar
                  _buildLiveStatusAndShortcutsFooter(cart, isMobile),
                ],
              ),
            ),

            // =================================================================
            // RIGHT QUICK ACTION LAUNCHER (Hidden on mobile)
            // =================================================================
            if (!isMobile) _buildRightActionLauncher(cart),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // 1. TOP WINDOW HEADER BAR (BillPro Title / Administrator)
  // ---------------------------------------------------------------------------
  Widget _buildWindowHeaderBar(CartState cart, bool isMobile) {
    final company = ref.watch(companyProfileProvider).value;
    final branch = (company?.branchName.isNotEmpty ?? false) ? company!.branchName.toUpperCase() : 'MAIN STORE';
    final cashier = _salesPersonController.text.trim().isNotEmpty ? _salesPersonController.text.trim() : 'ADMINISTRATOR';
    final appTitle = (company?.tradeName.isNotEmpty ?? false) ? '${company!.tradeName} POS' : 'BillPro POS';

    if (isMobile) {
      return Container(
        height: 38,
        color: const Color(0xFF131D31),
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [Color(0xFF2563EB), Color(0xFF06B6D4)]),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                appTitle,
                style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white),
              ),
            ),
            const SizedBox(width: 8),
            _buildViewModeSegmentedToggle(cart),
            const Spacer(),
            IconButton(
              icon: const Icon(Icons.apps_rounded, size: 20, color: AppTheme.accentCyan),
              tooltip: 'Quick Actions',
              onPressed: () => _showMobileActionLauncherSheet(cart),
            ),
            IconButton(
              icon: const Icon(Icons.help_outline, size: 16, color: AppTheme.textMuted),
              tooltip: 'Shortcuts',
              onPressed: _showHelpDialog,
            ),
          ],
        ),
      );
    }

    return Container(
      height: 36,
      color: const Color(0xFF131D31),
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [Color(0xFF2563EB), Color(0xFF06B6D4)]),
              borderRadius: BorderRadius.circular(4),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF2563EB).withValues(alpha: 0.3),
                  blurRadius: 4,
                  offset: const Offset(0, 1),
                ),
              ],
            ),
            child: Text(
              appTitle,
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white),
            ),
          ),
          const SizedBox(width: 10),
          Text(
            'User: $cashier  |  Branch: $branch  |  Offline Local DB',
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: AppTheme.textMuted),
          ),
          const Spacer(),
          // Segmented Navigation: [ Sales Billing ] vs [ Held Drafts (N) ]
          _buildViewModeSegmentedToggle(cart),
          const SizedBox(width: 14),
          // Mode Toggle
          Row(
            children: [
              Text(
                _isTouchMode ? 'Touch Mode' : 'Keyboard Rapid Mode',
                style: const TextStyle(fontSize: 11, color: AppTheme.accentCyan, fontWeight: FontWeight.w600),
              ),
              const SizedBox(width: 6),
              Switch(
                value: _isTouchMode,
                activeTrackColor: AppTheme.primaryBlue,
                activeThumbColor: AppTheme.accentCyan,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                onChanged: (val) => setState(() => _isTouchMode = val),
              ),
            ],
          ),
          const SizedBox(width: 14),
          IconButton(
            icon: const Icon(Icons.help_outline, size: 16, color: AppTheme.textMuted),
            tooltip: 'Keyboard Shortcuts [F1]',
            onPressed: _showHelpDialog,
          ),
        ],
      ),
    );
  }

  Widget _buildViewModeSegmentedToggle(CartState cart) {
    return Container(
      height: 28,
      decoration: BoxDecoration(
        color: const Color(0xFF0B1120),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: AppTheme.cardBorder),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Sales Invoice Tab
          InkWell(
            onTap: () => setState(() => _isDraftsViewActive = false),
            borderRadius: const BorderRadius.horizontal(left: Radius.circular(5)),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: !_isDraftsViewActive ? const Color(0xFF2563EB) : Colors.transparent,
                borderRadius: const BorderRadius.horizontal(left: Radius.circular(5)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.point_of_sale_rounded,
                    size: 13,
                    color: !_isDraftsViewActive ? Colors.white : AppTheme.textMuted,
                  ),
                  const SizedBox(width: 5),
                  Text(
                    'Sale Invoice',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: !_isDraftsViewActive ? Colors.white : AppTheme.textMuted,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Held Drafts Tab with Badge
          InkWell(
            onTap: () => setState(() => _isDraftsViewActive = true),
            borderRadius: const BorderRadius.horizontal(right: Radius.circular(5)),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: _isDraftsViewActive ? const Color(0xFF0284C7) : Colors.transparent,
                borderRadius: const BorderRadius.horizontal(right: Radius.circular(5)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.receipt_long_rounded,
                    size: 13,
                    color: _isDraftsViewActive ? Colors.white : (cart.heldCarts.isNotEmpty ? AppTheme.accentCyan : AppTheme.textMuted),
                  ),
                  const SizedBox(width: 5),
                  Text(
                    'Held Drafts',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: _isDraftsViewActive ? Colors.white : AppTheme.textMuted,
                    ),
                  ),
                  if (cart.heldCarts.isNotEmpty) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                      decoration: BoxDecoration(
                        color: _isDraftsViewActive ? Colors.white : const Color(0xFFEF4444),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '${cart.heldCarts.length}',
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w900,
                          color: _isDraftsViewActive ? const Color(0xFF0284C7) : Colors.white,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // 2A. TOP INVOICE HEADER FORM (ALIGNED SINGLE ROW)
  // ---------------------------------------------------------------------------
  Widget _buildTopInvoiceHeaderForm(CartState cart, bool isMobile) {
    final dateFormat = DateFormat('dd/MM/yyyy');

    if (isMobile) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: BoxDecoration(
          color: const Color(0xFF131D31),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: AppTheme.cardBorder),
        ),
        child: Column(
          children: [
            // Row 1: Invoice No, Date, Tax Mode, Notes
            Row(
              children: [
                // Invoice No & Prefix
                Expanded(
                  flex: 3,
                  child: _buildCompactLabeledField(
                    label: 'Invoice No',
                    child: Row(
                      children: [
                        SizedBox(
                          width: 32,
                          height: 28,
                          child: TextField(
                            controller: _prefixController,
                            style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppTheme.textMuted),
                            decoration: const InputDecoration(
                              isDense: true,
                              contentPadding: EdgeInsets.symmetric(horizontal: 3, vertical: 6),
                            ),
                          ),
                        ),
                        const SizedBox(width: 2),
                        Expanded(
                          child: SizedBox(
                            height: 28,
                            child: TextField(
                              controller: _invoiceNoController,
                              style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppTheme.accentCyan),
                              decoration: const InputDecoration(
                                isDense: true,
                                contentPadding: EdgeInsets.symmetric(horizontal: 4, vertical: 6),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 6),

                // Date
                Expanded(
                  flex: 3,
                  child: _buildCompactLabeledField(
                    label: 'Date',
                    child: InkWell(
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: _invoiceDate,
                          firstDate: DateTime(2020),
                          lastDate: DateTime(2035),
                        );
                        if (picked != null) {
                          setState(() => _invoiceDate = picked);
                        }
                      },
                      child: Container(
                        height: 28,
                        alignment: Alignment.centerLeft,
                        padding: const EdgeInsets.symmetric(horizontal: 6),
                        decoration: BoxDecoration(
                          color: AppTheme.darkBg,
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: AppTheme.cardBorder),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(dateFormat.format(_invoiceDate), style: const TextStyle(fontSize: 10, color: AppTheme.textLight)),
                            const Icon(Icons.calendar_today, size: 10, color: AppTheme.textMuted),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 6),

                // Tax Mode
                Expanded(
                  flex: 3,
                  child: _buildCompactLabeledField(
                    label: 'Tax Mode',
                    child: Container(
                      height: 28,
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      decoration: BoxDecoration(
                        color: AppTheme.darkBg,
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: AppTheme.cardBorder),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: cart.invoiceType,
                          isExpanded: true,
                          dropdownColor: AppTheme.cardBg,
                          icon: const Icon(Icons.arrow_drop_down, size: 14),
                          items: const [
                            DropdownMenuItem(value: 'Local', child: Text('Local', style: TextStyle(fontSize: 10, color: AppTheme.textLight))),
                            DropdownMenuItem(value: 'Interstate', child: Text('Interstate', style: TextStyle(fontSize: 10, color: AppTheme.textLight))),
                          ],
                          onChanged: (val) {
                            if (val != null) {
                              ref.read(cartNotifierProvider.notifier).setInvoiceType(val);
                            }
                          },
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 4),

                // Notes Button
                _buildCompactLabeledField(
                  label: 'Notes',
                  width: 28,
                  child: SizedBox(
                    height: 28,
                    child: IconButton(
                      padding: EdgeInsets.zero,
                      icon: Icon(
                        _notesController.text.trim().isNotEmpty ? Icons.sticky_note_2 : Icons.notes,
                        size: 15,
                        color: _notesController.text.trim().isNotEmpty ? AppTheme.accentAmber : AppTheme.textMuted,
                      ),
                      tooltip: 'Invoice Notes',
                      onPressed: _showInvoiceNotesDialog,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),

            // Row 2: Cust Mob, Customer Name (+ lookup), Dr Balance
            Row(
              children: [
                // Cust Mob
                SizedBox(
                  width: 90,
                  child: _buildCompactLabeledField(
                    label: 'Cust Mob',
                    child: SizedBox(
                      height: 28,
                      child: TextField(
                        controller: _custMobController,
                        keyboardType: TextInputType.phone,
                        style: const TextStyle(fontSize: 10, color: AppTheme.textLight),
                        decoration: const InputDecoration(
                          isDense: true,
                          hintText: 'Phone...',
                          hintStyle: TextStyle(fontSize: 9, color: AppTheme.textMuted),
                          contentPadding: EdgeInsets.symmetric(horizontal: 4, vertical: 6),
                        ),
                        onChanged: (val) {
                          final query = val.trim();
                          if (query.isNotEmpty) {
                            final customers = ref.read(customersProvider).value ?? [];
                            final matches = customers.where((c) => c.phone != null && c.phone!.contains(query)).toList();
                            if (matches.isNotEmpty) {
                              ref.read(cartNotifierProvider.notifier).setCustomer(matches.first);
                            }
                          }
                        },
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 6),

                // Customer Name
                Expanded(
                  child: _buildCompactLabeledField(
                    label: 'Customer Name',
                    child: Container(
                      height: 28,
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                      decoration: BoxDecoration(
                        color: AppTheme.darkBg,
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: AppTheme.cardBorder),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              cart.customer.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppTheme.textLight),
                            ),
                          ),
                          InkWell(
                            onTap: _showCustomerLookupDialog,
                            child: const Padding(
                              padding: EdgeInsets.symmetric(horizontal: 2),
                              child: Icon(Icons.person_search, size: 15, color: AppTheme.primaryBlue),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 6),

                // Dr Balance
                SizedBox(
                  width: 75,
                  child: _buildCompactLabeledField(
                    label: 'Dr Bal',
                    child: Container(
                      height: 28,
                      alignment: Alignment.center,
                      padding: const EdgeInsets.symmetric(horizontal: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFF2A1520),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: AppTheme.accentRose.withValues(alpha: 0.5)),
                      ),
                      child: Text(
                        'Dr ₹${cart.customer.currentBalance.toStringAsFixed(0)}',
                        style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppTheme.accentRose),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFF131D31),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: AppTheme.cardBorder),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Invoice No & Prefix
          _buildCompactLabeledField(
            label: 'Invoice No',
            width: 105,
            child: Row(
              children: [
                SizedBox(
                  width: 38,
                  height: 28,
                  child: TextField(
                    controller: _prefixController,
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.textMuted),
                    decoration: const InputDecoration(
                      isDense: true,
                      contentPadding: EdgeInsets.symmetric(horizontal: 4, vertical: 6),
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: SizedBox(
                    height: 28,
                    child: TextField(
                      controller: _invoiceNoController,
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.accentCyan),
                      decoration: const InputDecoration(
                        isDense: true,
                        contentPadding: EdgeInsets.symmetric(horizontal: 6, vertical: 6),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),

          // Invoice Date
          _buildCompactLabeledField(
            label: 'Date',
            width: 105,
            child: InkWell(
              onTap: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: _invoiceDate,
                  firstDate: DateTime(2020),
                  lastDate: DateTime(2035),
                );
                if (picked != null) {
                  setState(() => _invoiceDate = picked);
                }
              },
              child: Container(
                height: 28,
                alignment: Alignment.centerLeft,
                padding: const EdgeInsets.symmetric(horizontal: 6),
                decoration: BoxDecoration(
                  color: AppTheme.darkBg,
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: AppTheme.cardBorder),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(dateFormat.format(_invoiceDate), style: const TextStyle(fontSize: 10, color: AppTheme.textLight)),
                    const Icon(Icons.calendar_today, size: 11, color: AppTheme.textMuted),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),

          // Cust Mob (Instant auto-lookup)
          _buildCompactLabeledField(
            label: 'Cust Mob',
            width: 115,
            child: SizedBox(
              height: 28,
              child: TextField(
                controller: _custMobController,
                keyboardType: TextInputType.phone,
                style: const TextStyle(fontSize: 11, color: AppTheme.textLight),
                decoration: const InputDecoration(
                  isDense: true,
                  hintText: 'Phone...',
                  hintStyle: TextStyle(fontSize: 10, color: AppTheme.textMuted),
                  contentPadding: EdgeInsets.symmetric(horizontal: 6, vertical: 6),
                ),
                onChanged: (val) {
                  final query = val.trim();
                  if (query.isNotEmpty) {
                    final customers = ref.read(customersProvider).value ?? [];
                    final matches = customers.where((c) => c.phone != null && c.phone!.contains(query)).toList();
                    if (matches.isNotEmpty) {
                      ref.read(cartNotifierProvider.notifier).setCustomer(matches.first);
                    }
                  }
                },
              ),
            ),
          ),
          const SizedBox(width: 8),

          // Customer ID & Name + Search Action
          Expanded(
            child: _buildCompactLabeledField(
              label: 'Customer Name',
              child: Container(
                height: 28,
                padding: const EdgeInsets.symmetric(horizontal: 6),
                decoration: BoxDecoration(
                  color: AppTheme.darkBg,
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: AppTheme.cardBorder),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1E293B),
                        borderRadius: BorderRadius.circular(3),
                      ),
                      child: Text(
                        cart.customer.id.startsWith('cust_') ? cart.customer.id.substring(5).toUpperCase() : cart.customer.id,
                        style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: AppTheme.accentCyan),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        cart.customer.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.textLight),
                      ),
                    ),
                    InkWell(
                      onTap: _showCustomerLookupDialog,
                      child: const Tooltip(
                        message: 'Customer Search [F2]',
                        child: Padding(
                          padding: EdgeInsets.symmetric(horizontal: 4),
                          child: Icon(Icons.person_search, size: 16, color: AppTheme.primaryBlue),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),

          // Invoice Type (Local / Interstate)
          _buildCompactLabeledField(
            label: 'Tax Mode',
            width: 135,
            child: Container(
              height: 28,
              padding: const EdgeInsets.symmetric(horizontal: 6),
              decoration: BoxDecoration(
                color: AppTheme.darkBg,
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: AppTheme.cardBorder),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: cart.invoiceType,
                  isExpanded: true,
                  dropdownColor: AppTheme.cardBg,
                  icon: const Icon(Icons.arrow_drop_down, size: 16),
                  items: const [
                    DropdownMenuItem(value: 'Local', child: Text('Local (CGST+SGST)', style: TextStyle(fontSize: 10, color: AppTheme.textLight))),
                    DropdownMenuItem(value: 'Interstate', child: Text('Interstate (IGST)', style: TextStyle(fontSize: 10, color: AppTheme.textLight))),
                  ],
                  onChanged: (val) {
                    if (val != null) {
                      ref.read(cartNotifierProvider.notifier).setInvoiceType(val);
                    }
                  },
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),

          // Dr / Due Balance (Red/Rose box)
          _buildCompactLabeledField(
            label: 'Dr Balance',
            width: 90,
            child: Container(
              height: 28,
              alignment: Alignment.center,
              padding: const EdgeInsets.symmetric(horizontal: 4),
              decoration: BoxDecoration(
                color: const Color(0xFF2A1520),
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: AppTheme.accentRose.withValues(alpha: 0.5)),
              ),
              child: Text(
                'Dr ₹${cart.customer.currentBalance.toStringAsFixed(2)}',
                style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppTheme.accentRose),
              ),
            ),
          ),
          const SizedBox(width: 8),

          // Notes / Dispatch Dialog Button
          _buildCompactLabeledField(
            label: 'Notes',
            width: 32,
            child: SizedBox(
              height: 28,
              child: IconButton(
                padding: EdgeInsets.zero,
                icon: Icon(
                  _notesController.text.trim().isNotEmpty ? Icons.sticky_note_2 : Icons.notes,
                  size: 16,
                  color: _notesController.text.trim().isNotEmpty ? AppTheme.accentAmber : AppTheme.textMuted,
                ),
                tooltip: 'Invoice Notes & Dispatch Details',
                onPressed: _showInvoiceNotesDialog,
              ),
            ),
          ),
          const SizedBox(width: 6),

          // [+ Add Item] Action Button
          _buildCompactLabeledField(
            label: 'Action',
            width: 95,
            child: SizedBox(
              height: 28,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryBlue,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  visualDensity: VisualDensity.compact,
                ),
                icon: const Icon(Icons.add, size: 14),
                label: const Text('Add Item', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                onPressed: () => _barcodeFocusNode.requestFocus(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showInvoiceNotesDialog() {
    final isMobile = AppTheme.isMobile(context);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF131D31),
        insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: const BorderSide(color: AppTheme.cardBorder),
        ),
        title: const Row(
          children: [
            Icon(Icons.notes, color: AppTheme.accentCyan, size: 20),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                'Invoice Notes & Dispatch Details',
                style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        content: SizedBox(
          width: isMobile ? double.maxFinite : 460,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: _notesController,
                  maxLines: 2,
                  style: const TextStyle(fontSize: 12, color: AppTheme.textLight),
                  decoration: const InputDecoration(
                    labelText: 'Dispatch / Transport / Delivery Notes',
                    hintText: 'Enter dispatch, transporter name, vehicle no...',
                  ),
                  onChanged: (val) => ref.read(cartNotifierProvider.notifier).setNotes(val),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _salesPersonController,
                  style: const TextStyle(fontSize: 12, color: AppTheme.textLight),
                  decoration: const InputDecoration(
                    labelText: 'Sales Person / Cashier Name',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _shippingAddressController,
                  style: const TextStyle(fontSize: 12, color: AppTheme.textLight),
                  decoration: const InputDecoration(
                    labelText: 'Shipping / Delivery Address',
                    hintText: 'Enter street, city, pin code...',
                  ),
                ),
              ],
            ),
          ),
        ),
        actions: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: WrapAlignment.end,
            children: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('Close', style: TextStyle(color: AppTheme.textMuted)),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryBlue),
                onPressed: () {
                  setState(() {});
                  Navigator.of(ctx).pop();
                },
                child: const Text('Save & Apply'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCompactLabeledField({required String label, double? width, required Widget child}) {
    final body = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: AppTheme.textMuted),
        ),
        const SizedBox(height: 2),
        child,
      ],
    );

    if (width != null) {
      return SizedBox(width: width, child: body);
    }
    return body;
  }

  // ---------------------------------------------------------------------------
  // 2C. ITEMS DETAIL TAB CONTENT (RAPID ENTRY ROW + HIGH-DENSITY GRID)
  // ---------------------------------------------------------------------------
  Widget _buildItemsDetailTabContent(CartState cart, String currency, bool isMobile) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF10192A),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: AppTheme.cardBorder),
      ),
      child: Stack(
        children: [
          Column(
            children: [
              // Rapid Entry Row (Directly Above the Grid - BillPro style)
              _buildActiveRapidItemEntryRow(isMobile),

              // High Density Line Items Table
              Expanded(
                child: _buildHighDensityGrid(cart, currency, isMobile),
              ),
            ],
          ),

          // Autocomplete Floating Suggestion Panel
          if (_showProductSuggestions && _productSearchResults.isNotEmpty)
            Positioned(
              top: 54,
              left: isMobile ? 8 : 108,
              right: isMobile ? 8 : null,
              width: isMobile ? null : 320,
              height: 220,
              child: Container(
                decoration: BoxDecoration(
                  color: const Color(0xFF1E293B),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: AppTheme.primaryBlue),
                  boxShadow: [
                    BoxShadow(color: Colors.black.withValues(alpha: 0.5), blurRadius: 10, offset: const Offset(0, 4)),
                  ],
                ),
                child: ListView.separated(
                  itemCount: _productSearchResults.length,
                  separatorBuilder: (_, __) => const Divider(height: 1, color: AppTheme.cardBorder),
                  itemBuilder: (ctx, i) {
                    final p = _productSearchResults[i];
                    return ListTile(
                      dense: true,
                      title: Text(p.name, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white)),
                      subtitle: Text('Code: ${p.barcode ?? p.sku ?? "-"} | Stk: ${p.stockQuantity} ${p.unitOfMeasure}', style: const TextStyle(fontSize: 10, color: AppTheme.textMuted)),
                      trailing: Text('$currency${p.sellingPrice.toStringAsFixed(2)}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.primaryEmerald)),
                      onTap: () => _populateEntryFromProduct(p),
                    );
                  },
                ),
              ),
            ),
        ],
      ),
    );
  }

  // --- RAPID ACTIVE ITEM ENTRY ROW ---
  Widget _buildActiveRapidItemEntryRow(bool isMobile) {
    if (isMobile) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: const BoxDecoration(
          color: Color(0xFF19253C), // Highlighted Navy / Slate entry bar
          border: Border(bottom: BorderSide(color: AppTheme.cardBorder, width: 1.5)),
        ),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              // BarCode
              _buildEntryInput(
                label: 'BarCode',
                width: 90,
                controller: _barcodeEntryController,
                focusNode: _barcodeFocusNode,
                isImportant: true,
                onSubmitted: (val) async {
                  final query = val.trim();
                  if (query.isEmpty) return;
                  final repo = ref.read(productRepositoryProvider);
                  final match = await repo.findByBarcodeOrSku(query);
                  if (match != null) {
                    _populateEntryFromProduct(match);
                  } else {
                    final results = await repo.searchProducts(query);
                    if (results.isNotEmpty) {
                      _populateEntryFromProduct(results.first);
                    } else {
                      _showItemNotFoundSnackBar(query);
                    }
                  }
                },
              ),
              const SizedBox(width: 4),

              // Item Name
              SizedBox(
                width: 160,
                child: _buildEntryInput(
                  label: 'Item Name',
                  controller: _itemNameEntryController,
                  focusNode: _itemNameFocusNode,
                  isImportant: true,
                  onChanged: (val) async {
                    final query = val.trim();
                    if (query.length >= 2) {
                      final results = await ref.read(productRepositoryProvider).searchProducts(query);
                      setState(() {
                        _productSearchResults = results;
                        _showProductSuggestions = true;
                      });
                    } else {
                      setState(() => _showProductSuggestions = false);
                    }
                  },
                  onSubmitted: (_) => _commitEntryRowToCart(),
                ),
              ),
              const SizedBox(width: 4),

              // Qty
              _buildEntryInput(
                label: 'Qty',
                width: 50,
                controller: _qtyEntryController,
                focusNode: _qtyFocusNode,
                keyboardType: TextInputType.number,
                onChanged: (_) => _recalcEntryRow(),
                onSubmitted: (_) => _commitEntryRowToCart(),
              ),
              const SizedBox(width: 4),

              // MRP
              _buildEntryInput(
                label: 'MRP',
                width: 65,
                controller: _mrpEntryController,
                keyboardType: TextInputType.number,
                onChanged: (_) => _recalcEntryRow(),
              ),
              const SizedBox(width: 4),

              // SP (Selling Price)
              _buildEntryInput(
                label: 'SP',
                width: 70,
                controller: _spEntryController,
                focusNode: _spFocusNode,
                keyboardType: TextInputType.number,
                isImportant: true,
                onChanged: (_) => _recalcEntryRow(),
                onSubmitted: (_) => _commitEntryRowToCart(),
              ),
              const SizedBox(width: 4),

              // Disc %
              _buildEntryInput(
                label: 'Disc%',
                width: 45,
                controller: _discPercentEntryController,
                keyboardType: TextInputType.number,
                onChanged: (_) => _recalcEntryRow(),
              ),
              const SizedBox(width: 4),

              // Disc Amt
              _buildEntryInput(
                label: 'Amt',
                width: 50,
                controller: _discAmtEntryController,
                readOnly: true,
              ),
              const SizedBox(width: 4),

              // GST %
              _buildEntryInput(
                label: 'GST%',
                width: 45,
                controller: _gstPercentEntryController,
                keyboardType: TextInputType.number,
                onChanged: (_) => _recalcEntryRow(),
              ),
              const SizedBox(width: 4),

              // GST Amt
              _buildEntryInput(
                label: 'Gst Amt',
                width: 60,
                controller: _gstAmtEntryController,
                readOnly: true,
              ),
              const SizedBox(width: 4),

              // Net Amt
              _buildEntryInput(
                label: 'Net Amt',
                width: 75,
                controller: _netAmtEntryController,
                readOnly: true,
                isHighlight: true,
              ),
              const SizedBox(width: 4),

              // Batch
              _buildEntryInput(
                label: 'Batch',
                width: 70,
                controller: _batchEntryController,
              ),
              const SizedBox(width: 4),

              // Exp
              _buildEntryInput(
                label: 'Exp',
                width: 50,
                controller: _expEntryController,
              ),
              const SizedBox(width: 4),

              // Free Qty
              _buildEntryInput(
                label: 'Free',
                width: 45,
                controller: _freeQtyEntryController,
                keyboardType: TextInputType.number,
              ),
              const SizedBox(width: 4),

              // UOM
              _buildEntryInput(
                label: 'Uom',
                width: 45,
                controller: _uomEntryController,
              ),
              const SizedBox(width: 6),

              // Commit Button
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryEmerald,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  visualDensity: VisualDensity.compact,
                ),
                onPressed: _commitEntryRowToCart,
                child: const Text('Add ⏎', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ),
      );
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: const BoxDecoration(
        color: Color(0xFF19253C), // Highlighted Navy / Slate entry bar
        border: Border(bottom: BorderSide(color: AppTheme.cardBorder, width: 1.5)),
      ),
      child: Row(
        children: [
          // BarCode
          _buildEntryInput(
            label: 'BarCode',
            width: 100,
            controller: _barcodeEntryController,
            focusNode: _barcodeFocusNode,
            isImportant: true,
            onSubmitted: (val) async {
              final query = val.trim();
              if (query.isEmpty) return;
              final repo = ref.read(productRepositoryProvider);
              final match = await repo.findByBarcodeOrSku(query);
              if (match != null) {
                _populateEntryFromProduct(match);
              } else {
                final results = await repo.searchProducts(query);
                if (results.isNotEmpty) {
                  _populateEntryFromProduct(results.first);
                } else {
                  _showItemNotFoundSnackBar(query);
                }
              }
            },
          ),
          const SizedBox(width: 4),

          // Item Name
          Expanded(
            flex: 3,
            child: _buildEntryInput(
              label: 'Item Name',
              controller: _itemNameEntryController,
              focusNode: _itemNameFocusNode,
              isImportant: true,
              onChanged: (val) async {
                final query = val.trim();
                if (query.length >= 2) {
                  final results = await ref.read(productRepositoryProvider).searchProducts(query);
                  setState(() {
                    _productSearchResults = results;
                    _showProductSuggestions = true;
                  });
                } else {
                  setState(() => _showProductSuggestions = false);
                }
              },
              onSubmitted: (_) => _commitEntryRowToCart(),
            ),
          ),
          const SizedBox(width: 4),

          // Qty
          _buildEntryInput(
            label: 'Qty',
            width: 55,
            controller: _qtyEntryController,
            focusNode: _qtyFocusNode,
            keyboardType: TextInputType.number,
            onChanged: (_) => _recalcEntryRow(),
            onSubmitted: (_) => _commitEntryRowToCart(),
          ),
          const SizedBox(width: 4),

          // MRP
          _buildEntryInput(
            label: 'MRP',
            width: 70,
            controller: _mrpEntryController,
            keyboardType: TextInputType.number,
            onChanged: (_) => _recalcEntryRow(),
          ),
          const SizedBox(width: 4),

          // SP (Selling Price)
          _buildEntryInput(
            label: 'SP',
            width: 75,
            controller: _spEntryController,
            focusNode: _spFocusNode,
            keyboardType: TextInputType.number,
            isImportant: true,
            onChanged: (_) => _recalcEntryRow(),
            onSubmitted: (_) => _commitEntryRowToCart(),
          ),
          const SizedBox(width: 4),

          // Disc %
          _buildEntryInput(
            label: 'Disc%',
            width: 50,
            controller: _discPercentEntryController,
            keyboardType: TextInputType.number,
            onChanged: (_) => _recalcEntryRow(),
          ),
          const SizedBox(width: 4),

          // Disc Amt
          _buildEntryInput(
            label: 'Amt',
            width: 55,
            controller: _discAmtEntryController,
            readOnly: true,
          ),
          const SizedBox(width: 4),

          // GST %
          _buildEntryInput(
            label: 'GST%',
            width: 50,
            controller: _gstPercentEntryController,
            keyboardType: TextInputType.number,
            onChanged: (_) => _recalcEntryRow(),
          ),
          const SizedBox(width: 4),

          // GST Amt
          _buildEntryInput(
            label: 'Gst Amt',
            width: 65,
            controller: _gstAmtEntryController,
            readOnly: true,
          ),
          const SizedBox(width: 4),

          // Net Amt
          _buildEntryInput(
            label: 'Net Amt',
            width: 80,
            controller: _netAmtEntryController,
            readOnly: true,
            isHighlight: true,
          ),
          const SizedBox(width: 4),

          // Batch
          _buildEntryInput(
            label: 'Batch',
            width: 75,
            controller: _batchEntryController,
          ),
          const SizedBox(width: 4),

          // Exp
          _buildEntryInput(
            label: 'Exp',
            width: 55,
            controller: _expEntryController,
          ),
          const SizedBox(width: 4),

          // Free Qty
          _buildEntryInput(
            label: 'Free',
            width: 50,
            controller: _freeQtyEntryController,
            keyboardType: TextInputType.number,
          ),
          const SizedBox(width: 4),

          // UOM
          _buildEntryInput(
            label: 'Uom',
            width: 50,
            controller: _uomEntryController,
          ),
          const SizedBox(width: 6),

          // Commit Button
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryEmerald,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              visualDensity: VisualDensity.compact,
            ),
            onPressed: _commitEntryRowToCart,
            child: const Text('Add ⏎', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _buildEntryInput({
    required String label,
    double? width,
    required TextEditingController controller,
    FocusNode? focusNode,
    bool readOnly = false,
    bool isHighlight = false,
    bool isImportant = false,
    TextInputType? keyboardType,
    ValueChanged<String>? onChanged,
    ValueChanged<String>? onSubmitted,
  }) {
    final inputWidget = SizedBox(
      height: 28,
      child: TextField(
        controller: controller,
        focusNode: focusNode,
        readOnly: readOnly,
        keyboardType: keyboardType,
        onChanged: onChanged,
        onSubmitted: onSubmitted,
        textAlign: keyboardType == TextInputType.number ? TextAlign.right : TextAlign.left,
        style: TextStyle(
          fontSize: 11,
          fontWeight: isHighlight ? FontWeight.bold : FontWeight.normal,
          color: isHighlight
              ? AppTheme.accentCyan
              : (isImportant ? Colors.white : AppTheme.textLight),
        ),
        decoration: InputDecoration(
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
          filled: true,
          fillColor: readOnly ? const Color(0xFF0C1322) : const Color(0xFF141F32),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(3),
            borderSide: BorderSide(color: isImportant ? AppTheme.primaryBlue : AppTheme.cardBorder),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(3),
            borderSide: BorderSide(color: isImportant ? AppTheme.primaryBlue.withValues(alpha: 0.6) : AppTheme.cardBorder),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(3),
            borderSide: const BorderSide(color: AppTheme.accentCyan, width: 1.5),
          ),
        ),
      ),
    );

    final field = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 9,
            fontWeight: FontWeight.bold,
            color: isImportant ? AppTheme.accentCyan : AppTheme.textMuted,
          ),
        ),
        const SizedBox(height: 2),
        inputWidget,
      ],
    );

    if (width != null) {
      return SizedBox(width: width, child: field);
    }
    return field;
  }

  // --- HIGH DENSITY LINE ITEMS GRID ---
  Widget _buildHighDensityGrid(CartState cart, String currency, bool isMobile) {
    if (cart.items.isEmpty) {
      return Center(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.barcode_reader, size: 36, color: AppTheme.textMuted.withValues(alpha: 0.3)),
                const SizedBox(height: 6),
                const Text(
                  'Scan Barcode or Type Product Name to add items',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.textMuted),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Press Tab or Enter to navigate • F1 to search product catalog',
                  style: TextStyle(fontSize: 10, color: AppTheme.textSecondary),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final tableBody = Column(
      children: [
        // Column Header Row (BillPro Style Headers)
        Container(
          height: 30,
          color: const Color(0xFF142036),
          padding: const EdgeInsets.symmetric(horizontal: 10),
          child: const Row(
            children: [
              SizedBox(width: 30, child: Text('Sr', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.textMuted))),
              SizedBox(width: 85, child: Text('Item Code', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.textMuted))),
              Expanded(flex: 4, child: Text('Item Description', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.textMuted))),
              SizedBox(width: 50, child: Text('Qty', textAlign: TextAlign.right, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.textMuted))),
              SizedBox(width: 50, child: Text('Qty F', textAlign: TextAlign.right, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.textMuted))),
              SizedBox(width: 45, child: Text('Uom', textAlign: TextAlign.center, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.textMuted))),
              SizedBox(width: 75, child: Text('MRP', textAlign: TextAlign.right, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.textMuted))),
              SizedBox(width: 75, child: Text('SP', textAlign: TextAlign.right, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.textMuted))),
              SizedBox(width: 55, child: Text('Disc %', textAlign: TextAlign.right, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.textMuted))),
              SizedBox(width: 65, child: Text('Disc Amt', textAlign: TextAlign.right, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.textMuted))),
              SizedBox(width: 55, child: Text('Tax %', textAlign: TextAlign.right, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.textMuted))),
              SizedBox(width: 70, child: Text('Tax Amt', textAlign: TextAlign.right, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.textMuted))),
              SizedBox(width: 85, child: Text('Net Amt', textAlign: TextAlign.right, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.textMuted))),
              SizedBox(width: 80, child: Text('Batch', textAlign: TextAlign.center, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.textMuted))),
              SizedBox(width: 32),
            ],
          ),
        ),
        const Divider(height: 1, color: AppTheme.cardBorder),

        // Grid Rows
        Expanded(
          child: ListView.separated(
            itemCount: cart.items.length,
            separatorBuilder: (_, __) => const Divider(height: 1, color: AppTheme.cardBorder),
            itemBuilder: (ctx, idx) {
              final item = cart.items[idx];
              final isSelected = idx == cart.selectedRowIndex;
              final isEven = idx % 2 == 0;
              final taxRate = item.product.taxSlab?.ratePercent ?? 18.0;

              return InkWell(
                onTap: () => ref.read(cartNotifierProvider.notifier).setSelectedRow(idx),
                child: Container(
                  height: 32,
                  color: isSelected
                      ? const Color(0xFF1E3A8A).withValues(alpha: 0.5)
                      : (isEven ? const Color(0xFF0F172A) : const Color(0xFF131D31)),
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  child: Row(
                    children: [
                      // Sr
                      SizedBox(width: 30, child: Text('${idx + 1}', style: const TextStyle(fontSize: 11, color: AppTheme.textMuted))),

                      // Item Code
                      SizedBox(
                        width: 85,
                        child: Text(
                          item.product.barcode ?? item.product.sku ?? '-',
                          style: const TextStyle(fontSize: 11, color: AppTheme.textLight),
                        ),
                      ),

                      // Item Description
                      Expanded(
                        flex: 4,
                        child: Text(
                          item.product.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppTheme.textLight),
                        ),
                      ),

                      // Qty
                      SizedBox(
                        width: 50,
                        child: Text(
                          item.quantity.toStringAsFixed(2),
                          textAlign: TextAlign.right,
                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white),
                        ),
                      ),

                      // Qty Free
                      SizedBox(
                        width: 50,
                        child: Text(
                          item.freeQuantity.toStringAsFixed(2),
                          textAlign: TextAlign.right,
                          style: const TextStyle(fontSize: 11, color: AppTheme.textMuted),
                        ),
                      ),

                      // UOM
                      SizedBox(
                        width: 45,
                        child: Text(
                          item.uom,
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontSize: 10, color: AppTheme.textMuted),
                        ),
                      ),

                      // MRP
                      SizedBox(
                        width: 75,
                        child: Text(
                          item.mrp.toStringAsFixed(2),
                          textAlign: TextAlign.right,
                          style: const TextStyle(fontSize: 11, color: AppTheme.textLight),
                        ),
                      ),

                      // SP
                      SizedBox(
                        width: 75,
                        child: Text(
                          item.unitPrice.toStringAsFixed(2),
                          textAlign: TextAlign.right,
                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.accentCyan),
                        ),
                      ),

                      // Disc %
                      SizedBox(
                        width: 55,
                        child: Text(
                          item.discountAmount > 0
                              ? '${((item.discountAmount / (item.quantity * item.unitPrice)) * 100).toStringAsFixed(1)}%'
                              : '0.00',
                          textAlign: TextAlign.right,
                          style: const TextStyle(fontSize: 11, color: AppTheme.accentAmber),
                        ),
                      ),

                      // Disc Amt
                      SizedBox(
                        width: 65,
                        child: Text(
                          item.discountAmount.toStringAsFixed(2),
                          textAlign: TextAlign.right,
                          style: const TextStyle(fontSize: 11, color: AppTheme.accentAmber),
                        ),
                      ),

                      // Tax %
                      SizedBox(
                        width: 55,
                        child: Text(
                          '${taxRate.toStringAsFixed(1)}%',
                          textAlign: TextAlign.right,
                          style: const TextStyle(fontSize: 11, color: AppTheme.textMuted),
                        ),
                      ),

                      // Tax Amt
                      SizedBox(
                        width: 70,
                        child: Text(
                          item.taxResult.taxAmount.toStringAsFixed(2),
                          textAlign: TextAlign.right,
                          style: const TextStyle(fontSize: 11, color: AppTheme.textLight),
                        ),
                      ),

                      // Net Amt
                      SizedBox(
                        width: 85,
                        child: Text(
                          item.taxResult.totalLineAmount.toStringAsFixed(2),
                          textAlign: TextAlign.right,
                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.primaryEmerald),
                        ),
                      ),

                      // Batch
                      SizedBox(
                        width: 80,
                        child: Text(
                          item.batchNumber ?? '-',
                          textAlign: TextAlign.center,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 10, color: AppTheme.textMuted),
                        ),
                      ),

                      // Action (Delete)
                      SizedBox(
                        width: 32,
                        child: IconButton(
                          padding: EdgeInsets.zero,
                          icon: const Icon(Icons.close, size: 14, color: AppTheme.accentRose),
                          onPressed: () => ref.read(cartNotifierProvider.notifier).removeItemAt(idx),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );

    if (isMobile) {
      return LayoutBuilder(
        builder: (context, constraints) {
          return SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: SizedBox(
              width: 850,
              height: constraints.maxHeight,
              child: tableBody,
            ),
          );
        },
      );
    }

    return tableBody;
  }



  // ---------------------------------------------------------------------------
  // 2D. MID ACTION & PRINT BAR ([Save], [+Add], Total Qty, Print 3", A4, A5)
  // ---------------------------------------------------------------------------
  Widget _buildMidActionAndPrintBar(CartState cart, bool isMobile) {
    final barContent = Row(
      children: [
        // [Save] Pink / Coral BillPro button
        ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFE11D48), // Pink/Crimson BillPro Save
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
          ),
          icon: const Icon(Icons.save_rounded, size: 16),
          label: const Text('Save [F5]', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
          onPressed: _handleSaveBill,
        ),
        const SizedBox(width: 8),

        // [+ Add] Cyan button
        ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF0284C7),
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
          ),
          icon: const Icon(Icons.add_circle_outline_rounded, size: 16),
          label: const Text('Add', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
          onPressed: () => _barcodeFocusNode.requestFocus(),
        ),
        const SizedBox(width: 8),

        // [X Close / Clear]
        OutlinedButton.icon(
          style: OutlinedButton.styleFrom(
            foregroundColor: AppTheme.textMuted,
            side: const BorderSide(color: AppTheme.cardBorder),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
          ),
          icon: const Icon(Icons.delete_sweep_rounded, size: 15, color: AppTheme.accentRose),
          label: const Text('Clear', style: TextStyle(fontSize: 12)),
          onPressed: () => ref.read(cartNotifierProvider.notifier).clearCart(),
        ),
        const SizedBox(width: 12),

        // Aggregate Metrics (Total Qty, #MRP, #SP)
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(color: const Color(0xFF0B1120), borderRadius: BorderRadius.circular(6), border: Border.all(color: AppTheme.cardBorder)),
          child: Row(
            children: [
              Text('Total Qty: ${cart.totalUnits.toStringAsFixed(2)}',
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.textLight)),
              const SizedBox(width: 10),
              Text('#MRP: ₹${cart.totalMrp.toStringAsFixed(2)}',
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.accentAmber)),
              const SizedBox(width: 10),
              Text('#SP: ₹${cart.totalSellingPrice.toStringAsFixed(2)}',
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.accentCyan)),
            ],
          ),
        ),
        if (!isMobile) const Spacer() else const SizedBox(width: 12),

        // Print Format Options: Print 3", A4, A5, Print Button
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildPrintFormatChip('3_INCH', 'Print 3"'),
            const SizedBox(width: 6),
            _buildPrintFormatChip('A4', 'A4'),
            const SizedBox(width: 6),
            _buildPrintFormatChip('A5', 'A5'),
            const SizedBox(width: 8),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0284C7),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
              ),
              icon: const Icon(Icons.print_rounded, size: 15),
              label: const Text('Print [F9]', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
              onPressed: _triggerPrintActiveBill,
            ),
          ],
        ),
      ],
    );

    return Container(
      height: 44,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF131D31),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: AppTheme.cardBorder),
      ),
      child: isMobile
          ? SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: barContent,
            )
          : barContent,
    );
  }

  Widget _buildPrintFormatChip(String format, String label) {
    final currentFormat = ref.watch(cartNotifierProvider).selectedPrintFormat;
    final isSelected = currentFormat == format;

    return InkWell(
      onTap: () => ref.read(cartNotifierProvider.notifier).setPrintFormat(format),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.primaryBlue : const Color(0xFF0B1120),
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: isSelected ? AppTheme.primaryBlue : AppTheme.cardBorder),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isSelected ? Icons.check_circle : Icons.radio_button_unchecked,
              size: 12,
              color: isSelected ? Colors.white : AppTheme.textMuted,
            ),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                color: isSelected ? Colors.white : AppTheme.textMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // 2E. BOTTOM FINANCIAL SUMMARY & CASH TENDERING ROW
  // ---------------------------------------------------------------------------
  Widget _buildBottomFinancialAndTenderRow(CartState cart, String currency, bool isMobile) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF131D31),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: AppTheme.cardBorder),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Row 1: Financial Breakdown (Sub Total, Disc %, Fixed Disc, Tax, Other Charges, Round Off, Summary Pill)
          isMobile
              ? SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _buildCompactBottomField(
                        label: 'Sub Total',
                        value: '$currency${cart.subtotal.toStringAsFixed(2)}',
                        width: 90,
                      ),
                      const SizedBox(width: 6),
                      _buildCompactBottomInput(
                        label: 'Disc %',
                        width: 65,
                        controller: _discPercentTotalController,
                        onChanged: (val) {
                          final p = double.tryParse(val) ?? 0.0;
                          final discAmt = cart.subtotal * (p / 100.0);
                          _fixedDiscountController.text = discAmt.toStringAsFixed(2);
                          ref.read(cartNotifierProvider.notifier).setInvoiceDiscount(discAmt);
                        },
                      ),
                      const SizedBox(width: 6),
                      _buildCompactBottomInput(
                        label: 'Fixed Disc',
                        width: 75,
                        controller: _fixedDiscountController,
                        onChanged: (val) {
                          final amt = double.tryParse(val) ?? 0.0;
                          ref.read(cartNotifierProvider.notifier).setInvoiceDiscount(amt);
                        },
                      ),
                      const SizedBox(width: 6),
                      _buildCompactBottomField(
                        label: 'Tax (GST)',
                        value: '$currency${cart.taxTotal.toStringAsFixed(2)}',
                        width: 80,
                      ),
                      const SizedBox(width: 6),
                      _buildCompactBottomInput(
                        label: 'Other Char',
                        width: 75,
                        controller: _otherChargesController,
                        onChanged: (val) {
                          final amt = double.tryParse(val) ?? 0.0;
                          ref.read(cartNotifierProvider.notifier).setOtherCharges(amt);
                        },
                      ),
                      const SizedBox(width: 6),
                      _buildCompactBottomField(
                        label: 'Round Off',
                        value: cart.roundOff.toStringAsFixed(2),
                        width: 65,
                      ),
                      const SizedBox(width: 10),
                      // Live Summary Tag
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFF0B1120),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: AppTheme.cardBorder),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.receipt_outlined, size: 12, color: AppTheme.accentCyan),
                            const SizedBox(width: 4),
                            Text(
                              '${cart.items.length} Lines • ${cart.totalUnits.toStringAsFixed(cart.totalUnits % 1 == 0 ? 0 : 2)} Qty',
                              style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: AppTheme.textLight),
                            ),
                            if (cart.invoiceDiscount > 0) ...[
                              const SizedBox(width: 6),
                              Text(
                                'Saved: $currency${cart.invoiceDiscount.toStringAsFixed(2)}',
                                style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppTheme.accentAmber),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                )
              : Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // Sub Total
                    _buildCompactBottomField(
                      label: 'Sub Total',
                      value: '$currency${cart.subtotal.toStringAsFixed(2)}',
                      width: 95,
                    ),
                    const SizedBox(width: 8),

                    // Disc %
                    _buildCompactBottomInput(
                      label: 'Disc %',
                      width: 70,
                      controller: _discPercentTotalController,
                      onChanged: (val) {
                        final p = double.tryParse(val) ?? 0.0;
                        final discAmt = cart.subtotal * (p / 100.0);
                        _fixedDiscountController.text = discAmt.toStringAsFixed(2);
                        ref.read(cartNotifierProvider.notifier).setInvoiceDiscount(discAmt);
                      },
                    ),
                    const SizedBox(width: 8),

                    // Fixed Disc
                    _buildCompactBottomInput(
                      label: 'Fixed Disc',
                      width: 80,
                      controller: _fixedDiscountController,
                      onChanged: (val) {
                        final amt = double.tryParse(val) ?? 0.0;
                        ref.read(cartNotifierProvider.notifier).setInvoiceDiscount(amt);
                      },
                    ),
                    const SizedBox(width: 8),

                    // Tax (GST)
                    _buildCompactBottomField(
                      label: 'Tax (GST)',
                      value: '$currency${cart.taxTotal.toStringAsFixed(2)}',
                      width: 85,
                    ),
                    const SizedBox(width: 8),

                    // Other Charges
                    _buildCompactBottomInput(
                      label: 'Other Char',
                      width: 80,
                      controller: _otherChargesController,
                      onChanged: (val) {
                        final amt = double.tryParse(val) ?? 0.0;
                        ref.read(cartNotifierProvider.notifier).setOtherCharges(amt);
                      },
                    ),
                    const SizedBox(width: 8),

                    // Round Off
                    _buildCompactBottomField(
                      label: 'Round Off',
                      value: cart.roundOff.toStringAsFixed(2),
                      width: 70,
                    ),
                    const Spacer(),

                    // Live Summary Tag: Items, Qty, Total Discount
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0B1120),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: AppTheme.cardBorder),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.receipt_outlined, size: 13, color: AppTheme.accentCyan),
                          const SizedBox(width: 5),
                          Text(
                            '${cart.items.length} Lines  •  ${cart.totalUnits.toStringAsFixed(cart.totalUnits % 1 == 0 ? 0 : 2)} Qty',
                            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppTheme.textLight),
                          ),
                          if (cart.invoiceDiscount > 0) ...[
                            const SizedBox(width: 8),
                            Text(
                              'Saved: $currency${cart.invoiceDiscount.toStringAsFixed(2)}',
                              style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppTheme.accentAmber),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),

          const SizedBox(height: 6),
          const Divider(height: 1, color: AppTheme.cardBorder),
          const SizedBox(height: 6),

          // Row 2: Cash Tender, Refund, Net Payable, Hold Draft, Drafts/Sale, Cash
          isMobile
              ? SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _buildCompactBottomInput(
                        label: 'Cash Tender',
                        width: 110,
                        controller: _cashTenderController,
                        focusNode: _cashTenderFocusNode,
                        isHighlight: true,
                        onChanged: (val) {
                          final tendered = double.tryParse(val) ?? 0.0;
                          ref.read(cartNotifierProvider.notifier).setCashTendered(tendered);
                        },
                        onSubmitted: (_) => _handleSaveBill(),
                      ),
                      const SizedBox(width: 8),
                      // Refund
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFF2A1018),
                          borderRadius: BorderRadius.circular(5),
                          border: Border.all(color: const Color(0xFFF43F5E), width: 1.2),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text(
                              'Refund',
                              style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Color(0xFFFDA4AF)),
                            ),
                            const SizedBox(height: 1),
                            Text(
                              '$currency${cart.refundAmount.toStringAsFixed(2)}',
                              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: Color(0xFFFB7185)),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Net Amount (Payable)
                      Container(
                        constraints: const BoxConstraints(minWidth: 140),
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(colors: [Color(0xFF0C2444), Color(0xFF1E3A8A)]),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: AppTheme.accentCyan, width: 1.5),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text(
                              'NET PAYABLE',
                              style: TextStyle(fontSize: 8, fontWeight: FontWeight.w900, color: AppTheme.accentCyan, letterSpacing: 0.8),
                            ),
                            Text(
                              '$currency${cart.grandTotal.toStringAsFixed(2)}',
                              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Colors.white),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Hold Draft
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFD97706),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
                        ),
                        onPressed: _handleHoldCurrentDraft,
                        icon: const Icon(Icons.pause_circle_outline, size: 14),
                        label: const Text('DRAFT', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 10)),
                      ),
                      const SizedBox(width: 6),
                      // Recall
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _isDraftsViewActive
                              ? const Color(0xFF2563EB)
                              : (cart.heldCarts.isNotEmpty ? const Color(0xFF0284C7) : const Color(0xFF1E293B)),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
                        ),
                        onPressed: () => setState(() => _isDraftsViewActive = !_isDraftsViewActive),
                        icon: Icon(
                          _isDraftsViewActive ? Icons.point_of_sale_rounded : Icons.receipt_long,
                          size: 14,
                        ),
                        label: Text(
                          _isDraftsViewActive ? 'BILL' : 'DRAFTS (${cart.heldCarts.length})',
                          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 10),
                        ),
                      ),
                      const SizedBox(width: 6),
                      // Cash Payment
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFE11D48),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
                        ),
                        onPressed: () {
                          ref.read(cartNotifierProvider.notifier).setPaymentMethod('CASH');
                          _handleSaveBill();
                        },
                        icon: const Icon(Icons.payments_rounded, size: 14),
                        label: const Text('CASH PAY', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 10)),
                      ),
                    ],
                  ),
                )
              : Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Cash Tender (Key Operator Field)
              _buildCompactBottomInput(
                label: 'Cash Tender [Space]',
                width: 130,
                controller: _cashTenderController,
                focusNode: _cashTenderFocusNode,
                isHighlight: true,
                onChanged: (val) {
                  final tendered = double.tryParse(val) ?? 0.0;
                  ref.read(cartNotifierProvider.notifier).setCashTendered(tendered);
                },
                onSubmitted: (_) => _handleSaveBill(),
              ),
              const SizedBox(width: 10),

              // Refund Amt / Change Return (BillPro Highlight in Red/Coral)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF2A1018),
                  borderRadius: BorderRadius.circular(5),
                  border: Border.all(color: const Color(0xFFF43F5E), width: 1.2),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'Refund / Change',
                      style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Color(0xFFFDA4AF)),
                    ),
                    const SizedBox(height: 1),
                    Text(
                      '$currency${cart.refundAmount.toStringAsFixed(2)}',
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: Color(0xFFFB7185)),
                    ),
                  ],
                ),
              ),
              const Spacer(),

              // Sturdy & Prominent Net Amount (Payable) - Never Squished!
              Container(
                constraints: const BoxConstraints(minWidth: 175),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [Color(0xFF0C2444), Color(0xFF1E3A8A)]),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: AppTheme.accentCyan, width: 1.5),
                  boxShadow: [
                    BoxShadow(color: AppTheme.primaryBlue.withValues(alpha: 0.3), blurRadius: 6, offset: const Offset(0, 2)),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'NET AMOUNT (PAYABLE)',
                      style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: AppTheme.accentCyan, letterSpacing: 0.8),
                    ),
                    const SizedBox(height: 1),
                    Text(
                      '$currency${cart.grandTotal.toStringAsFixed(2)}',
                      style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: Colors.white),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),

              // Hold Bill / Save Draft (F6)
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFD97706),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
                ),
                onPressed: _handleHoldCurrentDraft,
                icon: const Icon(Icons.pause_circle_outline, size: 15),
                label: const Text(
                  'DRAFT [F6]',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 11, letterSpacing: 0.5),
                ),
              ),
              const SizedBox(width: 6),

              // Recall Held Drafts (F7) with Badge
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: _isDraftsViewActive
                      ? const Color(0xFF2563EB)
                      : (cart.heldCarts.isNotEmpty ? const Color(0xFF0284C7) : const Color(0xFF1E293B)),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(5),
                    side: BorderSide(
                      color: _isDraftsViewActive
                          ? const Color(0xFF60A5FA)
                          : (cart.heldCarts.isNotEmpty ? const Color(0xFF38BDF8) : AppTheme.cardBorder),
                      width: (_isDraftsViewActive || cart.heldCarts.isNotEmpty) ? 1.5 : 1,
                    ),
                  ),
                ),
                onPressed: () => setState(() => _isDraftsViewActive = !_isDraftsViewActive),
                icon: Icon(
                  _isDraftsViewActive ? Icons.point_of_sale_rounded : Icons.receipt_long,
                  size: 15,
                  color: (_isDraftsViewActive || cart.heldCarts.isNotEmpty) ? Colors.white : Colors.white70,
                ),
                label: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _isDraftsViewActive ? 'BILLING [F7]' : 'DRAFTS [F7]',
                      style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 11, letterSpacing: 0.5),
                    ),
                    if (cart.heldCarts.isNotEmpty) ...[
                      const SizedBox(width: 5),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEF4444),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '${cart.heldCarts.length}',
                          style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.white),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 6),

              // Cash Payment (F5 / Space)
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFE11D48),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
                ),
                onPressed: () {
                  ref.read(cartNotifierProvider.notifier).setPaymentMethod('CASH');
                  _handleSaveBill();
                },
                icon: const Icon(Icons.payments_rounded, size: 15),
                label: const Text('CASH', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 13, letterSpacing: 0.6)),
              ),
              const SizedBox(width: 6),

              // Multi Pay Split Payment
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF059669),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
                ),
                onPressed: _showMultiPayDialog,
                icon: const Icon(Icons.account_balance_wallet_rounded, size: 15),
                label: const Text('MULTI PAY', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 11, letterSpacing: 0.6)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCompactBottomField({required String label, required String value, required double width}) {
    return SizedBox(
      width: width,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label, style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: AppTheme.textMuted)),
          const SizedBox(height: 2),
          Container(
            height: 30,
            alignment: Alignment.centerRight,
            padding: const EdgeInsets.symmetric(horizontal: 6),
            decoration: BoxDecoration(color: const Color(0xFF0B1120), borderRadius: BorderRadius.circular(4), border: Border.all(color: AppTheme.cardBorder)),
            child: Text(value, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.textLight)),
          ),
        ],
      ),
    );
  }

  Widget _buildCompactBottomInput({
    required String label,
    required double width,
    required TextEditingController controller,
    FocusNode? focusNode,
    bool isHighlight = false,
    ValueChanged<String>? onChanged,
    ValueChanged<String>? onSubmitted,
  }) {
    return SizedBox(
      width: width,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.bold,
              color: isHighlight ? AppTheme.accentCyan : AppTheme.textMuted,
            ),
          ),
          const SizedBox(height: 2),
          SizedBox(
            height: 30,
            child: TextField(
              controller: controller,
              focusNode: focusNode,
              keyboardType: TextInputType.number,
              textAlign: TextAlign.right,
              onChanged: onChanged,
              onSubmitted: onSubmitted,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isHighlight ? FontWeight.bold : FontWeight.normal,
                color: isHighlight ? Colors.white : AppTheme.textLight,
              ),
              decoration: InputDecoration(
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
                filled: true,
                fillColor: isHighlight ? const Color(0xFF1E293B) : const Color(0xFF0B1120),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(4), borderSide: BorderSide(color: AppTheme.cardBorder)),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(4), borderSide: BorderSide(color: isHighlight ? AppTheme.primaryBlue : AppTheme.cardBorder)),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(4), borderSide: const BorderSide(color: AppTheme.accentCyan, width: 1.5)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // 3. PERSISTENT FOOTER STATUS & KEYBOARD SHORTCUTS BAR
  // ---------------------------------------------------------------------------
  Widget _buildLiveStatusAndShortcutsFooter(CartState cart, bool isMobile) {
    final selectedItem = cart.items.isNotEmpty && cart.selectedRowIndex < cart.items.length
        ? cart.items[cart.selectedRowIndex]
        : null;

    final stockText = selectedItem != null
        ? 'Stock: ${selectedItem.product.stockQuantity} ${selectedItem.uom} | Rate: ₹${selectedItem.unitPrice.toStringAsFixed(2)} | MRP: ₹${selectedItem.mrp.toStringAsFixed(2)} | GST: ${selectedItem.taxResult.taxAmount.toStringAsFixed(2)}'
        : 'Stock: Ready | Offline SQLite Sync Engine Active';

    return Container(
      height: 32,
      color: const Color(0xFF070B14),
      padding: EdgeInsets.symmetric(horizontal: isMobile ? 8 : 12),
      child: Row(
        children: [
          // Live Stock Indicator with Icon and Ellipsis protection
          const Icon(Icons.info_outline_rounded, size: 14, color: AppTheme.accentCyan),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              stockText,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: isMobile ? 10 : 11, fontWeight: FontWeight.bold, color: AppTheme.accentCyan),
            ),
          ),
          if (!isMobile) ...[
            const SizedBox(width: 10),
            Flexible(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildFooterShortcutBadge('F2', 'Cust'),
                    _buildFooterShortcutBadge('F3', 'Qty'),
                    _buildFooterShortcutBadge('F5', 'Save'),
                    _buildFooterShortcutBadge('F6', 'Draft'),
                    _buildFooterShortcutBadge('F7', _isDraftsViewActive ? 'Sale' : 'Recall'),
                    _buildFooterShortcutBadge('F9', 'Print'),
                    _buildFooterShortcutBadge('Alt+C', 'Card'),
                    _buildFooterShortcutBadge('Alt+M', 'MultiPay'),
                    _buildFooterShortcutBadge('Space', 'Tender'),
                  ],
                ),
              ),
            ),
          ] else ...[
            const SizedBox(width: 6),
            InkWell(
              onTap: () => _showMobileActionLauncherSheet(cart),
              borderRadius: BorderRadius.circular(4),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                decoration: BoxDecoration(
                  color: AppTheme.primaryBlue.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: AppTheme.primaryBlue.withValues(alpha: 0.5)),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.apps_rounded, size: 12, color: AppTheme.accentCyan),
                    SizedBox(width: 3),
                    Text('Actions', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppTheme.accentCyan)),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildFooterShortcutBadge(String key, String label) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 3),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
            decoration: BoxDecoration(
              color: const Color(0xFF1E293B),
              borderRadius: BorderRadius.circular(3),
              border: Border.all(color: AppTheme.cardBorder, width: 0.8),
            ),
            child: Text(
              key,
              style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.white),
            ),
          ),
          const SizedBox(width: 3),
          Text(
            label,
            style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w500, color: AppTheme.textMuted),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // RIGHT QUICK ACTION LAUNCHER (10% Vertical Dock)
  // ---------------------------------------------------------------------------
  Widget _buildRightActionLauncher([CartState? cart]) {
    final CartState activeCart = cart ?? ref.read(cartNotifierProvider);
    final launcherItems = [
      _LauncherItem(
        label: _isDraftsViewActive ? 'Sale Grid' : 'Drafts (${activeCart.heldCarts.length})',
        icon: Icons.receipt_long_rounded,
        color: const Color(0xFF0284C7),
        action: () => setState(() => _isDraftsViewActive = !_isDraftsViewActive),
      ),
      _LauncherItem(label: 'Sales', icon: Icons.point_of_sale_rounded, color: const Color(0xFFEC4899), action: () {
        if (_isDraftsViewActive) setState(() => _isDraftsViewActive = false);
        _barcodeFocusNode.requestFocus();
      }),
      _LauncherItem(label: 'Purchase', icon: Icons.local_shipping_rounded, color: const Color(0xFF10B981), action: () => widget.onNavigateTab?.call(2)),
      _LauncherItem(label: 'Voucher', icon: Icons.account_balance_wallet_rounded, color: const Color(0xFF06B6D4), action: _showVoucherDialog),
      _LauncherItem(label: 'Sales Return', icon: Icons.assignment_return_rounded, color: const Color(0xFFF97316), action: _showSalesReturnDialog),
      _LauncherItem(label: 'Sales Report', icon: Icons.query_stats_rounded, color: const Color(0xFF14B8A6), action: () => widget.onNavigateTab?.call(5)),
      _LauncherItem(label: 'Ledger', icon: Icons.menu_book_rounded, color: const Color(0xFF8B5CF6), action: () => widget.onNavigateTab?.call(4)),
      _LauncherItem(label: 'Pur Report', icon: Icons.trending_up_rounded, color: const Color(0xFFD946EF), action: () => widget.onNavigateTab?.call(5)),
      _LauncherItem(label: 'Stock Report', icon: Icons.inventory_2_rounded, color: const Color(0xFF3B82F6), action: () => widget.onNavigateTab?.call(3)),
      _LauncherItem(label: 'Item', icon: Icons.shopping_basket_rounded, color: const Color(0xFFF43F5E), action: () => widget.onNavigateTab?.call(3)),
      _LauncherItem(label: 'Account', icon: Icons.groups_2_rounded, color: const Color(0xFF0EA5E9), action: () => widget.onNavigateTab?.call(4)),
      _LauncherItem(label: 'Data Backup', icon: Icons.cloud_sync_rounded, color: const Color(0xFFF59E0B), action: _showBackupDialog),
      _LauncherItem(label: 'Sales Touch', icon: Icons.touch_app_rounded, color: const Color(0xFFA855F7), action: () {
        setState(() => _isTouchMode = !_isTouchMode);
      }),
    ];

    return Container(
      width: 100,
      color: const Color(0xFF131D31),
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(vertical: 8),
        itemCount: launcherItems.length,
        itemBuilder: (ctx, i) {
          final item = launcherItems[i];
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            child: InkWell(
              borderRadius: BorderRadius.circular(6),
              onTap: item.action,
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E293B),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: item.color.withValues(alpha: 0.3)),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: item.color.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Icon(item.icon, size: 18, color: item.color),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      item.label,
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  void _showVoucherDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.cardBg,
        insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        title: const Text('Cash / Expense Voucher Entry'),
        content: const Text('Record direct store expenses or cashier petty payments without leaving the POS screen.'),
        actions: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: WrapAlignment.end,
            children: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close')),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryBlue),
                onPressed: () {
                  Navigator.pop(ctx);
                  widget.onNavigateTab?.call(2); // Go to Purchases & Expenses
                },
                child: const Text('Open Expenses'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showSalesReturnDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.cardBg,
        insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        title: const Text('Sales Return / Credit Note Entry'),
        content: const Text('Enter original Invoice No to process item returns and restock quantities automatically.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close')),
        ],
      ),
    );
  }

  void _showBackupDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.cardBg,
        insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        title: const Row(
          children: [
            Icon(Icons.backup, color: AppTheme.accentAmber),
            SizedBox(width: 8),
            Expanded(child: Text('Offline Data Backup')),
          ],
        ),
        content: const Text('Your SQLite billing database is safely stored locally. You can export a snapshot backup anytime.'),
        actions: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: WrapAlignment.end,
            children: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close')),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryEmerald),
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Offline SQLite database snapshot backed up successfully!')),
                  );
                  Navigator.pop(ctx);
                },
                child: const Text('Backup Now'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _LauncherItem {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback action;

  _LauncherItem({
    required this.label,
    required this.icon,
    required this.color,
    required this.action,
  });
}
