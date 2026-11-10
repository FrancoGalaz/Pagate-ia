import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../../../../core/constants/app_constants.dart';
import '../../../../../core/theme/app_text.dart';
import '../../../../../core/utils/currency_formatter.dart';
import '../../../../../core/utils/month_labels.dart';
import '../../../../../core/widgets/widgets.dart';
import '../../../../auth/presentation/widgets/verificar_correo_banner.dart';
import '../../../../finances/domain/entities/finances_transaction_entity.dart';
import '../../../../finances/presentation/providers/finances_provider.dart';
import '../../../../hourly_value/presentation/bloc/hourly_rate_provider.dart';
import '../../../../inventory/domain/entities/inventory_item_entity.dart';
import '../../../../inventory/domain/entities/inventory_item_type.dart';
import '../../../../inventory/presentation/providers/inventory_provider.dart';
import '../../../../user_profile/presentation/providers/user_profile_provider.dart';

// ═══════════════════════════════════════════════════════════════════════
// PANTALLA DE INICIO
// ═══════════════════════════════════════════════════════════════════════
// Especificación: docs/DISENO-v2.md, "Pantalla de inicio".
//
// EL ORDEN ES EL DE LA PREGUNTA QUE EL USUARIO TRAE AL ABRIR LA APP:
// cuánto me queda → de dónde sale → cómo voy → registrar → cuánto vale mi
// hora → qué pasó → qué me falta.
//
// QUÉ SE BORRÓ Y POR QUÉ:
//
// · EL SALUDO CON EMOJI ("Hola, Camila 👋"). El nombre del negocio informa;
//   el saludo con emoji no. Y con él se van los tres datos inventados que
//   se presentaban como del usuario mientras el perfil cargaba: 'IA' como
//   iniciales, 'Artesano' y 'Mi Negocio'. Mientras no hay perfil se pinta
//   el esqueleto, no un nombre falso.
//
// · EL PUNTO ROJO DE NOTIFICACIONES. Ocho dp en `AppColors.error` SIN
//   NINGUNA CONDICIÓN: siempre encendido, sin sistema de notificaciones
//   detrás, y cuyo destino era la pantalla de Ayuda. El icono pasa de
//   campana a `help_outline`, que es lo que de verdad abre.
//
// · LA TARJETA DE BALANCE, que combinaba las cuatro cosas prohibidas a la
//   vez: degradado de marca, radio 32 y un glow verde al 40% con 24 dp de
//   blur. Encerrar la cifra en un degradado obliga a texto blanco sobre
//   verde, que es la razón por la que los dos mini-stats estaban en
//   `Colors.white70` y eran ilegibles. Ahora la cifra va sobre el lienzo,
//   en tinta, a 40/700: es lo primero que ve el ojo a un brazo de
//   distancia.
//
// · LAS CUATRO "ACCIONES RÁPIDAS" con sus cuatro colores hexadecimales
//   literales
//   —#00C2B8, #EF4444, #3B82F6, #F97316, de los cuales el turquesa y el
//   naranja ni siquiera existen en la paleta— y el icono de robot. Dos de
//   las cuatro (Inventario, IA) no eran acciones sino destinos que ya
//   están en la barra inferior: duplicar la navegación en la portada es
//   ruido. Quedan dos botones secundarios, Ingreso y Gasto.
//
// · LOS TRES GRÁFICOS. Sumaban ~834 dp de los ~1.697 de la pantalla: el
//   49% del scroll. En 360×800 eso empujaba la actividad reciente a 1,7
//   viewports. Y dos de los tres mostraban "Aún no hay datos mensuales"
//   hasta tener dos meses registrados, así que durante las primeras
//   semanas ese 49% era espacio vacío con un mensaje. Se van a Finanzas,
//   que es donde el usuario llega con intención de analizar.
//
// · LOS TÍTULOS GENÉRICOS EN TITLE CASE ("Balance del Mes", "Acciones
//   Rápidas", "Métricas Financieras", "Actividad Reciente"). En español la
//   mayúscula va solo en la primera palabra.
//
// EL ARREGLO FUNCIONAL MÁS IMPORTANTE: `_BalanceCard.build` NO CONSULTABA
// `finances.error` NI `isLoading` en ninguna línea, así que ante un
// `permission-denied` o un fallo de red mostraba "$0", la etiqueta "Sin
// datos" y "Registra tus primeros ingresos y gastos": presentaba un fallo
// como si el usuario no tuviera datos, contra el principio 5 de
// docs/ARQUITECTURA.md. Ahora los tres bloques de dinero comparten el
// mismo criterio: error → bloque de error con reintento; cargando →
// esqueleto; con datos → cifras.
//
// VARIANTE A (docs/diseno/variantes-cabal.html, opción 1 del valor hora):
// cabecera oscura con el saludo y una tarjeta superpuesta que reúne el
// balance, la meta («Ingresos: N % de tu meta»), ingresos y gastos, los dos
// botones de registrar y el valor de la hora en la franja del pie. Debajo,
// la guía de primeros pasos (solo sin movimientos), gastos fijos y stock
// bajo como filas, y los movimientos recientes.
//
// Y EL SELECTOR DE MES ARREGLA OTRO BUG, no es estética: Inicio y
// Finanzas leen el MISMO provider, cuyo resumen depende de
// `selectedMonthKey`. Tocar "julio" en Finanzas cambiaba el balance de
// Inicio sin decirlo. Con el selector visible, el mes deja de ser un
// estado invisible compartido.
// ═══════════════════════════════════════════════════════════════════════

