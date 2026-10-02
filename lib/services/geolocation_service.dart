// lib/services/geolocation_service.dart
//
// Профессиональный сервис геолокации.
// Использует getPositionStream для ожидания GPS-фикса,
// отбрасывает неточные позиции (accuracy > minAccuracy),
// возвращает лучшую за timeout.

import 'dart:async';

import 'package:geolocator/geolocator.dart';

import '../core/app_logger.dart';

class GeolocationService {
  static const _logTag = 'GeolocationService';

  /// Получить точную позицию.
  ///
  /// Слушает поток позиций, отбрасывает всё с accuracy > [minAccuracy],
  /// возвращает первую подходящую. Если за [timeout] не нашли —
  /// возвращает лучшую из полученных (может быть неточной).
  ///
  /// Возвращает null если:
  ///  - служба геолокации выключена
  ///  - разрешение не выдано / заблокировано
  ///  - не получили ни одной позиции за timeout
  static Future<Position?> getAccuratePosition({
    Duration timeout = const Duration(seconds: 15),
    double minAccuracy = 50.0,
    LocationAccuracy accuracy = LocationAccuracy.best,
  }) async {
    // 1. Проверка службы геолокации
    if (!await Geolocator.isLocationServiceEnabled()) {
      AppLogger.warning(_logTag, 'Location service disabled');
      return null;
    }

    // 2. Проверка/запрос разрешения
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      AppLogger.warning(_logTag, 'Permission denied: $permission');
      return null;
    }

    // 3. Слушаем поток позиций
    final completer = Completer<Position?>();
    Position? best;

    final stream = Geolocator.getPositionStream(
      locationSettings: LocationSettings(
        accuracy: accuracy,
        distanceFilter: 0,
      ),
    );

    final sub = stream.listen(
      (pos) {
        // Сохраняем лучшую по accuracy
        if (best == null || pos.accuracy < best!.accuracy) {
          best = pos;
          AppLogger.info(
            _logTag,
            'Position: ${pos.latitude},${pos.longitude} '
                'accuracy=${pos.accuracy.round()}m',
          );
        }
        // Если достигли нужной точности — завершаем
        if (pos.accuracy <= minAccuracy && !completer.isCompleted) {
          completer.complete(pos);
        }
      },
      onError: (e, st) {
        AppLogger.warning(_logTag, 'Stream error', e);
        if (!completer.isCompleted) completer.complete(best);
      },
    );

    // 4. Таймаут
    Timer(timeout, () {
      if (!completer.isCompleted) {
        AppLogger.warning(
          _logTag,
          'Timeout. Best accuracy: '
              '${best?.accuracy.round() ?? "none"}m',
        );
        completer.complete(best);
      }
    });

    final result = await completer.future;
    await sub.cancel();
    return result;
  }

  /// Проверить, включена ли служба геолокации.
  static Future<bool> isServiceEnabled() =>
      Geolocator.isLocationServiceEnabled();

  /// Проверить, выдано ли разрешение.
  static Future<bool> hasPermission() async {
    final p = await Geolocator.checkPermission();
    return p == LocationPermission.whileInUse ||
        p == LocationPermission.always;
  }
}
