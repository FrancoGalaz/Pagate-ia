import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../../core/constants/app_constants.dart';
import '../../../../../core/utils/currency_formatter.dart';
import '../../../../../core/utils/month_labels.dart';
import '../../../../../core/widgets/widgets.dart';
import '../../../../auth/presentation/widgets/verificar_correo_banner.dart';
import '../../../../finances/domain/entities/finances_transaction_entity.dart';
import '../../../../finances/presentation/providers/finances_provider.dart';
import '../../../../hourly_value/presentation/bloc/hourly_rate_provider.dart';
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
// Y EL SELECTOR DE MES ARRIBA ARREGLA OTRO BUG, no es estética: Inicio y
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
    required this.onVerValorHora,
    required this.onAyuda,
  });

  final VoidCallback onRegistrarIngreso;
  final VoidCallback onRegistrarGasto;
  final VoidCallback onVerFinanzas;
  final VoidCallback onVerValorHora;
  final VoidCallback onAyuda;

  @override
  Widget build(final BuildContext context) {
    // Cuántos meses hay que elegir, contando siempre el actual. Con uno
    // solo el selector no se dibuja, y entonces su banda tampoco debe
    // reservar alto: una cuenta recién creada veía 45 dp de hueco vacío
    // entre la barra de identidad y el balance.
    final meses = context.select<FinancesProvider, int>(
      (final p) => {
        for (final m in p.months) m.monthKey,
        FinancesProvider.currentMonthKey,
      }.length,
    );

    return CustomScrollView(
        slivers: [
          SliverToBoxAdapter(child: _BarraIdentidad(onAyuda: onAyuda)),

          // El selector queda pegado arriba al desplazarse: es el filtro
          // global de la app y tiene que estar siempre a la vista.
          SliverPersistentHeader(
            pinned: true,
            delegate: _SelectorPegajoso(visible: meses > 1),
          ),

          SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const VerificarCorreoBanner(),
                const _BloqueSaldo(),
                _Registrar(
                  onIngreso: onRegistrarIngreso,
                  onGasto: onRegistrarGasto,
                ),
                const _GastosFijos(),
                _ValorHora(onTap: onVerValorHora),
                _Movimientos(onVerTodos: onVerFinanzas),
                const _StockBajo(),
                const SizedBox(height: AppSpacing.x8),
              ],
            ),
          ),
        ],
    );
  }
}

// ─── Barra de identidad ────────────────────────────────────────────────

