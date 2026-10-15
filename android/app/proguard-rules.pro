# Flutter ProGuard Rules for Size Reduction and Code Shrinking

# Keep Flutter Engine and framework bindings
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }

# Keep native methods
-keepclasseswithmembernames class * {
    native <methods>;
}

# Keep Attributes
-keepattributes *Annotation*,Signature,InnerClasses,EnclosingMethod

# Prevent warnings from third-party plugins
-dontwarn io.flutter.**
-dontwarn com.google.**
