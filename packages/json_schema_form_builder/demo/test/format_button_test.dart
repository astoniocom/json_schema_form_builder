// The Format button of the Schema/JSON editor tabs: pretty-prints the
// current (parsed) text and stays disabled while the draft does not parse
// (formatting renders the last parsed value, so it would destroy a broken
// draft).
import 'package:demo/main.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

Finder _jsonEditor() => find.byWidgetPredicate((w) => w is TextField && w.expands);

Finder _formatButton() => find.byTooltip('Format').hitTestable();

String _editorText(WidgetTester tester) => tester.widget<TextField>(_jsonEditor()).controller!.text;

void main() {
  testWidgets('Format pretty-prints valid text and is disabled on a broken draft', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
    // The default test device pixel ratio (3.0) shrinks the logical size
    // below the sidebar breakpoint; this test drives the wide desktop layout.
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.binding.setSurfaceSize(const Size(1200, 900));

    await tester.pumpWidget(const DemoApp());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Numbers'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('JSON'));
    await tester.pumpAndSettle();

    // Compact but valid input: the editor keeps the text as typed.
    await tester.enterText(_jsonEditor(), '{"integer":5}');
    await tester.pumpAndSettle();
    expect(_editorText(tester), '{"integer":5}');

    await tester.tap(_formatButton());
    await tester.pumpAndSettle();
    expect(_editorText(tester), '{\n "integer": 5\n}');

    // A broken draft: the button must be disabled (formatting would replace
    // the draft with the last parsed value).
    await tester.enterText(_jsonEditor(), '{"integer": ');
    await tester.pumpAndSettle();
    final button = tester.widget<IconButton>(
      find.ancestor(of: find.byIcon(Icons.format_align_left).hitTestable(), matching: find.byType(IconButton)),
    );
    expect(button.onPressed, isNull);
    // The draft the user is typing stays untouched.
    expect(_editorText(tester), '{"integer": ');

    debugDefaultTargetPlatformOverride = null;
  });
}