/// Acciones que Inicio delega en el dashboard, que es quien sabe navegar.
class HomeTab extends StatelessWidget {
  const HomeTab({
    super.key,
    required this.onRegistrarIngreso,
    required this.onRegistrarGasto,
    required this.onVerFinanzas,
    required this.onVerInventario,
    required this.onVerValorHora,
    required this.onAyuda,
  });

  final VoidCallback onRegistrarIngreso;
  final VoidCallback onRegistrarGasto;
  final VoidCallback onVerFinanzas;
  final VoidCallback onVerInventario;
  final VoidCallback onVerValorHora;
  final VoidCallback onAyuda;

  @override
  Widget build(final BuildContext context) {
    // Cuántos meses hay que elegir, contando siempre el actual. Con uno
    // solo el selector no se dibuja, y entonces su banda tampoco debe
    // reservar alto.
    final meses = context.select<FinancesProvider, int>(
      (final p) => {
        for (final m in p.months) m.monthKey,
        FinancesProvider.currentMonthKey,
      }.length,
    );

    // La barra de estado va sobre el oscuro de la cabecera (el dashboard
    // pinta ese fondo en Inicio): íconos claros. El resto de la pantalla
    // sigue en el lienzo.
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: ColoredBox(
        color: AppPalette.canvas,
        child: CustomScrollView(
          slivers: [
            // El aviso va primero: con letra 2,0 la tarjeta del saldo ocupa la
            // pantalla entera y, debajo de ella, el aviso no se veía.
            const SliverToBoxAdapter(child: VerificarCorreoBanner()),
            SliverToBoxAdapter(
              child: _Portada(
                onAyuda: onAyuda,
                onIngreso: onRegistrarIngreso,
                onGasto: onRegistrarGasto,
                onValorHora: onVerValorHora,
              ),
            ),

            // El selector queda pegado arriba al desplazarse: es el filtro
            // global de la app y tiene que estar siempre a la vista. Va bajo la
            // tarjeta porque la tarjeta se monta sobre la cabecera oscura.
            SliverPersistentHeader(
              pinned: true,
              delegate: _SelectorPegajoso(visible: meses > 1),
            ),

            SliverToBoxAdapter(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _PrimerosPasos(
                    onValorHora: onVerValorHora,
                    onRegistrar: onRegistrarIngreso,
                    onInventario: onVerInventario,
                  ),
                  _Pendientes(
                    onFinanzas: onVerFinanzas,
                    onInventario: onVerInventario,
                  ),
                  _Movimientos(onVerTodos: onVerFinanzas),
                  const SizedBox(height: AppSpacing.x8),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Con letra de 1,5 o más los pares lado a lado se apilan, igual que en
/// [PagateDataRow].
bool _apilado(final BuildContext context) =>
    MediaQuery.textScalerOf(context).scale(10) >= 15;

// ─── Portada: cabecera oscura y tarjeta superpuesta ────────────────────

class _Portada extends StatelessWidget {
  const _Portada({
    required this.onAyuda,
    required this.onIngreso,
    required this.onGasto,
    required this.onValorHora,
  });

  final VoidCallback onAyuda;
  final VoidCallback onIngreso;
  final VoidCallback onGasto;
  final VoidCallback onValorHora;

  /// Lo que la tarjeta se monta sobre la cabecera.
  static const double _solape = 48;

  @override
  Widget build(final BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      ColoredBox(
        color: AppPalette.ink,
        child: _BarraIdentidad(onAyuda: onAyuda),
      ),
      Stack(
        children: [
          // La cabecera sigue detrás de la parte alta de la tarjeta y
          // termina con las esquinas redondeadas.
          const Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: _solape,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: AppPalette.ink,
                borderRadius: BorderRadius.vertical(
                  bottom: Radius.circular(AppRadius.r24),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.x4),
            child: _TarjetaSaldo(
              onIngreso: onIngreso,
              onGasto: onGasto,
              onValorHora: onValorHora,
            ),
          ),
        ],
      ),
    ],
  );
}

/// Avatar, saludo, nombre del taller y el acceso a la ayuda, en claro sobre
/// el oscuro.
class _BarraIdentidad extends StatelessWidget {
  const _BarraIdentidad({required this.onAyuda});

  final VoidCallback onAyuda;

  @override
  Widget build(final BuildContext context) {
    final theme = Theme.of(context);
    final profile = context.watch<UserProfileProvider>().profile;

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.x4,
        AppSpacing.x5,
        AppSpacing.x1,
        AppSpacing.x5,
      ),
      child: Row(
        children: [
          // Mientras no hay perfil se pinta el esqueleto, nunca un nombre
          // inventado.
          if (profile == null)
            const Expanded(child: _esqueletoIdentidad)
          else ...[
            Container(
              width: 44,
              height: 44,
              alignment: Alignment.center,
              decoration: const BoxDecoration(
                color: AppPalette.textOnInkMuted,
                shape: BoxShape.circle,
              ),
              child: Text(
                profile.avatarInitials,
                style: AppText.weight(
                  theme.textTheme.labelLarge!,
                  800,
                ).copyWith(color: AppPalette.ink),
              ),
            ),
            const SizedBox(width: AppSpacing.x3),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Hola, ${profile.name.split(' ').first}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: AppPalette.textOnInkMuted,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    profile.businessName,
                    style: AppText.weight(
                      theme.textTheme.titleMedium!,
                      800,
                    ).copyWith(color: AppPalette.textOnBrand),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
          IconButton(
            tooltip: 'Ayuda',
            color: AppPalette.textOnBrand,
            icon: const Icon(Icons.help_outline_rounded),
            onPressed: onAyuda,
          ),
        ],
      ),
    );
  }
}

const Widget _esqueletoIdentidad = PagateSkeletonGroup(
  child: Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    mainAxisSize: MainAxisSize.min,
    children: [
      PagateSkeleton(height: PagateSkeleton.lineaTitulo, widthFactor: 0.5),
      SizedBox(height: AppSpacing.x1),
      PagateSkeleton(height: PagateSkeleton.lineaMetadato, widthFactor: 0.3),
    ],
  ),
);

// ─── Selector de mes pegajoso ──────────────────────────────────────────

class _SelectorPegajoso extends SliverPersistentHeaderDelegate {
  const _SelectorPegajoso({required this.visible});

  /// `false` cuando solo hay un mes: la banda desaparece entera en vez de
  /// dejar un hueco.
  final bool visible;

  /// 32 del chip + 6 arriba + 6 abajo = 44, más el borde inferior.
  static const double _alto = 45;

  @override
  double get minExtent => visible ? _alto : 0;

  @override
  double get maxExtent => visible ? _alto : 0;

  @override
  Widget build(
    final BuildContext context,
    final double shrinkOffset,
    final bool overlapsContent,
  ) {
    final finances = context.watch<FinancesProvider>();
    return SizedBox(
      height: _alto,
      width: double.infinity,
      child: PagateMonthSelector(
        monthKeys: [for (final m in finances.months) m.monthKey],
        selectedMonthKey: finances.selectedMonthKey,
        currentMonthKey: FinancesProvider.currentMonthKey,
        onSelected: finances.selectMonthKey,
      ),
    );
  }

  @override
  bool shouldRebuild(final _SelectorPegajoso oldDelegate) =>
      oldDelegate.visible != visible;
}

// ─── Tarjeta de saldo ──────────────────────────────────────────────────

/// Balance, meta, ingresos y gastos, los dos botones de registrar y, en la
/// franja del pie, el valor de la hora.
///
/// LOS GASTOS FIJOS NO ENTRAN AQUÍ: `FinancesSummaryEntity.balance` es
/// `totalIncome - totalExpenses`, así que la tarjeta muestra exactamente
/// esas dos cifras y la de arriba es su resta. Los gastos fijos son un plan
/// mensual que no se resta (ver `_Pendientes`).
class _TarjetaSaldo extends StatelessWidget {
  const _TarjetaSaldo({
    required this.onIngreso,
    required this.onGasto,
    required this.onValorHora,
  });

  final VoidCallback onIngreso;
  final VoidCallback onGasto;
  final VoidCallback onValorHora;

  @override
  Widget build(final BuildContext context) {
    final theme = Theme.of(context);
    final finances = context.watch<FinancesProvider>();

    // Un fallo NUNCA se dibuja como un cero.
    final Widget saldo;
    if (finances.error != null) {
      saldo = PagateErrorState(
        message: finances.error!,
        onRetry: finances.retry,
      );
    } else if (finances.isLoading) {
      saldo = PagateSkeleton.balance();
    } else {
      final summary = finances.summary;
      final meta = finances.monthlyGoal;
      saldo = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Balance de ${_nombreDelMes(summary.monthKey)}'.toUpperCase(),
            style: theme.textTheme.labelSmall?.copyWith(
              color: AppPalette.textSecondary,
            ),
          ),
          const SizedBox(height: AppSpacing.x1),
          _CifraHeroe(balance: summary.balance),
          if (meta > 0) ...[
            const SizedBox(height: AppSpacing.x3),
            _Meta(ingresos: summary.totalIncome, meta: meta),
          ],
          const SizedBox(height: AppSpacing.x3),
          _IngresosYGastos(
            ingresos: summary.totalIncome,
            gastos: summary.totalExpenses,
          ),
        ],
      );
    }

