// lib/widgets/image_loader.dart
import 'package:flutter/material.dart';
import 'package:flutter_avif/flutter_avif.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../core/app_logger.dart';
import '../services/cdn_service.dart';
import '../services/smart_image_loader.dart';
import '../services/image_memory_cache.dart';
import '../core/app_colors.dart';

/// Универсальный загрузчик изображений со скелетоном и фолбэком.


class ImageLoader extends StatefulWidget {
  /// URL изображения (может быть null или пустым).
  final String? imageUrl;

  /// Ширина изображения.
  final double? width;

  /// Высота изображения.
  final double? height;

  /// Радиус скругления углов.
  final double borderRadius;

  /// Подгонка изображения.
  final BoxFit fit;

  /// Показывать ли скелетон при загрузке.
  final bool showSkeleton;

  /// Кастомный виджет скелетона (если нужен свой).
  final Widget? customSkeleton;

  /// Иконка при ошибке загрузки.
  final IconData errorIcon;

  /// Размер иконки при ошибке.
  final double errorIconSize;

  /// Цвет иконки при ошибке.
  final Color? errorIconColor;

  /// Приоритет загрузки (0 — высокий, 100 — низкий).
  final int priority;

  const ImageLoader({
    super.key,
    this.imageUrl,
    this.width,
    this.height,
    this.borderRadius = 0,
    this.fit = BoxFit.cover,
    this.showSkeleton = true,
    this.customSkeleton,
    this.errorIcon = Icons.image,
    this.errorIconSize = 24,
    this.errorIconColor,
    this.priority = 50,
  });

  @override
  State<ImageLoader> createState() => _ImageLoaderState();
}

class _ImageLoaderState extends State<ImageLoader> {
  static const _logTag = 'ImageLoader';

  bool _hasError = false;
  String? _cachedUrl;

  @override
  void initState() {
    super.initState();
    _loadImage();
  }

  @override
  void didUpdateWidget(ImageLoader oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.imageUrl != widget.imageUrl) {
      _loadImage();
    }
  }

  Future<void> _loadImage() async {
    if (widget.imageUrl == null || widget.imageUrl!.isEmpty) {
      setState(() {
        _hasError = true;
      });
      return;
    }

    setState(() {
      _hasError = false;
    });

    final url = CdnService.imageUrl(widget.imageUrl);

    try {
      final cachedFile = await SmartImageLoader().getCachedFile(url);

      if (cachedFile != null && mounted) {
        setState(() {
          _cachedUrl = url;
        });
        return;
      }

      await SmartImageLoader().load(url, priority: widget.priority);

      if (mounted) {
        setState(() {
          _cachedUrl = url;
        });
      }
    } catch (e) {
  AppLogger.warning(_logTag, 'image load failed: $url', e);
      if (mounted) {
        setState(() {
          _hasError = true;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(widget.borderRadius),
      child: SizedBox(
        width: widget.width,
        height: widget.height,
        child: _buildContent(),
      ),
    );
  }

  Widget _buildContent() {
    if (_hasError) {
      return _buildErrorPlaceholder();
    }

    if (_cachedUrl != null) {
      // 🔥 Сначала проверяем in-memory кэш (мгновенный доступ, 0 мс)
      final memoryBytes = ImageMemoryCache().get(_cachedUrl!);
      if (memoryBytes != null) {
        return Image.memory(
          memoryBytes,
          fit: widget.fit,
          width: widget.width,
          height: widget.height,
          filterQuality: FilterQuality.medium,
          gaplessPlayback: true,
        );
      }

      // Учитываем DPR: memCacheWidth/Height — в физических пикселях.


      // SVG — отдельный виджет (CachedNetworkImage не поддерживает SVG)
      if (_cachedUrl != null && _cachedUrl!.endsWith('.svg')) {
        return SvgPicture.network(
          _cachedUrl!,
          width: widget.width,
          height: widget.height,
          fit: BoxFit.contain,
          placeholderBuilder: (_) => SizedBox(
            width: widget.width,
            height: widget.height,
          ),
        );
      }
      // 🔥 AVIF через CachedNetworkAvifImage (правильный способ)
      final avifUrl = _cachedUrl!.replaceAll('.webp', '.avif');
      debugPrint('[ImageLoader] loading AVIF (CachedNetworkAvifImage): $avifUrl');
      return CachedNetworkAvifImage(
        avifUrl,
        fit: widget.fit,
        width: widget.width,
        height: widget.height,
        filterQuality: FilterQuality.high,
        errorBuilder: (_, _, _) {
          // 🔥 AVIF не загрузился — WebP
          debugPrint('[ImageLoader] AVIF failed, fallback to WebP: $_cachedUrl');
          return Image.network(
            _cachedUrl!,
            fit: widget.fit,
            width: widget.width,
            height: widget.height,
            errorBuilder: (_, _, _) => _buildErrorPlaceholder(),
          );
        },
      );
    }

    return _buildPlaceholder();
  }

  Widget _buildPlaceholder() {
    if (widget.showSkeleton) {
      return widget.customSkeleton ??
          ShimmerBox(
            height: widget.height ?? double.infinity,
            width: widget.width,
            borderRadius: widget.borderRadius,
          );
    }
    return Container(
      color: context.colors.surfaceAlt,
      child: Center(
        child: SizedBox(
          width: 24,
          height: 24,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: context.colors.brand.withValues(alpha: 0.5),
          ),
        ),
      ),
    );
  }

  Widget _buildErrorPlaceholder() {
    return Container(
      width: widget.width,
      height: widget.height,
      color: context.colors.surfaceAlt,
      child: Center(
        child: Icon(
          widget.errorIcon,
          size: widget.errorIconSize,
          color: widget.errorIconColor ?? context.colors.border,
        ),
      ),
    );
  }
}

/// Скелетон с анимацией shimmer.
class ShimmerBox extends StatefulWidget {
  final double height;
  final double? width;
  final double borderRadius;

  const ShimmerBox({
    super.key,
    required this.height,
    this.width,
    this.borderRadius = 8,
  });

  @override
  State<ShimmerBox> createState() => _ShimmerBoxState();
}

class _ShimmerBoxState extends State<ShimmerBox>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    )..repeat(reverse: true);
    _animation = Tween<double>(begin: -1.0, end: 1.0).animate(_controller);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Container(
          height: widget.height,
          width: widget.width,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(widget.borderRadius),
            gradient: LinearGradient(
              begin: Alignment(_animation.value - 1, 0),
              end: Alignment(_animation.value + 1, 0),
              colors: [
                context.colors.surfaceAlt,
                context.colors.border,
                context.colors.surfaceAlt,
              ],
            ),
          ),
        );
      },
    );
  }
}