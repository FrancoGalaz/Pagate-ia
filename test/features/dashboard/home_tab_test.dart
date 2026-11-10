// Widget test de HomeTab, sin Firebase.
//
// Los cuatro proveedores que la pantalla lee se sustituyen por dobles que
// exponen exactamente los getters que consume, así que se puede montar el
// estado con error, cargando, vacío y con datos sin tocar la red.
//
// Especificación: docs/DISENO-v2.md, "Pantalla de inicio".

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:pagate_ia/core/constants/app_constants.dart';
import 'package:pagate_ia/core/services/firebase_auth_service.dart';
import 'package:pagate_ia/core/theme/app_theme.dart';
import 'package:pagate_ia/core/widgets/widgets.dart';
import 'package:pagate_ia/features/dashboard/presentation/pages/tabs/home_tab.dart';
import 'package:pagate_ia/features/finances/domain/entities/finances_summary_entity.dart';
import 'package:pagate_ia/features/finances/domain/entities/finances_transaction_entity.dart';
import 'package:pagate_ia/features/finances/domain/entities/fixed_expense_entity.dart';
import 'package:pagate_ia/features/finances/presentation/providers/finances_provider.dart';
import 'package:pagate_ia/features/hourly_value/domain/entities/hourly_rate_entity.dart';
import 'package:pagate_ia/features/hourly_value/presentation/bloc/hourly_rate_provider.dart';
import 'package:pagate_ia/features/inventory/domain/entities/inventory_item_entity.dart';
import 'package:pagate_ia/features/inventory/domain/entities/inventory_item_type.dart';
import 'package:pagate_ia/features/inventory/presentation/providers/inventory_provider.dart';
import 'package:pagate_ia/features/user_profile/domain/entities/user_profile_entity.dart';
import 'package:pagate_ia/features/user_profile/presentation/providers/user_profile_provider.dart';

// ─── Dobles ─────────────────────────────────────────────────────────────

class _FinanzasFalsas extends ChangeNotifier implements FinancesProvider {
  _FinanzasFalsas({
    this.months = const [],
    this.transactions = const [],
    this.fixedExpenses = const [],
    this.error,
    this.isLoading = false,
    this.isLoadingTransactions = false,
    this.monthlyGoal = 0,
  });

  @override
  List<FinancesSummaryEntity> months;
  @override
  List<FinancesTransactionEntity> transactions;
  @override
  List<FixedExpenseEntity> fixedExpenses;
  @override
  String? error;
  @override
  bool isLoading;
  @override
  bool isLoadingTransactions;
  @override
  double monthlyGoal;
  @override
  String selectedMonthKey = '2026-10';

  final List<String> mesesElegidos = [];
  int reintentos = 0;

  @override
  double get totalFixedExpenses =>
      fixedExpenses.fold(0, (final a, final b) => a + b.amount);

  @override
  FinancesSummaryEntity get summary {
    for (final m in months) {
      if (m.monthKey == selectedMonthKey) return m;
    }
    return FinancesSummaryEntity(
      monthKey: selectedMonthKey,
      totalIncome: 0,
      totalExpenses: 0,
      transactionCount: 0,
    );
  }

  @override
  double get goalProgress => summary.goalProgress(monthlyGoal);

  @override
  void selectMonthKey(final String monthKey) => mesesElegidos.add(monthKey);

  @override
  void retry() => reintentos++;

  @override
  dynamic noSuchMethod(final Invocation invocation) =>
      super.noSuchMethod(invocation);
}

class _PerfilFalso extends ChangeNotifier implements UserProfileProvider {
  _PerfilFalso(this.profile);

  @override
  UserProfileEntity? profile;

  @override
  dynamic noSuchMethod(final Invocation invocation) =>
      super.noSuchMethod(invocation);
}

class _ValorHoraFalso extends ChangeNotifier implements HourlyRateProvider {
  _ValorHoraFalso(this.currentRate);

  @override
  HourlyRateEntity? currentRate;

  @override
  dynamic noSuchMethod(final Invocation invocation) =>
      super.noSuchMethod(invocation);
}

class _InventarioFalso extends ChangeNotifier implements InventoryProvider {
  _InventarioFalso({
    this.allItems = const [],
    final List<InventoryItemEntity>? inventarioCompleto,
  }) : inventarioCompleto = inventarioCompleto ?? allItems;

