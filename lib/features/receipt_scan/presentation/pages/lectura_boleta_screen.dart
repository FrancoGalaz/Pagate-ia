import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/utils/app_feedback.dart';
import '../../../../core/widgets/widgets.dart';
import '../../domain/entities/receipt_document.dart';
import '../../domain/entities/receipt_reading.dart';
import '../providers/receipt_scan_provider.dart';
import '../widgets/fila_articulo_propuesto.dart';
import '../widgets/hoja_revisar_articulo.dart';

// ═══════════════════════════════════════════════════════════════════════
// REVISAR LA BOLETA
// ═══════════════════════════════════════════════════════════════════════
// Especificación: apartado E del encargo del lector, sobre
// docs/DISENO-v2.md (tema claro único, todo a la izquierda, sin sombra,
// sin icono grande, tokens de `app_constants.dart`).
//
// ES UNA PANTALLA Y NO UNA HOJA. La lista propuesta puede llevar 40 filas:
// necesita su propio `Scaffold`, su `AppBar` con el botón de volver y una
// `PagateActionBar` fija abajo. Una hoja al 90% de alto con 40 filas
// dentro deja el botón de guardar fuera del alcance del pulgar.
//
// SIN BARRA DE PROGRESO MIENTRAS LEE. Ni ML Kit ni el rasterizado informan
// de avance, así que una barra que se mueve afirmaría algo que el código
// no sabe (principio 7 de docs/DISENO-v2.md). Se usa el esqueleto, que
// dice dónde va a estar el contenido sin prometer cuándo.
//
// EL ERROR DE GUARDADO VA DENTRO DE LA PANTALLA, no en un aviso flotante.
// El motivo está escrito en `inventario_tab.dart` y en
// `core/utils/app_feedback.dart`: un aviso de seis segundos encima del
// botón que el usuario acaba de pulsar tapa justo lo que tiene que volver
// a pulsar, y el `PagateInlineError` no se va solo.
// ═══════════════════════════════════════════════════════════════════════

class LecturaBoletaScreen extends StatefulWidget {
  const LecturaBoletaScreen({
    super.key,
    required this.documento,
    this.avisoDeEntrada,
  });

  /// El archivo que se va a leer. Se borra dentro del repositorio, haya ido
  /// bien o mal la lectura.
  final ReceiptDocument documento;

  /// Aviso que traía la entrada (por ejemplo "Llegaron 3 archivos. Leí el
  /// primero."). Se muestra junto a los de la lectura.
  final String? avisoDeEntrada;

  @override
  State<LecturaBoletaScreen> createState() => _LecturaBoletaScreenState();
}

class _LecturaBoletaScreenState extends State<LecturaBoletaScreen> {
  @override
  void initState() {
    super.initState();
    // Tras el primer frame: `procesar` notifica de forma sincrónica y
    // llamarlo durante `initState` dispararía un `setState` en construcción.
    WidgetsBinding.instance.addPostFrameCallback((final _) {
      if (!mounted) return;
      final provider = context.read<ReceiptScanProvider>();
      // `unawaited` no hace falta: el `await` se descarta a propósito y el
      // provider ya captura todos sus errores, pero se deja explícito para
      // el lint `unawaited_futures`.
      provider.procesar(widget.documento).ignore();
    });
  }

  Future<bool> _confirmarSalida() async {
    final provider = context.read<ReceiptScanProvider>();
    if (!provider.hayTrabajoQuePerder) return true;

    final salir = await showDialog<bool>(
      context: context,
      builder: (final dialogo) => AlertDialog(
        title: const Text('¿Descartar la lectura?'),
        content: const Text(
          'Se pierde la lista que revisaste. La boleta no se guardó en '
          'ningún sitio, así que tendrías que volver a leerla.',
        ),
        actions: [
          PagatePrimaryButton.text(
            label: 'Seguir revisando',
            onPressed: () => Navigator.pop(dialogo, false),
          ),
          PagatePrimaryButton.text(
            label: 'Descartar',
            isDestructive: true,
            onPressed: () => Navigator.pop(dialogo, true),
          ),
        ],
      ),
    );
    return salir ?? false;
  }

  Future<void> _guardar() async {
    final provider = context.read<ReceiptScanProvider>();
    final navigator = Navigator.of(context);
    final cuantos = provider.seleccionados;
    if (!await provider.guardar()) return;
    if (!mounted) return;
    navigator.pop();
    AppFeedback.showMessage(
      context,
      cuantos == 1
          ? '1 artículo agregado al inventario.'
          : '$cuantos artículos agregados al inventario.',
    );
  }

  Future<void> _revisar(final int indice) async {
    final provider = context.read<ReceiptScanProvider>();
    final corregido = await mostrarHojaRevisarArticulo(
      context,
      provider.items[indice],
    );
    if (corregido == null) return;
    provider.reemplazar(indice, corregido);
  }

