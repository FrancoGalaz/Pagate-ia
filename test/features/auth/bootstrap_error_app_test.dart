// Renderiza BootstrapErrorApp sin Firebase: solo tema, tokens y un callback.

import 'package:flutter_test/flutter_test.dart';
import 'package:pagate_ia/features/auth/presentation/widgets/bootstrap_error_app.dart';

void main() {
  testWidgets('BootstrapErrorApp muestra el mensaje y el detalle del error', (
    final tester,
  ) async {
    await tester.pumpWidget(
      BootstrapErrorApp(
        error: StateError('sin red'),
        onRetry: () {},
      ),
    );
    await tester.pump();

    expect(find.text('No pudimos iniciar la app'), findsOneWidget);
    expect(find.textContaining('sin red'), findsOneWidget);
    expect(find.text('Reintentar'), findsOneWidget);
  });

  testWidgets('BootstrapErrorApp invoca onRetry al tocar Reintentar', (
    final tester,
  ) async {
    var retries = 0;
    await tester.pumpWidget(
      BootstrapErrorApp(
        error: Exception('boom'),
        onRetry: () => retries++,
      ),
    );
    await tester.pump();

    await tester.tap(find.text('Reintentar'));
    await tester.pump();

    expect(retries, 1);
  });
}
