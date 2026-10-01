import java.util.Properties
import java.io.FileInputStream

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
    // Processes google-services.json at build time — needed for firebase_core/firebase_messaging
    // (push notifications). Those Flutter plugins bring their own native Firebase dependencies, so no
    // extra `implementation("com.google.firebase:...")` lines are needed here.
    id("com.google.gms.google-services")
}

// Read MAPS_API_KEY from local.properties (gitignored) — never hardcode the key in a checked-in file.
// Injected into AndroidManifest.xml below via manifestPlaceholders.
val localProperties = Properties()
val localPropertiesFile = rootProject.file("local.properties")
if (localPropertiesFile.exists()) {
    FileInputStream(localPropertiesFile).use { localProperties.load(it) }
}
val mapsApiKey: String = localProperties.getProperty("MAPS_API_KEY") ?: ""

// Release signing: android/key.properties (gitignored, with the .jks keystore kept OUTSIDE the repo) holds
// the Play upload key. Without it the release build falls back to the debug key so `flutter run --release`
// still works locally — but Google Play rejects a debug-signed bundle, so a Play build needs key.properties.
val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
val hasReleaseKeystore = keystorePropertiesFile.exists()
if (hasReleaseKeystore) {
    FileInputStream(keystorePropertiesFile).use { keystoreProperties.load(it) }
} else {
    logger.warn("WARNING: android/key.properties not found — release build will be signed with the DEBUG key (not uploadable to Play).")
}

android {
    namespace = "com.jmminfotech.jmm_employee_app"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
        // flutter_local_notifications requires this (java.time / java8+ APIs backported to older
        // Android versions) — without it, checkDebugAarMetadata fails the build outright.
        isCoreLibraryDesugaringEnabled = true
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        // Must equal the existing Play listing's package (com.jmm_infotech) so this build replaces that app.
        // `namespace` above stays com.jmminfotech.jmm_employee_app (code package) — the two may differ.
        applicationId = "com.jmm_infotech"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        manifestPlaceholders["mapsApiKey"] = mapsApiKey
    }

    signingConfigs {
        if (hasReleaseKeystore) {
            create("release") {
                keyAlias = keystoreProperties.getProperty("keyAlias")
                keyPassword = keystoreProperties.getProperty("keyPassword")
                storeFile = file(keystoreProperties.getProperty("storeFile"))
                storePassword = keystoreProperties.getProperty("storePassword")
            }
        }
    }

    buildTypes {
        release {
            signingConfig = if (hasReleaseKeystore) signingConfigs.getByName("release") else signingConfigs.getByName("debug")
        }
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

dependencies {
    // Required by isCoreLibraryDesugaringEnabled above.
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}

flutter {
    source = "../.."
}
