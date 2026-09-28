# ============================================================
# FLUTTER ENGINE
# ============================================================
-keep class io.flutter.** { *; }
-keep class io.flutter.embedding.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.plugin.** { *; }

# Play Core — dontwarn (Flutter engine ссылается)
-dontwarn com.google.android.play.core.**

# ============================================================
# FIREBASE (рефлексия, GMS) — ОСТАВЛЯЕМ
# ============================================================
-keep class com.google.firebase.** { *; }
-keep class com.google.android.gms.** { *; }
-dontwarn com.google.firebase.**
-dontwarn com.google.android.gms.**

-keep class com.google.firebase.iid.** { *; }
-keep class com.google.firebase.messaging.** { *; }

# ============================================================
# KOTLIN — dontwarn, без -keep (R8 сам удалит)
# ============================================================
-dontwarn kotlin.**
-dontwarn kotlinx.**
-dontwarn org.jetbrains.annotations.**

# ============================================================
# OKHTTP / DIO / NETWORKING
# ============================================================
-dontwarn okhttp3.**
-dontwarn okio.**
-dontwarn retrofit2.**
-dontwarn javax.annotation.**
-dontwarn org.conscrypt.**
-dontwarn org.bouncycastle.**
-dontwarn org.openjsse.**
-dontwarn android.support.**

# ============================================================
# FLUTTER_INAPPWEBVIEW (WebView для оплаты)
# ============================================================
-keep class com.pichillilorenzo.flutter_inappwebview.** { *; }

# ============================================================
# FLUTTER_MAP / GEOLOCATOR / GEOCODING
# ============================================================
-keep class com.lyokone.location.** { *; }
-keep class com.baseflow.geolocator.** { *; }
-keep class com.baseflow.geocoding.** { *; }

# ============================================================
# LOCAL_AUTH (биометрия)
# ============================================================
-keep class androidx.biometric.** { *; }
-keep class com.google.android.gms.auth.** { *; }

# ============================================================
# IMAGE_PICKER
# ============================================================
-keep class com.imagepicker.** { *; }

# ============================================================
# IN_APP_REVIEW
# ============================================================
-keep class com.google.android.play.core.review.** { *; }

# ============================================================
# FLUTTER_LOCAL_NOTIFICATIONS
# ============================================================
-keep class com.dexterous.flutterlocalnotifications.** { *; }

# ============================================================
# АННОТАЦИИ / STACKTRACE
# ============================================================
-keepattributes *Annotation*
-keepattributes Signature
-keepattributes InnerClasses
-keepattributes EnclosingMethod
-keepattributes SourceFile,LineNumberTable
-renamesourcefileattribute SourceFile

# ============================================================
# PARCELABLE / ENUM / NATIVE
# ============================================================
-keepclassmembers class * implements android.os.Parcelable {
    static ** CREATOR;
}

-keepclassmembers enum * {
    public static **[] values();
    public static ** valueOf(java.lang.String);
}

-keepclasseswithmembernames class * {
    native <methods>;
}
