import java.net.URI
import java.util.Base64

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Firebase's settings for push notifications come from google-services.json, which is not committed
// (docs/firebase.md). Without it the app still builds and runs, only without push notifications.
if (file("google-services.json").exists()) {
    apply(plugin = "com.google.gms.google-services")
} else {
    logger.warn("android/app/google-services.json is missing: this build gets no push notifications (docs/firebase.md)")
}

// The server's host, for the App Links of AndroidManifest.xml (docs/app-links.md). It comes from API_URL in
// config/dev.json: Flutter hands the dart-defines to Gradle as the "dart-defines" property, each one
// base64-encoded ("API_URL=https://..."), separated by commas.
val dartDefines: Map<String, String> =
    (project.findProperty("dart-defines") as String?).orEmpty()
        .split(",")
        .filter { it.isNotBlank() }
        .map { String(Base64.getDecoder().decode(it)).split("=", limit = 2) }
        .filter { it.size == 2 }
        .associate { it[0] to it[1] }
val appLinkHost: String =
    dartDefines["API_URL"]?.let { runCatching { URI(it).host }.getOrNull() } ?: "example.invalid"

android {
    namespace = "com.vnbadminton.vn_badminton_mobile"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
        // flutter_local_notifications uses java.time on every Android version.
        isCoreLibraryDesugaringEnabled = true
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.vnbadminton.vn_badminton_mobile"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        // Firebase (BoM 35), google_sign_in and flutter_local_notifications need Android 7.0 (API 24).
        minSdk = maxOf(flutter.minSdkVersion, 24)
        targetSdk = flutter.targetSdkVersion
        // Uses the version code from pubspec.yaml. When using split APKs, 1000 * ABI_VERSION
        // is added automatically by Flutter. (https://developer.android.com/studio/build/configure-apk-splits#configure-APK-versions)
        // You can force using the value of versionCode by specifying the `-P force-version-code-ignoring-abi=true`
        // flag during build.
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        // No API_URL (e.g. `flutter build` without config/dev.json): the links point nowhere.
        manifestPlaceholders["appLinkHost"] = appLinkHost
    }

    buildTypes {
        release {
            // TODO: Add your own signing config for the release build.
            // Signing with the debug keys for now, so `flutter run --release` works.
            signingConfig = signingConfigs.getByName("debug")
            proguardFiles("proguard-rules.pro")
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
    // For the AppCompat launch theme (see res/values/styles.xml).
    implementation("androidx.appcompat:appcompat:1.7.1")
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.5")
}
