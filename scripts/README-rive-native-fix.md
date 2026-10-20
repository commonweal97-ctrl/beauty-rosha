# Фикс rive_native 0.1.11 для iOS-симулятора (Apple Silicon)

## Проблема
`rive_native 0.1.11` содержит prebuilt `.a` в `native/build/iphoneos/bin/{release,emulator}`.
`release/` — для устройства (`LC_BUILD_VERSION = platform 2`), `emulator/` — для симулятора
(`platform 7`, fat `x86_64 arm64`). Podspec использует `[sdk=iphonesimulator*]`-условия
в `OTHER_LDFLAGS`/`LIBRARY_SEARCH_PATHS`, но CocoaPods НЕ транслирует их в Runner —
Xcode линкует release/libbrotli.a (platform 2) → ошибка
"Building for 'iOS-simulator', but linking in object file ... built for 'iOS'".

## Фикс
Пропатчен `~/.pub-cache/.../rive_native-0.1.11/ios/rive_native.podspec`:
1. `OTHER_LDFLAGS` сделан плоским — всегда `-force_load .../emulator/librive_native.a`.
   `LIBRARY_SEARCH_PATHS` — `emulator` первым, `release` вторым (для устройства).
2. Добавлен `script_phases` «Rive Simulator Fix» — перед компиляцией при
   `PLATFORM_NAME=iphonesimulator` копирует `emulator/*.a` поверх `release/*.a`.

## Восстановить патч после flutter clean / pub cache repair

    cp scripts/rive_native.podspec.patched \
       ~/.pub-cache/hosted/pub.dev/rive_native-0.1.11/ios/rive_native.podspec
    cd ios && pod install && cd ..
    flutter run -d "iPhone 17 Pro"

## Когда обновлять
При апгрейде `rive_native` версии — проверить, что upstream починил баг
(issue в rive-flutter про `platform 7` в `emulator/`). Если починил — удалить патч.
