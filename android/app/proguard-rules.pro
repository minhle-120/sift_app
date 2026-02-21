# LiteRT LM SDK
-keep class com.google.ai.edge.litertlm.** { *; }

# TFLite Core
-keep class org.tensorflow.lite.** { *; }

# Keep native methods and their classes
-keepclasseswithmembernames class * {
    native <methods>;
}

# Keep Flutter wrapper and plugins
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.embedding.** { *; }
-keep class io.flutter.plugins.** { *; }

# Flutter Play Store Split classes (suppress warnings if not using deferred components)
-dontwarn com.google.android.play.core.**
-dontwarn search.Search**

# Suppress warnings for javax.lang.model (referenced by AutoValue/MediaPipe dependencies)
-dontwarn javax.lang.model.**
-dontwarn autovalue.shaded.**

# Flogger (used by MediaPipe)
-keep class com.google.common.flogger.** { *; }
-dontwarn com.google.common.flogger.**
-keepclassmembers class * {
    static com.google.common.flogger.FluentLogger *;
}

# Protobuf
-keep class com.google.protobuf.** { *; }
-dontwarn com.google.protobuf.**

# Keep Protobuf messages and their builders
-keep class * extends com.google.protobuf.GeneratedMessageLite { *; }
-keep class * extends com.google.protobuf.MessageLite { *; }
-keep interface * extends com.google.protobuf.MessageLiteOrBuilder { *; }

# MediaPipe
-keep class com.google.mediapipe.** { *; }
-keep interface com.google.mediapipe.** { *; }
-dontwarn com.google.mediapipe.**
-dontnote com.google.mediapipe.**

# Critical for stack trace based class loading in MediaPipe/Flogger
-keepattributes Signature,Lines,SourceFile,EnclosingMethod,InnerClasses,RuntimeVisibleAnnotations,*Annotation*
