# Обновление зависимостей Flutter

**Дата:** 2026-10-02
**Flutter:** 3.44.6 (stable) / Dart 3.12.2
**Outdated:** 61 → 28 (минус 33)
**Прямых в outdated:** 0

---

## ✅ Обновлено

### Удалены (мёртвые зависимости)
| Пакет | Версия | Причина |
|---|---|---|
| `shimmer` | 3.0.0 | не использовался (свой `ShimmerBox`) |
| `cupertino_icons` | 1.0.9 | не использовался (только Material `Icons.*`) |
| `flutter_rating_bar` | 4.0.1 | не использовался (свой `product_rating_section`) |

### Переведены в транзитивные (убраны из pubspec)
| Пакет | Было | Кто тянет |
|---|---|---|
| `collection` | direct | транзитивно от других |
| `dio` | direct | `dio_cache_interceptor` |
| `intl` | direct | Firebase / flutter_map |

### Major-обновления (с миграцией кода)
| Пакет | Было → Стало | Что мигрировали |
|---|---|---|
| `cached_network_image` | 3.4.1 → 4.0.3 | API не менялся |
| `app_links` | 6.4.1 → 7.2.1 | API не менялся |
| `local_auth` | 2.3.0 → 3.0.2 | `AuthenticationOptions` → `persistAcrossBackgrounding` |
| `device_info_plus` | 10.1.2 → 13.3.0 | API не менялся (+ SPM) |
| `package_info_plus` | 8.3.1 → 10.2.2 | API не менялся |
| `share_plus` | 10.1.4 → 13.3.1 | `Share.share()` → `SharePlus.instance.share(ShareParams(...))` |
| `geolocator` | 10.1.1 → 14.1.1 | `desiredAccuracy` → `locationSettings: LocationSettings(...)` |
| `geocoding` | 2.2.2 → 5.0.0 | `placemarkFromCoordinates()` → `Geocoding().placemarkFromCoordinates()` |
| `flutter_map` | 7.0.2 → 8.3.2 | API не менялся |
| `latlong2` | 0.9.1 → 0.10.1 | API не менялся |
| `firebase_core` | 3.15.2 → 4.15.0 | API не менялся |
| `firebase_messaging` | 15.2.10 → 16.7.0 | `AuthorizationStatus.deniedPermanently` в switch |
| `firebase_crashlytics` | 4.3.10 → 5.4.0 | API не менялся |
| `firebase_analytics` | 11.6.0 → 12.6.0 | API не менялся |

### Побочные обновления (транзитивные)
- `win32` 5.15.0 → 6.4.0
- `win32_registry` 1.1.5 → 3.0.3
- `share_plus_platform_interface` 5.0.2 → 7.2.0
- `material_ui` 1.2.0 (новый)
- прочие `*_platform_interface`, `*_web`

---

## ⏸ Отложено (не наша вина)

### `connectivity_plus` 6.1.5 → 7.3.2

**Причина:** конфликт `dbus` версий.

connectivity_plus 7.x → nm ^0.6.0 → dbus ^0.8.0
flutter_local_notifications 22.x → flutter_local_notifications_linux 8.0.1 → dbus ^0.7.8

Разблокировка: выход flutter_local_notifications 23.x с dbus ^0.8.0.

### qr 3.0.2 → 4.0.0 (транзитивный через qr_flutter)

Причина: qr_flutter 4.1.0 — последняя версия, ещё не обновилась под qr 4.x.
Разблокировка: выход qr_flutter 5.x с qr ^4.0.0.

### cached_network_image 4.0.3 → 4.0.4

Причина: требует Flutter ≥ 3.47.6 (у нас 3.44.6).
Разблокировка: обновление Flutter SDK.

---

## Остальные 25 outdated — транзитивные

Приходят из Flutter SDK, Firebase, flutter_map, flutter_local_notifications.
Мы их не контролируем.

---

## План на будущее

1. Обновление Flutter SDK до 3.47.x — разблокирует cached_network_image 4.0.4
2. Следить за flutter_local_notifications (23.x разблокирует connectivity_plus)
3. Следить за qr_flutter (5.x разблокирует qr)
4. Раз в 2-3 месяца — flutter pub outdated + обновление разблокированного

---

## Инфраструктура для обновлений

- GeolocationService (lib/services/geolocation_service.dart) — сервис геолокации с getPositionStream + предзагрузкой
- Коммит после каждого пакета — легко откатить один пакет
- Бэкапы pubspec.yaml.bak_* перед каждым обновлением
