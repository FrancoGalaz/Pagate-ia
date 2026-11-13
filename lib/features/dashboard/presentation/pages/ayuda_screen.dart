import 'package:flutter/material.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/widgets/widgets.dart';

// ═══════════════════════════════════════════════════════════════════════
// AYUDA
// ═══════════════════════════════════════════════════════════════════════
// Especificación: docs/DISENO-v2.md, paso 7.
//
// QUÉ SE SUSTITUYÓ Y POR QUÉ:
//
// · LA CABECERA A MANO (un `Padding` con `Row` + `IconButton` + título)
//   pasa a `AppBar`, que ya trae del tema el fondo del lienzo, el título a
//   la izquierda en `headlineMedium`, cero elevación y el estilo de la
//   barra de estado.
//
// · EL CONTENEDOR DE RADIO 32 con borde alrededor de las cinco preguntas
//   pasa a [PagateSectionCard]: a sangre en móvil, con una línea arriba y
//   otra abajo. Las preguntas ganan los 32 dp de ancho que la caja les
//   quitaba, que en una pregunta de dos líneas se notan.
//
// · LAS VERSALITAS "PREGUNTAS FRECUENTES" con `letterSpacing: 1.2` escrito
//   a mano pasan a [PagateSectionHeader], el único criterio de título de
//   bloque del sistema.
//
// · EL `GestureDetector` DE CADA PREGUNTA, que no anunciaba rol ni estado
//   al lector de pantalla y no respondía al teclado, pasa a `InkWell` con
//   `Semantics(button: true, expanded:)`. Ahora TalkBack dice si la
//   respuesta está abierta o cerrada.
//
// · EL `Divider` CON `indent`/`endIndent` de 16: el divisor del sistema va
//   a sangre completa. Es lo que hace que la lista se lea como cartola.
// ═══════════════════════════════════════════════════════════════════════

/// Una pregunta frecuente y su respuesta.
///
/// Era un `Map<String, String>` con acceso por clave y `?? ''` en cada uso:
/// un error de tecleo en la clave daba una pregunta vacía en pantalla sin
/// que nada fallara.
class _Faq {
  const _Faq(this.pregunta, this.respuesta);

  final String pregunta;
  final String respuesta;
}

class AyudaScreen extends StatefulWidget {
  const AyudaScreen({super.key});

  @override
  State<AyudaScreen> createState() => _AyudaScreenState();
}

class _AyudaScreenState extends State<AyudaScreen> {
  int? _abierta;

  static const List<_Faq> _faqs = [
    _Faq(
      '¿Cómo registro un nuevo ingreso?',
      'En Inicio toca "Venta", o el botón de registrar en Finanzas. '
          'Escribe el título, el monto, la categoría y la fecha. Si fue un '
          'ingreso puedes anotar además con qué documento lo respaldaste y '
          'la comisión que te descontó el medio de pago.',
    ),
    _Faq(
      '¿Cómo funciona la meta mensual?',
      'Es el objetivo de ingresos del mes. Lo defines en tu perfil, en '
          '"Meta de ingresos", y la app te muestra cuánto te falta.',
    ),
    _Faq(
      '¿Cómo agrego productos al inventario?',
      'En Inventario, toca el botón + de la esquina inferior derecha. '
          'Completa los datos del producto o del material y guarda.',
    ),
    _Faq(
      '¿Para qué sirven el documento y la comisión de un ingreso?',
      'Para que después sepas de dónde viene cada peso. El documento '
          'anota si emitiste boleta de venta, boleta de honorarios o nada, y '
          'la comisión es lo que se quedó el medio de pago. Con eso el valor '
          'de tu hora se calcula sobre lo que de verdad recibiste. La app '
          'solo registra y ordena estos datos para que puedas revisarlos con '
          'tu contador: no calcula impuestos ni te dice cuánto declarar.',
    ),
    _Faq(
      '¿Qué significa el stock en rojo?',
      'Rojo quiere decir que no te queda ninguna unidad. Ámbar, que estás '
          'por debajo del mínimo que configuraste. Sin color, que tienes '
          'suficiente.',
    ),
  ];

  @override
  Widget build(final BuildContext context) => Scaffold(
        appBar: AppBar(
          leading: IconButton(
            tooltip: 'Volver',
            icon: const Icon(Icons.arrow_back_rounded),
            onPressed: () => Navigator.pop(context),
          ),
          title: const Text('Ayuda'),
        ),
        body: SafeArea(
          top: false,
          child: ListView(
            padding: const EdgeInsets.only(bottom: AppSpacing.x8),
            children: [
              const PagateSectionHeader(title: 'Preguntas frecuentes'),
              PagateSectionCard(
                child: Column(
                  children: [
                    for (var i = 0; i < _faqs.length; i++)
                      _FilaDeFaq(
                        faq: _faqs[i],
                        abierta: _abierta == i,
                        esUltima: i == _faqs.length - 1,
                        onToggle: () =>
                            setState(() => _abierta = _abierta == i ? null : i),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
}

/// Una pregunta pulsable con su respuesta debajo.
class _FilaDeFaq extends StatelessWidget {
  const _FilaDeFaq({
    required this.faq,
    required this.abierta,
    required this.esUltima,
    required this.onToggle,
  });

  final _Faq faq;
  final bool abierta;
  final bool esUltima;
  final VoidCallback onToggle;

  @override
  Widget build(final BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Semantics(
          button: true,
          expanded: abierta,
          child: Material(
            color: AppPalette.surface,
            child: InkWell(
              onTap: onToggle,
              highlightColor: AppPalette.sunken,
              splashFactory: NoSplash.splashFactory,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.x4,
                  vertical: AppSpacing.x3,
                ),
                child: ConstrainedBox(
                  // Mínimo, no fijo: a 2,0x la pregunta crece y la fila
                  // crece con ella en vez de recortar.
                  constraints: const BoxConstraints(minHeight: _altoMinimo),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          faq.pregunta,
                          style: theme.textTheme.titleMedium,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.x2),
                      ExcludeSemantics(
                        child: Icon(
                          abierta
                              ? Icons.keyboard_arrow_up_rounded
                              : Icons.keyboard_arrow_down_rounded,
                          size: AppIconSize.sm,
                          color: AppPalette.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
        if (abierta)
          ColoredBox(
            color: AppPalette.surface,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.x4,
                AppSpacing.x0,
                AppSpacing.x4,
                AppSpacing.x4,
              ),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  faq.respuesta,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: AppPalette.textSecondary,
                  ),
                ),
              ),
            ),
          ),
        if (!esUltima)
          const Divider(
            height: AppSizes.borderHairline,
            thickness: AppSizes.borderHairline,
            color: AppPalette.hairline,
          ),
      ],
    );
  }

  /// 24 de contenido + 12 + 12 de relleno = los 48 dp del sistema.
  static const double _altoMinimo = 24;
}
