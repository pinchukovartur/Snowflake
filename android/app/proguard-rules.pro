# R8 rules for the AppGallery build (branch huawei), as in Excellence.
#
# The HMS SDK refers to classes that are not in the package: HiAnalytics,
# EMUI system APIs and the full payment SDK. On the device they come from
# HMS Core, if at all; R8 doesn't know that and stops with "Missing class".
# Huawei ships no rules of its own.
-dontwarn com.huawei.hianalytics.**
-dontwarn com.huawei.libcore.io.**
-dontwarn com.huawei.android.**
-dontwarn com.huawei.hms.iapfull.**
-dontwarn org.bouncycastle.**

# The SDK calls its own classes by name through reflection: renaming them
# breaks it silently, on the device.
-keep class com.huawei.hms.** { *; }
-keep class com.huawei.agconnect.** { *; }
-keep interface com.huawei.hms.** { *; }

# Google Play services are excluded from this build (see build.gradle.kts).
# Unity Ads only uses GMS Cronet when it is there and falls back to its own
# HTTP client otherwise.
-dontwarn com.google.android.gms.**
