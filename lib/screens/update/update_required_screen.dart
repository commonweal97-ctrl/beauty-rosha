// lib/screens/update/update_required_screen.dart
import 'dart:io' show Platform;
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter/services.dart';
import '../../core/app_colors.dart';

class UpdateRequiredScreen extends StatefulWidget {
  final VoidCallback? onDismiss;
  
  const UpdateRequiredScreen({super.key, this.onDismiss});

  @override
  State<UpdateRequiredScreen> createState() => _UpdateRequiredScreenState();
}

class _UpdateRequiredScreenState extends State<UpdateRequiredScreen>
    with SingleTickerProviderStateMixin {
  
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  
  // Реальные ссылки
  static const String _appStoreUrl = 'https://apps.apple.com/app/id6789254420';
  static const String _googlePlayUrl = 'https://play.google.com/store/apps/details?id=com.beautyrosha.beauty_rosha';
  static const String _ruStoreUrl = 'https://www.rustore.ru/catalog/app/com.beautyrosha.beauty_rosha';

  bool? _isRuStore;

  String get _storeUrl {
    if (Platform.isIOS) return _appStoreUrl;
    if (_isRuStore == true) return _ruStoreUrl;
    return _googlePlayUrl;
  }

  String get _storeName {
    if (Platform.isIOS) return 'App Store';
    if (_isRuStore == true) return 'RuStore';
    return 'Google Play';
  }

  @override
  void initState() {
    super.initState();
    
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
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
    
    _animationController.forward();
    _detectRuStore();
  }

  Future<void> _detectRuStore() async {
    if (!Platform.isAndroid) return;
    try {
      const channel = MethodChannel('beautyrosha/installer');
      final installer = await channel.invokeMethod<String>('getInstallerPackage');
      if (mounted) {
        setState(() {
          _isRuStore = installer != null &&
              (installer.toLowerCase().contains('rustore') ||
               installer.toLowerCase().contains('ru.store'));
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isRuStore = false);
    }
  }

  Future<void> _openStore() async {
    final uri = Uri.parse(_storeUrl);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _updateLater() async {
    await _animationController.reverse();
    if (mounted) {
      Navigator.of(context).pop(false);
    }
  }

  Future<void> _closeDialog() async {
    await _animationController.reverse();
    if (mounted) {
      Navigator.of(context).pop(false);
      widget.onDismiss?.call();
    }
  }
  
  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: Material(
        color: Colors.transparent,
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Фоновое изображение
              Image.asset(
                'assets/images/update-photo.webp',
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          context.colors.textPrimary,
                          Color(0xFF2D2D2D),
                        ],
                      ),
                    ),
                  );
                },
              ),
              
              // Градиент для улучшения читаемости
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                height: MediaQuery.of(context).size.height * 0.5,
                child: IgnorePointer(
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          Colors.black.withValues(alpha: 0.3),
                          Colors.black.withValues(alpha: 0.7),
                          Colors.black.withValues(alpha: 0.85),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              
              // Контент
              SafeArea(
                child: Column(
                  children: [
                    // Крестик
                    Padding(
                      padding: const EdgeInsets.only(right: 8, top: 8),
                      child: Align(
                        alignment: Alignment.topRight,
                        child: GestureDetector(
                          onTap: _closeDialog,
                          child: Container(
                            width: 40,
                            height: 40,
                            margin: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.white.withValues(alpha: 0.2),
                            ),
                            child: const Icon(
                              Icons.close,
                              color: Colors.white,
                              size: 20,
                            ),
                          ),
                        ),
                      ),
                    ),
                    
                    const Spacer(),
                    
                    // Нижняя панель
                    SlideTransition(
                      position: _slideAnimation,
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text(
                              'Доступно\nобновление',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 28,
                                fontWeight: FontWeight.w700,
                                height: 1.2,
                                letterSpacing: -0.5,
                              ),
                            ),
                            
                            const SizedBox(height: 24),
                            
                            SizedBox(
                              width: double.infinity,
                              height: 56,
                              child: ElevatedButton(
                                onPressed: _openStore,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: context.colors.brand,
                                  foregroundColor: Colors.white,
                                  elevation: 0,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                ),
                                child: Text(
                                  'Обновить в $_storeName',
                                  style: const TextStyle(
                                    fontSize: 17,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ),
                            
                            const SizedBox(height: 12),
                            
                            SizedBox(
                              width: double.infinity,
                              height: 56,
                              child: TextButton(
                                onPressed: _updateLater,
                                style: TextButton.styleFrom(
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                    side: BorderSide(
                                      color: Colors.white.withValues(alpha: 0.3),
                                      width: 1,
                                    ),
                                  ),
                                ),
                                child: const Text(
                                  'Обновлю позже',
                                  style: TextStyle(
                                    fontSize: 17,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ),
                            
                            const SizedBox(height: 8),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}