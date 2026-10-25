#!/bin/bash
# release_all.sh — полная release-сборка Beauty Rosha
# Использование: ~/release_all.sh [флаги]
#   --no-upload-ios          — не загружать IPA в App Store
#   --no-upload-android      — не загружать AAB в RuStore
#   --no-upload-googleplay   — не загружать AAB в Google Play
#   --no-upload              — не загружать ничего (только сборка)
#   --submit-ios-review      — фоновый watcher: ждёт TestFlight и отправляет на review
#   --skip-moderation        — RuStore: только черновик, без модерации
#   --gp-track=production    — Google Play track (internal/beta/alpha/production)

set -e
set -o pipefail

# ─── ПУТИ ───
PROJECT_DIR="/Users/iprosinaleksanlraleksandrovic/Documents/beauty_rosha"
cd "$PROJECT_DIR" || exit 1

SYMBOLS_DIR="build/symbols/$(date +%Y%m%d-%H%M%S)"

# ─── APP STORE CONNECT ───
APPLE_ID="commonweal@mail.ru"
KEYCHAIN_ITEM="AC_PASSWORD"

# App Store Connect API (для автоматизации review)
APPSTORE_KEY_ID="8826Z84MLX"
APPSTORE_ISSUER_ID="fdedcd9a-4b94-411f-985b-b2c78a45036b"
APPSTORE_KEY_FILE="$HOME/.appstoreconnect/private_keys/AuthKey_8826Z84MLX.p8"
APPSTORE_BUNDLE_ID="com.beautyrosha.beautyRosha"

# ─── RUSTORE ───
RUSTORE_KEY_ID="2351032794"
RUSTORE_KEY_FILE="$HOME/.rustore/private_key.pem"
RUSTORE_PACKAGE="com.beautyrosha.beauty_rosha"

# ─── GOOGLE PLAY ───
GOOGLEPLAY_SERVICE_ACCOUNT="$HOME/.googleplay/service-account.json"
GOOGLEPLAY_PACKAGE="com.beautyrosha.beauty_rosha"
GOOGLEPLAY_TRACK="production"

# ─── ФЛАГИ (по умолчанию) ───
UPLOAD_IOS=true
UPLOAD_ANDROID=true
UPLOAD_GOOGLEPLAY=true
SUBMIT_IOS_REVIEW=false
SKIP_MODERATION=false

for arg in "$@"; do
    case $arg in
        --no-upload-ios) UPLOAD_IOS=false ;;
        --no-upload-android) UPLOAD_ANDROID=false ;;
        --no-upload-googleplay) UPLOAD_GOOGLEPLAY=false ;;
        --no-upload) UPLOAD_IOS=false; UPLOAD_ANDROID=false; UPLOAD_GOOGLEPLAY=false ;;
        --submit-ios-review) SUBMIT_IOS_REVIEW=true ;;
        --skip-moderation) SKIP_MODERATION=true ;;
        --gp-track=*) GOOGLEPLAY_TRACK="${arg#*=}" ;;
    esac
done

echo "═══════════════════════════════════════════════════"
echo " 🚀 RELEASE BUILD"
echo "═══════════════════════════════════════════════════"
echo ""

VERSION=$(grep '^version:' pubspec.yaml | awk '{print $2}' | tr -d "'")
VERSION_NAME=$(echo "$VERSION" | cut -d'+' -f1)
VERSION_CODE=$(echo "$VERSION" | cut -d'+' -f2)

echo "📦 Версия: $VERSION"
echo "📤 iOS: $UPLOAD_IOS | iOS review: $SUBMIT_IOS_REVIEW"
echo "📤 RuStore: $UPLOAD_ANDROID | Skip moderation: $SKIP_MODERATION"
echo "📤 Google Play: $UPLOAD_GOOGLEPLAY | Track: $GOOGLEPLAY_TRACK"
echo ""

# ─── 1. Очистка ───
echo "🧹 1. Очистка..."
flutter clean
flutter pub get
echo ""

# ─── 2. Analyze ───
echo "🔍 2. Analyze..."
flutter analyze
echo ""

# ─── 3. Android APK (arm64) ───
echo "🔨 3. Android APK (arm64)..."
flutter build apk --release --target-platform android-arm64 --split-per-abi \
    --obfuscate --split-debug-info="$SYMBOLS_DIR/android" 2>&1 | tail -3

APK_FILE="build/app/outputs/flutter-apk/app-arm64-v8a-release.apk"
if [ ! -f "$APK_FILE" ]; then
    echo "❌ APK не собрался!"
    exit 1
