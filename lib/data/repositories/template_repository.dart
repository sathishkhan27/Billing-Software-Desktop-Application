import '../../core/database/app_database.dart';
import '../models/invoice_template.dart';

class TemplateRepository {
  Future<List<InvoiceTemplate>> getTemplatesForCompany(String companyId) async {
    final db = await AppDatabase.instance;
    final List<Map<String, dynamic>> maps = await db.query(
      'invoice_templates',
      where: 'company_id = ?',
      whereArgs: [companyId],
    );
    return maps.map((m) => InvoiceTemplate.fromMap(m)).toList();
  }

  Future<InvoiceTemplate?> getDefaultTemplate(String companyId) async {
    final db = await AppDatabase.instance;
    final List<Map<String, dynamic>> maps = await db.query(
      'invoice_templates',
      where: 'company_id = ? AND is_default = 1',
      limit: 1,
      whereArgs: [companyId],
    );
    if (maps.isNotEmpty) {
      return InvoiceTemplate.fromMap(maps.first);
    }
    final all = await db.query(
      'invoice_templates',
      where: 'company_id = ?',
      limit: 1,
      whereArgs: [companyId],
    );
    if (all.isNotEmpty) {
      return InvoiceTemplate.fromMap(all.first);
    }
    return null;
  }

  Future<void> updateTemplate(InvoiceTemplate template) async {
    final db = await AppDatabase.instance;
    await db.update(
      'invoice_templates',
      template.toMap(),
      where: 'id = ?',
      whereArgs: [template.id],
    );
  }
}
