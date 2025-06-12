plugins {
    id("com.android.application")

    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
    id("com.google.gms.google-services")  // For Firebase
}

android {
    namespace = "com.example.myapp"
    compileSdk = 36  // ✅ Explicitly set (better than flutter.compileSdkVersion)
    ndkVersion = "27.0.12077973"  // ✅ Correct for ML Kit

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }

    kotlinOptions {
        jvmTarget = "11"
    }

    defaultConfig {
        applicationId = "com.example.myapp"
        minSdk = 23  // ✅ ML Kit requires min 21, 23 is safer
        targetSdk = 36  // ✅ Explicitly set
        versionCode = flutter.versionCode ?: 1
        versionName = flutter.versionName ?: "1.0"
        multiDexEnabled = true  // ✅ Needed for Firebase
    }

    buildTypes {
        debug {
            signingConfig = signingConfigs.getByName("debug")
        }
        release {
            signingConfig = signingConfigs.getByName("debug")  // ⚠️ Update for production
            isMinifyEnabled = true // ✅ Enable R8/proguard
            proguardFiles(
                getDefaultProguardFile("proguard-android.txt"),
                "proguard-rules.pro"
            )
        }
    }
}

dependencies {
    implementation(platform("com.google.firebase:firebase-bom:33.14.0"))  // ✅ Latest as of 2024

    // Required for Firebase Auth + Storage
    implementation("com.google.firebase:firebase-auth")
    implementation("com.google.firebase:firebase-storage")
    
    // ML Kit Face Detection (add explicitly)
    implementation("com.google.mlkit:face-detection:16.1.5")
    
    // CameraX (recommended for better camera support)
    implementation("androidx.camera:camera-camera2:1.3.3")
    implementation("androidx.camera:camera-lifecycle:1.3.3")
    implementation("androidx.camera:camera-view:1.3.3")
    
    // For Flutter engine
    implementation("org.jetbrains.kotlin:kotlin-stdlib-jdk8:1.9.0")

}

// ✅ Make sure this line is removed at the bottom (as you noted)
