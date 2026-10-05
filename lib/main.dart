import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/theme/app_theme.dart';
import 'domain/state/pos_providers.dart';
import 'presentation/screens/dashboard_screen.dart';
import 'presentation/screens/parties_screen.dart';
import 'presentation/screens/pos_billing_screen.dart';
import 'presentation/screens/product_management_screen.dart';
import 'presentation/screens/purchases_screen.dart';
import 'presentation/screens/reports_screen.dart';
import 'presentation/screens/settings_hub_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    const ProviderScope(
      child: AntigravityBillingApp(),
    ),
  );
}

class AntigravityBillingApp extends StatelessWidget {
  const AntigravityBillingApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'BillPro — Retail Billing Software',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      home: const MainNavigationShell(),
    );
  }
}

// ---------------------------------------------------------------------------
// Navigation destination model
// ---------------------------------------------------------------------------
class _NavDest {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  const _NavDest(this.icon, this.activeIcon, this.label);
}

const List<_NavDest> _destinations = [
  _NavDest(Icons.space_dashboard_outlined, Icons.space_dashboard_rounded, 'Dashboard'),
  _NavDest(Icons.point_of_sale_outlined, Icons.point_of_sale_rounded, 'Sales'),
  _NavDest(Icons.local_shipping_outlined, Icons.local_shipping_rounded, 'Purchase'),
  _NavDest(Icons.inventory_2_outlined, Icons.inventory_2_rounded, 'Inventory'),
  _NavDest(Icons.people_alt_outlined, Icons.people_alt_rounded, 'Customers'),
  _NavDest(Icons.insights_rounded, Icons.insights_rounded, 'Reports'),
  _NavDest(Icons.tune_rounded, Icons.tune_rounded, 'Settings'),
];

// ---------------------------------------------------------------------------
// Main Navigation Shell — responds to screen width
// ---------------------------------------------------------------------------
class MainNavigationShell extends ConsumerStatefulWidget {
  const MainNavigationShell({super.key});

  @override
  ConsumerState<MainNavigationShell> createState() => _MainNavigationShellState();
}

class _MainNavigationShellState extends ConsumerState<MainNavigationShell> {
  int _selectedTabIndex = 1;
  final TextEditingController _globalSearchController = TextEditingController();

  @override
  void dispose() {
    _globalSearchController.dispose();
    super.dispose();
  }

  void _onDestinationSelected(int index) {
    setState(() => _selectedTabIndex = index);
  }

