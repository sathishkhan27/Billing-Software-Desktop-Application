import '../../core/database/app_database.dart';
import '../models/purchase.dart';

class PurchaseRepository {
  Future<void> savePurchase(Purchase purchase) async {
    final db = await AppDatabase.instance;
    await db.transaction((txn) async {
      await txn.insert('purchases', purchase.toMap());
      for (final item in purchase.items) {
        await txn.insert('purchase_items', item.toMap());

        // Inward stock increment
        await txn.rawUpdate(
          'UPDATE products SET stock_quantity = stock_quantity + ? WHERE id = ?',
          [item.quantity, item.productId],
        );
      }
    });
  }

  Future<List<Purchase>> getAllPurchases({int limit = 50}) async {
    final db = await AppDatabase.instance;
    final List<Map<String, dynamic>> maps = await db.query(
      'purchases',
      orderBy: 'purchase_date DESC',
      limit: limit,
    );

    final List<Purchase> list = [];
    for (final map in maps) {
      final pid = map['id'] as String;
      final itemMaps = await db.rawQuery('''
        SELECT pi.*, p.name as product_name
        FROM purchase_items pi
        JOIN products p ON pi.product_id = p.id
        WHERE pi.purchase_id = ?
      ''', [pid]);

      final items = itemMaps.map((im) => PurchaseItem.fromMap(im, productName: im['product_name'] as String? ?? 'Item')).toList();
      list.add(Purchase.fromMap(map, items: items));
    }
    return list;
  }

  Future<void> addExpense(Expense expense) async {
    final db = await AppDatabase.instance;
    await db.insert('expenses', expense.toMap());
  }

  Future<List<Expense>> getExpenses({int limit = 50}) async {
    final db = await AppDatabase.instance;
    final List<Map<String, dynamic>> maps = await db.query(
      'expenses',
      orderBy: 'expense_date DESC',
      limit: limit,
    );
    return maps.map((m) => Expense.fromMap(m)).toList();
  }
}
