import '../../core/database/app_database.dart';
import '../models/invoice.dart';

class DashboardMetrics {
  final double todaySales;
  final int todayInvoiceCount;
  final double accountsBalance;
  final double stockValuation;
  final int totalProducts;
  final double todayExpenses;
  final List<DailySalesPoint> salesTrend;
  final List<Invoice> recentInvoices;

  const DashboardMetrics({
    required this.todaySales,
    required this.todayInvoiceCount,
    required this.accountsBalance,
    required this.stockValuation,
    required this.totalProducts,
    required this.todayExpenses,
    required this.salesTrend,
    required this.recentInvoices,
  });
}

class DailySalesPoint {
  final String dateLabel;
  final double amount;
  final int count;

  const DailySalesPoint({
    required this.dateLabel,
    required this.amount,
    required this.count,
  });
}

class DashboardRepository {
  Future<DashboardMetrics> getMetrics() async {
    final db = await AppDatabase.instance;
    final now = DateTime.now();
    final startOfToday = DateTime(now.year, now.month, now.day).millisecondsSinceEpoch ~/ 1000;

    // 1. Today's Sales
    final todayInvoicesRes = await db.rawQuery('''
      SELECT COUNT(*) as count, COALESCE(SUM(grand_total), 0.0) as total
      FROM invoices
      WHERE created_at >= ?
    ''', [startOfToday]);
    final todayInvoiceCount = (todayInvoicesRes.first['count'] as num? ?? 0).toInt();
    final todaySales = (todayInvoicesRes.first['total'] as num? ?? 0.0).toDouble();

    // 2. All Accounts Balance / Receivables
    final custBalanceRes = await db.rawQuery('''
      SELECT COALESCE(SUM(current_balance), 0.0) as total_due
      FROM customers
    ''');
    final accountsBalance = (custBalanceRes.first['total_due'] as num? ?? 0.0).toDouble();

    // 3. Stock Valuation & Product Count
    final stockRes = await db.rawQuery('''
      SELECT COUNT(*) as count, COALESCE(SUM(stock_quantity * selling_price), 0.0) as valuation
      FROM products
      WHERE is_active = 1
    ''');
    final totalProducts = (stockRes.first['count'] as num? ?? 0).toInt();
    final stockValuation = (stockRes.first['valuation'] as num? ?? 0.0).toDouble();

    // 4. Today's Expenses
    final expRes = await db.rawQuery('''
      SELECT COALESCE(SUM(amount), 0.0) as total
      FROM expenses
      WHERE created_at >= ?
    ''', [startOfToday]);
    final todayExpenses = (expRes.first['total'] as num? ?? 0.0).toDouble();

    // 5. Last 7 to 30 Days Sales Trend
    final List<DailySalesPoint> salesTrend = [];
    for (int i = 6; i >= 0; i--) {
      final day = now.subtract(Duration(days: i));
      final dayStart = DateTime(day.year, day.month, day.day).millisecondsSinceEpoch ~/ 1000;
      final dayEnd = dayStart + 86400;

      final dayRes = await db.rawQuery('''
        SELECT COUNT(*) as count, COALESCE(SUM(grand_total), 0.0) as total
        FROM invoices
        WHERE created_at >= ? AND created_at < ?
      ''', [dayStart, dayEnd]);

      final total = (dayRes.first['total'] as num? ?? 0.0).toDouble();
      final count = (dayRes.first['count'] as num? ?? 0).toInt();
      final label = '${day.day}/${day.month}';
      salesTrend.add(DailySalesPoint(dateLabel: label, amount: total, count: count));
    }

    // 6. Recent Invoices
    final invMaps = await db.rawQuery('''
      SELECT i.*, c.name as customer_name, c.phone as customer_phone
      FROM invoices i
      LEFT JOIN customers c ON i.customer_id = c.id
      ORDER BY i.created_at DESC
      LIMIT 10
    ''');

    final List<Invoice> recent = [];
    for (final m in invMaps) {
      recent.add(Invoice.fromMap(m));
    }

    return DashboardMetrics(
      todaySales: todaySales,
      todayInvoiceCount: todayInvoiceCount,
      accountsBalance: accountsBalance,
      stockValuation: stockValuation,
      totalProducts: totalProducts,
      todayExpenses: todayExpenses,
      salesTrend: salesTrend,
      recentInvoices: recent,
    );
  }
}