fi
APK_SIZE=$(du -h "$APK_FILE" | cut -f1)
echo "✅ APK: $APK_SIZE"
echo ""

# ─── 4. Android AAB (arm64) ───
echo "🔨 4. Android AAB (arm64)..."
flutter build appbundle --release --target-platform android-arm64 \
    --obfuscate --split-debug-info="$SYMBOLS_DIR/android" 2>&1 | tail -3

AAB_FILE="build/app/outputs/bundle/release/app-release.aab"
if [ ! -f "$AAB_FILE" ]; then
    echo "❌ AAB не собрался!"
    exit 1
fi
AAB_SIZE=$(du -h "$AAB_FILE" | cut -f1)
echo "✅ AAB: $AAB_SIZE"
echo ""

# ─── 5. iOS IPA ───
echo "🔨 5. iOS IPA..."
IPA_FILE=""
if flutter build ipa --release --obfuscate \
    --split-debug-info="$SYMBOLS_DIR/ios" 2>&1 | tail -3 || true; then
    IPA_FILE=$(find build/ios/ipa -name "*.ipa" 2>/dev/null | head -1)
    if [ -n "$IPA_FILE" ]; then
        IPA_SIZE=$(du -h "$IPA_FILE" | cut -f1)
        echo "✅ IPA: $IPA_SIZE"
    else
        echo "⚠️  iOS IPA не собрался"
    fi
fi
echo ""

# ─── 6. Выгрузка APK на сервер ───
echo "📤 6. Выгрузка APK на сервер..."
if [ -f ~/.ssh/deploy_apk ]; then
    if scp -i ~/.ssh/deploy_apk "$APK_FILE" \
        commonu1@beget:/home/c/commonu1/razrabotka/public_html/downloads/beauty-rosha.apk; then
        echo "✅ APK выгружен: https://бьютироща.рф/downloads/beauty-rosha.apk"
    else
        echo "❌ Ошибка выгрузки APK"
    fi
else
    echo "⚠️  ~/.ssh/deploy_apk не найден — пропуск"
fi
echo ""

# ─── 7. RuStore ───
if [ "$UPLOAD_ANDROID" = true ]; then
    echo "📤 7. Загрузка в RuStore..."
    RUSTORE_ARGS="--key-id $RUSTORE_KEY_ID --key-file $RUSTORE_KEY_FILE --package $RUSTORE_PACKAGE --aab $AAB_FILE --version-name $VERSION_NAME"
    if [ "$SKIP_MODERATION" = true ]; then
        RUSTORE_ARGS="$RUSTORE_ARGS --skip-submit"
    fi
    RUSTORE_MAX_RETRIES=3
    RUSTORE_RETRY_DELAY=30
    RUSTORE_SUCCESS=false
    for attempt in $(seq 1 $RUSTORE_MAX_RETRIES); do
        if [ $attempt -gt 1 ]; then
            echo "RuStore: retry $attempt/$RUSTORE_MAX_RETRIES через ${RUSTORE_RETRY_DELAY}s..."
            sleep $RUSTORE_RETRY_DELAY
        fi
        if python3 ~/rustore_publish.py $RUSTORE_ARGS; then
            echo "RuStore OK (попытка $attempt)"
            RUSTORE_SUCCESS=true
            break
        else
            echo "RuStore: ошибка (попытка $attempt)"
        fi
    done
    if [ "$RUSTORE_SUCCESS" = false ]; then
        echo "RuStore — все попытки исчерпаны"
    fi
else
    echo "ℹ️  RuStore отключён (--no-upload-android)"
fi
echo ""

# ─── 8. Google Play ───
if [ "$UPLOAD_GOOGLEPLAY" = true ]; then
    echo "📤 8. Загрузка в Google Play (track: $GOOGLEPLAY_TRACK)..."

    # 🔥 Проверяем зависимости (Python 3.12+ блокирует pip install)
    if ! python3 -c "import googleapiclient" 2>/dev/null; then
        echo "📦 Установка зависимостей (google-api-python-client)..."
        pip3 install --user --break-system-packages google-api-python-client google-auth google-auth-httplib2 2>&1 | tail -3
    fi

    GP_MAX_RETRIES=3
    GP_RETRY_DELAY=30
    GP_SUCCESS=false
    for attempt in $(seq 1 $GP_MAX_RETRIES); do
        if [ $attempt -gt 1 ]; then
            echo "Google Play: retry $attempt/$GP_MAX_RETRIES через ${GP_RETRY_DELAY}s..."
            sleep $GP_RETRY_DELAY
        fi
        if python3 ~/googleplay_publish.py \
            --service-account "$GOOGLEPLAY_SERVICE_ACCOUNT" \
            --package "$GOOGLEPLAY_PACKAGE" \
            --aab "$AAB_FILE" \
            --track "$GOOGLEPLAY_TRACK" \
            --whats-new "Улучшения и исправления" \
            --status completed; then
            echo "Google Play OK (попытка $attempt)"
            GP_SUCCESS=true
            break
        else
            echo "Google Play: ошибка (попытка $attempt)"
        fi
    done
    if [ "$GP_SUCCESS" = false ]; then
        echo "Google Play — все попытки исчерпаны"
    fi
