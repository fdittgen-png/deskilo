import com.android.build.gradle.internal.api.ApkVariantOutputImpl
import java.io.FileInputStream
import java.util.Properties

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Release signing (docs/guides/RELEASING.md): CI decodes the upload keystore
// from secrets and writes android/key.properties; local builds without it
// fall back to debug signing so `flutter run --release` keeps working.
val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}

android {
    namespace = "de.deskilo.app"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
        // flutter_local_notifications scheduled notifications need desugaring
        isCoreLibraryDesugaringEnabled = true
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        applicationId = "de.deskilo.app"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    // #787 — AGP embeds a Google-signed blob of the dependency tree in the
    // APK's signing block. F-Droid's `check apk` scanner refuses it ("found
    // extra signing block 'Dependency metadata'"), and it is unreadable to
    // anyone but Google, so it has no business in a reproducible APK. The
    // BUNDLE keeps it: that is the copy Play reads for its vulnerability
    // warnings, and Play never sees the APK.
    dependenciesInfo {
        includeInApk = false
        includeInBundle = true
    }

    signingConfigs {
        if (keystorePropertiesFile.exists()) {
            create("release") {
                keyAlias = keystoreProperties["keyAlias"] as String
                keyPassword = keystoreProperties["keyPassword"] as String
                storeFile = file(keystoreProperties["storeFile"] as String)
                storePassword = keystoreProperties["storePassword"] as String
                // PKCS12 upload keystore (generated with OpenSSL)
                storeType = keystoreProperties.getProperty("storeType", "PKCS12")
            }
        }
    }

    buildTypes {
        release {
            signingConfig = if (keystorePropertiesFile.exists()) {
                signingConfigs.getByName("release")
            } else {
                signingConfigs.getByName("debug")
            }
            // #86: keep rules for flutter_local_notifications' Gson usage —
            // without them release builds crash before the first frame.
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro",
            )
        }
    }
}

// #795 — per-ABI versionCodes for F-Droid's split builds, in the scheme
// their reviewer prescribed on fdroid/fdroiddata!47409.
//
// F-Droid publishes one APK per ABI and always installs the HIGHEST
// version code a device can take, keeping only the newest codes in the
// main repo. So the ABI digit has to sit in the LOWEST position and the
// order must be armeabi-v7a < arm64-v8a < x86_64 — otherwise a phone
// that could run arm64 is offered the 32-bit build forever, and an
// older release's x86_64 code could outrank a newer release's arm one.
//
// versionCode * 10 + abi, matching `VercodeOperation` in the recipe.
// Harmless to the store trains: they build a universal APK/AAB, which
// has no ABI filter and so is never rewritten here.
val abiCodes = mapOf("armeabi-v7a" to 1, "arm64-v8a" to 2, "x86_64" to 3)
android.applicationVariants.configureEach {
    val variant = this
    variant.outputs.forEach { output ->
        val abiVersionCode =
            abiCodes[output.filters.find { it.filterType == "ABI" }?.identifier]
        if (abiVersionCode != null) {
            (output as ApkVariantOutputImpl).versionCodeOverride =
                variant.versionCode * 10 + abiVersionCode
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}
