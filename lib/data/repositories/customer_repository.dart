import '../../core/database/app_database.dart';
import '../models/customer.dart';

class CustomerRepository {
  Future<List<Customer>> getAllCustomers() async {
    final db = await AppDatabase.instance;
    final List<Map<String, dynamic>> maps = await db.query(
      'customers',
      orderBy: 'name ASC',
    );
    return maps.map((m) => Customer.fromMap(m)).toList();
  }

  Future<Customer?> getCustomerById(String id) async {
    final db = await AppDatabase.instance;
    final List<Map<String, dynamic>> maps = await db.query(
      'customers',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (maps.isEmpty) return null;
    return Customer.fromMap(maps.first);
  }

  Future<List<Customer>> searchCustomers(String query) async {
    final db = await AppDatabase.instance;
    final q = '%${query.trim()}%';
    final List<Map<String, dynamic>> maps = await db.query(
      'customers',
      where: 'name LIKE ? OR phone LIKE ? OR tax_number LIKE ?',
      whereArgs: [q, q, q],
      orderBy: 'name ASC',
      limit: 20,
    );
    return maps.map((m) => Customer.fromMap(m)).toList();
  }

  Future<void> addCustomer(Customer customer) async {
    final db = await AppDatabase.instance;
    await db.insert('customers', customer.toMap());
  }

  Future<void> updateCustomer(Customer customer) async {
    final db = await AppDatabase.instance;
    await db.update(
      'customers',
      customer.toMap(),
      where: 'id = ?',
      whereArgs: [customer.id],
    );
  }

  Future<int> getCustomerInvoiceCount(String customerId) async {
    final db = await AppDatabase.instance;
    final result = await db.rawQuery(
      'SELECT COUNT(*) as count FROM invoices WHERE customer_id = ?',
      [customerId],
    );
    if (result.isNotEmpty && result.first['count'] != null) {
      return (result.first['count'] as num).toInt();
    }
    return 0;
  }

  Future<void> deleteCustomer(String id) async {
    final db = await AppDatabase.instance;
    await db.transaction((txn) async {
      // Safely unlink any existing invoices referencing this customer so foreign key
      // constraints are satisfied and invoice history/turnover records are preserved.
      await txn.update(
        'invoices',
        {'customer_id': null},
        where: 'customer_id = ?',
        whereArgs: [id],
      );
      await txn.delete(
        'customers',
        where: 'id = ?',
        whereArgs: [id],
      );
    });
  }

  Future<void> updateBalance(String id, double delta) async {
    final db = await AppDatabase.instance;
    await db.rawUpdate(
      'UPDATE customers SET current_balance = current_balance + ? WHERE id = ?',
      [delta, id],
    );
  }
}
