import 'package:flutter_test/flutter_test.dart';
import 'package:desktop_billing_app/data/models/company_profile.dart';
import 'package:desktop_billing_app/data/models/customer.dart';
import 'package:desktop_billing_app/data/models/invoice.dart';
import 'package:desktop_billing_app/data/models/invoice_template.dart';
import 'package:desktop_billing_app/data/models/product.dart';
import 'package:desktop_billing_app/data/models/purchase.dart';
import 'package:desktop_billing_app/domain/services/tax_calculator.dart';
import 'package:desktop_billing_app/domain/services/template_engine.dart';
import 'package:desktop_billing_app/domain/state/cart_state.dart';

void main() {
  group('TaxCalculator Tests', () {
    test('Calculates inclusive tax and CGST/SGST splits correctly', () {
      const slab = TaxSlab(
        id: 'tax_18',
        name: 'GST 18%',
        ratePercent: 18.0,
        splitDetails: {'cgst': 9.0, 'sgst': 9.0},
      );

      const product = Product(
        id: 'p1',
        name: 'Sample Shampoo',
        sellingPrice: 118.0,
        taxSlabId: 'tax_18',
        isTaxInclusive: true,
        taxSlab: slab,
      );

      final result = TaxCalculator.computeLine(
        product: product,
        quantity: 1.0,
        unitPrice: 118.0,
        discountAmount: 0.0,
      );

      expect(result.taxableAmount, 100.0);
      expect(result.taxAmount, 18.0);
      expect(result.totalLineAmount, 118.0);
      expect(result.splitAmounts['cgst'], 9.0);
      expect(result.splitAmounts['sgst'], 9.0);
    });

    test('Calculates exclusive tax correctly', () {
      const slab = TaxSlab(
        id: 'tax_5',
        name: 'GST 5%',
        ratePercent: 5.0,
        splitDetails: {'cgst': 2.5, 'sgst': 2.5},
      );

      const product = Product(
        id: 'p2',
        name: 'Bread',
        sellingPrice: 100.0,
        taxSlabId: 'tax_5',
        isTaxInclusive: false,
        taxSlab: slab,
      );

      final result = TaxCalculator.computeLine(
        product: product,
        quantity: 2.0,
        unitPrice: 100.0,
        discountAmount: 20.0, // gross base = 180.0
      );

      expect(result.taxableAmount, 180.0);
      expect(result.taxAmount, 9.0); // 5% of 180
      expect(result.totalLineAmount, 189.0);
    });
  });

  group('TemplateEngine Tests', () {
    test('Interpolates placeholders in thermal receipt string', () {
      const company = CompanyProfile(
        id: 'c1',
        tradeName: 'Apex Store',
        legalName: 'Apex Retail Inc',
        branchName: 'Downtown',
        addressLine1: '123 Main St',
        city: 'New York',
        stateProvince: 'NY',
        postalCode: '10001',
        country: 'US',
        phonePrimary: '555-0100',
        taxIdentifier: 'US123456789',
        upiVpa: 'apex@upi',
      );

      const invoice = Invoice(
        id: 'inv_1',
        companyId: 'c1',
        invoiceNumber: 'INV-1001',
        counterId: 'POS-01',
        cashierName: 'Sam',
        subtotal: 100.0,
        taxTotal: 18.0,
        grandTotal: 118.0,
        createdAt: 1774900000,
      );

      const template = InvoiceTemplate(
        id: 't1',
        companyId: 'c1',
        templateName: 'Thermal',
        targetFormat: 'THERMAL_80MM',
        layoutConfig: {},
        headerTemplate: 'Welcome to {{company.trade_name}}! Bill: {{invoice.number}}',
        footerTemplate: 'Total: {{invoice.grand_total}}',
        termsAndConditions: 'All sales final.',
      );

      final rendered = TemplateEngine.interpolate(
        rawTemplate: template.headerTemplate,
        company: company,
        invoice: invoice,
        template: template,
      );

      expect(rendered, contains('Welcome to Apex Store! Bill: INV-1001'));

      final upiUri = TemplateEngine.buildUpiPaymentUri(company: company, invoice: invoice);
      expect(upiUri, contains('upi://pay?pa=apex%40upi'));
      expect(upiUri, contains('am=118.00'));
    });

    test('Reflects company currencySymbol across invoice templates dynamically', () {
      const company = CompanyProfile(
        id: 'c1',
        tradeName: 'Apex Store',
        legalName: 'Apex Retail Inc',
        branchName: 'Downtown',
        addressLine1: '123 Main St',
        city: 'Chennai',
        stateProvince: 'TN',
        postalCode: '600001',
        country: 'IN',
        phonePrimary: '9876543210',
        taxIdentifier: '33AAAAA0000A1Z5',
        currencySymbol: '₹',
        currencyCode: 'INR',
      );

      const invoice = Invoice(
        id: 'inv_1',
        companyId: 'c1',
        invoiceNumber: 'INV-1001',
        counterId: 'POS-01',
        cashierName: 'Cashier',
        subtotal: 100.0,
        taxTotal: 18.0,
        grandTotal: 118.0,
        createdAt: 1774900000,
      );

      const template = InvoiceTemplate(
        id: 't1',
        companyId: 'c1',
        templateName: 'Thermal',
        targetFormat: 'THERMAL_80MM',
        layoutConfig: {},
        headerTemplate: 'Welcome to {{company.trade_name}}!',
        footerTemplate: 'Total: {{invoice.grand_total}} (Subtotal: {{invoice.subtotal}})',
        termsAndConditions: 'Thank you!',
      );

      final rendered = TemplateEngine.interpolate(
        rawTemplate: template.footerTemplate,
        company: company,
        invoice: invoice,
        template: template,
      );

      expect(rendered, contains('Total: ₹118.00 (Subtotal: ₹100.00)'));
    });
  });

  group('Customer & Ledger Tests', () {
    test('Customer model serialization and balance tracking', () {
      const customer = Customer(
        id: 'c_test_01',
        name: 'Ramesh Traders',
        phone: '98250 88990',
        taxNumber: '24AABCR9876P1Z1',
        creditLimit: 50000.0,
        currentBalance: 45906.0,
      );

      final map = customer.toMap();
      expect(map['name'], 'Ramesh Traders');
      expect(map['tax_number'], '24AABCR9876P1Z1');
      expect(map['current_balance'], 45906.0);

      final fromMap = Customer.fromMap(map);
      expect(fromMap.id, 'c_test_01');
      expect(fromMap.currentBalance, 45906.0);
    });
  });

  group('Purchase & Expense Tests', () {
    test('PurchaseItem and Purchase serialization', () {
      const item = PurchaseItem(
        id: 'pi_1',
        purchaseId: 'p_1',
        productId: 'prod_1',
        quantity: 10.0,
        unitCost: 350.0,
        totalAmount: 3500.0,
      );

      final purchase = Purchase(
        id: 'p_1',
        vendorName: 'National Wholesalers',
        purchaseDate: 1774900000,
        subtotal: 3500.0,
        grandTotal: 3500.0,
        createdAt: 1774900000,
        items: [item],
      );

      final map = purchase.toMap();
      expect(map['vendor_name'], 'National Wholesalers');
      expect(map['grand_total'], 3500.0);

      final fromMap = Purchase.fromMap(map, items: [item]);
      expect(fromMap.items.length, 1);
      expect(fromMap.items.first.totalAmount, 3500.0);
    });

    test('Expense model serialization', () {
      const expense = Expense(
        id: 'exp_1',
        title: 'Electricity Bill',
        category: 'Utility',
        amount: 2450.0,
        expenseDate: 1774900000,
        createdAt: 1774900000,
      );

      final map = expense.toMap();
      expect(map['title'], 'Electricity Bill');
      expect(map['amount'], 2450.0);

      final fromMap = Expense.fromMap(map);
      expect(fromMap.amount, 2450.0);
      expect(fromMap.category, 'Utility');
    });
  });

  group('BillPro Retail Options & Logics Tests', () {
    test('Calculates cash tendering and refund change return amount correctly', () {
      const slab = TaxSlab(
        id: 'tax_18',
        name: 'GST 18%',
        ratePercent: 18.0,
        splitDetails: {'cgst': 9.0, 'sgst': 9.0},
      );

      const product = Product(
        id: 'prod_1001',
        name: 'SAMSUNG J7 32 GB',
        sellingPrice: 12000.0,
        taxSlabId: 'tax_18',
        isTaxInclusive: true,
        taxSlab: slab,
      );

      final lineTax = TaxCalculator.computeLine(
        product: product,
        quantity: 1.0,
        unitPrice: 12000.0,
        discountAmount: 0.0,
      );

      final lineItem = CartLineItem(
        product: product,
        quantity: 1.0,
        freeQuantity: 0.0,
        unitPrice: 12000.0,
        mrp: 12000.0,
        uom: 'PCS',
        batchNumber: '898745722',
        taxResult: lineTax,
      );

      const customer = Customer(
        id: 'cust_avinash',
        name: 'AVINASH',
        phone: '98250 99887',
        currentBalance: 32328.0,
      );

      // Customer gives ₹15,500.00 cash for ₹12,000.00 bill
      final cart = CartState(
        items: [lineItem],
        customer: customer,
        cashTendered: 15500.0,
        otherCharges: 0.0,
        invoiceType: 'Local',
      );

      expect(cart.totalUnits, 1.0);
      expect(cart.grandTotal, 12000.0);
      expect(cart.refundAmount, 3500.0); // 15500 - 12000 = 3500 refund / change return!
    });

    test('Computes other charges (freight, packaging) into invoice totals correctly', () {
      final lineResults = [
        const LineTaxResult(
          taxableAmount: 1000.0,
          taxAmount: 180.0,
          totalLineAmount: 1180.0,
          splitAmounts: {'cgst': 90.0, 'sgst': 90.0},
        ),
      ];

      final totals = TaxCalculator.computeInvoiceTotals(
        lineResults: lineResults,
        invoiceDiscount: 0.0,
        otherCharges: 120.0, // e.g. shipping/freight
      );

      // 1180.0 + 120.0 = 1300.0
      expect(totals['grand_total'], 1300.0);
    });

    test('Serializes and deserializes Invoice with BillPro fields', () {
      const item = InvoiceItem(
        id: 'ii_1',
        invoiceId: 'inv_101',
        productId: 'prod_1001',
        productName: 'SAMSUNG J7 32 GB',
        barcode: '1001',
        quantity: 1.0,
        freeQuantity: 1.0, // Buy 1 Get 1 Free
        unitPrice: 12000.0,
        mrp: 12000.0,
        uom: 'PCS',
        batchNumber: 'BATCH-001',
        expiryDate: '12/28',
        discountAmount: 0.0,
        taxableAmount: 10169.49,
        taxRate: 18.0,
        taxAmount: 1830.51,
        totalLineAmount: 12000.0,
      );

      const invoice = Invoice(
        id: 'inv_101',
        companyId: 'c1',
        invoiceNumber: 'INV-1',
        counterId: 'POS-1',
        cashierName: 'ADMINISTRATOR',
        customerId: 'cust_avinash',
        customerName: 'AVINASH',
        customerPhone: '98250 99887',
        subtotal: 10169.49,
        otherCharges: 50.0,
        taxTotal: 1830.51,
        grandTotal: 12050.0,
        cashTendered: 15000.0,
        changeAmount: 2950.0,
        paymentMethod: 'CASH',
        invoiceType: 'Local',
        notes: 'Express delivery',
        createdAt: 1774900000,
        items: [item],
      );

      final invMap = invoice.toMap();
      expect(invMap['invoice_number'], 'INV-1');
      expect(invMap['other_charges'], 50.0);
      expect(invMap['cash_tendered'], 15000.0);
      expect(invMap['change_amount'], 2950.0);
      expect(invMap['invoice_type'], 'Local');

      final fromMap = Invoice.fromMap(invMap, items: [item], customerName: 'AVINASH');
      expect(fromMap.otherCharges, 50.0);
      expect(fromMap.cashTendered, 15000.0);
      expect(fromMap.changeAmount, 2950.0);
      expect(fromMap.items.first.freeQuantity, 1.0);
      expect(fromMap.items.first.batchNumber, 'BATCH-001');
      expect(fromMap.items.first.uom, 'PCS');
    });
  });

  group('Product & Inventory Tests', () {
    test('Calculates profit margin and markup percentages accurately', () {
      const product = Product(
        id: 'prod_test_1',
        name: 'Organic Almond Milk 1L',
        taxSlabId: 'tax_gst_18',
        sellingPrice: 150.0,
        costPrice: 120.0,
        mrp: 160.0,
        stockQuantity: 45.0,
        unitOfMeasure: 'LTR',
      );

      final margin = ((product.sellingPrice - product.costPrice) / product.sellingPrice) * 100;
      final markup = ((product.sellingPrice - product.costPrice) / product.costPrice) * 100;

      expect(margin, closeTo(20.0, 0.01));
      expect(markup, closeTo(25.0, 0.01));
      expect(product.mrp, 160.0);
      expect(product.unitOfMeasure, 'LTR');
    });

    test('Serializes and deserializes Product with all retail pricing fields', () {
      const product = Product(
        id: 'prod_test_2',
        name: 'Aashirvaad Atta 10kg',
        sku: 'AASH-10KG',
        barcode: '8901030000000',
        taxSlabId: 'tax_gst_5',
        sellingPrice: 420.0,
        costPrice: 380.0,
        mrp: 450.0,
        stockQuantity: 8.0,
        unitOfMeasure: 'PACK',
        isTaxInclusive: true,
      );

      final map = product.toMap();
      expect(map['sku'], 'AASH-10KG');
      expect(map['barcode'], '8901030000000');
      expect(map['cost_price'], 380.0);
      expect(map['selling_price'], 420.0);
      expect(map['mrp'], 450.0);
      expect(map['stock_quantity'], 8.0);
      expect(map['unit_of_measure'], 'PACK');

      final restored = Product.fromMap(map);
      expect(restored.name, 'Aashirvaad Atta 10kg');
      expect(restored.costPrice, 380.0);
      expect(restored.sellingPrice, 420.0);
      expect(restored.mrp, 450.0);
      expect(restored.stockQuantity, 8.0);
    });
  });

  group('Draft Billing (Hold & Recall) Tests', () {
    test('DraftInvoice captures state, calculates counts, and preserves metadata', () {
      const product1 = Product(
        id: 'p1',
        name: 'Organic Milk 1L',
        sellingPrice: 60.0,
        costPrice: 48.0,
        mrp: 65.0,
        taxSlabId: 'exempt',
      );

      final line1 = CartLineItem(
        product: product1,
        quantity: 2.0,
        unitPrice: 60.0,
        discountAmount: 0.0,
        taxResult: TaxCalculator.computeLine(
          product: product1,
          quantity: 2.0,
          unitPrice: 60.0,
          discountAmount: 0.0,
        ),
        mrp: 65.0,
        uom: 'LTR',
      );

      final draft = DraftInvoice(
        id: 'draft_101',
        tokenNumber: 'Draft #1',
        createdAt: DateTime.now(),
        customer: const Customer(id: 'c1', name: 'John Doe', phone: '9876543210'),
        items: [line1],
        invoiceDiscount: 10.0,
        otherCharges: 20.0,
        grandTotal: 130.0,
        notes: 'Customer fetching cash',
      );

      expect(draft.id, 'draft_101');
      expect(draft.tokenNumber, 'Draft #1');
      expect(draft.customer?.name, 'John Doe');
      expect(draft.itemCount, 1);
      expect(draft.totalUnits, 2.0);
      expect(draft.grandTotal, 130.0);
      expect(draft.notes, 'Customer fetching cash');
    });

    test('CartState supports heldCarts collection with multiple draft invoices', () {
      final state = CartState(customer: const Customer(id: 'c_default', name: 'Walk-in'));
      expect(state.heldCarts, isEmpty);

      final draft1 = DraftInvoice(
        id: 'd1',
        tokenNumber: 'Draft #1',
        createdAt: DateTime.now(),
        items: const [],
        grandTotal: 150.0,
        notes: 'Hold 1',
      );

      final draft2 = DraftInvoice(
        id: 'd2',
        tokenNumber: 'Draft #2',
        createdAt: DateTime.now(),
        items: const [],
        grandTotal: 250.0,
        notes: 'Hold 2',
      );

      final updatedState = state.copyWith(heldCarts: [draft1, draft2]);
      expect(updatedState.heldCarts.length, 2);
      expect(updatedState.heldCarts.first.tokenNumber, 'Draft #1');
      expect(updatedState.heldCarts.last.notes, 'Hold 2');
    });

    test('Drafts KPI calculations and search filter matching work accurately', () {
      final draft1 = DraftInvoice(
        id: 'd1',
        tokenNumber: 'Draft #1',
        createdAt: DateTime.now(),
        customer: const Customer(id: 'c1', name: 'Alice Smith', phone: '9888812345'),
        items: const [],
        grandTotal: 1200.0,
        notes: 'Counter 1 hold',
      );

      final draft2 = DraftInvoice(
        id: 'd2',
        tokenNumber: 'Draft #2',
        createdAt: DateTime.now(),
        customer: const Customer(id: 'c2', name: 'Bob Jones', phone: '9777754321'),
        items: const [],
        grandTotal: 850.0,
        notes: 'ATM visit',
      );

      final heldList = [draft1, draft2];
      final totalRevenue = heldList.fold(0.0, (sum, d) => sum + d.grandTotal);
      expect(totalRevenue, 2050.0);

      // Search match by customer name
      final filterCust = heldList.where((d) => (d.customer?.name.toLowerCase() ?? '').contains('alice')).toList();
      expect(filterCust.length, 1);
      expect(filterCust.first.tokenNumber, 'Draft #1');

      // Search match by note
      final filterNote = heldList.where((d) => (d.notes?.toLowerCase() ?? '').contains('atm')).toList();
      expect(filterNote.length, 1);
      expect(filterNote.first.tokenNumber, 'Draft #2');
    });
  });
}

