import 'package:flutter/material.dart';
import '../constants/app_constants.dart';
import 'pagate_primary_button.dart';

// ═══════════════════════════════════════════════════════════════════════
// ESTADO DE ERROR
// ═══════════════════════════════════════════════════════════════════════
// Especificación: docs/DISENO-v2.md, componente 11.
//
// AHORA SÍ ESTÁ EN EL BARREL. El archivo anterior lo admitía en su propio
// docstring —"No está en el barrel; impórtalo directo"— y el barrel
// exportaba nueve de los diez componentes. Un estado de error que cuesta
// más importar que escribir a mano es un estado de error que nadie usa, y
// por eso había pantallas que ante un fallo mostraban "$0".
//
// QUÉ SE BORRÓ: el icono de 48 dp, el `Center`, el `textAlign: center` y el
// radio pastilla. Queda un bloque alineado a la izquierda, con fondo
// `dangerSurface` #FBEAE8 y borde `danger`, que es lo que lo distingue del
// estado vacío sin gastar un icono.
//
// EL MENSAJE QUE LLEGA ES EL DEL SERVIDOR. Esta pantalla no lo reescribe ni
// lo adorna: el principio 5 de docs/ARQUITECTURA.md prohíbe presentar un
// fallo como si el usuario no tuviera datos.
// ═══════════════════════════════════════════════════════════════════════

/// Bloque de error con reintento.
///
/// Se usa cuando un stream o una carga falla: sin conexión, sin permisos,
/// cuota agotada. Nunca para un resultado vacío, que es [PagateEmptyState].
class PagateErrorState extends StatelessWidget {
  /// Texto del error, tal como lo entrega el proveedor.
  final String message;

  /// Reintento. Si es `null` no se dibuja el botón, lo que solo tiene
  /// sentido cuando el error no es recuperable desde esta pantalla.
  final VoidCallback? onRetry;

  /// Título del bloque. El valor por defecto cubre el caso corriente.
  final String title;

  /// **Se acepta y se ignora.** El sistema no lleva icono en el estado de
  /// error: el fondo y el borde ya lo distinguen, y el icono de 48 dp
  /// ocupaba el alto de tres líneas de texto.
  ///
  /// Sigue en el constructor para que los tres call sites compilen sin
  /// tocarlos; cada pantalla lo borra en su paso.
  @Deprecated('El sistema no lleva icono en el estado de error. Quita el '
      'argumento al migrar la pantalla; el parámetro se borra después.')
  final IconData? icon;

  /// **Se acepta y se ignora.** Ya no hay dos versiones: el bloque es
  /// siempre el mismo y se adapta al ancho de su contenedor.
  @Deprecated('El estado de error ya no tiene variante compacta. Quita el '
      'argumento al migrar la pantalla; el parámetro se borra después.')
  final bool compact;

  const PagateErrorState({
    super.key,
    required this.message,
    this.onRetry,
    this.title = 'No se pudieron cargar los datos',
    // ignore: deprecated_member_use_from_same_package
    this.icon,
    // ignore: deprecated_member_use_from_same_package
    this.compact = false,
  });

  @override
  Widget build(final BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(horizontal: AppSpacing.x4),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.x4,
        vertical: AppSpacing.x6,
      ),
      decoration: BoxDecoration(
        color: AppPalette.dangerSurface,
        borderRadius: AppRadius.r8Border,
        border: Border.all(
          color: AppPalette.danger,
          width: AppSizes.borderHairline,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            title,
            style: theme.textTheme.titleLarge?.copyWith(
              color: AppPalette.danger,
            ),
          ),
          const SizedBox(height: AppSpacing.x2),
          Text(
            message,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: AppPalette.textPrimary,
            ),
          ),
          if (onRetry != null) ...[
            const SizedBox(height: AppSpacing.x4),
            Align(
              alignment: Alignment.centerLeft,
              child: PagatePrimaryButton.secondary(
                label: 'Reintentar',
                onPressed: onRetry,
                fullWidth: false,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
