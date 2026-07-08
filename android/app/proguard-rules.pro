# ============================================================
# Frozen Catch — release ProGuard / R8 rules
# ============================================================
# Keep the classes that pluggable libraries reflect on at runtime
# (Flutter engine, Play Services, AppsFlyer, Firebase). Rules
# tuned to R8 defaults; do not add blanket -keep everywhere.
# ============================================================

# Flutter — the engine reflects on generated plugin classes.
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }
-keep class io.flutter.plugin.** { *; }
-dontwarn io.flutter.**

# AppsFlyer + Google GAID
-keep class com.appsflyer.** { *; }
-keep class com.google.android.gms.** { *; }
-dontwarn com.appsflyer.**
-dontwarn com.google.android.gms.**

# Firebase + AppCheck + Messaging
-keep class com.google.firebase.** { *; }
-keep class com.google.android.datatransport.** { *; }
-dontwarn com.google.firebase.**

# Kotlin coroutines internals (occasionally stripped by R8)
-keepnames class kotlinx.** { *; }
-dontwarn kotlinx.coroutines.**

# core-library-desugar-jdk-libs
-dontwarn java.time.**
-dontwarn sun.misc.Unsafe
