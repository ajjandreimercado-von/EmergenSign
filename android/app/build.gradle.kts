plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.emergensign.emergensign"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = "com.emergensign.emergensign"
        // Android 8.0 Oreo (API 26) minimum — required for MediaPipe Tasks Vision
        minSdk = 26
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    // Prevent the .task model file from being compressed in the APK.
    // MediaPipe requires direct memory-mapping of the model, which breaks
    // if the file is zlib-compressed inside the APK archive.
    aaptOptions {
        noCompress += listOf("task")
    }

    buildTypes {
        release {
            // TODO: Add your own signing config for the release build.
            signingConfig = signingConfigs.getByName("debug")
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
    implementation("androidx.concurrent:concurrent-futures:1.1.0")

    // MediaPipe Tasks Vision — includes HandLandmarker, fully on-device (no network).
    // Version 0.10.14 targets Android 8.0+ (API 26+).
    implementation("com.google.mediapipe:tasks-vision:0.10.14")
}
