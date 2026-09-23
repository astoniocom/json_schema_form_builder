// Verifies the instant (live) and on-demand (manual) validation modes of the
// example app: mode switching, error application and the Validate button.
import 'package:demo/main.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Finder _jsonEditor() => find.byWidgetPredicate((w) => w is TextField && w.expands);

Iterable<String?> _fieldErrors(WidgetTester tester) =>
    tester.widgetList<TextField>(find.byType(TextField)).where((w) => !w.expands).map((w) => w.decoration?.errorText).where((e) => e != null);

void main() {
  testWidgets('instant and on-demand validation', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
    // The default test device pixel ratio (3.0) shrinks the logical size
    // below the sidebar breakpoint; this test drives the wide desktop layout.
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.binding.setSurfaceSize(const Size(1200, 900));

    await tester.pumpWidget(const DemoApp());
    await tester.pumpAndSettle();

    // The startup sample is arbitrary; this test needs the Numbers sample
    // (its schema has an `integer` property to violate), so pick it
    // explicitly from the sample catalog (a permanent sidebar at this width).
    await tester.tap(find.text('Numbers'));
    await tester.pumpAndSettle();

    // Open the JSON editor tab (wide layout: Schema/JSON tabs on the right).
    await tester.tap(find.text('JSON'));
    await tester.pumpAndSettle();

    // 1. Instant mode: an invalid value must show errors right away.
    await tester.enterText(_jsonEditor(), '{"integer": "oops"}');
    await tester.pumpAndSettle();
    expect(_fieldErrors(tester), isNotEmpty, reason: 'instant mode must validate on edit');

    // 2. Switch to manual (uncheck Live validation; tapping the label must
    // work too): editing must not validate (errors are dropped).
    await tester.tap(find.text('Live validation'));
    await tester.pumpAndSettle();
    await tester.enterText(_jsonEditor(), '{"integer": "still bad"}');
    await tester.pumpAndSettle();
    expect(_fieldErrors(tester), isEmpty, reason: 'manual mode must not validate on edit');

    // 3. The Validate button applies errors and reports the outcome.
    await tester.tap(find.text('Validate'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Validation found'), findsOneWidget);
    expect(_fieldErrors(tester), isNotEmpty, reason: 'Validate must apply errors');

    // 4. Valid value: Validate reports success and clears errors.
    await tester.enterText(_jsonEditor(), '{"integer": 5}');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Validate'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Validation passed'), findsOneWidget);
    expect(_fieldErrors(tester), isEmpty);

    // 5. Switching back to live re-validates immediately.
    await tester.enterText(_jsonEditor(), '{"integer": "oops"}');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Live validation'));
    await tester.pumpAndSettle();
    expect(_fieldErrors(tester), isNotEmpty, reason: 'switching to live must re-validate');

    debugDefaultTargetPlatformOverride = null;
  });
}
