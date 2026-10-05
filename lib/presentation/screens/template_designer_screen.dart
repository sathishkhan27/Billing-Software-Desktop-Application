import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_theme.dart';
import '../../data/models/customer.dart';
import '../../data/models/invoice.dart';
import '../../data/models/invoice_template.dart';
import '../../domain/services/template_engine.dart';
import '../../domain/state/pos_providers.dart';

class TemplateDesignerScreen extends ConsumerStatefulWidget {
  const TemplateDesignerScreen({super.key});

  @override
  ConsumerState<TemplateDesignerScreen> createState() => _TemplateDesignerScreenState();
}

class _TemplateDesignerScreenState extends ConsumerState<TemplateDesignerScreen> {
  late TextEditingController _headerController;
  late TextEditingController _footerController;
  late TextEditingController _termsController;

  InvoiceTemplate? _currentTemplate;
  bool _initialized = false;
  bool _showLogo = true;
  bool _showQr = true;
  bool _showHsn = true;

  void _initControllers(InvoiceTemplate tmpl) {
    if (_initialized) {
      _headerController.dispose();
      _footerController.dispose();
      _termsController.dispose();
    }

    _currentTemplate = tmpl;
    _headerController = TextEditingController(text: tmpl.headerTemplate);
    _footerController = TextEditingController(text: tmpl.footerTemplate);
    _termsController = TextEditingController(text: tmpl.termsAndConditions);
    _showLogo = tmpl.showLogo;
    _showQr = tmpl.showQr;
    _showHsn = tmpl.showHsn;

    _headerController.addListener(() {
      if (mounted) setState(() {});
    });
    _footerController.addListener(() {
      if (mounted) setState(() {});
    });
    _termsController.addListener(() {
      if (mounted) setState(() {});
    });

    _initialized = true;
  }

  @override
  void dispose() {
    if (_initialized) {
      _headerController.dispose();
      _footerController.dispose();
      _termsController.dispose();
    }
    super.dispose();
  }

