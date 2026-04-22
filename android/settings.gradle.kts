pluginManagement {
    val flutterSdkPath =
        run {
            val properties = java.util.Properties()
            file("local.properties").inputStream().use { properties.load(it) }
            val flutterSdkPath = properties.getProperty("flutter.sdk")
            require(flutterSdkPath != null) { "flutter.sdk not set in local.properties" }
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
    id("com.android.application") version "8.11.1" apply false
    id("org.jetbrains.kotlin.android") version "2.2.20" apply false
}

include(":app")

// Patch: fix older Flutter plugins (flutter_qiblah, asset_delivery, …) for modern AGP + Kotlin 2.x
gradle.beforeProject {
    afterEvaluate {
        val android = extensions.findByName("android") as? com.android.build.gradle.BaseExtension
            ?: return@afterEvaluate
        // 1. Inject missing namespace (flutter_qiblah 2.x)
        if (android.namespace == null) {
            android.namespace = group.toString()
        }
        // 2. Align Java target to 11 so it matches the Kotlin target
        android.compileOptions.sourceCompatibility = JavaVersion.VERSION_11
        android.compileOptions.targetCompatibility = JavaVersion.VERSION_11
    }
}
