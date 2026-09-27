// lib/screens/profile/waitlist_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/app_logger.dart';
import '../../models/product_detail.dart';
import '../../providers/waitlist_provider.dart';
import '../../services/waitlist_service.dart';
import '../../widgets/scroll_to_top_button.dart';
import '../../widgets/waitlist/waitlist_item.dart';
import '../main_shell.dart';

class WaitlistScreen extends StatefulWidget {
  const WaitlistScreen({super.key});

  @override
  State<WaitlistScreen> createState() => _WaitlistScreenState();
}

class _WaitlistScreenState extends State<WaitlistScreen>
    with WidgetsBindingObserver {
  static const _logTag = 'WaitlistScreen';

  List<Map<String, dynamic>> _items = [];
  bool _isLoading = true;
  bool _hasMore = true;
  int _page = 1;
  bool _initialLoad = true;
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _searchController = TextEditingController();

  String _sort = 'date_desc';

  final Set<int> _selectedIds = {};
  bool get _allSelected =>
      _items.isNotEmpty && _selectedIds.length == _items.length;

  final Map<int, List<ProductCrossSell>> _crossSellsMap = {};

  final List<Map<String, String>> _sortOptions = [
    {'key': 'date_desc', 'label': 'Последние добавленные'},
    {'key': 'date_asc', 'label': 'Сначала старые'},
    {'key': 'price_asc', 'label': 'Дешевле'},
    {'key': 'price_desc', 'label': 'Дороже'},
    {'key': 'in_stock', 'label': 'В наличии'},
    {'key': 'out_of_stock', 'label': 'Не в наличии'},
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    MainShell.tabNotifier.addListener(_onTabChanged);
    _loadItems();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    MainShell.tabNotifier.removeListener(_onTabChanged);
    WidgetsBinding.instance.removeObserver(this);
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _onTabChanged() {
    if (!mounted) return;
    if (MainShell.tabNotifier.value == 3) {
      _loadItems(refresh: true);
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _loadItems(refresh: true);
    }
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 400) {
      _loadItems();
    }
  }

  Future<void> _loadItems({bool refresh = false}) async {
    if (!_initialLoad && !refresh && (!_hasMore || _isLoading)) return;
    if (refresh) {
      _page = 1;
      _hasMore = true;
      _initialLoad = true;
      _items = [];
      _selectedIds.clear();
      _crossSellsMap.clear();
    }
    setState(() => _isLoading = true);

    final result = await WaitlistService.getItems(
      page: _page,
      search: _searchController.text.isNotEmpty
          ? _searchController.text
          : null,
      sort: _sort,
    );

    if (!mounted) return;

    if (result.isFailure) {
      AppLogger.warning(
        _logTag,
        'loadItems(page=$_page) failed: ${result.errorOrNull?.message}',
      );
      setState(() {
        _isLoading = false;
        _initialLoad = false;
      });
      return;
    }

    final data = result.valueOrNull?['data'];
    if (data is! Map) {
      setState(() {
        _isLoading = false;
        _initialLoad = false;
      });
      return;
    }

    final itemsRaw = data['items'];
    final items = itemsRaw is List
        ? itemsRaw
            .whereType<Map>()
            .map((i) => Map<String, dynamic>.from(i))
            .toList()
        : <Map<String, dynamic>>[];

    setState(() {
      if (_page == 1) {
        _items = items;
      } else {
        _items.addAll(items);
      }
      _hasMore = data['has_more'] ?? false;
      if (_hasMore) _page++;
      _isLoading = false;
      _initialLoad = false;
    });

    final newIds = items
        .map<int?>((i) {
          final id = i['id'];
          if (id is int) return id;
          if (id is String) return int.tryParse(id);
          return null;
        })
        .whereType<int>()
        .toList();

    if (newIds.isNotEmpty) {
      _loadCrossSells(newIds);
    }

    final waitlistProvider = context.read<WaitlistProvider>();
    for (final item in items) {
      final id = item['id'];
      if (id is int) {
        waitlistProvider.setInWaitlist(id, true);
      }
    }
  }

  Future<void> _loadCrossSells(List<int> productIds) async {
    final result = await WaitlistService.getCrossSells(productIds);

    if (!mounted) return;

    if (result.isFailure) {
      AppLogger.warning(
        _logTag,
        'loadCrossSells failed: ${result.errorOrNull?.message}',
      );
      return;
    }

    final data = result.valueOrNull?['data'];
    if (data is! Map) return;

    setState(() {
      data.forEach((key, value) {
        final pid = int.tryParse(key.toString()) ?? 0;
        if (pid > 0 && value is List) {
          _crossSellsMap[pid] = value
              .whereType<Map>()
              .map((v) => ProductCrossSell.fromJson(
                    Map<String, dynamic>.from(v),
                  ))
              .toList();
        }
      });
    });
  }

  void _toggleSelectAll() {
    setState(() {
      if (_allSelected) {
        _selectedIds.clear();
      } else {
        _selectedIds.addAll(
          _items
              .map((i) => i['id'])
              .whereType<int>()
              .toList(),
        );
      }
    });
  }

  void _toggleItem(int id) {
    setState(() {
      if (_selectedIds.contains(id)) {
        _selectedIds.remove(id);
      } else {
        _selectedIds.add(id);
      }
    });
  }

  Future<void> _removeSelected() async {
    if (_selectedIds.isEmpty) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: const Text('Удалить выбранные?'),
        content: Text(
          '${_selectedIds.length} товаров будет удалено из листа ожидания',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text(
              'Отмена',
              style: TextStyle(color: Color(0xFF999999)),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text(
              'Удалить',
              style: TextStyle(
                color: Color(0xFFDD1847),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );

    if (confirm != true) return;
    if (!mounted) return;

    final toRemove = _selectedIds.toList();
    await WaitlistService.removeBatch(toRemove);

    if (!mounted) return;

    setState(() {
      _items.removeWhere((i) => toRemove.contains(i['id'] as int));
      _selectedIds.clear();
    });
    context.read<WaitlistProvider>().loadCount();
  }

  void _shareSelected() {
    if (_selectedIds.isEmpty) return;
    final selected = _items
        .where((i) => _selectedIds.contains(i['id'] as int))
        .toList();
    final text = selected.map((i) {
      final name = i['name'] ?? '';
      final slug = i['slug'] ?? '';
      return '$name — https://xn--80abvyjk6cts.xn--p1ai/product/$slug';
    }).join('\n');
    Share.share(text);
  }

  Future<void> _removeItem(int productId) async {
    await WaitlistService.remove(productId);

    if (!mounted) return;

    setState(() {
      _items.removeWhere((i) => i['id'] == productId);
      _selectedIds.remove(productId);
    });
    context.read<WaitlistProvider>().loadCount();
  }

  void _shareItem(Map<String, dynamic> item) {
    final name = item['name'] ?? '';
    final slug = item['slug'] ?? '';
    final url = 'https://xn--80abvyjk6cts.xn--p1ai/product/$slug';
    Share.share('$name — $url');
  }

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.of(context).padding.top;
    final bottomPadding = MediaQuery.of(context).padding.bottom;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      body: Stack(
        children: [
          Positioned.fill(
            child: Column(
              children: [
                SizedBox(height: topPadding + 48),
                Expanded(
                  child: _isLoading && _items.isEmpty
                      ? const Center(
                          child: CircularProgressIndicator(
                            color: Color(0xFFDD1847),
                          ),
                        )
                      : _items.isEmpty
                          ? Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    color: Colors.white,
                                    padding: const EdgeInsets.fromLTRB(
                                      16,
                                      12,
                                      16,
                                      12,
                                    ),
                                    child: Container(
                                      height: 44,
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFF8F8FA),
                                        borderRadius:
                                            BorderRadius.circular(14),
                                        border: Border.all(
                                          color: const Color(0xFFF0F0F0),
                                        ),
                                      ),
                                      child: TextField(
                                        controller: _searchController,
                                        onSubmitted: (value) =>
                                            _loadItems(refresh: true),
                                        onChanged: (value) {
                                          if (value.isEmpty) {
                                            _loadItems(refresh: true);
                                          }
                                        },
                                        style: const TextStyle(
                                          fontSize: 15,
                                        ),
                                        decoration: InputDecoration(
                                          hintText:
                                              'Название, артикул, бренд, цвет',
                                          hintStyle: TextStyle(
                                            color: Colors.grey[400],
                                            fontSize: 14,
                                          ),
                                          prefixIcon: const Icon(
                                            Icons.search,
                                            color: Color(0xFF999999),
                                            size: 22,
                                          ),
                                          border: InputBorder.none,
                                          contentPadding:
                                              const EdgeInsets.symmetric(
                                            vertical: 12,
                                          ),
                                          suffixIcon: _searchController
                                                  .text.isNotEmpty
                                              ? GestureDetector(
                                                  onTap: () {
                                                    _searchController.clear();
                                                    _loadItems(
                                                      refresh: true,
                                                    );
                                                  },
                                                  child: const Icon(
                                                    Icons.close,
                                                    size: 18,
                                                    color: Color(
                                                      0xFF999999,
                                                    ),
                                                  ),
                                                )
                                              : null,
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 32),
                                  const Icon(
                                    Icons.schedule,
                                    size: 64,
                                    color: Color(0xFFCCCCCC),
                                  ),
                                  const SizedBox(height: 16),
                                  const Text(
                                    'В листе ожидания пока ничего нет',
                                    style: TextStyle(
                                      fontSize: 16,
                                      color: Color(0xFF999999),
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  const Text(
                                    'Добавляйте товары, которых нет в наличии,\nчтобы узнать об их поступлении первыми',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: Color(0xFFAAAAAA),
                                    ),
                                  ),
                                ],
                              ),
                            )
                          : RefreshIndicator(
                              onRefresh: () => _loadItems(refresh: true),
                              color: const Color(0xFFDD1847),
                              child: CustomScrollView(
                                controller: _scrollController,
                                physics:
                                    const AlwaysScrollableScrollPhysics(),
                                slivers: [
                                  const SliverToBoxAdapter(
                                    child: SizedBox(height: 20),
                                  ),
                                  SliverToBoxAdapter(
                                    child: Container(
                                      color: Colors.white,
                                      padding: const EdgeInsets.fromLTRB(
                                        16,
                                        12,
                                        16,
                                        12,
                                      ),
                                      child: Container(
                                        height: 44,
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFF8F8FA),
                                          borderRadius:
                                              BorderRadius.circular(14),
                                          border: Border.all(
                                            color:
                                                const Color(0xFFF0F0F0),
                                          ),
                                        ),
                                        child: TextField(
                                          controller: _searchController,
                                          onSubmitted: (value) =>
                                              _loadItems(refresh: true),
                                          onChanged: (value) {
                                            if (value.isEmpty) {
                                              _loadItems(refresh: true);
                                            }
                                          },
                                          style: const TextStyle(
                                            fontSize: 15,
                                          ),
                                          decoration: InputDecoration(
                                            hintText:
                                                'Название, артикул, бренд, цвет',
                                            hintStyle: TextStyle(
                                              color: Colors.grey[400],
                                              fontSize: 14,
                                            ),
                                            prefixIcon: const Icon(
                                              Icons.search,
                                              color: Color(0xFF999999),
                                              size: 22,
                                            ),
                                            border: InputBorder.none,
                                            contentPadding:
                                                const EdgeInsets
                                                    .symmetric(
                                              vertical: 12,
                                            ),
                                            suffixIcon:
                                                _searchController
                                                        .text.isNotEmpty
                                                    ? GestureDetector(
                                                        onTap: () {
                                                          _searchController
                                                              .clear();
                                                          _loadItems(
                                                            refresh: true,
                                                          );
                                                        },
                                                        child: const Icon(
                                                          Icons.close,
                                                          size: 18,
                                                          color: Color(
                                                            0xFF999999,
                                                          ),
                                                        ),
                                                      )
                                                    : null,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SliverToBoxAdapter(
                                    child: SizedBox(height: 10),
                                  ),
                                  SliverToBoxAdapter(
                                    child: Container(
                                      color: Colors.white,
                                      padding: const EdgeInsets.fromLTRB(
                                        16,
                                        12,
                                        16,
                                        12,
                                      ),
                                      child: Row(
                                        children: [
                                          GestureDetector(
                                            onTap: _toggleSelectAll,
                                            child: Row(
                                              children: [
                                                SizedBox(
                                                  width: 22,
                                                  height: 22,
                                                  child: Checkbox(
                                                    value: _allSelected,
                                                    onChanged: (_) =>
                                                        _toggleSelectAll(),
                                                    activeColor:
                                                        const Color(
                                                      0xFFDD1847,
                                                    ),
                                                    shape:
                                                        RoundedRectangleBorder(
                                                      borderRadius:
                                                          BorderRadius
                                                              .circular(6),
                                                    ),
                                                  ),
                                                ),
                                                const SizedBox(width: 8),
                                                const Text(
                                                  'Все',
                                                  style: TextStyle(
                                                    fontSize: 15,
                                                    fontWeight:
                                                        FontWeight.w500,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                          const Spacer(),
                                          if (_selectedIds.isNotEmpty)
                                            Text(
                                              '${_selectedIds.length}',
                                              style: const TextStyle(
                                                fontSize: 14,
                                                fontWeight:
                                                    FontWeight.w600,
                                                color:
                                                    Color(0xFFDD1847),
                                              ),
                                            ),
                                          if (_selectedIds.isNotEmpty)
                                            const SizedBox(width: 12),
                                          _buildShareBtn(_shareSelected),
                                          const SizedBox(width: 8),
                                          _buildIconBtn(
                                            Icons.delete_outline,
                                            _removeSelected,
                                            color:
                                                const Color(0xFFDD1847),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                  SliverList(
                                    delegate: SliverChildBuilderDelegate(
                                      (context, index) {
                                        if (index >= _items.length) {
                                          return const Padding(
                                            padding: EdgeInsets.all(20),
                                            child: Center(
                                              child:
                                                  CircularProgressIndicator(
                                                color: Color(0xFFDD1847),
                                              ),
                                            ),
                                          );
                                        }
                                        final item = _items[index];
                                        final pid = item['id'] as int;
                                        final crossSells =
                                            _crossSellsMap[pid] ?? [];
                                        final isSelected =
                                            _selectedIds.contains(pid);
                                        return WaitlistItem(
                                          item: item,
                                          crossSells: crossSells,
                                          isSelected: isSelected,
                                          onToggleSelect: () =>
                                              _toggleItem(pid),
                                          onRemove: () =>
                                              _removeItem(pid),
                                          onShare: () =>
                                              _shareItem(item),
                                        );
                                      },
                                      childCount: _items.length +
                                          (_hasMore ? 1 : 0),
                                    ),
                                  ),
                                  SliverPadding(
                                    padding: EdgeInsets.only(
                                      bottom: 100 + bottomPadding,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                ),
              ],
            ),
          ),
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: ClipRRect(
              borderRadius: const BorderRadius.vertical(
                bottom: Radius.circular(20),
              ),
              child: Container(
                color: Colors.white,
                child: Padding(
                  padding: EdgeInsets.only(top: topPadding, bottom: 12),
                  child: Row(
                    children: [
                      const SizedBox(width: 8),
                      IconButton(
                        icon: const Icon(
                          Icons.arrow_back,
                          color: Color(0xFFFF2E6E),
                          size: 22,
                        ),
                        onPressed: () => Navigator.pop(context),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(
                          minWidth: 40,
                          minHeight: 40,
                        ),
                      ),
                      Expanded(
                        child: Column(
                          children: [
                            const Text(
                              'Лист ожидания',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF1A1A1A),
                              ),
                            ),
                            Text(
                              '${_items.length} товаров',
                              style: const TextStyle(
                                fontSize: 13,
                                color: Color(0xFF888888),
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(
                          Icons.swap_vert,
                          color: Color(0xFFFF2E6E),
                          size: 24,
                        ),
                        onPressed: _showSortSheet,
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(
                          minWidth: 40,
                          minHeight: 40,
                        ),
                      ),
                      const SizedBox(width: 8),
                    ],
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            bottom: bottomPadding + 20,
            right: 40,
            child: ScrollToTopButton(
              scrollController: _scrollController,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildIconBtn(IconData icon, VoidCallback onTap, {Color? color}) {
    return GestureDetector(
      onTap: _selectedIds.isEmpty ? null : onTap,
      child: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(19),
        ),
        child: Icon(
          icon,
          size: 22,
          color: _selectedIds.isEmpty
              ? const Color(0xFFCCCCCC)
              : (color ?? const Color(0xFF555555)),
        ),
      ),
    );
  }

  Widget _buildShareBtn(VoidCallback onTap) {
    return GestureDetector(
      onTap: _selectedIds.isEmpty ? null : onTap,
      child: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(19),
        ),
        child: Padding(
          padding: const EdgeInsets.all(9),
          child: SvgPicture.asset(
            'assets/icons/share.svg',
            width: 20,
            height: 20,
            colorFilter: ColorFilter.mode(
              _selectedIds.isEmpty
                  ? const Color(0xFFCCCCCC)
                  : const Color(0xFF555555),
              BlendMode.srcIn,
            ),
          ),
        ),
      ),
    );
  }

  void _showSortSheet() {
    showModalBottomSheet(
      context: context,
      useRootNavigator: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Сортировка',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 16),
            ..._sortOptions.map(
              (s) => GestureDetector(
                onTap: () {
                  Navigator.pop(ctx);
                  setState(() => _sort = s['key']!);
                  _loadItems(refresh: true);
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    vertical: 14,
                    horizontal: 16,
                  ),
                  decoration: BoxDecoration(
                    color: _sort == s['key']
                        ? const Color(0xFFFDF2F5)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Text(
                        s['label']!,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: _sort == s['key']
                              ? FontWeight.w600
                              : FontWeight.w400,
                          color: _sort == s['key']
                              ? const Color(0xFFDD1847)
                              : const Color(0xFF1A1A1A),
                        ),
                      ),
                      if (_sort == s['key']) const Spacer(),
                      if (_sort == s['key'])
                        const Icon(
                          Icons.check,
                          color: Color(0xFFDD1847),
                          size: 20,
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}