    return Container(
      key: const Key('inicio-tarjeta-saldo'),
      decoration: BoxDecoration(
        color: AppPalette.surface,
        borderRadius: AppRadius.r16Border,
        boxShadow: AppShadows.level2,
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.x4,
              AppSpacing.x4,
              AppSpacing.x4,
              AppSpacing.x4,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                saldo,
                const SizedBox(height: AppSpacing.x4),
                _Registrar(onIngreso: onIngreso, onGasto: onGasto),
              ],
            ),
          ),
          _FranjaValorHora(onTap: onValorHora),
        ],
      ),
    );
  }

  static String _nombreDelMes(final String monthKey) {
    final partes = monthKey.split('-');
    if (partes.length != 2) return monthKey;
    final mes = int.tryParse(partes[1]);
    return mes == null ? monthKey : monthName(mes);
  }
}

/// La única cifra dominante de la pantalla.
///
/// Baja de 40 a 32 dp cuando el texto supera los once caracteres
/// (`$123.456.789` son doce). La alternativa sería abreviar ("$1234.6K"),
/// que es justamente lo que el sistema elimina.
class _CifraHeroe extends StatelessWidget {
  const _CifraHeroe({required this.balance});

  final double balance;

  static const int _maxCaracteres = 11;

  @override
  Widget build(final BuildContext context) {
    final theme = Theme.of(context);
    final texto = formatCurrency(balance, currency: kFallbackCurrency);
    final estilo = texto.length > _maxCaracteres
        ? theme.textTheme.displayMedium
        : theme.textTheme.displayLarge;

    return Text(
      texto,
      style: estilo?.copyWith(
        color: balance < 0 ? AppPalette.moneyOut : AppPalette.textPrimary,
      ),
    );
  }
}

