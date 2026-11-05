import java.util.Properties
import java.io.FileInputStream

plugins {
    id("com.android.application")
    // START: FlutterFire Configuration
    id("com.google.gms.google-services")
    id("com.google.firebase.crashlytics")
    // END: FlutterFire Configuration
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// release 簽章：CI 會產生 android/key.properties 與 keystore；本機若無則回退 debug。
val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}

android {
    namespace = "com.js.seek_player"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = "com.js.seek_player"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        // ffmpeg_kit_flutter_new 需 minSdk ≥ 24(歌詞自動對時的音訊壓縮)。
        minSdk = maxOf(flutter.minSdkVersion, 24)
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        // app 顯示名稱的 manifest placeholder;debug 覆寫為 app_name_dev。
        manifestPlaceholders["appLabel"] = "@string/app_name"
        // Google Analytics 收集開關(AndroidManifest meta-data);debug 覆寫為 false。
        manifestPlaceholders["analyticsEnabled"] = "true"
    }

    signingConfigs {
        create("release") {
            if (keystorePropertiesFile.exists()) {
                keyAlias = keystoreProperties["keyAlias"] as String
                keyPassword = keystoreProperties["keyPassword"] as String
                storeFile = (keystoreProperties["storeFile"] as String?)?.let { file(it) }
                storePassword = keystoreProperties["storePassword"] as String
            }
        }
    }

    buildTypes {
        debug {
            // 與 release 版分開的 applicationId,讓兩者可同時安裝在同一台裝置。
            // Firebase 已另註冊 com.js.seek_player.dev(見 google-services.json)。
            applicationIdSuffix = ".dev"
            versionNameSuffix = "-dev"
            manifestPlaceholders["appLabel"] = "@string/app_name_dev"
            // dev 與 prod 同一個 Firebase 專案,debug 不收集以免灌進 MAU。
            // 要用 DebugView 驗證事件時暫時改成 "true"。
            manifestPlaceholders["analyticsEnabled"] = "false"
        }
        release {
            // 有 key.properties（CI / 已設定簽章）時用 release，否則回退 debug 讓本機可建置。
            signingConfig = if (keystorePropertiesFile.exists()) {
                signingConfigs.getByName("release")
            } else {
                signingConfigs.getByName("debug")
            }
            // R8 會混淆 ffmpeg-kit 的 JNI 綁定類別,啟動時崩「Bad JNI version」。
            // 明確開啟 minify 並套用 proguard-rules.pro 的 keep 規則。
            isMinifyEnabled = true
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro",
            )
        }
    }
}

dependencies {
    // LyricsBackgroundService 的 NotificationCompat / ServiceCompat。
    implementation("androidx.core:core-ktx:1.13.1")
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

flutter {
    source = "../.."
}
