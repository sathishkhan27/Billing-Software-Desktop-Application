import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_theme.dart';
import '../../data/models/company_profile.dart';
import '../../domain/state/pos_providers.dart';

class CompanySettingsScreen extends ConsumerStatefulWidget {
  const CompanySettingsScreen({super.key});

  @override
  ConsumerState<CompanySettingsScreen> createState() => _CompanySettingsScreenState();
}

class _CompanySettingsScreenState extends ConsumerState<CompanySettingsScreen> {
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _tradeNameController;
  late TextEditingController _legalNameController;
  late TextEditingController _branchController;
  late TextEditingController _address1Controller;
  late TextEditingController _address2Controller;
  late TextEditingController _cityController;
  late TextEditingController _stateController;
  late TextEditingController _postalController;
  late TextEditingController _phoneController;
  late TextEditingController _emailController;
  late TextEditingController _websiteController;
  late TextEditingController _taxIdController;
  late TextEditingController _panController;
  late TextEditingController _bankNameController;
  late TextEditingController _bankAccountController;
  late TextEditingController _bankIfscController;
  late TextEditingController _upiVpaController;
  late TextEditingController _currencySymbolController;
  late TextEditingController _invoicePrefixController;

  CompanyProfile? _currentProfile;
  bool _initialized = false;

  void _initControllers(CompanyProfile profile) {
    if (_initialized) {
      _tradeNameController.dispose();
      _legalNameController.dispose();
      _branchController.dispose();
      _address1Controller.dispose();
      _address2Controller.dispose();
      _cityController.dispose();
      _stateController.dispose();
      _postalController.dispose();
      _phoneController.dispose();
      _emailController.dispose();
      _websiteController.dispose();
      _taxIdController.dispose();
      _panController.dispose();
      _bankNameController.dispose();
      _bankAccountController.dispose();
      _bankIfscController.dispose();
      _upiVpaController.dispose();
      _currencySymbolController.dispose();
      _invoicePrefixController.dispose();
    }

    _currentProfile = profile;
    _tradeNameController = TextEditingController(text: profile.tradeName);
    _legalNameController = TextEditingController(text: profile.legalName);
    _branchController = TextEditingController(text: profile.branchName);
    _address1Controller = TextEditingController(text: profile.addressLine1);
    _address2Controller = TextEditingController(text: profile.addressLine2 ?? '');
    _cityController = TextEditingController(text: profile.city);
    _stateController = TextEditingController(text: profile.stateProvince);
    _postalController = TextEditingController(text: profile.postalCode);
    _phoneController = TextEditingController(text: profile.phonePrimary);
    _emailController = TextEditingController(text: profile.email ?? '');
    _websiteController = TextEditingController(text: profile.website ?? '');
    _taxIdController = TextEditingController(text: profile.taxIdentifier);
    _panController = TextEditingController(text: profile.panTaxNumber ?? '');
    _bankNameController = TextEditingController(text: profile.bankName ?? '');
    _bankAccountController = TextEditingController(text: profile.bankAccountNumber ?? '');
    _bankIfscController = TextEditingController(text: profile.bankIfscSwift ?? '');
    _upiVpaController = TextEditingController(text: profile.upiVpa ?? '');
    _currencySymbolController = TextEditingController(text: profile.currencySymbol);
    _invoicePrefixController = TextEditingController(text: profile.invoicePrefix);
    _initialized = true;
  }

  @override
  void dispose() {
    if (_initialized) {
      _tradeNameController.dispose();
      _legalNameController.dispose();
      _branchController.dispose();
      _address1Controller.dispose();
      _address2Controller.dispose();
      _cityController.dispose();
      _stateController.dispose();
      _postalController.dispose();
      _phoneController.dispose();
      _emailController.dispose();
      _websiteController.dispose();
      _taxIdController.dispose();
      _panController.dispose();
      _bankNameController.dispose();
      _bankAccountController.dispose();
      _bankIfscController.dispose();
      _upiVpaController.dispose();
      _currencySymbolController.dispose();
      _invoicePrefixController.dispose();
    }
    super.dispose();
  }

