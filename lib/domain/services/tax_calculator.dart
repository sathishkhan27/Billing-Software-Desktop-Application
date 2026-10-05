import '../../data/models/product.dart';

class LineTaxResult {
  final double taxableAmount;
  final double taxAmount;
  final double totalLineAmount;
  final Map<String, double> splitAmounts;

  const LineTaxResult({
    required this.taxableAmount,
    required this.taxAmount,
    required this.totalLineAmount,
    required this.splitAmounts,
  });
}

class TaxCalculator {
  /// Computes line item calculations taking into account quantity, rate, discount,
  /// and whether the selling price is tax-inclusive or tax-exclusive.
  static LineTaxResult computeLine({
    required Product product,
    required double quantity,
    required double unitPrice,
    required double discountAmount, // flat discount on the line
  }) {
    final taxRate = product.taxSlab?.ratePercent ?? 0.0;
    final splits = product.taxSlab?.splitDetails ?? {};

    final grossBase = (quantity * unitPrice) - discountAmount;
    final effectiveGross = grossBase < 0 ? 0.0 : grossBase;

    double taxableAmount;
    double taxAmount;
    double totalLineAmount;

    if (product.isTaxInclusive) {
      if (taxRate > 0) {
        // Price = Taxable + (Taxable * Rate / 100) => Taxable = Price / (1 + Rate/100)
        taxableAmount = double.parse((effectiveGross / (1.0 + (taxRate / 100.0))).toStringAsFixed(2));
        taxAmount = double.parse((effectiveGross - taxableAmount).toStringAsFixed(2));
        totalLineAmount = effectiveGross;
      } else {
        taxableAmount = effectiveGross;
        taxAmount = 0.0;
        totalLineAmount = effectiveGross;
      }
    } else {
      // Tax exclusive
      taxableAmount = effectiveGross;
      taxAmount = double.parse((taxableAmount * (taxRate / 100.0)).toStringAsFixed(2));
      totalLineAmount = taxableAmount + taxAmount;
    }

    final Map<String, double> splitAmounts = {};
    for (final entry in splits.entries) {
      final splitRate = entry.value;
      if (taxRate > 0) {
        final splitAmt = double.parse((taxAmount * (splitRate / taxRate)).toStringAsFixed(2));
        splitAmounts[entry.key] = splitAmt;
      } else {
        splitAmounts[entry.key] = 0.0;
      }
    }

    return LineTaxResult(
      taxableAmount: taxableAmount,
      taxAmount: taxAmount,
      totalLineAmount: double.parse(totalLineAmount.toStringAsFixed(2)),
      splitAmounts: splitAmounts,
    );
  }

  /// Calculates invoice totals, round off, and tax aggregates
  static Map<String, dynamic> computeInvoiceTotals({
    required List<LineTaxResult> lineResults,
    double invoiceDiscount = 0.0,
    double otherCharges = 0.0,
  }) {
    double subtotal = 0.0;
    double taxTotal = 0.0;
    double grossTotal = 0.0;
    final Map<String, double> aggregatedSplits = {};

    for (final res in lineResults) {
      subtotal += res.taxableAmount;
      taxTotal += res.taxAmount;
      grossTotal += res.totalLineAmount;

      res.splitAmounts.forEach((k, v) {
        aggregatedSplits[k] = (aggregatedSplits[k] ?? 0.0) + v;
      });
    }

    final effectiveGross = (grossTotal - invoiceDiscount + otherCharges).clamp(0.0, double.infinity);
    final roundedTotal = effectiveGross.roundToDouble();
    final roundOff = double.parse((roundedTotal - effectiveGross).toStringAsFixed(2));

    return {
      'subtotal': double.parse(subtotal.toStringAsFixed(2)),
      'tax_total': double.parse(taxTotal.toStringAsFixed(2)),
      'grand_total': roundedTotal,
      'round_off': roundOff,
      'aggregated_splits': aggregatedSplits,
    };
  }
}
