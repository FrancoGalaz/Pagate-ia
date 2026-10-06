import 'package:flutter/material.dart';

import '../constants/app_constants.dart';
import '../theme/app_text.dart';

// ═══════════════════════════════════════════════════════════════════════
// AVISO FLOTANTE
// ═══════════════════════════════════════════════════════════════════════
// EL DEFECTO QUE ARREGLA, que era grave: esta clase usaba
// `ScaffoldMessenger.of(context).showSnackBar(...)`, y un `SnackBar` NO lo
// dibuja el messenger: lo dibuja cada `Scaffold` registrado en él, dentro de
// su propio árbol. Una hoja modal (`showModalBottomSheet`) y un diálogo viven
// en el *overlay* del Navigator, es decir POR ENCIMA del Scaffold de la
// pantalla, y ninguno de los dos trae Scaffold propio.
//
// Resultado: el aviso se pintaba debajo del velo y detrás de la hoja, justo
// en el borde inferior que la hoja ocupa. En el camino de ÉXITO la hoja se
// cerraba antes de avisar y por eso sí se veía; en el `catch` la hoja seguía
// abierta y el aviso quedaba invisible. Cualquier fallo al guardar un
// movimiento de dinero era, literalmente, un botón que no hacía nada.
//
// POR QUÉ NO BASTA EL MESSENGER RAÍZ: aunque se tome el `ScaffoldMessenger`
// de la raíz, el que PINTA sigue siendo el Scaffold de la pantalla, que está
// debajo de la hoja. Cambiar de messenger no mueve el píxel.
//
// LA SOLUCIÓN: una `OverlayEntry` en el overlay RAÍZ, insertada al final, que
// por construcción se pinta encima de todas las rutas, incluidas las hojas
// modales y los diálogos. Un solo arreglo cubre los cuarenta sitios que
// llaman a [showMessage] y también los que se escriban después.
//
// PARA UN ERROR DENTRO DE UN FORMULARIO, además de esto, existe
// `PagateInlineError`: un aviso que NO se va solo, al lado del botón que
// falló. El aviso flotante dura unos segundos; el de un guardado de dinero
// fallido tiene que poder volverse a leer.
//
// EL TIEMPO DE VIDA ES UNA ANIMACIÓN, NO UN `Timer`. Con `Timer` cada widget
// test que provoque un aviso termina con un temporizador pendiente y
// `testWidgets` lo marca como fallo; con un `AnimationController`,
// `pumpAndSettle()` lo resuelve igual que cualquier otra animación.
// ═══════════════════════════════════════════════════════════════════════

/// Intención del aviso. Decide color y cuánto dura.
enum AppFeedbackTone {
  /// Confirmación o dato. Fondo tinta.
  neutral,

  /// Algo falló. Fondo `dangerSurface` y dura más, porque hay que leerlo.
  error,
}

/// Avisos efímeros de la app.
///
/// Se pintan en el overlay raíz, así que son visibles también con una hoja
/// modal o un diálogo abiertos. Para un error de formulario que deba
/// permanecer, usa `PagateInlineError` en lugar de esto.
class AppFeedback {
  AppFeedback._();

  /// Aviso en pantalla, si hay alguno. Solo puede haber uno: el segundo
  /// retira al primero en vez de apilarse.
  static _AvisoActivo? _activo;

  /// Cuánto se queda quieto antes de desvanecerse.
  static const Duration _esperaNeutral = Duration(seconds: 3);
  static const Duration _esperaError = Duration(seconds: 6);

  /// Muestra un aviso neutro (confirmación, estado, dato).
  static void showMessage(
    final BuildContext context,
    final String message,
  ) =>
      _mostrar(context, message, AppFeedbackTone.neutral);

  /// Muestra un aviso de error. Dura más y va en color de peligro.
  static void showError(
    final BuildContext context,
    final String message,
  ) =>
      _mostrar(context, message, AppFeedbackTone.error);

  /// Retira el aviso visible. Lo usan las pruebas y el cierre de pantalla.
  static void dismiss() {
    _activo?.retirar();
    _activo = null;
  }

  static void _mostrar(
    final BuildContext context,
    final String message,
    final AppFeedbackTone tone,
  ) {
    // `rootOverlay: true`: el overlay del Navigator raíz. Es lo que pone el
    // aviso por encima de la hoja modal en vez de debajo.
    final overlay = Overlay.maybeOf(context, rootOverlay: true);
    if (overlay == null) {
      // Sin overlay no hay dónde pintar (puede pasar en un test que monte un
      // widget suelto). Se deja rastro en lugar de tragarse el mensaje.
      debugPrint('AppFeedback sin Overlay: $message');
      return;
    }

    dismiss();

    final activo = _AvisoActivo();
    activo.entrada = OverlayEntry(
      builder: (final _) => _AvisoFlotante(
        mensaje: message,
        tono: tone,
        espera: tone == AppFeedbackTone.error ? _esperaError : _esperaNeutral,
        alTerminar: () {
          if (_activo == activo) _activo = null;
          activo.retirar();
        },
      ),
    );
    _activo = activo;
    overlay.insert(activo.entrada!);
  }
}

