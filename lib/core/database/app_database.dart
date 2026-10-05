import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:io' show Platform, Directory;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:sqflite_common_ffi_web/sqflite_ffi_web.dart';
import 'schema_migrations.dart';

class AppDatabase {
  static Database? _database;

  static Future<Database> get instance async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  static Future<Database> _initDatabase() async {
    // Platform-specific database factory setup:
    // 1. Web: IndexedDB-backed persistence via sqflite_common_ffi_web
    // 2. Desktop (macOS / Windows / Linux): sqflite_common_ffi via native SQLite C library
    // 3. Mobile (Android & iOS): sqflite native platform-channel factory (built-in)
    if (kIsWeb) {
      databaseFactory = databaseFactoryFfiWeb;
    } else if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      _setupDesktopFactory();
    } else {
      // Android / iOS: Default native sqflite databaseFactory is used directly.
      // We explicitly avoid overriding databaseFactory with FFI on mobile devices.
    }

    // Determine database path based on platform
    final String dbPath;
    if (kIsWeb) {
      // Web: just use a name — the web factory handles IndexedDB storage
      dbPath = 'billing_store.db';
    } else {
      final docsDir = await getApplicationDocumentsDirectory();
      final dbDirPath = p.join(docsDir.path, 'AntigravityBilling');
      final dbDir = await _createDirectory(dbDirPath);
      dbPath = p.join(dbDir, 'billing_store.db');
    }

    final db = await databaseFactory.openDatabase(
      dbPath,
      options: OpenDatabaseOptions(
        version: SchemaMigrations.currentVersion,
        onConfigure: (db) async {
          // PRAGMA foreign_keys is not supported on web
          if (!kIsWeb) {
            await db.execute('PRAGMA foreign_keys = ON');
          }
        },
        onCreate: (db, version) async {
          await _executeStatements(db, SchemaMigrations.initialSchema);
          await _seedInitialData(db);
        },
        onUpgrade: (db, oldVersion, newVersion) async {
          await _executeStatements(db, SchemaMigrations.initialSchema);
        },
        onOpen: (db) async {
          // Idempotent safeguard: ensures newly added tables and columns
          // are created immediately even on databases opened earlier
          await _executeStatements(db, SchemaMigrations.initialSchema);
          await _migrateNewColumns(db);
          await _cleanLegacyDemoData(db);
        },
      ),
    );