  /// Solo los items de la pestaña activa de Inventario.
  @override
  List<InventoryItemEntity> allItems;

  /// Productos y materiales juntos.
  @override
  List<InventoryItemEntity> inventarioCompleto;

  /// Inicio no dibuja el stock bajo si el inventario falla o está cargando:
  /// la sección es un aviso, no un dato que el usuario vino a buscar.
  @override
  String? error;
  @override
  bool isLoading = false;

  @override
  dynamic noSuchMethod(final Invocation invocation) =>
      super.noSuchMethod(invocation);
}

// ─── Datos de prueba ────────────────────────────────────────────────────

const _perfil = UserProfileEntity(
  id: 'u1',
  name: 'Camila Rojas',
  businessName: 'Greda Austral',
  businessType: 'Cerámica',
  currency: 'CLP',
  monthlyGoal: 500000,
  isPro: false,
  avatarInitials: 'CR',
);

FinancesTransactionEntity _tx({
  required final String title,
  required final double amount,
  required final bool ingreso,
  required final String categoria,
  required final int dia,
}) => FinancesTransactionEntity(
  id: 'tx-$title',
  title: title,
  description: '',
  amount: amount,
  type: ingreso ? TransactionType.income : TransactionType.expense,
  date: DateTime(2026, 10, dia),
  category: categoria,
);

// ─── Montaje ────────────────────────────────────────────────────────────

class _Acciones {
  int ingreso = 0;
  int gasto = 0;
  int finanzas = 0;
  int inventario = 0;
  int valorHora = 0;
  int ayuda = 0;
}

/// Correo verificado por defecto: el aviso tiene su propio test.
class _AuthVerificada extends ChangeNotifier implements FirebaseAuthService {
  _AuthVerificada({this.correoVerificado = true});

  @override
  final bool correoVerificado;

  @override
  dynamic noSuchMethod(final Invocation invocation) =>
      super.noSuchMethod(invocation);
}

