import java.net.URI
import java.security.KeyStore
import java.security.MessageDigest
import java.security.PrivateKey
import java.security.cert.X509Certificate
import java.util.Base64
import java.util.Properties

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

val signingProperties = Properties()
val signingFile = rootProject.file("key.properties")
if (signingFile.exists()) signingFile.inputStream().use { signingProperties.load(it) }
fun signingValue(name: String): String? =
    System.getenv("FINDIT_HIDDEN_${name.replace(Regex("([a-z])([A-Z])"), "$1_$2").uppercase()}")
        ?: signingProperties.getProperty(name)

// Two explicit gates, not an automatic debug-signing fallback. Flutter can pass
// this Gradle property directly with --android-project-arg=unsignedProductionCandidate=true.
val candidateProperty = providers.gradleProperty("unsignedProductionCandidate").orNull
val unsignedProductionCandidate = candidateProperty == "true"
// Public certificate pin for this new app's dedicated upload key, never a
// password or a pin from the original app. A key change requires explicit review.
val productionUploadCertificateSha256 = "e4d765e9c1676c9acfa95560b78177754e35fafc77dcb990dbf2e7ac2c999114"

android {
    namespace = "abiral.mobile.findithiddenobjects"
    compileSdk = maxOf(36, flutter.compileSdkVersion)
    ndkVersion = "28.2.13676358"

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // Separate from the original FindIt app; publisher ownership is a release gate.
        applicationId = "abiral.mobile.findithiddenobjects"
        minSdk = 24
        targetSdk = 36
        // Uses the version code from pubspec.yaml. When using split APKs, 1000 * ABI_VERSION
        // is added automatically by Flutter. (https://developer.android.com/studio/build/configure-apk-splits#configure-APK-versions)
        // You can force using the value of versionCode by specifying the `-P force-version-code-ignoring-abi=true`
        // flag during build.
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    flavorDimensions += "environment"
    productFlavors {
        create("dev") {
            dimension = "environment"
            applicationIdSuffix = ".dev"
            versionNameSuffix = "-dev"
            manifestPlaceholders["appLabel"] = "FindIt Hidden Dev"
        }
        create("qa") {
            dimension = "environment"
            applicationIdSuffix = ".qa"
            versionNameSuffix = "-qa"
            manifestPlaceholders["appLabel"] = "FindIt Hidden QA"
        }
        create("prod") {
            dimension = "environment"
            manifestPlaceholders["appLabel"] = "FindIt Hidden"
            // Public release evidence comes from the very same Dart defines
            // that the guarded Flutter build uses. No signing secrets go here.
            val config = dartConfiguration()
            manifestPlaceholders["hiddenAppEnvironment"] = config["APP_ENV"].orEmpty()
            manifestPlaceholders["hiddenBuildStage"] = config["BUILD_STAGE"].orEmpty()
            manifestPlaceholders["hiddenPrivacyPolicyUrl"] = config["PRIVACY_POLICY_URL"].orEmpty()
            manifestPlaceholders["hiddenPackIndexUrl"] = config["PACK_INDEX_URL"].orEmpty()
        }
    }

    signingConfigs {
        if (!unsignedProductionCandidate && !signingValue("storeFile").isNullOrBlank()) {
            create("upload") {
                storeFile = file(signingValue("storeFile")!!)
                storePassword = signingValue("storePassword")
                keyAlias = signingValue("keyAlias")
                keyPassword = signingValue("keyPassword")
            }
        }
    }

    buildTypes {
        release {
            // Signing belongs to each flavor. Dev/QA must never use an upload key.
            signingConfig = null
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(getDefaultProguardFile("proguard-android-optimize.txt"), "proguard-rules.pro")
        }
    }
    productFlavors.getByName("dev").signingConfig = signingConfigs.getByName("debug")
    productFlavors.getByName("qa").signingConfig = signingConfigs.getByName("debug")
    productFlavors.getByName("prod").signingConfig =
        if (unsignedProductionCandidate) null else signingConfigs.findByName("upload")
}

