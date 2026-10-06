import 'package:flutter/material.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_text.dart';

class AyudaScreen extends StatefulWidget {
  const AyudaScreen({super.key});

  @override
  State<AyudaScreen> createState() => _AyudaScreenState();
}

class _AyudaScreenState extends State<AyudaScreen> {
  int? _expandedIndex;

  static const List<Map<String, String>> _faqItems = [
    {
      'question': '¿Cómo registro un nuevo ingreso?',
      'answer':
          'En Inicio toca "Venta", o el botón de registrar en Finanzas. '
          'Escribe el título, el monto, la categoría y la fecha. Si fue un '
          'ingreso puedes anotar además con qué documento lo respaldaste y '
          'la comisión que te descontó el medio de pago.',
    },
    {
      'question': '¿Cómo funciona la meta mensual?',
      'answer':
          'Es el objetivo de ingresos del mes. Lo defines en tu perfil, en '
          '"Meta de ingresos", y la app te muestra cuánto te falta.',
    },
    {
      'question': '¿Cómo agrego productos al inventario?',
      'answer':
          'En Inventario, toca el botón + de la esquina inferior derecha. '
          'Completa los datos del producto o del material y guarda.',
    },
    {
      'question': '¿Para qué sirven el documento y la comisión de un ingreso?',
      'answer':
          'Para que después sepas de dónde viene cada peso. El documento '
          'anota si emitiste boleta de venta, boleta de honorarios o nada, y '
          'la comisión es lo que se quedó el medio de pago. Con eso el valor '
          'de tu hora se calcula sobre lo que de verdad recibiste. La app '
          'solo registra y ordena estos datos para que puedas revisarlos con '
          'tu contador: no calcula impuestos ni te dice cuánto declarar.',
    },
    {
      'question': '¿Qué significa el stock en rojo?',
      'answer':
          'El stock en rojo indica que el producto tiene 0 unidades disponibles (sin stock). El amarillo significa que está por debajo del mínimo configurado. El verde indica stock suficiente.',
    },
  ];

  @override
  Widget build(final BuildContext context) => Scaffold(
        backgroundColor: AppColors.backgroundDark,
        body: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.screenHorizontal,
                  AppSpacing.md,
                  AppSpacing.screenHorizontal,
                  AppSpacing.xl,
                ),
                child: Row(
                  children: [
                    IconButton(
                      tooltip: 'Volver',
                      icon: const Icon(Icons.arrow_back_rounded),
                      onPressed: () => Navigator.pop(context),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Text(
                      'Ayuda',
                      style: AppText.weight(
                        Theme.of(context).textTheme.headlineSmall!,
                        800,
                      ).copyWith(color: AppColors.textPrimaryDark),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.screenHorizontal),
                  children: [

                    Text(
                      'PREGUNTAS FRECUENTES',
                      style: AppText.weight(
                        Theme.of(context).textTheme.labelSmall!,
                        700,
                      ).copyWith(
                        color: AppColors.textSecondaryDark,
                        letterSpacing: 1.2,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),

                    Container(
                      decoration: BoxDecoration(
                        color: AppColors.surfaceDark,
                        borderRadius: AppRadius.xxlBorder,
                        border: Border.all(color: AppColors.borderDark),
                      ),
                      child: Column(
                        children: _faqItems
                            .asMap()
                            .entries
                            .map((final e) {
                          final i = e.key;
                          final faq = e.value;
                          final isLast = i == _faqItems.length - 1;
                          final isExpanded = _expandedIndex == i;

                          return Column(
                            children: [
                              GestureDetector(
                                onTap: () => setState(() =>
                                    _expandedIndex =
                                        isExpanded ? null : i),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: AppSpacing.md,
                                    vertical: AppSpacing.md,
                                  ),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          faq['question'] ?? '',
                                          style: AppText.weight(
                                            Theme.of(context).textTheme.bodyMedium!,
                                            600,
                                          ).copyWith(
                                            color: AppColors.textPrimaryDark,
                                          ),
                                        ),
                                      ),
                                      Icon(
                                        isExpanded
                                            ? Icons.keyboard_arrow_up_rounded
                                            : Icons
                                                .keyboard_arrow_down_rounded,
                                        color: AppColors.textSecondaryDark,
                                        size: 20,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              if (isExpanded)
                                Padding(
                                  padding: const EdgeInsets.fromLTRB(
                                    AppSpacing.md,
                                    0,
                                    AppSpacing.md,
                                    AppSpacing.md,
                                  ),
                                  child: Text(
                                    faq['answer'] ?? '',
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodyMedium
                                        ?.copyWith(
                                          color: AppColors.textSecondaryDark,
                                          height: 1.5,
                                        ),
                                  ),
                                ),
                              if (!isLast)
                                const Divider(
                                  height: 1,
                                  color: AppColors.borderDark,
                                  indent: AppSpacing.md,
                                  endIndent: AppSpacing.md,
                                ),
                            ],
                          );
                        }).toList(),
                      ),
                    ),

                    const SizedBox(height: AppSpacing.xxl),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
}
