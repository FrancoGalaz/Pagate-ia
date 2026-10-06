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
import '../../../user_profile/presentation/providers/user_profile_provider.dart';
import '../../../hourly_value/presentation/bloc/hourly_rate_provider.dart';
import '../../../hourly_value/presentation/pages/hourly_rate_setup_page.dart';
import 'editar_perfil_screen.dart';
import 'eliminar_cuenta_screen.dart';
import '../../../../core/theme/app_text.dart';

class ConfiguracionScreen extends StatelessWidget {
  const ConfiguracionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final profile = context.watch<UserProfileProvider>().profile;
    final hourlyRate = context.watch<HourlyRateProvider>().currentRate;

    return Scaffold(
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
                    'Configuración',
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
                  _Section(
                    title: 'Negocio',
                    children: [
                      _ItemRow(
                        icon: Icons.store_outlined,
                        label: 'Nombre del negocio',
                        subtitle: profile?.businessName ?? 'No definido',
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => const EditarPerfilScreen()),
                        ),
                      ),
                      const _Divider(),
                      _ItemRow(
                        icon: Icons.build_outlined,
                        label: 'Tipo de negocio',
                        subtitle: profile?.businessType ?? 'No definido',
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => const EditarPerfilScreen()),
                        ),
                      ),
                      const _Divider(),
                      _ItemRow(
                        icon: Icons.currency_exchange_rounded,
                        label: 'Moneda',
                        subtitle: profile?.currency ?? 'CLP',
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => const EditarPerfilScreen()),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  _Section(
                    title: 'Metas',
                    children: [
                      _ItemRow(
                        icon: Icons.flag_outlined,
                        label: 'Meta de ingresos',
                        subtitle: '${formatCurrency(
                          profile?.monthlyGoal ?? 0,
                          currency: kFallbackCurrency,
                        )} mensuales',
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => const EditarPerfilScreen()),
                        ),
                      ),
                      const _Divider(),
                      _ItemRow(
                        icon: Icons.timer_outlined,
                        label: 'Valor hora',
                        subtitle: hourlyRate != null
                            ? '${formatCurrency(
                                hourlyRate.hourlyValue,
                                currency: kFallbackCurrency,
                              )}/h'
                            : 'Calcular desde sueldo objetivo',
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => const HourlyRateSetupPage()),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  _Section(
                    title: 'Seguridad',
                    children: [
                      _ItemRow(
                        icon: Icons.lock_outline_rounded,
                        label: 'Cambiar contraseña',
                        subtitle: 'Enviar correo de restablecimiento',
                        onTap: () => _resetPassword(context),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  _Section(
                    title: 'Notificaciones',
                    children: [
                      _ItemRow(
                        icon: Icons.notifications_outlined,
                        label: 'Alertas de stock bajo',
                        subtitle: 'Todavía no disponible',
                        onTap: () => AppFeedback.showMessage(
                          context,
                          'Todavía no está disponible.',
                        ),
                      ),
                      const _Divider(),
                      _ItemRow(
                        icon: Icons.bar_chart_rounded,
                        label: 'Resumen semanal',
                        subtitle: 'Todavía no disponible',
                        onTap: () => AppFeedback.showMessage(
                          context,
                          'Todavía no está disponible.',
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  // LOS TEXTOS LEGALES, ALCANZABLES DESDE LA APP.
                  //
                  // Antes no existía esta sección y la pantalla de registro
                  // decía que los términos se podían revisar desde
                  // Configuración: no había nada que revisar. Ahora los tres
                  // enlaces abren de verdad en el navegador del sistema, y si
                  // la landing aún no está publicada se avisa y se copia el
                  // enlace en vez de dejar un 404 en pantalla.
                  _Section(
                    title: 'Legal',
                    children: [
                      _ItemRow(
                        icon: Icons.description_outlined,
                        label: 'Términos de uso',
                        subtitle: 'Se abre en el navegador',
                        onTap: () => unawaited(
                          abrirEnlaceExterno(context, kUrlTerminos),
                        ),
                      ),
                      const _Divider(),
                      _ItemRow(
                        icon: Icons.privacy_tip_outlined,
                        label: 'Política de privacidad',
                        subtitle: 'Se abre en el navegador',
                        onTap: () => unawaited(
                          abrirEnlaceExterno(context, kUrlPrivacidad),
                        ),
                      ),
                      const _Divider(),
                      // Distinta de "Eliminar cuenta" de más abajo: esa
                      // borra los datos desde la app; esta es la página
                      // pública que exige la ficha de Play, consultable sin
                      // instalar nada.
                      _ItemRow(
                        icon: Icons.open_in_new_rounded,
                        label: 'Cómo borrar tu cuenta',
                        subtitle: 'Instrucciones publicadas en la web',
                        onTap: () => unawaited(
                          abrirEnlaceExterno(context, kUrlBorradoCuenta),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  // Requisito de Google Play: la app tiene que ofrecer el
                  // borrado de cuenta desde dentro, no solo desde una URL.
                  // Va en su propia seccion y al final, separada de los
                  // ajustes corrientes, porque es la unica accion de esta
                  // pantalla que no se puede deshacer.
                  _Section(
                    title: 'Cuenta',
                    children: [
                      _ItemRow(
                        icon: Icons.delete_outline_rounded,
                        label: 'Eliminar cuenta',
                        subtitle: 'Borra tus datos de forma permanente',
                        isDestructive: true,
                        onTap: () {
                          // El servicio de auth se lee aqui, en la pantalla
                          // que si vive bajo los providers: la de borrado no
                          // depende de Firebase a proposito.
                          final auth = context.read<FirebaseAuthService>();
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => EliminarCuentaScreen(
                                email: auth.email,
                                onDeleted: auth.signOut,
                              ),
                            ),
                          );
                        },
                      ),
                    ],
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

  Future<void> _resetPassword(BuildContext context) async {
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

class _Section extends StatelessWidget {
  final String title;
  final List<Widget> children;

  const _Section({required this.title, required this.children});

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title.toUpperCase(),
            style: AppText.weight(
              Theme.of(context).textTheme.labelSmall!,
              700,
            ).copyWith(color: AppColors.textSecondaryDark, letterSpacing: 1.2),
          ),
          const SizedBox(height: AppSpacing.sm),
          Container(
            decoration: BoxDecoration(
              color: AppColors.surfaceDark,
              borderRadius: AppRadius.xxlBorder,
              border: Border.all(color: AppColors.borderDark),
            ),
            child: Column(children: children),
          ),
        ],
      );
}

class _Divider extends StatelessWidget {
  const _Divider();

  @override
  Widget build(BuildContext context) => const Divider(
        height: 1,
        color: AppColors.borderDark,
        indent: AppSpacing.md,
        endIndent: AppSpacing.md,
      );
}

class _ItemRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String subtitle;
  final VoidCallback onTap;

  /// Pinta la fila en el color de accion destructiva. Lo usa "Eliminar
  /// cuenta": es la unica fila de esta pantalla que no se puede deshacer y
  /// tiene que distinguirse antes de tocarla, no despues.
  final bool isDestructive;

  const _ItemRow({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.onTap,
    this.isDestructive = false,
  });

  @override
  Widget build(BuildContext context) => GestureDetector(
        // `opaque`: sin esto el `GestureDetector` usa `deferToChild` y solo
        // responden los píxeles pintados, así que tocar el hueco entre la
        // etiqueta y el chevron no hacía nada. Comprobado en el emulador:
        // un toque en el centro de "Términos de uso" no abría el enlace.
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.sm,
          ),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: isDestructive
                      ? AppPalette.dangerSurface
                      : AppColors.brand.withValues(alpha: 0.1),
                  borderRadius: AppRadius.smBorder,
                ),
                child: Icon(
                  icon,
                  color: isDestructive ? AppPalette.danger : AppColors.brand,
                  size: 18,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: AppText.weight(
                        Theme.of(context).textTheme.bodyMedium!,
                        600,
                      ).copyWith(
                        color: isDestructive
                            ? AppPalette.danger
                            : AppColors.textPrimaryDark,
                      ),
                    ),
                    Text(
                      subtitle,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: AppColors.textSecondaryDark,
                          ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.chevron_right_rounded,
                color: AppColors.textSecondaryDark,
                size: 20,
              ),
            ],
          ),
        ),
      );
}