fun dartConfiguration(): Map<String, String> {
    val values = (project.findProperty("dart-defines") as? String).orEmpty()
        .split(",").filter { it.isNotBlank() }.map {
            val decoded = runCatching { String(Base64.getDecoder().decode(it), Charsets.UTF_8) }
                .getOrElse { error("Malformed Dart defines are not allowed.") }
            check(decoded.contains("=")) { "Malformed Dart defines are not allowed." }
            decoded.substringBefore("=") to decoded.substringAfter("=")
        }
    check(values.map { it.first }.distinct().size == values.size) {
        "Duplicate Dart defines are not allowed."
    }
    return values.toMap()
}

fun isPublicHttps(value: String?): Boolean {
    val uri = runCatching { URI(value.orEmpty()) }.getOrNull() ?: return false
    val host = uri.host?.lowercase() ?: return false
    val reserved = listOf("localhost", "invalid", "example", "test", "local", "internal",
        "example.com", "example.org", "example.net")
    return uri.scheme == "https" && uri.userInfo == null && host.contains(".") &&
        !host.contains(":") && !host.matches(Regex("[0-9.]+")) &&
        reserved.none { host == it || host.endsWith(".$it") }
}

val rejectAdvertisingInGame by tasks.registering {
    doLast {
        val config = dartConfiguration()
        val target = (project.findProperty("target") as? String ?: "lib/main.dart").replace('\\', '/')
        val main = rootProject.projectDir.parentFile.resolve("lib/main.dart").absolutePath.replace('\\', '/')
        check(target == "lib/main.dart" || target == main) {
            "The hidden-object app requires lib/main.dart."
        }
        check(config["APP_ENV"] != "ad-preview" && !config.containsKey("AD_PREVIEW") &&
            config.keys.none { it.startsWith("ADMOB_", ignoreCase = true) } &&
            project.properties.keys.none {
                it.startsWith("admob", ignoreCase = true) || it.equals("AD_PREVIEW", ignoreCase = true)
            } && System.getenv().keys.none {
                it.startsWith("FINDIT_ADMOB_", ignoreCase = true) ||
                it.startsWith("ADMOB_", ignoreCase = true) || it == "AD_PREVIEW"
            }) {
            "Advertising configuration is not allowed in the hidden-object app."
        }
        check(candidateProperty == null || candidateProperty in listOf("true", "false")) {
            "unsignedProductionCandidate must be explicitly true or false."
        }
    }
}

val validateDevelopment by tasks.registering {
    dependsOn(rejectAdvertisingInGame)
    doLast {
        val config = dartConfiguration()
        check(!unsignedProductionCandidate && (config["APP_ENV"] ?: "development") == "development" &&
            config["BUILD_STAGE"].isNullOrBlank()) { "Dev builds require the development configuration, not a release candidate." }
    }
}

val validateQa by tasks.registering {
    dependsOn(rejectAdvertisingInGame)
    doLast {
        val config = dartConfiguration()
        check(!unsignedProductionCandidate && config["APP_ENV"] == "qa" && config["BUILD_STAGE"] == "qa") {
            "QA requires APP_ENV=qa and BUILD_STAGE=qa, without the unsigned-production flag."
        }
        check(config["PACK_INDEX_URL"].isNullOrBlank()) { "This ad-free release has no configured pack server." }
        check(config["PRIVACY_POLICY_URL"].isNullOrBlank() || isPublicHttps(config["PRIVACY_POLICY_URL"])) {
            "A configured privacy policy must use a public HTTPS URL."
        }
    }
}

