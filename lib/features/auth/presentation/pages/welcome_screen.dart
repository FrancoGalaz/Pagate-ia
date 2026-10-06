import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../../../../core/constants/app_brand.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/constants/app_links.dart';
import '../../../../core/utils/url_opener.dart';
import '../../../../core/widgets/widgets.dart';
import '../../../onboarding/presentation/pages/identity_step_screen.dart';
import 'login_screen.dart';

// ═══════════════════════════════════════════════════════════════════════
// PANTALLA DE BIENVENIDA
// ═══════════════════════════════════════════════════════════════════════
// Especificación: docs/DISENO-v2.md, "Pantalla de bienvenida".
//
// Es la primera pantalla que ve un revisor de Google Play y un usuario
// nuevo: tiene que contar qué hace la app en cinco segundos y no prometer
// nada que la app no haga.
//
// QUÉ SE BORRÓ Y POR QUÉ, una a una:
//
// · EL ORBE DE FONDO. Un `Positioned(top: -100, left: -50)` con un círculo
//   de 400×400 en marca al 8% envuelto en un filtro de desenfoque de 80 de
//   blur cuyo hijo era un `SizedBox.shrink()`: el filtro se aplicaba sobre
//   un área de 0×0, no producía ningún efecto visible y solo costaba un
//   `saveLayer`. Con él se va el `import 'dart:ui'`.
//
// · LA ILUSTRACIÓN ENTERA (340×340): un círculo de 280 con degradado
//   decorativo, un borde blanco al 50% sobre fondo claro (invisible), una
//   sombra de 40 de blur y un `Icons.handyman_outlined` de 80 dp al 30% de
//   opacidad sin función. Son ~380 dp que empujaban el mensaje real fuera
//   de la primera pantalla en dispositivos de 640 dp.
//
// · LAS DOS TARJETAS FLOTANTES con "GANANCIA +24%" y "STOCK Optimizado".
//   Cifras fabricadas presentadas con el lenguaje visual de un dato real
//   del usuario, en la pantalla donde todavía no hay usuario. Y un lector
//   de pantalla las leía literalmente como si fueran suyas.
//
// · "La primera herramienta financiera diseñada por y para artesanos":
//   afirmación de primacía no verificable. En la ficha de Play, material
//   para rechazo por afirmaciones engañosas.
//
// · EL BOTÓN DE APPLE, que solo mostraba "todavía no está disponible", y el
//   de Google, cuyo `isAvailable` es `kIsWeb`: en el APK que va a Play el
//   usuario veía dos opciones de arranque y la única visible era un botón
//   muerto. Queda un único botón primario.
//
// · El "(Gratis)" del botón: el precio va en la ficha de Play, no dentro de
//   un botón, y comprometerlo ahí ata el modelo de precios.
//
// · "¿Ya eres parte de la comunidad?" y el `TextDecoration.underline` sobre
//   media frase del titular: subrayar para dar énfasis es decoración, no
//   jerarquía.
//
// TODO ALINEADO A LA IZQUIERDA. Antes no quedaba un solo elemento alineado
// a la izquierda en toda la pantalla.
// ═══════════════════════════════════════════════════════════════════════

// Las direcciones de los textos legales viven en
// `core/constants/app_links.dart`: ahora las usan dos pantallas.

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(final BuildContext context) => Scaffold(
        body: SafeArea(
          child: LayoutBuilder(
            builder: (final context, final constraints) => SingleChildScrollView(
              child: ConstrainedBox(
                // El `Spacer` de la especificación necesita alto conocido;
                // con un mínimo igual al viewport, el bloque de acciones cae
                // al pie en una pantalla alta y la pantalla se desplaza en
                // una baja o con la fuente del sistema muy grande.
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: const IntrinsicHeight(child: _Contenido()),
              ),
            ),
          ),
        ),
      );
}

class _Contenido extends StatelessWidget {
  const _Contenido();

  @override
  Widget build(final BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.x4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: AppSpacing.x10),
          const PagateWordmark(),
          const SizedBox(height: AppSpacing.x10),

          // Dice literalmente lo que la app calcula, con las palabras que el
          // usuario usaría. Sustituye a "Tu talento crea, nosotros
          // calculamos", que es una promesa vaga.
          Text(
            'Saber cuánto ganas cada mes\ny cuánto vale tu hora.',
            style: theme.textTheme.headlineLarge,
          ),
          const SizedBox(height: AppSpacing.x4),
          Text(
            'Registra tus ventas y tus gastos en segundos. $kAppName '
            'calcula tu resultado del mes y el precio mínimo de tu trabajo.',
            style: theme.textTheme.bodyLarge?.copyWith(
              color: AppPalette.textSecondary,
            ),
          ),

          const SizedBox(height: AppSpacing.x8),

          // Tres afirmaciones comprobables, cada una con su feature en el
          // repo: FinancesProvider + months/, la feature hourly_value y
          // core/services/pdf_report_service.dart. Sin tarjeta, sin iconos
          // de colores y sin cifras.
          const _Prueba(
            icon: Icons.receipt_long_outlined,
            texto: 'Ingresos y gastos del mes, al día',
          ),
          const SizedBox(height: AppSpacing.x3),
          const _Prueba(
            icon: Icons.schedule_outlined,
            texto: 'Valor de tu hora según tus horas reales',
          ),
          const SizedBox(height: AppSpacing.x3),
          const _Prueba(
            icon: Icons.picture_as_pdf_outlined,
            texto: 'Reporte en PDF para tu contador',
          ),

