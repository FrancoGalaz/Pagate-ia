// PROPÓSITO
// ---------
// Widget test del formulario de fichas de inventario, sin Firebase. Cubre
// los dos defectos que cierra:
//
// 1. `supplier` y `code` existían en la entidad, en el modelo, en las reglas
//    y en la ficha, pero NINGÚN formulario los escribía: valían `null`
//    siempre. Aquí se comprueba que el formulario los ofrece, que lo
//    escrito llega tal cual a la capa de datos y que dejarlos vacíos guarda
//    `null` y no `''` (con `''` la ficha pintaría "Código" seguido de nada).
//
// 2. No había forma de editar una ficha. Aquí se comprueba que la misma
//    hoja se abre con los valores cargados, que guarda con el id y el tipo
//    originales, y que vaciar un campo opcional lo borra de verdad — lo que
//    `copyWith` NO permite, porque ahí `null` significa "déjalo como
//    estaba".
//
// La hoja se abre por el camino real (`mostrarHojaDeItem` /
// `mostrarHojaDeEdicionDeItem` sobre `showPagateSheet`) y no montando el
// widget a pelo: así el test también pasa por el `PopScope` de la hoja, que
// es quien pregunta antes de descartar.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:pagate_ia/core/theme/app_theme.dart';
import 'package:pagate_ia/features/inventory/domain/entities/inventory_item_entity.dart';
import 'package:pagate_ia/features/inventory/domain/entities/inventory_item_type.dart';
import 'package:pagate_ia/features/inventory/presentation/providers/inventory_provider.dart';
import 'package:pagate_ia/features/inventory/presentation/widgets/item_form_sheet.dart';

import 'fake_inventory_repository.dart';

/// Índice de cada campo dentro del `Form` de la hoja, en el orden en que se
/// dibujan.
const Map<String, int> _campos = {
  'nombre': 0,
  'precio': 1,
  'stock': 2,
  'minimo': 3,
  'unidad': 4,
  'proveedor': 5,
  'codigo': 6,
};

