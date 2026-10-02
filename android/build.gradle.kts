// The default Maven hosts are unreliable from this network: Gradle dies mid-download
// with "(bad_record_mac) Tag mismatch". audioplayers_android declares its own
// buildscript classpath (AGP 7.3.1 + Kotlin 1.7.10) that was never in the local cache,
// so it has to be fetched. These mirrors are prepended, so plugin buildscripts resolve
// from them before falling back to google()/mavenCentral() below.
val mavenMirrors = listOf(
    "https://maven.aliyun.com/repository/google",
    "https://maven.aliyun.com/repository/gradle-plugin",
    "https://maven.aliyun.com/repository/public",
)

allprojects {
    buildscript {
        repositories {
            mavenMirrors.forEach { m -> maven { setUrl(m) } }
        }
    }
    repositories {
        mavenMirrors.forEach { m -> maven { setUrl(m) } }
        google()
        mavenCentral()
    }
}

// file_picker 8.x pins compileSdk 34 but pulls flutter_plugin_android_lifecycle
// which needs 36, so every plugin module is lifted to the same level
subprojects {
    afterEvaluate {
        val ext = extensions.findByName("android")
        if (ext is com.android.build.gradle.BaseExtension) {
            @Suppress("DEPRECATION")
            ext.compileSdkVersion(36)
        }
    }
}

val newBuildDir: Directory =
    rootProject.layout.buildDirectory
        .dir("../../build")
        .get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)
}
subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
