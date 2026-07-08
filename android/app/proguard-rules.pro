# flutter_local_notifications deserializes launch details with Gson at
# initialize() — R8's default shrinking strips the generic signatures Gson
# needs and the app dies in main() before the first frame on RELEASE builds
# only ("Missing type parameter", #86). Keep rules per the plugin's docs.
-keep class com.dexterous.flutterlocalnotifications.** { *; }
-keepattributes Signature
-keepattributes *Annotation*
-keep class com.google.gson.reflect.TypeToken { *; }
-keep class * extends com.google.gson.reflect.TypeToken