          const Spacer(),
          const SizedBox(height: AppSpacing.x8),

          PagatePrimaryButton(
            label: 'Crear cuenta',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute<void>(
                builder: (final _) => const IdentityStepScreen(),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.x4),
          const _EnlaceSesion(),
          const SizedBox(height: AppSpacing.x4),
          const _LineaLegal(),
          const SizedBox(height: AppSpacing.x6),
        ],
      ),
    );
  }
}

/// Una de las tres pruebas: icono de contorno 20 dp y una línea de texto.
class _Prueba extends StatelessWidget {
  const _Prueba({required this.icon, required this.texto});

  final IconData icon;
  final String texto;

  @override
  Widget build(final BuildContext context) => Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // El icono es decorativo: el texto que va al lado lo dice todo. En
          // toda la app no había un solo `ExcludeSemantics`, y por eso el
          // lector de pantalla anunciaba adornos como si fueran contenido.
          ExcludeSemantics(
            child: Icon(icon, size: AppIconSize.sm, color: AppPalette.textMuted),
          ),
          const SizedBox(width: AppSpacing.x3),
          Expanded(
            child: Text(
              texto,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppPalette.textPrimary,
                  ),
            ),
          ),
        ],
      );
}

/// "¿Ya tienes cuenta? Inicia sesión", a la izquierda, dentro de un control
/// real de 48 dp de alto.
class _EnlaceSesion extends StatelessWidget {
  const _EnlaceSesion();

  @override
  Widget build(final BuildContext context) {
    final theme = Theme.of(context);

    return Align(
      alignment: Alignment.centerLeft,
      child: InkWell(
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute<void>(builder: (final _) => const LoginScreen()),
        ),
        borderRadius: AppRadius.r8Border,
        highlightColor: AppPalette.sunken,
        splashFactory: NoSplash.splashFactory,
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            minHeight: AppSizes.minTouchTarget,
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.x2,
              vertical: AppSpacing.x3,
            ),
            // Un solo `Text.rich` y no un `Row` de dos `Text`: una fila con
            // dos hijos de ancho intrínseco y sin `Flexible` es exactamente
            // la causa de los desbordes que hay que arreglar para publicar.
            // Como texto corrido, la frase se parte sola si no cabe.
            child: Text.rich(
              TextSpan(
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: AppPalette.textSecondary,
                ),
                children: [
                  const TextSpan(text: '¿Ya tienes cuenta? '),
                  TextSpan(
                    text: 'Inicia sesión',
                    style: theme.textTheme.titleSmall?.copyWith(
                      color: AppPalette.brand,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Línea legal con los dos enlaces reales.
///
/// LOS ENLACES ABREN DE VERDAD. Antes solo copiaban la dirección al
/// portapapeles porque `url_launcher` no estaba en `pubspec.yaml`: la línea
/// afirmaba que el usuario aceptaba unos términos y no había forma de
/// leerlos desde el teléfono. Si la landing todavía no está publicada,
/// `abrirEnlaceExterno` lo dice y copia el enlace, en lugar de expulsar al
/// usuario a un 404.
///
/// Antes de eso la línea respondía "puedes revisarlos desde configuración",
/// donde no existía ninguna sección de términos; ahora existe. Y en el
/// registro los dos enlaces estaban pintados en color de marca pero eran
/// `TextSpan` SIN `recognizer`: no respondían al toque.
class _LineaLegal extends StatefulWidget {
  const _LineaLegal();

  @override
  State<_LineaLegal> createState() => _LineaLegalState();
}

class _LineaLegalState extends State<_LineaLegal> {
  final TapGestureRecognizer _terminos = TapGestureRecognizer();
  final TapGestureRecognizer _privacidad = TapGestureRecognizer();

  @override
  void initState() {
    super.initState();
    _terminos.onTap = () => unawaited(_abrir(kUrlTerminos));
    _privacidad.onTap = () => unawaited(_abrir(kUrlPrivacidad));
  }

  @override
  void dispose() {
    _terminos.dispose();
    _privacidad.dispose();
    super.dispose();
  }

  Future<void> _abrir(final String url) async {
    if (!mounted) return;
    await abrirEnlaceExterno(context, url);
  }

  @override
  Widget build(final BuildContext context) {
    final theme = Theme.of(context);
    final base = theme.textTheme.bodySmall?.copyWith(
      color: AppPalette.textMuted,
    );
    final enlace = theme.textTheme.bodySmall?.copyWith(
      color: AppPalette.brand,
    );

    return Text.rich(
      TextSpan(
        style: base,
        children: [
          const TextSpan(text: 'Al continuar aceptas los '),
          TextSpan(text: 'Términos', style: enlace, recognizer: _terminos),
          const TextSpan(text: ' y la '),
          TextSpan(
            text: 'Política de privacidad',
            style: enlace,
            recognizer: _privacidad,
          ),
          const TextSpan(text: '.'),
        ],
      ),
    );
  }
}
