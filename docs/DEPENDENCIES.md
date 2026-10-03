# Зависимости Flutter — состояние

**Обновлено:** 2026-10-03
**Flutter:** 3.47.6 (stable) / Dart 3.13.5
**Outdated:** 61 → 28 (минус 33, все транзитивные)
**Прямых в outdated:** 0

---

## ✅ Обновлено

### Удалены (мёртвые зависимости)

| Пакет | Версия | Причина |
|---|---|---|
| `shimmer` | 3.0.0 | не использовался (свой `ShimmerBox`) |
| `cupertino_icons` | 1.0.9 | не использовался (только Material `Icons.*`) |
| `flutter_rating_bar` | 4.0.1 | не использовался (свой `product_rating_section`) |

### Переведены в транзитивные

| Пакет | Кто тянет |
|---|---|
| `collection` | транзитивно |
| `dio` | `dio_cache_interceptor` |
| `intl` | Firebase / flutter_map |

### Major-обновления (с миграцией кода)

| Пакет | Было → Стало | Миграция |
|---|---|---|
| `cached_network_image` | 3.4.1 → 4.0.4 | API не менялся |
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

### Обновление Flutter SDK

- Flutter 3.44.6 → 3.47.6 (3 minor-версии)
- Dart 3.12.2 → 3.13.5
- DevTools 2.57.0 → 2.60.0

### Firebase через SPM

- Убраны дублирующие поды из `ios/Podfile`
- Firebase теперь только через Swift Package Manager
- `Podfile.lock` и `Package.resolved` — обновлены

### Побочно обновились (транзитивно)

- `win32` 5.15.0 → 6.4.0
- `win32_registry` 1.1.5 → 3.0.3
- `share_plus_platform_interface` 5.0.2 → 7.2.0
- `intl` 0.20.2 → 0.20.3
- `matcher`, `meta`, `test_api`, `vector_math`

---

## ⏸ Отложено (не наш контроль)

### `connectivity_plus` 6.1.5 → 7.3.2

**Причина:** конфликт `dbus`.

- `connectivity_plus 7.x` → `nm ^0.6.0` → `dbus ^0.8.0`
- `flutter_local_notifications 22.x` → `flutter_local_notifications_linux 8.0.1` → `dbus ^0.7.8`

**Разблокировка:** выход `flutter_local_notifications 23.x` с `dbus ^0.8.0`.

**Проверка:**

    flutter pub outdated | grep -E "connectivity_plus|dbus|flutter_local_notifications"

### `qr` 3.0.2 → 4.0.0 (транзитивный от `qr_flutter`)

**Причина:** `qr_flutter 4.1.0` — последняя, ещё не обновилась под `qr 4.x`.

**Разблокировка:** выход `qr_flutter 5.x` с `qr ^4.0.0`.

**Использование:** `QrImageView(data: ..., version: QrVersions.auto, ...)` — стабильно.

---

## 📋 Остальные 28 outdated — транзитивные/SDK

Приходят из:

- Flutter SDK: `clock`, `matcher`, `meta`, `stack_trace`, `test_api`, `vector_math`, `unicode`, `xml`, `material_color_utilities`
- Firebase: `_flutterfire_internals`
- flutter_map: `mgrs_dart`, `proj4dart`, `petitparser`
- flutter_local_notifications: `dbus`, `nm`
- qr_flutter: `qr`
- SDK/platform: `hooks`, `code_assets`, `objective_c`, `posix`, `simple_sparse_list`, `record_use`, `image_picker_android`, `gsettings`, `cupertino_ui`, `cross_file`

Мы не контролируем. Обновятся, когда их родители подтянут новые версии.

---

## 🎯 План на будущее

1. `flutter pub outdated` — раз в 2-3 недели
2. `flutter upgrade` — при выходе stable +1 minor
3. `connectivity_plus` — проверить при `flutter_local_notifications 23.x`
4. `qr_flutter` — проверить при 5.x

---

## 🛠 Инфраструктура

### Компоненты

- `GeolocationService` (`lib/services/geolocation_service.dart`) — `getPositionStream` + предзагрузка
- `CdnService.imageUrl(url, {size})` — CDN + выбор размера
- `ImageHelper` (backend) — 4 размера картинок

### Коммиты

- После каждого пакета — отдельный коммит
- Бэкапы `pubspec.yaml.bak_*` — перед обновлением

### Теги (точки отката)

- `stable-2026-10-03` — текущая стабильная
- `pre-flutter-upgrade` / `post-flutter-upgrade`
- `image-optimization-v1` / `image-optimization-v2`
- `firebase-spm-fix`

---

## ⚠️ Известные проблемы (не наши)

1. `app-analytics-services.com` — Firebase Analytics, неверный URL (проверить)
2. `getToken` TimeoutException на iPhone — пуши приходят, но токен не сразу
3. `AppDelegate.swift` warning — исправлено (UIScene migration)

---

## 📊 Итог

| | |
|---|---|
| Flutter | 3.44.6 → 3.47.6 |
| Outdated | 61 → 28 |
| Мёртвых удалено | 3 |
| Major-обновлений | 14 |
| Коммитов | 20+ |
| Багов починено | 6+ |
| Трафик картинок | ×9 меньше |
