// PROPÓSITO
// ---------
// Widget test del formulario de movimientos, sin Firebase: un repositorio
// falso recoge lo que se guarda. Comprueba lo que exige el contrato C-3 en el
// cliente: los dos campos nuevos solo existen en un INGRESO, la comisión es
// opcional, no puede superar el monto, y lo que el usuario eligió llega tal
// cual a la capa de datos. Desde la variante A el formulario es una pantalla:
// el total grande es el campo del monto y las opciones se eligen en filas.

import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:pagate_ia/core/constants/app_constants.dart';
import 'package:pagate_ia/core/theme/app_theme.dart';
import 'package:pagate_ia/core/widgets/widgets.dart';
import 'package:pagate_ia/features/finances/domain/entities/finances_summary_entity.dart';
import 'package:pagate_ia/features/finances/domain/entities/finances_transaction_entity.dart';
import 'package:pagate_ia/features/finances/domain/entities/fixed_expense_entity.dart';
import 'package:pagate_ia/features/finances/domain/repositories/finances_repository.dart';
import 'package:pagate_ia/features/finances/presentation/providers/finances_provider.dart';
import 'package:pagate_ia/features/finances/presentation/widgets/transaction_form_sheet.dart';

/// Repositorio falso: guarda lo que le mandan, o revienta si se le pide.
class FakeRepository implements FinancesRepository {
  final List<FinancesTransactionEntity> added = [];

  /// Si no es nulo, `addTransaction` lo lanza en vez de guardar. Es lo que
  /// permite probar el camino de error, que era el que no se veía.
  Object? errorAlGuardar;

  @override
  Stream<List<FinancesSummaryEntity>> watchMonths() => const Stream.empty();

  @override
  Stream<List<FinancesTransactionEntity>> watchTransactions(
    final String monthKey,
  ) =>
      const Stream.empty();

  @override
  Stream<List<FixedExpenseEntity>> watchFixedExpenses() =>
      const Stream.empty();

  @override
  Future<void> addTransaction(
    final FinancesTransactionEntity transaction,
  ) async {
    final error = errorAlGuardar;
    if (error != null) throw error;
    added.add(transaction);
  }

  @override
  Future<void> updateTransaction(
    final FinancesTransactionEntity transaction,
  ) async {}

  @override
  Future<void> deleteTransaction(final String transactionId) async {}

  @override
  Future<void> addFixedExpense({
    required final String name,
    required final double amount,
  }) async {}

  @override
  Future<void> deleteFixedExpense(final String id) async {}
}