  void _saveProfile() async {
    if (!_formKey.currentState!.validate() || _currentProfile == null) return;

    final updated = _currentProfile!.copyWith(
      tradeName: _tradeNameController.text.trim(),
      legalName: _legalNameController.text.trim(),
      branchName: _branchController.text.trim(),
      addressLine1: _address1Controller.text.trim(),
      addressLine2: _address2Controller.text.trim().isEmpty ? null : _address2Controller.text.trim(),
      city: _cityController.text.trim(),
      stateProvince: _stateController.text.trim(),
      postalCode: _postalController.text.trim(),
      phonePrimary: _phoneController.text.trim(),
      email: _emailController.text.trim().isEmpty ? null : _emailController.text.trim(),
      website: _websiteController.text.trim().isEmpty ? null : _websiteController.text.trim(),
      taxIdentifier: _taxIdController.text.trim(),
      panTaxNumber: _panController.text.trim().isEmpty ? null : _panController.text.trim(),
      bankName: _bankNameController.text.trim().isEmpty ? null : _bankNameController.text.trim(),
      bankAccountNumber: _bankAccountController.text.trim().isEmpty ? null : _bankAccountController.text.trim(),
      bankIfscSwift: _bankIfscController.text.trim().isEmpty ? null : _bankIfscController.text.trim(),
      upiVpa: _upiVpaController.text.trim().isEmpty ? null : _upiVpaController.text.trim(),
      currencySymbol: _currencySymbolController.text.trim(),
      invoicePrefix: _invoicePrefixController.text.trim(),
    );

    final repo = ref.read(companyRepositoryProvider);
    await repo.updateCompany(updated);
    _currentProfile = updated;

    // Invalidate cached company profile in Riverpod
    ref.invalidate(companyProfileProvider);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Company profile & address details updated successfully!'),
          backgroundColor: AppTheme.primaryEmerald,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final companyAsync = ref.watch(companyProfileProvider);

    return companyAsync.when(
      loading: () => const Scaffold(
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(color: AppTheme.primaryEmerald),
              SizedBox(height: 16),
              Text(
                'Loading company profile...',
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
                  'Failed to load company profile:\n$err',
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
                  onPressed: () => ref.refresh(companyProfileProvider),
                ),
              ],
            ),
          ),
        ),
      ),
      data: (profile) {
        if (!_initialized || _currentProfile?.id != profile.id) {
          _initControllers(profile);
        }
        return _buildForm(context);
      },
    );
  }

  Widget _buildForm(BuildContext context) {
    final isMobile = AppTheme.isMobile(context);

    // Business Identity
    final tradeNameField = TextFormField(
      controller: _tradeNameController,
      decoration: const InputDecoration(
        labelText: 'Trade / Store Name *',
        hintText: 'e.g. My Store / Brand Name',
      ),
      validator: (v) => v == null || v.isEmpty ? 'Trade name is required' : null,
    );
    final legalNameField = TextFormField(
      controller: _legalNameController,
      decoration: const InputDecoration(
        labelText: 'Legal Entity Name *',
        hintText: 'e.g. Registered Business Entity Name',
      ),
      validator: (v) => v == null || v.isEmpty ? 'Legal name is required' : null,
    );
    final branchField = TextFormField(
      controller: _branchController,
      decoration: const InputDecoration(
        labelText: 'Branch Tag',
        hintText: 'e.g. Flagship Store',
      ),
    );

    // Address
    final address1Field = TextFormField(
      controller: _address1Controller,
      decoration: const InputDecoration(
        labelText: 'Address Line 1 *',
        hintText: 'Suite / Street / Building',
      ),
      validator: (v) => v == null || v.isEmpty ? 'Address is required' : null,
    );
    final address2Field = TextFormField(
      controller: _address2Controller,
      decoration: const InputDecoration(
        labelText: 'Address Line 2 (Optional)',
        hintText: 'Sector / Landmark',
      ),
    );
    final cityField = TextFormField(
      controller: _cityController,
      decoration: const InputDecoration(labelText: 'City *'),
      validator: (v) => v == null || v.isEmpty ? 'City required' : null,
    );
    final stateField = TextFormField(
      controller: _stateController,
      decoration: const InputDecoration(labelText: 'State / Province *'),
      validator: (v) => v == null || v.isEmpty ? 'State required' : null,
    );
    final postalField = TextFormField(
      controller: _postalController,
      decoration: const InputDecoration(labelText: 'Postal / PIN Code *'),
      validator: (v) => v == null || v.isEmpty ? 'Postal code required' : null,
    );

    // Contact
    final phoneField = TextFormField(
      controller: _phoneController,
      decoration: const InputDecoration(labelText: 'Primary Phone *'),
      validator: (v) => v == null || v.isEmpty ? 'Phone required' : null,
    );
    final emailField = TextFormField(
      controller: _emailController,
      decoration: const InputDecoration(labelText: 'Email Address'),
    );
    final websiteField = TextFormField(
      controller: _websiteController,
      decoration: const InputDecoration(labelText: 'Website URL'),
    );

    // Tax & Bank
    final taxIdField = TextFormField(
      controller: _taxIdController,
      decoration: const InputDecoration(
        labelText: 'Primary Tax ID (GSTIN/VAT/EIN) *',
        hintText: '27AABCA1234F1Z5',
      ),
      validator: (v) => v == null || v.isEmpty ? 'Tax identifier required' : null,
    );
    final panField = TextFormField(
      controller: _panController,
      decoration: const InputDecoration(
        labelText: 'Secondary Tax / PAN Number',
        hintText: 'AABCA1234F',
      ),
    );
    final upiVpaField = TextFormField(
      controller: _upiVpaController,
      decoration: const InputDecoration(
        labelText: 'UPI VPA (For Dynamic QR Codes)',
        hintText: 'merchant@bank',
      ),
    );
    final bankNameField = TextFormField(
      controller: _bankNameController,
      decoration: const InputDecoration(labelText: 'Bank Name'),
    );
    final bankAccountField = TextFormField(
      controller: _bankAccountController,
      decoration: const InputDecoration(labelText: 'Bank Account Number'),
    );
    final bankIfscField = TextFormField(
      controller: _bankIfscController,
      decoration: const InputDecoration(labelText: 'IFSC / SWIFT / Routing Code'),
    );

    // Invoicing Defaults
    final currencySymbolField = TextFormField(
      controller: _currencySymbolController,
      decoration: const InputDecoration(labelText: 'Currency Symbol'),
    );
    final invoicePrefixField = TextFormField(
      controller: _invoicePrefixController,
      decoration: const InputDecoration(
        labelText: 'Invoice Number Prefix',
        hintText: 'e.g. INV- or BILL/',
      ),
    );

    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F172A),
        title: Text(
          isMobile ? 'Company Profile' : 'Company & Branch Profile Settings',
          style: TextStyle(fontSize: isMobile ? 17 : 20, fontWeight: FontWeight.bold),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: isMobile
                ? IconButton(
                    icon: const Icon(Icons.save_rounded, color: AppTheme.primaryEmerald),
                    tooltip: 'Save Changes',
                    onPressed: _saveProfile,
                  )
                : ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryEmerald,
                      foregroundColor: Colors.white,
                    ),
                    icon: const Icon(Icons.save),
                    label: const Text('Save Changes'),
                    onPressed: _saveProfile,
                  ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(isMobile ? 16 : 24),
        child: Form(
          key: _formKey,
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1000),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // First-time setup banner shown when profile is blank
                  if (_tradeNameController.text.isEmpty) ...[
                    Container(
                      width: double.infinity,
                      margin: const EdgeInsets.only(bottom: 24),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppTheme.accentAmber.withValues(alpha: 0.12),
                        border: Border.all(color: AppTheme.accentAmber.withValues(alpha: 0.4)),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.info_outline_rounded, color: AppTheme.accentAmber, size: 22),
                          SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Setup Required — Fill in your business details',
                                  style: TextStyle(
                                    color: AppTheme.accentAmber,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                  ),
                                ),
                                SizedBox(height: 4),
                                Text(
                                  'Your company name, address, GSTIN and contact info will appear on every invoice. Complete this before raising your first bill.',
                                  style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  _buildSectionHeader('Business Identity & Branding', Icons.store),
                  const SizedBox(height: 12),
                  if (isMobile) ...[
                    tradeNameField,
                    const SizedBox(height: 12),
                    legalNameField,
                    const SizedBox(height: 12),
                    branchField,
                  ] else ...[
                    Row(
                      children: [
                        Expanded(flex: 2, child: tradeNameField),
                        const SizedBox(width: 16),
                        Expanded(flex: 2, child: legalNameField),
                        const SizedBox(width: 16),
                        Expanded(flex: 1, child: branchField),
                      ],
                    ),
                  ],
                  const SizedBox(height: 24),

                  _buildSectionHeader('Physical Store Address Details', Icons.location_on),
                  const SizedBox(height: 12),
                  if (isMobile) ...[
                    address1Field,
                    const SizedBox(height: 12),
                    address2Field,
                    const SizedBox(height: 12),
                    cityField,
                    const SizedBox(height: 12),
                    stateField,
                    const SizedBox(height: 12),
                    postalField,
                  ] else ...[
                    Row(
                      children: [
                        Expanded(child: address1Field),
                        const SizedBox(width: 16),
                        Expanded(child: address2Field),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(child: cityField),
                        const SizedBox(width: 16),
                        Expanded(child: stateField),
                        const SizedBox(width: 16),
                        Expanded(child: postalField),
                      ],
                    ),
                  ],
                  const SizedBox(height: 24),

                  _buildSectionHeader('Contact & Helpline', Icons.phone),
                  const SizedBox(height: 12),
                  if (isMobile) ...[
                    phoneField,
                    const SizedBox(height: 12),
                    emailField,
                    const SizedBox(height: 12),
                    websiteField,
                  ] else ...[
                    Row(
                      children: [
                        Expanded(child: phoneField),
                        const SizedBox(width: 16),
                        Expanded(child: emailField),
                        const SizedBox(width: 16),
                        Expanded(child: websiteField),
                      ],
                    ),
                  ],
                  const SizedBox(height: 24),

                  _buildSectionHeader('Taxation, Banking & Payment Settlement', Icons.account_balance),
                  const SizedBox(height: 12),
                  if (isMobile) ...[
                    taxIdField,
                    const SizedBox(height: 12),
                    panField,
                    const SizedBox(height: 12),
                    upiVpaField,
                    const SizedBox(height: 12),
                    bankNameField,
                    const SizedBox(height: 12),
                    bankAccountField,
                    const SizedBox(height: 12),
                    bankIfscField,
                  ] else ...[
                    Row(
                      children: [
                        Expanded(child: taxIdField),
                        const SizedBox(width: 16),
                        Expanded(child: panField),
                        const SizedBox(width: 16),
                        Expanded(child: upiVpaField),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(child: bankNameField),
                        const SizedBox(width: 16),
                        Expanded(child: bankAccountField),
                        const SizedBox(width: 16),
                        Expanded(child: bankIfscField),
                      ],
                    ),
                  ],
                  const SizedBox(height: 24),

                  _buildSectionHeader('Invoicing & Currency Defaults', Icons.receipt_long),
                  const SizedBox(height: 12),
                  if (isMobile) ...[
                    currencySymbolField,
                    const SizedBox(height: 12),
                    invoicePrefixField,
                  ] else ...[
                    Row(
                      children: [
                        Expanded(child: currencySymbolField),
                        const SizedBox(width: 16),
                        Expanded(child: invoicePrefixField),
                      ],
                    ),
                  ],
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, color: AppTheme.primaryEmerald, size: 20),
        const SizedBox(width: 10),
        Text(
          title,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.textLight),
        ),
      ],
    );
  }
}
