import java.util.Properties

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// 签名凭证读取顺序：android/key.properties 优先，其次环境变量 ANDROID_*。
// key.properties 已被 .gitignore 忽略 —— 有了它，Android Studio 菜单打包也能取到密钥
// （AS 的 Gradle 进程继承不到你在 PowerShell 里 $env: 设的会话级变量，这是最常见的坑）。
// 注意：脚本里不能写全限定名 java.util.Properties()，`java` 会被解析成 Gradle 的 java 扩展。
val keystoreProps = Properties().apply {
    val propsFile = rootProject.file("key.properties")
    if (propsFile.exists()) propsFile.inputStream().use { load(it) }
}

fun signingProp(propKey: String, envKey: String): String? =
    keystoreProps.getProperty(propKey)?.takeIf { it.isNotBlank() }
        ?: System.getenv(envKey)?.takeIf { it.isNotBlank() }

android {
    namespace = "com.meikongcui.teacherapp"
    compileSdk = 36
    ndkVersion = flutter.ndkVersion

    compileOptions {
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.meikongcui.teacherapp"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = 21
        targetSdk = 36
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        create("release") {
            // 密钥信息来自 key.properties 或环境变量，均不入库（敏感）
            val keystorePath = signingProp("storeFile", "ANDROID_KEYSTORE_PATH")
            // 相对路径按 android/ 目录解析；绝对路径原样使用
            storeFile = keystorePath?.let { rootProject.file(it) }
            storePassword = signingProp("storePassword", "ANDROID_STORE_PASSWORD")
            keyAlias = signingProp("keyAlias", "ANDROID_KEY_ALIAS")
            keyPassword = signingProp("keyPassword", "ANDROID_KEY_PASSWORD")
        }
    }

    buildTypes {
        release {
            // 使用自建 release keystore 签名（凭证来源：android/key.properties 或环境变量）
            signingConfig = signingConfigs.getByName("release")
        }
    }
}

dependencies {
    // 核心库脱糖：flutter_local_notifications 等依赖需要（release 构建 checkReleaseAarMetadata 会强制校验）
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.5")
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

flutter {
    source = "../.."
}