/// Avatar cuadrado, nombre del taller, nombre de la persona y el acceso a
/// la ayuda. Alto 56.
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
        AppSpacing.x2,
        AppSpacing.x1,
        AppSpacing.x2,
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 56),
        child: Row(
          children: [
            // Mientras no hay perfil se pinta el esqueleto. Antes se pintaba
            // 'IA' como iniciales, 'Artesano' como nombre y 'Mi Negocio'
            // como taller: tres datos inventados presentados como del
            // usuario.
            if (profile == null)
              const Expanded(child: _esqueletoIdentidad)
            else ...[
              Container(
                width: AppSizes.avatarSmall,
                height: AppSizes.avatarSmall,
                alignment: Alignment.center,
                decoration: const BoxDecoration(
                  color: AppPalette.brandSurface,
                  borderRadius: BorderRadius.all(Radius.circular(AppRadius.r8)),
                ),
                child: Text(
                  profile.avatarInitials,
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: AppPalette.brand,
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.x3),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      profile.businessName,
                      style: theme.textTheme.titleMedium,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      profile.name,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: AppPalette.textMuted,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],

            // Era una campana con un punto rojo siempre encendido, sin
            // sistema de notificaciones detrás, que abría la Ayuda.
            IconButton(
              tooltip: 'Ayuda',
              icon: const Icon(Icons.help_outline_rounded),
              onPressed: onAyuda,
            ),
          ],
        ),
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
    // Ancho completo y sin `Align`: con el selector centrado, los chips
    // arrancaban en mitad de la pantalla y la línea inferior solo cubría el
    // trozo ocupado. Todo va a la izquierda, con el margen del sistema.
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

// ─── Bloque de saldo y composición ─────────────────────────────────────

/// La cifra que ES la pantalla, la meta y las tres filas que responden "de
/// dónde sale ese número".
class _BloqueSaldo extends StatelessWidget {
  const _BloqueSaldo();

  @override
  Widget build(final BuildContext context) {
    final theme = Theme.of(context);
    final finances = context.watch<FinancesProvider>();

    // El criterio que faltaba: un fallo NUNCA se dibuja como un cero.
    if (finances.error != null) {
      return Padding(
        padding: const EdgeInsets.only(top: AppSpacing.x6),
        child: PagateErrorState(
          message: finances.error!,
          onRetry: finances.retry,
        ),
      );
    }
    if (finances.isLoading) {
      return PagateSkeleton.balance();
    }

    final summary = finances.summary;
    final balance = summary.balance;
    final meta = finances.monthlyGoal;
    final progreso = finances.goalProgress;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.x4,
            AppSpacing.x6,
            AppSpacing.x4,
            AppSpacing.x6,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Balance de ${_nombreDelMes(summary.monthKey)}'.toUpperCase(),
                style: theme.textTheme.labelSmall?.copyWith(
                  color: AppPalette.textSecondary,
                ),
              ),
              const SizedBox(height: AppSpacing.x2),
              _CifraHeroe(balance: balance),
              if (meta > 0) ...[
                const SizedBox(height: AppSpacing.x5),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Meta del mes '
                        '${formatCurrency(meta, currency: kFallbackCurrency)}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: AppPalette.textSecondary,
                        ),
                      ),
                    ),
                    Text(
                      '${(progreso * 100).round()} %',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: AppPalette.brand,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.x2),
                ClipRRect(
                  borderRadius: AppRadius.r4Border,
                  child: LinearProgressIndicator(value: progreso),
                ),
              ],
            ],
          ),
        ),

        // DOS filas, y la cifra de arriba es exactamente su resta.
        //
        // EL DEFECTO QUE ARREGLA: aquí había una TERCERA fila, "Gastos fijos
        // −$423.490", con el mismo formato y en el mismo bloque que Ingresos
        // y Gastos, pero `FinancesSummaryEntity.balance` es
        // `totalIncome - totalExpenses` y los gastos fijos NO entran. El
        // usuario sumaba las tres filas, le daba negativo, y el titular de
        // arriba decía +$380.000. En una app de plata eso no es un detalle.
        //
        // DECISIÓN, y por qué esta y no la otra: los gastos fijos NO se
        // restan del balance, así que salen de este bloque y pasan a una
        // sección propia (`_GastosFijos`, más abajo) que dice en una línea
        // que son una referencia mensual. Aquí quedan Ingresos y Gastos, y
        // la resta cuadra con la cifra héroe sin que nadie tenga que
        // comprobarlo dos veces.
        //
        // Lo contrario —meterlos en el balance— sería incorrecto por dos
        // motivos verificables en el repo: (1) el balance lo calcula el
        // trigger `onTransactionWritten` en `users/{uid}/months/{monthKey}`
        // a partir de las transacciones, y el cliente no escribe ahí
        // (docs/ARQUITECTURA.md), así que restarlos solo en pantalla dejaría
        // la app contando una cosa y el backend otra; (2) `fixedExpenses` es
        // un PLAN mensual sin fecha, y cuando el usuario paga el arriendo lo
        // registra además como gasto del mes, de modo que sumarlos contaría
        // el mismo dinero dos veces.
        //
        // Van todas en tinta: el color del dinero se reserva para las filas
        // de movimiento, que es donde discrimina.
        PagateSectionCard(
          child: Column(
            children: [
              PagateDataRow(
                label: 'Ingresos',
                value: formatCurrency(
                  summary.totalIncome,
                  currency: kFallbackCurrency,
                ),
              ),
              PagateDataRow(
                label: 'Gastos',
                value: formatSigned(
                  -summary.totalExpenses,
                  currency: kFallbackCurrency,
                ),
                showDivider: false,
              ),
            ],
          ),
        ),
      ],
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
/// (`$123.456.789` son doce). La alternativa sería abreviar, que es
/// justamente lo que el sistema elimina: "$1234.6K" es lo que esta pantalla
/// dibujaba antes.
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

// ─── Registrar ─────────────────────────────────────────────────────────

/// Dos botones secundarios que abren la misma hoja con el tipo
/// preseleccionado. Sustituyen a las cuatro "Acciones Rápidas".
class _Registrar extends StatelessWidget {
  const _Registrar({required this.onIngreso, required this.onGasto});

  final VoidCallback onIngreso;
  final VoidCallback onGasto;

