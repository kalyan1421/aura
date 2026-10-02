# R8 keep rules for the release build (docs/setup/android-release-signing.md).
#
# WorkManager (a direct dependency of the home-screen widget, F11) opens its own Room database by
# reflection: Room looks up WorkDatabase_Impl and calls its no-argument constructor. R8 strips that
# constructor in a release build, so the app died at launch, before any Aura code ran:
#   NoSuchMethodException: androidx.work.impl.WorkDatabase_Impl.<init> []
# Found by running the release build on an emulator; debug builds don't shrink, so they never showed it.
-keep class androidx.work.impl.WorkDatabase_Impl { <init>(); }
-keep class * extends androidx.room.RoomDatabase { <init>(); }

# flutter_local_notifications (daily reminders, capsule unlock pushes) keeps scheduled notifications as
# JSON read back with Gson by reflection, and ships no rules of its own. Without these, R8 renames its
# model fields and strips generic type info, so a scheduled notification breaks in release builds only
# ("Missing type parameter"). These are the rules from the plugin's README.
-keep class com.dexterous.flutterlocalnotifications.models.** { *; }
-keep class com.google.gson.reflect.TypeToken { *; }
-keep class * extends com.google.gson.reflect.TypeToken
-keepattributes Signature, *Annotation*
