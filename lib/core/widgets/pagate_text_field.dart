import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../constants/app_constants.dart';
import '../theme/app_text.dart';

// ═══════════════════════════════════════════════════════════════════════
// CAMPO DE FORMULARIO DEL SISTEMA
// ═══════════════════════════════════════════════════════════════════════
// Especificación: docs/DISENO-v2.md, componente 4.
//
// DOS DEFECTOS QUE ARREGLA, y ninguno es cosmético:
//
// 1. EL CAMPO ERA INVISIBLE. El tema anterior dejaba `border` y
//    `enabledBorder` en `BorderSide.none` sobre un relleno gris que contra
//    el blanco de la tarjeta daba 1,05:1. Ahora el contorno es
//    `borderField` #7E8794 sobre relleno blanco: 3,63:1, que es lo que pide
//    WCAG 1.4.11 cuando el límite del control es su único indicador.
//    El contorno lo pone el tema; aquí solo se compone.
//
// 2. NO HABÍA AUTOCOMPLETADO NI ENCADENAMIENTO. En todo `lib/` había UN
//    `textInputAction` y CERO `autofillHints`, porque el constructor no los
//    aceptaba: ninguna pantalla podía ponerlos aunque quisiera. Ahora están
//    en la API, y login y registro pueden envolverse en `AutofillGroup` con
//    `.name / .email / .newPassword`, `next` entre campos y `done` en el
//    último.
//
// LA ETIQUETA VA ENCIMA Y SIEMPRE VISIBLE, no flotando dentro del campo.
// Con etiqueta flotante, un campo relleno no dice qué contiene hasta que se
// vacía. Esto absorbe a `PagateLabel`, que pintaba versalitas con tracking
// 0,8 en un gris de 2,54:1 — un fallo de AA repetido en diecisiete sitios.
// ═══════════════════════════════════════════════════════════════════════

/// Campo de texto del sistema visual.
///
/// Variante `.amount` para montos: prefijo `$` fijo, cifras tabulares a
/// 20/600 y teclado numérico.
class PagateTextField extends StatefulWidget {
  /// Etiqueta encima del campo, en `titleSmall` 14/600 `textSecondary`, a
  /// 8 dp de la caja. Si es `null` no se dibuja nada y el campo queda a ras.
  final String? labelText;

  /// Texto guía dentro de la caja, en `bodyMedium` 14/400 `textMuted`
  /// (5,31:1). Dice un ejemplo, no repite la etiqueta.
  final String? hintText;

  final TextEditingController? controller;
  final FocusNode? focusNode;
  final TextInputType keyboardType;
  final bool isPassword;
  final bool readOnly;
  final bool enabled;
  final Widget? suffix;
  final String? Function(String?)? validator;
  final ValueChanged<String>? onChanged;
  final VoidCallback? onTap;
  final List<TextInputFormatter>? inputFormatters;
  final int? maxLength;
  final int maxLines;
  final bool autofocus;

  /// Qué hace la tecla de acción del teclado: `next` para saltar al campo
  /// siguiente, `done` en el último de un formulario.
  final TextInputAction? textInputAction;

  /// Se dispara con esa tecla. Es la mitad que faltaba de
  /// [textInputAction]: sin ella, `next` no lleva a ninguna parte.
  final ValueChanged<String>? onFieldSubmitted;

  /// Pistas para el gestor de contraseñas del sistema
  /// (`AutofillHints.email`, `.newPassword`, `.name`). Dentro de un
  /// `AutofillGroup` son lo que permite que Android ofrezca guardar la
  /// cuenta al registrarse.
  final Iterable<String>? autofillHints;

  final TextCapitalization textCapitalization;

  /// Texto de ayuda bajo el campo, en `bodySmall` `textMuted`. El mensaje de
  /// error lo pone el `validator` y tiene prioridad visual sobre este.
  final String? helperText;

  /// Variante de monto: prefijo `$` fijo, [AppText.amountField] 20/600
  /// tabular alineado a la derecha y teclado numérico.
  final bool isAmount;

  /// **Se acepta y se ignora.** El sistema no lleva iconos decorativos
  /// dentro del campo: el sobre, el candado, el lápiz y el dólar robaban
  /// 40 dp de ancho y repetían lo que la etiqueta ya dice.
  ///
  /// Sigue en el constructor para que los once call sites que lo pasan
  /// compilen sin tocarlos; cada pantalla lo borra cuando le toca su paso
  /// (R-6 para las cinco principales, R-7 para el resto). Cuando no quede
  /// ninguno, desaparece el parámetro.
  @Deprecated('El sistema no lleva iconos dentro del campo. Quita el '
      'argumento al migrar la pantalla; el parámetro se borra después.')
  final IconData? prefixIcon;

