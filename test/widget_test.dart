import 'package:flutter_test/flutter_test.dart';
import 'package:pagate_ia/main.dart';

void main() {
  testWidgets('App renders login screen', (WidgetTester tester) async {
    await tester.pumpWidget(const PagateIAApp());
    await tester.pumpAndSettle();

    // Verify that the app title is present
    expect(find.text('Págate-IA'), findsOneWidget);
  });
}
