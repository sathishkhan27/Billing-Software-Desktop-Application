import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import '../../core/theme/app_theme.dart';
import '../../data/models/product.dart';
import '../../data/models/purchase.dart';
import '../../domain/state/pos_providers.dart';

class PurchasesScreen extends ConsumerStatefulWidget {
  const PurchasesScreen({super.key});

  @override
  ConsumerState<PurchasesScreen> createState() => _PurchasesScreenState();
}

class _PurchasesScreenState extends ConsumerState<PurchasesScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final currency = ref.watch(currencySymbolProvider);

    return Scaffold(
      backgroundColor: AppTheme.darkBg,
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Bar
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Row(
                  children: [
                    Icon(Icons.shopping_cart_checkout_rounded, color: AppTheme.primaryBlue, size: 24),
                    SizedBox(width: 10),
                    Text(
                      'Purchases & Expenses (Inward)',
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppTheme.textLight),
                    ),
                  ],
                ),
                Row(
                  children: [
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryEmerald,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                      ),
                      icon: const Icon(Icons.add_shopping_cart_rounded, size: 18),
                      label: const Text('Record Purchase'),
                      onPressed: () => _showRecordPurchaseDialog(context),
                    ),
                    const SizedBox(width: 10),
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppTheme.accentRose,
                        side: const BorderSide(color: AppTheme.accentRose),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                      ),
                      icon: const Icon(Icons.receipt_long_rounded, size: 18),
                      label: const Text('Add Expense'),
                      onPressed: () => _showAddExpenseDialog(context),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Tab bar
            Container(
              decoration: const BoxDecoration(
                border: Border(bottom: BorderSide(color: AppTheme.cardBorder)),
              ),
              child: TabBar(
                controller: _tabController,
                indicatorColor: AppTheme.primaryBlue,
                labelColor: AppTheme.primaryBlue,
                unselectedLabelColor: AppTheme.textMuted,
                tabs: const [
                  Tab(text: 'Purchase Inward Bills'),
                  Tab(text: 'Store Expenses'),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Tab Views
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildPurchasesList(currency),
                  _buildExpensesList(currency),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPurchasesList(String currency) {
    final purchasesAsync = ref.watch(purchasesProvider);

    return purchasesAsync.when(
      data: (purchases) {
        if (purchases.isEmpty) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.shopping_bag_outlined, size: 48, color: AppTheme.textMuted),
                const SizedBox(height: 12),
                const Text('No purchases recorded yet.', style: TextStyle(color: AppTheme.textMuted)),
                const SizedBox(height: 8),
                ElevatedButton(
                  onPressed: () => _showRecordPurchaseDialog(context),
                  child: const Text('Inward Stock Now'),
                ),
              ],
            ),
          );
        }

        return Container(
          decoration: BoxDecoration(
            color: AppTheme.cardBg,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppTheme.cardBorder),
          ),
          child: ListView.separated(
            itemCount: purchases.length,
            separatorBuilder: (ctx, i) => const Divider(height: 1, color: AppTheme.cardBorder),
            itemBuilder: (ctx, index) {
              final p = purchases[index];
              final dateStr = DateFormat('dd-MMM-yyyy')
                  .format(DateTime.fromMillisecondsSinceEpoch(p.purchaseDate * 1000));

              return ListTile(
                leading: CircleAvatar(
                  backgroundColor: AppTheme.primaryEmerald.withValues(alpha: 0.15),
                  child: const Icon(Icons.inventory, color: AppTheme.primaryEmerald, size: 20),
                ),
                title: Row(
                  children: [
                    Text(p.vendorName, style: const TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(width: 10),
                    if (p.billNumber != null && p.billNumber!.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppTheme.cardBorder,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          'Bill: ${p.billNumber}',
                          style: const TextStyle(fontSize: 10, color: AppTheme.textLight),
                        ),
                      ),
                  ],
                ),
                subtitle: Text('$dateStr • ${p.items.length} items inwarded'),
                trailing: Text(
                  '$currency${p.grandTotal.toStringAsFixed(2)}',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppTheme.textLight),
                ),
              );
            },
          ),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator(color: AppTheme.primaryBlue)),
      error: (err, stack) => Center(child: Text('Error: $err')),
    );
  }

  Widget _buildExpensesList(String currency) {
    return FutureBuilder<List<Expense>>(
      future: ref.read(purchaseRepositoryProvider).getExpenses(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: AppTheme.primaryBlue));
        }

        final expenses = snapshot.data ?? [];
        if (expenses.isEmpty) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.receipt_outlined, size: 48, color: AppTheme.textMuted),
                const SizedBox(height: 12),
                const Text('No expenses recorded today.', style: TextStyle(color: AppTheme.textMuted)),
              ],
            ),
          );
        }

        return Container(
          decoration: BoxDecoration(
            color: AppTheme.cardBg,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppTheme.cardBorder),
          ),
          child: ListView.separated(
            itemCount: expenses.length,
            separatorBuilder: (ctx, i) => const Divider(height: 1, color: AppTheme.cardBorder),
            itemBuilder: (ctx, index) {
              final exp = expenses[index];
              final dateStr = DateFormat('dd-MMM-yyyy')
                  .format(DateTime.fromMillisecondsSinceEpoch(exp.expenseDate * 1000));

              return ListTile(
                leading: CircleAvatar(
                  backgroundColor: AppTheme.accentRose.withValues(alpha: 0.15),
                  child: const Icon(Icons.money_off, color: AppTheme.accentRose, size: 20),
                ),
                title: Text(exp.title, style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text('$dateStr • Category: ${exp.category} • Paid via ${exp.paymentMethod}'),
                trailing: Text(
                  '-$currency${exp.amount.toStringAsFixed(2)}',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppTheme.accentRose),
                ),
              );
            },
          ),
        );
      },
    );
  }

  void _showRecordPurchaseDialog(BuildContext context) async {
    final products = await ref.read(productsProvider.future);
    if (products.isEmpty) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please add products to your catalog first.')),
        );
      }
      return;
    }

    final vendorCtrl = TextEditingController();
    final billNoCtrl = TextEditingController();
    Product selectedProd = products.first;
    final qtyCtrl = TextEditingController(text: '1');
    final costCtrl = TextEditingController(text: selectedProd.costPrice.toString());
    if (!context.mounted) return;
    final isMobile = AppTheme.isMobile(context);

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            return AlertDialog(
              backgroundColor: AppTheme.cardBg,
              insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
              title: const Text('Record Inward Stock / Vendor Purchase'),
              content: SizedBox(
                width: isMobile ? double.maxFinite : 460,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextField(controller: vendorCtrl, decoration: const InputDecoration(labelText: 'Vendor / Supplier Name *', hintText: 'Enter vendor name')),
                      const SizedBox(height: 12),
                      TextField(controller: billNoCtrl, decoration: const InputDecoration(labelText: 'Supplier Bill / PO No', hintText: 'e.g. PO-1001')),
                      const SizedBox(height: 16),
                      DropdownButtonFormField<Product>(
                        initialValue: selectedProd,
                        decoration: const InputDecoration(labelText: 'Select Product to Inward *'),
                        dropdownColor: AppTheme.cardBg,
                        items: products.map((p) {
                          return DropdownMenuItem(
                            value: p,
                            child: Text('${p.name} (Stock: ${p.stockQuantity})'),
                          );
                        }).toList(),
                        onChanged: (p) {
                          if (p != null) {
                            setDialogState(() {
                              selectedProd = p;
                              costCtrl.text = p.costPrice.toString();
                            });
                          }
                        },
                      ),
                      const SizedBox(height: 12),
                      if (isMobile) ...[
                        TextField(
                          controller: qtyCtrl,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(labelText: 'Inward Quantity *'),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: costCtrl,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(labelText: 'Unit Cost (₹) *'),
                        ),
                      ] else ...[
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: qtyCtrl,
                                keyboardType: TextInputType.number,
                                decoration: const InputDecoration(labelText: 'Inward Quantity *'),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: TextField(
                                controller: costCtrl,
                                keyboardType: TextInputType.number,
                                decoration: const InputDecoration(labelText: 'Unit Cost (₹) *'),
                              ),
                            ),
                          ],
                        ),
                      ],
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
                      style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryEmerald),
                      onPressed: () async {
                        final qty = double.tryParse(qtyCtrl.text) ?? 0.0;
                        final cost = double.tryParse(costCtrl.text) ?? 0.0;
                        if (qty <= 0) return;

                        final purchaseId = const Uuid().v4();
                        final item = PurchaseItem(
                          id: const Uuid().v4(),
                          purchaseId: purchaseId,
                          productId: selectedProd.id,
                          productName: selectedProd.name,
                          quantity: qty,
                          unitCost: cost,
                          totalAmount: qty * cost,
                        );

                        final purchase = Purchase(
                          id: purchaseId,
                          vendorName: vendorCtrl.text.trim().isEmpty ? 'Vendor' : vendorCtrl.text.trim(),
                          billNumber: billNoCtrl.text.trim(),
                          purchaseDate: DateTime.now().millisecondsSinceEpoch ~/ 1000,
                          subtotal: qty * cost,
                          taxTotal: 0.0,
                          grandTotal: qty * cost,
                          createdAt: DateTime.now().millisecondsSinceEpoch ~/ 1000,
                          items: [item],
                        );

                        await ref.read(purchaseRepositoryProvider).savePurchase(purchase);
                        ref.invalidate(purchasesProvider);
                        ref.invalidate(productsProvider);
                        ref.invalidate(dashboardMetricsProvider);

                        if (ctx.mounted) {
                          Navigator.pop(ctx);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Successfully inwarded $qty ${selectedProd.unitOfMeasure} of ${selectedProd.name}')),
                          );
                        }
                      },
                      child: const Text('Save & Update Stock'),
                    ),
                  ],
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showAddExpenseDialog(BuildContext context) {
    final titleCtrl = TextEditingController();
    final amountCtrl = TextEditingController();
    String category = 'Store Utility';
    final isMobile = AppTheme.isMobile(context);

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            return AlertDialog(
              backgroundColor: AppTheme.cardBg,
              insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
              title: const Text('Record Store Expense'),
              content: SizedBox(
                width: isMobile ? double.maxFinite : 400,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextField(controller: titleCtrl, decoration: const InputDecoration(labelText: 'Expense Description *', hintText: 'e.g. Shop Electricity Bill')),
                      const SizedBox(height: 12),
                      TextField(controller: amountCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Amount (₹) *')),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        initialValue: category,
                        dropdownColor: AppTheme.cardBg,
                        decoration: const InputDecoration(labelText: 'Expense Category'),
                        items: ['Store Utility', 'Staff Refreshment', 'Rent', 'Stationery', 'Maintenance', 'Other']
                            .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                            .toList(),
                        onChanged: (val) {
                          if (val != null) setDialogState(() => category = val);
                        },
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
                    TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: AppTheme.accentRose),
                      onPressed: () async {
                        final amt = double.tryParse(amountCtrl.text) ?? 0.0;
                        if (titleCtrl.text.trim().isEmpty || amt <= 0) return;

                        final exp = Expense(
                          id: const Uuid().v4(),
                          title: titleCtrl.text.trim(),
                          category: category,
                          amount: amt,
                          expenseDate: DateTime.now().millisecondsSinceEpoch ~/ 1000,
                          createdAt: DateTime.now().millisecondsSinceEpoch ~/ 1000,
                        );

                        await ref.read(purchaseRepositoryProvider).addExpense(exp);
                        ref.invalidate(dashboardMetricsProvider);
                        setState(() {});
                        if (ctx.mounted) Navigator.pop(ctx);
                      },
                      child: const Text('Record Expense'),
                    ),
                  ],
                ),
              ],
            );
          },
        );
      },
    );
  }
}
