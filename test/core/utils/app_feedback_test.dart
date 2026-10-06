// PROPÓSITO: que no vuelva a haber un aviso tapado.
//
// EL DEFECTO QUE ESTE ARCHIVO IMPIDE QUE VUELVA, y era el peor de la app:
// `AppFeedback` usaba `ScaffoldMessenger.of(context).showSnackBar(...)`. Un
// `SnackBar` no lo dibuja el messenger: lo dibuja el `Scaffold` registrado en
// él, dentro de SU árbol. Una hoja modal vive en el overlay del Navigator,
// por encima de ese Scaffold, y no trae Scaffold propio. Resultado: el aviso
// se pintaba detrás de la hoja, justo en el borde inferior que la hoja ocupa.
//
// En el camino de éxito la hoja se cierra antes de avisar y por eso se veía.
// En el `catch` la hoja sigue abierta: al fallar el guardado de un ingreso no
// aparecía spinner, ni aviso, ni error. El botón parecía no hacer nada.
//
// UN `find.text` NO HABRÍA DETECTADO NADA: el texto SÍ estaba en el árbol,
// solo que debajo de la hoja. Por eso aquí se comprueba el HIT TEST en el
// centro del aviso: si algo lo cubre, el toque no llega a su render object y
// el test falla. Es la única forma de que "no queda tapado" sea comprobable.

import 'dart:io';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pagate_ia/core/theme/app_theme.dart';
import 'package:pagate_ia/core/utils/app_feedback.dart';

const String _mensaje = 'No se guardó: esta cuenta no tiene permiso';

/// Separador de líneas. Se expresa como `RegExp` para que valga igual con
/// CRLF, que es como están guardados varios archivos del repo en Windows.
final RegExp _salto = RegExp(r'\r?\n');

/// Quita comentarios: varios archivos CITAN el defecto para explicarlo.
String _sinComentarios(final String fuente) {
  final sinBloques = fuente.replaceAll(RegExp(r'/\*.*?\*/', dotAll: true), '');
  return sinBloques
      .split(_salto)
      .map((final linea) {
        final i = linea.indexOf('//');
        return i == -1 ? linea : linea.substring(0, i);
      })
      .join('\n');
}

/// ¿Llega un toque en el centro de [finder] hasta su propio render object?
///
/// `false` significa que hay algo encima (una hoja modal, un velo, un
/// diálogo) o que está fuera de pantalla: en los dos casos, el usuario no
/// puede verlo ni tocarlo.
bool _recibeToques(final WidgetTester tester, final Finder finder) {
  final objetivo = tester.renderObject(finder);
  final resultado = HitTestResult();
  tester.binding.hitTestInView(
    resultado,
    tester.getCenter(finder),
    tester.view.viewId,
  );
  return resultado.path.any((final entrada) => entrada.target == objetivo);
}

/// Pantalla con un botón que abre una hoja modal alta, y dentro de la hoja
/// un botón que avisa. Es la forma exacta del formulario de movimientos.
Widget _appConHoja({
  required final void Function(BuildContext) alPulsarDentro,
  final double altoHoja = 560,
}) =>
    MaterialApp(
      theme: AppTheme.lightTheme,
      home: Scaffold(
        body: Builder(
          builder: (final pantalla) => Center(
            child: ElevatedButton(
              onPressed: () => showModalBottomSheet<void>(
                context: pantalla,
                isScrollControlled: true,
                builder: (final hoja) => SizedBox(
                  height: altoHoja,
                  child: Center(
                    child: ElevatedButton(
                      onPressed: () => alPulsarDentro(hoja),
                      child: const Text('Guardar'),
                    ),
                  ),
                ),
              ),
              child: const Text('Abrir hoja'),
            ),
          ),
        ),
      ),
    );

Future<void> _abrirHojaYPulsar(final WidgetTester tester) async {
  await tester.tap(find.text('Abrir hoja'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Guardar'));
  // Un frame para insertar la entrada del overlay y el tiempo de entrada
  // para que acabe de aparecer.
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 250));
}

