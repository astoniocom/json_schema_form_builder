import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:json_schema_form_builder/json_schema_form_builder.dart';
import 'package:json_schema_form_builder/src/handlers/null/null_field.dart';

/// A language the library does not bundle, the way a package consumer adds
/// one: extend the English translation, override what is needed.
class _DeJsonFormLocalizations extends JsonFormLocalizationsEn {
  _DeJsonFormLocalizations() : super('de');

  @override
  String get setNullTooltip => 'Auf null setzen';
}

void main() {
  NullFieldState nullState() => const NullFieldState(
    value: PresenceValue.absent(),
    variants: null,
    rootSchema: null,
  );

  Widget app({Locale? locale, List<LocalizationsDelegate<dynamic>>? delegates, List<Locale>? supportedLocales}) => MaterialApp(
    locale: locale,
    supportedLocales: supportedLocales ?? const [Locale('en')],
    localizationsDelegates: delegates,
    home: Scaffold(
      body: NullField(fieldState: nullState(), onChanged: (_) {}),
    ),
  );

  group('JsonFormLocalizations', () {
    testWidgets('without registration the widgets fall back to the English defaults', (tester) async {
      await tester.pumpWidget(app());

      expect(find.byTooltip('Set to null'), findsOneWidget);
    });

    testWidgets('the bundled Russian translation works via the generated delegate', (tester) async {
      await tester.pumpWidget(
        app(
          locale: const Locale('ru'),
          supportedLocales: JsonFormLocalizations.supportedLocales,
          delegates: JsonFormLocalizations.localizationsDelegates,
        ),
      );

      expect(find.byTooltip('Установить null'), findsOneWidget);
      expect(find.byTooltip('Set to null'), findsNothing);
    });

    testWidgets('the bundled Polish translation works via the generated delegate', (tester) async {
      await tester.pumpWidget(
        app(
          locale: const Locale('pl'),
          supportedLocales: JsonFormLocalizations.supportedLocales,
          delegates: JsonFormLocalizations.localizationsDelegates,
        ),
      );

      expect(find.byTooltip('Ustaw null'), findsOneWidget);
      expect(find.byTooltip('Set to null'), findsNothing);
    });

    testWidgets('a consumer language registered before the bundled delegate wins', (tester) async {
      await tester.pumpWidget(
        app(
          locale: const Locale('de'),
          supportedLocales: const [Locale('de'), ...JsonFormLocalizations.supportedLocales],
          delegates: [
            JsonFormLocalizationsDelegate((locale) => locale.languageCode == 'de' ? _DeJsonFormLocalizations() : lookupJsonFormLocalizations(locale)),
            ...JsonFormLocalizations.localizationsDelegates,
          ],
        ),
      );

      expect(find.byTooltip('Auf null setzen'), findsOneWidget);
      expect(find.byTooltip('Set to null'), findsNothing);
    });
  });
}
