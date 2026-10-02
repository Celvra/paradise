import java.io.FileInputStream
import java.util.Properties

// Release signing material. The keystore and this file are both gitignored, so a
// clone has neither and falls back to the debug signing config below, which
// keeps `flutter run --release` working for a contributor who only wants to try
// the build. CI writes the real thing from repository secrets before building.
val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "fan.x0.para"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
        // flutter_local_notifications schedules via java.time, which needs desugaring
        // to run on older Android. Without this, :app:checkDebugAarMetadata fails with
        // "Dependency ':flutter_local_notifications' requires core library desugaring".
        isCoreLibraryDesugaringEnabled = true
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "fan.x0.para"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        // Uses the version code from pubspec.yaml. When using split APKs, 1000 * ABI_VERSION
        // is added automatically by Flutter. (https://developer.android.com/studio/build/configure-apk-splits#configure-APK-versions)
        // You can force using the value of versionCode by specifying the `-P force-version-code-ignoring-abi=true`
        // flag during build.
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        create("release") {
            if (keystorePropertiesFile.exists()) {
                keyAlias = keystoreProperties["keyAlias"] as String
                keyPassword = keystoreProperties["keyPassword"] as String
                storePassword = keystoreProperties["storePassword"] as String
                // resolved against this module, so storeFile is relative to
                // android/app rather than to wherever key.properties lives
                storeFile = file(keystoreProperties["storeFile"] as String)
            }
            // v2 and v3 are what actually ship. apksigner on a real build
            // reports v2 true, v3 true, v1 false, and that is the correct
            // outcome rather than a setting that failed: JAR signing only exists
            // for Android 6 and below, this app's minSdk is 24, so no device
            // that can install it reads a v1 signature. enableV1Signing is kept
            // so lowering minSdk does not silently ship an unverifiable package,
            // but it is a no-op at 24.
            //
            // v3 is the reason this is worth stating rather than trusting the
            // default: it is what allows a compromised key to be replaced
            // without publishing under a new package id.
            enableV1Signing = true
            enableV2Signing = true
            enableV3Signing = true
        }
    }

    buildTypes {
        release {
            signingConfig = if (keystorePropertiesFile.exists()) {
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

flutter {
    source = "../.."
}

dependencies {
    // Required by isCoreLibraryDesugaringEnabled above. 2.1.4 is the version that
    // works with AGP 9.x; the 1.2.2 that flutter_local_notifications pins in its own
    // module is not supported by this Gradle/AGP generation.
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}
