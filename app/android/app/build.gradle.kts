import java.util.Base64

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Mode choisi à la construction (D-127, D-129) : --dart-define=NAUTILINK_MODE=reel
// donne la vraie application (fr.nautilink.nautilink, « NautiLink ») ; sinon la
// démonstration (fr.nautilink.nautilink.demo, « NautiLink démo »), installable à
// côté de la vraie. Flutter passe les --dart-define à Gradle en base64.
val dartDefines: Map<String, String> =
    (project.findProperty("dart-defines") as String?)
        ?.split(",")
        ?.filter { it.isNotEmpty() }
        ?.associate {
            val d = String(Base64.getDecoder().decode(it))
            d.substringBefore("=") to d.substringAfter("=")
        } ?: emptyMap()
val modeReel = dartDefines["NAUTILINK_MODE"] == "reel"

android {
    namespace = "fr.nautilink.nautilink"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "fr.nautilink.nautilink"
        if (!modeReel) applicationIdSuffix = ".demo"
        manifestPlaceholders["appLabel"] = if (modeReel) "NautiLink" else "NautiLink démo"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        // Uses the version code from pubspec.yaml. When using split APKs, 1000 * ABI_VERSION
        // is added automatically by Flutter. (https://developer.android.com/studio/build/configure-apk-splits#configure-APK-versions)
        // You can force using the value of versionCode by specifying the `-P force-version-code-ignoring-abi=true`
        // flag during build.
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            // TODO: Add your own signing config for the release build.
            // Signing with the debug keys for now, so `flutter run --release` works.
            signingConfig = signingConfigs.getByName("debug")
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
