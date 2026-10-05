import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../core/theme/app_theme.dart';
import '../../data/models/invoice.dart';
import '../../data/repositories/dashboard_repository.dart';
import '../../domain/state/pos_providers.dart';

class DashboardScreen extends ConsumerWidget {
  final Function(int targetIndex)? onNavigateTab;

  const DashboardScreen({super.key, this.onNavigateTab});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final metricsAsync = ref.watch(dashboardMetricsProvider);
    final currency = ref.watch(currencySymbolProvider);
    final todayFormatted = DateFormat('dd-MMM-yyyy').format(DateTime.now());

    return Scaffold(
      backgroundColor: AppTheme.darkBg,
      body: metricsAsync.when(
        data: (metrics) => _buildDashboardContent(context, ref, metrics, currency, todayFormatted),
        loading: () => const Center(child: CircularProgressIndicator(color: AppTheme.primaryBlue)),
        error: (err, stack) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, color: AppTheme.accentRose, size: 48),
              const SizedBox(height: 12),
              Text('Failed to load dashboard metrics: $err', style: const TextStyle(color: AppTheme.textMuted)),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: () => ref.invalidate(dashboardMetricsProvider),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDashboardContent(
    BuildContext context,
    WidgetRef ref,
    DashboardMetrics metrics,
    String currency,
    String todayFormatted,
  ) {
    final isMobile = AppTheme.isMobile(context);

    final chartCard = Container(
      padding: EdgeInsets.all(isMobile ? 14 : 20),
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
              const Expanded(
                child: Row(
                  children: [
                    Icon(Icons.bar_chart, color: AppTheme.accentCyan, size: 20),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Sales (Last 7 Days)',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppTheme.textLight),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: AppTheme.accentCyan.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Text(
                  'Daily Trend',
                  style: TextStyle(color: AppTheme.accentCyan, fontSize: 11, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          SizedBox(
            height: 220,
            child: _buildSalesBarChart(metrics.salesTrend, currency),
          ),
        ],
      ),
    );

    final statusCard = Container(
      padding: EdgeInsets.all(isMobile ? 14 : 20),
      decoration: BoxDecoration(
        color: AppTheme.cardBg,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.verified_rounded, color: AppTheme.primaryEmerald, size: 20),
              SizedBox(width: 8),
              Text(
                'GST Ready & Offline Status',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppTheme.textLight),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildStatusRow('Deployment Mode', '100% Offline SQLite', Icons.cloud_done_rounded, AppTheme.accentCyan),
          _buildStatusRow('GST Compliance', 'B2C / B2B & HSN Slabs', Icons.receipt_long_rounded, AppTheme.primaryEmerald),
          _buildStatusRow('Fast POS Printing', 'ESC/POS 80mm & A4 PDF', Icons.print_rounded, AppTheme.accentAmber),
          _buildStatusRow('Digital Payment', 'Dynamic UPI QR Ready', Icons.qr_code_2_rounded, AppTheme.primaryBlue),
          const Divider(color: AppTheme.cardBorder, height: 24),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1E3A8A),
              foregroundColor: Colors.white,
              minimumSize: const Size.fromHeight(40),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
            ),
            icon: const Icon(Icons.analytics_rounded, size: 18),
            label: const Text('View Full Sales Reports'),
            onPressed: () => onNavigateTab?.call(5),
          ),
        ],
      ),
    );

    return SingleChildScrollView(
      padding: EdgeInsets.all(isMobile ? 16 : 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Bar
          if (isMobile)
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const Text(
                          'Dashboard',
                          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppTheme.textLight),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: AppTheme.cardBg,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: AppTheme.cardBorder),
                          ),
                          child: Text(
                            todayFormatted,
                            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 11, color: AppTheme.textLight),
                          ),
                        ),
                      ],
                    ),
                    IconButton(
                      icon: const Icon(Icons.refresh, size: 20, color: AppTheme.textMuted),
                      tooltip: 'Refresh Metrics',
                      onPressed: () => ref.invalidate(dashboardMetricsProvider),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryBlue,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                      ),
                      icon: const Icon(Icons.add_circle_outline_rounded, size: 16),
                      label: const Text('Create Invoice', style: TextStyle(fontSize: 12)),
                      onPressed: () => onNavigateTab?.call(1),
                    ),
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppTheme.textLight,
                        side: const BorderSide(color: AppTheme.cardBorder),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                      ),
                      icon: const Icon(Icons.inventory_2_rounded, size: 16),
                      label: const Text('Manage Stock', style: TextStyle(fontSize: 12)),
                      onPressed: () => onNavigateTab?.call(3),
                    ),
                  ],
                ),
              ],
            )
          else
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Text(
                      'Dashboard : ',
                      style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppTheme.textLight),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppTheme.cardBg,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: AppTheme.cardBorder),
                      ),
                      child: Row(
                        children: [
                          Text(
                            todayFormatted,
                            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: AppTheme.textLight),
                          ),
                          const SizedBox(width: 6),
                          const Icon(Icons.calendar_today, size: 14, color: AppTheme.textMuted),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    IconButton(
                      icon: const Icon(Icons.refresh, size: 20, color: AppTheme.textMuted),
                      tooltip: 'Refresh Metrics',
                      onPressed: () => ref.invalidate(dashboardMetricsProvider),
                    ),
                  ],
                ),
                Row(
                  children: [
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryBlue,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                      ),
                      icon: const Icon(Icons.add_circle_outline_rounded, size: 18),
                      label: const Text('Create Invoice'),
                      onPressed: () => onNavigateTab?.call(1),
                    ),
                    const SizedBox(width: 10),
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppTheme.textLight,
                        side: const BorderSide(color: AppTheme.cardBorder),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                      ),
                      icon: const Icon(Icons.inventory_2_rounded, size: 18),
                      label: const Text('Manage Stock'),
                      onPressed: () => onNavigateTab?.call(3),
                    ),
                  ],
                ),
              ],
            ),
          const SizedBox(height: 20),

          // 4 Colorful Metric Cards
          LayoutBuilder(
            builder: (context, constraints) {
              final isWide = constraints.maxWidth > 900;
              final isVeryNarrow = constraints.maxWidth < 500;
              final cardWidth = isWide
                  ? (constraints.maxWidth - 36) / 4
                  : (isVeryNarrow ? constraints.maxWidth : (constraints.maxWidth - 12) / 2);

              return Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  _buildMetricCard(
                    title: "Today's Sales",
                    value: '$currency${metrics.todaySales.toStringAsFixed(2)}',
                    subtext: '${metrics.todayInvoiceCount} Invoices generated',
                    color: const Color(0xFF0284C7),
                    icon: Icons.receipt_long_rounded,
                    onTapMore: () => onNavigateTab?.call(1),
                    width: cardWidth,
                  ),
                  _buildMetricCard(
                    title: "All Accounts Balance",
                    value: '$currency${metrics.accountsBalance.toStringAsFixed(2)}',
                    subtext: 'Net customer receivables',
                    color: const Color(0xFF16A34A),
                    icon: Icons.account_balance_wallet_rounded,
                    onTapMore: () => onNavigateTab?.call(4),
                    width: cardWidth,
                  ),
                  _buildMetricCard(
                    title: "Current Stock Status",
                    value: '$currency${metrics.stockValuation.toStringAsFixed(2)}',
                    subtext: '${metrics.totalProducts} Total Products',
                    color: const Color(0xFFD97706),
                    icon: Icons.inventory_2_rounded,
                    onTapMore: () => onNavigateTab?.call(3),
                    width: cardWidth,
                  ),
                  _buildMetricCard(
                    title: "Today's Expenses",
                    value: '$currency${metrics.todayExpenses.toStringAsFixed(2)}',
                    subtext: 'Operational overheads',
                    color: const Color(0xFFDC2626),
                    icon: Icons.payments_rounded,
                    onTapMore: () => onNavigateTab?.call(2),
                    width: cardWidth,
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 24),

          // Two Column Section: Sales Bar Chart + Status Widget
          if (isMobile)
            Column(
              children: [
                chartCard,
                const SizedBox(height: 20),
                statusCard,
              ],
            )
          else
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(flex: 6, child: chartCard),
                const SizedBox(width: 20),
                Expanded(flex: 4, child: statusCard),
              ],
            ),
          const SizedBox(height: 24),

          // Recent Invoices / Activity Table
          Container(
            padding: EdgeInsets.all(isMobile ? 14 : 20),
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
                    const Expanded(
                      child: Text(
                        'Recent Transactions & Invoices',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppTheme.textLight),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    TextButton(
                      onPressed: () => onNavigateTab?.call(1),
                      child: const Text('View All Invoices →'),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                if (metrics.recentInvoices.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 32),
                    child: Center(
                      child: Text('No invoices generated yet. Start billing in Sales tab!',
                          style: TextStyle(color: AppTheme.textMuted)),
                    ),
                  )
                else
                  _buildInvoicesTable(metrics.recentInvoices, currency, isMobile: isMobile),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricCard({
    required String title,
    required String value,
    required String subtext,
    required Color color,
    required IconData icon,
    required VoidCallback onTapMore,
    required double width,
  }) {
    return Container(
      width: width,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.3),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      value,
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    Icon(icon, color: Colors.white.withValues(alpha: 0.6), size: 28),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: Colors.white,
                  ),
                ),
                Text(
                  subtext,
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.white.withValues(alpha: 0.8),
                  ),
                ),
              ],
            ),
          ),
          InkWell(
            onTap: onTapMore,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.15),
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(8),
                  bottomRight: Radius.circular(8),
                ),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'More info',
                    style: TextStyle(fontSize: 12, color: Colors.white, fontWeight: FontWeight.w600),
                  ),
                  SizedBox(width: 6),
                  Icon(Icons.arrow_circle_right_outlined, size: 14, color: Colors.white),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusRow(String label, String value, IconData icon, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Icon(icon, color: color, size: 16),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(fontSize: 11, color: AppTheme.textMuted)),
                Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppTheme.textLight)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSalesBarChart(List<DailySalesPoint> points, String currency) {
    if (points.isEmpty) {
      return const Center(child: Text('No data for sales trend'));
    }

    final maxVal = points.map((p) => p.amount).fold(0.0, (a, b) => a > b ? a : b);
    final effectiveMax = maxVal > 0 ? maxVal : 1000.0;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: points.map((point) {
        final pct = (point.amount / effectiveMax).clamp(0.05, 1.0);
        return Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Text(
                  point.amount > 0 ? '$currency${point.amount.toStringAsFixed(0)}' : '',
                  style: const TextStyle(fontSize: 10, color: AppTheme.accentCyan, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 6),
                Container(
                  height: 140 * pct,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      begin: Alignment.bottomCenter,
                      end: Alignment.topCenter,
                      colors: [Color(0xFF0284C7), Color(0xFF38BDF8)],
                    ),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  point.dateLabel,
                  style: const TextStyle(fontSize: 11, color: AppTheme.textMuted),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildInvoicesTable(List<Invoice> invoices, String currency, {bool isMobile = false}) {
    final tableWidget = Table(
      columnWidths: isMobile
          ? const {
              0: FixedColumnWidth(120),
              1: FixedColumnWidth(110),
              2: FixedColumnWidth(140),
              3: FixedColumnWidth(90),
              4: FixedColumnWidth(100),
              5: FixedColumnWidth(90),
            }
          : const {
              0: FlexColumnWidth(2.2),
              1: FlexColumnWidth(2.2),
              2: FlexColumnWidth(2.6),
              3: FlexColumnWidth(1.8),
              4: FlexColumnWidth(2.0),
              5: FlexColumnWidth(1.8),
            },
      children: [
        TableRow(
          decoration: const BoxDecoration(color: Color(0xFF141F32)),
          children: [
            _buildTableHeader('INVOICE NO'),
            _buildTableHeader('DATE'),
            _buildTableHeader('CUSTOMER'),
            _buildTableHeader('PAYMENT'),
            _buildTableHeader('AMOUNT'),
            _buildTableHeader('STATUS'),
          ],
        ),
        ...invoices.map((inv) {
          final dateStr = DateFormat('dd/MM hh:mm a')
              .format(DateTime.fromMillisecondsSinceEpoch(inv.createdAt * 1000));
          return TableRow(
            decoration: const BoxDecoration(
              border: Border(top: BorderSide(color: AppTheme.cardBorder, width: 0.5)),
            ),
            children: [
              _buildTableCell(inv.invoiceNumber, bold: true, color: AppTheme.accentCyan),
              _buildTableCell(dateStr),
              _buildTableCell(inv.customerName),
              _buildTableCell(inv.paymentMethod),
              _buildTableCell('$currency${inv.grandTotal.toStringAsFixed(2)}', bold: true),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: inv.paymentStatus == 'PAID'
                          ? AppTheme.primaryEmerald.withValues(alpha: 0.2)
                          : AppTheme.accentAmber.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      inv.paymentStatus,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: inv.paymentStatus == 'PAID'
                            ? AppTheme.primaryEmerald
                            : AppTheme.accentAmber,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          );
        }),
      ],
    );

    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: AppTheme.cardBorder),
        borderRadius: BorderRadius.circular(6),
      ),
      child: isMobile
          ? SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: SizedBox(width: 650, child: tableWidget),
            )
          : tableWidget,
    );
  }

  Widget _buildTableHeader(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Text(
        text,
        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.textMuted),
      ),
    );
  }

  Widget _buildTableCell(String text, {bool bold = false, Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 12,
          fontWeight: bold ? FontWeight.bold : FontWeight.normal,
          color: color ?? AppTheme.textLight,
        ),
      ),
    );
  }
}
