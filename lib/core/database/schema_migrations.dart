class SchemaMigrations {
  static const int currentVersion = 2;

  static const String initialSchema = '''
    CREATE TABLE IF NOT EXISTS company_profiles (
      id TEXT PRIMARY KEY,
      trade_name TEXT NOT NULL,
      legal_name TEXT NOT NULL,
      branch_name TEXT NOT NULL DEFAULT 'Main Branch',
      address_line1 TEXT NOT NULL,
      address_line2 TEXT,
      city TEXT NOT NULL,
      state_province TEXT NOT NULL,
      postal_code TEXT NOT NULL,
      country TEXT NOT NULL DEFAULT 'IN',
      phone_primary TEXT NOT NULL,
      phone_secondary TEXT,
      email TEXT,
      website TEXT,
      tax_identifier TEXT NOT NULL,
      pan_tax_number TEXT,
      bank_name TEXT,
      bank_account_number TEXT,
      bank_ifsc_swift TEXT,
      upi_vpa TEXT,
      currency_symbol TEXT NOT NULL DEFAULT '₹',
      currency_code TEXT NOT NULL DEFAULT 'INR',
      logo_file_path TEXT,
      signature_seal_path TEXT,
      invoice_prefix TEXT NOT NULL DEFAULT 'INV-',
      invoice_next_seq INTEGER NOT NULL DEFAULT 1001,
      is_default INTEGER NOT NULL DEFAULT 1,
      created_at INTEGER NOT NULL,
      updated_at INTEGER NOT NULL
    );

    CREATE TABLE IF NOT EXISTS invoice_templates (
      id TEXT PRIMARY KEY,
      company_id TEXT NOT NULL,
      template_name TEXT NOT NULL,
      target_format TEXT NOT NULL,
      is_default INTEGER NOT NULL DEFAULT 0,
      layout_config TEXT NOT NULL,
      header_template TEXT,
      footer_template TEXT,
      terms_and_conditions TEXT,
      created_at INTEGER NOT NULL,
      FOREIGN KEY(company_id) REFERENCES company_profiles(id) ON DELETE CASCADE
    );

    CREATE TABLE IF NOT EXISTS tax_slabs (
      id TEXT PRIMARY KEY,
      name TEXT NOT NULL,
      hsn_sac_code TEXT,
      rate_percent REAL NOT NULL,
      split_details TEXT
    );

    CREATE TABLE IF NOT EXISTS categories (
      id TEXT PRIMARY KEY,
      name TEXT NOT NULL UNIQUE
    );

    CREATE TABLE IF NOT EXISTS products (
      id TEXT PRIMARY KEY,
      category_id TEXT,
      name TEXT NOT NULL,
      sku TEXT UNIQUE,
      barcode TEXT UNIQUE,
      tax_slab_id TEXT NOT NULL,
      is_tax_inclusive INTEGER NOT NULL DEFAULT 1,
      unit_of_measure TEXT NOT NULL DEFAULT 'PCS',
      cost_price REAL NOT NULL DEFAULT 0.0,
      selling_price REAL NOT NULL DEFAULT 0.0,
      mrp REAL,
      stock_quantity REAL NOT NULL DEFAULT 0.0,
      is_active INTEGER NOT NULL DEFAULT 1,
      FOREIGN KEY(category_id) REFERENCES categories(id),
      FOREIGN KEY(tax_slab_id) REFERENCES tax_slabs(id)
    );

    CREATE TABLE IF NOT EXISTS customers (
      id TEXT PRIMARY KEY,
      name TEXT NOT NULL,
      phone TEXT UNIQUE,
      email TEXT,
      tax_number TEXT,
      credit_limit REAL NOT NULL DEFAULT 0.0,
      current_balance REAL NOT NULL DEFAULT 0.0,
      loyalty_points INTEGER NOT NULL DEFAULT 0,
      created_at INTEGER NOT NULL
    );

    CREATE TABLE IF NOT EXISTS invoices (
      id TEXT PRIMARY KEY,
      company_id TEXT NOT NULL,
      template_id TEXT,
      invoice_number TEXT NOT NULL UNIQUE,
      counter_id TEXT NOT NULL DEFAULT 'POS-1',
      cashier_name TEXT NOT NULL DEFAULT 'Cashier',
      customer_id TEXT,
      subtotal REAL NOT NULL,
      item_discount_total REAL NOT NULL DEFAULT 0.0,
      invoice_discount_total REAL NOT NULL DEFAULT 0.0,
      other_charges REAL NOT NULL DEFAULT 0.0,
      tax_total REAL NOT NULL,
      round_off REAL NOT NULL DEFAULT 0.0,
      grand_total REAL NOT NULL,
      cash_tendered REAL NOT NULL DEFAULT 0.0,
      change_amount REAL NOT NULL DEFAULT 0.0,
      payment_status TEXT NOT NULL,
      payment_method TEXT NOT NULL DEFAULT 'CASH',
      invoice_type TEXT NOT NULL DEFAULT 'Local',
      notes TEXT,
      created_at INTEGER NOT NULL,
      FOREIGN KEY(company_id) REFERENCES company_profiles(id),
      FOREIGN KEY(customer_id) REFERENCES customers(id) ON DELETE SET NULL
    );

    CREATE TABLE IF NOT EXISTS invoice_items (
      id TEXT PRIMARY KEY,
      invoice_id TEXT NOT NULL,
      product_id TEXT NOT NULL,
      quantity REAL NOT NULL,
      free_quantity REAL NOT NULL DEFAULT 0.0,
      unit_price REAL NOT NULL,
      mrp REAL NOT NULL DEFAULT 0.0,
      uom TEXT NOT NULL DEFAULT 'PCS',
      batch_number TEXT,
      expiry_date TEXT,
      discount_amount REAL NOT NULL DEFAULT 0.0,
      taxable_amount REAL NOT NULL,
      tax_rate REAL NOT NULL,
      tax_amount REAL NOT NULL,
      total_line_amount REAL NOT NULL,
      FOREIGN KEY(invoice_id) REFERENCES invoices(id) ON DELETE CASCADE,
      FOREIGN KEY(product_id) REFERENCES products(id)
    );

    CREATE TABLE IF NOT EXISTS purchases (
      id TEXT PRIMARY KEY,
      vendor_name TEXT NOT NULL,
      bill_number TEXT,
      purchase_date INTEGER NOT NULL,
      subtotal REAL NOT NULL,
      tax_total REAL NOT NULL DEFAULT 0.0,
      grand_total REAL NOT NULL,
      payment_status TEXT NOT NULL DEFAULT 'PAID',
      notes TEXT,
      created_at INTEGER NOT NULL
    );

    CREATE TABLE IF NOT EXISTS purchase_items (
      id TEXT PRIMARY KEY,
      purchase_id TEXT NOT NULL,
      product_id TEXT NOT NULL,
      quantity REAL NOT NULL,
      unit_cost REAL NOT NULL,
      tax_rate REAL NOT NULL DEFAULT 0.0,
      total_amount REAL NOT NULL,
      FOREIGN KEY(purchase_id) REFERENCES purchases(id) ON DELETE CASCADE,
      FOREIGN KEY(product_id) REFERENCES products(id)
    );

    CREATE TABLE IF NOT EXISTS expenses (
      id TEXT PRIMARY KEY,
      title TEXT NOT NULL,
      category TEXT NOT NULL DEFAULT 'General',
      amount REAL NOT NULL,
      expense_date INTEGER NOT NULL,
      payment_method TEXT NOT NULL DEFAULT 'CASH',
      notes TEXT,
      created_at INTEGER NOT NULL
    );
  ''';
}
