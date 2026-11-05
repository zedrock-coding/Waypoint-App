import java.io.FileInputStream
import java.util.Properties

plugins {
    id("com.android.application")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
}

val envProperties = Properties()
val envCandidates = listOf(
    rootProject.file("../.env"),
    rootProject.file("../../.env"),
    file(".env")
)
for (cand in envCandidates) {
    if (cand.exists()) {
        cand.inputStream().use { envProperties.load(it) }
        break
    }
}

val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
if (keystorePropertiesFile.exists()) {
    keystorePropertiesFile.inputStream().use { keystoreProperties.load(it) }
}

android {
    namespace = "com.waypoint.app"
    compileSdk = 36
    ndkVersion = "28.2.13676358"

    compileOptions {
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = "17"
    }

    defaultConfig {
        applicationId = "com.waypoint.app"
        minSdk = flutter.minSdkVersion
        targetSdk = 34
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        create("release") {
            val ksPath = envProperties.getProperty("KEYSTORE_PATH")
                ?: keystoreProperties.getProperty("storeFile")
                ?: System.getenv("KEYSTORE_PATH")

            val candidateFiles = listOfNotNull(
                ksPath?.let { file(it) },
                ksPath?.let { rootProject.file(it) },
                ksPath?.let { rootProject.file("../$it") },
                file("upload-keystore.jks"),
                rootProject.file("upload-keystore.jks")
            )
            val resolvedStoreFile = candidateFiles.firstOrNull { it.exists() }

            if (resolvedStoreFile != null && resolvedStoreFile.exists()) {
                storeFile = resolvedStoreFile
                storePassword = envProperties.getProperty("KEYSTORE_PASSWORD")
                    ?: keystoreProperties.getProperty("storePassword")
                    ?: System.getenv("KEYSTORE_PASSWORD")
                keyAlias = envProperties.getProperty("KEY_ALIAS")
                    ?: keystoreProperties.getProperty("keyAlias")
                    ?: System.getenv("KEY_ALIAS")
                keyPassword = envProperties.getProperty("KEY_PASSWORD")
                    ?: keystoreProperties.getProperty("keyPassword")
                    ?: System.getenv("KEY_PASSWORD")
                enableV1Signing = true
                enableV2Signing = true
                enableV3Signing = true
                enableV4Signing = true
            }
        }
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("release")
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
        }
    }

    applicationVariants.all {
        outputs.all {
            val output = this as? com.android.build.gradle.internal.api.BaseVariantOutputImpl
            val vName = versionName ?: "0.4.1"
            output?.outputFileName = "waypoint-v${vName}.apk"
        }
    }
}

tasks.configureEach {
    if (name == "assembleRelease") {
        doLast {
            val flutterApkDir = layout.buildDirectory.dir("outputs/flutter-apk").get().asFile
            val defaultApk = File(flutterApkDir, "app-release.apk")
            val vName = android.defaultConfig.versionName ?: "0.4.1"
            if (defaultApk.exists()) {
                val versionedApk = File(flutterApkDir, "waypoint-v$vName.apk")
                defaultApk.copyTo(versionedApk, overwrite = true)
            }
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.0.4")
}
