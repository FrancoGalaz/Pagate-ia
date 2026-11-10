import 'package:flutter/material.dart';
import '../constants/app_constants.dart';

// ═══════════════════════════════════════════════════════════════════════
// BOTÓN DEL SISTEMA — tres variantes, una sola clase
// ═══════════════════════════════════════════════════════════════════════
// Especificación: docs/DISENO-v2.md, componentes 1, 2 y 3.
//
// POR QUÉ UNA SOLA CLASE CON TRES CONSTRUCTORES y no tres widgets: las tres
// variantes comparten alto mínimo, caja táctil, estado de carga y regla de
// ancho. Separarlas garantizaba que una se quedara atrás, que es justo lo
// que pasó con el botón secundario, hoy escrito a mano en cada pantalla.
//
// QUÉ SE BORRÓ DE LA VERSIÓN ANTERIOR:
//   · El `Container` envolvente, que existía SOLO para llevar un glow verde
//     de marca bajo el botón principal de toda la app. El
//     sistema separa con línea y superficie, nunca con sombra.
//   · La propiedad pública `hasShadow`, que venía en `true` por defecto.
//     Verificado con grep: cero call sites la pasaban, así que quitarla no
//     rompe ninguna pantalla.
//   · El alto fijo de 56 y el radio pastilla de 100. Ahora 48 y 12, que es
//     lo que ya impone el tema (`elevatedButtonTheme`).
//
// LO QUE NO SE TOCA: la API pública (`label`, `onPressed`, `leadingIcon`,
// `trailingIcon`, `isLoading`), para que las doce pantallas que ya lo usan
// mejoren sin editar una línea.
// ═══════════════════════════════════════════════════════════════════════

/// Las tres jerarquías de acción del sistema.
enum PagateButtonVariant {
  /// Acción principal de la pantalla. Relleno de marca, texto blanco.
  primary,

  /// Acción alternativa. Fondo blanco con contorno.
  secondary,

  /// Acción terciaria dentro de una fila o un encabezado. Sin caja.
  text,
}

/// Botón del sistema visual.
///
/// Reposo / presionado / deshabilitado / foco / cargando salen del tema
/// (`elevatedButtonTheme`, `outlinedButtonTheme`, `textButtonTheme`), así que
/// este widget no declara ni un color: solo compone el contenido y garantiza
/// el comportamiento del estado de carga.
class PagatePrimaryButton extends StatelessWidget {
  /// Texto del botón. Nunca se abrevia ni se envuelve en dos líneas: si no
  /// cabe, se corta con puntos suspensivos y es señal de que el texto es
  /// demasiado largo.
  final String label;

  /// `null` deshabilita el botón. El estado deshabilitado del primario es
  /// fondo `sunken` con texto `textMuted` (4,77:1): antes era un relleno
  /// #CBD5E1 con texto blanco encima, 1,48:1, literalmente ilegible.
  final VoidCallback? onPressed;

  final IconData? trailingIcon;
  final IconData? leadingIcon;

  /// Mientras es `true` el botón no responde y el texto se sustituye por un
  /// indicador de 18 dp **manteniendo el ancho**, para que la fila no salte.
  ///
  /// Es la única supervivencia del `CircularProgressIndicator` en todo el
  /// sistema: cualquier otra espera se dibuja con [PagateSkeleton].
  final bool isLoading;

  /// Jerarquía de la acción.
  final PagateButtonVariant variant;

  /// Ancho completo, que es el caso por defecto. Se pone en `false` en los
  /// estados vacíos, donde el botón acompaña a un texto y ocupar toda la
  /// línea lo convertiría en el elemento dominante de la pantalla.
  final bool fullWidth;

  /// Pinta la variante `.text` en `danger` en vez de en `brand`. Solo para
  /// acciones destructivas ("Eliminar"), nunca para enfatizar.
  final bool isDestructive;

  const PagatePrimaryButton({
    super.key,
    required this.label,
    this.onPressed,
    this.trailingIcon,
    this.leadingIcon,
    this.isLoading = false,
    this.fullWidth = true,
  })  : variant = PagateButtonVariant.primary,
        isDestructive = false;

  /// Acción alternativa: fondo `surface`, contorno `border`, texto tinta.
  /// Acción principal que destruye algo (Borrar, Eliminar mi cuenta).
  /// Relleno carmesí: nunca la greda de la acción corriente.
  const PagatePrimaryButton.destructive({
    super.key,
    required this.label,
    this.onPressed,
    this.trailingIcon,
    this.leadingIcon,
    this.isLoading = false,
    this.fullWidth = true,
  })  : variant = PagateButtonVariant.primary,
        isDestructive = true;

  const PagatePrimaryButton.secondary({
    super.key,
    required this.label,
    this.onPressed,
    this.trailingIcon,
    this.leadingIcon,
    this.isLoading = false,
    this.fullWidth = true,
  })  : variant = PagateButtonVariant.secondary,
        isDestructive = false;