else
    echo "ℹ️  Google Play отключён (--no-upload-googleplay)"
fi
echo ""

# ─── 9. App Store Connect (загрузка IPA) ───
if [ "$UPLOAD_IOS" = true ] && [ -n "$IPA_FILE" ] && [ -f "$IPA_FILE" ]; then
    echo "📤 9. Загрузка IPA в App Store Connect..."
    if xcrun altool --upload-app \
        --type ios \
        --file "$IPA_FILE" \
        --apiKey "$APPSTORE_KEY_ID" \
        --apiIssuer "$APPSTORE_ISSUER_ID" 2>&1 | tail -10; then
        echo "✅ IPA загружен в App Store Connect"
        IOS_UPLOADED=true
    else
        echo "❌ Ошибка загрузки IPA"
        IOS_UPLOADED=false
    fi
else
    IOS_UPLOADED=false
    if [ "$UPLOAD_IOS" = false ]; then
        echo "ℹ️  App Store отключён (--no-upload-ios)"
    fi
fi
echo ""

# ─── 10. iOS Review (фоновый watcher) ───
if [ "$SUBMIT_IOS_REVIEW" = true ] && [ "$IOS_UPLOADED" = true ]; then
    echo "🚀 10. Запуск фонового watcher для iOS review..."
    echo "    ✅ Ждёт TestFlight (5-30 мин)"
    echo "    ✅ Создаёт версию в App Store Connect"
    echo "    ✅ Отправляет на review автоматически"
    echo ""

    WATCH_LOG="/tmp/appstore_watch_${VERSION_NAME}.log"

    # Запуск через nohup — отвязан от терминала
    nohup ~/appstore_watch.sh "$VERSION_NAME" --wait-minutes=120 \
        > "$WATCH_LOG" 2>&1 &
    WATCH_PID=$!

    echo "✅ Watcher запущен (PID: $WATCH_PID)"
    echo ""
    echo "📊 Прогресс:"
    echo "   tail -f $WATCH_LOG"
    echo ""
    echo "🛑 Остановить:"
    echo "   kill $WATCH_PID"
    echo ""
    echo "⚠️  Mac должен быть включён до завершения!"
    echo ""
fi

# ─── ИТОГ ───
echo "═══════════════════════════════════════════════════"
echo " ✅ СБОРКА ЗАВЕРШЕНА"
echo "═══════════════════════════════════════════════════"
echo ""
echo "📊 РЕЗУЛЬТАТЫ:"
echo "   APK (arm64):          $APK_SIZE"
echo "   AAB (arm64):          $AAB_SIZE"
[ -n "$IPA_FILE" ] && [ -f "$IPA_FILE" ] && echo "   IPA (iOS):            $IPA_SIZE"
echo ""
echo "📤 Выгрузки:"
echo "   APK на сервер:        https://бьютироща.рф/downloads/beauty-rosha.apk"
[ "$UPLOAD_ANDROID" = true ] && echo "   RuStore:              ✅"
[ "$UPLOAD_GOOGLEPLAY" = true ] && echo "   Google Play:          ✅ ($GOOGLEPLAY_TRACK)"
[ "$UPLOAD_IOS" = true ] && [ "$IOS_UPLOADED" = true ] && echo "   App Store Connect:    ✅"
[ "$SUBMIT_IOS_REVIEW" = true ] && [ "$IOS_UPLOADED" = true ] && echo "   iOS review:           🔄 watcher (PID: $WATCH_PID)"
echo ""
echo "🔑 Символы для крэшей: $SYMBOLS_DIR"
echo "   ⚠️  СОХРАНИ — нужны для Firebase Crashlytics!"
echo ""
echo "📁 Пути:"
echo "   APK: $APK_FILE"
echo "   AAB: $AAB_FILE"
[ -n "$IPA_FILE" ] && [ -f "$IPA_FILE" ] && echo "   IPA: $IPA_FILE"
echo "═══════════════════════════════════════════════════"