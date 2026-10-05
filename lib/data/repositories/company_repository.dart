import '../../core/database/app_database.dart';
import '../models/company_profile.dart';

class CompanyRepository {
  Future<CompanyProfile?> getDefaultCompany() async {
    final db = await AppDatabase.instance;
    final List<Map<String, dynamic>> maps = await db.query(
      'company_profiles',
      where: 'is_default = 1',
      limit: 1,
    );
    if (maps.isNotEmpty) {
      return CompanyProfile.fromMap(maps.first);
    }
    final all = await db.query('company_profiles', limit: 1);
    if (all.isNotEmpty) {
      return CompanyProfile.fromMap(all.first);
    }
    return null;
  }

  Future<void> updateCompany(CompanyProfile profile) async {
    final db = await AppDatabase.instance;
    final map = profile.toMap();
    map['updated_at'] = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    await db.update(
      'company_profiles',
      map,
      where: 'id = ?',
      whereArgs: [profile.id],
    );
  }

  Future<int> getAndIncrementNextInvoiceSeq(String companyId) async {
    final db = await AppDatabase.instance;
    return await db.transaction((txn) async {
      final List<Map<String, dynamic>> result = await txn.query(
        'company_profiles',
        columns: ['invoice_next_seq'],
        where: 'id = ?',
        whereArgs: [companyId],
      );
      final current = result.first['invoice_next_seq'] as int? ?? 1001;
      await txn.update(
        'company_profiles',
        {'invoice_next_seq': current + 1},
        where: 'id = ?',
        whereArgs: [companyId],
      );
      return current;
    });
  }
}
