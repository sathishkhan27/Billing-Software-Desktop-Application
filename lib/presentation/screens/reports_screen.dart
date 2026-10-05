import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../core/database/app_database.dart';
import '../../core/theme/app_theme.dart';
import '../../domain/state/pos_providers.dart';

enum ReportPeriod { today, thisWeek, thisMonth, allTime }

enum ReportTab { salesDaybook, gstReport, itemSales, paymentModes }

class ReportsScreen extends ConsumerStatefulWidget {
  const ReportsScreen({super.key});

  @override
  ConsumerState<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends ConsumerState<ReportsScreen> {
  bool _loading = true;
  ReportPeriod _selectedPeriod = ReportPeriod.allTime;
  ReportTab _activeTab = ReportTab.salesDaybook;

  // Executive KPI summary metrics
  double _grossSales = 0.0;
  double _totalDiscounts = 0.0;
  double _totalTax = 0.0;
  double _netRevenue = 0.0;
  int _invoiceCount = 0;

  // Real database record lists
  List<Map<String, dynamic>> _invoicesList = [];
  List<Map<String, dynamic>> _gstSummary = [];
  List<Map<String, dynamic>> _paymentMethods = [];
  List<Map<String, dynamic>> _itemSalesList = [];

  @override
  void initState() {
    super.initState();
    _loadReportData();
  }

  Future<void> _loadReportData() async {
    setState(() => _loading = true);
    final db = await AppDatabase.instance;

    final now = DateTime.now();
    int? startTimestamp;
    switch (_selectedPeriod) {
      case ReportPeriod.today:
        startTimestamp = DateTime(now.year, now.month, now.day).millisecondsSinceEpoch ~/ 1000;
        break;
      case ReportPeriod.thisWeek:
        final startOfWeek = DateTime(now.year, now.month, now.day).subtract(Duration(days: now.weekday - 1));
        startTimestamp = startOfWeek.millisecondsSinceEpoch ~/ 1000;
        break;
      case ReportPeriod.thisMonth:
        startTimestamp = DateTime(now.year, now.month, 1).millisecondsSinceEpoch ~/ 1000;
        break;
      case ReportPeriod.allTime:
        startTimestamp = null;
        break;
    }

    final whereClause = startTimestamp != null ? 'WHERE created_at >= ?' : '';
    final whereArgs = startTimestamp != null ? [startTimestamp] : <Object>[];

    // 1. Overall Sales Summary Totals
    final salesRes = await db.rawQuery('''
      SELECT COUNT(*) as inv_count,
             COALESCE(SUM(subtotal), 0.0) as gross,
             COALESCE(SUM(invoice_discount_total + item_discount_total), 0.0) as discount,
             COALESCE(SUM(tax_total), 0.0) as tax,
             COALESCE(SUM(grand_total), 0.0) as net
      FROM invoices
      $whereClause
    ''', whereArgs);

    final first = salesRes.first;
    _invoiceCount = (first['inv_count'] as num? ?? 0).toInt();
    _grossSales = (first['gross'] as num? ?? 0.0).toDouble();
    _totalDiscounts = (first['discount'] as num? ?? 0.0).toDouble();
    _totalTax = (first['tax'] as num? ?? 0.0).toDouble();
    _netRevenue = (first['net'] as num? ?? 0.0).toDouble();

    // 2. Sales Invoices Register (Daybook) - Real Invoices
    final invoiceWhere = startTimestamp != null ? 'WHERE i.created_at >= ?' : '';
    final invRes = await db.rawQuery('''
      SELECT i.id,
             i.invoice_number,
             i.created_at,
             COALESCE(c.name, 'Walk-in Customer') as customer_name,
             i.payment_method,
             i.subtotal,
             i.tax_total,
             i.grand_total,
             i.payment_status,
             (SELECT COUNT(*) FROM invoice_items WHERE invoice_id = i.id) as item_count,
             (SELECT COALESCE(SUM(quantity), 0.0) FROM invoice_items WHERE invoice_id = i.id) as total_qty
      FROM invoices i
      LEFT JOIN customers c ON i.customer_id = c.id
      $invoiceWhere
      ORDER BY i.created_at DESC
    ''', whereArgs);
    _invoicesList = List<Map<String, dynamic>>.from(invRes);

    // 3. GST Breakdown by Slab - Real Tax Rates
    final gstWhere = startTimestamp != null ? 'WHERE i.created_at >= ?' : '';
    final gstRes = await db.rawQuery('''
      SELECT ii.tax_rate,
             COUNT(ii.id) as item_count,
             COALESCE(SUM(ii.taxable_amount), 0.0) as taxable_total,
             COALESCE(SUM(ii.tax_amount), 0.0) as tax_total
      FROM invoice_items ii
      JOIN invoices i ON ii.invoice_id = i.id
      $gstWhere
      GROUP BY ii.tax_rate
      ORDER BY ii.tax_rate ASC
    ''', whereArgs);
    _gstSummary = List<Map<String, dynamic>>.from(gstRes);

    // 4. Payment Methods - Real Tender Types
    final payRes = await db.rawQuery('''
      SELECT payment_method,
             COUNT(*) as count,
             COALESCE(SUM(grand_total), 0.0) as total
      FROM invoices
      $whereClause
      GROUP BY payment_method
      ORDER BY total DESC
    ''', whereArgs);
    _paymentMethods = List<Map<String, dynamic>>.from(payRes);

    // 5. Product-Wise Sales - Real Sold Items
    final itemWhere = startTimestamp != null ? 'WHERE i.created_at >= ?' : '';
    final itemsRes = await db.rawQuery('''
      SELECT COALESCE(p.name, 'Item') as name,
             COALESCE(p.unit_of_measure, 'PCS') as unit_of_measure,
             COUNT(ii.id) as transaction_count,
             COALESCE(SUM(ii.quantity), 0.0) as total_qty,
             COALESCE(SUM(ii.taxable_amount), 0.0) as taxable_amount,
             COALESCE(SUM(ii.tax_amount), 0.0) as tax_amount,
             COALESCE(SUM(ii.total_line_amount), 0.0) as total_revenue
      FROM invoice_items ii
      LEFT JOIN products p ON ii.product_id = p.id
      JOIN invoices i ON ii.invoice_id = i.id
      $itemWhere
      GROUP BY ii.product_id
      ORDER BY total_revenue DESC
    ''', whereArgs);
    _itemSalesList = List<Map<String, dynamic>>.from(itemsRes);

    if (mounted) {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final currency = ref.watch(currencySymbolProvider);
    final isMobile = AppTheme.isMobile(context);
    final isTablet = AppTheme.isTablet(context);

    return Scaffold(
      backgroundColor: AppTheme.darkBg,
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.primaryBlue))
          : SingleChildScrollView(
              padding: EdgeInsets.all(isMobile ? 12 : 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 1. TOP HEADER & DATE RANGE FILTER BAR
                  _buildTopHeader(isMobile),
                  const SizedBox(height: 16),

                  // 2. EXECUTIVE 5-METRIC KPI SUMMARY CARDS
                  _buildKpiSummaryCards(currency, isMobile, isTablet),
                  const SizedBox(height: 18),

                  // 3. REPORT SECTION NAVIGATION TABS
                  _buildReportTabSelector(isMobile),
                  const SizedBox(height: 16),

                  // 4. ACTIVE REPORT CONTENT VIEW (100% DYNAMIC SQLITE DATA)
                  _buildActiveReportView(currency, isMobile),
                ],
              ),
            ),
    );
  }

  // ---------------------------------------------------------------------------
  // 1. TOP HEADER & FILTER BAR
  // ---------------------------------------------------------------------------
  Widget _buildTopHeader(bool isMobile) {
    final dateChips = [
      _buildPeriodChip(ReportPeriod.today, 'Today'),
      _buildPeriodChip(ReportPeriod.thisWeek, 'This Week'),
      _buildPeriodChip(ReportPeriod.thisMonth, 'This Month'),
      _buildPeriodChip(ReportPeriod.allTime, 'All Time'),
    ];

    if (isMobile) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: const Color(0xFF131D31),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppTheme.cardBorder),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(7),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF2563EB), Color(0xFF06B6D4)],
                    ),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Icon(Icons.insights_rounded, color: Colors.white, size: 18),
                ),
                const SizedBox(width: 10),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Business Reports & Daybook',
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppTheme.textLight),
                      ),
                      Text(
                        'Live Sales, GST Registers & Product Performance',
                        style: TextStyle(fontSize: 10, color: AppTheme.textMuted),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'Refresh Reports',
                  iconSize: 18,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                  icon: const Icon(Icons.refresh_rounded, color: AppTheme.textMuted),
                  onPressed: _loadReportData,
                ),
              ],
            ),
            const SizedBox(height: 10),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: dateChips
                    .expand((chip) => [chip, const SizedBox(width: 6)])
                    .toList()
                  ..removeLast(),
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      decoration: BoxDecoration(
        color: const Color(0xFF131D31),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.cardBorder),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(9),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF2563EB), Color(0xFF06B6D4)],
              ),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.insights_rounded, color: Colors.white, size: 22),
          ),
          const SizedBox(width: 14),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Business Reports & Sales Daybook',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.textLight, letterSpacing: 0.3),
                ),
                SizedBox(height: 2),
                Text(
                  'Live billing transactions, GST tax registers, item sales performance & tender distribution',
                  style: TextStyle(fontSize: 11, color: AppTheme.textMuted),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),

          // Period Chips
          Row(
            children: dateChips
                .expand((chip) => [chip, const SizedBox(width: 6)])
                .toList()
              ..removeLast(),
          ),
          const SizedBox(width: 12),

          // Refresh Button
          IconButton(
            tooltip: 'Refresh Reports Data',
            style: IconButton.styleFrom(
              backgroundColor: const Color(0xFF1E293B),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(6),
                side: const BorderSide(color: AppTheme.cardBorder),
              ),
            ),
            icon: const Icon(Icons.refresh_rounded, size: 18, color: AppTheme.textMuted),
            onPressed: _loadReportData,
          ),
        ],
      ),
    );
  }

  Widget _buildPeriodChip(ReportPeriod period, String label) {
    final isSelected = _selectedPeriod == period;
    return InkWell(
      onTap: () {
        if (_selectedPeriod != period) {
          setState(() => _selectedPeriod = period);
          _loadReportData();
        }
      },
      borderRadius: BorderRadius.circular(6),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.primaryBlue : const Color(0xFF1E293B),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: isSelected ? AppTheme.primaryBlue : AppTheme.cardBorder,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
            color: isSelected ? Colors.white : AppTheme.textMuted,
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // 2. EXECUTIVE 5-METRIC KPI SUMMARY CARDS
  // ---------------------------------------------------------------------------
  Widget _buildKpiSummaryCards(String currency, bool isMobile, bool isTablet) {
    final cards = [
      _buildMetricCard(
        title: 'TOTAL INVOICES',
        value: '$_invoiceCount',
        subtitle: 'Invoices in period',
        icon: Icons.receipt_long_rounded,
        color: AppTheme.accentCyan,
      ),
      _buildMetricCard(
        title: 'GROSS TURNOVER',
        value: '$currency${_grossSales.toStringAsFixed(2)}',
        subtitle: 'Pre-discount turnover',
        icon: Icons.point_of_sale_rounded,
        color: AppTheme.primaryBlue,
      ),
      _buildMetricCard(
        title: 'TOTAL DISCOUNTS',
        value: '$currency${_totalDiscounts.toStringAsFixed(2)}',
        subtitle: 'Customer discounts',
        icon: Icons.local_offer_rounded,
        color: AppTheme.accentAmber,
      ),
      _buildMetricCard(
        title: 'GST COLLECTED',
        value: '$currency${_totalTax.toStringAsFixed(2)}',
        subtitle: 'Total tax liability',
        icon: Icons.account_balance_rounded,
        color: AppTheme.primaryEmerald,
      ),
      _buildMetricCard(
        title: 'NET REVENUE',
        value: '$currency${_netRevenue.toStringAsFixed(2)}',
        subtitle: 'Realized collection',
        icon: Icons.payments_rounded,
        color: const Color(0xFF60A5FA),
      ),
    ];

    if (isMobile) {
      return LayoutBuilder(
        builder: (context, constraints) {
          final itemWidth = (constraints.maxWidth - 8) / 2;
          return Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              ...cards.take(4).map((c) => SizedBox(width: itemWidth, child: c)),
              SizedBox(width: constraints.maxWidth, child: cards.last),
            ],
          );
        },
      );
    }

    if (isTablet) {
      return LayoutBuilder(
        builder: (context, constraints) {
          final itemWidth = (constraints.maxWidth - 16) / 3;
          return Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              ...cards.take(3).map((c) => SizedBox(width: itemWidth, child: c)),
              SizedBox(width: (constraints.maxWidth - 8) / 2, child: cards[3]),
              SizedBox(width: (constraints.maxWidth - 8) / 2, child: cards[4]),
            ],
          );
        },
      );
    }

    return Row(
      children: cards
          .asMap()
          .entries
          .map((e) => [
                if (e.key > 0) const SizedBox(width: 10),
                Expanded(child: e.value),
              ])
          .expand((x) => x)
          .toList(),
    );
  }

  Widget _buildMetricCard({
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF131D31),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppTheme.textMuted, letterSpacing: 0.5),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Container(
                padding: const EdgeInsets.all(5),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(5),
                ),
                child: Icon(icon, color: color, size: 15),
              ),
            ],
          ),
          const SizedBox(height: 6),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            style: const TextStyle(fontSize: 10, color: AppTheme.textSecondary),
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // 3. REPORT SECTION NAVIGATION TABS
  // ---------------------------------------------------------------------------
  Widget _buildReportTabSelector(bool isMobile) {
    final tabs = [
      {'tab': ReportTab.salesDaybook, 'label': 'Sales Daybook', 'icon': Icons.receipt_long_rounded, 'count': _invoicesList.length},
      {'tab': ReportTab.gstReport, 'label': 'GST Slabs', 'icon': Icons.table_chart_rounded, 'count': _gstSummary.length},
      {'tab': ReportTab.itemSales, 'label': 'Item-Wise Sales', 'icon': Icons.inventory_2_rounded, 'count': _itemSalesList.length},
      {'tab': ReportTab.paymentModes, 'label': 'Payment Modes', 'icon': Icons.payments_rounded, 'count': _paymentMethods.length},
    ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: tabs.map((t) {
          final tabEnum = t['tab'] as ReportTab;
          final isSelected = _activeTab == tabEnum;
          final label = t['label'] as String;
          final icon = t['icon'] as IconData;
          final count = t['count'] as int;

          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: InkWell(
              onTap: () => setState(() => _activeTab = tabEnum),
              borderRadius: BorderRadius.circular(6),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: isSelected ? AppTheme.primaryBlue : const Color(0xFF131D31),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: isSelected ? AppTheme.primaryBlue : AppTheme.cardBorder,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(icon, size: 15, color: isSelected ? Colors.white : AppTheme.textMuted),
                    const SizedBox(width: 6),
                    Text(
                      label,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                        color: isSelected ? Colors.white : AppTheme.textLight,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                      decoration: BoxDecoration(
                        color: isSelected ? Colors.white.withValues(alpha: 0.2) : const Color(0xFF1E293B),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '$count',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: isSelected ? Colors.white : AppTheme.accentCyan,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // 4. ACTIVE REPORT CONTENT VIEW
  // ---------------------------------------------------------------------------
  Widget _buildActiveReportView(String currency, bool isMobile) {
    switch (_activeTab) {
      case ReportTab.salesDaybook:
        return _buildSalesDaybookTable(currency, isMobile);
      case ReportTab.gstReport:
        return _buildGstBreakdownCard(currency, isMobile);
      case ReportTab.itemSales:
        return _buildItemSalesTable(currency, isMobile);
      case ReportTab.paymentModes:
        return _buildPaymentModesReport(currency, isMobile);
    }
  }

  // ---------------------------------------------------------------------------
  // REPORT 1: SALES DAYBOOK (INVOICES REGISTER) - 100% REAL BILLS
  // ---------------------------------------------------------------------------
  Widget _buildSalesDaybookTable(String currency, bool isMobile) {
    double totalSubtotal = 0.0;
    double totalTax = 0.0;
    double totalGrand = 0.0;
    double totalUnits = 0.0;

    for (final inv in _invoicesList) {
      totalSubtotal += (inv['subtotal'] as num? ?? 0.0).toDouble();
      totalTax += (inv['tax_total'] as num? ?? 0.0).toDouble();
      totalGrand += (inv['grand_total'] as num? ?? 0.0).toDouble();
      totalUnits += (inv['total_qty'] as num? ?? 0.0).toDouble();
    }

    return Container(
      padding: EdgeInsets.all(isMobile ? 12 : 18),
      decoration: BoxDecoration(
        color: AppTheme.cardBg,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.receipt_long_rounded, color: AppTheme.primaryBlue, size: 18),
                  const SizedBox(width: 8),
                  Text(
                    'Sales Daybook Register (${_invoicesList.length} Invoices)',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppTheme.textLight),
                  ),
                ],
              ),
              Text(
                'Total: $currency${totalGrand.toStringAsFixed(2)}',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.accentCyan),
              ),
            ],
          ),
          const SizedBox(height: 14),

          if (_invoicesList.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 36),
              child: Center(
                child: Text('No sales invoices found for the selected period.', style: TextStyle(color: AppTheme.textMuted)),
              ),
            )
          else
            LayoutBuilder(
              builder: (context, constraints) {
                final minTableWidth = 820.0;
                final tableWidth = constraints.maxWidth < minTableWidth ? minTableWidth : constraints.maxWidth;

                return SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: SizedBox(
                    width: tableWidth,
                    child: Table(
                      columnWidths: const {
                        0: FlexColumnWidth(1.6), // Invoice No
                        1: FlexColumnWidth(1.8), // Date Time
                        2: FlexColumnWidth(2.2), // Customer
                        3: FlexColumnWidth(1.3), // Payment Mode
                        4: FlexColumnWidth(1.2), // Qty
                        5: FlexColumnWidth(1.6), // Subtotal
                        6: FlexColumnWidth(1.5), // Tax
                        7: FlexColumnWidth(1.8), // Grand Total
                      },
                      children: [
                        // Header
                        TableRow(
                          decoration: const BoxDecoration(
                            color: Color(0xFF141F32),
                            borderRadius: BorderRadius.vertical(top: Radius.circular(6)),
                          ),
                          children: [
                            _buildTableHeaderCell('INVOICE NO', TextAlign.left),
                            _buildTableHeaderCell('DATE & TIME', TextAlign.left),
                            _buildTableHeaderCell('CUSTOMER', TextAlign.left),
                            _buildTableHeaderCell('PAYMENT', TextAlign.center),
                            _buildTableHeaderCell('QTY', TextAlign.right),
                            _buildTableHeaderCell('SUBTOTAL', TextAlign.right),
                            _buildTableHeaderCell('TAX', TextAlign.right),
                            _buildTableHeaderCell('NET TOTAL', TextAlign.right),
                          ],
                        ),

                        // Invoices
                        ..._invoicesList.map((inv) {
                          final invNo = inv['invoice_number'] as String? ?? '-';
                          final rawCreatedAt = (inv['created_at'] as num? ?? 0).toInt();
                          final dateStr = rawCreatedAt > 0
                              ? DateFormat('dd/MM/yyyy HH:mm').format(DateTime.fromMillisecondsSinceEpoch(rawCreatedAt * 1000))
                              : '-';
                          final cust = inv['customer_name'] as String? ?? 'Walk-in';
                          final payment = inv['payment_method'] as String? ?? 'CASH';
                          final qty = (inv['total_qty'] as num? ?? 0.0).toDouble();
                          final subtotal = (inv['subtotal'] as num? ?? 0.0).toDouble();
                          final tax = (inv['tax_total'] as num? ?? 0.0).toDouble();
                          final grand = (inv['grand_total'] as num? ?? 0.0).toDouble();

                          return TableRow(
                            decoration: const BoxDecoration(
                              border: Border(top: BorderSide(color: AppTheme.cardBorder, width: 0.5)),
                            ),
                            children: [
                              _buildTableBodyCell(invNo, align: TextAlign.left, bold: true, color: AppTheme.accentCyan),
                              _buildTableBodyCell(dateStr, align: TextAlign.left),
                              _buildTableBodyCell(cust, align: TextAlign.left),
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
                                child: Center(
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF1E293B),
                                      borderRadius: BorderRadius.circular(4),
                                      border: Border.all(color: AppTheme.cardBorder),
                                    ),
                                    child: Text(
                                      payment,
                                      style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppTheme.textLight),
                                    ),
                                  ),
                                ),
                              ),
                              _buildTableBodyCell(qty.toStringAsFixed(qty % 1 == 0 ? 0 : 2), align: TextAlign.right),
                              _buildTableBodyCell('$currency${subtotal.toStringAsFixed(2)}', align: TextAlign.right),
                              _buildTableBodyCell('$currency${tax.toStringAsFixed(2)}', align: TextAlign.right),
                              _buildTableBodyCell('$currency${grand.toStringAsFixed(2)}', align: TextAlign.right, bold: true, color: AppTheme.primaryEmerald),
                            ],
                          );
                        }),

                        // Totals Summary Row
                        TableRow(
                          decoration: const BoxDecoration(
                            color: Color(0xFF0F1B2D),
                            border: Border(top: BorderSide(color: AppTheme.primaryEmerald, width: 1.5)),
                          ),
                          children: [
                            _buildTableBodyCell('TOTALS', align: TextAlign.left, bold: true, color: Colors.white),
                            _buildTableBodyCell('${_invoicesList.length} Invoices', align: TextAlign.left, bold: true, color: AppTheme.textMuted),
                            _buildTableBodyCell('-', align: TextAlign.left),
                            _buildTableBodyCell('-', align: TextAlign.center),
                            _buildTableBodyCell(totalUnits.toStringAsFixed(totalUnits % 1 == 0 ? 0 : 2), align: TextAlign.right, bold: true, color: Colors.white),
                            _buildTableBodyCell('$currency${totalSubtotal.toStringAsFixed(2)}', align: TextAlign.right, bold: true, color: Colors.white),
                            _buildTableBodyCell('$currency${totalTax.toStringAsFixed(2)}', align: TextAlign.right, bold: true, color: Colors.white),
                            _buildTableBodyCell('$currency${totalGrand.toStringAsFixed(2)}', align: TextAlign.right, bold: true, color: AppTheme.primaryEmerald),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // REPORT 2: GST BREAKDOWN TABLE (REAL TAX RATES & TOTALS)
  // ---------------------------------------------------------------------------
  Widget _buildGstBreakdownCard(String currency, bool isMobile) {
    double totalTaxable = 0.0;
    double totalCgst = 0.0;
    double totalSgst = 0.0;
    double grandTotalTax = 0.0;

    for (final row in _gstSummary) {
      final taxable = (row['taxable_total'] as num? ?? 0.0).toDouble();
      final tax = (row['tax_total'] as num? ?? 0.0).toDouble();
      totalTaxable += taxable;
      grandTotalTax += tax;
      totalCgst += (tax / 2.0);
      totalSgst += (tax / 2.0);
    }

    return Container(
      padding: EdgeInsets.all(isMobile ? 12 : 18),
      decoration: BoxDecoration(
        color: AppTheme.cardBg,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Row(
                children: [
                  Icon(Icons.table_chart_rounded, color: AppTheme.primaryEmerald, size: 18),
                  SizedBox(width: 8),
                  Text(
                    'GST Tax Liability by Slab',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppTheme.textLight),
                  ),
                ],
              ),
              Text(
                'Total Tax: $currency${grandTotalTax.toStringAsFixed(2)}',
                style: const TextStyle(color: AppTheme.primaryEmerald, fontSize: 13, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 14),

          if (_gstSummary.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 36),
              child: Center(
                child: Text('No billed items in the selected period.', style: TextStyle(color: AppTheme.textMuted)),
              ),
            )
          else
            LayoutBuilder(
              builder: (context, constraints) {
                final minTableWidth = 680.0;
                final tableWidth = constraints.maxWidth < minTableWidth ? minTableWidth : constraints.maxWidth;

                return SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: SizedBox(
                    width: tableWidth,
                    child: Table(
                      columnWidths: const {
                        0: FlexColumnWidth(2.0), // GST Rate
                        1: FlexColumnWidth(1.5), // Item Count
                        2: FlexColumnWidth(2.5), // Taxable Turnover
                        3: FlexColumnWidth(2.0), // CGST
                        4: FlexColumnWidth(2.0), // SGST
                        5: FlexColumnWidth(2.5), // Total GST
                      },
                      children: [
                        TableRow(
                          decoration: const BoxDecoration(
                            color: Color(0xFF141F32),
                            borderRadius: BorderRadius.vertical(top: Radius.circular(6)),
                          ),
                          children: [
                            _buildTableHeaderCell('GST SLAB RATE', TextAlign.left),
                            _buildTableHeaderCell('ITEMS', TextAlign.center),
                            _buildTableHeaderCell('TAXABLE TURNOVER', TextAlign.right),
                            _buildTableHeaderCell('CGST', TextAlign.right),
                            _buildTableHeaderCell('SGST', TextAlign.right),
                            _buildTableHeaderCell('TOTAL GST TAX', TextAlign.right),
                          ],
                        ),
                        ..._gstSummary.map((row) {
                          final rate = (row['tax_rate'] as num? ?? 0.0).toDouble();
                          final count = (row['item_count'] as num? ?? 0).toInt();
                          final taxable = (row['taxable_total'] as num? ?? 0.0).toDouble();
                          final tax = (row['tax_total'] as num? ?? 0.0).toDouble();
                          final halfTax = tax / 2.0;

                          return TableRow(
                            decoration: const BoxDecoration(
                              border: Border(top: BorderSide(color: AppTheme.cardBorder, width: 0.5)),
                            ),
                            children: [
                              _buildTableBodyCell('${rate.toStringAsFixed(1)}% GST', align: TextAlign.left, bold: true, color: AppTheme.accentCyan),
                              _buildTableBodyCell('$count', align: TextAlign.center),
                              _buildTableBodyCell('$currency${taxable.toStringAsFixed(2)}', align: TextAlign.right),
                              _buildTableBodyCell('$currency${halfTax.toStringAsFixed(2)}', align: TextAlign.right),
                              _buildTableBodyCell('$currency${halfTax.toStringAsFixed(2)}', align: TextAlign.right),
                              _buildTableBodyCell('$currency${tax.toStringAsFixed(2)}', align: TextAlign.right, bold: true, color: AppTheme.primaryEmerald),
                            ],
                          );
                        }),
                        TableRow(
                          decoration: const BoxDecoration(
                            color: Color(0xFF0F1B2D),
                            border: Border(top: BorderSide(color: AppTheme.primaryEmerald, width: 1.5)),
                          ),
                          children: [
                            _buildTableBodyCell('TOTAL LIABILITY', align: TextAlign.left, bold: true, color: Colors.white),
                            _buildTableBodyCell('-', align: TextAlign.center),
                            _buildTableBodyCell('$currency${totalTaxable.toStringAsFixed(2)}', align: TextAlign.right, bold: true, color: Colors.white),
                            _buildTableBodyCell('$currency${totalCgst.toStringAsFixed(2)}', align: TextAlign.right, bold: true, color: Colors.white),
                            _buildTableBodyCell('$currency${totalSgst.toStringAsFixed(2)}', align: TextAlign.right, bold: true, color: Colors.white),
                            _buildTableBodyCell('$currency${grandTotalTax.toStringAsFixed(2)}', align: TextAlign.right, bold: true, color: AppTheme.primaryEmerald),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // REPORT 3: ITEM-WISE SALES TABLE - 100% REAL PRODUCT SALES
  // ---------------------------------------------------------------------------
  Widget _buildItemSalesTable(String currency, bool isMobile) {
    double totalUnitsSold = 0.0;
    double totalItemRevenue = 0.0;
    double totalItemTax = 0.0;

    for (final item in _itemSalesList) {
      totalUnitsSold += (item['total_qty'] as num? ?? 0.0).toDouble();
      totalItemRevenue += (item['total_revenue'] as num? ?? 0.0).toDouble();
      totalItemTax += (item['tax_amount'] as num? ?? 0.0).toDouble();
    }

    return Container(
      padding: EdgeInsets.all(isMobile ? 12 : 18),
      decoration: BoxDecoration(
        color: AppTheme.cardBg,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.inventory_2_rounded, color: AppTheme.accentCyan, size: 18),
                  const SizedBox(width: 8),
                  Text(
                    'Item-Wise Sales Summary (${_itemSalesList.length} Products)',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppTheme.textLight),
                  ),
                ],
              ),
              Text(
                'Revenue: $currency${totalItemRevenue.toStringAsFixed(2)}',
                style: const TextStyle(color: AppTheme.accentCyan, fontSize: 13, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 14),

          if (_itemSalesList.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 36),
              child: Center(
                child: Text('No item sales found for the selected period.', style: TextStyle(color: AppTheme.textMuted)),
              ),
            )
          else
            LayoutBuilder(
              builder: (context, constraints) {
                final minTableWidth = 720.0;
                final tableWidth = constraints.maxWidth < minTableWidth ? minTableWidth : constraints.maxWidth;

                return SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: SizedBox(
                    width: tableWidth,
                    child: Table(
                      columnWidths: const {
                        0: FlexColumnWidth(2.8), // Product Name
                        1: FlexColumnWidth(1.2), // UOM
                        2: FlexColumnWidth(1.5), // Units Sold
                        3: FlexColumnWidth(1.5), // Bills
                        4: FlexColumnWidth(2.0), // Taxable
                        5: FlexColumnWidth(1.8), // Tax
                        6: FlexColumnWidth(2.2), // Total Revenue
                      },
                      children: [
                        TableRow(
                          decoration: const BoxDecoration(
                            color: Color(0xFF141F32),
                            borderRadius: BorderRadius.vertical(top: Radius.circular(6)),
                          ),
                          children: [
                            _buildTableHeaderCell('PRODUCT NAME', TextAlign.left),
                            _buildTableHeaderCell('UNIT', TextAlign.center),
                            _buildTableHeaderCell('QTY SOLD', TextAlign.right),
                            _buildTableHeaderCell('BILLS', TextAlign.center),
                            _buildTableHeaderCell('TAXABLE', TextAlign.right),
                            _buildTableHeaderCell('TAX', TextAlign.right),
                            _buildTableHeaderCell('NET REVENUE', TextAlign.right),
                          ],
                        ),
                        ..._itemSalesList.map((item) {
                          final name = item['name'] as String? ?? 'Item';
                          final uom = item['unit_of_measure'] as String? ?? 'PCS';
                          final qty = (item['total_qty'] as num? ?? 0.0).toDouble();
                          final bills = (item['transaction_count'] as num? ?? 0).toInt();
                          final taxable = (item['taxable_amount'] as num? ?? 0.0).toDouble();
                          final tax = (item['tax_amount'] as num? ?? 0.0).toDouble();
                          final revenue = (item['total_revenue'] as num? ?? 0.0).toDouble();

                          return TableRow(
                            decoration: const BoxDecoration(
                              border: Border(top: BorderSide(color: AppTheme.cardBorder, width: 0.5)),
                            ),
                            children: [
                              _buildTableBodyCell(name, align: TextAlign.left, bold: true, color: AppTheme.textLight),
                              _buildTableBodyCell(uom, align: TextAlign.center),
                              _buildTableBodyCell(qty.toStringAsFixed(qty % 1 == 0 ? 0 : 2), align: TextAlign.right),
                              _buildTableBodyCell('$bills', align: TextAlign.center),
                              _buildTableBodyCell('$currency${taxable.toStringAsFixed(2)}', align: TextAlign.right),
                              _buildTableBodyCell('$currency${tax.toStringAsFixed(2)}', align: TextAlign.right),
                              _buildTableBodyCell('$currency${revenue.toStringAsFixed(2)}', align: TextAlign.right, bold: true, color: AppTheme.primaryEmerald),
                            ],
                          );
                        }),
                        TableRow(
                          decoration: const BoxDecoration(
                            color: Color(0xFF0F1B2D),
                            border: Border(top: BorderSide(color: AppTheme.primaryEmerald, width: 1.5)),
                          ),
                          children: [
                            _buildTableBodyCell('TOTALS', align: TextAlign.left, bold: true, color: Colors.white),
                            _buildTableBodyCell('-', align: TextAlign.center),
                            _buildTableBodyCell(totalUnitsSold.toStringAsFixed(totalUnitsSold % 1 == 0 ? 0 : 2), align: TextAlign.right, bold: true, color: Colors.white),
                            _buildTableBodyCell('-', align: TextAlign.center),
                            _buildTableBodyCell('-', align: TextAlign.right),
                            _buildTableBodyCell('$currency${totalItemTax.toStringAsFixed(2)}', align: TextAlign.right, bold: true, color: Colors.white),
                            _buildTableBodyCell('$currency${totalItemRevenue.toStringAsFixed(2)}', align: TextAlign.right, bold: true, color: AppTheme.primaryEmerald),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // REPORT 4: PAYMENT MODES BREAKDOWN - 100% REAL TENDER DATA
  // ---------------------------------------------------------------------------
  Widget _buildPaymentModesReport(String currency, bool isMobile) {
    final grandTotal = _paymentMethods.fold<double>(0.0, (sum, pm) => sum + (pm['total'] as num? ?? 0.0).toDouble());

    return Container(
      padding: EdgeInsets.all(isMobile ? 12 : 18),
      decoration: BoxDecoration(
        color: AppTheme.cardBg,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Row(
                children: [
                  Icon(Icons.payments_rounded, color: AppTheme.primaryEmerald, size: 18),
                  SizedBox(width: 8),
                  Text(
                    'Payment Mode Distribution',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppTheme.textLight),
                  ),
                ],
              ),
              Text(
                'Total Collections: $currency${grandTotal.toStringAsFixed(2)}',
                style: const TextStyle(color: AppTheme.primaryEmerald, fontSize: 13, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 16),

          if (_paymentMethods.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 36),
              child: Center(
                child: Text('No payment transaction records in the selected period.', style: TextStyle(color: AppTheme.textMuted)),
              ),
            )
          else
            ..._paymentMethods.map((pm) {
              final method = pm['payment_method'] as String? ?? 'CASH';
              final total = (pm['total'] as num? ?? 0.0).toDouble();
              final count = (pm['count'] as num? ?? 0).toInt();
              final share = grandTotal > 0 ? (total / grandTotal) : 0.0;

              final methodColor = method == 'CASH'
                  ? AppTheme.primaryEmerald
                  : (method == 'UPI'
                      ? AppTheme.accentCyan
                      : (method == 'CARD' ? const Color(0xFF8B5CF6) : AppTheme.accentAmber));

              final methodIcon = method == 'CASH'
                  ? Icons.money_rounded
                  : (method == 'UPI'
                      ? Icons.qr_code_2_rounded
                      : (method == 'CARD' ? Icons.credit_card_rounded : Icons.account_balance_wallet_rounded));

              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFF131D31),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppTheme.cardBorder),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: methodColor.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Icon(methodIcon, size: 16, color: methodColor),
                            ),
                            const SizedBox(width: 10),
                            Text(
                              method,
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.textLight),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: const Color(0xFF1E293B),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                '$count invoices  •  ${(share * 100).toStringAsFixed(1)}%',
                                style: const TextStyle(fontSize: 10, color: AppTheme.textMuted),
                              ),
                            ),
                          ],
                        ),
                        Text(
                          '$currency${total.toStringAsFixed(2)}',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: methodColor),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: share.clamp(0.0, 1.0),
                        minHeight: 6,
                        backgroundColor: const Color(0xFF141F32),
                        valueColor: AlwaysStoppedAnimation<Color>(methodColor),
                      ),
                    ),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }

  Widget _buildTableHeaderCell(String text, TextAlign align) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      child: Text(
        text,
        textAlign: align,
        style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppTheme.textMuted, letterSpacing: 0.4),
      ),
    );
  }

  Widget _buildTableBodyCell(String text, {required TextAlign align, bool bold = false, Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 11),
      child: Text(
        text,
        textAlign: align,
        style: TextStyle(
          fontSize: 12,
          fontWeight: bold ? FontWeight.bold : FontWeight.normal,
          color: color ?? AppTheme.textLight,
        ),
      ),
    );
  }
}
