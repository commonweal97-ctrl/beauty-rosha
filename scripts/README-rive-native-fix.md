# Фикс rive_native 0.1.11 для iOS (устройство + симулятор, Apple Silicon)

## Проблема
`rive_native 0.1.11` содержит prebuilt `.a`:
- `native/build/iphoneos/bin/release/` — для **устройства** (`LC_BUILD_VERSION = platform 2`)
- `native/build/iphoneos/bin/emulator/` — для **симулятора** (`platform 7`, fat `x86_64 arm64`)

Podspec upstream использует `[sdk=iphonesimulator*]`-условия в `OTHER_LDFLAGS`,
но **CocoaPods не транслирует их в Runner** — Xcode линкует `release/libbrotli.a`
(platform 2) → ошибка `Building for 'iOS-simulator', but linking in object file ... built for 'iOS'`.

## Фикс (3 части)

### 1. `scripts/rive_native.podspec.patched`
- `OTHER_LDFLAGS` — плоский (без `[sdk=...]`), всегда `-force_load .../bin/active/librive_native.a`
- `LIBRARY_SEARCH_PATHS = .../bin/active`
- `script_phase` «Rive Active Symlink» — перед компиляцией переключает симлинк `active/`:
  - `PLATFORM_NAME=iphonesimulator` → `active -> emulator/` (platform 7)
  - иначе → `active -> release/` (platform 2)
- `script_phase` «Rive Native Compile» — setup (если маркера нет)

### 2. `ios/Podfile` — `post_install`
Удаляет `-framework "rive_native"` из `Pods-Runner.{debug,release,profile}.xcconfig`
(иначе Pods-Runner тянет prebuilt framework, который содержит release/*.a — ломает симулятор).

### 3. `ios/Flutter/{Debug,Release}.xcconfig`
НЕ должны содержать `-force_load .../release/*.a` (старый костыль, ломал симулятор).
Должно быть только:
    #include? "Pods/Target Support Files/Pods-Runner/Pods-Runner.<config>.xcconfig"
    #include "Generated.xcconfig"

## Восстановление после flutter clean / pub cache repair

### 1. Скачать prebuilt .a (если native/build/iphoneos/bin/ пустой)
Dart setup падает с HandshakeException — используем curl:

    cd /tmp
    curl -fSL --retry 3 -o /tmp/rive_native_artifacts_ios.zip \
      "https://rive-flutter-artifacts.rive.app/rive_native_versions/0.1.11%2B3/rive_native_artifacts_ios.zip"

    DEST="$HOME/.pub-cache/hosted/pub.dev/rive_native-0.1.11/native/build/iphoneos/bin"
    mkdir -p "$DEST"
    unzip -o /tmp/rive_native_artifacts_ios.zip -d "$DEST"

### 2. Наложить podspec-патч
    cp scripts/rive_native.podspec.patched \
       ~/.pub-cache/hosted/pub.dev/rive_native-0.1.11/ios/rive_native.podspec
    ruby -c ~/.pub-cache/hosted/pub.dev/rive_native-0.1.11/ios/rive_native.podspec
    touch ~/.pub-cache/hosted/pub.dev/rive_native-0.1.11/ios/rive_marker_ios_setup_complete

### 3. Пересобрать Pods
    cd ios && rm -rf Pods Podfile.lock build && pod install && cd ..

### 4. Сборка
    flutter build ipa --release --no-codesign
    flutter build ios --simulator --debug

## Когда обновлять
При апгрейде rive_native — проверить upstream (issue про platform 7 в emulator/,
условия [sdk=iphonesimulator*] в CocoaPods). Если починили — удалить патч.
