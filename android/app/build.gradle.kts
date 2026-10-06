import java.util.Properties

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
    // Google services for Firebase
    id("com.google.gms.google-services")
}

// ---------------------------------------------------------------------------
// Firma de release
//
// Las credenciales viven en android/key.properties, que NO se versiona
// (android/.gitignore lo excluye junto con *.jks y *.keystore). Si el archivo
// no está —por ejemplo en un clon limpio o en CI sin secretos— el build de
// release NO falla: cae al keystore de depuración y avisa en voz alta. Esa es
// una decisión deliberada: que cualquiera pueda comprobar que el proyecto
// compila sin tener que pedir las claves, a cambio de un aviso imposible de
// pasar por alto para que nadie intente subir ese artefacto a Play.
//
// Para generar un keystore de subida propio:
//
//   keytool -genkeypair -v \
//     -keystore C:/Users/Franco/claves/pagate-upload.jks \
//     -storetype JKS -keyalg RSA -keysize 2048 -validity 10000 \
//     -alias upload \
//     -dname "CN=Pagate, OU=Desarrollo, O=Pagate, L=Santiago, ST=RM, C=CL"
//
// Guardarlo FUERA del repositorio y respaldarlo: si se pierde la clave de
// subida, Play permite reiniciarla, pero solo si la app usa Play App Signing.
// La huella SHA-256 que hay que registrar en App Check / Play Integrity es la
// de Play Console -> Probar y publicar -> Integridad de la app -> certificado
// de la clave de firma de la app, no la de este keystore de subida.
// ---------------------------------------------------------------------------
val keystorePropertiesFile = rootProject.file("key.properties")
val keystoreProperties = Properties().apply {
    if (keystorePropertiesFile.exists()) {
        keystorePropertiesFile.inputStream().use { load(it) }
    }
}
val hasReleaseKeystore = keystoreProperties.getProperty("storeFile") != null

if (!hasReleaseKeystore) {
    logger.warn(
        """
        |
        |  ============================================================
        |   AVISO: no se encontró android/key.properties.
        |   El build de release se firmará con el keystore de DEPURACIÓN.
        |   Google Play RECHAZA ese artefacto:
        |     «You uploaded an APK or Android App Bundle that was signed
        |      in debug mode».
        |   Crea android/key.properties (ver el comentario de este
        |   archivo) antes de generar el AAB que se vaya a publicar.
        |  ============================================================
        |
        """.trimMargin()
    )
}

android {
    namespace = "com.pagate.apppagate"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        applicationId = "com.pagate.apppagate"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        if (hasReleaseKeystore) {
            create("release") {
                // file() resuelve relativo a android/app/, que es el directorio
                // de este módulo; por eso key.properties usa ../ para llegar a
                // android/.
                storeFile = file(keystoreProperties.getProperty("storeFile"))
                storePassword = keystoreProperties.getProperty("storePassword")
                keyAlias = keystoreProperties.getProperty("keyAlias")
                keyPassword = keystoreProperties.getProperty("keyPassword")
            }
        }
    }

    buildTypes {
        release {
            signingConfig = if (hasReleaseKeystore) {
                signingConfigs.getByName("release")
            } else {
                signingConfigs.getByName("debug")
            }

            // R8 y el eliminador de recursos.
            //
            // El plugin de Gradle de Flutter ya los activa por su cuenta
            // (FlutterPlugin.kt:262-265 del SDK), así que estas dos líneas no
            // cambian el resultado de hoy: están para fijar el comportamiento
            // de forma explícita y auditable en vez de depender de un detalle
            // interno del SDK que puede cambiar de versión.
            //
            // Lo que SÍ es nuevo es proguard-rules.pro. Flutter solo lo añade
            // «si existe» (FlutterPlugin.kt:277-279) y hasta ahora no existía:
            // R8 llevaba corriendo sobre este proyecto sin una sola regla
            // propia, apoyado únicamente en las que traen los AAR de Firebase.
            //
            // Tamaño medido, en MB de 10^6 (la unidad que usa Play Console; la
            // línea «Built app-release.apk (57,7MB)» de la consola de Flutter
            // son MiB de 2^20 y por eso da otro número para los mismos bytes).
            // Medido sobre build/app/outputs/flutter-apk/app-release.apk de
            // este árbol, sumando las entradas del zip por prefijo:
            //
            //                       con R8 (lo de ahora)   con isMinifyEnabled=false
            //   APK completo              60,50 MB                65,02 MB
            //   classes.dex                3,77 MB                16,44 MB
            //   lib/**.so                 58,01 MB                58,01 MB
            //
            // Dos lecturas, las dos verificadas:
            // - R8 SÍ sirve: recorta el dex un 77 % y el APK 4,5 MB.
            // - Pero el APK sigue pesando 60 MB porque 58 de esos MB son las
            //   bibliotecas nativas de las tres ABI (arm64 19,46 + armv7 17,54
            //   + x86_64 21,01), que R8 no toca. Quien reduce eso de verdad es
            //   el AAB: Play entrega a cada teléfono una sola ABI.
            //
            // Lo que NO cambia el tamaño es añadir estas dos líneas, porque R8
            // ya estaba activo por el plugin de Flutter; están para fijarlo de
            // forma explícita, no para ahorrar bytes.
            //
            // Reproducir:
            //   python -c "import zipfile,os; z=zipfile.ZipFile(r'build/app/outputs/flutter-apk/app-release.apk'); print(os.path.getsize(z.filename), sum(i.file_size for i in z.infolist() if i.filename.startswith('lib/')), sum(i.file_size for i in z.infolist() if i.filename.endswith('.dex')))"
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro",
            )
        }
    }
}

flutter {
    source = "../.."
}
