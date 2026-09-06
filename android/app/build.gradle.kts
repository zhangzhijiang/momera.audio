import java.util.Properties

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.idatagear.momera.audio"
    compileSdk = 36
    ndkVersion = "28.2.13676358"

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        applicationId = "com.idatagear.momera.audio"
        minSdk = 24
        targetSdk = 36
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        multiDexEnabled = true

        // No `ndk { abiFilters ... }` here, deliberately.
        //
        // The Flutter Gradle Plugin owns abiFilters: configureAbiWithoutSplits()
        // calls abiFilters.clear() and adds all of armeabi-v7a, arm64-v8a and
        // x86_64 while the plugin is being applied — which happens before this
        // script body runs. A bare abiFilters.add(...) here therefore lands on an
        // already-full set and does nothing. (A block that did exactly that lived
        // here until 2026-09-05, claiming to select ABIs while having no effect.)
        //
        // Shipping all three is correct for an App Bundle: Play builds one config
        // APK per ABI and a device downloads only its own, so the install is the
        // same size either way (~30 MB on arm64) whether we ship one ABI or three.
        //
        // If ABIs ever do need restricting, it takes BOTH abiFilters.clear() plus
        // the wanted entries here AND `flutter build --target-platform ...`.
        // Passing only the build flag yields a broken armeabi-v7a split:
        // -Ptarget-platform does not feed configureAbiWithoutSplits, so Flutter's
        // libflutter.so/libapp.so would be omitted while third-party arm32 libs
        // (onnxruntime, translate_jni) still pass the filter — and Play would keep
        // offering the app to 32-bit devices. Note also that a static abiFilters
        // conflicts with `flutter build apk --split-per-abi`, which is why the
        // Flutter templates ship without one.
    }

    // Load signing properties safely.
    val keystoreProperties = Properties()
    val keystorePropertiesFile = rootProject.file("key.properties")
    if (keystorePropertiesFile.exists()) {
        keystorePropertiesFile.inputStream().use { keystoreProperties.load(it) }
    }

    signingConfigs {
        create("release") {
            val keyAliasProp = keystoreProperties.getProperty("keyAlias")
            val keyPasswordProp = keystoreProperties.getProperty("keyPassword")
            val storeFileProp = keystoreProperties.getProperty("storeFile")
            val storePasswordProp = keystoreProperties.getProperty("storePassword")

            if (!keyAliasProp.isNullOrEmpty()) keyAlias = keyAliasProp
            if (!keyPasswordProp.isNullOrEmpty()) keyPassword = keyPasswordProp
            if (!storeFileProp.isNullOrEmpty()) storeFile = file(storeFileProp)
            if (!storePasswordProp.isNullOrEmpty()) storePassword = storePasswordProp
        }
    }

    buildTypes {
        getByName("release") {
            signingConfig = signingConfigs.findByName("release")
            proguardFiles(getDefaultProguardFile("proguard-android-optimize.txt"), "proguard-rules.pro")
        }
    }
}

flutter {
    source = "../.."
}


dependencies {
    implementation("androidx.core:core-ktx:1.17.0")
    implementation("androidx.multidex:multidex:2.0.1")
}

