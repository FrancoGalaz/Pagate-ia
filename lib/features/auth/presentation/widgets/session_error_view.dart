import 'package:flutter/material.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/widgets/widgets.dart';

/// Estado de error a pantalla completa con reintento y, opcionalmente,
/// cierre de sesión (útil cuando el perfil no se puede leer por permisos).
///
/// Paso 7 de docs/DISENO-v2.md: el icono de nube de 48 dp centrado, el
/// titular a mano con `AppText.weight(..., 800)` y el texto centrado pasan
/// al componente del sistema, [PagateErrorState], que ya trae la superficie
/// `dangerSurface` con borde `danger`, el título y el botón de reintentar.
/// Así este error se ve igual que los de Inicio, Finanzas e Inventario.
class SessionErrorView extends StatelessWidget {
  const SessionErrorView({
    super.key,
    required this.message,
    required this.onRetry,
    this.onSignOut,
  });

  final String message;
  final VoidCallback onRetry;
  final VoidCallback? onSignOut;

  @override
  Widget build(final BuildContext context) => Scaffold(
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  PagateErrorState(
                    title: 'No pudimos cargar tus datos',
                    message: message,
                    onRetry: onRetry,
                  ),
                  if (onSignOut != null) ...[
                    const SizedBox(height: AppSpacing.x4),
                    Padding(
                      padding:
                          const EdgeInsets.symmetric(horizontal: AppSpacing.x4),
                      child: PagatePrimaryButton.text(
                        label: 'Cerrar sesión',
                        onPressed: onSignOut,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      );
}
