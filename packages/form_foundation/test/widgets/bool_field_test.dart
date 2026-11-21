import 'package:flutter_test/flutter_test.dart';
import 'package:form_foundation/form_foundation.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  Widget buildSubject({
    bool? value,
    String? title,
    void Function(bool? value)? onChanged,
    String? error,
    String? helpText,
    bool required = false,
    bool tristate = false,
    String? displayValue,
  }) {
    return MaterialApp(
      home: Scaffold(
        body: BoolField(
          value: value,
          title: title,
          onChanged: onChanged,
          error: error,
          helpText: helpText,
          required: required,
          tristate: tristate,
          displayValue: displayValue,
        ),
      ),
    );
  }

  group('BoolField Tests', () {
    testWidgets('1. Displays the value and Checkbox state', (tester) async {
      await tester.pumpWidget(
        buildSubject(
          value: true,
          title: 'Consent',
          displayValue: 'Yes',
          onChanged: (_) {},
        ),
      );

      // Check that the title and the custom value text are displayed
      expect(find.text('Consent'), findsOneWidget);
      expect(find.text('Yes'), findsOneWidget);

      // Check the checkbox state: two states by default
      final checkboxWidget = tester.widget<Checkbox>(find.byType(Checkbox));
      expect(checkboxWidget.value, isTrue);
      expect(checkboxWidget.tristate, isFalse);
    });

    group('2. State cycling logic (_nextValue)', () {
      testWidgets('By default (two states): false -> true -> false, null -> false', (tester) async {
        bool? updatedValue;

        // --- Step 1: false -> true ---
        await tester.pumpWidget(
          buildSubject(
            value: false,
            onChanged: (val) => updatedValue = val,
          ),
        );
        await tester.tap(find.byType(Checkbox));
        expect(updatedValue, isTrue);

        // --- Step 2: true -> false (null is skipped) ---
        await tester.pumpWidget(
          buildSubject(
            value: true,
            onChanged: (val) => updatedValue = val,
          ),
        );
        await tester.tap(find.byType(Checkbox));
        expect(updatedValue, isFalse);

        // --- Step 3: null (value not set yet) -> false ---
        await tester.pumpWidget(
          buildSubject(
            onChanged: (val) => updatedValue = val,
          ),
        );
        await tester.tap(find.byType(Checkbox));
        expect(updatedValue, isFalse);
      });

      testWidgets('With tristate = true: true -> null', (tester) async {
        bool? updatedValue = true;

        await tester.pumpWidget(
          buildSubject(
            value: true,
            tristate: true,
            onChanged: (val) => updatedValue = val,
          ),
        );

        await tester.tap(find.byType(Checkbox));
        expect(updatedValue, isNull);

        final checkboxWidget = tester.widget<Checkbox>(find.byType(Checkbox));
        expect(checkboxWidget.tristate, isTrue);
      });
    });

    testWidgets('3. Disabled when onChanged == null', (tester) async {
      await tester.pumpWidget(
        buildSubject(
          value: true,
        ),
      );

      final checkbox = tester.widget<Checkbox>(find.byType(Checkbox));
      expect(checkbox.onChanged, isNull);
    });

    testWidgets('4. Displays errors (errorText) and hint (helperText)', (tester) async {
      await tester.pumpWidget(
        buildSubject(
          value: false,
          title: 'Confirmation',
          error: 'Field is required',
          helpText: 'Provide a value',
          onChanged: (_) {},
        ),
      );

      // Wait for the animation/decoration to render
      await tester.pumpAndSettle();

      // Get the InputDecorator and check the decoration properties directly
      final inputDecorator = tester.widget<InputDecorator>(find.byType(InputDecorator));

      expect(inputDecorator.decoration.errorText, equals('Field is required'));
      expect(inputDecorator.decoration.helperText, equals('Provide a value'));
    });

    testWidgets('5. Does not display empty error strings (error == "")', (tester) async {
      await tester.pumpWidget(
        buildSubject(
          value: false,
          error: '',
          onChanged: (_) {},
        ),
      );

      final inputDecorator = tester.widget<InputDecorator>(find.byType(InputDecorator));
      expect(inputDecorator.decoration.errorText, isNull);
    });

    testWidgets('6. Correctly hides/shows the child text via isEmpty', (tester) async {
      // When displayValue is empty or null -> isEmpty = true and SizedBox.shrink() is rendered
      await tester.pumpWidget(
        buildSubject(
          value: true,
          onChanged: (_) {},
        ),
      );

      final emptyDecorator = tester.widget<InputDecorator>(find.byType(InputDecorator));
      expect(emptyDecorator.isEmpty, isTrue);
      expect(find.byType(SizedBox), findsWidgets);

      // When displayValue is filled in -> isEmpty = false
      await tester.pumpWidget(
        buildSubject(
          value: true,
          displayValue: 'Selected',
          onChanged: (_) {},
        ),
      );

      final filledDecorator = tester.widget<InputDecorator>(find.byType(InputDecorator));
      expect(filledDecorator.isEmpty, isFalse);
      expect(find.text('Selected'), findsOneWidget);
    });

    group('BoolField — tristate', () {
      testWidgets(
        'tristate=false, value=null does not cause an AssertionError in Checkbox',
        (tester) async {
          final result = await tester.pumpWidget(
            buildSubject(
              onChanged: (_) {},
            ),
          );

          // The two-state mode must survive value == null (value not set
          // yet): Checkbox throws
          // AssertionError('tristate || value != null') right during build
          // if tristate is not forced. Asserts are compiled only in
          // debug/profile, but `flutter test` does not disable them by
          // default, so the test catches the exception here.
          expect(tester.takeException(), isNull);
          return result;
        },
      );

      testWidgets(
        'Checkbox.tristate is always true when value == null, regardless of the tristate parameter',
        (tester) async {
          Future<void> pumpWith({required bool tristate, required bool? value}) {
            return tester.pumpWidget(
              buildSubject(
                tristate: tristate,
                value: value,
                onChanged: (_) {},
              ),
            );
          }

          await pumpWith(tristate: false, value: null);
          expect(tester.takeException(), isNull);
          expect(
            tester.widget<Checkbox>(find.byType(Checkbox)).tristate,
            isTrue,
            reason: 'value == null must yield tristate: true, otherwise the Checkbox constructor throws an assert',
          );

          await pumpWith(tristate: true, value: null);
          expect(tester.takeException(), isNull);
          expect(tester.widget<Checkbox>(find.byType(Checkbox)).tristate, isTrue);
        },
      );

      testWidgets(
        'required=true with a non-null value renders normally (no exception)',
        (tester) async {
          for (final value in [true, false]) {
            await tester.pumpWidget(
              buildSubject(
                required: true,
                value: value,
                onChanged: (_) {},
              ),
            );

            expect(tester.takeException(), isNull);
            expect(tester.widget<Checkbox>(find.byType(Checkbox)).value, value);
          }
        },
      );
    });
  });
}
