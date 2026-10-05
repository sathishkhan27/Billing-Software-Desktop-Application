import 'package:intl/intl.dart';
import '../../data/models/company_profile.dart';
import '../../data/models/customer.dart';
import '../../data/models/invoice.dart';
import '../../data/models/invoice_template.dart';

class RenderedReceipt {
  final String fullText;
  final String upiPaymentUri;
  final String targetFormat;

  const RenderedReceipt({
    required this.fullText,
    required this.upiPaymentUri,
    required this.targetFormat,
  });
}

class TemplateEngine {
  /// Resolves placeholders in a template string using data from company, invoice, and customer
  static String interpolate({
    required String rawTemplate,
    required CompanyProfile company,
    required Invoice invoice,
    Customer? customer,
    required InvoiceTemplate template,
  }) {
    final currency = company.currencySymbol;
    final date = DateTime.fromMillisecondsSinceEpoch(invoice.createdAt * 1000);
    final dateStr = DateFormat('dd/MM/yyyy').format(date);
    final timeStr = DateFormat('hh:mm a').format(date);

    final customerName = customer?.name ?? invoice.customerName;
    final customerPhone = customer?.phone ?? invoice.customerPhone ?? 'N/A';
    final customerTaxId = customer?.taxNumber ?? 'N/A';

    final totalDiscounts = invoice.itemDiscountTotal + invoice.invoiceDiscountTotal;

    String result = rawTemplate;

    // Company tokens
    result = result.replaceAll('{{company.trade_name}}', company.tradeName);
    result = result.replaceAll('{{company.legal_name}}', company.legalName);
    result = result.replaceAll('{{company.branch}}', company.branchName);
    result = result.replaceAll('{{company.address_full}}', company.fullAddress);
    result = result.replaceAll('{{company.address_line1}}', company.addressLine1);
    result = result.replaceAll('{{company.city}}', company.city);
    result = result.replaceAll('{{company.tax_id}}', company.taxIdentifier);
    result = result.replaceAll('{{company.pan_tax_number}}', company.panTaxNumber ?? 'N/A');
    result = result.replaceAll('{{company.phone}}', company.phonePrimary);
    result = result.replaceAll('{{company.email}}', company.email ?? 'N/A');
    result = result.replaceAll('{{company.website}}', company.website ?? 'N/A');
    result = result.replaceAll('{{company.bank_name}}', company.bankName ?? 'N/A');
    result = result.replaceAll('{{company.bank_account}}', company.bankAccountNumber ?? 'N/A');
    result = result.replaceAll('{{company.bank_ifsc}}', company.bankIfscSwift ?? 'N/A');
    result = result.replaceAll('{{company.upi_vpa}}', company.upiVpa ?? 'N/A');

    // Customer tokens
    result = result.replaceAll('{{customer.name}}', customerName);
    result = result.replaceAll('{{customer.phone}}', customerPhone);
    result = result.replaceAll('{{customer.tax_id}}', customerTaxId);

    // Invoice tokens
    result = result.replaceAll('{{invoice.number}}', invoice.invoiceNumber);
    result = result.replaceAll('{{invoice.date}}', dateStr);
    result = result.replaceAll('{{invoice.time}}', timeStr);
    result = result.replaceAll('{{invoice.cashier}}', invoice.cashierName);
    result = result.replaceAll('{{invoice.counter}}', invoice.counterId);
    result = result.replaceAll('{{invoice.subtotal}}', '$currency${invoice.subtotal.toStringAsFixed(2)}');
    result = result.replaceAll('{{invoice.discounts}}', '$currency${totalDiscounts.toStringAsFixed(2)}');
    result = result.replaceAll('{{invoice.tax_total}}', '$currency${invoice.taxTotal.toStringAsFixed(2)}');
    result = result.replaceAll('{{invoice.round_off}}', '$currency${invoice.roundOff.toStringAsFixed(2)}');
    result = result.replaceAll('{{invoice.grand_total}}', '$currency${invoice.grandTotal.toStringAsFixed(2)}');
    result = result.replaceAll('{{invoice.payment_method}}', invoice.paymentMethod);
    result = result.replaceAll('{{invoice.payment_status}}', invoice.paymentStatus);
    result = result.replaceAll('{{invoice.terms}}', template.termsAndConditions);

    return result;
  }

  /// Generates the standard UPI QR code payment URI string
  static String buildUpiPaymentUri({
    required CompanyProfile company,
    required Invoice invoice,
  }) {
    if (company.upiVpa == null || company.upiVpa!.isEmpty) return '';
    final vpa = Uri.encodeComponent(company.upiVpa!);
    final payeeName = Uri.encodeComponent(company.tradeName);
    final amount = invoice.grandTotal.toStringAsFixed(2);
    final refNote = Uri.encodeComponent(invoice.invoiceNumber);
    return 'upi://pay?pa=$vpa&pn=$payeeName&am=$amount&tn=$refNote&cu=${company.currencyCode}';
  }

  /// Assembles the complete receipt text for thermal printing
  static RenderedReceipt renderThermal({
    required InvoiceTemplate template,
    required CompanyProfile company,
    required Invoice invoice,
    Customer? customer,
  }) {
    final header = interpolate(
      rawTemplate: template.headerTemplate,
      company: company,
      invoice: invoice,
      customer: customer,
      template: template,
    );

    final footer = interpolate(
      rawTemplate: template.footerTemplate,
      company: company,
      invoice: invoice,
      customer: customer,
      template: template,
    );

    // Format line items grid for 3-inch (48 columns) or 2-inch (32 columns)
    final is80mm = template.targetFormat == 'THERMAL_80MM';
    final lineBuffer = StringBuffer();

    lineBuffer.writeln(is80mm
        ? 'Item Name             Qty   Rate   Disc    Amount'
        : 'Item           Qty  Rate  Amount');
    lineBuffer.writeln(is80mm
        ? '------------------------------------------------'
        : '--------------------------------');

    for (final item in invoice.items) {
      if (is80mm) {
        final name = item.productName.length > 20
            ? item.productName.substring(0, 19)
            : item.productName.padRight(21);
        final qty = item.quantity.toStringAsFixed(1).padLeft(5);
        final rate = item.unitPrice.toStringAsFixed(2).padLeft(7);
        final disc = item.discountAmount.toStringAsFixed(2).padLeft(7);
        final amt = item.totalLineAmount.toStringAsFixed(2).padLeft(8);
        lineBuffer.writeln('$name$qty$rate$disc$amt');
      } else {
        final name = item.productName.length > 14
            ? item.productName.substring(0, 13)
            : item.productName.padRight(14);
        final qty = item.quantity.toStringAsFixed(0).padLeft(4);
        final rate = item.unitPrice.toStringAsFixed(2).padLeft(6);
        final amt = item.totalLineAmount.toStringAsFixed(2).padLeft(8);
        lineBuffer.writeln('$name$qty$rate$amt');
      }
    }

    final fullText = '$header\n$lineBuffer$footer';
    final upiUri = buildUpiPaymentUri(company: company, invoice: invoice);

    return RenderedReceipt(
      fullText: fullText,
      upiPaymentUri: upiUri,
      targetFormat: template.targetFormat,
    );
  }
}