/// La barra dice qué mide: los INGRESOS del mes contra la meta. Sin la
/// frase, un 43 % podía leerse como 43 % del balance o de los gastos.
class _Meta extends StatelessWidget {
  const _Meta({required this.ingresos, required this.meta});

  final double ingresos;
  final double meta;

  @override
  Widget build(final BuildContext context) {
    final theme = Theme.of(context);
    // El porcentaje no se recorta en 100: pasarse de la meta es un dato.
    final porcentaje = (ingresos / meta * 100).round();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Ingresos: $porcentaje % de tu meta',
          style: AppText.weight(theme.textTheme.bodySmall!, 700),
        ),
        const SizedBox(height: AppSpacing.x1 + 2),
        ClipRRect(
          borderRadius: const BorderRadius.all(Radius.circular(AppRadius.r8)),
          child: LinearProgressIndicator(
            value: (ingresos / meta).clamp(0.0, 1.0),
            minHeight: 8,
            color: AppPalette.ink,
            backgroundColor: AppPalette.sunken,
          ),
        ),
        const SizedBox(height: AppSpacing.x1),
        Text(
          '${formatCurrency(ingresos, currency: kFallbackCurrency)} de '
          '${formatCurrency(meta, currency: kFallbackCurrency)}',
          style: theme.textTheme.bodySmall?.copyWith(
            color: AppPalette.textSecondary,
          ),
        ),
      ],
    );
  }
}