  @override
  Widget build(final BuildContext context) {
    final provider = context.watch<ReceiptScanProvider>();

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (final didPop, final _) async {
        if (didPop) return;
        if (await _confirmarSalida()) {
          if (context.mounted) Navigator.of(context).pop();
        }
      },
      child: Scaffold(
        backgroundColor: AppPalette.canvas,
        appBar: AppBar(
          title: const Text('Revisar la boleta'),
          leading: IconButton(
            tooltip: 'Volver',
            icon: const Icon(Icons.arrow_back_rounded),
            onPressed: () async {
              if (await _confirmarSalida()) {
                if (context.mounted) Navigator.of(context).pop();
              }
            },
          ),
        ),
        // `SafeArea` obligatorio en el `body` (principio 12).
        body: SafeArea(
          child: _Cuerpo(
            provider: provider,
            alRevisar: _revisar,
            avisoDeEntrada: widget.avisoDeEntrada,
          ),
        ),
        bottomNavigationBar: _Pie(
          provider: provider,
          alGuardar: _guardar,
          alDescartar: () async {
            if (await _confirmarSalida()) {
              if (context.mounted) Navigator.of(context).pop();
            }
          },
        ),
      ),
    );
  }
}

// ─── Cuerpo ────────────────────────────────────────────────────────────

class _Cuerpo extends StatelessWidget {
  const _Cuerpo({
    required this.provider,
    required this.alRevisar,
    this.avisoDeEntrada,
  });

  final ReceiptScanProvider provider;
  final ValueChanged<int> alRevisar;
  final String? avisoDeEntrada;

  @override
  Widget build(final BuildContext context) {
    switch (provider.phase) {
      case ReceiptScanPhase.leyendo:
        return ListView(
          padding: const EdgeInsets.only(top: AppSpacing.x4),
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.x4),
              child: Text(
                'Leyendo la boleta…',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
            const SizedBox(height: AppSpacing.x3),
            PagateSectionCard(child: PagateSkeleton.rows(4)),
          ],
        );

      case ReceiptScanPhase.sinTexto:
        return ListView(
          padding: const EdgeInsets.only(top: AppSpacing.x6),
          children: const [
            PagateErrorState(
              title: 'No pude leer nada de esa imagen',
              message: 'Prueba con más luz, sin sombra encima, y con toda la '
                  'boleta dentro del encuadre. Si el papel está muy '
                  'desvaído, escribir la ficha a mano va a ser más rápido.',
            ),
          ],
        );

      case ReceiptScanPhase.errorDeLectura:
        return ListView(
          padding: const EdgeInsets.only(top: AppSpacing.x6),
          children: [
            PagateErrorState(
              title: provider.errorMessage ?? 'No pude leer ese archivo',
              message: provider.errorHint ??
                  'Prueba con una foto de la boleta impresa.',
            ),
          ],
        );

      case ReceiptScanPhase.revisando:
      case ReceiptScanPhase.guardando:
      case ReceiptScanPhase.guardado:
        return _ListaPropuesta(
          provider: provider,
          alRevisar: alRevisar,
          avisoDeEntrada: avisoDeEntrada,
        );
    }
  }
}

class _ListaPropuesta extends StatelessWidget {
  const _ListaPropuesta({
    required this.provider,
    required this.alRevisar,
    this.avisoDeEntrada,
  });

  final ReceiptScanProvider provider;
  final ValueChanged<int> alRevisar;
  final String? avisoDeEntrada;

