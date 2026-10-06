import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../core/widgets/widgets.dart';
import '../bloc/hourly_rate_provider.dart';
import '../widgets/net_hourly_value_section.dart';

// ═══════════════════════════════════════════════════════════════════════
// VALOR DE TU HORA
// ═══════════════════════════════════════════════════════════════════════
// Especificación: docs/DISENO-v2.md, paso 7.
//
// Era la pantalla más lejana al sistema: su propio comentario de cabecera
// decía, en inglés, que sus rasgos eran el fondo en degradado, el cristal
// y las animaciones suaves.
//
// QUÉ SE SUSTITUYÓ Y POR QUÉ:
//
// · EL DEGRADADO DE FONDO de tres paradas (lienzo → marca al 10% → lienzo)
//   en diagonal. Sobre un lienzo claro el tramo verde al 10% es una mancha,
//   y el sistema no tiene degradados. Fondo plano del tema.
//
// · `GlassCard` y `PremiumTextField`, LOS DOS ARCHIVOS BORRADOS en este
//   paso. La tarjeta era la superficie del tema oscuro al 60%, con borde de
//   cristal de 1,5 dp y una sombra grande: blanco translúcido pensado para
//   ir sobre una
//   superficie oscura, es decir invisible sobre el lienzo claro, más una
//   sombra de 24 dp de blur. El campo "premium" era una etiqueta en
//   `titleMedium` 600 sobre un `TextFormField` con la decoración del tema:
//   exactamente lo que ya hace [PagateTextField], solo que sin
//   `autofillHints`, sin `textInputAction` y sin ocultar el contador de
//   caracteres. Ninguno de los dos tenía otro consumidor; lo verifiqué con
//   grep antes de borrarlos.
//
// · LA ANIMACIÓN DE ENTRADA (fade de 500 ms + slide de 0,3 de alto) con su
//   `AnimationController` y su `SingleTickerProviderStateMixin`. El sistema
//   no anima la entrada de una pantalla: la transición la pone el
//   Navigator, y encadenar las dos hace que el formulario entre dos veces.
//
// · LOS TRES DEGRADADOS DE MARCA (el cuadrado del icono de cabecera, el
//   bloque
//   de la cifra del diálogo y el fondo del botón).
//
// · EL `AlertDialog` DE ÉXITO, con la cifra en blanco sobre un bloque verde
//   y un `ElevatedButton` que el tema estira a ancho completo dentro del
//   `OverflowBar`. Pasa a hoja del sistema, con la cifra como lo que es: la
//   cifra dominante de la pantalla, en tinta y alineada a la izquierda.
//
// · EL AVISO AZUL del pie (`AppColors.info` #3B82F6, que da 3,68 sobre
//   blanco y NO cumple AA como texto normal; el token `info` ni existe en
//   la paleta v2, y esta pantalla era su único consumidor). Pasa a
//   superficie `sunken` con texto `textSecondary`, 6,91:1.
//
// · LOS TRES `validator` que leían el campo con `double.tryParse` y
//   `replaceAll(',', '')`: un sueldo escrito "1.000.000" como lo escribe un
//   chileno se guardaba como 1 peso y ninguna validación lo detectaba.
//   Ahora pasa por `parseCurrencyInput`, el único lector de montos de la
//   app, igual que el resto de los formularios.
// ═══════════════════════════════════════════════════════════════════════

class HourlyRateSetupPage extends StatefulWidget {
  const HourlyRateSetupPage({super.key});

  @override
  State<HourlyRateSetupPage> createState() => _HourlyRateSetupPageState();
}

class _HourlyRateSetupPageState extends State<HourlyRateSetupPage> {
  final _formKey = GlobalKey<FormState>();
  final _sueldo = TextEditingController();
  final _dias = TextEditingController();
  final _horas = TextEditingController();

  @override
  void dispose() {
    _sueldo.dispose();
    _dias.dispose();
    _horas.dispose();
    super.dispose();
  }

  Future<void> _calcular() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final provider = context.read<HourlyRateProvider>();
    final sueldo = parseCurrencyInput(_sueldo.text);
    if (sueldo == null) return;

    final guardado = await provider.calculateAndSave(
      desiredSalary: sueldo,
      workingDays: int.parse(_dias.text.trim()),
      hoursPerDay: double.parse(_horas.text.trim().replaceAll(',', '.')),
    );

    if (!mounted) return;
    if (!guardado) return; // El error lo pinta `_AvisoDeError`.

