# Flutter
-keep class io.flutter.** { *; }
-dontwarn io.flutter.embedding.**

# flutter_local_notifications — conserver les receivers de notifications planifiées
-keep class com.dexterous.** { *; }

# Google Play Core / Asset Delivery
-keep class com.google.android.play.core.** { *; }
-dontwarn com.google.android.play.core.**

# Google Tasks
-keep class com.google.android.gms.tasks.** { *; }
-dontwarn com.google.android.gms.tasks.**

# Annotations Google
-dontwarn com.google.android.gms.common.annotation.**
-dontwarn com.google.android.gms.common.annotation.NoNullnessRewrite
