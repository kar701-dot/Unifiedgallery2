import java.util.Properties
import java.io.FileInputStream
import org.gradle.api.GradleException

plugins {
    id("com.android.application")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
    id("com.google.gms.google-services")
    id("com.google.firebase.crashlytics")
}

android {
    namespace = "com.pranav.onedrivephotos"
    compileSdk = 36
    // ✅ CRITICAL FIX: Force the NDK version that supports 16KB pages
    // NDK r27+ is required for 16KB page alignment (Android 15 compatibility)
    ndkVersion = "28.2.13676358"  // Required by jni plugin (backward compatible with NDK r27)
    
    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
        isCoreLibraryDesugaringEnabled = true
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {

        
        applicationId = "com.pranav.onedrivephotos"
        minSdk = flutter.minSdkVersion
        targetSdk = 36
        versionCode = flutter.versionCode
        versionName = flutter.versionName

        manifestPlaceholders["appAuthRedirectScheme"] = "com.pranav.onedrivephotos"
        manifestPlaceholders += mapOf(
            "appAuthRedirectScheme" to "com.pranav.onedrivephotos")

     ndk {
    abiFilters += listOf("armeabi-v7a", "arm64-v8a", "x86_64")
}
packaging {
    jniLibs {
        // ⚠️ WORKAROUND: Use compressed packaging to bypass 16KB alignment check
        // This is needed because Isar 3.1.0 doesn't support 16KB pages yet
        // Trade-off: Slightly slower app startup (libraries must be decompressed)
        // DO NOT set to false — Isar 3.1.0 native libs are NOT 16KB page-aligned;
        // false will crash the app on Android 15 devices (Pixel 9, etc.)
        useLegacyPackaging = false
   }
}


    }

    signingConfigs {
        create("release") {
            val keyPropertiesFile = rootProject.file("key.properties")
            if (keyPropertiesFile.exists()) {
                println(">>> Signing config using key.properties")
                val keyProperties = Properties().apply {
                    load(FileInputStream(keyPropertiesFile))
                }

                storeFile = file(keyProperties.getProperty("storeFile"))
                storePassword = keyProperties.getProperty("storePassword")
                keyAlias = keyProperties.getProperty("keyAlias")
                keyPassword = keyProperties.getProperty("keyPassword")
            } else {
                println(">>> Signing config NOT using key.properties (file not found at ${keyPropertiesFile.absolutePath})")
                throw GradleException("Could not find key.properties file at ${keyPropertiesFile.absolutePath}. Place it in the root of your project.")
            }
        }
    }

    buildTypes {
        getByName("release") {
            signingConfig = signingConfigs.getByName("release")
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
            // Disable Crashlytics mapping file upload at build time.
            // This prevents build failures when the build machine has no
            // internet access to firebasecrashlyticssymbols.googleapis.com.
            // Crash reporting still works; stack traces just won't be deobfuscated.
            // To re-enable: set both to true and ensure network access at build time.
            firebaseCrashlytics {
                mappingFileUploadEnabled = false
                nativeSymbolUploadEnabled = false
            }
        }
    }
}

flutter {
    source = "../.."
}

configurations {
    all {
        exclude(group = "com.google.firebase", module = "firebase-iid")
    }
}

dependencies {
    implementation("androidx.core:core-ktx:1.15.0")
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.0.4")
}

// Explicitly disable Crashlytics upload tasks during builds to prevent UnknownHostException
tasks.matching { it.name.startsWith("uploadCrashlytics") }.configureEach {
    enabled = false
}

