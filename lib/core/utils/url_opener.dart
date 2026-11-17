import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';

import 'app_feedback.dart';

// ═══════════════════════════════════════════════════════════════════════
// ABRIR UN ENLACE EXTERNO
// ═══════════════════════════════════════════════════════════════════════
// QUÉ ARREGLA: la línea legal de Bienvenida decía "Al continuar aceptas los
// Términos y la Privacidad" y al tocar el enlace se limitaba a COPIAR la URL
// al portapapeles, porque `url_launcher` no estaba en `pubspec.yaml`. El
// usuario aceptaba un texto que no podía leer desde el teléfono.
//
// EL 404 SE CUENTA ANTES DE SALIR DE LA APP. La landing todavía no está
// publicada: hasta que el dueño la suba, esas tres URLs devuelven 404 y lo
// honesto es decirlo, no expulsar al usuario a una página de error de GitHub
// y dejarlo ahí. Por eso hay una comprobación HEAD con tope de tiempo:
//   · 404 o 410  → se avisa de que aún no está publicado y se copia el
//                  enlace, que es una acción real y verificable.
//   · cualquier otra respuesta, o un fallo de red → se abre igual. Si no hay
//     conexión, el navegador lo dirá mejor que nosotros, y un bloqueo de
//     CORS en web no es motivo para no abrir nada.
//
// LA COMPROBACIÓN NO ES UNA GARANTÍA y no se presenta como tal: entre el HEAD
// y el toque del navegador puede cambiar todo. Solo cubre el caso conocido.
// ═══════════════════════════════════════════════════════════════════════

/// Cuánto se espera a la comprobación antes de abrir de todas formas.
///
/// Corto a propósito: es un trámite previo a un toque, no una carga.
const Duration _topeComprobacion = Duration(seconds: 3);

/// Lanza la URL en el navegador del sistema. Inyectable para las pruebas.
@visibleForTesting
Future<bool> Function(Uri uri) debugLanzadorDeEnlaces = _lanzar;

/// Devuelve el código HTTP de la URL, o `null` si no se pudo saber.
/// Inyectable para las pruebas.
@visibleForTesting
Future<int?> Function(Uri uri) debugComprobadorDeEnlaces = _comprobar;

Future<bool> _lanzar(final Uri uri) => launchUrl(
      uri,
      // Navegador del sistema, no una vista dentro de la app: un texto legal
      // tiene que poder guardarse, compartirse y verse la barra de
      // direcciones.
      mode: LaunchMode.externalApplication,
    );

Future<int?> _comprobar(final Uri uri) async {
  try {
    final respuesta = await http.head(uri).timeout(_topeComprobacion);
    return respuesta.statusCode;
  } on Object catch (e) {
    // Sin red, DNS caído, CORS en web, tope de tiempo: no se sabe el estado.
    debugPrint('No se pudo comprobar $uri: $e');
    return null;
  }
}

/// Resultado de intentar abrir un enlace. Se devuelve para que las pruebas
/// y el llamante puedan reaccionar; la pantalla normal lo ignora porque el
/// aviso ya se mostró.
enum ResultadoEnlace {
  /// El navegador lo tomó.
  abierto,

  /// La dirección devolvió 404 o 410: todavía no está publicada.
  noPublicado,

  /// No hubo navegador que lo abriera.
  sinNavegador,

  /// La URL no es válida.
  urlInvalida,
}

/// Abre [url] en el navegador del sistema y avisa si no se pudo.
///
/// Cuando falla, copia el enlace al portapapeles: así el usuario conserva
/// algo con lo que llegar al texto desde otro sitio.
Future<ResultadoEnlace> abrirEnlaceExterno(
  final BuildContext context,
  final String url,
) async {
  final uri = Uri.tryParse(url);
  if (uri == null || !uri.hasScheme) {
    if (context.mounted) {
      AppFeedback.showError(context, 'Ese enlace no es válido: $url');
    }
    return ResultadoEnlace.urlInvalida;
  }

  final codigo = await debugComprobadorDeEnlaces(uri);
  if (codigo == 404 || codigo == 410) {
    await _copiar(url);
    if (context.mounted) {
      AppFeedback.showError(
        context,
        'Esa página todavía no está publicada. Copiamos el enlace para que '
        'puedas abrirlo más tarde.',
      );
    }
    return ResultadoEnlace.noPublicado;
  }

  bool abierto;
  try {
    abierto = await debugLanzadorDeEnlaces(uri);
  } on Object catch (e) {
    debugPrint('No se pudo abrir $uri: $e');
    abierto = false;
  }

  if (abierto) return ResultadoEnlace.abierto;

  await _copiar(url);
  if (context.mounted) {
    AppFeedback.showError(
      context,
      'No se pudo abrir el navegador. Copiamos el enlace al portapapeles.',
    );
  }
  return ResultadoEnlace.sinNavegador;
}

Future<void> _copiar(final String url) =>
    Clipboard.setData(ClipboardData(text: url));