/// Ingresos en verde con «+» y gastos en el oscuro con «−»: el balance de
/// arriba es exactamente su resta.
class _IngresosYGastos extends StatelessWidget {
  const _IngresosYGastos({required this.ingresos, required this.gastos});

  final double ingresos;
  final double gastos;

  @override
  Widget build(final BuildContext context) {
    final apilado = _apilado(context);
    final ingreso = _cifra(
      context,
      etiqueta: 'Ingresos',
      monto: formatSigned(ingresos, currency: kFallbackCurrency),
      color: AppPalette.moneyIn,
      alFinal: false,
    );
    final gasto = _cifra(
      context,
      etiqueta: 'Gastos',
      monto: formatSigned(-gastos, currency: kFallbackCurrency),
      color: AppPalette.ink,
      alFinal: !apilado,
    );

    return Container(
      padding: const EdgeInsets.only(top: AppSpacing.x3),
      decoration: const BoxDecoration(
        border: Border(
          top: BorderSide(
            color: AppPalette.hairline,
            width: AppSizes.borderHairline,
          ),
        ),
      ),
      child: apilado
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [ingreso, const SizedBox(height: AppSpacing.x2), gasto],
            )
          : Row(
              children: [
                Expanded(child: ingreso),
                const SizedBox(width: AppSpacing.x3),
                Expanded(child: gasto),
              ],
            ),
    );
  }

  Widget _cifra(
    final BuildContext context, {
    required final String etiqueta,
    required final String monto,
    required final Color color,
    required final bool alFinal,
  }) => Column(
    crossAxisAlignment: alFinal
        ? CrossAxisAlignment.end
        : CrossAxisAlignment.start,
    children: [
      Text(
        etiqueta,
        style: AppText.weight(
          Theme.of(context).textTheme.bodySmall!,
          600,
        ).copyWith(color: AppPalette.textSecondary),
      ),
      Text(
        monto,
        softWrap: false,
        style: AppText.amountRow.copyWith(color: color),
      ),
    ],
  );
}