  /// Acción terciaria: sin caja, alto visible 40 y caja táctil 48. Se usa en
  /// el extremo derecho de un encabezado de sección ("Ver todos") y dentro de
  /// un estado vacío.
  ///
  /// Nunca va a ancho completo: un botón de texto que ocupa la línea entera
  /// se lee como una fila pulsable, no como una acción.
  const PagatePrimaryButton.text({
    super.key,
    required this.label,
    this.onPressed,
    this.trailingIcon,
    this.leadingIcon,
    this.isLoading = false,
    this.isDestructive = false,
  })  : variant = PagateButtonVariant.text,
        fullWidth = false;

  @override
  Widget build(final BuildContext context) {
    final isEnabled = onPressed != null && !isLoading;
    final child = _content(context);

    final button = switch (variant) {
      PagateButtonVariant.primary => ElevatedButton(
          onPressed: isEnabled ? onPressed : null,
          style: isDestructive
              ? _destructiveFilled.merge(fullWidth ? null : _shrinkToContent)
              : (fullWidth ? null : _shrinkToContent),
          child: child,
        ),
      PagateButtonVariant.secondary => OutlinedButton(
          onPressed: isEnabled ? onPressed : null,
          style: fullWidth ? null : _shrinkToContent,
          child: child,
        ),
      PagateButtonVariant.text => TextButton(
          onPressed: isEnabled ? onPressed : null,
          style: isDestructive ? _destructiveText : null,
          child: child,
        ),
    };

    // El ancho completo se pide con `SizedBox` y no con `minimumSize`
    // infinito para que el botón siga encogiendo dentro de una `Row`: es lo
    // que permite poner "+ Ingreso" y "− Gasto" uno al lado del otro.
    return fullWidth ? SizedBox(width: double.infinity, child: button) : button;
  }

  /// Contenido del botón.
  ///
  /// Cargando se dibuja en un [Stack] con el texto a opacidad cero debajo:
  /// así el botón conserva EXACTAMENTE el ancho que tenía y la pantalla no
  /// se recoloca al pulsar. Sustituir el texto por el indicador, como hacía
  /// la versión anterior, encogía el botón a 24 dp de ancho dentro de una
  /// fila.
  Widget _content(final BuildContext context) {
    final row = Row(
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (leadingIcon != null) ...[
          Icon(leadingIcon, size: _iconSize),
          const SizedBox(width: AppSpacing.x2),
        ],
        Flexible(
          child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
        ),
        if (trailingIcon != null) ...[
          const SizedBox(width: AppSpacing.x2),
          Icon(trailingIcon, size: _iconSize),
        ],
      ],
    );

    if (!isLoading) return row;

    return Stack(
      alignment: Alignment.center,
      children: [
        // `ExcludeSemantics` porque el lector de pantalla ya anuncia el
        // botón por su etiqueta; el texto fantasma lo repetiría.
        ExcludeSemantics(child: Opacity(opacity: 0, child: row)),
        SizedBox(
          width: _spinnerSize,
          height: _spinnerSize,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            valueColor: AlwaysStoppedAnimation<Color>(_spinnerColor),
          ),
        ),
      ],
    );
  }

  double get _iconSize =>
      variant == PagateButtonVariant.text ? AppIconSize.xs : AppIconSize.sm;

  /// 18 dp: cabe holgado en los 48 del primario y en los 40 del botón de
  /// texto sin empujar la altura.
  static const double _spinnerSize = 18;

  Color get _spinnerColor => switch (variant) {
        PagateButtonVariant.primary => AppPalette.textOnBrand,
        PagateButtonVariant.secondary => AppPalette.textPrimary,
        PagateButtonVariant.text =>
          isDestructive ? AppPalette.danger : AppPalette.brand,
      };

  /// El tema fija `minimumSize: Size(infinity, 48)` en el primario y en el
  /// secundario. Esto lo libera para los dos sitios donde el botón comparte
  /// línea con otro: el par Ingreso/Gasto de Inicio y el estado vacío.
  static const ButtonStyle _shrinkToContent = ButtonStyle(
    minimumSize: WidgetStatePropertyAll(Size(0, AppSizes.buttonHeight)),
  );

  /// Variante destructiva del botón de texto: `danger` sobre
  /// `dangerSurface` al pulsar, los dos verificados a 6,49:1.
  /// Relleno carmesí (blanco encima 7,38:1); deshabilitado igual que el
  /// primario del tema.
  static final ButtonStyle _destructiveFilled = ButtonStyle(
    backgroundColor: WidgetStateProperty.resolveWith(
      (final states) => states.contains(WidgetState.disabled)
          ? AppPalette.sunken
          : states.contains(WidgetState.pressed)
              ? AppPalette.textPrimary
              : AppPalette.danger,
    ),
  );

  static final ButtonStyle _destructiveText = ButtonStyle(
    foregroundColor: WidgetStateProperty.resolveWith(
      (final states) => states.contains(WidgetState.disabled)
          ? AppPalette.textMuted
          : AppPalette.danger,
    ),
    backgroundColor: WidgetStateProperty.resolveWith(
      (final states) => states.contains(WidgetState.pressed)
          ? AppPalette.dangerSurface
          : Colors.transparent,
    ),
  );
}
