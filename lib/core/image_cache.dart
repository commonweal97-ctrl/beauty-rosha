// lib/core/image_cache.dart
//
// Утилита для расчёта memCacheWidth/Height для картинок.
// Уменьшает потребление RAM при декодировании изображений.
// Использование:
//   memCacheWidth: imageCacheSize(context, width: 96),
//   memCacheHeight: imageCacheSize(context, height: 128),

import 'package:flutter/material.dart';

/// Рассчитывает размер для memCache* с учётом devicePixelRatio.
///
/// [width]/[height] — логические размеры виджета.
/// [scale] — множитель (по умолчанию = devicePixelRatio, но можно
/// задать меньше для экономии памяти на retina-экранах).
///
/// Возвращает int в физических пикселях.
int imageCacheSize(
  BuildContext context, {
  required double size,
  double scaleFactor = 1.0,
}) {
  final dpr = MediaQuery.of(context).devicePixelRatio;
  // Ограничиваем максимальный множитель, чтобы не жрать много на 3x экранах.
  final effectiveScale = dpr > 2.0 ? 2.0 : dpr;
  return (size * effectiveScale * scaleFactor).round();
}

/// Упрощённый вариант — возвращает tuple (width, height).
(int, int) imageCacheSizePair(
  BuildContext context, {
  required double width,
  required double height,
}) {
  return (
    imageCacheSize(context, size: width),
    imageCacheSize(context, size: height),
  );
}
