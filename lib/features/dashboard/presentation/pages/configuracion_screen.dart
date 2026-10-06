import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/config/firebase_errors.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/constants/app_links.dart';
import '../../../../core/services/firebase_auth_service.dart';
import '../../../../core/utils/app_feedback.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../core/utils/url_opener.dart';
import '../../../../core/widgets/widgets.dart';
import '../../../hourly_value/presentation/bloc/hourly_rate_provider.dart';
import '../../../hourly_value/presentation/pages/hourly_rate_setup_page.dart';
import '../../../user_profile/domain/entities/user_profile_entity.dart';
import '../../../user_profile/presentation/providers/user_profile_provider.dart';
import 'editar_perfil_screen.dart';
import 'eliminar_cuenta_screen.dart';

// ═══════════════════════════════════════════════════════════════════════
// CONFIGURACIÓN
// ═══════════════════════════════════════════════════════════════════════
// Especificación: docs/DISENO-v2.md, paso 7.
//
// QUÉ SE SUSTITUYÓ Y POR QUÉ:
//
// · `_Section`: versalitas con `letterSpacing: 1.2` sobre un contenedor de
//   radio 32 con borde. Era uno de los dos criterios opuestos de título de
//   bloque que convivían en la app. Pasa a [PagateSectionHeader] +
//   [PagateSectionCard].
//
// · `_ItemRow`: la cuarta reimplementación de la fila etiqueta/valor, con
//   un cuadrado teñido de icono de 36 dp que robaba 48 dp de ancho al
//   texto. Pasa a [PagateDataRow], que trae el chevron, el fondo de
//   pulsación, el divisor a sangre y los 48 dp de alto mínimo.
//
// · `_Divider` con `indent`/`endIndent` de 16: el divisor del sistema va a
//   sangre completa, y además ya lo pone cada [PagateDataRow].
//
// · LA SECCIÓN "NOTIFICACIONES" COMPLETA. Sus dos filas ("Alertas de stock
//   bajo" y "Resumen semanal") respondían 'Todavía no está disponible.' No
//   hay notificaciones en el proyecto: ni `firebase_messaging` en
//   `pubspec.yaml`, ni permiso `POST_NOTIFICATIONS` en el manifiesto, ni
//   nada en `functions/`. Dos ajustes que no ajustan nada, en la pantalla
//   de ajustes, delante de un revisor de Google Play. Vuelven cuando haya
//   notificaciones de verdad.
//
// LO QUE NO SE TOCÓ: el orden de las secciones, los textos legales y la
// entrada de borrado de cuenta. Eso lo fijó la tarea C-3 y es requisito de
// la ficha de Play.
// ═══════════════════════════════════════════════════════════════════════

class ConfiguracionScreen extends StatelessWidget {
  const ConfiguracionScreen({super.key});

