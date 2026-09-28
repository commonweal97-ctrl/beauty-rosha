// lib/widgets/scroll_to_top_button.dart
import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';

import '../core/app_logger.dart';
import '../core/app_colors.dart';

/// Кнопка "Наверх", которая появляется только после остановки скролла
/// на расстоянии [threshold] пикселей от верха.
class ScrollToTopButton extends StatefulWidget {
  /// ScrollController для отслеживания позиции скролла.
  final ScrollController scrollController;

  /// Пороговое значение offset, после которого кнопка может появиться.
  final double threshold;

  /// Задержка перед появлением кнопки после остановки скролла.
  final Duration appearDelay;

  /// Размер кнопки.
  final double size;

  /// Цвет иконки.
  final Color? iconColor;

  /// Цвет фона кнопки.
  final Color backgroundColor;

  /// Длительность анимации появления/исчезновения.
  final Duration animationDuration;

  /// Callback при нажатии (по умолчанию скроллит к началу).
  final VoidCallback? onTap;

  const ScrollToTopButton({
    super.key,
    required this.scrollController,
    this.threshold = 500,
    this.appearDelay = const Duration(milliseconds: 300),
    this.size = 44,
    this.iconColor,
    this.backgroundColor = Colors.white,
    this.animationDuration = const Duration(milliseconds: 250),
    this.onTap,
  });

  @override
  State<ScrollToTopButton> createState() => _ScrollToTopButtonState();
}

class _ScrollToTopButtonState extends State<ScrollToTopButton> {
  static const _logTag = 'ScrollToTopButton';

  bool _showButton = false;
  Timer? _scrollEndTimer;

  @override
  void initState() {
    super.initState();
    widget.scrollController.addListener(_onScroll);
  }

  void _onScroll() {
    if (!widget.scrollController.hasClients) return;

    try {
      final offset = widget.scrollController.offset;

      if (_showButton) {
        setState(() {
          _showButton = false;
        });
      }

      _scrollEndTimer?.cancel();

      _scrollEndTimer = Timer(widget.appearDelay, () {
        if (!mounted) return;
        if (!widget.scrollController.hasClients) return;

        final shouldShow = offset > widget.threshold;

        if (shouldShow) {
          setState(() {
            _showButton = true;
          });
        }
      });
    } catch (e) {
      AppLogger.warning(_logTag, 'onScroll failed', e);
    }
  }

  void _handleTap() {
    if (widget.onTap != null) {
      widget.onTap!();
    } else {
      if (widget.scrollController.hasClients) {
        widget.scrollController.animateTo(
          0,
          duration: const Duration(milliseconds: 400),
          curve: Curves.easeOut,
        );
      }
    }
  }

  @override
  void dispose() {
    _scrollEndTimer?.cancel();
    try {
      widget.scrollController.removeListener(_onScroll);
    } catch (_) {}
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedOpacity(
      opacity: _showButton ? 1.0 : 0.0,
      duration: widget.animationDuration,
      child: AnimatedScale(
        scale: _showButton ? 1.0 : 0.7,
        duration: widget.animationDuration,
        curve: Curves.easeOutBack,
        child: GestureDetector(
          onTap: _handleTap,
          child: Container(
            width: widget.size,
            height: widget.size,
            decoration: BoxDecoration(
              color: widget.backgroundColor.withValues(alpha: 0.85),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.06),
                  blurRadius: 20,
                  offset: const Offset(0, 4),
                ),
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.03),
                  blurRadius: 2,
                  offset: const Offset(0, 1),
                ),
              ],
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.8),
                width: 1,
              ),
            ),
            child: ClipOval(
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                child: Center(
                  child: Icon(
                    Icons.keyboard_arrow_up,
                    color: widget.iconColor ?? context.colors.brand,
                    size: widget.size * 0.64,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}