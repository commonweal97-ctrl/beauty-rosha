// lib/widgets/mobile_menu.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/mobile_menu_data.dart';
import '../services/mobile_menu_service.dart';
import '../services/city_service.dart';
import '../screens/catalog/catalog_screen.dart';
import '../screens/service/service_screen.dart';
import 'city_picker.dart';
import 'image_loader.dart';
import 'package:provider/provider.dart';
import '../../providers/catalog_provider.dart';
import '../core/app_colors.dart';

class MobileMenu extends StatefulWidget {
  final VoidCallback? onClose;
  final MobileMenuData menuData;
  final Function(int categoryId)? onCategoryTap;
  final VoidCallback? onNotificationsTap;

  const MobileMenu({
    super.key,
    this.onClose,
    required this.menuData,
    this.onCategoryTap,
    this.onNotificationsTap,
  });

  @override
  State<MobileMenu> createState() => _MobileMenuState();
}

class _MobileMenuState extends State<MobileMenu> {
  String _city = 'Брянск';
  
  final List<MenuNavItem> _navStack = [];
  List<MenuCategory> _currentCategories = [];
  String _currentTitle = '';
  bool _loadingCategories = false;

  @override
  void initState() {
    super.initState();
    _loadCity();
    _loadMainCategories();
  }

  Future<void> _loadCity() async {
    final prefs = await SharedPreferences.getInstance();
    final savedCity = prefs.getString('city');
    if (savedCity != null && savedCity.isNotEmpty) {
      setState(() => _city = savedCity);
    } else {
      setState(() => _city = widget.menuData.city);
    }
  }

  void _loadMainCategories() {
    _currentCategories = widget.menuData.categories;
    _currentTitle = '';
  }