  void _saveTemplate() async {
    if (_currentTemplate == null) return;

    final updated = _currentTemplate!.copyWith(
      headerTemplate: _headerController.text,
      footerTemplate: _footerController.text,
      termsAndConditions: _termsController.text,
      layoutConfig: {
        'show_logo': _showLogo,
        'show_qr': _showQr,
        'show_hsn': _showHsn,
        'header_alignment': 'CENTER',
      },
    );

    final repo = ref.read(templateRepositoryProvider);
    await repo.updateTemplate(updated);
    _currentTemplate = updated;

    ref.invalidate(activeTemplateProvider);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Invoice template saved successfully!'),
          backgroundColor: AppTheme.primaryEmerald,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final templateAsync = ref.watch(activeTemplateProvider);
    final companyAsync = ref.watch(companyProfileProvider);

    return templateAsync.when(
      loading: () => const Scaffold(
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(color: AppTheme.primaryEmerald),
              SizedBox(height: 16),
              Text(
                'Loading invoice template...',
                style: TextStyle(color: AppTheme.textSecondary),
              ),
            ],
          ),
        ),
      ),
      error: (err, stack) => Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error_outline, color: AppTheme.accentRose, size: 48),
                const SizedBox(height: 16),
                Text(
                  'Failed to load invoice template:\n$err',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: AppTheme.textSecondary),
                ),
                const SizedBox(height: 20),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryEmerald,
                    foregroundColor: Colors.white,
                  ),
                  icon: const Icon(Icons.refresh),
                  label: const Text('Retry Loading'),
                  onPressed: () => ref.refresh(activeTemplateProvider),
                ),
              ],
            ),
          ),
        ),
      ),
      data: (tmpl) {
        if (!_initialized || _currentTemplate?.id != tmpl.id) {
          _initControllers(tmpl);
        }
        final company = companyAsync.value;
        return _buildContent(context, company);
      },
    );
  }

  Widget _buildContent(BuildContext context, dynamic company) {
    final isMobile = AppTheme.isMobile(context);

    final editorPane = SingleChildScrollView(
      padding: EdgeInsets.all(isMobile ? 16 : 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildTokensGuide(),
          const SizedBox(height: 20),
          const Text('Header Template (with {{placeholders}}):', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 6),
          TextField(
            controller: _headerController,
            maxLines: 9,
            style: const TextStyle(fontFamily: 'Courier', fontSize: 12),
            decoration: const InputDecoration(hintText: 'Enter header template with {{placeholders}}'),
          ),
          const SizedBox(height: 16),
          const Text('Footer Template & Payment Section:', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 6),
          TextField(
            controller: _footerController,
            maxLines: 12,
            style: const TextStyle(fontFamily: 'Courier', fontSize: 12),
            decoration: const InputDecoration(hintText: 'Enter footer template'),
          ),
          const SizedBox(height: 16),
          const Text('Terms & Conditions / Store Policies:', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 6),
          TextField(
            controller: _termsController,
            maxLines: 4,
            decoration: const InputDecoration(hintText: 'Enter return & refund policies'),
          ),
          const SizedBox(height: 20),
          const Text('Layout Toggles:', style: TextStyle(fontWeight: FontWeight.bold)),
          SwitchListTile(
            title: const Text('Show Store Logo at Header'),
            value: _showLogo,
            activeTrackColor: AppTheme.primaryEmerald,
            onChanged: (v) => setState(() => _showLogo = v),
          ),
          SwitchListTile(
            title: const Text('Show Dynamic UPI Payment QR Code'),
            value: _showQr,
            activeTrackColor: AppTheme.primaryEmerald,
            onChanged: (v) => setState(() => _showQr = v),
          ),
          SwitchListTile(
            title: const Text('Show HSN/SAC Code on Detailed Bills'),
            value: _showHsn,
            activeTrackColor: AppTheme.primaryEmerald,
            onChanged: (v) => setState(() => _showHsn = v),
          ),
        ],
      ),
    );

    final previewPane = Container(
      color: const Color(0xFF090D16),
      padding: EdgeInsets.all(isMobile ? 12 : 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.visibility, color: AppTheme.accentCyan, size: 18),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Live Thermal Print Preview (Simulated 80mm)',
                  style: TextStyle(fontWeight: FontWeight.bold, color: AppTheme.accentCyan),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Expanded(
            child: Center(
              child: Container(
                width: isMobile ? double.infinity : 380,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF0F172A),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppTheme.cardBorder, width: 2),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.5),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: SingleChildScrollView(
                  child: Text(
                    company != null
                        ? _generateLivePreview(company)
                        : 'Loading company data...',
                    style: const TextStyle(
                      fontFamily: 'Courier',
                      fontSize: 10.5,
                      color: Colors.white,
                      height: 1.35,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );

    final saveButton = isMobile
        ? IconButton(
            icon: const Icon(Icons.save_rounded, color: AppTheme.primaryEmerald),
            tooltip: 'Save Template',
            onPressed: _saveTemplate,
          )
        : ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryEmerald,
              foregroundColor: Colors.white,
            ),
            icon: const Icon(Icons.save),
            label: const Text('Save Template'),
            onPressed: _saveTemplate,
          );

    if (isMobile) {
      return DefaultTabController(
        length: 2,
        child: Scaffold(
          appBar: AppBar(
            backgroundColor: const Color(0xFF0F172A),
            title: const Text('Invoice Template', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
            actions: [
              Padding(
                padding: const EdgeInsets.only(right: 12),
                child: saveButton,
              ),
            ],
            bottom: const TabBar(
              indicatorColor: AppTheme.primaryEmerald,
              labelColor: AppTheme.primaryEmerald,
              unselectedLabelColor: AppTheme.textMuted,
              tabs: [
                Tab(icon: Icon(Icons.edit_note, size: 20), text: 'Editor'),
                Tab(icon: Icon(Icons.visibility, size: 20), text: '80mm Preview'),
              ],
            ),
          ),
          body: TabBarView(
            children: [
              editorPane,
              previewPane,
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F172A),
        title: const Text('Invoice Template Designer (WYSIWYG)'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: saveButton,
          ),
        ],
      ),
      body: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(flex: 6, child: editorPane),
          const VerticalDivider(width: 1, color: AppTheme.cardBorder),
          Expanded(flex: 5, child: previewPane),
        ],
      ),
    );
  }

  Widget _buildTokensGuide() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.cardBg,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.cardBorder),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Available Template Placeholders:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppTheme.accentCyan)),
          SizedBox(height: 6),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              Chip(label: Text('{{company.trade_name}}', style: TextStyle(fontSize: 10))),
              Chip(label: Text('{{company.legal_name}}', style: TextStyle(fontSize: 10))),
              Chip(label: Text('{{company.address_full}}', style: TextStyle(fontSize: 10))),
              Chip(label: Text('{{company.tax_id}}', style: TextStyle(fontSize: 10))),
              Chip(label: Text('{{company.phone}}', style: TextStyle(fontSize: 10))),
              Chip(label: Text('{{company.upi_vpa}}', style: TextStyle(fontSize: 10))),
              Chip(label: Text('{{invoice.number}}', style: TextStyle(fontSize: 10))),
              Chip(label: Text('{{invoice.date}}', style: TextStyle(fontSize: 10))),
              Chip(label: Text('{{invoice.grand_total}}', style: TextStyle(fontSize: 10))),
              Chip(label: Text('{{customer.name}}', style: TextStyle(fontSize: 10))),
            ],
          ),
        ],
      ),
    );
  }

  String _generateLivePreview(dynamic company) {
    final previewTemplate = _currentTemplate!.copyWith(
      headerTemplate: _headerController.text,
      footerTemplate: _footerController.text,
      termsAndConditions: _termsController.text,
    );

    final dummyInvoice = Invoice(
      id: 'preview_01',
      companyId: company.id,
      invoiceNumber: '${company.invoicePrefix}1001',
      counterId: 'Counter 1',
      cashierName: 'Cashier',
      subtotal: 18.00,
      itemDiscountTotal: 0.00,
      taxTotal: 2.16,
      roundOff: 0.00,
      grandTotal: 20.16,
      createdAt: DateTime.now().millisecondsSinceEpoch ~/ 1000,
      items: const [
        InvoiceItem(
          id: '1',
          invoiceId: 'preview_01',
          productId: 'p1',
          productName: 'Sample Item 1',
          quantity: 2.0,
          unitPrice: 5.00,
          taxableAmount: 8.47,
          taxRate: 18.0,
          taxAmount: 1.53,
          totalLineAmount: 10.00,
        ),
        InvoiceItem(
          id: '2',
          invoiceId: 'preview_01',
          productId: 'p2',
          productName: 'Sample Item 2',
          quantity: 1.0,
          unitPrice: 4.00,
          taxableAmount: 3.81,
          taxRate: 5.0,
          taxAmount: 0.19,
          totalLineAmount: 4.00,
        ),
        InvoiceItem(
          id: '3',
          invoiceId: 'preview_01',
          productId: 'p3',
          productName: 'Sample Item 3',
          quantity: 2.0,
          unitPrice: 3.08,
          taxableAmount: 5.22,
          taxRate: 18.0,
          taxAmount: 0.94,
          totalLineAmount: 6.16,
        ),
      ],
    );

    final dummyCustomer = const Customer(
      id: 'c1',
      name: 'Preview Customer',
      phone: '',
      loyaltyPoints: 0,
    );

    final rendered = TemplateEngine.renderThermal(
      template: previewTemplate,
      company: company,
      invoice: dummyInvoice,
      customer: dummyCustomer,
    );

    return rendered.fullText;
  }
}
