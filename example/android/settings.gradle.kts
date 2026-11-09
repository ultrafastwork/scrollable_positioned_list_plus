pluginManagement {
    val flutterSdkPath = run {
        val properties = java.util.Properties()
        val localPropertiesFile = file("local.properties")
        if (localPropertiesFile.exists()) {
            localPropertiesFile.inputStream().use { properties.load(it) }
        }
        var flutterSdkPath = properties.getProperty("flutter.sdk")
        if (flutterSdkPath == null) {
            // Fallback: check for FVM symlink in project root
            val fvmLink = file("../.fvm/flutter_sdk")
            if (fvmLink.exists()) {
                flutterSdkPath = fvmLink.canonicalPath
            }
        }
        if (flutterSdkPath == null) {
            // Fallback: check FVM default version
            val fvmDefault = file("${System.getProperty("user.home")}/fvm/default")
            if (fvmDefault.exists()) {
                flutterSdkPath = fvmDefault.canonicalPath
            }
        }
        require(flutterSdkPath != null) {
            "Flutter SDK not found. Checked: local.properties, .fvm/flutter_sdk, and ~/fvm/default"
        }
        flutterSdkPath
    }

    includeBuild("$flutterSdkPath/packages/flutter_tools/gradle")

    repositories {
        google()
        mavenCentral()
        gradlePluginPortal()
    }
}

plugins {
    id("dev.flutter.flutter-plugin-loader") version "1.0.0"
    id("com.android.application") version "8.12.0" apply false
    id("org.jetbrains.kotlin.android") version "2.4.10" apply false
}

include(":app")
