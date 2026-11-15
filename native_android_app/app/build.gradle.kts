plugins {
    alias(libs.plugins.android.application)
}

android {
    namespace = "com.example.native_android_app"
    compileSdk {
        version = release(37)
    }

    defaultConfig {
        applicationId = "com.example.native_android_app"
        minSdk = 24
        targetSdk = 37
        versionCode = 1
        versionName = "1.0"

        // Flutter release engines ship no x86 build.
        ndk {
            abiFilters += listOf(
                "armeabi-v7a",
                "arm64-v8a",
                "x86_64"
            )
        }
    }

    buildFeatures {
        viewBinding = true
    }

    buildTypes {
        release {
            optimization {
                enable = false
            }
        }
    }
    compileOptions {
        sourceCompatibility =  JavaVersion.VERSION_17
        targetCompatibility =  JavaVersion.VERSION_17
    }
}

dependencies {
    // The Flutter module, built with `flutter build aar --no-debug --no-profile`.
    implementation("com.example.flutter_module:flutter_release:1.0")

    implementation(libs.androidx.activity.ktx)
    implementation(libs.androidx.appcompat)
    implementation(libs.androidx.constraintlayout)
    implementation(libs.androidx.core.ktx)
    implementation(libs.material)
}
