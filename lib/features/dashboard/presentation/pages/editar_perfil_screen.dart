import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../../../core/config/firebase_errors.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../core/widgets/widgets.dart';
import '../../../user_profile/domain/entities/user_profile_entity.dart';
import '../../../user_profile/presentation/providers/user_profile_provider.dart';

// ═══════════════════════════════════════════════════════════════════════
// EDITAR PERFIL
// ═══════════════════════════════════════════════════════════════════════
// Especificación: docs/DISENO-v2.md, paso 7.
//
// QUÉ SE SUSTITUYÓ Y POR QUÉ:
//
// · LAS CINCO ETIQUETAS EN VERSALITAS ("NOMBRE COMPLETO", "MONEDA"…) con
//   `letterSpacing: 1.2` escrito a mano sobre el gris del tema oscuro. La
//   etiqueta de campo del sistema vive DENTRO de [PagateTextField], en
//   `titleSmall` y en caja normal; las versalitas quedan solo para el
//   agrupador pegajoso de una lista larga.
//
// · LAS DIEZ PASTILLAS de rubro y moneda: `GestureDetector` sobre
//   `AnimatedContainer` de radio 100 con ~29 dp de caja táctil, el control
//   más pequeño de esta pantalla. Pasan a [PagateChipSelector], que es el
//   único patrón de selección del sistema y trae los 48 dp.
//
// · EL BOTÓN DE GUARDAR escrito a mano: `ElevatedButton` con
//   `backgroundColor`/`foregroundColor` fijados en el widget —que ganan
//   sobre el estado deshabilitado del tema, así que seguía viéndose verde
//   al estar apagado—, radio 24 y un `CircularProgressIndicator` que
//   SUSTITUÍA al texto, encogiendo el botón al pulsarlo. Pasa a
//   [PagatePrimaryButton], que dibuja el spinner encima del texto a
//   opacidad cero y conserva el ancho.
//
// · LOS CUATRO `AppFeedback.showError` DE VALIDACIÓN, uno por campo, que
//   aparecían de a uno y se iban solos. Pasan a `Form` + `validator`: el
//   mensaje queda bajo el campo que lo provoca y no se va hasta que se
//   corrige.
//
// · EL AVISO DE GUARDADO FALLIDO, que era otro aviso flotante efímero
//   sobre una pantalla con scroll. Pasa a [PagateInlineError] justo encima
//   del botón.
//
// Y GANA `PopScope`: el botón atrás ya no descarta cinco campos escritos
// sin preguntar.
// ═══════════════════════════════════════════════════════════════════════

class EditarPerfilScreen extends StatefulWidget {
  const EditarPerfilScreen({super.key});

  @override
  State<EditarPerfilScreen> createState() => _EditarPerfilScreenState();
}