  @override
  Widget build(final BuildContext context) {
    final profile = context.watch<UserProfileProvider>().profile;
    final hourlyRate = context.watch<HourlyRateProvider>().currentRate;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: 'Volver',
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Configuración'),
      ),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.only(bottom: AppSpacing.x8),
          children: [
            // ─── Negocio ────────────────────────────────────────────
            const PagateSectionHeader(title: 'Negocio'),
            PagateSectionCard(
              child: Column(
                children: [
                  PagateDataRow(
                    label: 'Nombre del negocio',
                    value: (profile?.businessName.isNotEmpty ?? false)
                        ? profile!.businessName
                        : 'Sin definir',
                    onTap: () => _abrirEdicion(context),
                  ),
                  PagateDataRow(
                    label: 'Rubro',
                    value: (profile?.businessType.isNotEmpty ?? false)
                        ? profile!.businessType
                        : 'Sin definir',
                    onTap: () => _abrirEdicion(context),
                  ),
                  PagateDataRow(
                    label: 'Moneda',
                    value: profile?.currency ?? kDefaultCurrency,
                    onTap: () => _abrirEdicion(context),
                    showDivider: false,
                  ),
                ],
              ),
            ),

            // ─── Metas ──────────────────────────────────────────────
            const PagateSectionHeader(title: 'Metas'),
            PagateSectionCard(
              child: Column(
                children: [
                  PagateDataRow(
                    label: 'Meta de ingresos',
                    subtitle: 'Al mes',
                    value: formatCurrency(
                      profile?.monthlyGoal ?? 0,
                      currency: kFallbackCurrency,
                    ),
                    onTap: () => _abrirEdicion(context),
                  ),
                  PagateDataRow(
                    label: 'Valor de tu hora',
                    subtitle: hourlyRate == null
                        ? 'Calcular desde tu sueldo objetivo'
                        : 'Por hora trabajada',
                    value: hourlyRate == null
                        ? 'Calcular'
                        : formatCurrency(
                            hourlyRate.hourlyValue,
                            currency: kFallbackCurrency,
                          ),
                    valueColor: hourlyRate == null ? AppPalette.brand : null,
                    showDivider: false,
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute<void>(
                        builder: (final _) => const HourlyRateSetupPage(),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // ─── Seguridad ──────────────────────────────────────────
            const PagateSectionHeader(title: 'Seguridad'),
            PagateSectionCard(
              child: PagateDataRow(
                label: 'Cambiar contraseña',
                subtitle: 'Te llega un correo con el enlace',
                value: '',
                showDivider: false,
                onTap: () => unawaited(_resetPassword(context)),
              ),
            ),

            // ─── Legal ──────────────────────────────────────────────
            // LOS TEXTOS LEGALES, ALCANZABLES DESDE LA APP.
            //
            // Antes no existía esta sección y la pantalla de registro decía
            // que los términos se podían revisar desde Configuración: no
            // había nada que revisar. Ahora los tres enlaces abren de verdad
            // en el navegador del sistema, y si la landing aún no está
            // publicada se avisa y se copia el enlace en vez de dejar un 404
            // en pantalla.
            const PagateSectionHeader(title: 'Legal'),
            PagateSectionCard(
              child: Column(
                children: [
                  PagateDataRow(
                    label: 'Términos de uso',
                    subtitle: 'Se abre en el navegador',
                    value: '',
                    onTap: () =>
                        unawaited(abrirEnlaceExterno(context, kUrlTerminos)),
                  ),
                  PagateDataRow(
                    label: 'Política de privacidad',
                    subtitle: 'Se abre en el navegador',
                    value: '',
                    onTap: () =>
                        unawaited(abrirEnlaceExterno(context, kUrlPrivacidad)),
                  ),
                  // Distinta de "Eliminar cuenta" de más abajo: esa borra los
                  // datos desde la app; esta es la página pública que exige la
                  // ficha de Play, consultable sin instalar nada.
                  PagateDataRow(
                    label: 'Cómo borrar tu cuenta',
                    subtitle: 'Instrucciones en la web',
                    value: '',
                    showDivider: false,
                    onTap: () => unawaited(
                      abrirEnlaceExterno(context, kUrlBorradoCuenta),
                    ),
                  ),
                ],
              ),
            ),

            // ─── Cuenta ─────────────────────────────────────────────
            // Requisito de Google Play: la app tiene que ofrecer el borrado
            // de cuenta desde dentro, no solo desde una URL. Va en su propia
            // sección y al final, separada de los ajustes corrientes, porque
            // es la única acción de esta pantalla que no se puede deshacer.
            const PagateSectionHeader(title: 'Cuenta'),
            PagateSectionCard(
              child: PagateDataRow(
                label: 'Eliminar cuenta',
                subtitle: 'Borra todos tus datos',
                value: '',
                showDivider: false,

                // El icono en `danger` es lo que distingue esta fila ANTES
                // de tocarla: es la única acción de la pantalla que no se
                // puede deshacer. La fila anterior pintaba de rojo la
                // etiqueta entera, y [PagateDataRow] no tiñe etiquetas a
                // propósito —la jerarquía del sistema la lleva el valor—,
                // así que el aviso pasa al único sitio del componente
                // pensado para un control explícito.
                trailing: const Padding(
                  padding: EdgeInsets.only(left: AppSpacing.x2),
                  child: Icon(
                    Icons.delete_outline_rounded,
                    size: AppIconSize.sm,
                    color: AppPalette.danger,
                  ),
                ),
                onTap: () {
                  // El servicio de auth se lee aquí, en la pantalla que sí
                  // vive bajo los providers: la de borrado no depende de
                  // Firebase a propósito.
                  final auth = context.read<FirebaseAuthService>();
                  Navigator.push(
                    context,
                    MaterialPageRoute<void>(
                      builder: (final _) => EliminarCuentaScreen(
                        email: auth.email,
                        onDeleted: auth.signOut,
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Las tres filas de "Negocio" y la meta llevan al mismo formulario.
  void _abrirEdicion(final BuildContext context) => Navigator.push(
        context,
        MaterialPageRoute<void>(
          builder: (final _) => const EditarPerfilScreen(),
        ),
      );

  Future<void> _resetPassword(final BuildContext context) async {
    final auth = context.read<FirebaseAuthService>();
    final email = auth.email;
    if (email == null || email.isEmpty) {
      AppFeedback.showError(
        context,
        'No hay un correo asociado a esta cuenta.',
      );
      return;
    }
    try {
      await auth.sendPasswordReset(email: email);
      if (!context.mounted) return;
      AppFeedback.showMessage(
        context,
        'Correo de restablecimiento enviado a $email.',
      );
    } catch (e) {
      if (!context.mounted) return;
      AppFeedback.showError(context, describeFirebaseError(e));
    }
  }
}
