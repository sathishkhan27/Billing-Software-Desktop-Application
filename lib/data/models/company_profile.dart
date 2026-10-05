class CompanyProfile {
  final String id;
  final String tradeName;
  final String legalName;
  final String branchName;
  final String addressLine1;
  final String? addressLine2;
  final String city;
  final String stateProvince;
  final String postalCode;
  final String country;
  final String phonePrimary;
  final String? phoneSecondary;
  final String? email;
  final String? website;
  final String taxIdentifier;
  final String? panTaxNumber;
  final String? bankName;
  final String? bankAccountNumber;
  final String? bankIfscSwift;
  final String? upiVpa;
  final String currencySymbol;
  final String currencyCode;
  final String? logoFilePath;
  final String? signatureSealPath;
  final String invoicePrefix;
  final int invoiceNextSeq;
  final bool isDefault;

  const CompanyProfile({
    required this.id,
    required this.tradeName,
    required this.legalName,
    required this.branchName,
    required this.addressLine1,
    this.addressLine2,
    required this.city,
    required this.stateProvince,
    required this.postalCode,
    required this.country,
    required this.phonePrimary,
    this.phoneSecondary,
    this.email,
    this.website,
    required this.taxIdentifier,
    this.panTaxNumber,
    this.bankName,
    this.bankAccountNumber,
    this.bankIfscSwift,
    this.upiVpa,
    this.currencySymbol = '₹',
    this.currencyCode = 'INR',
    this.logoFilePath,
    this.signatureSealPath,
    this.invoicePrefix = 'INV-',
    this.invoiceNextSeq = 1,
    this.isDefault = true,
  });

  String get fullAddress {
    final buffer = StringBuffer(addressLine1);
    if (addressLine2 != null && addressLine2!.isNotEmpty) {
      buffer.write(', $addressLine2');
    }
    buffer.write(', $city, $stateProvince $postalCode, $country');
    return buffer.toString();
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'trade_name': tradeName,
      'legal_name': legalName,
      'branch_name': branchName,
      'address_line1': addressLine1,
      'address_line2': addressLine2,
      'city': city,
      'state_province': stateProvince,
      'postal_code': postalCode,
      'country': country,
      'phone_primary': phonePrimary,
      'phone_secondary': phoneSecondary,
      'email': email,
      'website': website,
      'tax_identifier': taxIdentifier,
      'pan_tax_number': panTaxNumber,
      'bank_name': bankName,
      'bank_account_number': bankAccountNumber,
      'bank_ifsc_swift': bankIfscSwift,
      'upi_vpa': upiVpa,
      'currency_symbol': currencySymbol,
      'currency_code': currencyCode,
      'logo_file_path': logoFilePath,
      'signature_seal_path': signatureSealPath,
      'invoice_prefix': invoicePrefix,
      'invoice_next_seq': invoiceNextSeq,
      'is_default': isDefault ? 1 : 0,
    };
  }

  factory CompanyProfile.fromMap(Map<String, dynamic> map) {
    return CompanyProfile(
      id: map['id'] as String,
      tradeName: map['trade_name'] as String? ?? '',
      legalName: map['legal_name'] as String? ?? '',
      branchName: map['branch_name'] as String? ?? '',
      addressLine1: map['address_line1'] as String? ?? '',
      addressLine2: map['address_line2'] as String?,
      city: map['city'] as String? ?? '',
      stateProvince: map['state_province'] as String? ?? '',
      postalCode: map['postal_code'] as String? ?? '',
      country: map['country'] as String? ?? '',
      phonePrimary: map['phone_primary'] as String? ?? '',
      phoneSecondary: map['phone_secondary'] as String?,
      email: map['email'] as String?,
      website: map['website'] as String?,
      taxIdentifier: map['tax_identifier'] as String? ?? '',
      panTaxNumber: map['pan_tax_number'] as String?,
      bankName: map['bank_name'] as String?,
      bankAccountNumber: map['bank_account_number'] as String?,
      bankIfscSwift: map['bank_ifsc_swift'] as String?,
      upiVpa: map['upi_vpa'] as String?,
      currencySymbol: map['currency_symbol'] as String? ?? '₹',
      currencyCode: map['currency_code'] as String? ?? 'INR',
      logoFilePath: map['logo_file_path'] as String?,
      signatureSealPath: map['signature_seal_path'] as String?,
      invoicePrefix: map['invoice_prefix'] as String? ?? 'INV-',
      invoiceNextSeq: map['invoice_next_seq'] as int? ?? 1,
      isDefault: (map['is_default'] as int? ?? 1) == 1,
    );
  }

  CompanyProfile copyWith({
    String? tradeName,
    String? legalName,
    String? branchName,
    String? addressLine1,
    String? addressLine2,
    String? city,
    String? stateProvince,
    String? postalCode,
    String? country,
    String? phonePrimary,
    String? phoneSecondary,
    String? email,
    String? website,
    String? taxIdentifier,
    String? panTaxNumber,
    String? bankName,
    String? bankAccountNumber,
    String? bankIfscSwift,
    String? upiVpa,
    String? currencySymbol,
    String? currencyCode,
    String? logoFilePath,
    String? signatureSealPath,
    String? invoicePrefix,
    int? invoiceNextSeq,
  }) {
    return CompanyProfile(
      id: id,
      tradeName: tradeName ?? this.tradeName,
      legalName: legalName ?? this.legalName,
      branchName: branchName ?? this.branchName,
      addressLine1: addressLine1 ?? this.addressLine1,
      addressLine2: addressLine2 ?? this.addressLine2,
      city: city ?? this.city,
      stateProvince: stateProvince ?? this.stateProvince,
      postalCode: postalCode ?? this.postalCode,
      country: country ?? this.country,
      phonePrimary: phonePrimary ?? this.phonePrimary,
      phoneSecondary: phoneSecondary ?? this.phoneSecondary,
      email: email ?? this.email,
      website: website ?? this.website,
      taxIdentifier: taxIdentifier ?? this.taxIdentifier,
      panTaxNumber: panTaxNumber ?? this.panTaxNumber,
      bankName: bankName ?? this.bankName,
      bankAccountNumber: bankAccountNumber ?? this.bankAccountNumber,
      bankIfscSwift: bankIfscSwift ?? this.bankIfscSwift,
      upiVpa: upiVpa ?? this.upiVpa,
      currencySymbol: currencySymbol ?? this.currencySymbol,
      currencyCode: currencyCode ?? this.currencyCode,
      logoFilePath: logoFilePath ?? this.logoFilePath,
      signatureSealPath: signatureSealPath ?? this.signatureSealPath,
      invoicePrefix: invoicePrefix ?? this.invoicePrefix,
      invoiceNextSeq: invoiceNextSeq ?? this.invoiceNextSeq,
      isDefault: isDefault,
    );
  }
}
