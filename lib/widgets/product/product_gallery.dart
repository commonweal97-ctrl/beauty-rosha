// lib/widgets/product/product_gallery.dart
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../../screens/product/photo_view_screen.dart';
import '../../services/cdn_service.dart';
import '../image_loader.dart';
import '../../core/app_colors.dart';

class ProductGallery extends StatefulWidget {
  final List<String> images;
  final String heroTag;
  final String? videoUrl;
  final int? salePercent;

  const ProductGallery({
    super.key,
    required this.images,
    this.heroTag = 'product_gallery',
    this.videoUrl,
    this.salePercent,
  });

  @override
  State<ProductGallery> createState() => _ProductGalleryState();
}

class _ProductGalleryState extends State<ProductGallery> {
  final PageController _pageController = PageController();
  int _currentPage = 0;
  bool _zoomed = false;
  final TransformationController _zoomController = TransformationController();
  bool _disposed = false;

  VideoPlayerController? _videoController;
  bool _videoInitialized = false;
  bool _isVideoPlaying = false;
  bool _videoLoading = true;

  int get _totalCount =>
      (widget.videoUrl != null ? 1 : 0) + widget.images.length;
  int get _videoIndex => 0;
  bool get _hasVideo =>
      widget.videoUrl != null && widget.videoUrl!.isNotEmpty;

  @override
  void initState() {
    super.initState();
    if (_hasVideo) {
      _initVideo();
    }
  }

  void _initVideo() {
    final videoUrl = widget.videoUrl?.replaceFirst(
      'https://xn--80aaf6ac.xn--80abvyjk6cts.xn--p1ai',
      'https://xn--80abvyjk6cts.xn--p1ai',
    );

    if (videoUrl == null) return;

    _videoController = VideoPlayerController.networkUrl(
      Uri.parse(videoUrl),
      videoPlayerOptions: VideoPlayerOptions(
        mixWithOthers: true,
        allowBackgroundPlayback: false,
      ),
    );

    _videoController!.initialize().then((_) {
      if (!_disposed && mounted) {
        _safeSetState(() {
          _videoInitialized = true;
          _videoLoading = false;
        });
        _videoController!.setLooping(true);
        _videoController!.setVolume(0);
      }
    }).catchError((_) {
      if (!_disposed && mounted) {
        _safeSetState(() {
          _videoInitialized = false;
          _videoLoading = false;
        });
      }
    });
  }

