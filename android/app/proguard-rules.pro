# Reglas de R8 propias de Págate-IA.
#
# Alcance deliberadamente corto. Casi todo lo que necesitan los SDK de Firebase
# ya viaja dentro de los propios AAR como reglas de consumidor y R8 las aplica
# sin que haya que copiarlas: verificado abriendo el proguard.txt de
# firebase-firestore 25.1.4, firebase-auth 23.2.1 y firebase-functions 21.2.1 en
# la caché de Gradle (traen los -dontwarn de javax.naming, okio, checkerframework
# y los -keep de los modelos que Auth deserializa por reflexión). Flutter añade
# además flutter_proguard_rules.pro, que conserva toda implementación de
# FlutterPlugin y silencia android.** e io.flutter.plugin.**.
#
# Aquí solo quedan los huecos que esas reglas NO cubren.

# --------------------------------------------------------------------------
# printing 5.14.3 (el plugin que imprime y comparte los PDF que genera `pdf`)
# --------------------------------------------------------------------------
# El paquete `pdf` es Dart puro y R8 no lo toca. `printing` sí trae código
# Android y NO empaqueta reglas de consumidor (comprobado: su android/ no tiene
# proguard-rules.pro ni consumerProguardFiles).
#
# PrintingPlugin lo salva la regla de Flutter por implementar FlutterPlugin, y
# PrintFileProvider lo salva el manifiesto por ser un ContentProvider. Quien
# queda sin red es android.print.PdfConvert: vive en un paquete del sistema que
# el plugin no posee, y Flutter aplica `-dontwarn android.**`, de modo que si R8
# lo elimina u ofusca el fallo no aparece hasta que el usuario pulsa exportar.
-keep class android.print.PdfConvert { *; }
-keep class net.nfet.flutter.printing.** { *; }

# --------------------------------------------------------------------------
# firebase_app_check — Play Integrity
# --------------------------------------------------------------------------
# El proveedor de Play Integrity se instancia por nombre a través del registro
# de componentes de Firebase, no por una referencia directa en el código, así
# que R8 no ve ninguna arista hacia él.
-keep class com.google.firebase.appcheck.playintegrity.** { *; }
-keep class com.google.android.play.core.integrity.** { *; }

# --------------------------------------------------------------------------
# Avisos de dependencias opcionales que no se empaquetan
# --------------------------------------------------------------------------
# gRPC (el transporte de cloud_firestore) declara enlaces opcionales con
# Conscrypt y con el motor de anotaciones de errores. Ninguno está en el APK, y
# sin estos -dontwarn R8 corta el build en modo completo.
-dontwarn org.conscrypt.**
-dontwarn com.google.errorprone.annotations.**
-dontwarn javax.annotation.**

# --------------------------------------------------------------------------
# google_mlkit_text_recognition — los tres alfabetos que NO se empaquetan
# --------------------------------------------------------------------------
# Sin estas cuatro líneas `flutter build apk --release` FALLA, no avisa:
#
#   Missing class com.google.mlkit.vision.text.chinese.ChineseTextRecognizerOptions
#   ... devanagari ... japanese ... korean ...
#   Execution failed for task ':app:minifyReleaseWithR8'
#
# El motivo es deliberado del lado del paquete: su `android/build.gradle`
# declara UN solo artefacto, `com.google.mlkit:text-recognition:16.0.1`, que
# es el alfabeto latino; los otros tres (chino, devanagari, japonés, coreano)
# son dependencias aparte que no se incluyen. Pero su código Kotlin los
# nombra en el `when` que elige el reconocedor, así que R8 ve una referencia
# a clases que no están y corta el build.
#
# `-dontwarn` y NO añadir los artefactos: esta app lee boletas chilenas, y
# cada alfabeto extra son varios MB de modelo que nadie va a usar. La guarda
# de que no se usan está en el código: `MlkitTextReader` construye el
# `TextRecognizer` sin argumentos, y su `script` por defecto es
# `TextRecognitionScript.latin`.
-dontwarn com.google.mlkit.vision.text.chinese.**
-dontwarn com.google.mlkit.vision.text.devanagari.**
-dontwarn com.google.mlkit.vision.text.japanese.**
-dontwarn com.google.mlkit.vision.text.korean.**

# --------------------------------------------------------------------------
# Trazas de excepción legibles en los informes de fallos de Play Console
# --------------------------------------------------------------------------
# Sin esto, las líneas de las trazas se pierden y un fallo en producción llega a
# Play Console sin número de línea. El mapping queda en
# build/app/outputs/mapping/release/mapping.txt y hay que subirlo a Play junto
# con el AAB para poder desofuscar.
-keepattributes SourceFile,LineNumberTable
-renamesourcefileattribute SourceFile