/// Envoltorio de la `OverlayEntry` que garantiza que se retira y se libera
/// UNA sola vez: el aviso puede irse por el toque del usuario y por el final
/// de la animación, y `OverlayEntry.remove()` sobre una entrada ya retirada
/// lanza.
class _AvisoActivo {
  OverlayEntry? entrada;
  bool _retirada = false;

  void retirar() {
    if (_retirada) return;
    _retirada = true;
    final e = entrada;
    if (e == null) return;
    e.remove();
    e.dispose();
  }
}

/// El aviso en sí: una tarjeta al pie de la pantalla, por encima del teclado
/// y de la zona segura.
class _AvisoFlotante extends StatefulWidget {
  const _AvisoFlotante({
    required this.mensaje,
    required this.tono,
    required this.espera,
    required this.alTerminar,
  });

  final String mensaje;
  final AppFeedbackTone tono;
  final Duration espera;
  final VoidCallback alTerminar;

  @override
  State<_AvisoFlotante> createState() => _AvisoFlotanteState();
}

class _AvisoFlotanteState extends State<_AvisoFlotante>
    with SingleTickerProviderStateMixin {
  static const Duration _entrada = AppDurations.fast;
  static const Duration _salida = AppDurations.fast;

  late final AnimationController _control;
  late final Animation<double> _opacidad;
  late final Animation<double> _subida;

  @override
  void initState() {
    super.initState();

    final total = _entrada + widget.espera + _salida;
    _control = AnimationController(duration: total, vsync: this);

    // Pesos proporcionales a la duración de cada tramo: entrar, quedarse
    // quieto, salir. Así el tiempo de vida es una animación y no un `Timer`.
    final ms = total.inMilliseconds.toDouble();
    _opacidad = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(begin: 0, end: 1)
            .chain(CurveTween(curve: AppCurves.enter)),
        weight: _entrada.inMilliseconds / ms,
      ),
      TweenSequenceItem(
        tween: ConstantTween<double>(1),
        weight: widget.espera.inMilliseconds / ms,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 1, end: 0)
            .chain(CurveTween(curve: AppCurves.exit)),
        weight: _salida.inMilliseconds / ms,
      ),
    ]).animate(_control);

    // Baja 12 dp al entrar y se queda. No sube al salir: el desvanecido ya
    // cuenta la salida y un doble movimiento marea.
    _subida = Tween<double>(begin: -AppSpacing.x3, end: 0).animate(
      CurvedAnimation(
        parent: _control,
        curve: Interval(
          0,
          _entrada.inMilliseconds / ms,
          curve: AppCurves.enter,
        ),
      ),
    );

    _control.addStatusListener((final estado) {
      if (estado == AnimationStatus.completed) widget.alTerminar();
    });
    _control.forward();
  }

  @override
  void dispose() {
    _control.dispose();
    super.dispose();
  }

  @override
  Widget build(final BuildContext context) {
    final esError = widget.tono == AppFeedbackTone.error;
    final fondo = esError ? AppPalette.dangerSurface : AppPalette.textPrimary;
    final tinta = esError ? AppPalette.danger : AppPalette.surface;

    return Positioned(
      left: 0,
      right: 0,
      // ARRIBA, NO ABAJO, y no es una preferencia estética. En esta app la
      // acción principal de toda hoja y de toda pantalla está pegada al pie:
      // anclado abajo, el aviso tapaba durante seis segundos el botón que el
      // usuario acababa de pulsar (comprobado en el emulador, captura
      // `11-aviso-encima`). Arriba, además, el teclado abierto no entra en
      // juego y no hace falta compensar `viewInsets`.
      top: MediaQuery.paddingOf(context).top + AppSpacing.x2,
      child: AnimatedBuilder(
        animation: _control,
        builder: (final context, final hijo) => Opacity(
          opacity: _opacidad.value,
          child: Transform.translate(
            offset: Offset(0, _subida.value),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.x4,
              ),
              child: Semantics(
                // `liveRegion`: el lector de pantalla lo lee al aparecer. El
                // `SnackBar` lo hacía por su cuenta y una `OverlayEntry` no.
                liveRegion: true,
                container: true,
                child: Material(
                  color: fondo,
                  borderRadius: AppRadius.r12Border,
                  // Sin sombra: va sobre el velo de la hoja, que ya separa.
                  elevation: 0,
                  child: InkWell(
                    // Tocar lo cierra: un aviso de error de seis segundos
                    // encima de un formulario tiene que poder quitarse.
                    onTap: widget.alTerminar,
                    borderRadius: AppRadius.r12Border,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.x4,
                        vertical: AppSpacing.x3,
                      ),
                      child: Row(
                        children: [
                          Icon(
                            esError
                                ? Icons.error_outline_rounded
                                : Icons.info_outline_rounded,
                            size: AppIconSize.sm,
                            color: tinta,
                          ),
                          const SizedBox(width: AppSpacing.x3),
                          Expanded(
                            child: Text(
                              widget.mensaje,
                              style: AppText.weight(
                                Theme.of(context).textTheme.bodyMedium!,
                                500,
                              ).copyWith(color: tinta),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