  @override
  Widget build(final BuildContext context) {
    final items = provider.items;

    if (items.isEmpty) {
      return ListView(
        padding: const EdgeInsets.only(top: AppSpacing.x6),
        children: [
          const PagateSectionCard(
            child: PagateEmptyState(
              title: 'Leí la boleta pero no saqué ningún artículo',
              description: 'Puede que la foto haya salido con poco contraste, '
                  'o que esa boleta no tenga una lista de artículos que yo '
                  'sepa reconocer.',
            ),
          ),
        ],
      );
    }

    return ListView(
      padding: const EdgeInsets.only(top: AppSpacing.x4),
      children: [
        _FranjaDeAvisos(provider: provider, avisoDeEntrada: avisoDeEntrada),
        const SizedBox(height: AppSpacing.x4),
        PagateSectionCard(
          child: Column(
            children: [
              // Por índice y no por identidad: dos artículos con los mismos
              // campos son iguales, y comparar por valor marcaría los dos
              // como último dejando una fila sin divisor.
              for (var i = 0; i < items.length; i++)
                FilaArticuloPropuesto(
                  item: items[i],
                  mostrarDivisor: i != items.length - 1,
                  onAlternar: (final valor) =>
                      provider.alternar(i, valor: valor),
                  onAbrir: () => alRevisar(i),
                ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.x6),
      ],
    );
  }
}

/// Todo lo que hay que decirle al usuario sobre la calidad de esta lectura.
///
/// La última frase va SIEMPRE, en todos los casos, y ningún aviso
/// condicional la sustituye: lo que el reconocimiento no vio no aparece en
/// ninguna lista, así que es la única forma honesta de decir que la lista
/// puede estar incompleta.
class _FranjaDeAvisos extends StatelessWidget {
  const _FranjaDeAvisos({required this.provider, this.avisoDeEntrada});

  final ReceiptScanProvider provider;

  /// Lo que traía la entrada: "Llegaron 3 archivos. Leí el primero.".
  final String? avisoDeEntrada;

  List<String> _avisos() {
    final avisos = <String>[];

    // Primero el de la entrada: si llegaron tres archivos y solo se leyó
    // uno, eso explica por qué falta lo que falta, así que va antes de
    // cualquier observación sobre la calidad de la lectura.
    final entrada = avisoDeEntrada;
    if (entrada != null) avisos.add(entrada);

    switch (provider.degradation) {
      case ScanDegradation.ninguna:
        break;
      case ScanDegradation.sinConexion:
      case ScanDegradation.modeloFallo:
        avisos.add(
          'Ordené la lista yo sola, sin el asistente, y eso sale peor. '
          'Revísala con más cuidado.',
        );
      case ScanDegradation.sinCuota:
        avisos.add(
          provider.serverMessage ??
              'No quedan lecturas ordenadas por el asistente, así que ordené '
                  'la lista yo sola. Revísala con más cuidado.',
        );
      case ScanDegradation.modeloVacio:
        avisos.add(
          'El asistente no reconoció artículos en este texto, así que esta '
          'lista es la que armé yo sola.',
        );
    }

    // DOS AVISOS DISTINTOS, no uno. "Poco contraste" solo se puede
    // afirmar cuando ML Kit informó una confianza baja de verdad; decirlo
    // porque salieron dos artículos sería inventar una causa, y una boleta
    // de dos materiales es perfectamente normal. Lo que sí se puede
    // afirmar con pocos artículos es que salieron pocos.
    if (provider.confianzaBaja) {
      avisos.add(
        'El texto salió con poco contraste y puede estar mal leído.',
      );
    } else if (provider.items.length < 3) {
      avisos.add(
        'Saqué pocos artículos. Si la boleta tenía más, no los leí.',
      );
    }

    if (provider.truncated) {
      avisos.add(
        'La boleta tenía más de lo que caben en esta lista. Lo que sobró no '
        'lo leí.',
      );
    }

    avisos.add(
      'Lo que no aparezca en esta lista no lo leí. Compara con la boleta '
      'antes de guardar.',
    );
    return avisos;
  }

  @override
  Widget build(final BuildContext context) {
    final theme = Theme.of(context);
    final avisos = _avisos();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.x4),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(AppSpacing.x3),
        decoration: BoxDecoration(
          color: AppPalette.warningSurface,
          borderRadius: AppRadius.r8Border,
          border: Border.all(
            color: AppPalette.warning,
            width: AppSizes.borderHairline,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var i = 0; i < avisos.length; i++) ...[
              if (i > 0) const SizedBox(height: AppSpacing.x2),
              Text(
                avisos[i],
                style: theme.textTheme.bodySmall?.copyWith(
                  color: AppPalette.warning,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ─── Pie ───────────────────────────────────────────────────────────────

class _Pie extends StatelessWidget {
  const _Pie({
    required this.provider,
    required this.alGuardar,
    required this.alDescartar,
  });

  final ReceiptScanProvider provider;
  final Future<void> Function() alGuardar;
  final Future<void> Function() alDescartar;

  @override
  Widget build(final BuildContext context) {
    switch (provider.phase) {
      case ReceiptScanPhase.leyendo:
        return const SizedBox.shrink();

      case ReceiptScanPhase.sinTexto:
      case ReceiptScanPhase.errorDeLectura:
        return PagateActionBar(
          secondary: PagatePrimaryButton.text(
            label: 'Escribir la ficha a mano',
            onPressed: () => Navigator.of(context).pop(),
          ),
          child: PagatePrimaryButton(
            label: 'Probar con otra foto',
            onPressed: () => Navigator.of(context).pop(),
          ),
        );

      case ReceiptScanPhase.revisando:
      case ReceiptScanPhase.guardando:
      case ReceiptScanPhase.guardado:
        final cuantos = provider.seleccionados;
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (provider.saveError != null)
              ColoredBox(
                color: AppPalette.surface,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.x4,
                    AppSpacing.x3,
                    AppSpacing.x4,
                    0,
                  ),
                  child: PagateInlineError(message: provider.saveError),
                ),
              ),
            PagateActionBar(
              secondary: PagatePrimaryButton.text(
                label: 'Descartar la lectura',
                isDestructive: true,
                onPressed: provider.phase == ReceiptScanPhase.guardando
                    ? null
                    : () => alDescartar().ignore(),
              ),
              child: PagatePrimaryButton(
                label: _etiqueta(cuantos),
                isLoading: provider.phase == ReceiptScanPhase.guardando,
                onPressed: cuantos == 0 ? null : () => alGuardar().ignore(),
              ),
            ),
          ],
        );
    }
  }

  /// El recuento vivo. Deshabilitado con cero no dice "Guardar 0".
  static String _etiqueta(final int cuantos) {
    if (cuantos == 0) return 'Guardar artículos';
    if (cuantos == 1) return 'Guardar 1 artículo';
    return 'Guardar $cuantos artículos';
  }
}