Future<_Acciones> _montar(
  final WidgetTester tester, {
  required final _FinanzasFalsas finanzas,
  final UserProfileEntity? perfil,
  final HourlyRateEntity? valorHora,
  final _InventarioFalso? inventario,
  final double textScale = 1.0,
  final bool correoVerificado = true,
}) async {
  tester.view
    ..physicalSize = const Size(360, 900)
    ..devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  final acciones = _Acciones();
  await tester.pumpWidget(
    MediaQuery(
      data: MediaQueryData(
        size: const Size(360, 900),
        textScaler: TextScaler.linear(textScale),
      ),
      child: MultiProvider(
        providers: [
          ChangeNotifierProvider<FinancesProvider>.value(value: finanzas),
          ChangeNotifierProvider<UserProfileProvider>.value(
            value: _PerfilFalso(perfil),
          ),
          ChangeNotifierProvider<HourlyRateProvider>.value(
            value: _ValorHoraFalso(valorHora),
          ),
          ChangeNotifierProvider<InventoryProvider>.value(
            value: inventario ?? _InventarioFalso(),
          ),
          ChangeNotifierProvider<FirebaseAuthService>.value(
            value: _AuthVerificada(correoVerificado: correoVerificado),
          ),
        ],
        child: MaterialApp(
          theme: AppTheme.lightTheme,
          home: Scaffold(
            body: HomeTab(
              onRegistrarIngreso: () => acciones.ingreso++,
              onRegistrarGasto: () => acciones.gasto++,
              onVerFinanzas: () => acciones.finanzas++,
              onVerInventario: () => acciones.inventario++,
              onVerValorHora: () => acciones.valorHora++,
              onAyuda: () => acciones.ayuda++,
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pump();
  return acciones;
}

_FinanzasFalsas _conDatos() => _FinanzasFalsas(
  months: [
    const FinancesSummaryEntity(
      monthKey: '2026-10',
      totalIncome: 1240000,
      totalExpenses: 860000,
      transactionCount: 3,
    ),
    const FinancesSummaryEntity(
      monthKey: '2026-09',
      totalIncome: 900000,
      totalExpenses: 700000,
      transactionCount: 2,
    ),
  ],
  transactions: [
    _tx(
      title: 'Venta feria Lastarria',
      amount: 120000,
      ingreso: true,
      categoria: 'Venta en feria',
      dia: 12,
    ),
    _tx(
      title: 'Greda 25 kg',
      amount: 35000,
      ingreso: false,
      categoria: 'Insumos y materiales',
      dia: 11,
    ),
  ],
  fixedExpenses: const [
    FixedExpenseEntity(id: 'fx1', name: 'Arriendo', amount: 320000),
  ],
  monthlyGoal: 500000,
);

void main() {
  testWidgets('la cifra dominante es el balance, en tinta y sin abreviar', (
    final tester,
  ) async {
    await _montar(tester, finanzas: _conDatos(), perfil: _perfil);

    // 1.240.000 − 860.000 = 380.000. Ni "$380K" ni "$1234.6K", que es lo
    // que esta pantalla dibujaba.
    expect(find.text(r'$380.000'), findsOneWidget);
    expect(find.textContaining('K'), findsNothing);

    final estilo = tester.widget<Text>(find.text(r'$380.000')).style!;
    expect(estilo.color, AppPalette.textPrimary);
    expect(estilo.fontSize, 40);
  });

  testWidgets('un balance negativo se pinta en rojo de dinero', (
    final tester,
  ) async {
    final finanzas = _FinanzasFalsas(
      months: [
        const FinancesSummaryEntity(
          monthKey: '2026-10',
          totalIncome: 100000,
          totalExpenses: 250000,
          transactionCount: 2,
        ),
      ],
    );
    await _montar(tester, finanzas: finanzas, perfil: _perfil);

    expect(
      tester.widget<Text>(find.text(r'−$150.000')).style!.color,
      AppPalette.moneyOut,
    );
  });

  testWidgets('no queda nada del inventario visual anterior', (
    final tester,
  ) async {
    await _montar(tester, finanzas: _conDatos(), perfil: _perfil);

    // El emoji del saludo. El saludo sin emoji volvió con la variante A,
    // en la cabecera oscura.
    expect(find.textContaining('👋'), findsNothing);

    // Los títulos genéricos en Title Case.
    for (final titulo in [
      'Balance del Mes',
      'Acciones Rápidas',
      'Métricas Financieras',
      'Actividad Reciente',
    ]) {
      expect(find.text(titulo), findsNothing, reason: titulo);
    }

    // El bloque verde con degradado y glow de marca. La sombra suave de las
    // tarjetas de la variante A es la del sistema (`AppShadows`).
    expect(
      find.byWidgetPredicate(
        (final w) =>
            w is DecoratedBox &&
            w.decoration is BoxDecoration &&
            ((w.decoration as BoxDecoration).gradient != null ||
                ((w.decoration as BoxDecoration).boxShadow?.any(
                      (final s) =>
                          !AppShadows.level1.contains(s) &&
                          !AppShadows.level2.contains(s),
                    ) ??
                    false)),
      ),
      findsNothing,
    );

    // Los cuatro iconos circulares pastel de las acciones rápidas.
    expect(find.text('Venta'), findsNothing);
    expect(find.text('Preguntar IA'), findsNothing);
    expect(find.byIcon(Icons.smart_toy_outlined), findsNothing);
  });

  testWidgets('el acceso de la esquina dice Ayuda y no tiene punto rojo', (
    final tester,
  ) async {
    final acciones = await _montar(
      tester,
      finanzas: _conDatos(),
      perfil: _perfil,
    );

    // Era una campana con un punto rojo de 8 dp SIEMPRE encendido, sin
    // sistema de notificaciones detrás, cuyo destino era la Ayuda.
    expect(find.byIcon(Icons.notifications_outlined), findsNothing);
    expect(find.byTooltip('Ayuda'), findsOneWidget);

    await tester.tap(find.byTooltip('Ayuda'));
    expect(acciones.ayuda, 1);
  });

  testWidgets('sin perfil se pinta el esqueleto, no un nombre inventado', (
    final tester,
  ) async {
    await _montar(tester, finanzas: _conDatos());

    for (final inventado in ['IA', 'Artesano', 'Mi Negocio']) {
      expect(find.text(inventado), findsNothing, reason: inventado);
    }
    expect(find.byType(PagateSkeleton), findsWidgets);
  });

  testWidgets('la composición responde de dónde sale el balance', (
    final tester,
  ) async {
    await _montar(tester, finanzas: _conDatos(), perfil: _perfil);

    expect(find.text('Ingresos'), findsOneWidget);
    expect(find.text(r'+$1.240.000'), findsOneWidget);
    expect(find.text('Gastos'), findsOneWidget);
    expect(find.text(r'−$860.000'), findsOneWidget);

    // Variante A: verde solo para ingresos; el gasto va en el oscuro con su
    // «−».
    expect(
      tester.widget<Text>(find.text(r'+$1.240.000')).style!.color,
      AppPalette.moneyIn,
    );
    expect(
      tester.widget<Text>(find.text(r'−$860.000')).style!.color,
      AppPalette.ink,
    );
  });

  testWidgets('el bloque de saldo cuadra: solo ingresos y gastos', (
    final tester,
  ) async {
    await _montar(tester, finanzas: _conDatos(), perfil: _perfil);

    // EL DEFECTO QUE ESTE TEST IMPIDE QUE VUELVA: el bloque tenía una
    // TERCERA fila, "Gastos fijos −$320.000", con el mismo formato que las
    // otras dos, pero `FinancesSummaryEntity.balance` es
    // `totalIncome - totalExpenses` y los gastos fijos no entran. Quien
    // sumaba las tres filas obtenía $60.000 mientras el titular decía
    // $380.000.
    final bloque = find.byKey(const Key('inicio-tarjeta-saldo'));
    expect(bloque, findsOneWidget);
    expect(
      find.descendant(of: bloque, matching: find.textContaining('320.000')),
      findsNothing,
      reason: 'ingresos y gastos, y nada más que se reste por su cuenta',
    );
    expect(
      find.descendant(of: bloque, matching: find.text('Gastos fijos')),
      findsNothing,
    );

    // 1.240.000 − 860.000 = 380.000, que es la cifra héroe. Comprobado
    // leyendo las dos cifras, no el código que las pinta.
    expect(
      find.descendant(of: bloque, matching: find.text(r'+$1.240.000')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: bloque, matching: find.text(r'−$860.000')),
      findsOneWidget,
    );
    expect(find.text(r'$380.000'), findsOneWidget);
  });

  testWidgets('los gastos fijos van aparte, sin signo y con su aviso', (
    final tester,
  ) async {
    await _montar(tester, finanzas: _conDatos(), perfil: _perfil);

    expect(find.text('Gastos fijos'), findsOneWidget);

    // SIN signo menos: el menos de una fila significa "ya se restó del
    // balance", y un gasto fijo no se resta.
    expect(find.text(r'−$320.000'), findsNothing);
    expect(find.text(r'$320.000'), findsOneWidget);

    // Y lo dice con palabras, no solo con la maquetación.
    expect(find.text('No se restan del balance'), findsOneWidget);
  });

  testWidgets('el aviso de gastos fijos puede usar 2 líneas', (
    final tester,
  ) async {
    await _montar(
      tester,
      finanzas: _conDatos(),
      perfil: _perfil,
      textScale: 2.0,
    );
    final aviso = find.text('No se restan del balance', skipOffstage: false);
    expect(tester.widget<Text>(aviso).maxLines, 2);
  });

  testWidgets('el aviso de verificar correo va bajo la tarjeta, y con letra '
      '2,0 el balance se ve en la primera pantalla', (final tester) async {
    await _montar(
      tester,
      finanzas: _conDatos(),
      perfil: _perfil,
      textScale: 2.0,
      correoVerificado: false,
    );

    final tarjeta = find.byKey(const Key('inicio-tarjeta-saldo'));
    expect(
      tester.getBottomLeft(find.text(r'$380.000')).dy,
      lessThan(900),
      reason: 'el balance, dentro de la primera pantalla',
    );
    // El aviso puede quedar fuera de la pantalla: se busca sin filtrar.
    final aviso = find.text('Verifica tu correo', skipOffstage: false);
    await tester.scrollUntilVisible(aviso, 300);
    expect(
      tester.getTopLeft(aviso).dy,
      greaterThan(tester.getBottomLeft(tarjeta).dy),
    );
  });

  testWidgets('la barra de meta dice qué mide', (final tester) async {
    await _montar(tester, finanzas: _conDatos(), perfil: _perfil);

    // 1.240.000 de 500.000: el porcentaje no se recorta en 100.
    expect(find.text('Ingresos: 248 % de tu meta'), findsOneWidget);
    expect(find.text(r'$1.240.000 de $500.000'), findsOneWidget);
  });

  testWidgets('sin meta no se dibuja la barra', (final tester) async {
    await _montar(tester, finanzas: _FinanzasFalsas(), perfil: _perfil);

    expect(find.textContaining('de tu meta'), findsNothing);
  });

  testWidgets('sin gastos fijos la sección no se dibuja', (final tester) async {
    await _montar(tester, finanzas: _FinanzasFalsas(), perfil: _perfil);

    expect(find.text('Gastos fijos'), findsNothing);
    expect(find.text('Comprometido cada mes'), findsNothing);
  });

  testWidgets('un fallo NO se dibuja como un cero', (final tester) async {
    final finanzas = _FinanzasFalsas(
      error: 'No tienes permiso para leer esto.',
    );
    await _montar(tester, finanzas: finanzas, perfil: _perfil);

    // El bloque de saldo no consultaba `error` ni `isLoading` en ninguna
    // línea: ante un permission-denied mostraba "$0", "Sin datos" y
    // "Registra tus primeros ingresos", presentando un fallo como si el
    // usuario no tuviera datos.
    expect(find.text(r'$0'), findsNothing);
    expect(find.text('No tienes permiso para leer esto.'), findsWidgets);

    await tester.tap(find.text('Reintentar').first);
    expect(finanzas.reintentos, 1);
  });

  testWidgets('mientras carga se pinta el esqueleto, no un spinner', (
    final tester,
  ) async {
    final finanzas = _FinanzasFalsas(
      isLoading: true,
      isLoadingTransactions: true,
    );
    await _montar(tester, finanzas: finanzas, perfil: _perfil);

    expect(find.byType(PagateSkeleton), findsWidgets);
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

  testWidgets('los dos botones de registrar llaman a su acción', (
    final tester,
  ) async {
    final acciones = await _montar(
      tester,
      finanzas: _conDatos(),
      perfil: _perfil,
    );

    await tester.tap(find.text('+ Ingreso'));
    await tester.tap(find.text('− Gasto'));
    expect(acciones.ingreso, 1);
    expect(acciones.gasto, 1);
  });

  testWidgets('el valor hora está en la portada y lleva a calcularlo', (
    final tester,
  ) async {
    final acciones = await _montar(
      tester,
      finanzas: _conDatos(),
      perfil: _perfil,
      valorHora: const HourlyRateEntity(
        desiredMonthlySalary: 768000,
        availableHoursPerMonth: 160,
      ),
    );

    // En la franja al pie de la tarjeta del saldo.
    final tarjeta = find.byKey(const Key('inicio-tarjeta-saldo'));
    expect(
      find.descendant(of: tarjeta, matching: find.text('Tu hora vale')),
      findsOneWidget,
    );
    expect(find.text(r'$4.800'), findsOneWidget);
    expect(find.text('Con 160 horas al mes'), findsOneWidget);

    await tester.tap(find.text('Tu hora vale'));
    expect(acciones.valorHora, 1);
  });

  testWidgets('con letra 2,0 el valor hora baja bajo la etiqueta', (
    final tester,
  ) async {
    await _montar(
      tester,
      finanzas: _conDatos(),
      perfil: _perfil,
      valorHora: const HourlyRateEntity(
        desiredMonthlySalary: 768000,
        availableHoursPerMonth: 160,
      ),
      textScale: 2.0,
    );

    // Lado a lado, la etiqueta se partía en cinco líneas de una palabra.
    expect(tester.takeException(), isNull);
    expect(
      tester.getTopLeft(find.text(r'$4.800')).dy,
      greaterThan(tester.getTopLeft(find.text('Con 160 horas al mes')).dy),
    );
    expect(
      tester.getSize(find.text('Tu hora vale')).height,
      lessThan(2 * 14 * 2.0 * 1.6),
      reason: 'una sola línea',
    );
  });

  testWidgets('sin valor hora configurado invita a calcularlo', (
    final tester,
  ) async {
    await _montar(tester, finanzas: _conDatos(), perfil: _perfil);

    final calcular = tester.widget<Text>(find.text('Calcular'));
    expect(calcular.style!.color, AppPalette.brand);
  });

  testWidgets('los movimientos salen con su fecha, categoría y signo', (
    final tester,
  ) async {
    await _montar(tester, finanzas: _conDatos(), perfil: _perfil);

    expect(find.text('Venta feria Lastarria'), findsOneWidget);
    expect(find.text('12 oct · Venta en feria'), findsOneWidget);
    expect(find.text(r'+$120.000'), findsOneWidget);
    expect(find.text(r'−$35.000'), findsOneWidget);

    // Ingreso en verde dinero, gasto en tinta.
    expect(
      tester.widget<Text>(find.text(r'+$120.000')).style!.color,
      AppPalette.moneyIn,
    );
    expect(
      tester.widget<Text>(find.text(r'−$35.000')).style!.color,
      AppPalette.textPrimary,
    );
  });

  testWidgets('sin movimientos el estado vacío dice qué hacer', (
    final tester,
  ) async {
    await _montar(tester, finanzas: _FinanzasFalsas(), perfil: _perfil);

    expect(find.text('Sin movimientos este mes'), findsOneWidget);
    expect(find.byType(PagateEmptyState), findsOneWidget);
  });

  testWidgets('una cuenta sin ningún movimiento ofrece registrar el primero', (
    final tester,
  ) async {
    final acciones = await _montar(
      tester,
      finanzas: _FinanzasFalsas(),
      perfil: _perfil,
    );

    expect(find.text('Ver Finanzas'), findsNothing);
    await tester.ensureVisible(find.text('Registrar movimiento'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Registrar movimiento'));
    expect(acciones.ingreso, 1);
    expect(acciones.finanzas, 0);
  });

  testWidgets('con movimientos en otros meses, el vacío lleva a Finanzas', (
    final tester,
  ) async {
    final acciones = await _montar(
      tester,
      finanzas: _FinanzasFalsas(
        months: const [
          FinancesSummaryEntity(
            monthKey: '2026-09',
            totalIncome: 900000,
            totalExpenses: 700000,
            transactionCount: 2,
          ),
        ],
      ),
      perfil: _perfil,
    );

    expect(find.text('Registrar movimiento'), findsNothing);
    await tester.ensureVisible(find.text('Ver Finanzas'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ver Finanzas'));
    expect(acciones.finanzas, 1);
  });

  testWidgets('el stock bajo solo aparece si hay algo que decir', (
    final tester,
  ) async {
    await _montar(tester, finanzas: _conDatos(), perfil: _perfil);
    expect(find.textContaining('Stock bajo'), findsNothing);

    await _montar(
      tester,
      finanzas: _conDatos(),
      perfil: _perfil,
      inventario: _InventarioFalso(
        allItems: const [
          InventoryItemEntity(
            id: 'i1',
            name: 'Esmalte celadón',
            type: InventoryItemType.material,
            price: 12000,
            stock: 0,
            minStock: 5,
            unit: 'un.',
          ),
          InventoryItemEntity(
            id: 'i2',
            name: 'Greda de alta',
            type: InventoryItemType.material,
            price: 9000,
            stock: 2,
            minStock: 6,
            unit: 'un.',
          ),
        ],
      ),
    );

    expect(find.text('Stock bajo (2)'), findsOneWidget);
    expect(find.text('2 materiales'), findsOneWidget);
  });

  testWidgets('el stock bajo cuenta productos y materiales, no solo la '
      'pestaña activa de Inventario', (final tester) async {
    InventoryItemEntity item(
      final String id,
      final InventoryItemType tipo,
    ) => InventoryItemEntity(
      id: id,
      name: 'Item $id',
      type: tipo,
      price: 1000,
      stock: 0,
      minStock: 5,
      unit: 'un.',
    );
    final producto = item('p1', InventoryItemType.product);

    // EL DEFECTO: Inicio leía `allItems`, que solo trae la pestaña activa
    // de Inventario. Con «Productos» activa, los materiales sin stock no
    // contaban.
    await _montar(
      tester,
      finanzas: _conDatos(),
      perfil: _perfil,
      inventario: _InventarioFalso(
        allItems: [producto],
        inventarioCompleto: [
          producto,
          item('m1', InventoryItemType.material),
          item('m2', InventoryItemType.material),
        ],
      ),
    );

    expect(find.text('Stock bajo (3)'), findsOneWidget);
    expect(find.text('1 producto y 2 materiales'), findsOneWidget);
  });

  testWidgets('la fila de stock bajo lleva a Inventario', (final tester) async {
    final acciones = await _montar(
      tester,
      finanzas: _conDatos(),
      perfil: _perfil,
      inventario: _InventarioFalso(
        allItems: const [
          InventoryItemEntity(
            id: 'm1',
            name: 'Esmalte',
            type: InventoryItemType.material,
            price: 1000,
            stock: 0,
            minStock: 5,
            unit: 'un.',
          ),
        ],
      ),
    );

    await tester.tap(find.text('Stock bajo (1)'));
    expect(acciones.inventario, 1);
  });

  group('primeros pasos', () {
    testWidgets('una cuenta sin movimientos ve la guía con su avance', (
      final tester,
    ) async {
      final acciones = await _montar(
        tester,
        finanzas: _FinanzasFalsas(),
        perfil: _perfil,
      );

      expect(find.text('Primeros pasos'), findsOneWidget);
      expect(find.text('1 de 4'), findsOneWidget);

      final guia = find.byKey(const Key('inicio-primeros-pasos'));
      await tester.tap(
        find.descendant(of: guia, matching: find.text('Registrar')),
      );
      await tester.tap(
        find.descendant(of: guia, matching: find.text('Calcular')),
      );
      await tester.tap(
        find.descendant(of: guia, matching: find.text('Agregar')),
      );
      expect(acciones.ingreso, 1);
      expect(acciones.valorHora, 1);
      expect(acciones.inventario, 1);
    });

    testWidgets('lo ya hecho cuenta y pierde su botón', (final tester) async {
      await _montar(
        tester,
        finanzas: _FinanzasFalsas(),
        perfil: _perfil,
        valorHora: const HourlyRateEntity(
          desiredMonthlySalary: 768000,
          availableHoursPerMonth: 160,
        ),
      );

      expect(find.text('2 de 4'), findsOneWidget);
      final guia = find.byKey(const Key('inicio-primeros-pasos'));
      expect(
        find.descendant(of: guia, matching: find.text('Calcular')),
        findsNothing,
      );
    });

    testWidgets('desaparece con el primer movimiento', (final tester) async {
      await _montar(tester, finanzas: _conDatos(), perfil: _perfil);
      expect(find.text('Primeros pasos'), findsNothing);
    });

    testWidgets('mientras carga no se dibuja', (final tester) async {
      await _montar(
        tester,
        finanzas: _FinanzasFalsas(isLoading: true),
        perfil: _perfil,
      );
      expect(find.text('Primeros pasos'), findsNothing);
    });
  });

  testWidgets('el selector de mes está en Inicio y cambia el mes', (
    final tester,
  ) async {
    final finanzas = _conDatos();
    await _montar(tester, finanzas: finanzas, perfil: _perfil);

    // Antes el mes era un estado invisible compartido con Finanzas: tocar
    // "julio" allí cambiaba el balance de aquí sin decirlo.
    final selector = find.byKey(const Key('inicio-selector-mes'));
    expect(
      find.descendant(
        of: find.byKey(const Key('inicio-tarjeta-saldo')),
        matching: selector,
      ),
      findsOneWidget,
      reason: 'dentro de la tarjeta, junto al rótulo del balance',
    );

    await tester.tap(selector);
    await tester.pumpAndSettle();
    // El año entero: «sep 26» se leía como un día.
    expect(find.text('sep 26'), findsNothing);
    await tester.tap(find.text('sep 2026'));
    await tester.pumpAndSettle();
    expect(finanzas.mesesElegidos, ['2026-09']);
  });

  testWidgets('con un solo mes la banda del selector desaparece entera', (
    final tester,
  ) async {
    await _montar(tester, finanzas: _FinanzasFalsas(), perfil: _perfil);

    // Una cuenta recién creada veía 45 dp de hueco vacío entre la barra de
    // identidad y el balance: el selector no se dibujaba pero su banda
    // seguía reservando alto.
    expect(find.byKey(const Key('inicio-selector-mes')), findsNothing);
    expect(
      tester.getTopLeft(find.textContaining('BALANCE DE')).dy,
      lessThan(200),
    );
  });

  testWidgets('no desborda a 1,3x ni a 2,0x', (final tester) async {
    await _montar(
      tester,
      finanzas: _conDatos(),
      perfil: _perfil,
      textScale: 1.3,
    );
    expect(tester.takeException(), isNull);

    await _montar(
      tester,
      finanzas: _conDatos(),
      perfil: _perfil,
      textScale: 2.0,
    );
    expect(tester.takeException(), isNull);
  });
}
