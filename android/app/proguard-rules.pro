# Room SQLite
-keepclassmembers class * extends androidx.room.RoomDatabase {
    <init>();
}
-keep class * extends androidx.room.RoomDatabase
-dontwarn androidx.room.paging.**

# Kotlinx Serialization
-keepattributes *Annotation*,InnerClasses
-dontnote kotlinx.serialization.SerializationKt
-keepclassmembers class * {
    *** Companion;
}
-keepclasseswithmembers class * {
    kotlinx.serialization.KSerializer serializer(...);
}

# Retrofit & OkHttp
-dontwarn okhttp3.**
-dontwarn okio.**
-dontwarn retrofit2.**
-keepattributes Signature
-keepattributes Exceptions

# Data classes and entities
-keep class de.schuelken.studyhabit.core.database.** { *; }
-keep class de.schuelken.studyhabit.core.network.** { *; }
-keep class de.schuelken.studyhabit.core.model.** { *; }

# Security Crypto / Tink ErrorProne annotations
-dontwarn com.google.errorprone.annotations.**

