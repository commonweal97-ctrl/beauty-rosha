// lib/widgets/product/fullscreen_media_viewer.dart
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../core/app_colors.dart';
import '../../core/price_formatter.dart';

class FullscreenMediaItem {
  final String mediaUrl;
  final bool isVideo;
  final String? videoPreview;
  final String userName;
  final String? userAvatar;
  final String? comment;
  final int rating;
  final String? productImage;
  final String? productName;
  final double? productPrice;
  final double? productSalePrice;
  final double? productCardPrice;

  FullscreenMediaItem({
    required this.mediaUrl,
    required this.isVideo,
    this.videoPreview,
    required this.userName,
    this.userAvatar,
    this.comment,
    this.rating = 5,
    this.productImage,
    this.productName,
    this.productPrice,
    this.productSalePrice,
    this.productCardPrice,
  });
}

class FullscreenMediaViewer extends StatefulWidget {
  final List<FullscreenMediaItem> items;
  final int initialIndex;

  const FullscreenMediaViewer({
    super.key,
    required this.items,
    this.initialIndex = 0,
  });

  @override
  State<FullscreenMediaViewer> createState() => _FullscreenMediaViewerState();
}

class _FullscreenMediaViewerState extends State<FullscreenMediaViewer> {
  late PageController _pageController;
  late int _currentIndex;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: widget.initialIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  String _imageUrl(String url) {
    if (url.startsWith('http')) return url;
    return 'https://xn--80abvyjk6cts.xn--p1ai/$url';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      resizeToAvoidBottomInset: false,
      extendBodyBehindAppBar: true,
      extendBody: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Отзыв ${_currentIndex + 1} из ${widget.items.length}',
          style: const TextStyle(color: Colors.white, fontSize: 16),
        ),
        centerTitle: true,
      ),
      body: Stack(
        children: [
          // Медиа область
          Positioned.fill(
            child: PageView.builder(
              controller: _pageController,
              scrollDirection: Axis.vertical,
              itemCount: widget.items.length,
              onPageChanged: (index) {
                setState(() => _currentIndex = index);
              },
              itemBuilder: (context, index) {
                return _buildMediaItem(widget.items[index]);
              },
            ),
          ),

          // Вертикальная пагинация справа
          Positioned(
            right: 6,
            top: 0,
            bottom: 0,
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: List.generate(widget.items.length, (i) {
                  final isActive = i == _currentIndex;
                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    margin: const EdgeInsets.symmetric(vertical: 3),
                    width: isActive ? 6 : 4,
                    height: isActive ? 18 : 8,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(4),
                      color: isActive ? Colors.white : Colors.white38,
                    ),
                  );
                }),
              ),
            ),
          ),

          // Контент отзыва (над футером)
          Positioned(
            left: 0,
            right: 0,
            bottom: 90,
            child: _buildReviewContent(widget.items[_currentIndex]),
          ),

          // Чёрный футер с товаром
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: _buildProductFooter(widget.items[_currentIndex]),
          ),
        ],
      ),
    );
  }

  Widget _buildMediaItem(FullscreenMediaItem item) {
    if (item.isVideo) {
      return _VideoPlayerItem(item: item);
    }
    return Center(
      child: CachedNetworkImage(
        imageUrl: _imageUrl(item.mediaUrl),
        fit: BoxFit.contain,
        width: double.infinity,
        height: double.infinity,
        placeholder: (_, _) => const Center(
          child: CircularProgressIndicator(color: Colors.white54),
        ),
        errorWidget: (_, _, _) => const Center(
          child: Icon(Icons.broken_image, color: Colors.white54, size: 48),
        ),
      ),
    );
  }

  Widget _buildReviewContent(FullscreenMediaItem item) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              CircleAvatar(
                backgroundColor: context.colors.textPrimary,
                radius: 16,
                child: Text(
                  item.userName.isNotEmpty ? item.userName[0].toUpperCase() : '?',
                  style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  item.userName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Row(
                children: List.generate(5, (i) => Icon(
                  i < item.rating ? Icons.star : Icons.star_border,
                  size: 18,
                  color: i < item.rating ? context.colors.warning : Colors.white38,
                )),
              ),
            ],
          ),

          if (item.comment != null && item.comment!.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              item.comment!,
              maxLines: 5,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                height: 1.5,
                fontWeight: FontWeight.w400,
              ),
            ),
          ],
        ],
      ),
    );
  }

    Widget _buildProductFooter(FullscreenMediaItem item) {
    // Определяем отображаемую цену
    double? displayPrice;
    double? oldPrice;

    if (item.productSalePrice != null && item.productSalePrice! < (item.productPrice ?? double.infinity)) {
      displayPrice = item.productSalePrice;
      oldPrice = item.productPrice;
    } else if (item.productCardPrice != null && item.productCardPrice! < (item.productPrice ?? double.infinity)) {
      displayPrice = item.productCardPrice;
      oldPrice = item.productPrice;
    } else {
      displayPrice = item.productPrice;
    }

    return Container(
      color: Colors.black,
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 14),
      child: Row(
        children: [
          // Цены горизонтально: актуальная крупная слева, старая зачёркнутая справа
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                // Текущая цена (крупная)
                Flexible(
                  child: displayPrice != null
                      ? context.formatPrice(
                          displayPrice,
                          fontSize: 24,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                          maxLines: 1,
                        )
                      : const Text(
                          'Цена по запросу',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                          ),
                        ),
                ),
                // Старая цена (зачёркнутая) справа
                if (oldPrice != null) ...[
                  const SizedBox(width: 8),
                  context.formatPrice(
                    oldPrice,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: Colors.white38,
                    decoration: TextDecoration.lineThrough,
                  ),
                ],
              ],
            ),
          ),

          const SizedBox(width: 8),

          // В корзину (компактная)
          GestureDetector(
            onTap: () {},
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Text(
                'В корзину',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.black),
              ),
            ),
          ),

          const SizedBox(width: 6),

          // Купить сейчас (компактная)
          GestureDetector(
            onTap: () {},
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [context.colors.brand, context.colors.brandDark],
                ),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Text(
                'Купить сейчас',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.white),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _VideoPlayerItem extends StatefulWidget {
  final FullscreenMediaItem item;

  const _VideoPlayerItem({required this.item});

  @override
  State<_VideoPlayerItem> createState() => _VideoPlayerItemState();
}

