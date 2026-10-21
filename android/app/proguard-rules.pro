# shared_preferences_android 2.5.0 calls its Kotlin API through JNI (Pigeon JNI) and ships no keep rules.
# JNI looks classes and methods up by name, so R8 must keep the plugin's classes and the Kotlin types its Dart
# bindings name (lib/src/messages.g.dart there). Without them the release app stops on a white screen at start-up.
-keep class io.flutter.plugins.sharedpreferences.** { *; }
-keep class kotlin.coroutines.** { *; }
-keep class kotlin.Unit { *; }
-keep class kotlin.Result { *; }
-keep class kotlin.Result$Failure { *; }
