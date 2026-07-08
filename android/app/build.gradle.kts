import java.util.Properties
import java.io.FileInputStream

// ============================================================
// Frozen Catch — Android app module
// ============================================================
// Package identity: com.frozcatch.frozencatch (bundleId agreed with
// the manager). Must match:
//   • lib/settings/identity.dart → FrostIdentity.bundleId
//   • android/app/src/main/kotlin/com/frozcatch/frozencatch/MainActivity.kt
//   • android/app/google-services.json → package_name  (when supplied)
// ============================================================

plugins {
    id("com.android.application")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
}

// Apply google-services only when the credentials file is present, so
// this project keeps building before Firebase is wired up.
if (file("google-services.json").exists()) {
    apply(plugin = "com.google.gms.google-services")
}

// Load release signing config from android/key.properties if it exists.
val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
val keystoreAvailable = keystorePropertiesFile.exists()
if (keystoreAvailable) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}

android {
    namespace = "com.frozcatch.frozencatch"

    // TZ §6: targetSdk=35, minSdk=30. compileSdk stays at 36 to keep
    // recent transitive plugin deps happy (see gray_part_pitfalls.md §2).
    compileSdk = 36
    ndkVersion = flutter.ndkVersion

    compileOptions {
        // flutter_local_notifications 19+ pulls in java.time.*, which the
        // desugaring library backports to API 30 and below.
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = "com.frozcatch.frozencatch"
        minSdk = 30
        targetSdk = 35
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        create("release") {
            if (keystoreAvailable) {
                keyAlias = keystoreProperties["keyAlias"] as String
                keyPassword = keystoreProperties["keyPassword"] as String
                storeFile = rootProject.file(keystoreProperties["storeFile"] as String)
                storePassword = keystoreProperties["storePassword"] as String
            }
        }
    }

    buildTypes {
        release {
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
            signingConfig = if (keystoreAvailable) {
                signingConfigs.getByName("release")
            } else {
                signingConfigs.getByName("debug")
            }
        }
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}

flutter {
    source = "../.."
}
