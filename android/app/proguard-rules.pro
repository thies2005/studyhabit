# Preserve generic signatures (crucial for Gson TypeToken)
-keepattributes Signature, *Annotation*, InnerClasses, EnclosingMethod

# Keep Gson's TypeToken class and its subclasses
-keep class com.google.gson.reflect.TypeToken { *; }
-keep class * extends com.google.gson.reflect.TypeToken

# Keep flutter_local_notifications classes
-keep class com.dexterous.flutterlocalnotifications.** { *; }
