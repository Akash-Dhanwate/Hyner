import java.util.Base64
import java.util.Properties

plugins {
    id("com.android.application")
    id("com.google.gms.google-services")
    id("dev.flutter.flutter-gradle-plugin")
}

// Supplied through --dart-define-from-file after actual Firebase registration.
// com.example.hyner is the generated local-development template identifier.
val defines = (project.findProperty("dart-defines") as String?)
    ?.split(",")?.mapNotNull {
        val parts = String(Base64.getDecoder().decode(it)).split("=", limit = 2)
        if (parts.size == 2) parts[0] to parts[1] else null
    }?.toMap() ?: emptyMap()
val hynerApplicationId = defines["HYNER_ANDROID_APPLICATION_ID"] ?: "com.example.hyner"
val signingFile = rootProject.file("key.properties")
val signing = Properties().apply { if (signingFile.exists()) signingFile.inputStream().use { load(it) } }
val releaseRequested = gradle.startParameter.taskNames.any { it.contains("Release", ignoreCase = true) }
if (releaseRequested) {
    val required = listOf("FIREBASE_API_KEY", "FIREBASE_APP_ID", "FIREBASE_PROJECT_ID", "FIREBASE_MESSAGING_SENDER_ID", "GOOGLE_SERVER_CLIENT_ID")
    check(defines["HYNER_ENV"] == "production" && required.all { !defines[it].isNullOrBlank() }) {
        "Production Firebase configuration is required. See docs/SETUP.md."
    }
    check(!hynerApplicationId.startsWith("com.example.")) { "Register the final Android application ID before a release build." }
    check(signingFile.exists() && listOf("storeFile", "storePassword", "keyAlias", "keyPassword").all { !signing.getProperty(it).isNullOrBlank() }) {
        "A local release signing configuration is required. Debug signing is never used for release. See docs/SETUP.md."
    }
}

android {
    namespace = "com.example.hyner"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion
    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }
    defaultConfig {
        applicationId = hynerApplicationId
        minSdk = 24
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }
    signingConfigs {
        if (signingFile.exists()) {
            create("hynerRelease") {
                storeFile = file(signing.getProperty("storeFile"))
                storePassword = signing.getProperty("storePassword")
                keyAlias = signing.getProperty("keyAlias")
                keyPassword = signing.getProperty("keyPassword")
            }
        }
    }
    buildTypes {
        release {
            if (signingFile.exists()) signingConfig = signingConfigs.getByName("hynerRelease")
        }
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

flutter { source = "../.." }
