// lib/screens/product/photo_view_screen.dart
//
// Полноэкранный просмотр фото товара.
// - Шапка brand-цвета с счётчиком и «Закрыть»
// - Свайп между фото
// - Pinch-to-zoom
// - Swipe-down to dismiss (как Instagram)

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:photo_view/photo_view.dart';
import 'package:photo_view/photo_view_gallery.dart';

import '../../core/app_colors.dart';
import '../../services/haptic_service.dart';

class PhotoViewScreen extends StatefulWidget {
  final List<String> images;
  final int initialIndex;

  const PhotoViewScreen({
    super.key,
    required this.images,
    this.initialIndex = 0,
  });

  @override
  State<PhotoViewScreen> createState() => _PhotoViewScreenState();
}

class _PhotoViewScreenState extends State<PhotoViewScreen>
    with SingleTickerProviderStateMixin {
  late int _currentIndex;
  late PageController _pageController;
  final PhotoViewController _photoViewController = PhotoViewController();
  final PhotoViewScaleStateController _scaleStateController =
      PhotoViewScaleStateController();

  // Swipe-to-dismiss
  double _dragOffset = 0;
  double _dragOpacity = 1.0;
  bool _isDragging = false;
  late AnimationController _animationController;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: widget.initialIndex);

    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
    _animationController.addListener(() {
      setState(() {
        _dragOffset = _dragOffset * (1 - _animationController.value);
        _dragOpacity = (1 - _dragOffset.abs() / 400).clamp(0.3, 1.0);
      });
    });
    _animationController.addStatusListener((status) {
      if (status == AnimationStatus.completed && _dragOffset.abs() < 10) {
        setState(() {
          _dragOffset = 0;
          _dragOpacity = 1.0;
          _isDragging = false;
        });
        _animationController.reset();
      }
    });
  }

  @override
  void dispose() {
    _animationController.dispose();
    _pageController.dispose();
    _photoViewController.dispose();
    _scaleStateController.dispose();
    super.dispose();
  }

  bool get _isZoomed =>
      _scaleStateController.scaleState != PhotoViewScaleState.initial;

  void _onVerticalDragStart(DragStartDetails details) {
    if (_isZoomed) return;
    setState(() => _isDragging = true);
  }

  void _onVerticalDragUpdate(DragUpdateDetails details) {
    if (_isZoomed) return;
    setState(() {
      _dragOffset += details.delta.dy;
      // Затемнение: чем дальше — тем прозрачнее
      _dragOpacity = (1.0 - (_dragOffset.abs() / 400)).clamp(0.3, 1.0);
    });
  }

  void _onVerticalDragEnd(DragEndDetails details) {
    if (_isZoomed) return;

    final velocity = details.velocity.pixelsPerSecond.dy;

    if (_dragOffset.abs() > 100 || velocity.abs() > 800) {
      // Закрываем
      HapticService.light();
      Navigator.of(context).pop();
    } else {
      // Возвращаем
      _animateBack();
    }
  }

  void _animateBack() {
    final startOffset = _dragOffset;
    _animationController.reset();
    _animationController.forward().then((_) {
      if (mounted) {
        setState(() {
          _dragOffset = 0;
          _dragOpacity = 1.0;
          _isDragging = false;
        });
      }
    });
    // Плавный возврат
    final startTime = DateTime.now();
    const duration = Duration(milliseconds: 200);
    void tick() {
      if (!mounted) return;
      final elapsed = DateTime.now().difference(startTime);
      final t = (elapsed.inMilliseconds / duration.inMilliseconds).clamp(0.0, 1.0);
      setState(() {
        _dragOffset = startOffset * (1 - t);
        _dragOpacity = (1.0 - (_dragOffset.abs() / 400)).clamp(0.3, 1.0);
      });
      if (t < 1.0) {
        WidgetsBinding.instance.addPostFrameCallback((_) => tick());
      } else {
        setState(() {
          _dragOffset = 0;
          _dragOpacity = 1.0;
          _isDragging = false;
        });
      }
    }
    WidgetsBinding.instance.addPostFrameCallback((_) => tick());
  }

  @override
  Widget build(BuildContext context) {
    final brandColor = context.colors.brand;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: GestureDetector(
        onVerticalDragStart: _onVerticalDragStart,
        onVerticalDragUpdate: _onVerticalDragUpdate,
        onVerticalDragEnd: _onVerticalDragEnd,
        child: Stack(
          children: [
            // === Затемнение фона ===
            Positioned.fill(
              child: Container(
                color: Colors.black.withValues(alpha: _dragOpacity),
              ),
            ),

            // === Фото ===
            Positioned.fill(
              child: Transform.translate(
                offset: Offset(0, _dragOffset),
                child: Opacity(
                  opacity: _dragOpacity,
                  child: PhotoViewGallery.builder(
                    itemCount: widget.images.length,
                    pageController: _pageController,
                    onPageChanged: (index) {
                      setState(() => _currentIndex = index);
                    },
                    builder: (context, index) {
                      return PhotoViewGalleryPageOptions(
                        imageProvider: CachedNetworkImageProvider(
                          widget.images[index],
                        ),
                        minScale: PhotoViewComputedScale.contained,
                        maxScale: PhotoViewComputedScale.covered * 4,
                        filterQuality: FilterQuality.high,
                        heroAttributes: PhotoViewHeroAttributes(
                          tag: 'product_image_$index',
                        ),
                        controller: _photoViewController,
                        scaleStateController: _scaleStateController,
                      );
                    },
                    loadingBuilder: (context, event) {
                      final progress = event?.expectedTotalBytes != null
                          ? event!.cumulativeBytesLoaded /
                              event.expectedTotalBytes!
                          : null;
                      return Center(
                        child: CircularProgressIndicator(
                          color: Colors.white.withValues(alpha: 0.7),
                          value: progress,
                        ),
                      );
                    },
                    backgroundDecoration: const BoxDecoration(
                      color: Colors.transparent,
                    ),
                  ),
                ),
              ),
            ),

            // === Шапка ===
            if (!_isDragging || _dragOffset.abs() < 50)
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: AnimatedOpacity(
                  opacity: _dragOpacity,
                  duration: const Duration(milliseconds: 100),
                  child: Container(
                    decoration: BoxDecoration(color: brandColor),
                    padding: EdgeInsets.only(
                      top: MediaQuery.of(context).padding.top,
                    ),
                    child: SizedBox(
                      height: 56,
                      child: Row(
                        children: [
                          Expanded(
                            child: Center(
                              child: Text(
                                '${_currentIndex + 1} из ${widget.images.length}',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.only(right: 16),
                            child: GestureDetector(
                              onTap: () => Navigator.of(context).pop(),
                              behavior: HitTestBehavior.opaque,
                              child: const Padding(
                                padding: EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 8,
                                ),
                                child: Text(
                                  'Закрыть',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 15,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
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
