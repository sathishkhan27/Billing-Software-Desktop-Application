import 'dart:convert';

class TaxSlab {
  final String id;
  final String name;
  final String? hsnSacCode;
  final double ratePercent;
  final Map<String, double> splitDetails;

  const TaxSlab({
    required this.id,
    required this.name,
    this.hsnSacCode,
    required this.ratePercent,
    required this.splitDetails,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'hsn_sac_code': hsnSacCode,
      'rate_percent': ratePercent,
      'split_details': jsonEncode(splitDetails),
    };
  }

  factory TaxSlab.fromMap(Map<String, dynamic> map) {
    Map<String, double> splits = {};
    if (map['split_details'] != null) {
      try {
        final decoded = jsonDecode(map['split_details'] as String) as Map<String, dynamic>;
        splits = decoded.map((k, v) => MapEntry(k, (v as num).toDouble()));
      } catch (_) {}
    }
    return TaxSlab(
      id: map['id'] as String,
      name: map['name'] as String,
      hsnSacCode: map['hsn_sac_code'] as String?,
      ratePercent: (map['rate_percent'] as num).toDouble(),
      splitDetails: splits,
    );
  }
}

class Product {
  final String id;
  final String? categoryId;
  final String name;
  final String? sku;
  final String? barcode;
  final String taxSlabId;
  final bool isTaxInclusive;
  final String unitOfMeasure;
  final double costPrice;
  final double sellingPrice;
  final double? mrp;
  final double stockQuantity;
  final bool isActive;
  final TaxSlab? taxSlab;

  const Product({
    required this.id,
    this.categoryId,
    required this.name,
    this.sku,
    this.barcode,
    required this.taxSlabId,
    this.isTaxInclusive = true,
    this.unitOfMeasure = 'PCS',
    this.costPrice = 0.0,
    required this.sellingPrice,
    this.mrp,
    this.stockQuantity = 0.0,
    this.isActive = true,
    this.taxSlab,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'category_id': categoryId,
      'name': name,
      'sku': sku,
      'barcode': barcode,
      'tax_slab_id': taxSlabId,
      'is_tax_inclusive': isTaxInclusive ? 1 : 0,
      'unit_of_measure': unitOfMeasure,
      'cost_price': costPrice,
      'selling_price': sellingPrice,
      'mrp': mrp,
      'stock_quantity': stockQuantity,
      'is_active': isActive ? 1 : 0,
    };
  }

  factory Product.fromMap(Map<String, dynamic> map, {TaxSlab? slab}) {
    return Product(
      id: map['id'] as String,
      categoryId: map['category_id'] as String?,
      name: map['name'] as String,
      sku: map['sku'] as String?,
      barcode: map['barcode'] as String?,
      taxSlabId: map['tax_slab_id'] as String,
      isTaxInclusive: (map['is_tax_inclusive'] as int? ?? 1) == 1,
      unitOfMeasure: map['unit_of_measure'] as String? ?? 'PCS',
      costPrice: (map['cost_price'] as num? ?? 0.0).toDouble(),
      sellingPrice: (map['selling_price'] as num).toDouble(),
      mrp: (map['mrp'] as num?)?.toDouble(),
      stockQuantity: (map['stock_quantity'] as num? ?? 0.0).toDouble(),
      isActive: (map['is_active'] as int? ?? 1) == 1,
      taxSlab: slab,
    );
  }

  Product copyWith({
    String? id,
    String? categoryId,
    String? name,
    String? sku,
    String? barcode,
    String? taxSlabId,
    bool? isTaxInclusive,
    String? unitOfMeasure,
    double? costPrice,
    double? sellingPrice,
    double? mrp,
    double? stockQuantity,
    bool? isActive,
    TaxSlab? taxSlab,
  }) {
    return Product(
      id: id ?? this.id,
      categoryId: categoryId ?? this.categoryId,
      name: name ?? this.name,
      sku: sku ?? this.sku,
      barcode: barcode ?? this.barcode,
      taxSlabId: taxSlabId ?? this.taxSlabId,
      isTaxInclusive: isTaxInclusive ?? this.isTaxInclusive,
      unitOfMeasure: unitOfMeasure ?? this.unitOfMeasure,
      costPrice: costPrice ?? this.costPrice,
      sellingPrice: sellingPrice ?? this.sellingPrice,
      mrp: mrp ?? this.mrp,
      stockQuantity: stockQuantity ?? this.stockQuantity,
      isActive: isActive ?? this.isActive,
      taxSlab: taxSlab ?? this.taxSlab,
    );
  }
}
