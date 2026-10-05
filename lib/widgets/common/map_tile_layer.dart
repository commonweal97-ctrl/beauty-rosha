// lib/widgets/common/map_tile_layer.dart
//
// Единый слой тайлов карты для всего проекта.
// OSM + инверсия цветов для тёмной темы.
// Используется ВЕЗДЕ, где есть FlutterMap.

import 'package:dio_cache_interceptor/dio_cache_interceptor.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_cache/flutter_map_cache.dart';

/// Возвращает готовый TileLayer с кэшем,
/// инвертированный для тёмной темы (через ColorFiltered).
///
/// Использование:
/// ```dart
/// FlutterMap(
///   options: MapOptions(...),
///   children: [
///     buildMapTileLayer(),
///     ...other layers
///   ],
/// );
/// ```
Widget buildMapTileLayer() {
  return Builder(
    builder: (context) {
      final isDark = Theme.of(context).brightness == Brightness.dark;

      final baseLayer = TileLayer(
        urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
        userAgentPackageName: 'com.beautyrosha.app',
        tileProvider: CachedTileProvider(store: MemCacheStore()),
      );

      if (!isDark) return baseLayer;

      return ColorFiltered(
        colorFilter: const ColorFilter.matrix([
          -0.85, 0, 0, 0, 210,
          0, -0.85, 0, 0, 210,
          0, 0, -0.85, 0, 210,
          0, 0, 0, 1, 0,
        ]),
        child: baseLayer,
      );
    },
  );
}

/// Атрибуция для карт (обязательно по ToS OpenStreetMap).
/// Добавляй в `children` FlutterMap ПОСЛЕ всех слоёв:
///
/// ```dart
/// FlutterMap(
///   options: MapOptions(...),
///   children: [
///     buildMapTileLayer(),
///     ...другие слои,
///     buildMapAttribution(),
///   ],
/// );
/// ```
Widget buildMapAttribution() {
  return Builder(
    builder: (context) {
      final isDark = Theme.of(context).brightness == Brightness.dark;

      return Align(
        alignment: Alignment.bottomLeft,
        child: Padding(
          padding: const EdgeInsets.only(left: 8, bottom: 6),
          child: IgnorePointer(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
              decoration: BoxDecoration(
                color: isDark
                    ? Colors.black.withValues(alpha: 0.55)
                    : Colors.white.withValues(alpha: 0.75),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                '© OpenStreetMap',
                style: TextStyle(
                  fontSize: 10,
                  height: 1.0,
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.85)
                      : Colors.black.withValues(alpha: 0.7),
                ),
              ),
            ),
          ),
        ),
      );
    },
  );
}