    return db;
  }

  /// Sets up sqflite_common_ffi for desktop platforms (macOS/Windows/Linux).
  /// This method intentionally uses dart:io; it is never called on web.
  static void _setupDesktopFactory() {
    // ignore: avoid_dynamic_calls
    try {
      // Only applies to macOS / Windows / Linux
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    } catch (_) {
      // Android & iOS: sqflite factory is already the default — no setup needed
    }
  }

  /// Creates a directory at [path] and returns its path string.
  /// This is extracted so the web build never sees a direct Directory() call.
  static Future<String> _createDirectory(String path) async {
    // ignore: avoid_slow_async_io
    final dir = await Directory(path).create(recursive: true);
    return dir.path;
  }

  static Future<void> _migrateNewColumns(Database db) async {
    final invoiceColumns = [
      'ALTER TABLE invoices ADD COLUMN other_charges REAL NOT NULL DEFAULT 0.0',
      'ALTER TABLE invoices ADD COLUMN cash_tendered REAL NOT NULL DEFAULT 0.0',
      'ALTER TABLE invoices ADD COLUMN change_amount REAL NOT NULL DEFAULT 0.0',
      'ALTER TABLE invoices ADD COLUMN notes TEXT',
    ];
    for (final colSql in invoiceColumns) {
      try {
        await db.execute(colSql);
      } catch (_) {}
    }

    final itemColumns = [
      'ALTER TABLE invoice_items ADD COLUMN free_quantity REAL NOT NULL DEFAULT 0.0',
      'ALTER TABLE invoice_items ADD COLUMN mrp REAL NOT NULL DEFAULT 0.0',
      'ALTER TABLE invoice_items ADD COLUMN uom TEXT NOT NULL DEFAULT "PCS"',
      'ALTER TABLE invoice_items ADD COLUMN batch_number TEXT',
      'ALTER TABLE invoice_items ADD COLUMN expiry_date TEXT',
    ];
    for (final colSql in itemColumns) {
      try {
        await db.execute(colSql);
      } catch (_) {}
    }
  }

  static Future<void> _executeStatements(Database db, String schemaSql) async {
    final statements = schemaSql
        .split(';')
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty);

    for (final statement in statements) {
      if (statement.toUpperCase().contains('JOURNAL_MODE')) {
        continue; // Cannot execute PRAGMA journal_mode from within a transaction
      }
      await db.execute(statement);
    }
  }

  static Future<void> _safeInsert(Database db, String table, Map<String, dynamic> values) async {
    await db.insert(table, values, conflictAlgorithm: ConflictAlgorithm.ignore);
  }

  static Future<void> _seedInitialData(Database db) async {
    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;

    // 1. Seed blank company profile — user must fill via Company Settings
    await _safeInsert(db, 'company_profiles', {
      'id': 'comp_default_01',
      'trade_name': '',
      'legal_name': '',
      'branch_name': '',
      'address_line1': '',
      'address_line2': null,
      'city': '',
      'state_province': '',
      'postal_code': '',
      'country': '',
      'phone_primary': '',
      'phone_secondary': null,
      'email': null,
      'website': null,
      'tax_identifier': '',
      'pan_tax_number': null,
      'bank_name': null,
      'bank_account_number': null,
      'bank_ifsc_swift': null,
      'upi_vpa': null,
      'currency_symbol': '₹',
      'currency_code': 'INR',
      'logo_file_path': null,
      'signature_seal_path': null,
      'invoice_prefix': 'INV-',
      'invoice_next_seq': 1,
      'is_default': 1,
      'created_at': now,
      'updated_at': now,
    });

    // 2. Seed Default Invoice Template
    await _safeInsert(db, 'invoice_templates', {
      'id': 'tmpl_thermal_80',
      'company_id': 'comp_default_01',
      'template_name': 'Standard 3-Inch (80mm) Thermal',
      'target_format': 'THERMAL_80MM',
      'is_default': 1,
      'layout_config': '{"show_logo": true, "show_qr": true, "show_hsn": true, "header_alignment": "CENTER"}',
      'header_template': '''
================================
       {{company.trade_name}}
       {{company.address_full}}
  GSTIN: {{company.tax_id}} | Ph: {{company.phone}}
================================
Bill No: {{invoice.number}}   Date: {{invoice.date}} {{invoice.time}}
Cashier: {{invoice.cashier}}  Counter: {{invoice.counter}}
Customer: {{customer.name}}
--------------------------------''',
      'footer_template': '''
--------------------------------
Subtotal:                    {{invoice.subtotal}}
Discounts:                  -{{invoice.discounts}}
GST Total:                   {{invoice.tax_total}}
Round Off:                   {{invoice.round_off}}
--------------------------------
GRAND TOTAL:                 {{invoice.grand_total}}
--------------------------------
Paid via: {{invoice.payment_method}} ({{invoice.grand_total}})

         [ DYNAMIC QR CODE ]
        Scan to Pay via UPI
        {{company.upi_vpa}}

    Thank you for shopping with us!
================================''',
      'terms_and_conditions': '1. Goods once sold can be exchanged within 7 days.\n2. Invoices are computer generated and GST compliant.',
      'created_at': now,
    });

    // 3. Seed Standard GST Tax Slabs (system configuration, not demo data)
    await _safeInsert(db, 'tax_slabs', {
      'id': 'tax_gst_0',
      'name': 'Exempt (0%)',
      'hsn_sac_code': '0000',
      'rate_percent': 0.0,
      'split_details': '{"cgst": 0.0, "sgst": 0.0}',
    });
    await _safeInsert(db, 'tax_slabs', {
      'id': 'tax_gst_5',
      'name': 'GST 5%',
      'hsn_sac_code': '1905',
      'rate_percent': 5.0,
      'split_details': '{"cgst": 2.5, "sgst": 2.5}',
    });
    await _safeInsert(db, 'tax_slabs', {
      'id': 'tax_gst_12',
      'name': 'GST 12%',
      'hsn_sac_code': '2106',
      'rate_percent': 12.0,
      'split_details': '{"cgst": 6.0, "sgst": 6.0}',
    });
    await _safeInsert(db, 'tax_slabs', {
      'id': 'tax_gst_18',
      'name': 'GST 18%',
      'hsn_sac_code': '3305',
      'rate_percent': 18.0,
      'split_details': '{"cgst": 9.0, "sgst": 9.0}',
    });
    await _safeInsert(db, 'tax_slabs', {
      'id': 'tax_gst_28',
      'name': 'GST 28%',
      'hsn_sac_code': '8418',
      'rate_percent': 28.0,
      'split_details': '{"cgst": 14.0, "sgst": 14.0}',
    });

    // 4. Seed default product categories
    await _safeInsert(db, 'categories', {'id': 'cat_general', 'name': 'General'});
    await _safeInsert(db, 'categories', {'id': 'cat_grocery', 'name': 'Groceries'});
    await _safeInsert(db, 'categories', {'id': 'cat_electronics', 'name': 'Electronics'});
  }

  static Future<void> _cleanLegacyDemoData(Database db) async {
    try {
      // 1. Remove legacy demo invoices and their line items
      await db.delete('invoice_items', where: "invoice_id IN ('inv_sample_01', 'inv_sample_02')");
      await db.delete('invoices', where: "id IN ('inv_sample_01', 'inv_sample_02')");

      // 2. Unlink any invoices referencing legacy demo customers, then delete demo customers
      await db.update(
        'invoices',
        {'customer_id': null},
        where: "customer_id IN ('cust_ramesh', 'cust_patel', 'cust_avinash', 'cust_walkin')",
      );
      await db.delete(
        'customers',
        where: "id IN ('cust_ramesh', 'cust_patel', 'cust_avinash', 'cust_walkin')",
      );

      // 3. Remove hardcoded demo products
      final demoProductIds = [
        'prod_1001', 'prod_1002', 'prod_1003', 'prod_1004', 'prod_1005',
        'prod_1006', 'prod_1007', 'prod_1008', 'prod_1009',
        'prod_001', 'prod_002', 'prod_003', 'prod_004', 'prod_005',
      ];
      final placeholders = List.filled(demoProductIds.length, '?').join(',');
      await db.delete('products', where: "id IN ($placeholders)", whereArgs: demoProductIds);

      // 4. Clear legacy fake company profile data on existing installations.
      //    Only wipe if trade_name still contains old seeded demo values.
      final existing = await db.query(
        'company_profiles',
        columns: ['id', 'trade_name'],
        where: "id = 'comp_default_01'",
        limit: 1,
      );
      if (existing.isNotEmpty) {
        final name = existing.first['trade_name'] as String? ?? '';
        if (name == 'My Business Store') {
          final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
          await db.update(
            'company_profiles',
            {
              'trade_name': '',
              'legal_name': '',
              'branch_name': '',
              'address_line1': '',
              'address_line2': null,
              'city': '',
              'state_province': '',
              'postal_code': '',
              'country': '',
              'phone_primary': '',
              'phone_secondary': null,
              'email': null,
              'website': null,
              'tax_identifier': '',
              'pan_tax_number': null,
              'bank_name': null,
              'bank_account_number': null,
              'bank_ifsc_swift': null,
              'upi_vpa': null,
              'invoice_next_seq': 1,
              'updated_at': now,
            },
            where: "id = 'comp_default_01'",
          );
        }
      }
    } catch (_) {
      // Non-critical safeguard
    }
  }
}
