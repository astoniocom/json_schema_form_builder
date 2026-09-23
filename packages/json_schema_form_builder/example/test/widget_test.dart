import 'package:example/main.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('renders the form generated from the schema', (tester) async {
    await tester.pumpWidget(const ExampleApp());
    // The state building is async: wait for the rebuild to land.
    await tester.pumpAndSettle();

    // Fields declared in the schema are on screen.
    expect(find.text('Name'), findsWidgets);
    expect(find.text('Age'), findsWidgets);
    expect(find.text('Subscribe to newsletter'), findsWidgets);
  });
}
