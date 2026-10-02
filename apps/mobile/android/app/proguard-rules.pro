# R8 keep rules for the release build (docs/setup/android-release-signing.md).
#
# WorkManager (a direct dependency of the home-screen widget, F11) opens its own Room database by
# reflection: Room looks up WorkDatabase_Impl and calls its no-argument constructor. R8 strips that
# constructor in a release build, so the app died at launch, before any Aura code ran:
#   NoSuchMethodException: androidx.work.impl.WorkDatabase_Impl.<init> []
# Found by running the release build on an emulator; debug builds don't shrink, so they never showed it.
-keep class androidx.work.impl.WorkDatabase_Impl { <init>(); }
-keep class * extends androidx.room.RoomDatabase { <init>(); }
