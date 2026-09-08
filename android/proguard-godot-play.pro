# Godot JNI / activity
-keep class org.godotengine.** { *; }
-keep class com.godot.** { *; }
-keepclasseswithmembernames class * {
    native <methods>;
}

-dontwarn org.godotengine.**