  void _onVideoListener() {
    if (!_disposed && mounted) {
      if (_videoController!.value.isInitialized && _videoLoading) {
        _safeSetState(() => _videoLoading = false);
      }
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _pageController.dispose();
    _zoomController.dispose();
    _videoController?.removeListener(_onVideoListener);
    _videoController?.dispose();
    super.dispose();
  }

  void _safeSetState(VoidCallback fn) {
    if (!_disposed && mounted) setState(fn);
  }

  void _toggleVideoPlayPause() {
    if (_videoController == null || !_videoInitialized) return;
    if (_isVideoPlaying) {
      _videoController!.pause();
    } else {
      _videoController!.play();
      _videoController!.setVolume(1.0);
    }
    _safeSetState(() => _isVideoPlaying = !_isVideoPlaying);
  }

  void _toggleFullScreen() {
    if (_videoController == null || !_videoInitialized) return;

    final wasPlaying = _isVideoPlaying;

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => Scaffold(
          backgroundColor: Colors.black,
          body: SafeArea(
            child: Stack(
              children: [
                Center(
                  child: GestureDetector(
                    onTap: () {
                      if (_videoController!.value.isPlaying) {
                        _videoController!.pause();
                      } else {
                        _videoController!.play();
                      }
                      setState(() {});
                    },
                    child: VideoPlayer(_videoController!),
                  ),
                ),
                Positioned(
                  top: 16,
                  left: 16,
                  child: GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.close,
                        color: Colors.white,
                        size: 22,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ).then((_) {
      if (wasPlaying && !_videoController!.value.isPlaying) {
        _videoController!.play();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;

    if (!_hasVideo && widget.images.isEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Container(
          height: screenWidth * 1.35,
          color: context.colors.surfaceAlt,
          child: Center(
            child: Icon(Icons.image, size: 64, color: context.colors.border),
          ),
        ),
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        GestureDetector(
          onDoubleTap: () {
            if (_currentPage == _videoIndex && _hasVideo) {
              _toggleVideoPlayPause();
              return;
            }
            _safeSetState(() => _zoomed = !_zoomed);
            if (!_zoomed) _zoomController.value = Matrix4.identity();
          },
          onTap: () {
            if (_currentPage != _videoIndex && widget.images.isNotEmpty) {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => PhotoViewScreen(
                    images: widget.images
                        .map((url) => CdnService.imageUrl(url))
                        .toList(),
                    initialIndex: _hasVideo ? _currentPage - 1 : _currentPage,
                  ),
                ),
              );
            }
          },
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: Stack(
              children: [
                InteractiveViewer(
                  transformationController: _zoomController,
                  panEnabled: _zoomed && _currentPage != _videoIndex,
                  scaleEnabled: _zoomed && _currentPage != _videoIndex,
                  child: Container(
                    width: screenWidth,
                    height: screenWidth * 1.35,
                    color: context.colors.surfaceAlt,
                    child: PageView.builder(
                      controller: _pageController,
                      onPageChanged: (index) {
                        _safeSetState(() {
                          _currentPage = index;
                          _zoomed = false;
                          _zoomController.value = Matrix4.identity();
                        });
                        if (index != _videoIndex && _isVideoPlaying) {
                          _videoController?.pause();
                          _safeSetState(() => _isVideoPlaying = false);
                        }
                      },
                      itemCount: _totalCount,
                      itemBuilder: (context, index) {
                        if (_hasVideo && index == _videoIndex) {
                          return _buildVideoSlide();
                        }
                        final imageIndex = _hasVideo ? index - 1 : index;
                        final url = widget.images[imageIndex];

                        return Hero(
                          tag: '${widget.heroTag}_$imageIndex',
                          child: ImageLoader(
                            imageUrl: url,
                            width: screenWidth,
                            height: screenWidth * 1.35,
                            borderRadius: 0,
                            errorIcon: Icons.broken_image,
                          ),
                        );
                      },
                    ),
                  ),
                ),
                if (widget.salePercent != null && widget.salePercent! > 0)
                  Positioned(
                    bottom: 12,
                    left: 12,
                    child: Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: context.colors.error,
                        borderRadius: BorderRadius.circular(8),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.15),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Text(
                        '−${widget.salePercent}%',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
        if (_totalCount > 1)
          Padding(
            padding: const EdgeInsets.only(top: 8, bottom: 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(_totalCount, (index) {
                final isActive = _currentPage == index;
                return AnimatedContainer(
                  duration: Duration(milliseconds: 200),
                  curve: Curves.easeInOut,
                  width: isActive ? 20 : 6,
                  height: 6,
                  margin: EdgeInsets.symmetric(horizontal: 3),
                  decoration: BoxDecoration(
                    color: isActive
                        ? context.colors.brand
                        : context.colors.border,
                    borderRadius: BorderRadius.circular(3),
                  ),
                );
              }),
            ),
          ),
      ],
    );
  }

  Widget _buildVideoSlide() {
    if (!_videoInitialized || _videoController == null) {
      return Container(
        color: context.colors.textPrimary,
        child: const Center(
          child: CircularProgressIndicator(color: Colors.white54),
        ),
      );
    }

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _toggleVideoPlayPause,
      child: Stack(
        fit: StackFit.expand,
        children: [
          VideoPlayer(_videoController!),
          if (!_isVideoPlaying)
            Center(
              child: Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.6),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.play_arrow,
                  color: Colors.white,
                  size: 32,
                ),
              ),
            ),
          Positioned(
            top: 12,
            left: 12,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    _isVideoPlaying ? Icons.pause : Icons.play_arrow,
                    color: Colors.white,
                    size: 14,
                  ),
                  const SizedBox(width: 4),
                  const Text(
                    'Видео',
                    style: TextStyle(color: Colors.white, fontSize: 11),
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            bottom: 12,
            right: 12,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                GestureDetector(
                  onTap: () {
                    if (_videoController != null) {
                      final newVolume =
                          _videoController!.value.volume > 0 ? 0.0 : 1.0;
                      _videoController!.setVolume(newVolume);
                      _safeSetState(() {});
                    }
                  },
                  child: Container(
                    width: 36,
                    height: 36,
                    margin: const EdgeInsets.only(bottom: 8),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      (_videoController?.value.volume ?? 0) > 0
                          ? Icons.volume_up
                          : Icons.volume_off,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                ),
                GestureDetector(
                  onTap: _toggleFullScreen,
                  child: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.fullscreen,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}