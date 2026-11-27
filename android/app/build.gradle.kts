import java.util.Properties

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Release signing: android/key.properties (not in git) points to the keystore in ../app_keys/Snowflake.
// Branch huawei: AppGallery has its own key, app_keys/Snowflake/huawei.jks
// (see huawei.properties next to it), as in Excellence. App Signing is
// mandatory for an AAB, and AGC keeps that key (Method 2, sign.zip); the
// Play key is the one Play updates come from and stays out of a second store.
val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
val huaweiPropertiesFile = File("/Users/arturpincukov/Documents/PinchApp/app_keys/Snowflake/huawei.properties")
if (huaweiPropertiesFile.exists()) {
    huaweiPropertiesFile.inputStream().use { keystoreProperties.load(it) }
} else if (keystorePropertiesFile.exists()) {
    keystorePropertiesFile.inputStream().use { keystoreProperties.load(it) }
}
val hasReleaseKey = huaweiPropertiesFile.exists() || keystorePropertiesFile.exists()

android {
    namespace = "com.Pinchukov.Snowflake"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.Pinchukov.Snowflake"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        create("release") {
            if (hasReleaseKey) {
                keyAlias = keystoreProperties["keyAlias"] as String
                keyPassword = keystoreProperties["keyPassword"] as String
                storeFile = keystoreProperties["storeFile"]?.let { file(it) }
                storePassword = keystoreProperties["storePassword"] as String
            }
        }
    }

    buildTypes {
        release {
            signingConfig = if (hasReleaseKey) {
                signingConfigs.getByName("release")
            } else {
                signingConfigs.getByName("debug")
            }
            // Branch huawei: R8 rules for the HMS IAP SDK (see the file).
            proguardFiles(getDefaultProguardFile("proguard-android-optimize.txt"), "proguard-rules.pro")
            // Branch huawei: no native debug symbols in the AAB. The AppGallery
            // validator rejects bundles that carry them without a clear error
            // (as in Excellence), and there is no crash reporting there to use
            // them. Flutter then prints "Failed to strip debug symbols": the
            // bundle is fine.
            ndk {
                debugSymbolLevel = "none"
            }
        }
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

flutter {
    source = "../.."
}

dependencies {
    // Branch huawei (AppGallery): no Google services. Huawei phones since
    // 2020 ship without GMS, so play-services-appset / -ads-identifier (which
    // main adds for LevelPlay) would be dead weight and a review question.
    // LevelPlay and Unity Ads work without them.
    // Unity Ads through LevelPlay (pulls in com.unity3d.ads:unity-ads 4.22.0).
    implementation("com.unity3d.ads-mediation:unityads-adapter:5.17.0")
    // Purchases: Huawei IAP instead of Play Billing (see HuaweiBilling.kt).
    implementation("com.huawei.hms:iap:6.16.6.305")
}

// Keep Google Play services out even when a library pulls them in.
configurations.all {
    exclude(group = "com.google.android.gms")
    exclude(group = "com.android.billingclient")
}