void main() {
  tearDown(AppFeedback.dismiss);

  test('ninguna pantalla vuelve a avisar con ScaffoldMessenger', () {
    // DOS mecanismos de aviso es lo que dejó el error de guardado invisible:
    // `AppFeedback` para unas pantallas y `ScaffoldMessenger` suelto en
    // `ia_tab`. Toda la app avisa por `AppFeedback`, que pinta en el overlay
    // raíz y por tanto se ve también con una hoja o un diálogo encima.
    //
    // `app_theme.dart` no entra en el veto porque define `SnackBarThemeData`
    // y no muestra ningún aviso; si alguien vuelve a llamar al messenger
    // desde una pantalla, este test lo dice con archivo y línea.
    final culpables = <String>[];
    final fuentes = Directory('lib')
        .listSync(recursive: true)
        .whereType<File>()
        .where((final f) => f.path.endsWith('.dart'));

    for (final fuente in fuentes) {
      final lineas = _sinComentarios(fuente.readAsStringSync()).split(_salto);
      for (var i = 0; i < lineas.length; i++) {
        final linea = lineas[i];
        if (linea.contains('ScaffoldMessenger') ||
            linea.contains('showSnackBar(')) {
          culpables.add('${fuente.path}:${i + 1}: ${linea.trim()}');
        }
      }
    }
    expect(culpables, isEmpty, reason: culpables.join('\n'));
  });

  testWidgets('el aviso de error se ve ENCIMA de una hoja modal abierta', (
    final tester,
  ) async {
    await tester.pumpWidget(
      _appConHoja(
        alPulsarDentro: (final hoja) => AppFeedback.showError(hoja, _mensaje),
      ),
    );
    await _abrirHojaYPulsar(tester);

    expect(find.text(_mensaje), findsOneWidget);

    // LA COMPROBACIÓN QUE IMPORTA. Con el `SnackBar` anterior esto era
    // `false`: el texto estaba en el árbol y el usuario no veía nada.
    expect(
      _recibeToques(tester, find.text(_mensaje)),
      isTrue,
      reason: 'el aviso tiene que estar por encima de la hoja, no detrás',
    );

    // La hoja sigue abierta: el aviso no la cierra ni la sustituye.
    expect(find.text('Guardar'), findsOneWidget);
  });

  testWidgets('así quedaba antes: un SnackBar desde la hoja SÍ queda tapado', (
    final tester,
  ) async {
    // Este test no prueba código de la app: documenta por qué el arreglo no
    // podía ser "usar el messenger raíz". El messenger raíz delega el pintado
    // en el Scaffold de la pantalla, que está debajo de la hoja.
    await tester.pumpWidget(
      _appConHoja(
        alPulsarDentro: (final hoja) => ScaffoldMessenger.of(hoja)
            .showSnackBar(const SnackBar(content: Text(_mensaje))),
      ),
    );
    await _abrirHojaYPulsar(tester);
    await tester.pumpAndSettle();

    expect(find.text(_mensaje), findsOneWidget, reason: 'está en el árbol');
    expect(
      _recibeToques(tester, find.text(_mensaje)),
      isFalse,
      reason: 'y aun así el usuario no lo ve: esto era el defecto',
    );

    // Se deja correr el temporizador del SnackBar: `testWidgets` falla si
    // queda uno pendiente al terminar.
    await tester.pump(const Duration(seconds: 6));
    await tester.pumpAndSettle();
  });

  testWidgets('el aviso también se ve encima de un diálogo', (
    final tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: Scaffold(
          body: Builder(
            builder: (final pantalla) => Center(
              child: ElevatedButton(
                onPressed: () => showDialog<void>(
                  context: pantalla,
                  builder: (final dialogo) => AlertDialog(
                    content: ElevatedButton(
                      onPressed: () =>
                          AppFeedback.showError(dialogo, _mensaje),
                      child: const Text('Guardar'),
                    ),
                  ),
                ),
                child: const Text('Abrir diálogo'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Abrir diálogo'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Guardar'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));

    expect(_recibeToques(tester, find.text(_mensaje)), isTrue);
  });

  testWidgets('tocarlo lo cierra', (final tester) async {
    await tester.pumpWidget(
      _appConHoja(
        alPulsarDentro: (final hoja) => AppFeedback.showError(hoja, _mensaje),
      ),
    );
    await _abrirHojaYPulsar(tester);

    // `hitTestWarningShouldBeFatal`: si el toque no alcanzara el aviso, esto
    // sería un fallo y no una advertencia en consola.
    WidgetController.hitTestWarningShouldBeFatal = true;
    addTearDown(() => WidgetController.hitTestWarningShouldBeFatal = false);

    await tester.tap(find.text(_mensaje));
    await tester.pumpAndSettle();
    expect(find.text(_mensaje), findsNothing);
  });

  testWidgets('se va solo sin dejar temporizadores pendientes', (
    final tester,
  ) async {
    await tester.pumpWidget(
      _appConHoja(
        alPulsarDentro: (final hoja) => AppFeedback.showError(hoja, _mensaje),
      ),
    );
    await _abrirHojaYPulsar(tester);
    expect(find.text(_mensaje), findsOneWidget);

    // El tiempo de vida es una animación, no un `Timer`: `pumpAndSettle` lo
    // resuelve. Con `Timer` cada test que provocara un aviso terminaría con
    // un temporizador pendiente, que `testWidgets` marca como fallo.
    await tester.pumpAndSettle();
    expect(find.text(_mensaje), findsNothing);
  });

  testWidgets('dos avisos seguidos no se apilan', (final tester) async {
    await tester.pumpWidget(
      _appConHoja(
        alPulsarDentro: (final hoja) {
          AppFeedback.showMessage(hoja, 'Primero');
          AppFeedback.showError(hoja, 'Segundo');
        },
      ),
    );
    await _abrirHojaYPulsar(tester);

    expect(find.text('Primero'), findsNothing);
    expect(find.text('Segundo'), findsOneWidget);
    await tester.pumpAndSettle();
  });

  testWidgets('en una pantalla normal, sin hoja, también se ve', (
    final tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: Scaffold(
          body: Builder(
            builder: (final pantalla) => Center(
              child: ElevatedButton(
                onPressed: () => AppFeedback.showMessage(pantalla, _mensaje),
                child: const Text('Avisar'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Avisar'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));

    expect(_recibeToques(tester, find.text(_mensaje)), isTrue);
    await tester.pumpAndSettle();
  });
}