class _EditarPerfilScreenState extends State<EditarPerfilScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nombre = TextEditingController();
  final _negocio = TextEditingController();
  final _meta = TextEditingController();

  String _rubro = '';
  String _moneda = kDefaultCurrency;
  bool _guardando = false;
  bool _cargado = false;

  /// Copia de los valores con los que se abrió la pantalla, para saber si
  /// hay algo que se perdería al salir.
  String _nombreInicial = '';
  String _negocioInicial = '';
  String _metaInicial = '';
  String _rubroInicial = '';
  String _monedaInicial = kDefaultCurrency;

  String? _errorGuardado;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_cargado) return;
    _cargado = true;

    final profile = context.read<UserProfileProvider>().profile;
    _nombre.text = _nombreInicial = profile?.name ?? '';
    _negocio.text = _negocioInicial = profile?.businessName ?? '';
    // La meta se muestra en dígitos pelados a propósito: el campo la lee con
    // `parseCurrencyInput`, que acepta los puntos de millar que escribe un
    // chileno, pero precargarla con puntos invitaba a borrarlos a mano.
    _meta.text = _metaInicial = profile?.monthlyGoal.toStringAsFixed(0) ?? '';
    _rubro = _rubroInicial = profile?.businessType ?? '';
    _moneda = _monedaInicial = profile?.currency ?? kDefaultCurrency;
  }

  @override
  void dispose() {
    _nombre.dispose();
    _negocio.dispose();
    _meta.dispose();
    super.dispose();
  }

  bool get _tieneCambios =>
      _nombre.text != _nombreInicial ||
      _negocio.text != _negocioInicial ||
      _meta.text != _metaInicial ||
      _rubro != _rubroInicial ||
      _moneda != _monedaInicial;

  /// Pregunta antes de perder lo escrito. `true` deja salir.
  Future<bool> _confirmarSalida() async {
    if (_guardando) return false;
    if (!_tieneCambios) return true;

    final salir = await showDialog<bool>(
      context: context,
      builder: (final dialogo) => AlertDialog(
        title: const Text('¿Descartar los cambios?'),
        content: const Text('Lo que cambiaste no se va a guardar.'),
        actions: [
          PagatePrimaryButton.text(
            label: 'Seguir editando',
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

  Future<void> _salir() async {
    if (await _confirmarSalida() && mounted) Navigator.pop(context);
  }

  Future<void> _guardar() async {
    if (_guardando) return;
    if (!(_formKey.currentState?.validate() ?? false)) return;

    // Mismo defecto que en el onboarding: "800.000" se guardaba como 800.
    final meta = parseCurrencyInput(_meta.text);
    if (meta == null) return;

    setState(() {
      _guardando = true;
      _errorGuardado = null;
    });

    try {
      await context.read<UserProfileProvider>().updateFromSetup(
            name: _nombre.text.trim(),
            businessName: _negocio.text.trim(),
            businessType: _rubro,
            currency: _moneda,
            monthlyGoal: meta,
          );
      if (!mounted) return;
      // Los valores guardados pasan a ser los iniciales: salir ya no pierde
      // nada y `PopScope` no vuelve a preguntar.
      _nombreInicial = _nombre.text;
      _negocioInicial = _negocio.text;
      _metaInicial = _meta.text;
      _rubroInicial = _rubro;
      _monedaInicial = _moneda;
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _guardando = false;
        _errorGuardado = describeFirebaseError(e);
      });
    }
  }

  @override
  Widget build(final BuildContext context) => PopScope(
        canPop: false,
        onPopInvokedWithResult: (final didPop, final _) async {
          if (didPop) return;
          await _salir();
        },
        child: Scaffold(
          appBar: AppBar(
            leading: IconButton(
              tooltip: 'Volver',
              icon: const Icon(Icons.arrow_back_rounded),
              onPressed: _salir,
            ),
            title: const Text('Editar perfil'),
          ),
          body: SafeArea(
            top: false,
            child: Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.x4,
                  AppSpacing.x4,
                  AppSpacing.x4,
                  AppSpacing.x8,
                ),
                children: [
                  PagateTextField(
                    labelText: 'Tu nombre',
                    controller: _nombre,
                    hintText: 'Nombre y apellido',
                    maxLength: 120,
                    textCapitalization: TextCapitalization.words,
                    textInputAction: TextInputAction.next,
                    autofillHints: const [AutofillHints.name],
                    validator: (final v) => (v == null || v.trim().isEmpty)
                        ? 'Escribe tu nombre'
                        : null,
                  ),
                  const SizedBox(height: AppSpacing.x4),

                  PagateTextField(
                    labelText: 'Nombre del negocio',
                    controller: _negocio,
                    hintText: 'Como lo conocen tus clientes',
                    maxLength: 120,
                    textCapitalization: TextCapitalization.words,
                    textInputAction: TextInputAction.next,
                    validator: (final v) => (v == null || v.trim().isEmpty)
                        ? 'Escribe el nombre de tu negocio'
                        : null,
                  ),
                  const SizedBox(height: AppSpacing.x6),

                  const _EtiquetaDeGrupo('Rubro'),
                  const SizedBox(height: AppSpacing.x2),
                  PagateChipSelector(
                    options: kBusinessTypes,
                    selected: {_rubro},
                    onToggle: (final tipo) => setState(() => _rubro = tipo),
                  ),
                  if (_rubro.isEmpty) ...[
                    const SizedBox(height: AppSpacing.x2),
                    const _AvisoDeGrupo('Elige el rubro de tu negocio'),
                  ],
                  const SizedBox(height: AppSpacing.x6),

                  const _EtiquetaDeGrupo('Moneda'),
                  const SizedBox(height: AppSpacing.x2),
                  PagateChipSelector(
                    options: kSupportedCurrencies,
                    selected: {_moneda},
                    onToggle: (final codigo) =>
                        setState(() => _moneda = codigo),
                  ),
                  const SizedBox(height: AppSpacing.x6),

                  PagateTextField.amount(
                    labelText: 'Meta de ingresos del mes',
                    controller: _meta,
                    hintText: '0',
                    helperText: 'Lo que quieres facturar en un mes',
                    textInputAction: TextInputAction.done,
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
                    ],
                    onFieldSubmitted: (final _) => _guardar(),
                    validator: (final v) {
                      final meta = parseCurrencyInput(v ?? '');
                      if (meta == null) return 'Ingresa una meta válida';
                      if (meta <= 0) return 'La meta debe ser mayor que cero';
                      return null;
                    },
                  ),

                  const SizedBox(height: AppSpacing.x8),

                  if (_errorGuardado != null) ...[
                    PagateInlineError(message: _errorGuardado),
                    const SizedBox(height: AppSpacing.x4),
                  ],
                  PagatePrimaryButton(
                    label: 'Guardar cambios',
                    isLoading: _guardando,
                    // El rubro no es un campo de texto, así que su validación
                    // no la puede hacer el `Form`: se comprueba aquí y el
                    // botón queda apagado hasta que haya uno elegido.
                    onPressed: _rubro.isEmpty ? null : _guardar,
                  ),
                ],
              ),
            ),
          ),
        ),
      );
}

/// Etiqueta de un grupo de controles que no es un campo de texto.
///
/// Mismo estilo que la etiqueta interna de [PagateTextField], para que el
/// formulario se lea con un solo criterio.
class _EtiquetaDeGrupo extends StatelessWidget {
  const _EtiquetaDeGrupo(this.texto);

  final String texto;

  @override
  Widget build(final BuildContext context) => Text(
        texto,
        style: Theme.of(context).textTheme.titleSmall?.copyWith(
              color: AppPalette.textSecondary,
            ),
      );
}

/// Mensaje de validación de un grupo de chips. Imita el `errorStyle` del
/// campo de texto para que los dos errores del formulario se vean igual.
class _AvisoDeGrupo extends StatelessWidget {
  const _AvisoDeGrupo(this.texto);

  final String texto;

  @override
  Widget build(final BuildContext context) => Text(
        texto,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: AppPalette.danger,
            ),
      );
}
