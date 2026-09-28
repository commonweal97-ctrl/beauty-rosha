// lib/widgets/smart_image.dart
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../services/cdn_service.dart';
import '../services/smart_image_loader.dart';
import '../core/app_colors.dart';

class SmartImage extends StatefulWidget {
  final String imageUrl;
  final double? width;
  final double? height;
  final BoxFit fit;
  final int priority;
  final double borderRadius;
  final Widget? placeholder;
  final Widget? errorWidget;

  const SmartImage({
    super.key,
    required this.imageUrl,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.priority = 50,
    this.borderRadius = 0,
    this.placeholder,
    this.errorWidget,
  });

  @override
  State<SmartImage> createState() => _SmartImageState();
}

class _SmartImageState extends State<SmartImage> {
  bool _hasError = false;
  String? _cachedUrl;

  @override
  void initState() {
    super.initState();
    _loadImage();
  }

  @override
  void didUpdateWidget(SmartImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.imageUrl != widget.imageUrl) {
      _loadImage();
    }
  }

  Future<void> _loadImage() async {
    setState(() {
      _hasError = false;
    });

    final url = CdnService.imageUrl(widget.imageUrl);

    try {
      await SmartImageLoader().load(url, priority: widget.priority);

      if (mounted) {
        setState(() {
          _cachedUrl = url;
        });
      }
    } catch (e) {
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
      child: _buildContent(),
    );
  }

  Widget _buildContent() {
    if (_hasError) {
      return widget.errorWidget ?? _buildDefaultError();
    }

    if (_cachedUrl != null) {
      return CachedNetworkImage(
        imageUrl: _cachedUrl!,
        width: widget.width,
        height: widget.height,
        memCacheWidth: widget.width?.toInt(),
        memCacheHeight: widget.height?.toInt(),
        fit: widget.fit,
        placeholder: (context, url) => widget.placeholder ?? _buildShimmer(),
        errorWidget: (context, url, error) =>
            widget.errorWidget ?? _buildDefaultError(),
        fadeInDuration: Duration(milliseconds: 300),
        fadeOutDuration: Duration(milliseconds: 200),
      );
    }

    return widget.placeholder ?? _buildShimmer();
  }

  Widget _buildShimmer() {
    return Container(
      width: widget.width,
      height: widget.height,
      color: context.colors.surfaceAlt,
      child: Center(
        child: SizedBox(
          width: 24,
          height: 24,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: context.colors.brand,
          ),
        ),
      ),
    );
  }

  Widget _buildDefaultError() {
    return Container(
      width: widget.width,
      height: widget.height,
      color: context.colors.surfaceAlt,
      child: Center(
        child: Icon(
          Icons.image_not_supported_outlined,
          color: context.colors.textDisabled,
          size: 32,
        ),
      ),
    );
  }
}