val validateProduction by tasks.registering {
    dependsOn(rejectAdvertisingInGame)
    doLast {
        val config = dartConfiguration()
        check(config["APP_ENV"] == "production") { "Production requires APP_ENV=production." }
        check(config["PACK_INDEX_URL"].isNullOrBlank()) { "This ad-free release has no configured pack server." }
        if (unsignedProductionCandidate) {
            check(config["BUILD_STAGE"] == "unsigned-candidate") {
                "Unsigned APK candidates require BUILD_STAGE=unsigned-candidate and -PunsignedProductionCandidate=true."
            }
            check(gradle.startParameter.taskNames.none { it.contains("bundle", ignoreCase = true) }) {
                "An unsigned candidate is APK-only. AAB builds require final signing and a public privacy policy."
            }
            check(android.productFlavors.getByName("prod").signingConfig == null) {
                "An unsigned production candidate must have no signing configuration."
            }
            check(config["PRIVACY_POLICY_URL"].isNullOrBlank() || isPublicHttps(config["PRIVACY_POLICY_URL"])) {
                "A configured privacy policy must use a public HTTPS URL."
            }
        } else {
            check(config["BUILD_STAGE"] == "final") {
                "Signed production requires BUILD_STAGE=final. Unsigned APK candidates need both explicit candidate gates."
            }
            check(listOf("storeFile", "storePassword", "keyAlias", "keyPassword").all { !signingValue(it).isNullOrBlank() }) {
                "Production requires an upload key. See android/key.properties.example and README.md."
            }
            check(isPublicHttps(config["PRIVACY_POLICY_URL"])) {
                "PRIVACY_POLICY_URL must be the publisher's public HTTPS policy, not a placeholder."
            }
            check(file(signingValue("storeFile")!!).isFile) { "The configured upload keystore does not exist." }
            check(!signingValue("keyAlias")!!.equals("androiddebugkey", ignoreCase = true) &&
                !file(signingValue("storeFile")!!).name.equals("debug.keystore", ignoreCase = true)) {
                "A development key cannot sign production."
            }
            // Validate the actual key, not just its filename/alias. Never print
            // passwords or use a renamed Android Debug certificate as production.
            val keyStore = runCatching {
                KeyStore.getInstance(file(signingValue("storeFile")!!), signingValue("storePassword")!!.toCharArray())
            }.getOrElse { error("The production upload keystore cannot be opened with the configured credentials.") }
            val alias = signingValue("keyAlias")!!
            check(keyStore.isKeyEntry(alias)) { "The production upload alias is not a private-key entry." }
            val key = runCatching { keyStore.getKey(alias, signingValue("keyPassword")!!.toCharArray()) }
                .getOrElse { error("The production upload private key cannot be opened with the configured credentials.") }
            check(key is PrivateKey) { "The production upload alias has no private key." }
            val certificate = keyStore.getCertificate(alias) as? X509Certificate
                ?: error("The production upload key has no X.509 certificate.")
            val certificateSha256 = MessageDigest.getInstance("SHA-256").digest(certificate.encoded)
                .joinToString("") { "%02x".format(it.toInt() and 0xff) }
             check(!certificate.subjectX500Principal.name.contains("CN=Android Debug", ignoreCase = true) &&
                 certificateSha256 != "b08451266f6a68fa07cc2cf4da0112d0c755b77a671a46b2c7980bc8b920b594") {
                 "A development key cannot sign production."
             }
             check(certificateSha256 == productionUploadCertificateSha256) {
                 "The production certificate does not match this app's dedicated upload key."
             }
            runCatching { certificate.checkValidity() }
                .getOrElse { error("The production upload certificate is expired or not yet valid.") }
        }
    }
}

val validateSignedProductionBundle by tasks.registering {
    dependsOn(validateProduction)
    doLast {
        check(!unsignedProductionCandidate && dartConfiguration()["BUILD_STAGE"] == "final") {
            "AAB builds require final signing and a public privacy policy; unsigned candidates are APK-only."
        }
    }
}

val rejectNonReleaseProduction by tasks.registering {
    doLast { error("The production package identity is release-only. Use dev or qa for local testing.") }
}

tasks.configureEach {
    if (name == "preProdReleaseBuild") dependsOn(validateProduction)
    if (name.matches(Regex("preProd(Debug|Profile)Build"))) dependsOn(rejectNonReleaseProduction)
    if (name.matches(Regex("preDev(Debug|Profile|Release)Build"))) dependsOn(validateDevelopment)
    if (name.matches(Regex("preQa(Debug|Profile|Release)Build"))) dependsOn(validateQa)
    if (name in listOf("bundleProdRelease", "packageProdReleaseBundle", "signProdReleaseBundle", "buildProdReleasePreBundle")) {
        dependsOn(validateSignedProductionBundle)
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
