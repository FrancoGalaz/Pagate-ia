allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

val newBuildDir: Directory =
    rootProject.layout.buildDirectory
        .dir("../../build")
        .get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)
}
subprojects {
    project.evaluationDependsOn(":app")
}

// ---------------------------------------------------------------------------
// Compatibilidad de JVM target en los plugins de terceros
//
// POR QUÉ EXISTE ESTO, con el error exacto que arregla:
//
//   Execution failed for task ':receive_sharing_intent:compileDebugKotlin'.
//   > Inconsistent JVM-target compatibility detected for tasks
//     'compileDebugJavaWithJavac' (1.8) and 'compileDebugKotlin' (21).
//
// `receive_sharing_intent` 1.8.1 no declara `compileOptions`, así que su
// Java compila a 1.8 mientras su Kotlin coge el de la JDK que ejecuta
// Gradle (21). Desde Kotlin 1.8 esa mezcla es un error de build, no un
// aviso, y la app entera deja de compilar por un plugin que no es nuestro.
//
// Se arregla aquí y no editando el paquete en el caché de pub por un motivo
// práctico: el caché se borra con `flutter pub cache repair` y lo que se
// toque ahí no viaja al siguiente clon ni a CI. Esto sí está versionado.
//
// Se fija 17, que es lo que ya usa `android/app/build.gradle.kts` para el
// módulo de la app (`JavaVersion.VERSION_17`), así que todo el proyecto
// compila contra el mismo nivel. NO se toca el módulo `:app`: su
// configuración manda sobre esto.
subprojects {
    if (project.name != "app") {
        // `afterEvaluate` y no `plugins.withId` a secas: varios plugins
        // declaran SUS PROPIAS `compileOptions` (google_mlkit_commons pone
        // Java 11), y una configuración puesta antes de evaluarlos la
        // pisarían ellos. Aquí se aplica cuando ya terminaron.
        project.afterEvaluate {
            val android = project.extensions.findByName("android")
            if (android is com.android.build.gradle.BaseExtension) {
                android.compileOptions {
                    sourceCompatibility = JavaVersion.VERSION_17
                    targetCompatibility = JavaVersion.VERSION_17
                }
            }
            project.tasks.withType<org.jetbrains.kotlin.gradle.tasks.KotlinCompile>()
                .configureEach {
                    compilerOptions {
                        jvmTarget.set(
                            org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17,
                        )
                    }
                }
        }
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
