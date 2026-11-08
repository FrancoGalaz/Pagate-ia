import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../../../core/constants/app_brand.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/widgets.dart';

/// App mínima que se monta cuando `bootstrapFirebase()` falla antes de que
/// exista [PagateIAApp]. Sin esto el usuario vería una pantalla negra.
///
/// No depende de Firebase ni de providers: solo del tema y de los tokens.
/// [onRetry] debe volver a intentar el arranque y, si tiene éxito, montar la
/// app real con `runApp`.
///
/// Paso 7 de docs/DISENO-v2.md: el icono de 48 dp centrado y los tres
/// bloques de texto a mano pasan a [PagateErrorState]. El detalle técnico
/// del error solo se muestra en debug ([mostrarDetalle]); en release queda en
/// el log (`main.dart` lo imprime con `debugPrint`), no en pantalla.
class BootstrapErrorApp extends StatelessWidget {
  const BootstrapErrorApp({
    super.key,
    required this.error,
    required this.onRetry,
    this.mostrarDetalle = kDebugMode,
  });

  final Object error;
  final VoidCallback onRetry;

  /// Muestra la excepción debajo del mensaje. Por defecto solo en debug.
  final bool mostrarDetalle;

  @override
  Widget build(final BuildContext context) => MaterialApp(
        title: kAppName,
        debugShowCheckedModeBanner: false,
        theme: AppTheme.lightTheme,
        home: _BootstrapErrorView(
          error: error,
          onRetry: onRetry,
          mostrarDetalle: mostrarDetalle,
        ),
      );
}

class _BootstrapErrorView extends StatelessWidget {
  const _BootstrapErrorView({
    required this.error,
    required this.onRetry,
    required this.mostrarDetalle,
  });

  final Object error;
  final VoidCallback onRetry;
  final bool mostrarDetalle;

  @override
  Widget build(final BuildContext context) => Scaffold(
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.x6),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  PagateErrorState(
                    title: 'No pudimos iniciar la app',
                    message: 'Revisa tu conexión e inténtalo de nuevo. Si el '
                        'problema continúa, cierra la app y vuelve a abrirla.',
                    onRetry: onRetry,
                  ),
                  if (mostrarDetalle) ...[
                    const SizedBox(height: AppSpacing.x4),
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.x4,
                      ),
                      child: Text(
                        'Detalle: $error',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: AppPalette.textMuted,
                            ),
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
