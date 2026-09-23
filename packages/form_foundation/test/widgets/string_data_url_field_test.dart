import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:form_foundation/form_foundation.dart';

Widget buildSubject({
  String? value,
  void Function(String)? onChanged,
  DataUrlFilePicker? pickFile,
  String? title,
  bool required = false,
}) {
  return MaterialApp(
    home: Scaffold(
      body: StringDataUrlField(
        value: value,
        title: title,
        onChanged: onChanged,
        pickFile: pickFile,
        required: required,
      ),
    ),
  );
}

void main() {
  group('DataUrl codec', () {
    test('encode produces the rjsf flavor and tryParse round-trips it', () {
      final encoded = DataUrl.encode(
        bytes: utf8.encode('hello'),
        name: 'file with space.txt',
        mimeType: 'text/plain',
      );

      expect(encoded, startsWith('data:text/plain;name='));
      expect(encoded, endsWith(';base64,${base64Encode(utf8.encode('hello'))}'));

      final parsed = DataUrl.tryParse(encoded)!;
      expect(parsed.mimeType, 'text/plain');
      expect(parsed.name, 'file with space.txt');
      expect(parsed.byteLength, utf8.encode('hello').length);
    });

    test('a missing mime type falls back to application/octet-stream', () {
      final encoded = DataUrl.encode(bytes: const [1, 2, 3], name: 'a.bin');
      expect(encoded, startsWith('data:application/octet-stream;'));
    });

    test('tryParse rejects non data URLs', () {
      expect(DataUrl.tryParse('not a data url'), isNull);
      expect(DataUrl.tryParse('data:no-comma'), isNull);
    });

    test('tryParse handles a data URL without a name parameter', () {
      final parsed = DataUrl.tryParse('data:image/png;base64,AAAA')!;
      expect(parsed.mimeType, 'image/png');
      expect(parsed.name, isNull);
      expect(parsed.byteLength, 3);
    });
  });

  group('StringDataUrlField', () {
    testWidgets('1. Picking a file writes the encoded data URL', (tester) async {
      final written = <String>[];
      await tester.pumpWidget(buildSubject(
        onChanged: written.add,
        pickFile: () async => PickedFileData(
          name: 'photo.png',
          bytes: Uint8List.fromList(const [1, 2, 3, 4]),
          mimeType: 'image/png',
        ),
      ));

      await tester.tap(find.byIcon(Icons.attach_file));
      await tester.pump();

      expect(written.single, 'data:image/png;name=photo.png;base64,${base64Encode(const [1, 2, 3, 4])}');
      // The field now shows the file name and size instead of the raw URL.
      expect(find.text('photo.png (4 B)'), findsOneWidget);
    });

    testWidgets('2. A cancelled picker writes nothing', (tester) async {
      final written = <String>[];
      await tester.pumpWidget(buildSubject(
        onChanged: written.add,
        pickFile: () async => null,
      ));

      await tester.tap(find.byIcon(Icons.attach_file));
      await tester.pump();

      expect(written, isEmpty);
    });

    testWidgets('3. An existing value is displayed as name and size', (tester) async {
      final value = DataUrl.encode(bytes: List.filled(2048, 7), name: 'doc.pdf', mimeType: 'application/pdf');
      await tester.pumpWidget(buildSubject(value: value, onChanged: (_) {}));

      expect(find.text('doc.pdf (2.0 KB)'), findsOneWidget);
    });

    testWidgets('4. Clearing writes an empty string', (tester) async {
      final written = <String>[];
      final value = DataUrl.encode(bytes: const [1], name: 'a.txt');
      await tester.pumpWidget(buildSubject(value: value, onChanged: written.add));

      await tester.tap(find.byIcon(Icons.clear));
      await tester.pump();

      expect(written.single, '');
    });

    testWidgets('5. Without a picker the attach button is disabled', (tester) async {
      await tester.pumpWidget(buildSubject(onChanged: (_) {}));

      final button = tester.widget<IconButton>(
        find.widgetWithIcon(IconButton, Icons.attach_file),
      );
      expect(button.onPressed, isNull);
    });

    testWidgets('6. A malformed value stays visible truncated', (tester) async {
      final raw = 'x' * 100;
      await tester.pumpWidget(buildSubject(value: raw, onChanged: (_) {}));

      expect(find.text('${'x' * 40}…'), findsOneWidget);
    });
  });
}
