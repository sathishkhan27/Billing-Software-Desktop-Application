import '../../core/database/app_database.dart';
import '../models/product.dart';

class ProductRepository {
  Future<List<Product>> getAllProducts() async {
    final db = await AppDatabase.instance;
    final List<Map<String, dynamic>> productMaps = await db.query(
      'products',
      where: 'is_active = 1',
      orderBy: 'name ASC',
    );

    final List<Map<String, dynamic>> slabMaps = await db.query('tax_slabs');
    final Map<String, TaxSlab> slabMap = {
      for (final s in slabMaps) s['id'] as String: TaxSlab.fromMap(s),
    };

    return productMaps.map((p) {
      final slab = slabMap[p['tax_slab_id'] as String];
      return Product.fromMap(p, slab: slab);
    }).toList();
  }

  Future<Product?> findByBarcodeOrSku(String code) async {
    final clean = code.trim();
    if (clean.isEmpty) return null;

    final db = await AppDatabase.instance;
    final List<Map<String, dynamic>> maps = await db.query(
      'products',
      where: 'barcode = ? OR sku = ?',
      whereArgs: [clean, clean],
      limit: 1,
    );

    if (maps.isEmpty) return null;

    final productData = maps.first;
    final slabId = productData['tax_slab_id'] as String;

    final List<Map<String, dynamic>> slabMaps = await db.query(
      'tax_slabs',
      where: 'id = ?',
      whereArgs: [slabId],
      limit: 1,
    );

    final slab = slabMaps.isNotEmpty ? TaxSlab.fromMap(slabMaps.first) : null;
    return Product.fromMap(productData, slab: slab);
  }

  Future<List<Product>> searchProducts(String query) async {
    final clean = query.trim();
    if (clean.isEmpty) return getAllProducts();

    final db = await AppDatabase.instance;
    final List<Map<String, dynamic>> productMaps = await db.query(
      'products',
      where: 'is_active = 1 AND (name LIKE ? OR barcode LIKE ? OR sku LIKE ?)',
      whereArgs: ['%$clean%', '%$clean%', '%$clean%'],
      limit: 20,
    );

    final List<Map<String, dynamic>> slabMaps = await db.query('tax_slabs');
    final Map<String, TaxSlab> slabMap = {
      for (final s in slabMaps) s['id'] as String: TaxSlab.fromMap(s),
    };

    return productMaps.map((p) {
      final slab = slabMap[p['tax_slab_id'] as String];
      return Product.fromMap(p, slab: slab);
    }).toList();
  }

  Future<void> createProduct(Product product) async {
    final db = await AppDatabase.instance;
    await db.insert('products', product.toMap());
  }

  Future<void> updateProduct(Product product) async {
    final db = await AppDatabase.instance;
    await db.update(
      'products',
      product.toMap(),
      where: 'id = ?',
      whereArgs: [product.id],
    );
  }

  Future<void> deleteProduct(String productId) async {
    final db = await AppDatabase.instance;
    // Safely remove the product row from the local database
    await db.execute('PRAGMA foreign_keys = OFF;');
    await db.delete(
      'products',
      where: 'id = ?',
      whereArgs: [productId],
    );
    await db.execute('PRAGMA foreign_keys = ON;');
  }

  Future<void> updateStock(String productId, double newQuantity) async {
    final db = await AppDatabase.instance;
    await db.update(
      'products',
      {'stock_quantity': newQuantity},
      where: 'id = ?',
      whereArgs: [productId],
    );
  }

  Future<List<TaxSlab>> getAllTaxSlabs() async {
    final db = await AppDatabase.instance;
    final List<Map<String, dynamic>> maps = await db.query(
      'tax_slabs',
      orderBy: 'rate_percent ASC',
    );
    return maps.map((m) => TaxSlab.fromMap(m)).toList();
  }

  Future<List<Map<String, String>>> getAllCategories() async {
    final db = await AppDatabase.instance;
    final List<Map<String, dynamic>> maps = await db.query(
      'categories',
      orderBy: 'name ASC',
    );
    return maps.map((m) => {
      'id': m['id'] as String,
      'name': m['name'] as String,
    }).toList();
  }

  Future<void> createCategory(String id, String name) async {
    final db = await AppDatabase.instance;
    await db.insert('categories', {
      'id': id,
      'name': name,
    });
  }
}
