import 'package:flutter/material.dart';
import '../constants/app_constants.dart';

/// Ícono de 18 dp en el oscuro, dentro de un cuadro `sunken` de 34 dp y
/// radio 10. Es la marca de la fila de formulario de la variante A.
/// Decorativo: la etiqueta de la fila ya dice lo mismo.
class PagateIconSquare extends StatelessWidget {
  final IconData icon;

  const PagateIconSquare({super.key, required this.icon});

  @override
  Widget build(final BuildContext context) => ExcludeSemantics(
        child: Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: AppPalette.sunken,
            borderRadius: AppRadius.r10Border,
          ),
          child: Icon(icon, size: 18, color: AppPalette.ink),
        ),
      );
}