  Future<void> _saveCity(String city) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('city', city);
    setState(() => _city = city);
  }

  void _openCityPicker() {
    showModalBottomSheet(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => CityPicker(
        onSelect: (city, country) {
          _saveCity(city);
          CityService.saveCity(city, country: country);
        },
      ),
    );
  }

  Future<void> _onCategoryTap(MenuCategory category) async {
    setState(() => _loadingCategories = true);
    
    final result = await MobileMenuService.getSubcategories(category.id);
    
    if (mounted && result != null) {
      final List subJson = result['subcategories'] ?? [];
      final subcategories = subJson.map((s) => MenuCategory.fromJson(s)).toList();
      
      if (subcategories.isEmpty) {
        setState(() => _loadingCategories = false);
        _navigateToCatalog(category.id);
      } else {
        setState(() {
          _navStack.add(MenuNavItem(
            categories: _currentCategories,
            title: _currentTitle,
            parentId: category.id,
            parentName: category.name,
          ));
          _currentCategories = subcategories;
          _currentTitle = category.name;
          _loadingCategories = false;
        });
      }
    } else if (mounted) {
      setState(() => _loadingCategories = false);
    }
  }

  void _goBack() {
    if (_navStack.isNotEmpty) {
      final previous = _navStack.removeLast();
      setState(() {
        _currentCategories = previous.categories;
        _currentTitle = previous.title;
      });
    }
  }

  void _navigateToCatalog(int categoryId) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ChangeNotifierProvider(
          create: (_) => CatalogProvider(),
          child: CatalogScreen(
            initialCategoryId: categoryId,
            fromMenu: true,
          ),
        ),
      ),
    );
  }

  void _openBannerLink(String linkUrl) async {
    if (linkUrl.isEmpty) return;
    
    final cleanUrl = linkUrl.startsWith('/') ? linkUrl.substring(1) : linkUrl;
    
    if (cleanUrl == 'service') {
      Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ServiceScreen()));
      return;
    }
    
    final uri = Uri.tryParse(linkUrl);
    if (uri != null && await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  bool get _isOnMainScreen => _navStack.isEmpty;

  @override
  Widget build(BuildContext context) {
    final featuredBanners = widget.menuData.banners.where((b) => b.bannerType == 'featured').toList();
    final mediumBanners = widget.menuData.banners.where((b) => b.bannerType == 'medium').toList();
    final screenWidth = MediaQuery.of(context).size.width;
    final statusBarHeight = MediaQuery.of(context).padding.top;
    final bottomPadding = MediaQuery.of(context).padding.bottom;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness:
              Theme.of(context).brightness == Brightness.dark
                  ? Brightness.light
                  : Brightness.dark,
          statusBarBrightness:
              Theme.of(context).brightness == Brightness.dark
                  ? Brightness.dark
                  : Brightness.light,
        ),
      child: Container(
        color: Colors.white,
        child: Column(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.vertical(bottom: Radius.circular(20)),
              child: Container(
                padding: EdgeInsets.only(top: statusBarHeight, bottom: 4),
                color: Colors.white,
                child: _isOnMainScreen
                    ? _buildMainHeader()
                    : _buildSubcategoryHeader(),
              ),
            ),
            Expanded(
              child: _loadingCategories
                  ? Center(child: CircularProgressIndicator(color: context.colors.brand))
                  : _isOnMainScreen
                      ? _buildMainView(screenWidth, featuredBanners, mediumBanners, bottomPadding)
                      : _buildCategoriesView(screenWidth, bottomPadding),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMainHeader() {
    return Padding(
      padding: EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: Row(
        children: [
          GestureDetector(
            onTap: _openCityPicker,
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(color: context.colors.surfaceAlt, borderRadius: BorderRadius.circular(12)),
              child: Row(children: [
                Icon(Icons.location_on, color: context.colors.brand, size: 18),
                SizedBox(width: 6),
                Text(_city, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: context.colors.textPrimary)),
                SizedBox(width: 4),
                Icon(Icons.arrow_drop_down, color: context.colors.brand, size: 18),
              ]),
            ),
          ),
          Spacer(),
          GestureDetector(
            onTap: widget.onNotificationsTap,
            child: Container(
              width: 44, height: 44, decoration: BoxDecoration(color: context.colors.surfaceAlt, borderRadius: BorderRadius.circular(12)),
              child: Stack(children: [
                Center(
                  child: SvgPicture.asset(
                    'assets/icons/kolokol.svg',
                    width: 22,
                    height: 22,
                    colorFilter: ColorFilter.mode(context.colors.textSecondary, BlendMode.srcIn),
                  ),
                ),
                if (widget.menuData.unreadNotifications > 0)
                  Positioned(top: 4, right: 4, child: Container(constraints: BoxConstraints(minWidth: 18), height: 18, padding: const EdgeInsets.symmetric(horizontal: 4), decoration: BoxDecoration(color: context.colors.brand, borderRadius: BorderRadius.circular(9)), child: Center(child: Text(widget.menuData.unreadNotifications > 99 ? '99+' : '${widget.menuData.unreadNotifications}', style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w700))))),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSubcategoryHeader() {
    return Padding(
      padding: EdgeInsets.fromLTRB(0, 12, 0, 12),
      child: Row(
        children: [
          SizedBox(width: 8),
          IconButton(
            icon: Icon(Icons.arrow_back, color: context.colors.error, size: 22),
            onPressed: _goBack,
            padding: EdgeInsets.zero,
            constraints: BoxConstraints(minWidth: 40, minHeight: 40),
          ),
          Expanded(
            child: Text(
              _currentTitle,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: context.colors.textPrimary),
            ),
          ),
          const SizedBox(width: 48),
        ],
      ),
    );
  }

  Widget _buildMainView(double screenWidth, List<MenuBanner> featuredBanners, List<MenuBanner> mediumBanners, double bottomPadding) {
    final categorySize = (screenWidth - 32 - 6) / 4;
    final bottomNavHeight = 80.0 + bottomPadding;
    
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      children: [
        if (featuredBanners.isNotEmpty) ...[
          _buildFeaturedBanner(imageUrl: featuredBanners.first.imageUrl, linkUrl: featuredBanners.first.linkUrl),
          const SizedBox(height: 2),
        ],
        if (mediumBanners.length >= 2) ...[
          Row(children: [
            Expanded(child: _buildMediumBanner(imageUrl: mediumBanners[0].imageUrl, linkUrl: mediumBanners[0].linkUrl)),
            const SizedBox(width: 2),
            Expanded(child: _buildMediumBanner(imageUrl: mediumBanners[1].imageUrl, linkUrl: mediumBanners[1].linkUrl)),
          ]),
          SizedBox(height: 2),
        ],
        if (_currentCategories.isNotEmpty) ...[
          ..._chunkCategories(_currentCategories, 4).map((row) => Padding(
            padding: EdgeInsets.only(bottom: 2),
            child: Row(children: row.map((cat) => SizedBox(width: categorySize, height: categorySize, child: _buildCategoryItem(imageUrl: cat.imageUrl, label: cat.name, onTap: () => _onCategoryTap(cat)))).toList()),
          )),
        ],
        SizedBox(height: bottomNavHeight),
      ],
    );
  }

  Widget _buildCategoriesView(double screenWidth, double bottomPadding) {
    if (_currentCategories.isEmpty) return Center(child: Text('Нет категорий', style: TextStyle(color: context.colors.textMuted)));
    final itemWidth = (screenWidth - 32 - 4) / 3;
    final bottomNavHeight = 80.0 + bottomPadding;
    
    return ListView(
      padding: EdgeInsets.symmetric(horizontal: 16),
      children: [
        SizedBox(height: 8),
        if (_navStack.isNotEmpty)
          Padding(
            padding: EdgeInsets.only(bottom: 12),
            child: SizedBox(width: double.infinity, child: ElevatedButton(
              onPressed: () => _navigateToCatalog(_navStack.last.parentId),
              style: ElevatedButton.styleFrom(backgroundColor: context.colors.brand, foregroundColor: Colors.white, padding: EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
              child: Text('Все товары — ${_navStack.last.parentName}', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
            )),
          ),
        ..._chunkCategories(_currentCategories, 3).map((row) => Padding(
          padding: const EdgeInsets.only(bottom: 2),
          child: Row(children: row.map((sub) => SizedBox(width: itemWidth, height: itemWidth, child: _buildCategoryItem(imageUrl: sub.imageUrl, label: sub.name, onTap: () => _onCategoryTap(sub)))).toList()),
        )),
        SizedBox(height: bottomNavHeight),
      ],
    );
  }

  Widget _buildFeaturedBanner({required String imageUrl, required String linkUrl}) {
    return GestureDetector(
      onTap: () => _openBannerLink(linkUrl),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16), 
        child: AspectRatio(
          aspectRatio: 21 / 9, 
          child: ImageLoader(
            imageUrl: imageUrl,
            width: double.infinity,
            height: double.infinity,
            borderRadius: 0,
          ),
        ),
      ),
    );
  }

  Widget _buildMediumBanner({required String imageUrl, required String linkUrl}) {
    return GestureDetector(
      onTap: () => _openBannerLink(linkUrl),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16), 
        child: AspectRatio(
          aspectRatio: 4 / 3, 
          child: ImageLoader(
            imageUrl: imageUrl,
            width: double.infinity,
            height: double.infinity,
            borderRadius: 0,
          ),
        ),
      ),
    );
  }

  Widget _buildCategoryItem({required String? imageUrl, required String label, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Padding(
        padding: EdgeInsets.all(1),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: imageUrl != null && imageUrl.isNotEmpty
              ? ImageLoader(
                  imageUrl: imageUrl,
                  width: double.infinity,
                  height: double.infinity,
                  borderRadius: 0,
                  errorIcon: Icons.category,
                  errorIconSize: 16,
                )
              : Container(
                  color: context.colors.surfaceAlt, 
                  child: Center(
                    child: Text(
                      label.isNotEmpty ? label[0].toUpperCase() : '?', 
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: context.colors.textDisabled),
                    ),
                  ),
                ),
        ),
      ),
    );
  }

  List<List<MenuCategory>> _chunkCategories(List<MenuCategory> list, int chunkSize) {
    final chunks = <List<MenuCategory>>[];
    for (var i = 0; i < list.length; i += chunkSize) {
      final end = (i + chunkSize < list.length) ? i + chunkSize : list.length;
      chunks.add(list.sublist(i, end));
    }
    return chunks;
  }
}

class MenuNavItem {
  final List<MenuCategory> categories;
  final String title;
  final int parentId;
  final String parentName;

  MenuNavItem({required this.categories, required this.title, required this.parentId, required this.parentName});
}