  @override
  Widget build(BuildContext context) {
    final companyAsync = ref.watch(companyProfileProvider);
    final company = companyAsync.value;
    final tradeName = company?.tradeName.isNotEmpty == true ? company!.tradeName : 'My Business';
    final branchName = company?.branchName.isNotEmpty == true ? company!.branchName : 'Main Store';
    final metrics = ref.watch(dashboardMetricsProvider).value;
    final heldDraftsCount = ref.watch(cartNotifierProvider).heldCarts.length;
    final products = ref.watch(productsProvider).value ?? [];
    final lowStockCount = products.where((p) => p.stockQuantity <= 15).length;
    final alertCount = heldDraftsCount + lowStockCount;

    // Live mini bar data
    final List<double> miniBarHeights;
    if (metrics != null && metrics.salesTrend.isNotEmpty) {
      final rawTotals = metrics.salesTrend.take(7).map((e) => e.amount).toList();
      final maxVal = rawTotals.fold<double>(0.0, max);
      miniBarHeights = rawTotals
          .map((val) => maxVal > 0 ? (val / maxVal).clamp(0.18, 1.0) : 0.25)
          .toList();
    } else {
      miniBarHeights = [0.2, 0.45, 0.35, 0.7, 0.5, 0.85, 0.6];
    }

    final screens = [
      DashboardScreen(onNavigateTab: _onDestinationSelected),
      PosBillingScreen(onNavigateTab: _onDestinationSelected),
      const PurchasesScreen(),
      const ProductManagementScreen(),
      const CustomersScreen(),
      const ReportsScreen(),
      const SettingsHubScreen(),
    ];

    final isMobile = AppTheme.isMobile(context);
    final isTablet = AppTheme.isTablet(context);

    // ─── MOBILE LAYOUT ────────────────────────────────────────────────────
    if (isMobile) {
      return Scaffold(
        backgroundColor: AppTheme.darkBg,
        appBar: _buildMobileAppBar(tradeName, branchName, alertCount, heldDraftsCount, lowStockCount),
        drawer: _buildMobileDrawer(tradeName, branchName),
        body: IndexedStack(
          index: _selectedTabIndex,
          children: screens,
        ),
        bottomNavigationBar: _buildBottomNavBar(),
      );
    }

    // ─── TABLET LAYOUT ────────────────────────────────────────────────────
    if (isTablet) {
      return Scaffold(
        backgroundColor: AppTheme.darkBg,
        appBar: _buildMobileAppBar(tradeName, branchName, alertCount, heldDraftsCount, lowStockCount),
        body: Row(
          children: [
            _buildNavigationRail(),
            const VerticalDivider(width: 1, color: AppTheme.cardBorder),
            Expanded(
              child: IndexedStack(
                index: _selectedTabIndex,
                children: screens,
              ),
            ),
          ],
        ),
      );
    }

    // ─── DESKTOP LAYOUT ───────────────────────────────────────────────────
    return Scaffold(
      backgroundColor: AppTheme.darkBg,
      body: Row(
        children: [
          _buildDesktopSidebar(
            tradeName: tradeName,
            branchName: branchName,
            miniBarHeights: miniBarHeights,
          ),
          const VerticalDivider(width: 1, color: AppTheme.cardBorder),
          Expanded(
            child: Column(
              children: [
                _buildDesktopTopBar(
                  tradeName: tradeName,
                  company: company,
                  alertCount: alertCount,
                  heldDraftsCount: heldDraftsCount,
                  lowStockCount: lowStockCount,
                ),
                const Divider(height: 1, color: AppTheme.cardBorder),
                Expanded(
                  child: IndexedStack(
                    index: _selectedTabIndex,
                    children: screens,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Mobile / Tablet AppBar ────────────────────────────────────────────────
  PreferredSizeWidget _buildMobileAppBar(
    String tradeName,
    String branchName,
    int alertCount,
    int heldDraftsCount,
    int lowStockCount,
  ) {
    return AppBar(
      backgroundColor: AppTheme.sidebarBg,
      elevation: 0,
      titleSpacing: 12,
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF2563EB), Color(0xFF06B6D4)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(7),
            ),
            child: const Icon(Icons.receipt_long_rounded, color: Colors.white, size: 18),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  tradeName,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textLight,
                  ),
                ),
                Text(
                  branchName,
                  style: const TextStyle(fontSize: 10, color: AppTheme.accentCyan),
                ),
              ],
            ),
          ),
        ],
      ),
      actions: [
        // Notification badge
        Stack(
          children: [
            IconButton(
              icon: Icon(
                alertCount > 0
                    ? Icons.notifications_active_rounded
                    : Icons.notifications_none_rounded,
                size: 22,
                color: alertCount > 0 ? AppTheme.accentAmber : AppTheme.textMuted,
              ),
              onPressed: () => _showAlertSnackbar(context, heldDraftsCount, lowStockCount),
            ),
            if (alertCount > 0)
              Positioned(
                right: 6,
                top: 6,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                  decoration: BoxDecoration(
                    color: AppTheme.accentRose,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '$alertCount',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 9,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(width: 4),
      ],
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(1),
        child: Container(height: 1, color: AppTheme.cardBorder),
      ),
    );
  }

  // ── Bottom Navigation Bar (Mobile) ────────────────────────────────────────
  Widget _buildBottomNavBar() {
    return Container(
      decoration: const BoxDecoration(
        color: AppTheme.sidebarBg,
        border: Border(top: BorderSide(color: AppTheme.cardBorder)),
      ),
      child: SafeArea(
        child: NavigationBar(
          backgroundColor: AppTheme.sidebarBg,
          indicatorColor: AppTheme.sidebarActiveBg,
          selectedIndex: _selectedTabIndex,
          onDestinationSelected: _onDestinationSelected,
          labelBehavior: NavigationDestinationLabelBehavior.onlyShowSelected,
          destinations: _destinations
              .map(
                (d) => NavigationDestination(
                  icon: Icon(d.icon, color: AppTheme.textMuted),
                  selectedIcon: Icon(d.activeIcon, color: Colors.white),
                  label: d.label,
                ),
              )
              .toList(),
        ),
      ),
    );
  }

  // ── Mobile Navigation Drawer ──────────────────────────────────────────────
  Widget _buildMobileDrawer(String tradeName, String branchName) {
    return Drawer(
      backgroundColor: AppTheme.sidebarBg,
      child: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF2563EB), Color(0xFF06B6D4)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(8),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF2563EB).withValues(alpha: 0.35),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.receipt_long_rounded,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          tradeName,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.textLight,
                          ),
                        ),
                        Text(
                          branchName,
                          style: const TextStyle(fontSize: 10, color: AppTheme.accentCyan),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1, color: AppTheme.cardBorder),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
                itemCount: _destinations.length,
                itemBuilder: (ctx, idx) {
                  final d = _destinations[idx];
                  final isSelected = _selectedTabIndex == idx;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: ListTile(
                      dense: true,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                      tileColor: isSelected ? AppTheme.sidebarActiveBg : Colors.transparent,
                      leading: Icon(
                        isSelected ? d.activeIcon : d.icon,
                        color: isSelected ? Colors.white : AppTheme.textMuted,
                        size: 20,
                      ),
                      title: Text(
                        d.label,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                          color: isSelected ? Colors.white : AppTheme.textLight,
                        ),
                      ),
                      onTap: () {
                        Navigator.pop(ctx);
                        _onDestinationSelected(idx);
                      },
                    ),
                  );
                },
              ),
            ),
            const Divider(height: 1, color: AppTheme.cardBorder),
            const Padding(
              padding: EdgeInsets.all(12),
              child: Text(
                'BillPro • Universal Edition',
                style: TextStyle(fontSize: 10, color: AppTheme.textMuted),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Navigation Rail (Tablet) ──────────────────────────────────────────────
  Widget _buildNavigationRail() {
    return NavigationRail(
      backgroundColor: AppTheme.sidebarBg,
      selectedIndex: _selectedTabIndex,
      onDestinationSelected: _onDestinationSelected,
      useIndicator: true,
      indicatorColor: AppTheme.sidebarActiveBg,
      labelType: NavigationRailLabelType.all,
      selectedLabelTextStyle: const TextStyle(
        color: Colors.white,
        fontSize: 11,
        fontWeight: FontWeight.bold,
      ),
      unselectedLabelTextStyle: const TextStyle(
        color: AppTheme.textMuted,
        fontSize: 11,
      ),
      destinations: _destinations
          .map(
            (d) => NavigationRailDestination(
              icon: Icon(d.icon, color: AppTheme.textMuted, size: 22),
              selectedIcon: Icon(d.activeIcon, color: Colors.white, size: 22),
              label: Text(d.label),
            ),
          )
          .toList(),
    );
  }

  // ── Desktop Sidebar (Full) ────────────────────────────────────────────────
  Widget _buildDesktopSidebar({
    required String tradeName,
    required String branchName,
    required List<double> miniBarHeights,
  }) {
    return Container(
      width: 230,
      color: AppTheme.sidebarBg,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Brand header
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF2563EB), Color(0xFF06B6D4)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(8),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF2563EB).withValues(alpha: 0.35),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.receipt_long_rounded,
                    color: Colors.white,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        tradeName,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.textLight,
                          letterSpacing: 0.2,
                        ),
                      ),
                      Text(
                        branchName,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppTheme.accentCyan,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: AppTheme.cardBorder),
          const SizedBox(height: 12),

          // Navigation items
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              children: _destinations.asMap().entries.map((entry) {
                return _buildSidebarNavItem(
                  index: entry.key,
                  dest: entry.value,
                );
              }).toList(),
            ),
          ),

          // Mini chart
          Padding(
            padding: const EdgeInsets.all(12),
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFF141F32),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppTheme.cardBorder),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Weekly Sales Trend',
                        style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.textMuted),
                      ),
                      Icon(Icons.trending_up_rounded,
                          size: 14, color: AppTheme.accentCyan),
                    ],
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    height: 38,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: miniBarHeights.map(_buildMiniBar).toList(),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Offline badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            color: const Color(0xFF090D16),
            child: const Row(
              children: [
                Icon(Icons.offline_bolt_rounded,
                    size: 14, color: AppTheme.primaryEmerald),
                SizedBox(width: 8),
                Text(
                  'Offline SQLite Engine Active',
                  style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textMuted),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Desktop Top Bar ───────────────────────────────────────────────────────
  Widget _buildDesktopTopBar({
    required String tradeName,
    required dynamic company,
    required int alertCount,
    required int heldDraftsCount,
    required int lowStockCount,
  }) {
    return Container(
      height: 56,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      color: AppTheme.sidebarBg,
      child: Row(
        children: [
          // Search bar
          Container(
            width: 340,
            height: 36,
            decoration: BoxDecoration(
              color: AppTheme.darkBg,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: AppTheme.cardBorder),
            ),
            child: TextField(
              controller: _globalSearchController,
              onSubmitted: (query) {
                if (query.trim().isNotEmpty) _onDestinationSelected(1);
              },
              style: const TextStyle(fontSize: 13),
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search, size: 18, color: AppTheme.textMuted),
                hintText: 'Search...',
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(vertical: 8),
              ),
            ),
          ),
          const Spacer(),
          // Notification icon
          Stack(
            children: [
              IconButton(
                icon: Icon(
                  alertCount > 0
                      ? Icons.notifications_active_rounded
                      : Icons.notifications_none_rounded,
                  size: 20,
                  color: alertCount > 0 ? AppTheme.accentAmber : AppTheme.textMuted,
                ),
                tooltip: 'Notifications & Alerts',
                onPressed: () =>
                    _showAlertSnackbar(context, heldDraftsCount, lowStockCount),
              ),
              if (alertCount > 0)
                Positioned(
                  right: 6,
                  top: 6,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppTheme.accentRose,
                      borderRadius: BorderRadius.circular(10),
                      boxShadow: [
                        BoxShadow(
                          color: AppTheme.accentRose.withValues(alpha: 0.5),
                          blurRadius: 4,
                        ),
                      ],
                    ),
                    child: Text(
                      alertCount > 99 ? '99+' : '$alertCount',
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 9,
                          fontWeight: FontWeight.w900),
                    ),
                  ),
                ),
            ],
          ),
          // Store icon
          IconButton(
            icon: const Icon(Icons.storefront_rounded,
                size: 20, color: AppTheme.textMuted),
            tooltip: 'Store Dashboard',
            onPressed: () => _onDestinationSelected(0),
          ),
          // Avatar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6),
            child: CircleAvatar(
              radius: 14,
              backgroundColor: AppTheme.primaryBlue,
              child: Text(
                tradeName.isNotEmpty
                    ? tradeName.substring(0, 1).toUpperCase()
                    : 'B',
                style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Colors.white),
              ),
            ),
          ),
          const SizedBox(width: 8),
          // GST badge
          Tooltip(
            message: 'GST: ${company?.taxIdentifier ?? "Not configured"}',
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF0284C7), Color(0xFF0EA5E9)],
                ),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF0284C7).withValues(alpha: 0.3),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.verified_rounded,
                      size: 14, color: Colors.white),
                  const SizedBox(width: 5),
                  Text(
                    company?.taxIdentifier?.isNotEmpty == true
                        ? 'GST: ${company!.taxIdentifier}'
                        : 'GST Ready',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Sidebar nav item ──────────────────────────────────────────────────────
  Widget _buildSidebarNavItem({
    required int index,
    required _NavDest dest,
  }) {
    final isSelected = _selectedTabIndex == index;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(6),
          onTap: () => _onDestinationSelected(index),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: isSelected ? AppTheme.sidebarActiveBg : Colors.transparent,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Row(
              children: [
                Icon(
                  isSelected ? dest.activeIcon : dest.icon,
                  size: 20,
                  color: isSelected ? Colors.white : AppTheme.textMuted,
                ),
                const SizedBox(width: 12),
                Text(
                  dest.label,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight:
                        isSelected ? FontWeight.bold : FontWeight.w500,
                    color: isSelected ? Colors.white : AppTheme.textMuted,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── Mini bar chart ────────────────────────────────────────────────────────
  Widget _buildMiniBar(double pct) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 2),
        child: Container(
          height: 38 * pct,
          decoration: BoxDecoration(
            color: AppTheme.primaryBlue.withValues(alpha: 0.7),
            borderRadius: BorderRadius.circular(2),
          ),
        ),
      ),
    );
  }

  // ── Alert snackbar ────────────────────────────────────────────────────────
  void _showAlertSnackbar(
      BuildContext context, int heldDrafts, int lowStock) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Status: $heldDrafts draft bill(s) on hold • $lowStock product(s) low on stock • Offline DB healthy.',
        ),
        backgroundColor: AppTheme.cardBg,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}