/// La acción principal es registrar un ingreso: va en la greda. El gasto,
/// en secundario.
class _Registrar extends StatelessWidget {
  const _Registrar({required this.onIngreso, required this.onGasto});

  final VoidCallback onIngreso;
  final VoidCallback onGasto;

  @override
  Widget build(final BuildContext context) => Row(
    children: [
      Expanded(
        child: PagatePrimaryButton(label: '+ Ingreso', onPressed: onIngreso),
      ),
      const SizedBox(width: AppSpacing.x3),
      Expanded(
        child: PagatePrimaryButton.secondary(
          // U+2212, el mismo signo que la columna de montos.
          label: '− Gasto',
          onPressed: onGasto,
        ),
      ),
    ],
  );
}

/// El valor de la hora cierra la tarjeta en una franja tintada que se toca
/// para ir a calcularlo. Es la promesa diferencial del producto.
class _FranjaValorHora extends StatelessWidget {
  const _FranjaValorHora({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(final BuildContext context) {
    final theme = Theme.of(context);
    final rate = context.watch<HourlyRateProvider>().currentRate;
    final horas = rate?.availableHoursPerMonth.round();
    // Con letra de 1,5 o más la cifra baja bajo el texto: lado a lado, la
    // etiqueta se partía en cinco líneas de una palabra.
    final apilado = _apilado(context);
    final valor = rate == null
        ? Text(
            'Calcular',
            style: AppText.weight(
              theme.textTheme.labelLarge!,
              700,
            ).copyWith(color: AppPalette.brand),
          )
        : Text(
            formatCurrency(rate.hourlyValue, currency: kFallbackCurrency),
            softWrap: false,
            style: AppText.weight(
              AppText.amountField,
              800,
            ).copyWith(color: AppPalette.ink),
          );

    return Material(
      color: AppPalette.canvas,
      child: InkWell(
        onTap: onTap,
        highlightColor: AppPalette.sunken,
        splashFactory: NoSplash.splashFactory,
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.x4,
            vertical: AppSpacing.x3,
          ),
          decoration: const BoxDecoration(
            border: Border(
              top: BorderSide(
                color: AppPalette.hairline,
                width: AppSizes.borderHairline,
              ),
            ),
          ),
          child: Row(
            children: [
              const PagateIconSquare(icon: Icons.schedule_rounded),
              const SizedBox(width: AppSpacing.x3),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      rate == null ? '¿Cuánto vale tu hora?' : 'Tu hora vale',
                      style: theme.textTheme.titleSmall,
                    ),
                    Text(
                      rate == null
                          ? 'Calcúlalo en un minuto'
                          : 'Con $horas horas al mes',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: AppPalette.textSecondary,
                      ),
                    ),
                    if (apilado) ...[
                      const SizedBox(height: AppSpacing.x1),
                      valor,
                    ],
                  ],
                ),
              ),
              if (!apilado) ...[
                const SizedBox(width: AppSpacing.x2),
                valor,
              ],
              if (rate != null)
                const Icon(
                  Icons.chevron_right_rounded,
                  size: AppIconSize.sm,
                  color: AppPalette.textMuted,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Primeros pasos ────────────────────────────────────────────────────

/// Guía de una cuenta nueva: se ve mientras no hay ningún movimiento
/// registrado y desaparece con el primero.
class _PrimerosPasos extends StatelessWidget {
  const _PrimerosPasos({
    required this.onValorHora,
    required this.onRegistrar,
    required this.onInventario,
  });

  final VoidCallback onValorHora;
  final VoidCallback onRegistrar;
  final VoidCallback onInventario;

  @override
  Widget build(final BuildContext context) {
    final theme = Theme.of(context);
    final finances = context.watch<FinancesProvider>();
    final inventory = context.watch<InventoryProvider>();
    final rate = context.watch<HourlyRateProvider>().currentRate;

    // Mientras algo carga o falla no se sabe si la cuenta es nueva: mejor
    // no dibujar nada que dibujar una guía equivocada.
    if (finances.error != null ||
        finances.isLoading ||
        finances.isLoadingTransactions ||
        inventory.isLoading) {
      return const SizedBox.shrink();
    }
    final hayMovimientos =
        finances.transactions.isNotEmpty ||
        finances.months.any((final m) => m.transactionCount > 0);
    if (hayMovimientos) return const SizedBox.shrink();

    final pasos = [
      // El registro ya pasó por la configuración del taller.
      ('Configura tu taller', true, null, null),
      ('Calcula el valor de tu hora', rate != null, 'Calcular', onValorHora),
      ('Registra tu primer movimiento', false, 'Registrar', onRegistrar),
      (
        'Agrega un producto o material',
        inventory.inventarioCompleto.isNotEmpty,
        'Agregar',
        onInventario,
      ),
    ];
    final hechos = pasos.where((final p) => p.$2).length;

    return Container(
      key: const Key('inicio-primeros-pasos'),
      margin: const EdgeInsets.fromLTRB(
        AppSpacing.x4,
        AppSpacing.x4,
        AppSpacing.x4,
        0,
      ),
      padding: const EdgeInsets.all(AppSpacing.x3 + 2),
      decoration: BoxDecoration(
        color: AppPalette.surface,
        borderRadius: AppRadius.r16Border,
        boxShadow: AppShadows.level1,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Primeros pasos',
                  style: AppText.weight(theme.textTheme.titleMedium!, 800),
                ),
              ),
              Text(
                '$hechos de ${pasos.length}',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: AppPalette.textSecondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.x2),
          ClipRRect(
            borderRadius: const BorderRadius.all(
              Radius.circular(AppRadius.r8),
            ),
            child: LinearProgressIndicator(
              value: hechos / pasos.length,
              minHeight: 8,
              color: AppPalette.ink,
              backgroundColor: AppPalette.sunken,
            ),
          ),
          for (final (texto, hecho, accion, alTocar) in pasos)
            _Paso(
              texto: texto,
              hecho: hecho,
              accion: hecho ? null : accion,
              onTap: hecho ? null : alTocar,
            ),
        ],
      ),
    );
  }
}