  const PagateTextField({
    super.key,
    this.labelText,
    this.hintText,
    this.controller,
    this.focusNode,
    this.keyboardType = TextInputType.text,
    this.isPassword = false,
    this.readOnly = false,
    this.enabled = true,
    this.suffix,
    this.validator,
    this.onChanged,
    this.onTap,
    this.inputFormatters,
    this.maxLength,
    this.maxLines = 1,
    this.autofocus = false,
    this.textInputAction,
    this.onFieldSubmitted,
    this.autofillHints,
    this.textCapitalization = TextCapitalization.none,
    this.helperText,
    // ignore: deprecated_member_use_from_same_package
    this.prefixIcon,
  }) : isAmount = false;

  /// Campo de monto. El `$` vive dentro de la caja como prefijo fijo en
  /// `textMuted`, así que el usuario escribe solo dígitos y la cifra queda
  /// alineada a la derecha, en la misma columna que el resto de los montos
  /// de la app.
  const PagateTextField.amount({
    super.key,
    this.labelText,
    this.hintText,
    this.controller,
    this.focusNode,
    this.readOnly = false,
    this.enabled = true,
    this.suffix,
    this.validator,
    this.onChanged,
    this.onTap,
    this.inputFormatters,
    this.autofocus = false,
    this.textInputAction,
    this.onFieldSubmitted,
    this.helperText,
    // ignore: deprecated_member_use_from_same_package
    this.prefixIcon,
  })  : isAmount = true,
        isPassword = false,
        keyboardType = const TextInputType.numberWithOptions(decimal: true),
        maxLength = null,
        maxLines = 1,
        autofillHints = null,
        textCapitalization = TextCapitalization.none;

  @override
  State<PagateTextField> createState() => _PagateTextFieldState();
}

class _PagateTextFieldState extends State<PagateTextField> {
  bool _isObscured = true;

  @override
  Widget build(final BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (widget.labelText != null) ...[
          Text(
            widget.labelText!,
            style: theme.textTheme.titleSmall?.copyWith(
              color: widget.enabled
                  ? AppPalette.textSecondary
                  : AppPalette.textMuted,
            ),
          ),
          const SizedBox(height: AppSpacing.x2),
        ],
        TextFormField(
          controller: widget.controller,
          focusNode: widget.focusNode,
          keyboardType: widget.keyboardType,
          obscureText: widget.isPassword && _isObscured,
          readOnly: widget.readOnly,
          enabled: widget.enabled,
          autofocus: widget.autofocus,
          validator: widget.validator,
          onChanged: widget.onChanged,
          onTap: widget.onTap,
          inputFormatters: widget.inputFormatters,
          maxLength: widget.maxLength,
          maxLines: widget.isPassword ? 1 : widget.maxLines,
          textInputAction: widget.textInputAction,
          onFieldSubmitted: widget.onFieldSubmitted,
          autofillHints: widget.autofillHints,
          textCapitalization: widget.textCapitalization,
          textAlign: widget.isAmount ? TextAlign.right : TextAlign.start,
          style: _textStyle(theme),
          decoration: InputDecoration(
            hintText: widget.hintText,
            helperText: widget.helperText,

            // Se apaga el contador de caracteres de Material: añade una
            // línea bajo cada campo con `maxLength` y no aporta nada en un
            // formulario de cuatro campos.
            counterText: '',

            // El `$` del campo de monto. Va dentro de la caja, en
            // `textMuted`, y NO es un icono decorativo: es parte del dato.
            prefixText: widget.isAmount ? r'$ ' : null,
            prefixStyle: widget.isAmount
                ? AppText.amountField.copyWith(color: AppPalette.textMuted)
                : null,
            suffixIcon: _buildSuffix(),

            // Sin `prefixIcon`. Los de sobre, candado, lápiz y dólar
            // robaban 40 dp al campo y repetían lo que la etiqueta ya dice.
            alignLabelWithHint: true,
          ),
        ),
      ],
    );
  }

  /// El texto escrito va en `bodyLarge` 16/400 tinta, o en
  /// [AppText.amountField] 20/600 tabular si es un monto.
  ///
  /// Solo lectura conserva el color de texto normal a propósito: un campo de
  /// solo lectura muestra un dato real y tiene que leerse; el gris se
  /// reserva para `enabled: false`, que WCAG 1.4.3 exime.
  TextStyle _textStyle(final ThemeData theme) {
    final base = widget.isAmount
        ? AppText.amountField
        : theme.textTheme.bodyLarge ?? AppText.bodyLarge;
    return base.copyWith(
      color: widget.enabled ? AppPalette.textPrimary : AppPalette.textMuted,
    );
  }

  Widget? _buildSuffix() {
    if (widget.isPassword) {
      return IconButton(
        tooltip: _isObscured ? 'Mostrar contraseña' : 'Ocultar contraseña',
        icon: Icon(
          _isObscured
              ? Icons.visibility_off_outlined
              : Icons.visibility_outlined,
          size: AppIconSize.sm,
        ),
        onPressed: () => setState(() => _isObscured = !_isObscured),
      );
    }
    return widget.suffix;
  }
}
