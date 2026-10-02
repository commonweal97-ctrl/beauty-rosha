// lib/core/image_cache.dart
//
// Утилита для расчёта memCacheWidth/Height для картинок.
// Учитывает devicePixelRatio для правильного качества на retina.
//
// Использование:
//   memCacheWidth: imageCacheSize(context, size: 96),
//   memCacheHeight: imageCacheSize(context, size: 128),

import 'package:flutter/material.dart';

/// Максимальный множитель DPR (защита от 4x+ дисплеев).
const double _maxDpr = 3.0;

/// Рассчитывает размер для memCache* с учётом devicePixelRatio.
///
/// [size] — логический размер виджета.
/// [scaleFactor] — дополнительный множитель (по умолчанию 1.0).
///
/// Возвращает int в физических пикселях.
int imageCacheSize(
  BuildContext context, {
  required double size,
  double scaleFactor = 1.0,
}) {
  final dpr = MediaQuery.of(context).devicePixelRatio;
  final effectiveScale = dpr > _maxDpr ? _maxDpr : dpr;
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
