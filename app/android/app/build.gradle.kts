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

    // Clé de signature fixe de la production (D-145) : fichier et mots de
    // passe donnés par le workflow « Site GitHub Pages » à partir des secrets
    // ANDROID_KEYSTORE_BASE64, ANDROID_KEYSTORE_PASSWORD, ANDROID_KEY_ALIAS et
    // ANDROID_KEY_PASSWORD. Sans eux (poste de développement, démonstration),
    // clé de débogage comme avant.
    val cleProduction = System.getenv("NAUTILINK_KEYSTORE")?.let { file(it) }?.takeIf { it.exists() }
    signingConfigs {
        if (cleProduction != null) {
            create("production") {
                storeFile = cleProduction
                storePassword = System.getenv("NAUTILINK_KEYSTORE_PASSWORD")
                keyAlias = System.getenv("NAUTILINK_KEY_ALIAS")
                // Clé PKCS12 de keytool : même mot de passe que le fichier ;
                // ANDROID_KEY_PASSWORD absent ou vide : celui du fichier.
                keyPassword = System.getenv("NAUTILINK_KEY_PASSWORD")?.takeIf { it.isNotEmpty() }
                    ?: System.getenv("NAUTILINK_KEYSTORE_PASSWORD")
            }
        }
    }

    buildTypes {
        release {
            signingConfig =
                if (cleProduction != null && modeReel) signingConfigs.getByName("production")
                else signingConfigs.getByName("debug")
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
    // Canaux natifs (MainActivity.kt) : autorisations, FileProvider, notifications.
    implementation("androidx.core:core-ktx:1.16.0")
}
