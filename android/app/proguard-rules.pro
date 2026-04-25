## Flutter-specific rules
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.**  { *; }
-keep class io.flutter.util.**  { *; }
-keep class io.flutter.view.**  { *; }
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }

## Hive
-keep class * extends com.google.protobuf.GeneratedMessageLite { *; }

## flutter_secure_storage
-keep class com.it_nomads.fluttersecurestorage.** { *; }

-keep class com.google.android.play.core.** { *; }
-dontwarn com.google.android.play.core.**
-dontwarn io.flutter.embedding.**
