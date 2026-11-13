import 'package:flutter/material.dart';

import '../constants/app_brand.dart';
import '../constants/app_constants.dart';

// ═══════════════════════════════════════════════════════════════════════
// MARCA — UN SOLO LOGOTIPO
// ═══════════════════════════════════════════════════════════════════════
// Especificación: docs/DISENO-v2.md, "Pantalla de bienvenida" (la marca
// provisional) y paso 7 (unificación).
//
// Había dos dibujos y tres nombres repartidos en cuatro archivos; el porqué
// del nombre elegido está en `core/constants/app_brand.dart`. Aquí vive el
// ÚNICO dibujo: un cuadrado de marca de radio 8 y el nombre, en Manrope 700.
//
// QUÉ SE BORRÓ:
//
// · EL RAYO (`Icons.bolt_rounded`) sobre un cuadrado de 72 dp con
//   degradado de marca y glow verde al 40% que
//   presidía el login y el splash. Un rayo no dice nada de una app de
//   cuentas: es el icono genérico de "energía" o "rápido". Mientras no
//   exista un logotipo real, un cuadrado de marca es honesto y no finge
//   significar algo.
//
// · El cuadrado con el mismo degradado y el mismo rayo del rail de
//   escritorio,
//   que era el tercer dibujo distinto.
//
// Cuando exista un logotipo de verdad se cambia aquí y cambia en los cinco
// sitios a la vez. Eso es justamente el punto de que este archivo exista.
// ═══════════════════════════════════════════════════════════════════════

/// La marca de la app: cuadrado de marca y nombre.
class PagateWordmark extends StatelessWidget {
  /// Escala del cuadrado y del nombre.
  final PagateWordmarkSize size;

  /// `true` apila el nombre bajo el cuadrado y centra los dos.
  ///
  /// Es la variante del rail de escritorio, que mide 80 dp de ancho: en fila
  /// el nombre no cabe. Es el MISMO dibujo, solo con el nombre debajo.
  final bool apilada;

  const PagateWordmark({super.key, this.size = PagateWordmarkSize.normal})
      : apilada = false;

  /// Variante del rail de escritorio. Ver [apilada].
  const PagateWordmark.apilada({super.key})
      : size = PagateWordmarkSize.rail,
        apilada = true;

  @override
  Widget build(final BuildContext context) {
    final theme = Theme.of(context);

    final (double lado, TextStyle? estilo) = switch (size) {
      PagateWordmarkSize.rail => (
          AppSizes.avatarSmall,
          theme.textTheme.labelSmall?.copyWith(
            color: AppPalette.textSecondary,
          ),
        ),
      PagateWordmarkSize.normal => (
          _ladoNormal,
          theme.textTheme.headlineMedium,
        ),
      PagateWordmarkSize.grande => (
          _ladoGrande,
          theme.textTheme.displaySmall,
        ),
    };

    // Decorativo: el nombre que va al lado (o debajo) ya es la marca.
    final cuadrado = ExcludeSemantics(
      child: Container(
        width: lado,
        height: lado,
        decoration: const BoxDecoration(
          color: AppPalette.brand,
          borderRadius: BorderRadius.all(Radius.circular(AppRadius.r8)),
        ),
      ),
    );
    final nombre = Text(
      kAppName,
      style: estilo,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );

    if (apilada) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          cuadrado,
          const SizedBox(height: AppSpacing.x1),
          nombre,
        ],
      );
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        cuadrado,
        const SizedBox(width: AppSpacing.x2),

        // `Flexible` y no un `Text` suelto: en una `Row` los hijos sin flex
        // se miden con ancho infinito, así que el `maxLines: 1` no recorta y
        // la fila desborda. Medido: a 2,0x de fuente del sistema en una
        // pantalla de 360 dp, la marca de Bienvenida se salía 66 px.
        Flexible(child: nombre),
      ],
    );
  }

  static const double _ladoNormal = 28;
  static const double _ladoGrande = 40;
}

/// Las tres escalas de la marca.
///
/// [normal] es la de la cabecera de Bienvenida; [grande] la de las dos
/// pantallas donde la marca ES el contenido (login y splash); [rail] la del
/// rail de escritorio, que solo se usa desde [PagateWordmark.apilada].
enum PagateWordmarkSize { rail, normal, grande }