  @override
  Widget build(final BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.x4,
          AppSpacing.x6,
          AppSpacing.x4,
          0,
        ),
        child: Row(
          children: [
            Expanded(
              child: PagatePrimaryButton.secondary(
                label: '+ Ingreso',
                onPressed: onIngreso,
              ),
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
        ),
      );
}

// ─── Valor de tu hora ──────────────────────────────────────────────────

/// La promesa diferencial del producto, que hasta ahora estaba enterrada
/// detrás de Perfil. Cuesta 48 dp.
// ─── Gastos fijos ──────────────────────────────────────────────────────

/// Los gastos fijos del mes, FUERA del bloque de saldo.
///
/// Estaban como tercera fila del mismo bloque que Ingresos y Gastos, con el
/// mismo formato y el mismo signo menos, y no se restan del balance: el
/// usuario sumaba las tres filas, le salía negativo y el titular decía
/// +$380.000.
///
/// Aquí tienen encabezado propio, el monto va SIN signo (el menos de una fila
/// significa "ya se restó") y una línea dice qué son. Si no hay ninguno, la
/// sección no se dibuja: no hay nada que aclarar.
class _GastosFijos extends StatelessWidget {
  const _GastosFijos();

  @override
  Widget build(final BuildContext context) {
    final total = context.select<FinancesProvider, double>(
      (final p) => p.totalFixedExpenses,
    );
    if (total <= 0) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const PagateSectionHeader(title: 'Gastos fijos'),
        PagateSectionCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              PagateDataRow(
                label: 'Comprometido cada mes',
                value: formatCurrency(total, currency: kFallbackCurrency),
                showDivider: false,
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.x4,
                  AppSpacing.x0,
                  AppSpacing.x4,
                  AppSpacing.x3,
                ),
                child: Text(
                  'Referencia de lo que pagas todos los meses. No se resta '
                  'del balance: cada pago entra cuando lo registras como '
                  'gasto.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppPalette.textMuted,
                      ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ValorHora extends StatelessWidget {
  const _ValorHora({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(final BuildContext context) {
    final rate = context.watch<HourlyRateProvider>().currentRate;

    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.x6),
      child: PagateSectionCard(
        child: PagateDataRow(
          label: 'Valor de tu hora',
          value: rate == null
              ? 'Calcular'
              : formatCurrency(rate.hourlyValue, currency: kFallbackCurrency),
          valueColor: rate == null ? AppPalette.brand : null,
          onTap: onTap,
          showDivider: false,
        ),
      ),
    );
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
      padding: const EdgeInsets.only(top: AppSpacing.x6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PagateSectionHeader(
            title: 'Movimientos',
            actionLabel: movimientos.isEmpty ? null : 'Ver todos',
            onAction: movimientos.isEmpty ? null : onVerTodos,
          ),
          PagateSectionCard(
            child: _cuerpo(context, finances, movimientos),
          ),
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
        description: 'Registra tu primera venta o tu primer gasto del mes.',
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

// ─── Stock bajo ────────────────────────────────────────────────────────

/// Solo existe si hay algo que decir. Es el único sitio de Inicio donde
/// aparece ámbar o rojo, y por eso se ve.
class _StockBajo extends StatelessWidget {
  const _StockBajo();

  /// Tres filas como máximo: a partir de ahí es una lista, y la lista está
  /// en Inventario.
  static const int _maxFilas = 3;

  @override
  Widget build(final BuildContext context) {
    final inventory = context.watch<InventoryProvider>();

    // Un error de inventario no se anuncia en Inicio: esta sección es un
    // aviso, no un dato que el usuario vino a buscar, y un bloque rojo de
    // error aquí competiría con el balance.
    if (inventory.error != null || inventory.isLoading) {
      return const SizedBox.shrink();
    }

    final bajos = [
      for (final item in inventory.allItems)
        if (item.stockStatus != StockStatus.ok) item,
    ];
    if (bajos.isEmpty) return const SizedBox.shrink();

    final visibles = bajos.take(_maxFilas).toList();

    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.x6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PagateSectionHeader(title: 'Stock bajo (${bajos.length})'),
          PagateSectionCard(
            child: Column(
              children: [
                for (final item in visibles)
                  PagateDataRow(
                    label: item.name,
                    value: '${item.stock} de ${item.minStock} ${item.unit}',
                    valueColor: item.stockStatus == StockStatus.critical
                        ? AppPalette.danger
                        : AppPalette.warning,
                    showDivider: item != visibles.last,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
