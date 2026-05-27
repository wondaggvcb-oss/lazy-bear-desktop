# Flutter 相关
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }

# Glide
-keep public class * implements com.bumptech.glide.module.GlideModule
-keep class com.bumptech.glide.** { *; }

# Kotlin
-keep class kotlin.** { *; }

# Bear 自身
-keep class com.example.bear.** { *; }

# Play Store deferred components — not used, suppress R8 warnings
-dontwarn com.google.android.play.core.**
