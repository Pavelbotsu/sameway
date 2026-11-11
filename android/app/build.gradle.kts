import java.util.Properties
import java.io.FileInputStream

// Release signing material lives in android/key.properties, which is
// gitignored. Without it a release build FAILS, unless the debug-key fallback
// is asked for explicitly (local testing only — the debug keystore is a
// well-known shared key, so such an APK must never be distributed):
//   flutter build apk --release -PallowDebugSigning=true
val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
    id("com.google.gms.google-services")
    // Version comes from the buildscript classpath in android/build.gradle.kts
    // (Gradle forbids re-declaring a version here in that case).
    // Uploads the R8 mapping file for release builds so Java/Kotlin stack
    // traces in Crashlytics are readable. Dart symbols (--split-debug-info)
    // are uploaded separately, see RELEASE_SETUP.md.
    id("com.google.firebase.crashlytics")
    // Firebase Performance Monitoring — instruments app-start and network
    // traces at build time. Version from the buildscript classpath.
    id("com.google.firebase.firebase-perf")
}

android {
    namespace = "com.example.sameway"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
        // Required by flutter_local_notifications (Phase 3.6) — backports
        // Java 8+ APIs (java.time, etc.) to older Android API levels.
        isCoreLibraryDesugaringEnabled = true
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11.toString()
    }

    defaultConfig {
        // Permanent once published — the Play Store identity of the app, and it
        // cannot be changed afterwards. `com.example.*` is a placeholder the
        // Play Store rejects outright.
        //
        // BUILDS FAIL UNTIL this package is registered in the Firebase console
        // and a regenerated google-services.json is dropped in
        // android/app/. See RELEASE_SETUP.md. The failure is explicit:
        //   "No matching client found for package name 'com.sameway.app'"
        //
        // `namespace` above deliberately stays com.example.sameway: it only
        // names the generated R/BuildConfig classes and the MainActivity
        // package, and changing it would mean moving the Kotlin sources for no
        // user-visible gain.
        applicationId = "com.sameway.app"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        // flutter_local_notifications requires multidex on lower API levels.
        multiDexEnabled = true
    }

    signingConfigs {
        create("release") {
            // Populated from android/key.properties (gitignored). See
            // android/key.properties.example for the required keys.
            if (keystorePropertiesFile.exists()) {
                keyAlias = keystoreProperties["keyAlias"] as String
                keyPassword = keystoreProperties["keyPassword"] as String
                storeFile = file(keystoreProperties["storeFile"] as String)
                storePassword = keystoreProperties["storePassword"] as String
            }
        }
    }

    buildTypes {
        release {
            // Real release key when key.properties is present. Otherwise the
            // debug key is wired in, but the guard below stops any release
            // task unless allowDebugSigning is set.
            //
            // A debug-signed release must NOT be distributed: the debug
            // keystore is a shared, well-known key, and switching to a real key
            // later forces every existing install to uninstall/reinstall
            // (Android refuses upgrades across a signature change).
            signingConfig = if (keystorePropertiesFile.exists()) {
                signingConfigs.getByName("release")
            } else {
                signingConfigs.getByName("debug")
            }
        }
    }
}

// Fail release builds that would be debug-signed. Checked once the task graph
// is known, so debug/profile builds and `flutter run` are unaffected.
val allowDebugSigning = (findProperty("allowDebugSigning") as String?)?.toBoolean() == true
gradle.taskGraph.whenReady {
    val releaseTask = allTasks.any {
        it.project == project && it.name.matches(Regex("(assemble|bundle|package)Release"))
    }
    if (releaseTask && !keystorePropertiesFile.exists()) {
        if (!allowDebugSigning) {
            throw GradleException(
                "android/key.properties not found: refusing to sign a release build with the " +
                "DEBUG key. Create key.properties (see key.properties.example), or for a local " +
                "test build only pass -PallowDebugSigning=true."
            )
        }
        logger.warn(
            "WARNING: signing release with the DEBUG key (allowDebugSigning). Do not distribute this build."
        )
    }
}

flutter {
    source = "../.."
}

dependencies {
    // Core library desugaring — required by flutter_local_notifications.
    // The version is pinned to a known-good release; bump in lockstep with
    // the AGP version when upgrading.
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
    // Import the BoM for the Firebase platform
    implementation(platform("com.google.firebase:firebase-bom:34.15.0"))

    // Add the dependencies for the Crashlytics and Analytics libraries
    // When using the BoM, you don't specify versions in Firebase library dependencies
    implementation("com.google.firebase:firebase-crashlytics")
    implementation("com.google.firebase:firebase-analytics")

}
