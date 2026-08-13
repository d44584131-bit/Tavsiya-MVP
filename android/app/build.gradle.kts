plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Стабильный ключ подписи релизных сборок — нужен, чтобы обновления APK
// ставились поверх старой версии (а не требовали удаления приложения) и
// чтобы SHA-1 отпечаток, зарегистрированный в Google Cloud под нативный
// Google Sign-In, не менялся от сборки к сборке. Секреты приходят из CI
// (см. .github/workflows/build-apk.yml); при их отсутствии (локальная
// сборка) release тихо падает обратно на debug-ключ, как было раньше.
val releaseKeystorePath: String? = System.getenv("ANDROID_KEYSTORE_PATH")
val hasReleaseSigning =
    !releaseKeystorePath.isNullOrEmpty() && file(releaseKeystorePath).exists()

android {
    namespace = "com.example.tavsiya"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.example.tavsiya"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        create("release") {
            if (hasReleaseSigning) {
                storeFile = file(releaseKeystorePath!!)
                storePassword = System.getenv("KEYSTORE_PASSWORD")
                keyAlias = System.getenv("KEY_ALIAS")
                keyPassword = System.getenv("KEY_PASSWORD")
            }
        }
    }

    buildTypes {
        release {
            signingConfig = if (hasReleaseSigning) {
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
