plugins {
    id("com.android.application")
    id("kotlin-android")
    // Le plugin Flutter doit être après Android et Kotlin
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.example.quran"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }

    kotlinOptions {
        // Correction de l'erreur jvmTarget
        jvmTarget = "11"
    }

    defaultConfig {
        applicationId = "com.example.quran"
        minSdk = flutter.minSdkVersion // On force 21 pour la compatibilité avec just_audio
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    // Bloc de sécurité pour les conflits de fichiers
    packaging {
        resources {
            excludes += "/META-INF/{AL2.0,LGPL2.1}"
        }
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("debug")
            // Correction des erreurs : on ajoute "is" devant
            isMinifyEnabled = false
            isShrinkResources = false
        }
    }
}
flutter {
    source = "../.."
}