class _VideoPlayerItemState extends State<_VideoPlayerItem> {
  VideoPlayerController? _controller;
  bool _isPlaying = false;
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    _initVideo();
  }

  Future<void> _initVideo() async {
    _controller = VideoPlayerController.networkUrl(
      Uri.parse(widget.item.mediaUrl.startsWith('http')
          ? widget.item.mediaUrl
          : 'https://xn--80abvyjk6cts.xn--p1ai/${widget.item.mediaUrl}'),
    );

    await _controller!.initialize();
    _controller!.setLooping(true);

    if (mounted) {
      setState(() => _isInitialized = true);
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  void _togglePlay() {
    if (_isPlaying) {
      _controller?.pause();
    } else {
      _controller?.play();
    }
    setState(() => _isPlaying = !_isPlaying);
  }

  @override
  Widget build(BuildContext context) {
    if (!_isInitialized) {
      return Stack(
        fit: StackFit.expand,
        children: [
          if (widget.item.videoPreview != null && widget.item.videoPreview!.isNotEmpty)
            Image.network(
              widget.item.videoPreview!.startsWith('http')
                  ? widget.item.videoPreview!
                  : 'https://xn--80abvyjk6cts.xn--p1ai/${widget.item.videoPreview}',
              fit: BoxFit.contain,
              width: double.infinity,
              height: double.infinity,
            ),
          const Center(
            child: CircularProgressIndicator(color: Colors.white54),
          ),
        ],
      );
    }

    return GestureDetector(
      onTap: _togglePlay,
      child: Center(
        child: AspectRatio(
          aspectRatio: _controller!.value.aspectRatio,
          child: Stack(
            fit: StackFit.expand,
            children: [
              VideoPlayer(_controller!),
              if (!_isPlaying)
                const Center(
                  child: Icon(Icons.play_circle_fill, color: Colors.white, size: 64),
                ),
            ],
          ),
        ),
      ),
    );
  }
}