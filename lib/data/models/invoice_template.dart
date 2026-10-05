import 'dart:convert';

class InvoiceTemplate {
  final String id;
  final String companyId;
  final String templateName;
  final String targetFormat; // THERMAL_58MM, THERMAL_80MM, A4_SHEET, A5_SHEET
  final bool isDefault;
  final Map<String, dynamic> layoutConfig;
  final String headerTemplate;
  final String footerTemplate;
  final String termsAndConditions;

  const InvoiceTemplate({
    required this.id,
    required this.companyId,
    required this.templateName,
    required this.targetFormat,
    this.isDefault = false,
    required this.layoutConfig,
    required this.headerTemplate,
    required this.footerTemplate,
    required this.termsAndConditions,
  });

  bool get showLogo => layoutConfig['show_logo'] as bool? ?? true;
  bool get showQr => layoutConfig['show_qr'] as bool? ?? true;
  bool get showHsn => layoutConfig['show_hsn'] as bool? ?? true;
  String get headerAlignment => layoutConfig['header_alignment'] as String? ?? 'CENTER';

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'company_id': companyId,
      'template_name': templateName,
      'target_format': targetFormat,
      'is_default': isDefault ? 1 : 0,
      'layout_config': jsonEncode(layoutConfig),
      'header_template': headerTemplate,
      'footer_template': footerTemplate,
      'terms_and_conditions': termsAndConditions,
    };
  }

  factory InvoiceTemplate.fromMap(Map<String, dynamic> map) {
    Map<String, dynamic> config = {};
    if (map['layout_config'] != null) {
      try {
        config = jsonDecode(map['layout_config'] as String) as Map<String, dynamic>;
      } catch (_) {}
    }

    return InvoiceTemplate(
      id: map['id'] as String,
      companyId: map['company_id'] as String,
      templateName: map['template_name'] as String,
      targetFormat: map['target_format'] as String,
      isDefault: (map['is_default'] as int? ?? 0) == 1,
      layoutConfig: config,
      headerTemplate: map['header_template'] as String? ?? '',
      footerTemplate: map['footer_template'] as String? ?? '',
      termsAndConditions: map['terms_and_conditions'] as String? ?? '',
    );
  }

  InvoiceTemplate copyWith({
    String? templateName,
    String? targetFormat,
    bool? isDefault,
    Map<String, dynamic>? layoutConfig,
    String? headerTemplate,
    String? footerTemplate,
    String? termsAndConditions,
  }) {
    return InvoiceTemplate(
      id: id,
      companyId: companyId,
      templateName: templateName ?? this.templateName,
      targetFormat: targetFormat ?? this.targetFormat,
      isDefault: isDefault ?? this.isDefault,
      layoutConfig: layoutConfig ?? this.layoutConfig,
      headerTemplate: headerTemplate ?? this.headerTemplate,
      footerTemplate: footerTemplate ?? this.footerTemplate,
      termsAndConditions: termsAndConditions ?? this.termsAndConditions,
    );
  }
}