void main() {
  late FakeInventoryRepository repository;
  late InventoryProvider provider;

  setUp(() {
    repository = FakeInventoryRepository();
    provider = InventoryProvider(repository: repository);
  });

  tearDown(() async {
    provider.dispose();
    await repository.cerrar();
  });

  /// Monta una pantalla con un botón que abre la hoja, y la abre.
  Future<void> abrir(
    final WidgetTester tester, {
    final InventoryItemEntity? editar,
    final InventoryItemType tipo = InventoryItemType.product,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: ChangeNotifierProvider<InventoryProvider>.value(
          value: provider,
          child: Scaffold(
            body: Builder(
              builder: (final context) => Center(
                child: ElevatedButton(
                  onPressed: () => editar == null
                      ? mostrarHojaDeItem(context, tipo)
                      : mostrarHojaDeEdicionDeItem(context, editar),
                  child: const Text('Abrir'),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Abrir'));
    await tester.pumpAndSettle();
  }

  Finder campo(final String nombre) => find
      .descendant(
        of: find.byType(Form),
        matching: find.byType(TextFormField),
      )
      .at(_campos[nombre]!);

  Future<void> escribir(
    final WidgetTester tester,
    final String nombre,
    final String texto,
  ) async {
    await tester.ensureVisible(campo(nombre));
    await tester.enterText(campo(nombre), texto);
    await tester.pump();
  }

  /// El valor que tiene un campo ahora mismo.
  String leer(final String nombre) => _textoDe(campo(nombre));

  Future<void> guardar(
    final WidgetTester tester,
    final String etiqueta,
  ) async {
    final boton = find.text(etiqueta);
    await tester.ensureVisible(boton);
    await tester.pump();
    await tester.tap(boton);
    await tester.pumpAndSettle();
  }

  /// Ficha de referencia para los tests de edición.
  const ficha = InventoryItemEntity(
    id: 'item-1',
    name: 'Greda 25 kg',
    type: InventoryItemType.material,
    price: 18990,
    stock: 4,
    minStock: 2,
    unit: 'sacos',
    supplier: 'Cerámicas del Sur',
    code: 'GR-25',
  );

  // ─── Alta ────────────────────────────────────────────────────────────

  testWidgets('el alta ofrece proveedor y código, etiquetados de opcionales', (
    final tester,
  ) async {
    await abrir(tester);

    expect(find.text('Nuevo producto'), findsOneWidget);
    expect(
      find.text('Proveedor (opcional)'),
      findsOneWidget,
      reason: 'el campo existía en la entidad y en las reglas, pero ningún '
          'formulario lo ofrecía',
    );
    expect(find.text('Código (opcional)'), findsOneWidget);
  });

  testWidgets('guarda el proveedor y el código escritos', (final tester) async {
    await abrir(tester);
    await escribir(tester, 'nombre', 'Taza de greda');
    await escribir(tester, 'precio', '12.500');
    await escribir(tester, 'proveedor', 'Cerámicas del Sur');
    await escribir(tester, 'codigo', 'TZ-01');

    await guardar(tester, 'Guardar ficha');

    expect(repository.agregados, hasLength(1));
    final guardada = repository.agregados.single;
    expect(guardada.name, 'Taza de greda');
    expect(guardada.price, 12500);
    expect(guardada.supplier, 'Cerámicas del Sur');
    expect(guardada.code, 'TZ-01');
    expect(guardada.type, InventoryItemType.product);
  });

  testWidgets('un opcional vacío se guarda como null, no como cadena vacía', (
    final tester,
  ) async {
    await abrir(tester);
    await escribir(tester, 'nombre', 'Taza de greda');
    await escribir(tester, 'precio', '12.500');
    // El proveedor se escribe y se borra: el campo queda tocado y vacío.
    await escribir(tester, 'proveedor', 'Algo');
    await escribir(tester, 'proveedor', '   ');

    await guardar(tester, 'Guardar ficha');

    final guardada = repository.agregados.single;
    expect(guardada.supplier, isNull);
    expect(guardada.code, isNull);
  });

  testWidgets('sin proveedor ni código, el alta sigue siendo válida', (
    final tester,
  ) async {
    await abrir(tester, tipo: InventoryItemType.material);
    await escribir(tester, 'nombre', 'Greda 25 kg');
    await escribir(tester, 'precio', '18.990');

    await guardar(tester, 'Guardar ficha');

    expect(
      repository.agregados,
      hasLength(1),
      reason: 'los dos campos nuevos son opcionales: no pueden bloquear el '
          'guardado',
    );
  });

  // ─── Edición ─────────────────────────────────────────────────────────

  testWidgets('la edición carga los valores de la ficha', (
    final tester,
  ) async {
    await abrir(tester, editar: ficha);

    expect(find.text('Editar material'), findsOneWidget);
    expect(find.text('Guardar cambios'), findsOneWidget);
    expect(leer('nombre'), 'Greda 25 kg');
    expect(
      leer('precio'),
      '18990',
      reason: 'el precio se precarga en dígitos pelados, que es lo que '
          'parseCurrencyInput vuelve a leer sin ambigüedad',
    );
    expect(leer('stock'), '4');
    expect(leer('minimo'), '2');
    expect(leer('unidad'), 'sacos');
    expect(leer('proveedor'), 'Cerámicas del Sur');
    expect(leer('codigo'), 'GR-25');
  });

  testWidgets('guarda los cambios con el id y el tipo originales', (
    final tester,
  ) async {
    await abrir(tester, editar: ficha);
    await escribir(tester, 'nombre', 'Greda roja 25 kg');
    await escribir(tester, 'precio', '21.500');
    await escribir(tester, 'codigo', 'GR-25R');

    await guardar(tester, 'Guardar cambios');

    expect(repository.agregados, isEmpty, reason: 'editar no duplica fichas');
    expect(repository.actualizados, hasLength(1));
    final guardada = repository.actualizados.single;
    expect(guardada.id, 'item-1');
    expect(guardada.type, InventoryItemType.material);
    expect(guardada.name, 'Greda roja 25 kg');
    expect(guardada.price, 21500);
    expect(guardada.code, 'GR-25R');
    expect(guardada.supplier, 'Cerámicas del Sur');
    expect(guardada.stock, 4);
    expect(guardada.minStock, 2);
  });

  testWidgets('vaciar el proveedor en una edición lo borra de verdad', (
    final tester,
  ) async {
    await abrir(tester, editar: ficha);
    await escribir(tester, 'proveedor', '');

    await guardar(tester, 'Guardar cambios');

    expect(
      repository.actualizados.single.supplier,
      isNull,
      reason: 'por eso la entidad se construye a mano y no con copyWith: '
          'ahí null significa "no lo cambies"',
    );
  });

  testWidgets('cerrar una edición sin tocar nada no pregunta nada', (
    final tester,
  ) async {
    await abrir(tester, editar: ficha);

    await tester.tap(find.byTooltip('Cerrar'));
    await tester.pumpAndSettle();

    expect(
      find.text('¿Descartar los cambios?'),
      findsNothing,
      reason: 'en una edición los campos vienen llenos: "hay algo escrito" '
          'no puede significar "hay algo que perder"',
    );
    expect(find.byType(ItemFormSheet), findsNothing);
  });

  testWidgets('cerrar una edición con un cambio sí pregunta', (
    final tester,
  ) async {
    await abrir(tester, editar: ficha);
    await escribir(tester, 'nombre', 'Greda roja');

    await tester.tap(find.byTooltip('Cerrar'));
    await tester.pumpAndSettle();

    expect(find.text('¿Descartar los cambios?'), findsOneWidget);
    await tester.tap(find.text('Seguir editando'));
    await tester.pumpAndSettle();
    expect(find.byType(ItemFormSheet), findsOneWidget);
    expect(repository.actualizados, isEmpty);
  });

  testWidgets('si la escritura falla, el error se queda dentro de la hoja', (
    final tester,
  ) async {
    repository.errorAlGuardar = Exception('sin red');
    await abrir(tester, editar: ficha);
    await escribir(tester, 'nombre', 'Greda roja');

    await guardar(tester, 'Guardar cambios');

    expect(find.byType(ItemFormSheet), findsOneWidget);
    expect(
      find.textContaining('No se pudieron guardar los cambios'),
      findsOneWidget,
    );
  });
}

/// El texto que tiene escrito el campo que hay en [finder].
///
/// Se lee del controlador y no con `find.text`, que encontraría la misma
/// cadena en cualquier otro campo de la hoja.
String _textoDe(final Finder finder) {
  final campo = find
      .descendant(of: finder, matching: find.byType(TextField))
      .evaluate()
      .single
      .widget as TextField;
  return campo.controller?.text ?? '';
}
