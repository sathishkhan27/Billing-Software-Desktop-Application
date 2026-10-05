import '../../core/database/app_database.dart';
import '../models/invoice.dart';

class InvoiceRepository {
  Future<void> saveInvoice(Invoice invoice) async {
    final db = await AppDatabase.instance;

    await db.transaction((txn) async {
      // 1. Insert invoice header
      await txn.insert('invoices', invoice.toMap());

      // 2. Insert line items
      for (final item in invoice.items) {
        await txn.insert('invoice_items', item.toMap());

        // 3. Atomically decrement product stock (including free goods)
        await txn.rawUpdate(
          'UPDATE products SET stock_quantity = stock_quantity - ? WHERE id = ?',
          [item.quantity + item.freeQuantity, item.productId],
        );
      }
    });
  }

  Future<List<Invoice>> getRecentInvoices({int limit = 10}) async {
    final db = await AppDatabase.instance;
    final List<Map<String, dynamic>> invoiceMaps = await db.query(
      'invoices',
      orderBy: 'created_at DESC',
      limit: limit,
    );

    final List<Invoice> result = [];
    for (final invMap in invoiceMaps) {
      final invId = invMap['id'] as String;
      final List<Map<String, dynamic>> itemMaps = await db.rawQuery('''
        SELECT ii.*, p.name as product_name, p.barcode
        FROM invoice_items ii
        JOIN products p ON ii.product_id = p.id
        WHERE ii.invoice_id = ?
      ''', [invId]);

      final items = itemMaps.map((im) {
        return InvoiceItem.fromMap(
          im,
          productName: im['product_name'] as String? ?? 'Product',
          barcode: im['barcode'] as String?,
        );
      }).toList();

      result.add(Invoice.fromMap(invMap, items: items));
    }
    return result;
  }
}
