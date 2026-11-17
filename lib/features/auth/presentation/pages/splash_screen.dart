import 'package:flutter/material.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/widgets/widgets.dart';

/// Pantalla de espera mientras se resuelve la sesión o se carga el perfil.
///
/// Paso 7 de docs/DISENO-v2.md: el cuadrado de 72 dp con degradado de marca,
/// glow verde y un `Icons.bolt_rounded` dentro —el segundo logotipo de la
/// app— pasa a [PagateWordmark], el único. El fondo lo pone
/// `scaffoldBackgroundColor`, así que el `backgroundColor` explícito —el
/// alias de lienzo del tema oscuro, que desde el paso 3 ya devolvía el
/// lienzo claro— se va.
class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(final BuildContext context) => const Scaffold(
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              PagateWordmark(size: PagateWordmarkSize.grande),
              SizedBox(height: AppSpacing.x8),
              SizedBox(
                width: AppIconSize.md,
                height: AppIconSize.md,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ],
          ),
        ),
      );
}
