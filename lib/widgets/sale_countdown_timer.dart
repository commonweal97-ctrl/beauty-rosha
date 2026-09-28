// lib/widgets/sale_countdown_timer.dart
import 'dart:async';
import 'package:flutter/material.dart';
import '../core/app_colors.dart';

class SaleCountdownTimer extends StatefulWidget {
  final DateTime saleEndDate;
  final DateTime? saleStartDate;
  final bool compact;

  const SaleCountdownTimer({
    super.key,
    required this.saleEndDate,
    this.saleStartDate,
    this.compact = false,
  });

  @override
  State<SaleCountdownTimer> createState() => _SaleCountdownTimerState();
}

class _SaleCountdownTimerState extends State<SaleCountdownTimer> {
  Timer? _timer;
  Duration _remaining = Duration.zero;
  double _progress = 1.0;

  @override
  void initState() {
    super.initState();
    _updateRemaining();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      _updateRemaining();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _updateRemaining() {
    final now = DateTime.now();
    final remaining = widget.saleEndDate.difference(now);

    if (remaining.isNegative || remaining == Duration.zero) {
      if (mounted) {
        setState(() {
          _remaining = Duration.zero;
          _progress = 0.0;
        });
      }
      _timer?.cancel();
      return;
    }

    // Единая логика для всех режимов
    double progress = _calculateProgress(now, remaining);

    if (mounted) {
      setState(() {
        _remaining = remaining;
        _progress = progress;
      });
    }
  }

  double _calculateProgress(DateTime now, Duration remaining) {
    // Если есть дата начала — считаем от неё
    if (widget.saleStartDate != null) {
      final totalDuration = widget.saleEndDate.difference(widget.saleStartDate!);
      if (totalDuration.inSeconds > 0) {
        return (remaining.inSeconds / totalDuration.inSeconds).clamp(0.0, 1.0);
      }
    }
    
    // Дефолт: 7 дней (стандартная длительность акции)
    const defaultDuration = Duration(days: 7);
    return (remaining.inSeconds / defaultDuration.inSeconds).clamp(0.0, 1.0);
  }

  @override
  Widget build(BuildContext context) {
    if (_remaining == Duration.zero) return const SizedBox.shrink();

    return widget.compact ? _buildCompact() : _buildFull();
  }

  Widget _buildCompact() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('🔥', style: TextStyle(fontSize: 10)),
        SizedBox(width: 4),
        Text(
          _formatTime(_remaining),
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: context.colors.textMuted,
          ),
        ),
      ],
    );
  }

  Widget _buildFull() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Color(0xFFF8F8F8),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'До конца акции',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: context.colors.textMuted,
                ),
              ),
              Spacer(),
              Text(
                _formatTime(_remaining),
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: context.colors.textPrimary,
                  fontFeatures: [FontFeature.tabularFigures()],
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          _buildProgressBar(),
        ],
      ),
    );
  }

  Widget _buildProgressBar() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final maxWidth = constraints.maxWidth;
        final fillWidth = maxWidth * _progress;
        final indicatorPosition = (fillWidth - 8).clamp(0.0, maxWidth - 16.0);

        return SizedBox(
          height: 16,
          child: Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.centerLeft,
            children: [
              // Фоновая шкала
              Container(
                width: maxWidth,
                height: 6,
                decoration: BoxDecoration(
                  color: const Color(0xFFEEEEEE),
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
              
              // Заполненная часть
              AnimatedContainer(
                duration: const Duration(milliseconds: 500),
                curve: Curves.linear,
                width: fillWidth.clamp(0.0, maxWidth),
                height: 6,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: _getGradientColors(),
                  ),
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
              
              // Огонёк-индикатор
              AnimatedPositioned(
                duration: const Duration(milliseconds: 500),
                curve: Curves.linear,
                left: indicatorPosition,
                child: Container(
                  width: 16,
                  height: 16,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    border: Border.all(color: const Color(0xFFDDDDDD), width: 0.5),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.08),
                        blurRadius: 3,
                        offset: const Offset(0, 1),
                      ),
                    ],
                  ),
                  child: const Center(
                    child: Text('🔥', style: TextStyle(fontSize: 8)),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  List<Color> _getGradientColors() {
    if (_progress > 0.5) {
      return const [Color(0xFF4CAF50), Color(0xFF8BC34A)];
    } else if (_progress > 0.25) {
      return const [Color(0xFFFFA500), Color(0xFFFFC107)];
    } else {
      return const [Color(0xFFF44336), Color(0xFFFF5722)];
    }
  }

  String _formatTime(Duration d) {
    final days = d.inDays;
    final hours = d.inHours % 24;
    final minutes = d.inMinutes % 60;
    final seconds = d.inSeconds % 60;

    if (days > 0) {
      return '$days дн ${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    }
    return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }
}