import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/constants/app_brand.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/services/firebase_auth_service.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../core/widgets/widgets.dart';
import '../../../dashboard/presentation/pages/ayuda_screen.dart';
import '../../../dashboard/presentation/pages/configuracion_screen.dart';
import '../../domain/entities/user_profile_entity.dart';
import '../providers/user_profile_provider.dart';

// ═══════════════════════════════════════════════════════════════════════
// PESTAÑA DE PERFIL
// ═══════════════════════════════════════════════════════════════════════
// Especificación: docs/DISENO-v2.md, paso 7.
//
// QUÉ SE SUSTITUYÓ Y POR QUÉ:
//
// · EL AVATAR: un círculo de 88 dp con degradado de marca y glow verde al
//   40% —la sombra que más daño hacía de las siete— con las iniciales en un `TextStyle` escrito a mano
//   (`fontSize: 28`, `fontFamily: 'Manrope'`, `fontWeight: w800`). Ese
//   estilo a mano era además inútil: sin `fontVariations` el w800 no movía
//   el eje de la fuente variable y se dibujaba en ExtraLight. Ahora es un
//   cuadrado de marca de radio 12 con las iniciales en el estilo del
//   sistema.
//
// · LA INSIGNIA "PRO": otra pastilla con degradado. Pasa a la insignia del
//   sistema (radio 4, superficie de marca, texto `brand`).
//
// · `_StatItem` × 3 DENTRO DE UNA TARJETA DE RADIO 32 con dos `Container`
//   de 1 dp hechos a mano como divisores verticales. Era la sexta
//   reimplementación de la fila etiqueta/valor, y la única en columnas: a
//   130% de fuente del sistema "Sin definir" no cabía en un tercio de
//   pantalla. Pasa a tres [PagateDataRow] en una [PagateSectionCard].
//
// · `_MenuItem` × 5: cinco `GestureDetector` sobre `Container` de radio 24
//   con un cuadrado teñido de icono de 36 dp cada uno. Pasan a `ListTile`,
//   cuyo píxel ya define el tema, dentro de una sección.
//
// · LOS DOS BOTONES MUERTOS, "Calificar la app" y "Compartir Págate-IA".
//   Los dos respondían 'Todavía no está disponible.' Una app que va a
//   revisión de Google Play no puede ofrecer dos entradas de menú que no
//   hacen nada: es material de rechazo por funcionalidad roto, y para el
//   usuario es peor que no tenerlas. Vuelven cuando exista `share_plus` y
//   un enlace real a la ficha.
// ═══════════════════════════════════════════════════════════════════════

class PerfilTab extends StatelessWidget {
  const PerfilTab({super.key});

  @override
  Widget build(final BuildContext context) {
    final profile = context.watch<UserProfileProvider>().profile;
    final theme = Theme.of(context);

    return ListView(
      padding: const EdgeInsets.only(bottom: AppSpacing.x8),
      children: [
        // ─── Identidad ──────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.x4,
            AppSpacing.x6,
            AppSpacing.x4,
            AppSpacing.x6,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              _Avatar(iniciales: profile?.avatarInitials ?? ''),
              const SizedBox(width: AppSpacing.x4),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      profile?.name ?? '',
                      style: theme.textTheme.headlineMedium,
                    ),
                    if ((profile?.businessName ?? '').isNotEmpty) ...[
                      const SizedBox(height: AppSpacing.x1),
                      Text(
                        profile!.businessName,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: AppPalette.textSecondary,
                        ),
                      ),
                    ],
                    if (profile?.isPro == true) ...[
                      const SizedBox(height: AppSpacing.x2),
                      const _InsigniaPro(),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),

        // ─── Datos del negocio ──────────────────────────────────────
        const PagateSectionHeader(title: 'Tu negocio'),
        PagateSectionCard(
          child: Column(
            children: [
              PagateDataRow(
                label: 'Moneda',
                value: profile?.currency ?? kDefaultCurrency,
              ),
              PagateDataRow(
                label: 'Meta de ingresos del mes',
                value: formatCurrency(
                  profile?.monthlyGoal ?? 0,
                  currency: kFallbackCurrency,
                ),
              ),
              PagateDataRow(
                label: 'Rubro',
                value: (profile?.businessType.isNotEmpty ?? false)
                    ? profile!.businessType
                    : 'Sin definir',
                showDivider: false,
              ),
            ],
          ),
        ),

        // ─── Menú ───────────────────────────────────────────────────
        const PagateSectionHeader(title: 'Tu cuenta'),
        PagateSectionCard(
          child: Column(
            children: [
              _FilaDeMenu(
                icon: Icons.settings_outlined,
                label: 'Configuración',
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute<void>(
                    builder: (final _) => const ConfiguracionScreen(),
                  ),
                ),
              ),
              const Divider(
                height: AppSizes.borderHairline,
                thickness: AppSizes.borderHairline,
                color: AppPalette.hairline,
              ),
              _FilaDeMenu(
                icon: Icons.help_outline_rounded,
                label: 'Ayuda',
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute<void>(
                    builder: (final _) => const AyudaScreen(),
                  ),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: AppSpacing.x8),

        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.x4),
          // El AuthGate vuelve a Bienvenida al cerrar la sesión: esta
          // pantalla no navega.
          child: PagatePrimaryButton.secondary(
            label: 'Cerrar sesión',
            leadingIcon: Icons.logout_rounded,
            onPressed: () => context.read<FirebaseAuthService>().signOut(),
          ),
        ),

        const SizedBox(height: AppSpacing.x6),
        Center(
          child: Text(
            '$kAppName 1.0.0',
            style: theme.textTheme.bodySmall?.copyWith(
              color: AppPalette.textMuted,
            ),
          ),
        ),
      ],
    );
  }
}

/// Cuadrado de marca con las iniciales. Decorativo: el nombre va al lado.
class _Avatar extends StatelessWidget {
  const _Avatar({required this.iniciales});

  final String iniciales;

  @override
  Widget build(final BuildContext context) => ExcludeSemantics(
        child: Container(
          width: AppSizes.avatarLarge,
          height: AppSizes.avatarLarge,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: AppPalette.brand,
            borderRadius: AppRadius.r12Border,
          ),
          child: Text(
            iniciales,
            style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                  color: AppPalette.textOnBrand,
                ),
          ),
        ),
      );
}

/// Insignia del plan. Radio 4, superficie de marca, sin degradado.
class _InsigniaPro extends StatelessWidget {
  const _InsigniaPro();

  @override
  Widget build(final BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.x2,
          vertical: AppSpacing.x1,
        ),
        decoration: BoxDecoration(
          color: AppPalette.brandSurface,
          borderRadius: AppRadius.r4Border,
          border: Border.all(
            color: AppPalette.brand,
            width: AppSizes.borderHairline,
          ),
        ),
        child: Text(
          'Plan Pro',
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: AppPalette.brand,
              ),
        ),
      );
}

/// Fila de navegación del menú. El píxel lo define `listTileTheme`.
class _FilaDeMenu extends StatelessWidget {
  const _FilaDeMenu({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(final BuildContext context) => ListTile(
        leading: Icon(icon, size: AppIconSize.sm),
        title: Text(label),
        trailing: const Icon(
          Icons.chevron_right_rounded,
          size: AppIconSize.sm,
        ),
        onTap: onTap,
      );
}
