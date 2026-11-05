# Flutter ProGuard Rules
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.**  { *; }
-keep class io.flutter.util.**  { *; }
-keep class io.flutter.view.**  { *; }
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.**  { *; }

# Waypoint App & AppWidgets
-keep class com.waypoint.app.** { *; }

# HomeWidget Plugin
-keep class es.antonborri.home_widget.** { *; }

# Desugaring & Play Core Warnings
-dontwarn java.time.**
-dontwarn com.google.android.play.core.splitcompat.**
-dontwarn com.google.android.play.core.splitinstall.**
-dontwarn com.google.android.play.core.tasks.**
