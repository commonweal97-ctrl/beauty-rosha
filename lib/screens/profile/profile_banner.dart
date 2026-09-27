// lib/screens/profile/profile_banner.dart
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';

// ========================================================================
// SHIMMER WIDGET
// ========================================================================

class ProfileShimmerWidget extends StatefulWidget {
  const ProfileShimmerWidget({super.key});
  @override
  State<ProfileShimmerWidget> createState() => _ProfileShimmerWidgetState();
}

class _ProfileShimmerWidgetState extends State<ProfileShimmerWidget> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 1500));
    _animation = Tween<double>(begin: -2, end: 2).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
    _controller.repeat();
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
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment(_animation.value - 1, 0),
              end: Alignment(_animation.value, 0),
              colors: const [
                Color(0xFFEDEDED),
                Color(0xFFF8F8F8),
                Color(0xFFEDEDED),
              ],
            ),
          ),
        );
      },
    );
  }
}

// ========================================================================
// ANIMATED BANNER WRAPPER
// ========================================================================

class ProfileAnimatedBannerWrapper extends StatelessWidget {
  final Widget child;
  final bool isLoaded;
  
  const ProfileAnimatedBannerWrapper({
    super.key,
    required this.child,
    required this.isLoaded,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 400),
      switchInCurve: Curves.easeOut,
      switchOutCurve: Curves.easeIn,
      transitionBuilder: (Widget child, Animation<double> animation) {
        return FadeTransition(
          opacity: animation,
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0, 0.05),
              end: Offset.zero,
            ).animate(animation),
            child: child,
          ),
        );
      },
      child: child,
    );
  }
}

// ========================================================================
// PROFILE BANNER WIDGET
// ========================================================================

class ProfileBanner extends StatelessWidget {
  final String? bannerUrl;
  final String? linkUrl;
  final bool isLoading;
  final bool imageReady;
  final VoidCallback? onTap;
  
  const ProfileBanner({
    super.key,
    this.bannerUrl,
    this.linkUrl,
    this.isLoading = false,
    this.imageReady = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    if (isLoading || (bannerUrl != null && bannerUrl!.isNotEmpty && !imageReady)) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: ProfileAnimatedBannerWrapper(
          isLoaded: false,
          child: Container(
            key: const ValueKey('banner_skeleton'),
            height: 160,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: const ProfileShimmerWidget(),
            ),
          ),
        ),
      );
    }
    
    if (bannerUrl == null || bannerUrl!.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: ProfileAnimatedBannerWrapper(
          isLoaded: true,
          child: _buildDefaultBanner(),
        ),
      );
    }
    
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: ProfileAnimatedBannerWrapper(
        isLoaded: true,
        child: GestureDetector(
          onTap: onTap,
          child: ClipRRect(
            key: const ValueKey('banner_image'),
            borderRadius: BorderRadius.circular(16),
            child: CachedNetworkImage(
              imageUrl: bannerUrl!,
              fit: BoxFit.cover,
              width: double.infinity,
              height: 160,
              fadeInDuration: Duration.zero,
              placeholder: (_, _) => const ProfileShimmerWidget(),
              errorWidget: (_, _, _) => _buildDefaultBanner(),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDefaultBanner() {
    return Container(
      key: const ValueKey('banner_default'),
      width: double.infinity, 
      height: 160,
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [Color(0xFFFDF2F5), Color(0xFFFFE4E9)]), 
        borderRadius: BorderRadius.circular(16),
      ),
      child: const Center(
        child: Text(
          'Специальные предложения и акции', 
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFFDD1847)),
        ),
      ),
    );
  }
}