    await showPagateSheet<void>(
      context: context,
      builder: (final _) => _HojaDeResultado(
        valorHora: provider.currentRate?.hourlyValue ?? 0,
      ),
    );
  }

  @override
  Widget build(final BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: 'Volver',
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Valor de tu hora'),
      ),
      body: SafeArea(
        top: false,
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.only(bottom: AppSpacing.x8),
            children: [
              // ─── Qué hace esta pantalla ─────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.x4,
                  AppSpacing.x2,
                  AppSpacing.x4,
                  AppSpacing.x6,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '¿Cuánto quieres ganar?',
                      style: theme.textTheme.headlineLarge,
                    ),
                    const SizedBox(height: AppSpacing.x2),
                    Text(
                      'Dinos tu meta y las horas que trabajas, y calculamos '
                      'cuánto tendría que valer tu hora para llegar a ella.',
                      style: theme.textTheme.bodyLarge?.copyWith(
                        color: AppPalette.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),

              const _AvisoDeError(),

              // ─── Los tres datos ─────────────────────────────────
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.x4,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    PagateTextField.amount(
                      labelText: 'Sueldo que quieres al mes',
                      controller: _sueldo,
                      hintText: '0',
                      textInputAction: TextInputAction.next,
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
                      ],
                      validator: (final v) {
                        final sueldo = parseCurrencyInput(v ?? '');
                        if (sueldo == null) return 'Ingresa un sueldo válido';
                        if (sueldo <= 0) {
                          return 'Tiene que ser mayor que cero';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: AppSpacing.x4),

                    PagateTextField(
                      labelText: 'Días que trabajas al mes',
                      controller: _dias,
                      hintText: '20',
                      keyboardType: TextInputType.number,
                      textInputAction: TextInputAction.next,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                      ],
                      validator: (final v) {
                        final dias = int.tryParse((v ?? '').trim());
                        if (dias == null) return 'Escribe cuántos días';
                        if (dias <= 0 || dias > 31) {
                          return 'Entre 1 y 31 días';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: AppSpacing.x4),

                    PagateTextField(
                      labelText: 'Horas que trabajas al día',
                      controller: _horas,
                      hintText: '8',
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      textInputAction: TextInputAction.done,
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(
                          RegExp(r'^\d{0,2}([.,]\d{0,2})?'),
                        ),
                      ],
                      onFieldSubmitted: (final _) => _calcular(),
                      validator: (final v) {
                        final horas = double.tryParse(
                          (v ?? '').trim().replaceAll(',', '.'),
                        );
                        if (horas == null) return 'Escribe cuántas horas';
                        if (horas <= 0 || horas > 24) {
                          return 'Entre 1 y 24 horas';
                        }
                        return null;
                      },
                    ),

                    const SizedBox(height: AppSpacing.x6),
                    Consumer<HourlyRateProvider>(
                      builder: (final context, final provider, final child) =>
                          PagatePrimaryButton(
                        label: 'Calcular mi valor hora',
                        isLoading: provider.isSaving,
                        onPressed: _calcular,
                      ),
                    ),

                    const SizedBox(height: AppSpacing.x4),
                    const _Explicacion(),
                  ],
                ),
              ),

              // Contrato C-3: debajo de la meta, el hecho. Lo que le quedó
              // por hora este mes, con las comisiones del medio de pago ya
              // descontadas.
              //
              // Con su `Padding`: la sección no trae margen lateral propio
              // —antes lo heredaba del `EdgeInsets.all(24)` que envolvía la
              // pantalla entera— y en emulator-5554 la cifra y su etiqueta
              // salían pegadas al borde izquierdo de la pantalla.
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: AppSpacing.x4),
                child: NetHourlyValueSection(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Aviso visible si el valor hora guardado no se pudo leer, o si el guardado
/// falló.
///
/// Antes eran dos avisos distintos: el de lectura, una caja roja a mano con
/// `error.withValues(alpha: 0.1)`, y el de escritura, un `SnackBar` que se
/// iba. Los dos pasan al estado de error del sistema.
class _AvisoDeError extends StatelessWidget {
  const _AvisoDeError();

  @override
  Widget build(final BuildContext context) =>
      Consumer<HourlyRateProvider>(builder: (
        final context,
        final provider,
        final child,
      ) {
        final mensaje = provider.error ?? provider.saveError;
        if (mensaje == null) return const SizedBox.shrink();

        return Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.x6),
          child: PagateErrorState(
            title: provider.error != null
                ? 'No pudimos leer tu valor hora'
                : 'No se pudo guardar',
            message: mensaje,
            onRetry: provider.error != null ? provider.retry : null,
          ),
        );
      });
}

/// Qué es el valor hora y qué no es.
///
/// La última frase no sobra: sin ella la cifra se lee como un precio
/// recomendado, y la app mide, no asesora.
class _Explicacion extends StatelessWidget {
  const _Explicacion();

  @override
  Widget build(final BuildContext context) => Container(
        padding: const EdgeInsets.all(AppSpacing.x3),
        decoration: BoxDecoration(
          color: AppPalette.sunken,
          borderRadius: AppRadius.r8Border,
        ),
        child: Text(
          'Es tu meta dividida por las horas que trabajas: la referencia con '
          'la que puedes comparar lo que cobras. No es un precio '
          'recomendado.',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AppPalette.textSecondary,
              ),
        ),
      );
}

/// Hoja que muestra el valor hora recién calculado.
class _HojaDeResultado extends StatelessWidget {
  const _HojaDeResultado({required this.valorHora});

  final double valorHora;

  @override
  Widget build(final BuildContext context) {
    final theme = Theme.of(context);

    return PagateSheet(
      title: 'Tu valor hora objetivo',
      primaryAction: PagatePrimaryButton(
        label: 'Entendido',
        onPressed: () => Navigator.of(context).pop(),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // La cifra dominante de la hoja: alineada a la izquierda, en
          // figuras tabulares y sin abreviar.
          Text(
            formatCurrency(valorHora, currency: kFallbackCurrency),
            style: theme.textTheme.displayMedium,
          ),
          const SizedBox(height: AppSpacing.x2),
          Text(
            'Por cada hora que trabajes. Lo vuelves a ver en Configuración, '
            'en "Valor de tu hora".',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: AppPalette.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}
