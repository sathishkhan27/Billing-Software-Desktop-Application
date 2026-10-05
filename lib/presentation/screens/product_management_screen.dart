import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../core/theme/app_theme.dart';
import '../../data/models/product.dart';
import '../../domain/state/pos_providers.dart';

enum StockFilter { all, inStock, lowStock, outOfStock }

enum ProductSortOption {
  nameAsc,
  nameDesc,
  stockAsc,
  stockDesc,
  priceAsc,
  priceDesc,
  marginDesc,
}

class ProductManagementScreen extends ConsumerStatefulWidget {
  const ProductManagementScreen({super.key});

  @override
  ConsumerState<ProductManagementScreen> createState() => _ProductManagementScreenState();
}

class _ProductManagementScreenState extends ConsumerState<ProductManagementScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _selectedCategory = 'ALL';
  StockFilter _selectedStockFilter = StockFilter.all;
  ProductSortOption _sortBy = ProductSortOption.nameAsc;

  final ScrollController _horizontalScrollController = ScrollController();
  final ScrollController _verticalScrollController = ScrollController();

  // Exact column widths for pixel-perfect header and row alignment
  static const double colWidthProduct = 260.0;
  static const double colWidthSku = 110.0;
  static const double colWidthCategory = 120.0;
  static const double colWidthStock = 160.0;
  static const double colWidthCostPrice = 110.0;
  static const double colWidthSellingPrice = 115.0;
  static const double colWidthMrp = 105.0;
  static const double colWidthMargin = 95.0;
  static const double colWidthTaxSlab = 115.0;
  static const double colWidthActions = 170.0;

  static const double totalTableWidth = colWidthProduct +
      colWidthSku +
      colWidthCategory +
      colWidthStock +
      colWidthCostPrice +
      colWidthSellingPrice +
      colWidthMrp +
      colWidthMargin +
      colWidthTaxSlab +
      colWidthActions +
      32.0; // padding

  @override
  void dispose() {
    _searchController.dispose();
    _horizontalScrollController.dispose();
    _verticalScrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final productsAsync = ref.watch(productsProvider);
    final categoriesAsync = ref.watch(categoriesProvider);
    final taxSlabsAsync = ref.watch(taxSlabsProvider);
    final currency = ref.watch(currencySymbolProvider);
    final isMobile = AppTheme.isMobile(context);

    return Scaffold(
      backgroundColor: const Color(0xFF0B1120),
      appBar: AppBar(
        backgroundColor: const Color(0xFF131C31),
        elevation: 0,
        titleSpacing: isMobile ? 12 : 20,
        title: isMobile
            ? const Text(
                'Inventory',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
              )
            : Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(9),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryEmerald.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppTheme.primaryEmerald.withValues(alpha: 0.3)),
                    ),
                    child: const Icon(Icons.inventory_2_rounded, color: AppTheme.primaryEmerald, size: 22),
                  ),
                  const SizedBox(width: 14),
                  const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Inventory & Product Catalog',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white, letterSpacing: 0.3),
                      ),
                      Text(
                        'Track stock levels, retail pricing, margins, barcodes, and tax slabs',
                        style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                      ),
                    ],
                  ),
                ],
              ),
        actions: [
          Padding(
            padding: EdgeInsets.only(right: isMobile ? 8 : 16),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (isMobile) ...[
                  IconButton(
                    tooltip: 'Stock Inward (+)',
                    icon: const Icon(Icons.add_shopping_cart, color: AppTheme.accentAmber, size: 20),
                    onPressed: () {
                      final allProds = productsAsync.value ?? [];
                      _openStockInwardDialog(context, allProducts: allProds, currency: currency);
                    },
                  ),
                  IconButton(
                    tooltip: 'Add Product',
                    icon: const Icon(Icons.add_circle, color: AppTheme.primaryEmerald, size: 22),
                    onPressed: () {
                      final taxSlabs = taxSlabsAsync.value ?? [];
                      final categories = categoriesAsync.value ?? [];
                      _openProductDialog(context, taxSlabs: taxSlabs, categories: categories, currency: currency);
                    },
                  ),
                ] else ...[
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppTheme.accentAmber,
                      side: BorderSide(color: AppTheme.accentAmber.withValues(alpha: 0.6), width: 1.2),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    icon: const Icon(Icons.add_shopping_cart, size: 17),
                    label: const Text('Stock Inward (+)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    onPressed: () {
                      final allProds = productsAsync.value ?? [];
                      _openStockInwardDialog(context, allProducts: allProds, currency: currency);
                    },
                  ),
                  const SizedBox(width: 10),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryEmerald,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      elevation: 2,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    icon: const Icon(Icons.add_circle, size: 18),
                    label: const Text('Add Product', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    onPressed: () {
                      final taxSlabs = taxSlabsAsync.value ?? [];
                      final categories = categoriesAsync.value ?? [];
                      _openProductDialog(context, taxSlabs: taxSlabs, categories: categories, currency: currency);
                    },
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
      body: productsAsync.when(
        loading: () => const Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(color: AppTheme.primaryEmerald),
              SizedBox(height: 16),
              Text('Loading product catalog...', style: TextStyle(color: AppTheme.textSecondary)),
            ],
          ),
        ),
        error: (err, stack) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, color: AppTheme.accentRose, size: 48),
              const SizedBox(height: 16),
              Text('Error loading products: $err', style: const TextStyle(color: Colors.white70)),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                icon: const Icon(Icons.refresh),
                label: const Text('Retry'),
                onPressed: () => ref.refresh(productsProvider),
              ),
            ],
          ),
        ),
        data: (allProducts) {
          final categories = categoriesAsync.value ?? [];
          final taxSlabs = taxSlabsAsync.value ?? [];

          // Summary KPI Calculations
          final totalCount = allProducts.length;
          final lowStockCount = allProducts.where((p) => p.stockQuantity > 0 && p.stockQuantity <= 10).length;
          final outOfStockCount = allProducts.where((p) => p.stockQuantity <= 0).length;
          final inStockCount = allProducts.where((p) => p.stockQuantity > 10).length;
          final totalRetailValuation = allProducts.fold<double>(
            0.0,
            (sum, p) => sum + (p.stockQuantity > 0 ? (p.stockQuantity * p.sellingPrice) : 0.0),
          );
          final totalCostValuation = allProducts.fold<double>(
            0.0,
            (sum, p) => sum + (p.stockQuantity > 0 ? (p.stockQuantity * p.costPrice) : 0.0),
          );

          // Filter products based on search, category, and stock filter
          final searchQuery = _searchController.text.trim().toLowerCase();
          List<Product> filteredProducts = allProducts.where((p) {
            // Category filter
            if (_selectedCategory != 'ALL' && p.categoryId != _selectedCategory) {
              return false;
            }

            // Stock filter
            switch (_selectedStockFilter) {
              case StockFilter.inStock:
                if (p.stockQuantity <= 10) return false;
                break;
              case StockFilter.lowStock:
                if (p.stockQuantity <= 0 || p.stockQuantity > 10) return false;
                break;
              case StockFilter.outOfStock:
                if (p.stockQuantity > 0) return false;
                break;
              case StockFilter.all:
                break;
            }

            // Search query
            if (searchQuery.isNotEmpty) {
              final matchName = p.name.toLowerCase().contains(searchQuery);
              final matchBarcode = p.barcode?.toLowerCase().contains(searchQuery) ?? false;
              final matchSku = p.sku?.toLowerCase().contains(searchQuery) ?? false;
              if (!matchName && !matchBarcode && !matchSku) {
                return false;
              }
            }

            return true;
          }).toList();

          // Sorting logic
          filteredProducts.sort((a, b) {
            switch (_sortBy) {
              case ProductSortOption.nameAsc:
                return a.name.toLowerCase().compareTo(b.name.toLowerCase());
              case ProductSortOption.nameDesc:
                return b.name.toLowerCase().compareTo(a.name.toLowerCase());
              case ProductSortOption.stockAsc:
                return a.stockQuantity.compareTo(b.stockQuantity);
              case ProductSortOption.stockDesc:
                return b.stockQuantity.compareTo(a.stockQuantity);
              case ProductSortOption.priceAsc:
                return a.sellingPrice.compareTo(b.sellingPrice);
              case ProductSortOption.priceDesc:
                return b.sellingPrice.compareTo(a.sellingPrice);
              case ProductSortOption.marginDesc:
                final marginA = a.sellingPrice > 0 ? ((a.sellingPrice - a.costPrice) / a.sellingPrice) : 0.0;
                final marginB = b.sellingPrice > 0 ? ((b.sellingPrice - b.costPrice) / b.sellingPrice) : 0.0;
                return marginB.compareTo(marginA);
            }
          });

          return Column(
            children: [
              // Top KPI Analytics Cards Bar
              Container(
                padding: EdgeInsets.symmetric(horizontal: isMobile ? 12 : 20, vertical: 14),
                decoration: const BoxDecoration(
                  color: Color(0xFF111827),
                  border: Border(bottom: BorderSide(color: Color(0xFF1E293B))),
                ),
                child: isMobile
                    ? SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            _buildMetricCard(
                              label: 'Total Products',
                              value: '$totalCount',
                              subtitle: 'Active in catalog',
                              icon: Icons.inventory_2_outlined,
                              color: AppTheme.accentCyan,
                              isSelected: _selectedStockFilter == StockFilter.all,
                              width: 220,
                              onTap: () {
                                setState(() {
                                  _selectedStockFilter = StockFilter.all;
                                });
                              },
                            ),
                            const SizedBox(width: 12),
                            _buildMetricCard(
                              label: 'Total Stock Valuation',
                              value: '$currency${totalRetailValuation.toStringAsFixed(2)}',
                              subtitle: 'Cost Basis: $currency${totalCostValuation.toStringAsFixed(2)}',
                              icon: Icons.account_balance_wallet_outlined,
                              color: AppTheme.primaryEmerald,
                              isSelected: false,
                              width: 250,
                            ),
                            const SizedBox(width: 12),
                            _buildMetricCard(
                              label: 'Low Stock Alert',
                              value: '$lowStockCount',
                              subtitle: 'Requires reordering (≤10)',
                              icon: Icons.warning_amber_rounded,
                              color: AppTheme.accentAmber,
                              isSelected: _selectedStockFilter == StockFilter.lowStock,
                              width: 230,
                              onTap: () {
                                setState(() {
                                  _selectedStockFilter = _selectedStockFilter == StockFilter.lowStock
                                      ? StockFilter.all
                                      : StockFilter.lowStock;
                                });
                              },
                            ),
                            const SizedBox(width: 12),
                            _buildMetricCard(
                              label: 'Out of Stock',
                              value: '$outOfStockCount',
                              subtitle: 'Zero inventory items',
                              icon: Icons.remove_circle_outline,
                              color: AppTheme.accentRose,
                              isSelected: _selectedStockFilter == StockFilter.outOfStock,
                              width: 220,
                              onTap: () {
                                setState(() {
                                  _selectedStockFilter = _selectedStockFilter == StockFilter.outOfStock
                                      ? StockFilter.all
                                      : StockFilter.outOfStock;
                                });
                              },
                            ),
                          ],
                        ),
                      )
                    : Row(
                        children: [
                          _buildMetricCard(
                            label: 'Total Products',
                            value: '$totalCount',
                            subtitle: 'Active in catalog',
                            icon: Icons.inventory_2_outlined,
                            color: AppTheme.accentCyan,
                            isSelected: _selectedStockFilter == StockFilter.all,
                            onTap: () {
                              setState(() {
                                _selectedStockFilter = StockFilter.all;
                              });
                            },
                          ),
                          const SizedBox(width: 14),
                          _buildMetricCard(
                            label: 'Total Stock Valuation',
                            value: '$currency${totalRetailValuation.toStringAsFixed(2)}',
                            subtitle: 'Cost Basis: $currency${totalCostValuation.toStringAsFixed(2)}',
                            icon: Icons.account_balance_wallet_outlined,
                            color: AppTheme.primaryEmerald,
                            isSelected: false,
                          ),
                          const SizedBox(width: 14),
                          _buildMetricCard(
                            label: 'Low Stock Alert',
                            value: '$lowStockCount',
                            subtitle: 'Requires reordering (≤10)',
                            icon: Icons.warning_amber_rounded,
                            color: AppTheme.accentAmber,
                            isSelected: _selectedStockFilter == StockFilter.lowStock,
                            onTap: () {
                              setState(() {
                                _selectedStockFilter = _selectedStockFilter == StockFilter.lowStock
                                    ? StockFilter.all
                                    : StockFilter.lowStock;
                              });
                            },
                          ),
                          const SizedBox(width: 14),
                          _buildMetricCard(
                            label: 'Out of Stock',
                            value: '$outOfStockCount',
                            subtitle: 'Zero inventory items',
                            icon: Icons.remove_circle_outline,
                            color: AppTheme.accentRose,
                            isSelected: _selectedStockFilter == StockFilter.outOfStock,
                            onTap: () {
                              setState(() {
                                _selectedStockFilter = _selectedStockFilter == StockFilter.outOfStock
                                    ? StockFilter.all
                                    : StockFilter.outOfStock;
                              });
                            },
                          ),
                        ],
                      ),
              ),

              // Filter Controls & Action Bar
              Padding(
                padding: EdgeInsets.symmetric(horizontal: isMobile ? 12 : 20, vertical: isMobile ? 8 : 12),
                child: isMobile
                    ? Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // Search Bar full width
                          TextField(
                            controller: _searchController,
                            style: const TextStyle(color: Colors.white, fontSize: 13),
                            decoration: InputDecoration(
                              hintText: 'Search product name, barcode, SKU...',
                              hintStyle: const TextStyle(color: AppTheme.textSecondary, fontSize: 13),
                              prefixIcon: const Icon(Icons.search, color: AppTheme.textSecondary, size: 19),
                              suffixIcon: _searchController.text.isNotEmpty
                                  ? IconButton(
                                      icon: const Icon(Icons.clear, size: 18, color: AppTheme.textSecondary),
                                      onPressed: () {
                                        setState(() {
                                          _searchController.clear();
                                        });
                                      },
                                    )
                                  : null,
                              isDense: true,
                              filled: true,
                              fillColor: const Color(0xFF1E293B),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: const BorderSide(color: AppTheme.cardBorder),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: const BorderSide(color: AppTheme.cardBorder),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: const BorderSide(color: AppTheme.primaryEmerald, width: 1.5),
                              ),
                            ),
                            onChanged: (_) => setState(() {}),
                          ),
                          const SizedBox(height: 8),
                          // Stock Chips horizontally scrollable
                          SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: Container(
                              decoration: BoxDecoration(
                                color: const Color(0xFF1E293B),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: AppTheme.cardBorder),
                              ),
                              padding: const EdgeInsets.all(3),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  _buildFilterChip('All (${allProducts.length})', StockFilter.all),
                                  _buildFilterChip('In Stock ($inStockCount)', StockFilter.inStock),
                                  _buildFilterChip('Low ($lowStockCount)', StockFilter.lowStock, accentColor: AppTheme.accentAmber),
                                  _buildFilterChip('Out ($outOfStockCount)', StockFilter.outOfStock, accentColor: AppTheme.accentRose),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          // Dropdowns and Refresh in row
                          Row(
                            children: [
                              Expanded(
                                flex: 5,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF1E293B),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: AppTheme.cardBorder),
                                  ),
                                  child: DropdownButtonHideUnderline(
                                    child: DropdownButton<String>(
                                      value: _selectedCategory,
                                      isExpanded: true,
                                      dropdownColor: const Color(0xFF1E293B),
                                      style: const TextStyle(color: Colors.white, fontSize: 12),
                                      icon: const Icon(Icons.category_outlined, color: AppTheme.textSecondary, size: 16),
                                      items: [
                                        const DropdownMenuItem(value: 'ALL', child: Text('All Categories', overflow: TextOverflow.ellipsis)),
                                        ...categories.map(
                                          (c) => DropdownMenuItem(
                                            value: c['id'],
                                            child: Text(c['name'] ?? '', overflow: TextOverflow.ellipsis),
                                          ),
                                        ),
                                      ],
                                      onChanged: (val) {
                                        if (val != null) {
                                          setState(() {
                                            _selectedCategory = val;
                                          });
                                        }
                                      },
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                flex: 5,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF1E293B),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: AppTheme.cardBorder),
                                  ),
                                  child: DropdownButtonHideUnderline(
                                    child: DropdownButton<ProductSortOption>(
                                      value: _sortBy,
                                      isExpanded: true,
                                      dropdownColor: const Color(0xFF1E293B),
                                      style: const TextStyle(color: Colors.white, fontSize: 12),
                                      icon: const Icon(Icons.sort, color: AppTheme.textSecondary, size: 16),
                                      items: const [
                                        DropdownMenuItem(value: ProductSortOption.nameAsc, child: Text('Name (A-Z)', overflow: TextOverflow.ellipsis)),
                                        DropdownMenuItem(value: ProductSortOption.nameDesc, child: Text('Name (Z-A)', overflow: TextOverflow.ellipsis)),
                                        DropdownMenuItem(value: ProductSortOption.stockAsc, child: Text('Stock (Lowest)', overflow: TextOverflow.ellipsis)),
                                        DropdownMenuItem(value: ProductSortOption.stockDesc, child: Text('Stock (Highest)', overflow: TextOverflow.ellipsis)),
                                        DropdownMenuItem(value: ProductSortOption.priceAsc, child: Text('Price (Lowest)', overflow: TextOverflow.ellipsis)),
                                        DropdownMenuItem(value: ProductSortOption.priceDesc, child: Text('Price (Highest)', overflow: TextOverflow.ellipsis)),
                                        DropdownMenuItem(value: ProductSortOption.marginDesc, child: Text('Margin (High)', overflow: TextOverflow.ellipsis)),
                                      ],
                                      onChanged: (val) {
                                        if (val != null) {
                                          setState(() {
                                            _sortBy = val;
                                          });
                                        }
                                      },
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              IconButton(
                                tooltip: 'Refresh Product List',
                                style: IconButton.styleFrom(
                                  backgroundColor: const Color(0xFF1E293B),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                    side: const BorderSide(color: AppTheme.cardBorder),
                                  ),
                                ),
                                icon: const Icon(Icons.refresh, color: AppTheme.textSecondary, size: 18),
                                onPressed: () => ref.refresh(productsProvider),
                              ),
                            ],
                          ),
                        ],
                      )
                    : Row(
                        children: [
                          // Search Bar
                          Expanded(
                            flex: 4,
                            child: TextField(
                              controller: _searchController,
                              style: const TextStyle(color: Colors.white, fontSize: 13),
                              decoration: InputDecoration(
                                hintText: 'Search by product name, barcode, or SKU...',
                                hintStyle: const TextStyle(color: AppTheme.textSecondary, fontSize: 13),
                                prefixIcon: const Icon(Icons.search, color: AppTheme.textSecondary, size: 19),
                                suffixIcon: _searchController.text.isNotEmpty
                                    ? IconButton(
                                        icon: const Icon(Icons.clear, size: 18, color: AppTheme.textSecondary),
                                        onPressed: () {
                                          setState(() {
                                            _searchController.clear();
                                          });
                                        },
                                      )
                                    : null,
                                isDense: true,
                                filled: true,
                                fillColor: const Color(0xFF1E293B),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  borderSide: const BorderSide(color: AppTheme.cardBorder),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  borderSide: const BorderSide(color: AppTheme.cardBorder),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  borderSide: const BorderSide(color: AppTheme.primaryEmerald, width: 1.5),
                                ),
                              ),
                              onChanged: (_) => setState(() {}),
                            ),
                          ),
                          const SizedBox(width: 12),

                          // Category Filter Dropdown
                          Container(
                            width: 180,
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            decoration: BoxDecoration(
                              color: const Color(0xFF1E293B),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: AppTheme.cardBorder),
                            ),
                            child: DropdownButtonHideUnderline(
                              child: DropdownButton<String>(
                                value: _selectedCategory,
                                isExpanded: true,
                                dropdownColor: const Color(0xFF1E293B),
                                style: const TextStyle(color: Colors.white, fontSize: 13),
                                icon: const Icon(Icons.category_outlined, color: AppTheme.textSecondary, size: 18),
                                items: [
                                  const DropdownMenuItem(value: 'ALL', child: Text('All Categories')),
                                  ...categories.map(
                                    (c) => DropdownMenuItem(
                                      value: c['id'],
                                      child: Text(c['name'] ?? ''),
                                    ),
                                  ),
                                ],
                                onChanged: (val) {
                                  if (val != null) {
                                    setState(() {
                                      _selectedCategory = val;
                                    });
                                  }
                                },
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),

                          // Stock Status Chips
                          Container(
                            decoration: BoxDecoration(
                              color: const Color(0xFF1E293B),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: AppTheme.cardBorder),
                            ),
                            padding: const EdgeInsets.all(3),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                _buildFilterChip('All (${allProducts.length})', StockFilter.all),
                                _buildFilterChip('In Stock ($inStockCount)', StockFilter.inStock),
                                _buildFilterChip('Low Stock ($lowStockCount)', StockFilter.lowStock, accentColor: AppTheme.accentAmber),
                                _buildFilterChip('Out ($outOfStockCount)', StockFilter.outOfStock, accentColor: AppTheme.accentRose),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),

                          // Sorting Dropdown
                          Container(
                            width: 170,
                            padding: const EdgeInsets.symmetric(horizontal: 10),
                            decoration: BoxDecoration(
                              color: const Color(0xFF1E293B),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: AppTheme.cardBorder),
                            ),
                            child: DropdownButtonHideUnderline(
                              child: DropdownButton<ProductSortOption>(
                                value: _sortBy,
                                isExpanded: true,
                                dropdownColor: const Color(0xFF1E293B),
                                style: const TextStyle(color: Colors.white, fontSize: 12),
                                icon: const Icon(Icons.sort, color: AppTheme.textSecondary, size: 18),
                                items: const [
                                  DropdownMenuItem(value: ProductSortOption.nameAsc, child: Text('Sort: Name (A-Z)')),
                                  DropdownMenuItem(value: ProductSortOption.nameDesc, child: Text('Sort: Name (Z-A)')),
                                  DropdownMenuItem(value: ProductSortOption.stockAsc, child: Text('Sort: Stock (Lowest)')),
                                  DropdownMenuItem(value: ProductSortOption.stockDesc, child: Text('Sort: Stock (Highest)')),
                                  DropdownMenuItem(value: ProductSortOption.priceAsc, child: Text('Sort: Price (Lowest)')),
                                  DropdownMenuItem(value: ProductSortOption.priceDesc, child: Text('Sort: Price (Highest)')),
                                  DropdownMenuItem(value: ProductSortOption.marginDesc, child: Text('Sort: Margin % (High)')),
                                ],
                                onChanged: (val) {
                                  if (val != null) {
                                    setState(() {
                                      _sortBy = val;
                                    });
                                  }
                                },
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),

                          // Refresh Button
                          IconButton(
                            tooltip: 'Refresh Product List',
                            style: IconButton.styleFrom(
                              backgroundColor: const Color(0xFF1E293B),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                                side: const BorderSide(color: AppTheme.cardBorder),
                              ),
                            ),
                            icon: const Icon(Icons.refresh, color: AppTheme.textSecondary, size: 19),
                            onPressed: () => ref.refresh(productsProvider),
                          ),
                        ],
                      ),
              ),

              // Items Count & Active Filter Indicator
              Padding(
                padding: EdgeInsets.symmetric(horizontal: isMobile ? 12 : 22, vertical: 2),
                child: Row(
                  children: [
                    Text(
                      'Showing ${filteredProducts.length} of ${allProducts.length} items',
                      style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12, fontWeight: FontWeight.w500),
                    ),
                    if (_selectedStockFilter != StockFilter.all || _selectedCategory != 'ALL' || searchQuery.isNotEmpty) ...[
                      const SizedBox(width: 10),
                      InkWell(
                        onTap: () {
                          setState(() {
                            _selectedCategory = 'ALL';
                            _selectedStockFilter = StockFilter.all;
                            _searchController.clear();
                          });
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppTheme.accentRose.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.close, size: 12, color: AppTheme.accentRose),
                              SizedBox(width: 4),
                              Text('Reset Filters', style: TextStyle(color: AppTheme.accentRose, fontSize: 11)),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 6),

              // Product Data Table (Desktop Sticky-Header Layout with Exact Alignment)
              Expanded(
                child: filteredProducts.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.inventory_2_outlined, color: AppTheme.textSecondary, size: 54),
                            const SizedBox(height: 12),
                            const Text(
                              'No products found matching the criteria',
                              style: TextStyle(color: Colors.white70, fontSize: 16, fontWeight: FontWeight.w500),
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              'Try adjusting your search query, category, or stock status filter',
                              style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
                            ),
                            const SizedBox(height: 16),
                            ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppTheme.primaryEmerald,
                                foregroundColor: Colors.white,
                              ),
                              icon: const Icon(Icons.add),
                              label: const Text('Add New Product'),
                              onPressed: () => _openProductDialog(
                                context,
                                taxSlabs: taxSlabs,
                                categories: categories,
                                currency: currency,
                              ),
                            ),
                          ],
                        ),
                      )
                    : Container(
                        margin: EdgeInsets.fromLTRB(isMobile ? 8 : 20, 4, isMobile ? 8 : 20, 16),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1E293B),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: AppTheme.cardBorder),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(9),
                          child: Scrollbar(
                            controller: _horizontalScrollController,
                            thumbVisibility: true,
                            child: SingleChildScrollView(
                              controller: _horizontalScrollController,
                              scrollDirection: Axis.horizontal,
                              child: SizedBox(
                                width: totalTableWidth,
                                child: Column(
                                  children: [
                                    // Fixed Table Header Row
                                    _buildHeaderRow(currency),

                                    // Scrollable Table Body
                                    Expanded(
                                      child: Scrollbar(
                                        controller: _verticalScrollController,
                                        thumbVisibility: true,
                                        child: ListView.separated(
                                          controller: _verticalScrollController,
                                          itemCount: filteredProducts.length,
                                          separatorBuilder: (context, index) => const Divider(
                                            height: 1,
                                            thickness: 1,
                                            color: Color(0xFF263346),
                                          ),
                                          itemBuilder: (context, index) {
                                            final product = filteredProducts[index];
                                            final categoryName = categories.firstWhere(
                                              (c) => c['id'] == product.categoryId,
                                              orElse: () => {'name': 'General'},
                                            )['name'] ?? 'General';

                                            return _buildProductDataRow(
                                              product: product,
                                              categoryName: categoryName,
                                              currency: currency,
                                              taxSlabs: taxSlabs,
                                              categories: categories,
                                              isEven: index % 2 == 0,
                                            );
                                          },
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildFilterChip(String label, StockFilter filter, {Color? accentColor}) {
    final isSelected = _selectedStockFilter == filter;
    final color = accentColor ?? AppTheme.primaryEmerald;

    return InkWell(
      onTap: () {
        setState(() {
          _selectedStockFilter = filter;
        });
      },
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? color.withValues(alpha: 0.2) : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            color: isSelected ? color : AppTheme.textSecondary,
          ),
        ),
      ),
    );
  }

  Widget _buildMetricCard({
    required String label,
    required String value,
    required String subtitle,
    required IconData icon,
    required Color color,
    required bool isSelected,
    VoidCallback? onTap,
    double? width,
  }) {
    final cardWidget = InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: const Color(0xFF1E293B),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? color : AppTheme.cardBorder,
            width: isSelected ? 1.5 : 1.0,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12, fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    value,
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(color: color.withValues(alpha: 0.85), fontSize: 11),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );

    if (width != null) {
      return SizedBox(width: width, child: cardWidget);
    }
    return Expanded(child: cardWidget);
  }

  // Header Row with strictly matching column widths & alignments
  Widget _buildHeaderRow(String currency) {
    return Container(
      height: 44,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: const BoxDecoration(
        color: Color(0xFF131C31),
        border: Border(bottom: BorderSide(color: Color(0xFF334155), width: 1.2)),
      ),
      child: Row(
        children: [
          // 1. Product & Barcode (Left Aligned)
          SizedBox(
            width: colWidthProduct,
            child: const Text(
              'PRODUCT & BARCODE',
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF94A3B8), letterSpacing: 0.5),
            ),
          ),

          // 2. SKU (Left Aligned)
          SizedBox(
            width: colWidthSku,
            child: const Text(
              'SKU',
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF94A3B8), letterSpacing: 0.5),
            ),
          ),

          // 3. Category (Left Aligned)
          SizedBox(
            width: colWidthCategory,
            child: const Text(
              'CATEGORY',
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF94A3B8), letterSpacing: 0.5),
            ),
          ),

          // 4. Stock Level (Center Aligned)
          SizedBox(
            width: colWidthStock,
            child: const Center(
              child: Text(
                'STOCK LEVEL',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF94A3B8), letterSpacing: 0.5),
              ),
            ),
          ),

          // 5. Cost Price (Right Aligned)
          SizedBox(
            width: colWidthCostPrice,
            child: Align(
              alignment: Alignment.centerRight,
              child: Text(
                'COST ($currency)',
                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF94A3B8), letterSpacing: 0.5),
              ),
            ),
          ),

          // 6. Selling Price (Right Aligned)
          SizedBox(
            width: colWidthSellingPrice,
            child: Align(
              alignment: Alignment.centerRight,
              child: Text(
                'SELL ($currency)',
                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF94A3B8), letterSpacing: 0.5),
              ),
            ),
          ),

          // 7. MRP (Right Aligned)
          SizedBox(
            width: colWidthMrp,
            child: Align(
              alignment: Alignment.centerRight,
              child: Text(
                'MRP ($currency)',
                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF94A3B8), letterSpacing: 0.5),
              ),
            ),
          ),

          // 8. Margin % (Right Aligned)
          SizedBox(
            width: colWidthMargin,
            child: const Align(
              alignment: Alignment.centerRight,
              child: Text(
                'MARGIN %',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF94A3B8), letterSpacing: 0.5),
              ),
            ),
          ),

          // 9. Tax Slab (Center Aligned)
          SizedBox(
            width: colWidthTaxSlab,
            child: const Center(
              child: Text(
                'TAX SLAB',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF94A3B8), letterSpacing: 0.5),
              ),
            ),
          ),

          // 10. Actions (Center Aligned)
          SizedBox(
            width: colWidthActions,
            child: const Center(
              child: Text(
                'ACTIONS',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF94A3B8), letterSpacing: 0.5),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Table Data Row with exact matching widths and aligned numeric data
  Widget _buildProductDataRow({
    required Product product,
    required String categoryName,
    required String currency,
    required List<TaxSlab> taxSlabs,
    required List<Map<String, String>> categories,
    required bool isEven,
  }) {
    // Profit margin calculation: ((SP - CP) / SP) * 100
    final hasMargin = product.sellingPrice > 0 && product.costPrice > 0;
    final marginPercent = hasMargin
        ? ((product.sellingPrice - product.costPrice) / product.sellingPrice) * 100
        : (product.sellingPrice > 0 ? 100.0 : 0.0);

    return Container(
      height: 54,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      color: isEven ? const Color(0xFF1E293B) : const Color(0xFF192231),
      child: Row(
        children: [
          // 1. Product & Barcode (Left Aligned)
          SizedBox(
            width: colWidthProduct,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  product.name,
                  style: const TextStyle(fontWeight: FontWeight.w600, color: Colors.white, fontSize: 13),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 3),
                Row(
                  children: [
                    const Icon(Icons.qr_code_2, size: 13, color: AppTheme.textSecondary),
                    const SizedBox(width: 4),
                    Text(
                      product.barcode ?? 'No Barcode',
                      style: const TextStyle(color: AppTheme.textSecondary, fontSize: 11, fontFamily: 'monospace'),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // 2. SKU (Left Aligned)
          SizedBox(
            width: colWidthSku,
            child: Align(
              alignment: Alignment.centerLeft,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFF0F172A),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: const Color(0xFF334155), width: 0.8),
                ),
                child: Text(
                  product.sku ?? '-',
                  style: const TextStyle(color: AppTheme.accentCyan, fontSize: 11, fontFamily: 'monospace'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
          ),

          // 3. Category (Left Aligned)
          SizedBox(
            width: colWidthCategory,
            child: Align(
              alignment: Alignment.centerLeft,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF334155).withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  categoryName,
                  style: const TextStyle(color: Colors.white70, fontSize: 11),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
          ),

          // 4. Stock Level & Quick Micro-Adjust Stepper (Center Aligned)
          SizedBox(
            width: colWidthStock,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Decrement Button
                Tooltip(
                  message: 'Deduct 1 ${product.unitOfMeasure}',
                  waitDuration: const Duration(milliseconds: 300),
                  child: InkWell(
                    onTap: () => _quickAdjustStock(product, -1),
                    borderRadius: BorderRadius.circular(4),
                    child: Container(
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                        color: const Color(0xFF334155),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: const Color(0xFF475569), width: 0.8),
                      ),
                      child: const Icon(Icons.remove, size: 13, color: Colors.white70),
                    ),
                  ),
                ),
                const SizedBox(width: 6),

                // Stock Badge (Click to open full adjustment modal)
                Tooltip(
                  message: 'Click to adjust stock',
                  waitDuration: const Duration(milliseconds: 300),
                  child: InkWell(
                    onTap: () => _openStockAdjustDialog(context, product),
                    borderRadius: BorderRadius.circular(6),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: product.stockQuantity <= 0
                            ? AppTheme.accentRose.withValues(alpha: 0.15)
                            : product.stockQuantity <= 10
                                ? AppTheme.accentAmber.withValues(alpha: 0.15)
                                : AppTheme.primaryEmerald.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: product.stockQuantity <= 0
                              ? AppTheme.accentRose
                              : product.stockQuantity <= 10
                                  ? AppTheme.accentAmber
                                  : AppTheme.primaryEmerald,
                          width: 0.8,
                        ),
                      ),
                      child: Text(
                        '${product.stockQuantity.toStringAsFixed(0)} ${product.unitOfMeasure}',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                          color: product.stockQuantity <= 0
                              ? AppTheme.accentRose
                              : product.stockQuantity <= 10
                                  ? AppTheme.accentAmber
                                  : AppTheme.primaryEmerald,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 6),

                // Increment Button
                Tooltip(
                  message: 'Add 1 ${product.unitOfMeasure}',
                  waitDuration: const Duration(milliseconds: 300),
                  child: InkWell(
                    onTap: () => _quickAdjustStock(product, 1),
                    borderRadius: BorderRadius.circular(4),
                    child: Container(
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                        color: const Color(0xFF334155),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: const Color(0xFF475569), width: 0.8),
                      ),
                      child: const Icon(Icons.add, size: 13, color: Colors.white70),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // 5. Cost Price (Right Aligned)
          SizedBox(
            width: colWidthCostPrice,
            child: Align(
              alignment: Alignment.centerRight,
              child: Text(
                '$currency${product.costPrice.toStringAsFixed(2)}',
                style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13, fontFamily: 'monospace'),
              ),
            ),
          ),

          // 6. Selling Price (Right Aligned)
          SizedBox(
            width: colWidthSellingPrice,
            child: Align(
              alignment: Alignment.centerRight,
              child: Text(
                '$currency${product.sellingPrice.toStringAsFixed(2)}',
                style: const TextStyle(
                  color: AppTheme.primaryEmerald,
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                  fontFamily: 'monospace',
                ),
              ),
            ),
          ),

          // 7. MRP (Right Aligned)
          SizedBox(
            width: colWidthMrp,
            child: Align(
              alignment: Alignment.centerRight,
              child: product.mrp != null && product.mrp! > 0
                  ? Text(
                      '$currency${product.mrp!.toStringAsFixed(2)}',
                      style: TextStyle(
                        color: product.mrp! > product.sellingPrice ? AppTheme.textSecondary : Colors.white70,
                        fontSize: 12,
                        fontFamily: 'monospace',
                        decoration: product.mrp! > product.sellingPrice ? TextDecoration.lineThrough : null,
                      ),
                    )
                  : const Text('-', style: TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
            ),
          ),

          // 8. Margin % (Right Aligned)
          SizedBox(
            width: colWidthMargin,
            child: Align(
              alignment: Alignment.centerRight,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                decoration: BoxDecoration(
                  color: marginPercent >= 20
                      ? AppTheme.primaryEmerald.withValues(alpha: 0.15)
                      : marginPercent >= 10
                          ? AppTheme.accentCyan.withValues(alpha: 0.15)
                          : AppTheme.accentAmber.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  '${marginPercent.toStringAsFixed(1)}%',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 11,
                    fontFamily: 'monospace',
                    color: marginPercent >= 20
                        ? AppTheme.primaryEmerald
                        : marginPercent >= 10
                            ? AppTheme.accentCyan
                            : AppTheme.accentAmber,
                  ),
                ),
              ),
            ),
          ),

          // 9. Tax Slab (Center Aligned)
          SizedBox(
            width: colWidthTaxSlab,
            child: Center(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '${product.taxSlab?.ratePercent.toStringAsFixed(0) ?? "0"}%',
                    style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(width: 5),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                    decoration: BoxDecoration(
                      color: product.isTaxInclusive
                          ? Colors.blue.withValues(alpha: 0.2)
                          : Colors.orange.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      product.isTaxInclusive ? 'Incl' : 'Excl',
                      style: TextStyle(
                        fontSize: 10,
                        color: product.isTaxInclusive ? Colors.blueAccent : Colors.orangeAccent,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // 10. Actions (Center Aligned)
          SizedBox(
            width: colWidthActions,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildActionIconButton(
                  icon: Icons.add_shopping_cart_rounded,
                  color: AppTheme.primaryEmerald,
                  tooltip: 'Add to POS Cart',
                  onPressed: () {
                    ref.read(cartNotifierProvider.notifier).addOrIncrementProduct(product);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Added "${product.name}" to POS cart'),
                        duration: const Duration(seconds: 1),
                        backgroundColor: AppTheme.primaryEmerald,
                      ),
                    );
                  },
                ),
                const SizedBox(width: 8),
                _buildActionIconButton(
                  icon: Icons.tune_rounded,
                  color: AppTheme.accentAmber,
                  tooltip: 'Adjust Stock Level',
                  onPressed: () => _openStockAdjustDialog(context, product),
                ),
                const SizedBox(width: 8),
                _buildActionIconButton(
                  icon: Icons.edit_outlined,
                  color: AppTheme.accentCyan,
                  tooltip: 'Edit Product Details',
                  onPressed: () => _openProductDialog(
                    context,
                    product: product,
                    taxSlabs: taxSlabs,
                    categories: categories,
                    currency: currency,
                  ),
                ),
                const SizedBox(width: 8),
                _buildActionIconButton(
                  icon: Icons.delete_outline_rounded,
                  color: AppTheme.accentRose,
                  tooltip: 'Delete Product',
                  onPressed: () => _confirmDeleteProduct(context, product),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Reusable styled micro-action button for desktop table rows
  Widget _buildActionIconButton({
    required IconData icon,
    required Color color,
    required String tooltip,
    required VoidCallback onPressed,
  }) {
    return Tooltip(
      message: tooltip,
      waitDuration: const Duration(milliseconds: 300),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(6),
          hoverColor: color.withValues(alpha: 0.2),
          child: Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: color.withValues(alpha: 0.3), width: 0.8),
            ),
            child: Center(
              child: Icon(icon, size: 16, color: color),
            ),
          ),
        ),
      ),
    );
  }

  // Rapid Stock Micro-Stepper (+1 / -1)
  Future<void> _quickAdjustStock(Product product, double delta) async {
    final newQty = max(0.0, product.stockQuantity + delta);
    final repo = ref.read(productRepositoryProvider);
    await repo.updateStock(product.id, newQty);
    ref.invalidate(productsProvider);
  }

  // Fast Stock Inward replenishment modal from Top Action Bar
  void _openStockInwardDialog(
    BuildContext context, {
    required List<Product> allProducts,
    required String currency,
  }) {
    if (allProducts.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No products available for stock inward')),
      );
      return;
    }

    String? selectedProductId = allProducts.first.id;
    final qtyController = TextEditingController(text: '10');
    final invoiceRefController = TextEditingController();

    showDialog(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (ctx, setModalState) {
          final isMobile = AppTheme.isMobile(ctx);
          final selectedProduct = allProducts.firstWhere(
            (p) => p.id == selectedProductId,
            orElse: () => allProducts.first,
          );
          final inwardQty = double.tryParse(qtyController.text.trim()) ?? 0.0;
          final newStock = selectedProduct.stockQuantity + inwardQty;

          return AlertDialog(
            backgroundColor: const Color(0xFF1E293B),
            insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppTheme.accentAmber.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.add_shopping_cart, color: AppTheme.accentAmber, size: 20),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Quick Stock Inward',
                        style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        'Add incoming stock from supplier shipments',
                        style: TextStyle(color: AppTheme.textSecondary, fontSize: 11),
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
                    DropdownButtonFormField<String>(
                      initialValue: selectedProductId,
                      dropdownColor: const Color(0xFF1E293B),
                      style: const TextStyle(color: Colors.white, fontSize: 13),
                      decoration: const InputDecoration(labelText: 'Select Product to Inward'),
                      items: allProducts.map((p) {
                        return DropdownMenuItem(
                          value: p.id,
                          child: Text(
                            '${p.name} (Cur: ${p.stockQuantity.toStringAsFixed(0)} ${p.unitOfMeasure})',
                            overflow: TextOverflow.ellipsis,
                          ),
                        );
                      }).toList(),
                      onChanged: (val) {
                        if (val != null) {
                          setModalState(() {
                            selectedProductId = val;
                          });
                        }
                      },
                    ),
                    const SizedBox(height: 14),

                    if (isMobile) ...[
                      TextField(
                        controller: qtyController,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
                        decoration: InputDecoration(
                          labelText: 'Inward Quantity *',
                          suffixText: selectedProduct.unitOfMeasure,
                        ),
                        onChanged: (_) => setModalState(() {}),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: invoiceRefController,
                        style: const TextStyle(color: Colors.white, fontSize: 13),
                        decoration: const InputDecoration(
                          labelText: 'Supplier Invoice / Batch Ref',
                          hintText: 'e.g. INV-9042',
                        ),
                      ),
                    ] else
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: qtyController,
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
                              decoration: InputDecoration(
                                labelText: 'Inward Quantity *',
                                suffixText: selectedProduct.unitOfMeasure,
                              ),
                              onChanged: (_) => setModalState(() {}),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextField(
                              controller: invoiceRefController,
                              style: const TextStyle(color: Colors.white, fontSize: 13),
                              decoration: const InputDecoration(
                                labelText: 'Supplier Invoice / Batch Ref',
                                hintText: 'e.g. INV-9042',
                              ),
                            ),
                          ),
                        ],
                      ),
                    const SizedBox(height: 10),

                    // Quick presets
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      children: [5, 10, 25, 50, 100].map((q) {
                        return InkWell(
                          onTap: () {
                            setModalState(() {
                              qtyController.text = q.toString();
                            });
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: const Color(0xFF334155),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text('+$q', style: const TextStyle(color: Colors.white70, fontSize: 12)),
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 16),

                    // Preview Box
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryEmerald.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppTheme.primaryEmerald.withValues(alpha: 0.3)),
                      ),
                      child: isMobile
                          ? Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Current: ${selectedProduct.stockQuantity.toStringAsFixed(0)} → Inward: +${inwardQty.toStringAsFixed(0)}',
                                  style: const TextStyle(color: Colors.white70, fontSize: 13),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'New Total: ${newStock.toStringAsFixed(0)} ${selectedProduct.unitOfMeasure}',
                                  style: const TextStyle(color: AppTheme.primaryEmerald, fontWeight: FontWeight.bold, fontSize: 14),
                                ),
                              ],
                            )
                          : Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Current: ${selectedProduct.stockQuantity.toStringAsFixed(0)} → Inward: +${inwardQty.toStringAsFixed(0)}',
                                  style: const TextStyle(color: Colors.white70, fontSize: 13),
                                ),
                                Text(
                                  'New Total: ${newStock.toStringAsFixed(0)} ${selectedProduct.unitOfMeasure}',
                                  style: const TextStyle(color: AppTheme.primaryEmerald, fontWeight: FontWeight.bold, fontSize: 14),
                                ),
                              ],
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
                  TextButton(
                    onPressed: () => Navigator.pop(dialogCtx),
                    child: const Text('Cancel', style: TextStyle(color: AppTheme.textSecondary)),
                  ),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryEmerald,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 11),
                    ),
                    icon: const Icon(Icons.check, size: 18),
                    label: const Text('Confirm Inward'),
                    onPressed: () async {
                      if (inwardQty <= 0) return;
                      final repo = ref.read(productRepositoryProvider);
                      await repo.updateStock(selectedProduct.id, newStock);
                      ref.invalidate(productsProvider);
                      if (dialogCtx.mounted) {
                        Navigator.pop(dialogCtx);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Successfully inwarded ${inwardQty.toStringAsFixed(0)} ${selectedProduct.unitOfMeasure} for "${selectedProduct.name}"'),
                            backgroundColor: AppTheme.primaryEmerald,
                          ),
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

  // Stock Adjustment Dialog with Add / Reduce / Set Modes and presets
  void _openStockAdjustDialog(BuildContext context, Product product) {
    String mode = 'ADD'; // 'ADD', 'REDUCE', 'SET'
    final amountController = TextEditingController(text: '10');
    String selectedReason = 'Stock Restock / Purchase Inward';

    final reasons = [
      'Stock Restock / Purchase Inward',
      'Inventory Physical Count Audit',
      'Damaged / Expired Goods',
      'Customer Return / Restock',
      'Wastage / Scrap',
      'Other Adjustment',
    ];

    showDialog(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (ctx, setModalState) {
          final enteredVal = double.tryParse(amountController.text.trim()) ?? 0.0;
          double resultingQty = product.stockQuantity;
          if (mode == 'ADD') {
            resultingQty = product.stockQuantity + enteredVal;
          } else if (mode == 'REDUCE') {
            resultingQty = max(0.0, product.stockQuantity - enteredVal);
          } else {
            resultingQty = max(0.0, enteredVal);
          }

          final isMobile = AppTheme.isMobile(ctx);

          return AlertDialog(
            backgroundColor: const Color(0xFF1E293B),
            insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppTheme.accentAmber.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.inventory_2_rounded, color: AppTheme.accentAmber, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Stock Adjustment',
                        style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      Text(
                        product.name,
                        style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            content: SizedBox(
              width: isMobile ? double.maxFinite : 440,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Current Stock Banner
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0F172A),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFF334155)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Current In-Stock:', style: TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
                        Text(
                          '${product.stockQuantity.toStringAsFixed(0)} ${product.unitOfMeasure}',
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Mode Segmented Buttons
                  Row(
                    children: [
                      Expanded(
                        child: _buildModeTab(
                          label: 'Add (+)',
                          modeKey: 'ADD',
                          currentMode: mode,
                          color: AppTheme.primaryEmerald,
                          onTap: () => setModalState(() => mode = 'ADD'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _buildModeTab(
                          label: 'Reduce (-)',
                          modeKey: 'REDUCE',
                          currentMode: mode,
                          color: AppTheme.accentRose,
                          onTap: () => setModalState(() => mode = 'REDUCE'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _buildModeTab(
                          label: 'Set Exact (=)',
                          modeKey: 'SET',
                          currentMode: mode,
                          color: AppTheme.accentCyan,
                          onTap: () => setModalState(() => mode = 'SET'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Quantity Input
                  TextField(
                    controller: amountController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                    decoration: InputDecoration(
                      labelText: mode == 'SET' ? 'New Total Stock' : 'Quantity to ${mode == 'ADD' ? 'Add' : 'Deduct'}',
                      suffixText: product.unitOfMeasure,
                      suffixStyle: const TextStyle(color: AppTheme.textSecondary),
                    ),
                    onChanged: (_) => setModalState(() {}),
                  ),
                  const SizedBox(height: 10),

                  // Preset Quantity Buttons
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: [1, 5, 10, 25, 50, 100].map((q) {
                      return InkWell(
                        onTap: () {
                          setModalState(() {
                            amountController.text = q.toString();
                          });
                        },
                        borderRadius: BorderRadius.circular(6),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xFF334155),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            '+$q',
                            style: const TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w600),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 16),

                  // Reason Dropdown
                  DropdownButtonFormField<String>(
                    initialValue: selectedReason,
                    dropdownColor: const Color(0xFF1E293B),
                    style: const TextStyle(color: Colors.white, fontSize: 13),
                    decoration: const InputDecoration(labelText: 'Adjustment Reason'),
                    items: reasons.map((r) => DropdownMenuItem(value: r, child: Text(r))).toList(),
                    onChanged: (val) {
                      if (val != null) {
                        setModalState(() {
                          selectedReason = val;
                        });
                      }
                    },
                  ),
                  const SizedBox(height: 16),

                  // Resulting Stock Summary Box
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryEmerald.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppTheme.primaryEmerald.withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Resulting Final Stock:', style: TextStyle(color: Colors.white70, fontSize: 13)),
                        Text(
                          '${resultingQty.toStringAsFixed(0)} ${product.unitOfMeasure}',
                          style: const TextStyle(
                            color: AppTheme.primaryEmerald,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
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
                  TextButton(
                    onPressed: () => Navigator.pop(dialogCtx),
                    child: const Text('Cancel', style: TextStyle(color: AppTheme.textSecondary)),
                  ),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryEmerald,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 11),
                    ),
                    icon: const Icon(Icons.check, size: 18),
                    label: const Text('Apply Adjustment'),
                    onPressed: () async {
                      final repo = ref.read(productRepositoryProvider);
                      await repo.updateStock(product.id, resultingQty);
                      ref.invalidate(productsProvider);
                      if (dialogCtx.mounted) {
                        Navigator.pop(dialogCtx);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Stock for "${product.name}" updated to ${resultingQty.toStringAsFixed(0)} ${product.unitOfMeasure}'),
                            backgroundColor: AppTheme.primaryEmerald,
                          ),
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

  Widget _buildModeTab({
    required String label,
    required String modeKey,
    required String currentMode,
    required Color color,
    required VoidCallback onTap,
  }) {
    final isSelected = currentMode == modeKey;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 9),
        decoration: BoxDecoration(
          color: isSelected ? color.withValues(alpha: 0.2) : const Color(0xFF0F172A),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? color : const Color(0xFF334155),
            width: isSelected ? 1.5 : 1.0,
          ),
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              color: isSelected ? color : AppTheme.textSecondary,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
              fontSize: 12,
            ),
          ),
        ),
      ),
    );
  }

  // Delete Product Confirmation
  void _confirmDeleteProduct(BuildContext context, Product product) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        title: Row(
          children: [
            const Icon(Icons.delete_outline, color: AppTheme.accentRose, size: 22),
            const SizedBox(width: 8),
            const Expanded(
              child: Text(
                'Delete Product from Catalog',
                style: TextStyle(color: Colors.white, fontSize: 16),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        content: Text(
          'Are you sure you want to permanently delete "${product.name}"? It will be removed from your active catalog.',
          style: const TextStyle(color: AppTheme.textSecondary),
        ),
        actions: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: WrapAlignment.end,
            children: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel', style: TextStyle(color: AppTheme.textSecondary)),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.accentRose,
                  foregroundColor: Colors.white,
                ),
                onPressed: () async {
                  final repo = ref.read(productRepositoryProvider);
                  await repo.deleteProduct(product.id);
                  ref.invalidate(productsProvider);
                  if (ctx.mounted) {
                    Navigator.pop(ctx);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Product "${product.name}" deleted from catalog'),
                        backgroundColor: AppTheme.accentRose,
                      ),
                    );
                  }
                },
                child: const Text('Delete Permanently'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // Full Add & Edit Product Modal with Live Margin Calculation
  void _openProductDialog(
    BuildContext context, {
    Product? product,
    required List<TaxSlab> taxSlabs,
    required List<Map<String, String>> categories,
    String currency = '₹',
  }) {
    final formKey = GlobalKey<FormState>();
    final isEditing = product != null;

    final nameController = TextEditingController(text: product?.name ?? '');
    final barcodeController = TextEditingController(text: product?.barcode ?? '');
    final skuController = TextEditingController(text: product?.sku ?? '');
    final costPriceController = TextEditingController(text: product?.costPrice.toStringAsFixed(2) ?? '0.00');
    final sellingPriceController = TextEditingController(text: product?.sellingPrice.toStringAsFixed(2) ?? '0.00');
    final mrpController = TextEditingController(text: product?.mrp != null ? product!.mrp!.toStringAsFixed(2) : '');
    final stockController = TextEditingController(text: product?.stockQuantity.toStringAsFixed(0) ?? '0');

    String selectedTaxSlabId = product?.taxSlabId ?? (taxSlabs.isNotEmpty ? taxSlabs.first.id : 'tax_gst_0');
    String? selectedCategoryId = product?.categoryId ?? (categories.isNotEmpty ? categories.first['id'] : null);
    String selectedUom = product?.unitOfMeasure ?? 'PCS';
    bool isTaxInclusive = product?.isTaxInclusive ?? true;

    final isMobile = AppTheme.isMobile(context);

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          final cp = double.tryParse(costPriceController.text.trim()) ?? 0.0;
          final sp = double.tryParse(sellingPriceController.text.trim()) ?? 0.0;
          final liveMargin = sp > 0 ? ((sp - cp) / sp) * 100 : 0.0;
          final liveMarkup = cp > 0 ? ((sp - cp) / cp) * 100 : 0.0;

          final barcodeField = TextFormField(
            controller: barcodeController,
            style: const TextStyle(color: Colors.white, fontFamily: 'monospace'),
            decoration: InputDecoration(
              labelText: 'Barcode (EAN/UPC)',
              suffixIcon: IconButton(
                icon: const Icon(Icons.auto_awesome, size: 18, color: AppTheme.accentCyan),
                tooltip: 'Generate random retail barcode',
                onPressed: () {
                  final randomCode = '890${Random().nextInt(900000000) + 100000000}';
                  setDialogState(() {
                    barcodeController.text = randomCode;
                  });
                },
              ),
            ),
          );

          final skuField = TextFormField(
            controller: skuController,
            style: const TextStyle(color: Colors.white, fontFamily: 'monospace'),
            decoration: InputDecoration(
              labelText: 'SKU Code',
              suffixIcon: IconButton(
                icon: const Icon(Icons.auto_awesome, size: 18, color: AppTheme.accentCyan),
                tooltip: 'Generate SKU code from name',
                onPressed: () {
                  final prefix = nameController.text.trim().replaceAll(' ', '-').toUpperCase();
                  final cleanPrefix = prefix.length > 5 ? prefix.substring(0, 5) : (prefix.isEmpty ? 'PROD' : prefix);
                  final randomSku = '$cleanPrefix-${Random().nextInt(900) + 100}';
                  setDialogState(() {
                    skuController.text = randomSku;
                  });
                },
              ),
            ),
          );

          final categoryField = DropdownButtonFormField<String>(
            initialValue: selectedCategoryId,
            dropdownColor: const Color(0xFF1E293B),
            style: const TextStyle(color: Colors.white),
            decoration: const InputDecoration(labelText: 'Category'),
            items: categories.map((c) {
              return DropdownMenuItem(
                value: c['id'],
                child: Text(c['name'] ?? ''),
              );
            }).toList(),
            onChanged: (val) {
              setDialogState(() {
                selectedCategoryId = val;
              });
            },
          );

          final uomField = DropdownButtonFormField<String>(
            initialValue: selectedUom,
            dropdownColor: const Color(0xFF1E293B),
            style: const TextStyle(color: Colors.white),
            decoration: const InputDecoration(labelText: 'Unit of Measure (UOM)'),
            items: const [
              DropdownMenuItem(value: 'PCS', child: Text('Pieces (PCS)')),
              DropdownMenuItem(value: 'KG', child: Text('Kilogram (KG)')),
              DropdownMenuItem(value: 'GM', child: Text('Gram (GM)')),
              DropdownMenuItem(value: 'LTR', child: Text('Litre (LTR)')),
              DropdownMenuItem(value: 'ML', child: Text('Millilitre (ML)')),
              DropdownMenuItem(value: 'PACK', child: Text('Pack (PACK)')),
              DropdownMenuItem(value: 'BOX', child: Text('Box (BOX)')),
              DropdownMenuItem(value: 'BOTTLE', child: Text('Bottle (BOTTLE)')),
              DropdownMenuItem(value: 'DOZ', child: Text('Dozen (DOZ)')),
              DropdownMenuItem(value: 'MTR', child: Text('Meter (MTR)')),
            ],
            onChanged: (val) {
              if (val != null) {
                setDialogState(() {
                  selectedUom = val;
                });
              }
            },
          );

          final costPriceField = TextFormField(
            controller: costPriceController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              labelText: 'Cost Price ($currency)',
              hintText: '0.00',
            ),
            onChanged: (_) => setDialogState(() {}),
          );

          final sellingPriceField = TextFormField(
            controller: sellingPriceController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            decoration: InputDecoration(
              labelText: 'Selling Price ($currency) *',
              hintText: '0.00',
            ),
            validator: (v) {
              if (v == null || v.trim().isEmpty) return 'Required';
              if (double.tryParse(v) == null) return 'Invalid number';
              return null;
            },
            onChanged: (_) => setDialogState(() {}),
          );

          final mrpField = TextFormField(
            controller: mrpController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              labelText: 'MRP ($currency)',
              hintText: 'Optional',
            ),
          );

          final taxSlabField = DropdownButtonFormField<String>(
            initialValue: selectedTaxSlabId,
            dropdownColor: const Color(0xFF1E293B),
            style: const TextStyle(color: Colors.white),
            decoration: const InputDecoration(labelText: 'Tax Slab'),
            items: taxSlabs.map((s) {
              return DropdownMenuItem(
                value: s.id,
                child: Text('${s.name} (${s.ratePercent.toStringAsFixed(0)}%)'),
              );
            }).toList(),
            onChanged: (val) {
              if (val != null) {
                setDialogState(() {
                  selectedTaxSlabId = val;
                });
              }
            },
          );

          final taxInclusiveField = SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Tax Inclusive', style: TextStyle(color: Colors.white, fontSize: 13)),
            subtitle: Text(
              isTaxInclusive ? 'SP includes tax' : 'Tax added to SP',
              style: const TextStyle(color: AppTheme.textSecondary, fontSize: 11),
            ),
            value: isTaxInclusive,
            activeThumbColor: AppTheme.primaryEmerald,
            onChanged: (val) {
              setDialogState(() {
                isTaxInclusive = val;
              });
            },
          );

          return AlertDialog(
            backgroundColor: const Color(0xFF1E293B),
            insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryEmerald.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    isEditing ? Icons.edit_note : Icons.add_box_outlined,
                    color: AppTheme.primaryEmerald,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    isEditing ? 'Edit Product Details' : 'Add New Retail Product',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 17),
                  ),
                ),
              ],
            ),
            content: SizedBox(
              width: isMobile ? double.maxFinite : 650,
              child: Form(
                key: formKey,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Section 1: Item Details
                      const Text(
                        'BASIC INFORMATION',
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.accentCyan, letterSpacing: 0.5),
                      ),
                      const SizedBox(height: 8),

                      TextFormField(
                        controller: nameController,
                        style: const TextStyle(color: Colors.white),
                        decoration: const InputDecoration(
                          labelText: 'Product Name *',
                          hintText: 'e.g. Basmati Rice 5kg / Aashirvaad Atta 10kg',
                        ),
                        validator: (v) => (v == null || v.trim().isEmpty) ? 'Product name is required' : null,
                      ),
                      const SizedBox(height: 12),

                      // Barcode & SKU
                      if (isMobile) ...[
                        barcodeField,
                        const SizedBox(height: 12),
                        skuField,
                      ] else ...[
                        Row(
                          children: [
                            Expanded(child: barcodeField),
                            const SizedBox(width: 12),
                            Expanded(child: skuField),
                          ],
                        ),
                      ],
                      const SizedBox(height: 12),

                      // Category & UOM
                      if (isMobile) ...[
                        categoryField,
                        const SizedBox(height: 12),
                        uomField,
                      ] else ...[
                        Row(
                          children: [
                            Expanded(child: categoryField),
                            const SizedBox(width: 12),
                            Expanded(child: uomField),
                          ],
                        ),
                      ],
                      const SizedBox(height: 18),

                      // Section 2: Pricing & Margins
                      const Text(
                        'PRICING, MRP & PROFIT MARGINS',
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.accentCyan, letterSpacing: 0.5),
                      ),
                      const SizedBox(height: 8),

                      if (isMobile) ...[
                        costPriceField,
                        const SizedBox(height: 12),
                        sellingPriceField,
                        const SizedBox(height: 12),
                        mrpField,
                      ] else ...[
                        Row(
                          children: [
                            Expanded(child: costPriceField),
                            const SizedBox(width: 12),
                            Expanded(child: sellingPriceField),
                            const SizedBox(width: 12),
                            Expanded(child: mrpField),
                          ],
                        ),
                      ],
                      const SizedBox(height: 8),

                      // Live Profit Margin Indicator Bar
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: const Color(0xFF0F172A),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: const Color(0xFF334155)),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Calculated Profit Margin: ${liveMargin.toStringAsFixed(1)}%',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                                color: liveMargin >= 20
                                    ? AppTheme.primaryEmerald
                                    : liveMargin >= 10
                                        ? AppTheme.accentCyan
                                        : AppTheme.accentAmber,
                              ),
                            ),
                            Text(
                              'Markup: ${liveMarkup.toStringAsFixed(1)}%',
                              style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 18),

                      // Section 3: Tax & Stock
                      const Text(
                        'TAXATION & INVENTORY',
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.accentCyan, letterSpacing: 0.5),
                      ),
                      const SizedBox(height: 8),

                      if (isMobile) ...[
                        taxSlabField,
                        const SizedBox(height: 8),
                        taxInclusiveField,
                      ] else ...[
                        Row(
                          children: [
                            Expanded(flex: 3, child: taxSlabField),
                            const SizedBox(width: 12),
                            Expanded(flex: 2, child: taxInclusiveField),
                          ],
                        ),
                      ],
                      const SizedBox(height: 12),

                      // Stock Quantity
                      TextFormField(
                        controller: stockController,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          labelText: isEditing ? 'Update Stock Count' : 'Initial Stock Quantity',
                          hintText: 'Enter available inventory',
                          suffixText: selectedUom,
                          suffixStyle: const TextStyle(color: AppTheme.textSecondary),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            actions: [
              Wrap(
                spacing: 8,
                runSpacing: 8,
                alignment: WrapAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(dialogCtx),
                    child: const Text('Cancel', style: TextStyle(color: AppTheme.textSecondary)),
                  ),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryEmerald,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 11),
                    ),
                    icon: const Icon(Icons.check, size: 18),
                    label: Text(isEditing ? 'Save Product' : 'Add to Catalog'),
                    onPressed: () async {
                      if (!formKey.currentState!.validate()) return;

                      final repo = ref.read(productRepositoryProvider);
                      final pid = product?.id ?? const Uuid().v4();
                      final costP = double.tryParse(costPriceController.text.trim()) ?? 0.0;
                      final sellP = double.tryParse(sellingPriceController.text.trim()) ?? 0.0;
                      final mrpVal = double.tryParse(mrpController.text.trim());
                      final stockVal = double.tryParse(stockController.text.trim()) ?? 0.0;

                      final newOrUpdated = Product(
                        id: pid,
                        name: nameController.text.trim(),
                        barcode: barcodeController.text.trim().isEmpty ? null : barcodeController.text.trim(),
                        sku: skuController.text.trim().isEmpty ? null : skuController.text.trim(),
                        categoryId: selectedCategoryId,
                        taxSlabId: selectedTaxSlabId,
                        unitOfMeasure: selectedUom,
                        costPrice: costP,
                        sellingPrice: sellP,
                        mrp: mrpVal,
                        stockQuantity: stockVal,
                        isTaxInclusive: isTaxInclusive,
                        isActive: true,
                      );

                      if (isEditing) {
                        await repo.updateProduct(newOrUpdated);
                      } else {
                        await repo.createProduct(newOrUpdated);
                      }

                      ref.invalidate(productsProvider);
                      if (dialogCtx.mounted) {
                        Navigator.pop(dialogCtx);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              isEditing
                                  ? 'Product "${newOrUpdated.name}" updated successfully!'
                                  : 'Product "${newOrUpdated.name}" added to catalog!',
                            ),
                            backgroundColor: AppTheme.primaryEmerald,
                          ),
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
}