void main() {
  late FakeRepository repository;
  late FinancesProvider provider;

  setUp(() {
    repository = FakeRepository();
    provider = FinancesProvider(repository: repository);
  });

  tearDown(() => provider.dispose());

  /// Pantalla alta: el formulario entero cabe y no hay filas sin construir.
  void pantallaAlta(final WidgetTester tester) {
    tester.view
      ..physicalSize = const Size(420, 1400)
      ..devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
  }

  Future<void> montar(
    final WidgetTester tester, {
    final TransactionType tipo = TransactionType.income,
  }) async {
    pantallaAlta(tester);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: ChangeNotifierProvider<FinancesProvider>.value(
          value: provider,
          child: TransactionFormSheet(initialType: tipo),
        ),
      ),
    );
    await tester.pump();
  }

  /// Escribe en un campo del formulario. El total grande ES el campo del
  /// monto y va primero.
  Future<void> escribir(
    final WidgetTester tester,
    final String etiqueta,
    final String texto,
  ) async {
    final campo = find.descendant(
      of: find.byType(TransactionFormSheet),
      matching: find.byType(TextFormField),
    );
    final indices = {'monto': 0, 'titulo': 1};
    await tester.enterText(campo.at(indices[etiqueta]!), texto);
    await tester.pump();
  }

  /// Abre la fila [fila] y elige [opcion] en su hoja.
  Future<void> elegir(
    final WidgetTester tester,
    final String fila,
    final String opcion,
  ) async {
    await tester.tap(find.text(fila));
    await tester.pumpAndSettle();
    await tester.tap(
      find.descendant(of: find.byType(PagateSheet), matching: find.text(opcion)),
    );
    await tester.pumpAndSettle();
  }

  /// Abre la hoja de la comisión y escribe [texto]. No la cierra.
  Future<void> escribirComision(
    final WidgetTester tester,
    final String texto,
  ) async {
    await tester.tap(find.text('Comisión'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.descendant(
        of: find.byType(PagateSheet),
        matching: find.byType(TextFormField),
      ),
      texto,
    );
    await tester.pump();
  }

  Future<void> ponerComision(
    final WidgetTester tester,
    final String texto,
  ) async {
    await escribirComision(tester, texto);
    await tester.tap(find.text('Listo'));
    await tester.pumpAndSettle();
  }

  Future<void> enviar(final WidgetTester tester, final String etiqueta) async {
    await tester.tap(find.text(etiqueta));
    await tester.pumpAndSettle();
  }

  testWidgets('el total grande es el campo del monto, sin otro «Monto»', (
    final tester,
  ) async {
    await montar(tester);

    expect(find.text('MONTO'), findsOneWidget);
    expect(find.text('Monto'), findsNothing, reason: 'sin campo duplicado');

    // Ingreso: verde con «+».
    final signo = tester.widget<Text>(find.text(r'+$'));
    expect(signo.style?.color, AppPalette.moneyIn);

    // Gasto: oscuro con «−».
    await tester.tap(find.text('Gasto'));
    await tester.pump();
    expect(
      tester.widget<Text>(find.text(r'−$')).style?.color,
      AppPalette.ink,
    );
  });

  testWidgets('en un ingreso aparecen el documento y la comisión', (
    final tester,
  ) async {
    await montar(tester);

    expect(find.text('Documento'), findsOneWidget);
    expect(find.text('Sin documento'), findsOneWidget);
    expect(find.text('Comisión'), findsOneWidget);

    await tester.tap(find.text('Documento'));
    await tester.pumpAndSettle();
    expect(find.text('Boleta de venta'), findsOneWidget);
    expect(find.text('Boleta de honorarios'), findsOneWidget);
    await tester.tap(find.text('Sin documento').last);
    await tester.pumpAndSettle();

    await escribirComision(tester, '');
    expect(
      find.textContaining('Mercado Pago'),
      findsOneWidget,
      reason: 'la ayuda tiene que nombrar los medios de pago reales',
    );
  });

  testWidgets('en un gasto no aparece ninguno de los dos', (
    final tester,
  ) async {
    await montar(tester, tipo: TransactionType.expense);

    expect(find.text('Documento'), findsNothing);
    expect(find.text('Sin documento'), findsNothing);
    expect(find.text('Comisión'), findsNothing);
  });

  testWidgets('al cambiar de ingreso a gasto se olvidan los dos campos', (
    final tester,
  ) async {
    await montar(tester);
    await escribir(tester, 'monto', '120.000');
    await ponerComision(tester, '5.000');
    await elegir(tester, 'Documento', 'Boleta de venta');
    expect(find.text(r'$5.000'), findsOneWidget);

    await tester.tap(find.text('Gasto'));
    await tester.pump();
    expect(find.text('Comisión'), findsNothing);

    await tester.tap(find.text('Ingreso'));
    await tester.pump();
    // Una comisión puesta para un ingreso no puede sobrevivir a un paso por
    // Gasto, ni el documento elegido.
    expect(find.text(r'$5.000'), findsNothing);
    expect(find.text(r'$0'), findsOneWidget);
    expect(find.text('Sin documento'), findsOneWidget);
  });

  testWidgets('guarda el documento y la comisión elegidos', (
    final tester,
  ) async {
    await montar(tester);
    await escribir(tester, 'titulo', 'Venta en feria');
    await escribir(tester, 'monto', '120.000');
    await ponerComision(tester, '4.560');
    await elegir(tester, 'Documento', 'Boleta de venta');

    await enviar(tester, 'Crear ingreso');

    expect(repository.added, hasLength(1));
    final guardada = repository.added.single;
    expect(guardada.title, 'Venta en feria');
    expect(guardada.amount, 120000);
    expect(guardada.platformFee, 4560);
    expect(guardada.docType, TransactionDocType.boletaVenta);
    expect(guardada.netAmount, 115440);
  });

  testWidgets('sin comisión el movimiento queda con los valores por defecto', (
    final tester,
  ) async {
    await montar(tester);
    await escribir(tester, 'titulo', 'Pedido por transferencia');
    await escribir(tester, 'monto', '80.000');

    await enviar(tester, 'Crear ingreso');

    expect(repository.added, hasLength(1));
    final guardada = repository.added.single;
    expect(guardada.platformFee, 0);
    expect(guardada.docType, TransactionDocType.sinDocumento);
    expect(guardada.netAmount, 80000);
  });

  testWidgets('guarda la categoría elegida', (final tester) async {
    await montar(tester, tipo: TransactionType.expense);
    await escribir(tester, 'titulo', 'Greda 25 kg');
    await escribir(tester, 'monto', '35.000');
    await elegir(tester, 'Categoría', 'Herramientas');

    await enviar(tester, 'Crear gasto');

    expect(repository.added.single.category, 'Herramientas');
    expect(repository.added.single.type, TransactionType.expense);
  });

  testWidgets('las categorías de ingreso son las del oficio chileno', (
    final tester,
  ) async {
    await montar(tester);
    await tester.tap(find.text('Categoría'));
    await tester.pumpAndSettle();

    final hoja = find.byType(PagateSheet);
    for (final categoria in incomeCategories) {
      expect(
        find.descendant(of: hoja, matching: find.text(categoria)),
        findsOneWidget,
        reason: categoria,
      );
    }
    // Las genéricas de antes ya no se ofrecen.
    expect(find.text('Materiales'), findsNothing);
    expect(find.text('Servicios'), findsNothing);
  });

  testWidgets('las categorías de gasto son las de un taller', (
    final tester,
  ) async {
    await montar(tester, tipo: TransactionType.expense);
    await tester.tap(find.text('Categoría'));
    await tester.pumpAndSettle();

    final hoja = find.byType(PagateSheet);
    for (final categoria in expenseCategories) {
      expect(
        find.descendant(of: hoja, matching: find.text(categoria)),
        findsOneWidget,
        reason: categoria,
      );
    }
    // Un gasto no ofrece categorías de ingreso.
    expect(find.text('Venta en feria'), findsNothing);
  });

  testWidgets('una comisión mayor que el monto no se acepta en su hoja', (
    final tester,
  ) async {
    await montar(tester);
    await escribir(tester, 'monto', '20.000');
    await escribirComision(tester, '30.000');
    await tester.tap(find.text('Listo'));
    await tester.pumpAndSettle();

    expect(
      find.text('La comisión no puede ser mayor que el monto'),
      findsOneWidget,
    );
    expect(find.byType(PagateSheet), findsOneWidget, reason: 'sigue abierta');
  });

  testWidgets('si el monto baja por debajo de la comisión, no se guarda', (
    final tester,
  ) async {
    await montar(tester);
    await escribir(tester, 'titulo', 'Venta por Instagram');
    await escribir(tester, 'monto', '20.000');
    await ponerComision(tester, '10.000');
    await escribir(tester, 'monto', '5.000');

    await enviar(tester, 'Crear ingreso');

    expect(repository.added, isEmpty);
    expect(
      find.text('La comisión no puede ser mayor que el monto'),
      findsOneWidget,
    );
  });

  testWidgets('Limpiar deja el formulario como al abrirlo', (
    final tester,
  ) async {
    await montar(tester);
    await escribir(tester, 'titulo', 'Feria del sábado');
    await escribir(tester, 'monto', '120.000');
    await ponerComision(tester, '4.560');
    await elegir(tester, 'Documento', 'Boleta de venta');

    await tester.tap(find.text('Limpiar'));
    await tester.pump();

    expect(find.text('Feria del sábado'), findsNothing);
    expect(find.text('120.000'), findsNothing);
    expect(find.text(r'$0'), findsOneWidget);
    expect(find.text('Sin documento'), findsOneWidget);
    // El tipo se mantiene.
    expect(find.text('Crear ingreso'), findsOneWidget);
  });

  testWidgets('Limpiar va arriba y abajo queda solo la acción de crear', (
    final tester,
  ) async {
    await montar(tester);

    expect(
      find.descendant(of: find.byType(AppBar), matching: find.text('Limpiar')),
      findsOneWidget,
    );
    expect(find.byType(PagateClearCreateBar), findsNothing);
    final crear = find.widgetWithText(PagatePrimaryButton, 'Crear ingreso');
    expect(crear, findsOneWidget);
    // A todo el ancho, menos los 16 dp de cada lado.
    expect(tester.getSize(crear).width, 420 - 2 * AppSpacing.x4);
  });

  testWidgets('el monto no lleva texto de ayuda', (final tester) async {
    await montar(tester);
    expect(find.textContaining('El teclado es numérico'), findsNothing);
  });

  testWidgets('la tarjeta de filas tiene el mismo margen que los campos', (
    final tester,
  ) async {
    await montar(tester);

    final tarjeta = find.byType(PagateSectionCard);
    final titulo = find.byType(TextFormField).at(1);
    expect(tester.getTopLeft(tarjeta).dx, tester.getTopLeft(titulo).dx);
    expect(tester.getTopRight(tarjeta).dx, tester.getTopRight(titulo).dx);
  });

  // ─── EL CAMINO DE ERROR, que era invisible ────────────────────────────
  //
  // Lo que pasaba: el aviso se pintaba con `ScaffoldMessenger`, es decir
  // dentro del Scaffold de la pantalla que está DEBAJO del formulario. Al
  // fallar el guardado de un ingreso, ocho capturas seguidas sin spinner,
  // sin aviso y sin error. El botón parecía no hacer nada.
  //
  // Un `find.text` no habría detectado nada, porque el texto SÍ estaba en el
  // árbol. Por eso estos tests abren el formulario como lo abre la app y
  // comprueban el hit test.

  /// ¿Llega un toque en el centro de [finder] hasta su render object?
  bool recibeToques(final WidgetTester tester, final Finder finder) {
    final objetivo = tester.renderObject(finder);
    final resultado = HitTestResult();
    tester.binding.hitTestInView(
      resultado,
      tester.getCenter(finder),
      tester.view.viewId,
    );
    return resultado.path.any((final e) => e.target == objetivo);
  }

  /// Abre el formulario con `showTransactionSheet`, que es como lo abre la
  /// app: encima de otra pantalla.
  Future<void> abrirComoLaApp(final WidgetTester tester) async {
    pantallaAlta(tester);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: ChangeNotifierProvider<FinancesProvider>.value(
          value: provider,
          child: Scaffold(
            body: Builder(
              builder: (final context) => Center(
                child: ElevatedButton(
                  onPressed: () => showTransactionSheet(context),
                  child: const Text('Registrar movimiento'),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Registrar movimiento'));
    await tester.pumpAndSettle();
  }

  testWidgets('un guardado fallido SE VE dentro del formulario', (
    final tester,
  ) async {
    repository.errorAlGuardar = FirebaseException(
      plugin: 'cloud_firestore',
      code: 'permission-denied',
    );

    await abrirComoLaApp(tester);
    await escribir(tester, 'titulo', 'Venta en feria');
    await escribir(tester, 'monto', '120.000');
    await enviar(tester, 'Crear ingreso');

    // 1. El error está en pantalla.
    final aviso = find.byType(PagateInlineError);
    expect(aviso, findsOneWidget, reason: 'el fallo no puede ser silencioso');

    // 2. Y está DENTRO del formulario, no detrás de él.
    expect(
      find.descendant(
        of: find.byType(TransactionFormSheet),
        matching: aviso,
      ),
      findsOneWidget,
    );

    // 3. LA COMPROBACIÓN QUE IMPORTA: nada lo cubre.
    final texto = find.descendant(of: aviso, matching: find.byType(Text));
    expect(
      recibeToques(tester, texto),
      isTrue,
      reason: 'el aviso tiene que quedar por encima de todo',
    );

    // 4. El formulario sigue abierto y lo escrito sigue ahí: un fallo de
    // red no puede costarle al usuario el formulario entero.
    expect(find.text('Crear ingreso'), findsOneWidget);
    expect(find.text('Venta en feria'), findsWidgets);
    expect(find.text('120.000'), findsOneWidget);
    expect(repository.added, isEmpty);
  });

  testWidgets('el texto del error habla de GUARDAR, no de ver', (
    final tester,
  ) async {
    repository.errorAlGuardar = FirebaseException(
      plugin: 'cloud_firestore',
      code: 'permission-denied',
    );

    await abrirComoLaApp(tester);
    await escribir(tester, 'titulo', 'Venta por Instagram');
    await escribir(tester, 'monto', '45.000');
    await enviar(tester, 'Crear ingreso');

    expect(find.textContaining('No se guardó'), findsOneWidget);
    expect(find.textContaining('ver estos datos'), findsNothing);
  });

  testWidgets('el botón vuelve a estar pulsable tras el fallo', (
    final tester,
  ) async {
    repository.errorAlGuardar = FirebaseException(
      plugin: 'cloud_firestore',
      code: 'unavailable',
    );

    await abrirComoLaApp(tester);
    await escribir(tester, 'titulo', 'Pedido personalizado');
    await escribir(tester, 'monto', '80.000');
    await enviar(tester, 'Crear ingreso');
    expect(find.byType(PagateInlineError), findsOneWidget);

    // Segundo intento, ahora sin error: se guarda y el formulario se cierra.
    repository.errorAlGuardar = null;
    await enviar(tester, 'Crear ingreso');

    expect(repository.added, hasLength(1));
    expect(repository.added.single.amount, 80000);
    expect(find.byType(TransactionFormSheet), findsNothing);
  });

  testWidgets('al cambiar de tipo el error del intento anterior se va', (
    final tester,
  ) async {
    repository.errorAlGuardar = FirebaseException(
      plugin: 'cloud_firestore',
      code: 'unavailable',
    );

    await abrirComoLaApp(tester);
    await escribir(tester, 'titulo', 'Venta en feria');
    await escribir(tester, 'monto', '30.000');
    await enviar(tester, 'Crear ingreso');
    expect(find.byType(PagateInlineError), findsOneWidget);

    await tester.tap(find.text('Gasto'));
    await tester.pump();

    // El error era de otro movimiento: dejarlo visible sería mentir.
    expect(find.byType(PagateInlineError), findsNothing);
  });

  testWidgets('con letra 2,0 no desborda', (final tester) async {
    pantallaAlta(tester);
    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(
          size: Size(420, 1400),
          textScaler: TextScaler.linear(2),
        ),
        child: MaterialApp(
          theme: AppTheme.lightTheme,
          home: ChangeNotifierProvider<FinancesProvider>.value(
            value: provider,
            child: const TransactionFormSheet(),
          ),
        ),
      ),
    );
    await tester.pump();
    expect(tester.takeException(), isNull);

    // El título se achica junto a «Limpiar» en vez de cortarse.
    final titulo = find.text('Nuevo movimiento');
    expect(
      tester.getTopRight(titulo).dx,
      lessThanOrEqualTo(tester.getTopLeft(find.text('Limpiar')).dx),
    );
    expect(
      tester.renderObject<RenderParagraph>(titulo).didExceedMaxLines,
      isFalse,
    );
  });
}