class _Paso extends StatelessWidget {
  const _Paso({
    required this.texto,
    required this.hecho,
    this.accion,
    this.onTap,
  });

  final String texto;
  final bool hecho;
  final String? accion;
  final VoidCallback? onTap;

  @override
  Widget build(final BuildContext context) {
    final theme = Theme.of(context);
    return Semantics(
      checked: hecho,
      child: Padding(
        padding: const EdgeInsets.only(top: AppSpacing.x2),
        child: Row(
          children: [
            Container(
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                color: hecho ? AppPalette.ink : null,
                shape: BoxShape.circle,
                border: hecho
                    ? null
                    : Border.all(color: AppPalette.border, width: 2),
              ),
              child: hecho
                  ? const Icon(
                      Icons.check_rounded,
                      size: 14,
                      color: AppPalette.textOnBrand,
                    )
                  : null,
            ),
            const SizedBox(width: AppSpacing.x3),
            Expanded(
              child: Text(
                texto,
                style: theme.textTheme.titleSmall?.copyWith(
                  color: hecho ? AppPalette.textSecondary : null,
                  decoration: hecho ? TextDecoration.lineThrough : null,
                ),
              ),
            ),
            if (accion != null)
              TextButton(
                onPressed: onTap,
                style: TextButton.styleFrom(
                  foregroundColor: AppPalette.brand,
                ),
                child: Text(accion!),
              ),
          ],
        ),
      ),
    );
  }
}

// ─── Gastos fijos y stock bajo ─────────────────────────────────────────

/// Las dos filas que avisan de algo: el plan de gastos fijos y el stock
/// bajo. Cada una solo existe si tiene algo que decir; sin ninguna, la
/// sección no se dibuja.
class _Pendientes extends StatelessWidget {
  const _Pendientes({required this.onFinanzas, required this.onInventario});

  final VoidCallback onFinanzas;
  final VoidCallback onInventario;

