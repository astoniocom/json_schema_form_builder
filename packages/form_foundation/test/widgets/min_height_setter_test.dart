import 'package:flutter_test/flutter_test.dart';
// Internal helper, deliberately not exported by the facade.
import 'package:form_foundation/src/widgets/min_height_setter.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  group('MinHeightSetter', () {
    testWidgets('is invisible and zero-width but as tall as a one-line TextField', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                MinHeightSetter(),
                SizedBox(width: 200, child: TextField()),
              ],
            ),
          ),
        ),
      );

      final setterSize = tester.getSize(find.byType(MinHeightSetter));
      final fieldHeight = tester.getSize(find.byType(TextField).last).height;

      expect(setterSize.width, 0);
      // Its whole purpose: hold the row at field height without visible UI.
      expect(setterSize.height, fieldHeight);

      final opacity = tester.widget<Opacity>(
        find.descendant(of: find.byType(MinHeightSetter), matching: find.byType(Opacity)),
      );
      expect(opacity.opacity, 0);
    });

    testWidgets('its inner TextField is disabled and takes no input', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: Row(children: [MinHeightSetter()]))),
      );

      final inner = tester.widget<TextField>(
        find.descendant(of: find.byType(MinHeightSetter), matching: find.byType(TextField)),
      );
      expect(inner.enabled, isFalse);
    });
  });
}
