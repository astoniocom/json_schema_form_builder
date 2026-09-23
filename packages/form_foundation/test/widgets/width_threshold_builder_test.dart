import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:form_foundation/form_foundation.dart';

void main() {
  Widget harness({required double width}) {
    return MaterialApp(
      home: Scaffold(
        body: Center(
          child: SizedBox(
            width: width,
            child: WidthThresholdBuilder(
              minWidth: 300,
              wideBuilder: (_) => const Text('wide'),
              narrowBuilder: (_) => const Text('narrow'),
            ),
          ),
        ),
      ),
    );
  }

  group('WidthThresholdBuilder', () {
    testWidgets('the first frame renders neither variant (width not yet measured)', (tester) async {
      await tester.pumpWidget(harness(width: 500));

      // The width is reported in a post-frame callback; until the next
      // frame no variant may be chosen.
      expect(find.text('wide'), findsNothing);
      expect(find.text('narrow'), findsNothing);

      await tester.pump();
      expect(find.text('wide'), findsOneWidget);
    });

    testWidgets('width >= minWidth builds the wide variant, below it the narrow one', (tester) async {
      await tester.pumpWidget(harness(width: 500));
      await tester.pump();
      expect(find.text('wide'), findsOneWidget);
      expect(find.text('narrow'), findsNothing);

      await tester.pumpWidget(harness(width: 200));
      await tester.pump();
      expect(find.text('narrow'), findsOneWidget);
      expect(find.text('wide'), findsNothing);
    });

    testWidgets('the threshold itself is wide (>=, not >)', (tester) async {
      await tester.pumpWidget(harness(width: 300));
      await tester.pump();

      expect(find.text('wide'), findsOneWidget);
    });

    testWidgets('does not throw inside an IntrinsicHeight parent (the reason it exists)', (tester) async {
      // A LayoutBuilder here would throw "LayoutBuilder does not support
      // returning intrinsic dimensions".
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    child: WidthThresholdBuilder(
                      minWidth: 300,
                      wideBuilder: (_) => const Text('wide'),
                      narrowBuilder: (_) => const Text('narrow'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(tester.takeException(), isNull);
      expect(find.text('wide'), findsOneWidget);
    });
  });
}