  @override
  Widget build(final BuildContext context) {
    final totalFijos = context.select<FinancesProvider, double>(
      (final p) => p.totalFixedExpenses,
    );
    final inventory = context.watch<InventoryProvider>();

    // Un error de inventario no se anuncia en Inicio: la fila es un aviso,
    // no un dato que el usuario vino a buscar.
    // TODO el inventario, no `allItems`: ese solo trae la pestaña activa de
    // Inventario y los materiales sin stock no contaban con «Productos»
    // abierta.
    final bajos = inventory.error != null || inventory.isLoading
        ? const <InventoryItemEntity>[]
        : [
            for (final item in inventory.inventarioCompleto)
              if (item.stockStatus != StockStatus.ok) item,
          ];

    if (totalFijos <= 0 && bajos.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.x4),
      child: PagateSectionCard(
        child: Column(
          children: [
            if (totalFijos > 0)
              PagateDataRow(
                icon: Icons.event_repeat_rounded,
                label: 'Gastos fijos',
                // SIN signo menos: el menos de una fila significa "ya se
                // restó del balance", y un gasto fijo no se resta. Y lo dice
                // con palabras.
                subtitle: 'Cada mes · no se resta del balance',
                value: formatCurrency(totalFijos, currency: kFallbackCurrency),
                onTap: onFinanzas,
                showDivider: bajos.isNotEmpty,
              ),
            if (bajos.isNotEmpty)
              PagateDataRow(
                icon: Icons.inventory_2_outlined,
                label: 'Stock bajo',
                subtitle: _resumenStock(bajos),
                value: '${bajos.length}',
                // El carmesí es solo para alertas, y esta lo es.
                valueColor: AppPalette.danger,
                onTap: onInventario,
                showDivider: false,
              ),
          ],
        ),
      ),
    );
  }

  /// "1 producto y 3 materiales".
  static String _resumenStock(final List<InventoryItemEntity> bajos) {
    final productos = bajos
        .where((final i) => i.type == InventoryItemType.product)
        .length;
    final materiales = bajos.length - productos;
    return [
      if (productos > 0)
        '$productos ${productos == 1 ? 'producto' : 'productos'}',
      if (materiales > 0)
        '$materiales ${materiales == 1 ? 'material' : 'materiales'}',
    ].join(' y ');
  }
}

// ─── Movimientos ───────────────────────────────────────────────────────

class _Movimientos extends StatelessWidget {
  const _Movimientos({required this.onVerTodos});

  final VoidCallback onVerTodos;

  @override
  Widget build(final BuildContext context) {
    final finances = context.watch<FinancesProvider>();
    final movimientos = finances.transactions.take(5).toList();

    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.x2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PagateSectionHeader(
            title: 'Movimientos recientes',
            actionLabel: movimientos.isEmpty ? null : 'Ver todos',
            onAction: movimientos.isEmpty ? null : onVerTodos,
          ),
          PagateSectionCard(child: _cuerpo(context, finances, movimientos)),
        ],
      ),
    );
  }

  Widget _cuerpo(
    final BuildContext context,
    final FinancesProvider finances,
    final List<FinancesTransactionEntity> movimientos,
  ) {
    if (finances.error != null) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.x4),
        child: PagateErrorState(
          message: finances.error!,
          onRetry: finances.retry,
        ),
      );
    }
    if (finances.isLoadingTransactions) {
      return PagateSkeleton.rows(3);
    }
    if (movimientos.isEmpty) {
      return PagateEmptyState(
        title: 'Sin movimientos este mes',
        description: 'Cuando registres una venta o un gasto, aparece aquí.',
        actionLabel: 'Ver Finanzas',
        onAction: onVerTodos,
      );
    }

    return Column(
      children: [
        for (final tx in movimientos)
          PagateMovementRow(
            title: tx.title,
            meta: '${formatDayMonth(tx.date)} · ${tx.category}',
            amount: formatSigned(
              tx.isIncome ? tx.amount : -tx.amount,
              currency: kFallbackCurrency,
            ),
            isIncome: tx.isIncome,
          ),
      ],
    );
  }
}
