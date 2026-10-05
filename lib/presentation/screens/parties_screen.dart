import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../core/theme/app_theme.dart';
import '../../data/models/customer.dart';
import '../../domain/state/pos_providers.dart';

enum CustomerFilter { all, withDue, settled, advance }
typedef PartyFilter = CustomerFilter;

enum CustomerSortBy { nameAsc, nameDesc, dueDesc, limitDesc }
typedef PartySortBy = CustomerSortBy;

class CustomersScreen extends ConsumerStatefulWidget {
  const CustomersScreen({super.key});

  @override
  ConsumerState<CustomersScreen> createState() => _CustomersScreenState();
}

typedef PartiesScreen = CustomersScreen;

class _CustomersScreenState extends ConsumerState<CustomersScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  CustomerFilter _selectedFilter = CustomerFilter.all;
  CustomerSortBy _selectedSort = CustomerSortBy.nameAsc;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final customersAsync = ref.watch(customersProvider);
    final currency = ref.watch(currencySymbolProvider);

    return Scaffold(
      backgroundColor: AppTheme.darkBg,
      body: customersAsync.when(
        data: (allCustomers) {
          // KPI calculations
          final totalCustomers = allCustomers.length;
          final totalReceivables = allCustomers.fold<double>(
            0.0,
            (sum, c) => sum + (c.currentBalance > 0 ? c.currentBalance : 0.0),
          );
          final debtorsCount = allCustomers.where((c) => c.currentBalance > 0).length;
          final settledCount = allCustomers.where((c) => c.currentBalance == 0).length;
          final advanceCount = allCustomers.where((c) => c.currentBalance < 0).length;

          // Filtering
          List<Customer> filtered = allCustomers.where((c) {
            // Filter chip
            switch (_selectedFilter) {
              case CustomerFilter.withDue:
                if (c.currentBalance <= 0) return false;
                break;
              case CustomerFilter.settled:
                if (c.currentBalance != 0) return false;
                break;
              case CustomerFilter.advance:
                if (c.currentBalance >= 0) return false;
                break;
              case CustomerFilter.all:
                break;
            }

            // Search query
            if (_searchQuery.isEmpty) return true;
            final query = _searchQuery.toLowerCase();
            return c.name.toLowerCase().contains(query) ||
                (c.phone?.contains(query) ?? false) ||
                (c.email?.toLowerCase().contains(query) ?? false) ||
                (c.taxNumber?.toLowerCase().contains(query) ?? false);
          }).toList();

          // Sorting
          filtered.sort((a, b) {
            switch (_selectedSort) {
              case CustomerSortBy.nameAsc:
                return a.name.toLowerCase().compareTo(b.name.toLowerCase());
              case CustomerSortBy.nameDesc:
                return b.name.toLowerCase().compareTo(a.name.toLowerCase());
              case CustomerSortBy.dueDesc:
                return b.currentBalance.compareTo(a.currentBalance);
              case CustomerSortBy.limitDesc:
                return b.creditLimit.compareTo(a.creditLimit);
            }
          });

          return Padding(
            padding: EdgeInsets.all(AppTheme.isMobile(context) ? 12 : 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 1. Top Window Header & Primary Actions
                _buildTopHeader(context),
                const SizedBox(height: 16),

                // 2. Executive KPI Summary Cards
                _buildKpiSummaryCards(
                  currency: currency,
                  totalCustomers: totalCustomers,
                  totalReceivables: totalReceivables,
                  debtorsCount: debtorsCount,
                  settledCount: settledCount,
                ),
                const SizedBox(height: 14),

                // 3. Search, Filter Chips & Sorting Control Bar
                _buildFilterAndSortBar(
                  allCount: totalCustomers,
                  dueCount: debtorsCount,
                  settledCount: settledCount,
                  advanceCount: advanceCount,
                  visibleCount: filtered.length,
                ),
                const SizedBox(height: 12),

                // 4. Main Customers Data Table Directory
                Expanded(
                  child: filtered.isEmpty
                      ? _buildEmptyState()
                      : _buildCustomersTable(filtered, currency),
                ),
              ],
            ),
          );
        },
        loading: () => const Center(
          child: CircularProgressIndicator(color: AppTheme.primaryBlue),
        ),
        error: (err, _) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline_rounded, size: 40, color: AppTheme.accentRose),
              const SizedBox(height: 12),
              Text(
                'Failed to load customer directory: $err',
                style: const TextStyle(color: AppTheme.textMuted),
              ),
              const SizedBox(height: 12),
              ElevatedButton.icon(
                onPressed: () => ref.invalidate(customersProvider),
                icon: const Icon(Icons.refresh, size: 16),
                label: const Text('Retry'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // 1. TOP HEADER
  // ---------------------------------------------------------------------------
  Widget _buildTopHeader(BuildContext context) {
    final isMobile = AppTheme.isMobile(context);

    if (isMobile) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: const Color(0xFF131D31),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppTheme.cardBorder),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF2563EB), Color(0xFF06B6D4)],
                ),
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Icon(Icons.groups_3_rounded, color: Colors.white, size: 18),
            ),
            const SizedBox(width: 10),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Customers & Accounts',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textLight,
                    ),
                  ),
                  Text(
                    'Directory & Ledger',
                    style: TextStyle(fontSize: 10, color: AppTheme.textMuted),
                  ),
                ],
              ),
            ),
            IconButton(
              tooltip: 'Refresh',
              iconSize: 18,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
              icon: const Icon(Icons.refresh_rounded, color: AppTheme.textMuted),
              onPressed: () => ref.invalidate(customersProvider),
            ),
            const SizedBox(width: 6),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryBlue,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                visualDensity: VisualDensity.compact,
              ),
              icon: const Icon(Icons.person_add_alt_1_rounded, size: 15),
              label: const Text(
                'Add Customer',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
              ),
              onPressed: () => _showCustomerFormDialog(context),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF131D31),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.cardBorder),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(9),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF2563EB), Color(0xFF06B6D4)],
              ),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.groups_3_rounded, color: Colors.white, size: 22),
          ),
          const SizedBox(width: 14),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Customers & Accounts',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textLight,
                    letterSpacing: 0.3,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  'Directory of customers, credit lines and outstanding receivables',
                  style: TextStyle(fontSize: 11, color: AppTheme.textMuted),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),

          // Refresh Button
          IconButton(
            tooltip: 'Refresh Customers Directory',
            style: IconButton.styleFrom(
              backgroundColor: const Color(0xFF1E293B),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(6),
                side: const BorderSide(color: AppTheme.cardBorder),
              ),
            ),
            icon: const Icon(Icons.refresh_rounded, size: 18, color: AppTheme.textMuted),
            onPressed: () => ref.invalidate(customersProvider),
          ),
          const SizedBox(width: 10),

          // Add New Customer Primary Action
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryBlue,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              elevation: 2,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
            ),
            icon: const Icon(Icons.person_add_alt_1_rounded, size: 17),
            label: const Text(
              'Add New Customer',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
            ),
            onPressed: () => _showCustomerFormDialog(context),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // 2. EXECUTIVE KPI SUMMARY CARDS
  // ---------------------------------------------------------------------------
  Widget _buildKpiSummaryCards({
    required String currency,
    required int totalCustomers,
    required double totalReceivables,
    required int debtorsCount,
    required int settledCount,
  }) {
    final cards = [
      _buildMetricCard(
        title: 'TOTAL REGISTERED CUSTOMERS',
        value: '$totalCustomers',
        subtitle: 'All customer accounts',
        icon: Icons.groups_rounded,
        iconColor: const Color(0xFF38BDF8),
        badgeColor: const Color(0xFF0F2644),
        isSelected: _selectedFilter == CustomerFilter.all,
        onTap: () => setState(() => _selectedFilter = CustomerFilter.all),
      ),
      _buildMetricCard(
        title: 'TOTAL RECEIVABLES (DUE)',
        value: '$currency${totalReceivables.toStringAsFixed(2)}',
        subtitle: 'Unsettled ledger balances',
        icon: Icons.account_balance_wallet_rounded,
        iconColor: const Color(0xFFFB7185),
        badgeColor: const Color(0xFF2A1018),
        isAlert: totalReceivables > 0,
        isSelected: _selectedFilter == CustomerFilter.withDue,
        onTap: () => setState(() => _selectedFilter = CustomerFilter.withDue),
      ),
      _buildMetricCard(
        title: 'ACTIVE DEBTORS (DUE)',
        value: '$debtorsCount',
        subtitle: 'Customers requiring collection',
        icon: Icons.pending_actions_rounded,
        iconColor: const Color(0xFFFBBF24),
        badgeColor: const Color(0xFF2E200B),
        isSelected: _selectedFilter == CustomerFilter.withDue,
        onTap: () => setState(() => _selectedFilter = CustomerFilter.withDue),
      ),
      _buildMetricCard(
        title: 'SETTLED ACCOUNTS',
        value: '$settledCount',
        subtitle: 'Zero outstanding ledger',
        icon: Icons.verified_rounded,
        iconColor: const Color(0xFF34D399),
        badgeColor: const Color(0xFF09291D),
        isSelected: _selectedFilter == CustomerFilter.settled,
        onTap: () => setState(() => _selectedFilter = CustomerFilter.settled),
      ),
    ];

    // Mobile: 2×2 grid via Wrap
    if (AppTheme.isMobile(context)) {
      return Wrap(
        spacing: 10,
        runSpacing: 10,
        children: cards.map((c) => SizedBox(
          width: (MediaQuery.sizeOf(context).width - 44) / 2,
          child: c,
        )).toList(),
      );
    }

    // Tablet/Desktop: single row
    return Row(
      children: cards.asMap().entries.map((e) => [
        if (e.key > 0) const SizedBox(width: 12),
        Expanded(child: e.value),
      ]).expand((x) => x).toList(),
    );
  }

  Widget _buildMetricCard({
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    required Color iconColor,
    required Color badgeColor,
    bool isAlert = false,
    bool isSelected = false,
    VoidCallback? onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: const Color(0xFF131D31),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected
                ? (isAlert ? const Color(0xFFF43F5E) : AppTheme.primaryBlue)
                : (isAlert ? const Color(0xFFF43F5E).withValues(alpha: 0.5) : AppTheme.cardBorder),
            width: isSelected ? 1.6 : 1.0,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: badgeColor,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: iconColor, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textMuted,
                      letterSpacing: 0.6,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    value,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                      color: isAlert ? const Color(0xFFFB7185) : Colors.white,
                    ),
                  ),
                  const SizedBox(height: 1),
                  Text(
                    subtitle,
                    style: const TextStyle(fontSize: 10, color: AppTheme.textSecondary),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // 3. UNIFIED SEARCH, FILTER CHIPS & SORTING BAR
  // ---------------------------------------------------------------------------
  Widget _buildFilterAndSortBar({
    required int allCount,
    required int dueCount,
    required int settledCount,
    required int advanceCount,
    required int visibleCount,
  }) {
    final isMobile = AppTheme.isMobile(context);
    final searchField = SizedBox(
      height: 34,
      child: TextField(
        controller: _searchController,
        onChanged: (val) => setState(() => _searchQuery = val.trim()),
        style: const TextStyle(fontSize: 12, color: AppTheme.textLight),
        decoration: InputDecoration(
          isDense: true,
          hintText: 'Search name, phone, GSTIN...',
          hintStyle: const TextStyle(fontSize: 11, color: AppTheme.textMuted),
          contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          prefixIcon: const Icon(Icons.search_rounded, size: 16, color: AppTheme.textMuted),
          suffixIcon: _searchController.text.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear, size: 14),
                  onPressed: () {
                    _searchController.clear();
                    setState(() => _searchQuery = '');
                  },
                )
              : null,
        ),
      ),
    );

    final chips = Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        _buildFilterChip('All', allCount, CustomerFilter.all),
        _buildFilterChip('Due', dueCount, CustomerFilter.withDue, accentColor: const Color(0xFFFB7185)),
        _buildFilterChip('Settled', settledCount, CustomerFilter.settled, accentColor: const Color(0xFF34D399)),
        if (advanceCount > 0)
          _buildFilterChip('Advance', advanceCount, CustomerFilter.advance, accentColor: const Color(0xFF38BDF8)),
      ],
    );

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12, vertical: isMobile ? 10 : 8),
      decoration: BoxDecoration(
        color: const Color(0xFF10192A),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: AppTheme.cardBorder),
      ),
      child: isMobile
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                searchField,
                const SizedBox(height: 10),
                chips,
              ],
            )
          : Row(
              children: [
                SizedBox(width: 280, child: searchField),
                const SizedBox(width: 14),
                _buildFilterChip('All Customers', allCount, CustomerFilter.all),
                const SizedBox(width: 6),
                _buildFilterChip('With Due', dueCount, CustomerFilter.withDue, accentColor: const Color(0xFFFB7185)),
                const SizedBox(width: 6),
                _buildFilterChip('Settled (Nil)', settledCount, CustomerFilter.settled, accentColor: const Color(0xFF34D399)),
                if (advanceCount > 0) ...[
                  const SizedBox(width: 6),
                  _buildFilterChip('Advance Cr', advanceCount, CustomerFilter.advance, accentColor: const Color(0xFF38BDF8)),
                ],
                const Spacer(),
                Text(
                  'Showing $visibleCount of $allCount customers',
                  style: const TextStyle(fontSize: 11, color: AppTheme.textMuted),
                ),
                const SizedBox(width: 12),
                _buildSortDropdown(),
              ],
            ),
    );
  }

  Widget _buildSortDropdown() {
    return Container(
      height: 32,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: AppTheme.cardBorder),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<CustomerSortBy>(
          value: _selectedSort,
          dropdownColor: const Color(0xFF1E293B),
          icon: const Icon(Icons.sort_rounded, size: 15, color: AppTheme.accentCyan),
          style: const TextStyle(fontSize: 11, color: AppTheme.textLight),
          items: const [
            DropdownMenuItem(value: CustomerSortBy.nameAsc, child: Text('Sort: Name (A-Z)')),
            DropdownMenuItem(value: CustomerSortBy.nameDesc, child: Text('Sort: Name (Z-A)')),
            DropdownMenuItem(value: CustomerSortBy.dueDesc, child: Text('Sort: Highest Due Balance')),
            DropdownMenuItem(value: CustomerSortBy.limitDesc, child: Text('Sort: Highest Credit Limit')),
          ],
          onChanged: (val) {
            if (val != null) setState(() => _selectedSort = val);
          },
        ),
      ),
    );
  }

  Widget _buildFilterChip(
    String label,
    int count,
    CustomerFilter filter, {
    Color? accentColor,
  }) {
    final isSelected = _selectedFilter == filter;
    final color = accentColor ?? AppTheme.primaryBlue;

    return InkWell(
      onTap: () => setState(() => _selectedFilter = filter),
      borderRadius: BorderRadius.circular(4),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? color.withValues(alpha: 0.15) : const Color(0xFF141F32),
          borderRadius: BorderRadius.circular(4),
          border: Border.all(
            color: isSelected ? color : AppTheme.cardBorder,
            width: isSelected ? 1.2 : 1.0,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                color: isSelected ? Colors.white : AppTheme.textMuted,
              ),
            ),
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
              decoration: BoxDecoration(
                color: isSelected ? color : const Color(0xFF1E293B),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '$count',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: isSelected ? Colors.white : AppTheme.textMuted,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // 4. MAIN CUSTOMERS DATA TABLE WITH EXACT COLUMN ALIGNMENT
  // ---------------------------------------------------------------------------
  static const TextStyle _tableHeaderStyle = TextStyle(
    fontWeight: FontWeight.bold,
    fontSize: 10,
    color: AppTheme.textMuted,
    letterSpacing: 0.5,
  );

  Widget _buildCustomersTable(List<Customer> customers, String currency) {
    // ── Mobile: card-list view ────────────────────────────────────────────────
    if (AppTheme.isMobile(context)) {
      return Container(
        decoration: BoxDecoration(
          color: const Color(0xFF10192A),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppTheme.cardBorder),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: ListView.separated(
            itemCount: customers.length,
            separatorBuilder: (_, __) => const Divider(height: 1, color: AppTheme.cardBorder),
            itemBuilder: (ctx, idx) {
              final c = customers[idx];
              final hasDue = c.currentBalance > 0;
              final hasAdvance = c.currentBalance < 0;
              final statusColor = hasDue
                  ? const Color(0xFFFB7185)
                  : (hasAdvance ? const Color(0xFF38BDF8) : const Color(0xFF34D399));
              final statusLabel = hasDue ? 'Due Balance' : (hasAdvance ? 'Advance Cr' : 'Clean / Paid');

              return InkWell(
                onTap: () => _showCustomerStatementDialog(context, c, currency),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Row 1: Avatar + Name + Status badge
                      Row(
                        children: [
                          CircleAvatar(
                            radius: 18,
                            backgroundColor: _getAvatarColor(c.name).withValues(alpha: 0.18),
                            child: Text(
                              c.name.isNotEmpty ? c.name[0].toUpperCase() : 'C',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: _getAvatarColor(c.name),
                                fontSize: 13,
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  c.name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                    color: AppTheme.textLight,
                                  ),
                                ),
                                Row(
                                  children: [
                                    if (c.phone != null) ...[
                                      Text(
                                        c.phone!,
                                        style: const TextStyle(fontSize: 11, color: AppTheme.accentCyan),
                                      ),
                                      const SizedBox(width: 8),
                                    ],
                                    if (c.taxNumber != null && c.taxNumber!.isNotEmpty)
                                      Flexible(
                                        child: Text(
                                          'GST: ${c.taxNumber}',
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(fontSize: 10, color: AppTheme.textMuted),
                                        ),
                                      ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: statusColor.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: statusColor.withValues(alpha: 0.4)),
                            ),
                            child: Text(
                              statusLabel,
                              style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: statusColor),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),

                      // Row 2: Financial Stats Block
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        decoration: BoxDecoration(
                          color: const Color(0xFF0F172A),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: AppTheme.cardBorder),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('Outstanding Due', style: TextStyle(fontSize: 10, color: AppTheme.textMuted)),
                                  const SizedBox(height: 2),
                                  Text(
                                    hasDue
                                        ? 'Dr $currency${c.currentBalance.toStringAsFixed(2)}'
                                        : (hasAdvance ? 'Cr $currency${c.currentBalance.abs().toStringAsFixed(2)}' : '$currency 0.00'),
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w900,
                                      color: hasDue ? const Color(0xFFFB7185) : (hasAdvance ? AppTheme.accentCyan : const Color(0xFF34D399)),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Container(width: 1, height: 26, color: AppTheme.cardBorder),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('Credit Limit', style: TextStyle(fontSize: 10, color: AppTheme.textMuted)),
                                  const SizedBox(height: 2),
                                  Text(
                                    '$currency${c.creditLimit.toStringAsFixed(2)}',
                                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.textLight),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),

                      // Row 3: Action Buttons Bar
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          if (hasDue) ...[
                            TextButton.icon(
                              style: TextButton.styleFrom(
                                foregroundColor: const Color(0xFF34D399),
                                backgroundColor: const Color(0xFF09291D),
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                visualDensity: VisualDensity.compact,
                              ),
                              icon: const Icon(Icons.payments_rounded, size: 14),
                              label: const Text('Pay', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                              onPressed: () => _showReceivePaymentDialog(context, c),
                            ),
                            const SizedBox(width: 6),
                          ],
                          TextButton.icon(
                            style: TextButton.styleFrom(
                              foregroundColor: AppTheme.accentCyan,
                              backgroundColor: const Color(0xFF082F49),
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              visualDensity: VisualDensity.compact,
                            ),
                            icon: const Icon(Icons.receipt_long_rounded, size: 14),
                            label: const Text('Statement', style: TextStyle(fontSize: 11)),
                            onPressed: () => _showCustomerStatementDialog(context, c, currency),
                          ),
                          const SizedBox(width: 6),
                          _buildActionIconButton(
                            icon: Icons.edit_note_rounded,
                            tooltip: 'Edit Profile',
                            color: const Color(0xFF60A5FA),
                            hoverBgColor: AppTheme.primaryBlue,
                            onPressed: () => _showCustomerFormDialog(context, customer: c),
                          ),
                          const SizedBox(width: 4),
                          _buildActionIconButton(
                            icon: Icons.delete_outline_rounded,
                            tooltip: 'Delete Profile',
                            color: const Color(0xFFFB7185),
                            hoverBgColor: const Color(0xFFE11D48),
                            onPressed: () => _showDeleteCustomerConfirmationDialog(context, c),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      );
    }

    // ── Desktop/Tablet: traditional table view ────────────────────────────────
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF10192A),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.cardBorder),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Column(
          children: [
            // Exact Column-Aligned Table Header Bar
            Container(
              height: 38,
              color: const Color(0xFF162238),
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: const Row(
                children: [
                  Expanded(flex: 3, child: Text('CUSTOMER / BUSINESS NAME', style: _tableHeaderStyle)),
                  Expanded(flex: 2, child: Text('PHONE / CONTACT', style: _tableHeaderStyle)),
                  Expanded(flex: 2, child: Text('GSTIN / TAX ID', style: _tableHeaderStyle)),
                  Expanded(flex: 2, child: Padding(padding: EdgeInsets.only(right: 14), child: Text('CREDIT LIMIT', textAlign: TextAlign.right, style: _tableHeaderStyle))),
                  Expanded(flex: 2, child: Padding(padding: EdgeInsets.only(right: 14), child: Text('OUTSTANDING DUE', textAlign: TextAlign.right, style: _tableHeaderStyle))),
                  SizedBox(width: 110, child: Center(child: Text('STATUS', style: _tableHeaderStyle))),
                  SizedBox(width: 150, child: Align(alignment: Alignment.centerRight, child: Text('ACTIONS', style: _tableHeaderStyle))),
                ],
              ),
            ),
            const Divider(height: 1, color: AppTheme.cardBorder),

            // Rows
            Expanded(
              child: ListView.separated(
                itemCount: customers.length,
                separatorBuilder: (_, __) => const Divider(height: 1, color: AppTheme.cardBorder),
                itemBuilder: (ctx, idx) {
                  final customer = customers[idx];
                  final isEven = idx % 2 == 0;
                  final hasDue = customer.currentBalance > 0;
                  final hasAdvance = customer.currentBalance < 0;

                  return InkWell(
                    onTap: () => _showCustomerStatementDialog(context, customer, currency),
                    child: Container(
                      height: 50,
                      color: isEven ? const Color(0xFF0F172A) : const Color(0xFF131D31),
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Row(
                        children: [
                          // 1. Customer Name & Avatar
                          Expanded(
                            flex: 3,
                            child: Row(
                              children: [
                                CircleAvatar(
                                  radius: 14,
                                  backgroundColor: _getAvatarColor(customer.name).withValues(alpha: 0.18),
                                  child: Text(
                                    customer.name.isNotEmpty ? customer.name.substring(0, 1).toUpperCase() : 'C',
                                    style: TextStyle(fontWeight: FontWeight.bold, color: _getAvatarColor(customer.name), fontSize: 11),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Text(customer.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppTheme.textLight)),
                                      Text(customer.email ?? 'ID: ${customer.id}', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 10, color: AppTheme.textSecondary)),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          // 2. Phone
                          Expanded(
                            flex: 2,
                            child: Row(
                              children: [
                                Icon(Icons.phone_outlined, size: 13, color: customer.phone != null ? AppTheme.accentCyan : AppTheme.textMuted.withValues(alpha: 0.4)),
                                const SizedBox(width: 6),
                                Expanded(child: Text(customer.phone ?? '-', style: TextStyle(fontSize: 11, color: customer.phone != null ? AppTheme.textLight : AppTheme.textMuted))),
                              ],
                            ),
                          ),
                          // 3. GSTIN
                          Expanded(
                            flex: 2,
                            child: customer.taxNumber != null && customer.taxNumber!.isNotEmpty
                                ? Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF082F49),
                                      borderRadius: BorderRadius.circular(4),
                                      border: Border.all(color: const Color(0xFF0284C7).withValues(alpha: 0.5)),
                                    ),
                                    child: Text(customer.taxNumber!, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF38BDF8))),
                                  )
                                : const Text('-', style: TextStyle(fontSize: 11, color: AppTheme.textMuted)),
                          ),
                          // 4. Credit Limit
                          Expanded(
                            flex: 2,
                            child: Padding(
                              padding: const EdgeInsets.only(right: 14),
                              child: Text('$currency${customer.creditLimit.toStringAsFixed(2)}', textAlign: TextAlign.right, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppTheme.textLight)),
                            ),
                          ),
                          // 5. Outstanding Due
                          Expanded(
                            flex: 2,
                            child: Padding(
                              padding: const EdgeInsets.only(right: 14),
                              child: Text(
                                hasDue ? 'Dr $currency${customer.currentBalance.toStringAsFixed(2)}' : (hasAdvance ? 'Cr $currency${customer.currentBalance.abs().toStringAsFixed(2)}' : '$currency 0.00'),
                                textAlign: TextAlign.right,
                                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: hasDue ? const Color(0xFFFB7185) : (hasAdvance ? AppTheme.accentCyan : const Color(0xFF34D399))),
                              ),
                            ),
                          ),
                          // 6. Status
                          SizedBox(
                            width: 110,
                            child: Center(
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: hasDue ? const Color(0xFF2A1018) : (hasAdvance ? const Color(0xFF082F49) : const Color(0xFF09291D)),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(color: hasDue ? const Color(0xFFF43F5E).withValues(alpha: 0.5) : (hasAdvance ? const Color(0xFF38BDF8).withValues(alpha: 0.5) : const Color(0xFF34D399).withValues(alpha: 0.5))),
                                ),
                                child: Text(
                                  hasDue ? 'Due Balance' : (hasAdvance ? 'Advance Cr' : 'Clean / Paid'),
                                  style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: hasDue ? const Color(0xFFFB7185) : (hasAdvance ? const Color(0xFF38BDF8) : const Color(0xFF34D399))),
                                ),
                              ),
                            ),
                          ),
                          // 7. Actions
                          SizedBox(
                            width: 150,
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                if (hasDue) ...[
                                  _buildActionIconButton(icon: Icons.payments_rounded, tooltip: 'Receive Payment', color: const Color(0xFF34D399), hoverBgColor: const Color(0xFF10B981), onPressed: () => _showReceivePaymentDialog(context, customer)),
                                  const SizedBox(width: 5),
                                ],
                                _buildActionIconButton(icon: Icons.receipt_long_rounded, tooltip: 'View Customer Statement', color: AppTheme.accentCyan, hoverBgColor: AppTheme.accentCyan, onPressed: () => _showCustomerStatementDialog(context, customer, currency)),
                                const SizedBox(width: 5),
                                _buildActionIconButton(icon: Icons.edit_note_rounded, tooltip: 'Edit Customer Profile', color: const Color(0xFF60A5FA), hoverBgColor: AppTheme.primaryBlue, onPressed: () => _showCustomerFormDialog(context, customer: customer)),
                                const SizedBox(width: 5),
                                _buildActionIconButton(icon: Icons.delete_outline_rounded, tooltip: 'Delete Customer Profile', color: const Color(0xFFFB7185), hoverBgColor: const Color(0xFFE11D48), onPressed: () => _showDeleteCustomerConfirmationDialog(context, customer)),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionIconButton({
    required IconData icon,
    required String tooltip,
    required Color color,
    required Color hoverBgColor,
    required VoidCallback onPressed,
  }) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(6),
        child: Container(
          width: 30,
          height: 30,
          decoration: BoxDecoration(
            color: hoverBgColor.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: hoverBgColor.withValues(alpha: 0.28)),
          ),
          child: Icon(icon, size: 15, color: color),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF1E293B),
              shape: BoxShape.circle,
              border: Border.all(color: AppTheme.cardBorder),
            ),
            child: const Icon(Icons.person_search_rounded, size: 40, color: AppTheme.textMuted),
          ),
          const SizedBox(height: 14),
          Text(
            _searchQuery.isEmpty ? 'No customers registered yet' : 'No customer matching "$_searchQuery"',
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppTheme.textLight),
          ),
          const SizedBox(height: 6),
          const Text(
            'Create customer accounts to manage credit limits and billing ledgers',
            style: TextStyle(fontSize: 11, color: AppTheme.textSecondary),
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryBlue),
            onPressed: () => _showCustomerFormDialog(context),
            icon: const Icon(Icons.add, size: 16),
            label: const Text('Add First Customer'),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // 5. ACTION ALERTS & MODALS
  // ---------------------------------------------------------------------------

  // --- ACTION ALERT 1: DELETE CUSTOMER CONFIRMATION ---
  void _showDeleteCustomerConfirmationDialog(BuildContext context, Customer customer) async {
    final hasDue = customer.currentBalance > 0;
    int invoiceCount = 0;
    try {
      invoiceCount = await ref.read(customerRepositoryProvider).getCustomerInvoiceCount(customer.id);
    } catch (_) {}

    if (!context.mounted) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogCtx) {
        final isMobile = AppTheme.isMobile(dialogCtx);
        return AlertDialog(
          backgroundColor: const Color(0xFF141F32),
          insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
            side: const BorderSide(color: Color(0xFFE11D48), width: 1.2),
          ),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF2A1018),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: const Color(0xFFF43F5E), width: 1.2),
                ),
                child: const Icon(Icons.warning_amber_rounded, color: Color(0xFFFB7185), size: 22),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'Delete Customer Profile',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                ),
              ),
            ],
          ),
          content: SizedBox(
            width: isMobile ? double.maxFinite : 460,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                RichText(
                  text: TextSpan(
                    style: const TextStyle(fontSize: 13, color: AppTheme.textLight, height: 1.4),
                    children: [
                      const TextSpan(text: 'Are you sure you want to permanently delete '),
                      TextSpan(
                        text: '"${customer.name}"',
                        style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF38BDF8)),
                      ),
                      const TextSpan(text: '? This action cannot be reversed.'),
                    ],
                  ),
                ),
                const SizedBox(height: 12),

                // Severe warning if customer has active due balance
                if (hasDue)
                  Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF2A1018),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: const Color(0xFFF43F5E), width: 1),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.error_outline_rounded, color: Color(0xFFFB7185), size: 18),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Outstanding Due Balance Warning',
                                style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFFFDA4AF)),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'This customer has an unsettled ledger due of ₹${customer.currentBalance.toStringAsFixed(2)}. Deleting this customer will affect ledger reconciliations.',
                                style: const TextStyle(fontSize: 10, color: Color(0xFFFECDD3)),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                // Linked invoices advisory
                if (invoiceCount > 0)
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0F2644),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: const Color(0xFF0284C7).withValues(alpha: 0.5)),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.info_outline_rounded, color: Color(0xFF38BDF8), size: 18),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '$invoiceCount Linked Sales Invoice${invoiceCount > 1 ? 's' : ''}',
                                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFFBAE6FD)),
                              ),
                              const SizedBox(height: 2),
                              const Text(
                                'Existing invoices will be safely preserved in transaction records and reports, while customer references will be unlinked.',
                                style: TextStyle(fontSize: 10, color: Color(0xFFE0F2FE)),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          actions: [
            Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.end,
              children: [
                OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppTheme.textLight,
                    side: const BorderSide(color: AppTheme.cardBorder),
                  ),
                  onPressed: () => Navigator.pop(dialogCtx),
                  child: const Text('Cancel'),
                ),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFE11D48),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                  ),
                  icon: const Icon(Icons.delete_forever_rounded, size: 16),
                  label: const Text('Delete Permanently', style: TextStyle(fontWeight: FontWeight.bold)),
                  onPressed: () async {
                    try {
                      await ref.read(customerRepositoryProvider).deleteCustomer(customer.id);
                      ref.invalidate(customersProvider);
                      ref.invalidate(dashboardMetricsProvider);
                      if (dialogCtx.mounted) {
                        Navigator.pop(dialogCtx);
                        _showModernSnackBar(
                          context,
                          'Customer "${customer.name}" permanently deleted',
                          icon: Icons.delete_outline_rounded,
                          backgroundColor: const Color(0xFFE11D48),
                        );
                      }
                    } catch (e) {
                      if (dialogCtx.mounted) {
                        Navigator.pop(dialogCtx);
                        _showModernSnackBar(
                          context,
                          'Failed to delete customer: $e',
                          icon: Icons.error_outline_rounded,
                          backgroundColor: const Color(0xFFE11D48),
                        );
                      }
                    }
                  },
                ),
              ],
            ),
          ],
        );
      },
    );
  }

  // --- ACTION ALERT 2: RECEIVE PAYMENT RECEIPT MODAL ---
  void _showReceivePaymentDialog(BuildContext context, Customer customer) {
    final amtCtrl = TextEditingController(text: customer.currentBalance.toStringAsFixed(2));
    String paymentMode = 'CASH';
    final notesCtrl = TextEditingController();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          final isMobile = AppTheme.isMobile(ctx);
          final enteredAmt = double.tryParse(amtCtrl.text.trim()) ?? 0.0;
          final remainingBalance = (customer.currentBalance - enteredAmt).clamp(-9999999.0, customer.currentBalance);

          return AlertDialog(
            backgroundColor: const Color(0xFF141F32),
            insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
              side: const BorderSide(color: Color(0xFF10B981), width: 1.2),
            ),
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF09291D),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: const Color(0xFF10B981)),
                  ),
                  child: const Icon(Icons.payments_rounded, color: Color(0xFF34D399), size: 20),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Record Payment Receipt',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        'Receive outstanding payment and update ledger',
                        style: TextStyle(fontSize: 10, color: AppTheme.textMuted),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            content: SizedBox(
              width: isMobile ? double.maxFinite : 480,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Customer Due Balance Overview Card
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1E293B),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: AppTheme.cardBorder),
                      ),
                      child: isMobile
                          ? Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('CUSTOMER NAME', style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: AppTheme.textMuted)),
                                const SizedBox(height: 2),
                                Text(customer.name, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.white)),
                                if (customer.phone != null)
                                  Text(customer.phone!, style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
                                const Divider(height: 12, color: AppTheme.cardBorder),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    const Text('TOTAL OUTSTANDING DUE', style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Color(0xFFFDA4AF))),
                                    Text(
                                      '₹${customer.currentBalance.toStringAsFixed(2)}',
                                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: Color(0xFFFB7185)),
                                    ),
                                  ],
                                ),
                              ],
                            )
                          : Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text('CUSTOMER NAME', style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: AppTheme.textMuted)),
                                      const SizedBox(height: 2),
                                      Text(customer.name, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.white)),
                                      if (customer.phone != null)
                                        Text(customer.phone!, style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
                                    ],
                                  ),
                                ),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    const Text('TOTAL OUTSTANDING DUE', style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Color(0xFFFDA4AF))),
                                    const SizedBox(height: 2),
                                    Text(
                                      '₹${customer.currentBalance.toStringAsFixed(2)}',
                                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Color(0xFFFB7185)),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                    ),
                    const SizedBox(height: 14),

                    // Quick Shortcut Percentage Chips
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        const Text('Quick Fill:', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppTheme.textMuted)),
                        _buildQuickAmountChip('Full Due', customer.currentBalance, amtCtrl, setDialogState),
                        _buildQuickAmountChip('50%', customer.currentBalance * 0.5, amtCtrl, setDialogState),
                        _buildQuickAmountChip('25%', customer.currentBalance * 0.25, amtCtrl, setDialogState),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Amount Received Field
                    TextField(
                      controller: amtCtrl,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF34D399)),
                      onChanged: (_) => setDialogState(() {}),
                      decoration: const InputDecoration(
                        labelText: 'Amount Received (₹) *',
                        prefixIcon: Icon(Icons.currency_rupee, size: 16, color: Color(0xFF34D399)),
                      ),
                    ),
                    const SizedBox(height: 8),

                    // Live Remaining Balance Preview
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0F172A),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: AppTheme.cardBorder),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Remaining Ledger Balance After Receipt:', style: TextStyle(fontSize: 10, color: AppTheme.textMuted)),
                          Text(
                            '₹${remainingBalance.toStringAsFixed(2)}',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: remainingBalance <= 0 ? const Color(0xFF34D399) : const Color(0xFFFB7185),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Payment Mode Selector
                    const Text('PAYMENT METHOD', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppTheme.textMuted)),
                    const SizedBox(height: 6),
                    Row(
                      children: ['CASH', 'UPI / QR', 'CARD', 'BANK'].map((mode) {
                        final isSelected = paymentMode == mode;
                        return Expanded(
                          child: Padding(
                            padding: const EdgeInsets.only(right: 6),
                            child: InkWell(
                              onTap: () => setDialogState(() => paymentMode = mode),
                              child: Container(
                                height: 32,
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  color: isSelected ? const Color(0xFF059669) : const Color(0xFF1E293B),
                                  borderRadius: BorderRadius.circular(4),
                                  border: Border.all(color: isSelected ? const Color(0xFF10B981) : AppTheme.cardBorder),
                                ),
                                child: Text(
                                  mode,
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                                    color: isSelected ? Colors.white : AppTheme.textMuted,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 12),

                    // Reference Notes
                    TextField(
                      controller: notesCtrl,
                      style: const TextStyle(fontSize: 11, color: AppTheme.textLight),
                      decoration: const InputDecoration(
                        labelText: 'Receipt Note / Transaction Reference (Optional)',
                        hintText: 'e.g. UPI Ref / Cheque No / Cash voucher...',
                        isDense: true,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              Wrap(
                spacing: 8,
                runSpacing: 8,
                alignment: WrapAlignment.end,
                children: [
                  OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppTheme.textLight,
                      side: const BorderSide(color: AppTheme.cardBorder),
                    ),
                    onPressed: () => Navigator.pop(dialogCtx),
                    child: const Text('Cancel'),
                  ),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF059669),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                    ),
                    icon: const Icon(Icons.check_circle_rounded, size: 16),
                    label: Text('Record Receipt (₹${enteredAmt.toStringAsFixed(2)})', style: const TextStyle(fontWeight: FontWeight.bold)),
                    onPressed: () async {
                      if (enteredAmt <= 0) return;
                      await ref.read(customerRepositoryProvider).updateBalance(customer.id, -enteredAmt);
                      ref.invalidate(customersProvider);
                      ref.invalidate(dashboardMetricsProvider);
                      if (dialogCtx.mounted) {
                        Navigator.pop(dialogCtx);
                        _showModernSnackBar(
                          context,
                          'Receipt of ₹${enteredAmt.toStringAsFixed(2)} recorded for "${customer.name}". Balance: ₹${remainingBalance.toStringAsFixed(2)}',
                          icon: Icons.receipt_long_rounded,
                          backgroundColor: const Color(0xFF059669),
                        );
                      }
                    },
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildQuickAmountChip(
    String label,
    double amount,
    TextEditingController controller,
    StateSetter setDialogState,
  ) {
    return InkWell(
      onTap: () {
        setDialogState(() {
          controller.text = amount.toStringAsFixed(2);
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: const Color(0xFF0C2444),
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: const Color(0xFF0284C7)),
        ),
        child: Text(
          '$label (₹${amount.toStringAsFixed(0)})',
          style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF38BDF8)),
        ),
      ),
    );
  }

  // --- ACTION ALERT 3: ADD / EDIT CUSTOMER FORM MODAL ---
  void _showCustomerFormDialog(BuildContext context, {Customer? customer}) {
    final isEditing = customer != null;
    final nameCtrl = TextEditingController(text: customer?.name ?? '');
    final phoneCtrl = TextEditingController(text: customer?.phone ?? '');
    final emailCtrl = TextEditingController(text: customer?.email ?? '');
    final gstinCtrl = TextEditingController(text: customer?.taxNumber ?? '');
    final limitCtrl = TextEditingController(text: customer?.creditLimit.toString() ?? '10000');
    final balanceCtrl = TextEditingController(text: customer?.currentBalance.toString() ?? '0.00');

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogCtx) {
        final isMobile = AppTheme.isMobile(dialogCtx);
        return AlertDialog(
          backgroundColor: const Color(0xFF141F32),
          insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
            side: const BorderSide(color: AppTheme.cardBorder),
          ),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: isEditing ? const Color(0xFF0F2644) : const Color(0xFF09291D),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: isEditing ? AppTheme.primaryBlue : AppTheme.primaryEmerald),
                ),
                child: Icon(
                  isEditing ? Icons.edit_note_rounded : Icons.person_add_alt_1_rounded,
                  color: isEditing ? const Color(0xFF60A5FA) : const Color(0xFF34D399),
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  isEditing ? 'Edit: ${customer.name}' : 'Create New Customer',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          content: SizedBox(
            width: isMobile ? double.maxFinite : 500,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // General & Contact Details
                  const Text(
                    'BASIC & CONTACT INFORMATION',
                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppTheme.accentCyan, letterSpacing: 0.6),
                  ),
                  const SizedBox(height: 8),

                  TextField(
                    controller: nameCtrl,
                    style: const TextStyle(fontSize: 12, color: AppTheme.textLight),
                    decoration: const InputDecoration(
                      labelText: 'Customer / Business Name *',
                      hintText: 'e.g. Ramesh Traders, Rahul Sharma...',
                      prefixIcon: Icon(Icons.business_rounded, size: 16),
                    ),
                  ),
                  const SizedBox(height: 10),

                  if (isMobile) ...[
                    TextField(
                      controller: phoneCtrl,
                      keyboardType: TextInputType.phone,
                      style: const TextStyle(fontSize: 12, color: AppTheme.textLight),
                      decoration: const InputDecoration(
                        labelText: 'Phone Number',
                        hintText: '10-digit mobile...',
                        prefixIcon: Icon(Icons.phone_rounded, size: 16),
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: emailCtrl,
                      keyboardType: TextInputType.emailAddress,
                      style: const TextStyle(fontSize: 12, color: AppTheme.textLight),
                      decoration: const InputDecoration(
                        labelText: 'Email Address',
                        hintText: 'customer@domain.com',
                        prefixIcon: Icon(Icons.email_outlined, size: 16),
                      ),
                    ),
                  ] else
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: phoneCtrl,
                            keyboardType: TextInputType.phone,
                            style: const TextStyle(fontSize: 12, color: AppTheme.textLight),
                            decoration: const InputDecoration(
                              labelText: 'Phone Number',
                              hintText: '10-digit mobile...',
                              prefixIcon: Icon(Icons.phone_rounded, size: 16),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: TextField(
                            controller: emailCtrl,
                            keyboardType: TextInputType.emailAddress,
                            style: const TextStyle(fontSize: 12, color: AppTheme.textLight),
                            decoration: const InputDecoration(
                              labelText: 'Email Address',
                              hintText: 'customer@domain.com',
                              prefixIcon: Icon(Icons.email_outlined, size: 16),
                            ),
                          ),
                        ),
                      ],
                    ),
                  const SizedBox(height: 16),

                  // Financial & Tax Details
                  const Text(
                    'FINANCIAL & TAX LEDGER',
                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppTheme.accentCyan, letterSpacing: 0.6),
                  ),
                  const SizedBox(height: 8),

                  TextField(
                    controller: gstinCtrl,
                    style: const TextStyle(fontSize: 12, color: AppTheme.textLight),
                    decoration: const InputDecoration(
                      labelText: 'GSTIN / Tax ID',
                      hintText: '15-character GSTIN (optional)',
                      prefixIcon: Icon(Icons.badge_rounded, size: 16),
                    ),
                  ),
                  const SizedBox(height: 10),

                  if (isMobile) ...[
                    TextField(
                      controller: limitCtrl,
                      keyboardType: TextInputType.number,
                      style: const TextStyle(fontSize: 12, color: AppTheme.textLight),
                      decoration: const InputDecoration(
                        labelText: 'Credit Limit (₹)',
                        prefixIcon: Icon(Icons.speed_rounded, size: 16),
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: balanceCtrl,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      style: const TextStyle(fontSize: 12, color: AppTheme.textLight),
                      decoration: InputDecoration(
                        labelText: isEditing ? 'Current Due Balance (₹)' : 'Opening Due Balance (₹)',
                        prefixIcon: const Icon(Icons.account_balance_wallet_outlined, size: 16),
                      ),
                    ),
                  ] else
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: limitCtrl,
                            keyboardType: TextInputType.number,
                            style: const TextStyle(fontSize: 12, color: AppTheme.textLight),
                            decoration: const InputDecoration(
                              labelText: 'Credit Limit (₹)',
                              prefixIcon: Icon(Icons.speed_rounded, size: 16),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: TextField(
                            controller: balanceCtrl,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            style: const TextStyle(fontSize: 12, color: AppTheme.textLight),
                            decoration: InputDecoration(
                              labelText: isEditing ? 'Current Due Balance (₹)' : 'Opening Due Balance (₹)',
                              prefixIcon: const Icon(Icons.account_balance_wallet_outlined, size: 16),
                            ),
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ),
          ),
          actions: [
            Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.end,
              children: [
                OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppTheme.textLight,
                    side: const BorderSide(color: AppTheme.cardBorder),
                  ),
                  onPressed: () => Navigator.pop(dialogCtx),
                  child: const Text('Cancel'),
                ),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryBlue,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                  ),
                  icon: const Icon(Icons.save_rounded, size: 16),
                  label: Text(isEditing ? 'Update Customer' : 'Create Customer', style: const TextStyle(fontWeight: FontWeight.bold)),
                  onPressed: () async {
                    final name = nameCtrl.text.trim();
                    if (name.isEmpty) {
                      _showModernSnackBar(
                        context,
                        'Please enter a valid Customer Name',
                        icon: Icons.error_outline_rounded,
                        backgroundColor: const Color(0xFFE11D48),
                      );
                      return;
                    }

                    final repo = ref.read(customerRepositoryProvider);
                    if (isEditing) {
                      final updated = Customer(
                        id: customer.id,
                        name: name,
                        phone: phoneCtrl.text.trim().isEmpty ? null : phoneCtrl.text.trim(),
                        email: emailCtrl.text.trim().isEmpty ? null : emailCtrl.text.trim(),
                        taxNumber: gstinCtrl.text.trim().isEmpty ? null : gstinCtrl.text.trim(),
                        creditLimit: double.tryParse(limitCtrl.text) ?? customer.creditLimit,
                        currentBalance: double.tryParse(balanceCtrl.text) ?? customer.currentBalance,
                        loyaltyPoints: customer.loyaltyPoints,
                      );
                      await repo.updateCustomer(updated);
                    } else {
                      final newCust = Customer(
                        id: 'cust_${const Uuid().v4().substring(0, 8)}',
                        name: name,
                        phone: phoneCtrl.text.trim().isEmpty ? null : phoneCtrl.text.trim(),
                        email: emailCtrl.text.trim().isEmpty ? null : emailCtrl.text.trim(),
                        taxNumber: gstinCtrl.text.trim().isEmpty ? null : gstinCtrl.text.trim(),
                        creditLimit: double.tryParse(limitCtrl.text) ?? 10000.0,
                        currentBalance: double.tryParse(balanceCtrl.text) ?? 0.0,
                      );
                      await repo.addCustomer(newCust);
                    }

                    ref.invalidate(customersProvider);
                    ref.invalidate(dashboardMetricsProvider);
                    if (dialogCtx.mounted) {
                      Navigator.pop(dialogCtx);
                      _showModernSnackBar(
                        context,
                        isEditing ? 'Customer profile updated successfully' : 'New customer "$name" registered successfully',
                        icon: Icons.check_circle_rounded,
                      );
                    }
                  },
                ),
              ],
            ),
          ],
        );
      },
    );
  }

  // --- ACTION ALERT 4: CUSTOMER STATEMENT / LEDGER DETAILS MODAL ---
  void _showCustomerStatementDialog(BuildContext context, Customer customer, String currency) {
    final creditUsedPct = customer.creditLimit > 0
        ? (customer.currentBalance / customer.creditLimit).clamp(0.0, 1.0)
        : 0.0;

    showDialog(
      context: context,
      builder: (dialogCtx) {
        final isMobile = AppTheme.isMobile(dialogCtx);
        return AlertDialog(
          backgroundColor: const Color(0xFF141F32),
          insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
            side: const BorderSide(color: AppTheme.cardBorder),
          ),
          title: Row(
            children: [
              CircleAvatar(
                radius: 16,
                backgroundColor: _getAvatarColor(customer.name).withValues(alpha: 0.18),
                child: Text(
                  customer.name.isNotEmpty ? customer.name.substring(0, 1).toUpperCase() : 'C',
                  style: TextStyle(fontWeight: FontWeight.bold, color: _getAvatarColor(customer.name), fontSize: 13),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      customer.name,
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      'Customer Code: ${customer.id}',
                      style: const TextStyle(fontSize: 10, color: AppTheme.textMuted),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
          content: SizedBox(
            width: isMobile ? double.maxFinite : 480,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Ledger Financial Stats Container
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E293B),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: AppTheme.cardBorder),
                    ),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Outstanding Due:', style: TextStyle(fontSize: 12, color: AppTheme.textMuted)),
                            Text(
                              '$currency${customer.currentBalance.toStringAsFixed(2)}',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w900,
                                color: customer.currentBalance > 0 ? const Color(0xFFFB7185) : const Color(0xFF34D399),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Credit Limit Allowed:', style: TextStyle(fontSize: 12, color: AppTheme.textMuted)),
                            Text(
                              '$currency${customer.creditLimit.toStringAsFixed(2)}',
                              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.white),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        // Credit utilization bar
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: creditUsedPct,
                            minHeight: 6,
                            backgroundColor: const Color(0xFF0F172A),
                            valueColor: AlwaysStoppedAnimation<Color>(
                              creditUsedPct > 0.85
                                  ? const Color(0xFFEF4444)
                                  : (creditUsedPct > 0.5 ? const Color(0xFFF59E0B) : const Color(0xFF10B981)),
                            ),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Align(
                          alignment: Alignment.centerRight,
                          child: Text(
                            '${(creditUsedPct * 100).toStringAsFixed(0)}% credit utilized',
                            style: const TextStyle(fontSize: 9, color: AppTheme.textSecondary),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Contact information list
                  const Text('CONTACT & TAX INFORMATION', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppTheme.accentCyan)),
                  const SizedBox(height: 6),
                  _buildStatementInfoRow(Icons.phone_rounded, 'Phone', customer.phone ?? 'Not specified'),
                  _buildStatementInfoRow(Icons.email_outlined, 'Email', customer.email ?? 'Not specified'),
                  _buildStatementInfoRow(Icons.badge_rounded, 'GSTIN', customer.taxNumber ?? 'Unregistered'),
                ],
              ),
            ),
          ),
          actions: [
            Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.end,
              children: [
                if (customer.currentBalance > 0)
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF059669)),
                    icon: const Icon(Icons.payments_rounded, size: 15),
                    label: const Text('Receive Payment'),
                    onPressed: () {
                      Navigator.pop(dialogCtx);
                      _showReceivePaymentDialog(context, customer);
                    },
                  ),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryBlue),
                  icon: const Icon(Icons.edit_note_rounded, size: 15),
                  label: const Text('Edit Details'),
                  onPressed: () {
                    Navigator.pop(dialogCtx);
                    _showCustomerFormDialog(context, customer: customer);
                  },
                ),
                TextButton(
                  onPressed: () => Navigator.pop(dialogCtx),
                  child: const Text('Close'),
                ),
              ],
            ),
          ],
        );
      },
    );
  }

  Widget _buildStatementInfoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 14, color: AppTheme.textMuted),
          const SizedBox(width: 8),
          SizedBox(width: 60, child: Text(label, style: const TextStyle(fontSize: 11, color: AppTheme.textMuted))),
          Expanded(child: Text(value, style: const TextStyle(fontSize: 11, color: AppTheme.textLight))),
        ],
      ),
    );
  }

  // --- STYLIZED FLOATING SNACKBAR / ACTION NOTIFICATION ---
  void _showModernSnackBar(
    BuildContext context,
    String message, {
    IconData icon = Icons.info_outline_rounded,
    Color backgroundColor = const Color(0xFF0284C7),
  }) {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        backgroundColor: backgroundColor,
        duration: const Duration(seconds: 3),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        content: Row(
          children: [
            Icon(icon, color: Colors.white, size: 18),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _getAvatarColor(String name) {
    final colors = [
      const Color(0xFF38BDF8),
      const Color(0xFF818CF8),
      const Color(0xFFA78BFA),
      const Color(0xFF34D399),
      const Color(0xFFFBBF24),
      const Color(0xFFFB7185),
    ];
    if (name.isEmpty) return colors.first;
    return colors[name.codeUnitAt(0) % colors.length];
  }
}
