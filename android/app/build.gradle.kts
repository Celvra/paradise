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
    // permission_handler_android 14.1 references Manifest.permission
    // ACCESS_LOCAL_NETWORK and VERSION_CODES.CINNAMON_BUN, which the android-36
    // platform jars do not ship; they first exist in API 37 (Cinnamon Bun)
    compileSdk = 37
    // Pinned rather than taken from flutter.ndkVersion. The PTY JNI needs a
    // CMake that knows posix_openpt and that has been true since 22, and an
    // unpinned NDK is how a toolchain bump turns into a build failure on a
    // machine nobody is watching.
    ndkVersion = "28.2.13676358"

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

        // Flutter owns the APK's ABI list, including under --split-per-abi, so
        // this only has to agree with it rather than drive it.
        externalNativeBuild {
            cmake {
                abiFilters += listOf("armeabi-v7a", "arm64-v8a", "x86_64")
            }
        }
    }

    externalNativeBuild {
        cmake {
            path = file("src/main/cpp/CMakeLists.txt")
        }
    }

    packaging {
        jniLibs {
            // Load bearing, not a preference. With the default the .so files
            // stay compressed inside the APK and there is no file on disk to
            // execve, so proot cannot start at all.
            useLegacyPackaging = true
        }
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

val requiredWorkspaceLibs = listOf(
    "armeabi-v7a/libproot_exec.so",
    "armeabi-v7a/libproot_loader.so",
    "armeabi-v7a/libtalloc.so",
    "armeabi-v7a/libandroid-shmem.so",
    "arm64-v8a/libproot_exec.so",
    "arm64-v8a/libproot_loader.so",
    "arm64-v8a/libtalloc.so",
    "arm64-v8a/libandroid-shmem.so",
    "x86_64/libproot_exec.so",
    "x86_64/libproot_loader.so",
    "x86_64/libtalloc.so",
    "x86_64/libandroid-shmem.so",
)

dependencies {
    // XZInputStream for RootfsExtractor. Debian rootfs images are tar.xz and
    // java.util.zip has no xz, so without this a Debian install cannot unpack.
    implementation("org.tukaani:xz:1.10")

    // Required by isCoreLibraryDesugaringEnabled above. 2.1.4 is the version that
    // works with AGP 9.x; the 1.2.2 that flutter_local_notifications pins in its own
    // module is not supported by this Gradle/AGP generation.
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}

/**
 * Fetches proot and its shared library dependencies into jniLibs.
 *
 * The binaries are gitignored: they are large, they come from a third party
 * pool that rolls its versions, and checking in a binary nobody reviews is how
 * a supply chain problem becomes permanent. The sha256 of every file is in
 * tool/proot_checksums.txt and the script refuses to finish on a mismatch.
 */
val fetchWorkspaceLibs = tasks.register<Exec>("fetchWorkspaceLibs") {
    workingDir = rootProject.projectDir
    // absolute: the repo root is one above the Gradle root, and a relative
    // path would resolve against workingDir, which is how a fresh checkout
    // (CI) died with 127 while a tree that already had the .so files built fine
    // Forward slashes: Git Bash on Windows swallows backslashes from native
    // callers (D:\a\b turns into D:ab), which kills the script path there.
    // Resolve bash from PATH ourselves: when WSL is enabled, Windows places a
    // bash.exe stub in System32 that CreateProcess prefers over every real
    // shell on PATH, and that stub cannot see host paths at all.
    val pathExt = if (org.gradle.internal.os.OperatingSystem.current().isWindows) ".exe" else ""
    val bash = System.getenv("PATH").orEmpty().split(File.pathSeparatorChar)
        .asSequence()
        .map { File(it, "bash$pathExt") }
        .firstOrNull { it.isFile }
        ?.absolutePath
        ?.replace('\\', '/')
        ?: "bash"
    commandLine(bash, file("../../tool/fetch_proot.sh").absolutePath.replace('\\', '/'))
    // only when something is actually missing. The script itself is a network
    // round trip and a build should not need one.
    onlyIf {
        requiredWorkspaceLibs.any { rel ->
            val f = file("src/main/jniLibs/$rel")
            !f.exists() || f.length() == 0L
        }
    }
    outputs.upToDateWhen { false }
}

tasks.matching { it.name == "preBuild" }.configureEach {
    dependsOn(fetchWorkspaceLibs)
}
