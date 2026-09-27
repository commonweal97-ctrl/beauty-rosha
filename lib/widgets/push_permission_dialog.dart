// lib/widgets/push_permission_dialog.dart

import 'package:flutter/material.dart';
import '../services/push_permission_service.dart';

/// Полноэкранный попап для запроса разрешения на push-уведомления
///
/// Ответственность:
/// - Отображение красивого полноэкранного попапа
/// - Анимации появления/исчезновения
/// - Делегирование всей бизнес-логики в PushPermissionService
class PushPermissionDialog extends StatefulWidget {
  final VoidCallback? onDismiss;
  
  const PushPermissionDialog({super.key, this.onDismiss});

  @override
  State<PushPermissionDialog> createState() => _PushPermissionDialogState();
}

class _PushPermissionDialogState extends State<PushPermissionDialog>
    with SingleTickerProviderStateMixin {
  
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  
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
    PushPermissionService.saveLastShown();
  }
  
  Future<void> _enableAllNotifications() async {
    await _animationController.reverse();
    
    if (mounted) {
      Navigator.of(context).pop(PushDialogResult.enable);
    }
  }
  
  Future<void> _setupLater() async {
    await PushPermissionService.saveLastDismissed();
    await _animationController.reverse();
    
    if (mounted) {
      Navigator.of(context).pop(PushDialogResult.later);
    }
  }
  
  Future<void> _closeDialog() async {
    await PushPermissionService.saveLastDismissed();
    await _animationController.reverse();
    
    if (mounted) {
      Navigator.of(context).pop(PushDialogResult.dismiss);
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
    return Material(
      color: Colors.transparent,
      child: FadeTransition(
        opacity: _fadeAnimation,
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Фоновое изображение на весь экран
            Image.asset(
              'assets/images/push-okno.png.webp',
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) {
                return Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Color(0xFF1A1A1A),
                        Color(0xFF2D2D2D),
                      ],
                    ),
                  ),
                );
              },
            ),
            
            // Градиент для улучшения читаемости текста
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
                  // Верхняя панель с крестиком
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
                  
                  // Нижняя панель с текстом и кнопками
                  SlideTransition(
                    position: _slideAnimation,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text(
                            'Сообщать вам\nо важном и выгодном?',
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
                              onPressed: _enableAllNotifications,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFFDD1847),
                                foregroundColor: Colors.white,
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                              ),
                              child: const Text(
                                'Включить все уведомления',
                                style: TextStyle(
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
                              onPressed: _setupLater,
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
                                'Настроить уведомления позже',
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
    );
  }
}

/// Результат взаимодействия с диалогом
enum PushDialogResult {
  enable,
  later,
  dismiss,
}