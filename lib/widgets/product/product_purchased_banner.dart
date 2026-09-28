// lib/widgets/product/product_purchased_banner.dart
import 'package:flutter/material.dart';
import '../rate_product_sheet.dart';
import '../../core/app_colors.dart';

class ProductPurchasedBanner extends StatefulWidget {
  final int productId;
  final Map<String, dynamic> item;
  // 🔥 НОВОЕ: флаги из ProductDetail, чтобы не делать лишний запрос
  final bool purchased;
  final bool alreadyRated;

  const ProductPurchasedBanner({
    super.key,
    required this.productId,
    required this.item,
    this.purchased = false,
    this.alreadyRated = false,
  });

  @override
  State<ProductPurchasedBanner> createState() => _ProductPurchasedBannerState();
}

class _ProductPurchasedBannerState extends State<ProductPurchasedBanner>
    with SingleTickerProviderStateMixin {
  bool _shouldShow = false;
  bool _checked = false;
  late final AnimationController _animationController;
  late final Animation<double> _fadeAnimation;
  late final Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOut,
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutCubic,
    ));
    
    // 🔥 ИСПРАВЛЕНО: используем переданные флаги вместо запроса к API
    _checkPurchasedAndNotRated();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _checkPurchasedAndNotRated() {
    // 🔥 ИСПРАВЛЕНО: используем purchased и alreadyRated из ProductDetail
    // Больше не делаем лишний API-запрос!
    if (mounted) {
      setState(() {
        _shouldShow = widget.purchased && !widget.alreadyRated;
        _checked = true;
      });
      if (_shouldShow) {
        _animationController.forward();
      }
    }
  }

  void _openRateSheet() {
    RateProductSheet.show(context, widget.item, () {
      setState(() => _shouldShow = false);
    });
  }

  void _close() {
    _animationController.reverse().then((_) {
      if (mounted) setState(() => _shouldShow = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!_checked || !_shouldShow) return const SizedBox();

    return FadeTransition(
      opacity: _fadeAnimation,
      child: SlideTransition(
        position: _slideAnimation,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            // Контейнер со звёздами
            GestureDetector(
              onTap: _openRateSheet,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.1),
                      blurRadius: 12,
                      offset: const Offset(0, -2),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(5, (i) => Padding(
                        padding: EdgeInsets.symmetric(horizontal: 4),
                        child: Icon(
                          Icons.star,
                          size: 36,
                          color: context.colors.border,
                        ),
                      )),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Нажмите, чтобы оценить',
                      style: TextStyle(fontSize: 13, color: context.colors.textMuted),
                    ),
                  ],
                ),
              ),
            ),
            // Крестик в правом верхнем углу
            Positioned(
              top: -12,
              right: -12,
              child: GestureDetector(
                onTap: _close,
                child: Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.15),
                        blurRadius: 8,
                        offset: Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Icon(
                    Icons.close,
                    size: 18,
                    color: context.colors.textSecondary,
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