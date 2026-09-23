import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import 'generated/json_form_localizations_gen.dart';
import 'generated/json_form_localizations_gen_en.dart';

export 'generated/json_form_localizations_gen.dart';
export 'generated/json_form_localizations_gen_en.dart';
export 'generated/json_form_localizations_gen_pl.dart';
export 'generated/json_form_localizations_gen_ru.dart';

/// The UI strings of json_schema_form_builder widgets.
///
/// The strings live in ARB files (`lib/src/l10n/arb/`); [JsonFormLocalizations]
/// and its bundled translations (English, Russian) are generated from them by
/// `flutter gen-l10n` (see `l10n.yaml`). To use a bundled translation,
/// register the generated delegate:
///
/// ```dart
/// MaterialApp(
///   localizationsDelegates: JsonFormLocalizations.localizationsDelegates,
///   supportedLocales: JsonFormLocalizations.supportedLocales,
/// )
/// ```
///
/// For a language the library does not bundle, either translate a copy of
/// `intl_en.arb` and contribute it, or extend [JsonFormLocalizationsEn]
/// (untranslated strings stay English) and register the subclass BEFORE the
/// bundled delegate — for a given type, the first delegate in the list wins:
///
/// ```dart
/// class DeJsonFormLocalizations extends JsonFormLocalizationsEn {
///   DeJsonFormLocalizations() : super('de');
///   @override
///   String get valueNotSetLabel => 'Nicht gesetzt';
/// }
///
/// MaterialApp(
///   localizationsDelegates: [
///     JsonFormLocalizationsDelegate(
///       (locale) => locale.languageCode == 'de' ? DeJsonFormLocalizations() : lookupJsonFormLocalizations(locale),
///     ),
///     ...JsonFormLocalizations.localizationsDelegates,
///   ],
/// )
/// ```
///
/// Widgets of this package resolve their strings via [jsonFormLocalizationsOf],
/// which falls back to English when no delegate is registered, so a plain
/// `MaterialApp` works without any setup.
JsonFormLocalizations jsonFormLocalizationsOf(BuildContext context) => Localizations.of<JsonFormLocalizations>(context, JsonFormLocalizations) ?? _englishFallback;

final JsonFormLocalizations _englishFallback = JsonFormLocalizationsEn();

/// Registers a [JsonFormLocalizations] (sub)class per locale: the way a host
/// plugs in its own language (see [jsonFormLocalizationsOf] for an example).
class JsonFormLocalizationsDelegate extends LocalizationsDelegate<JsonFormLocalizations> {
  /// Creates a delegate resolving localizations via [resolve].
  const JsonFormLocalizationsDelegate(this.resolve);

  /// Returns the localizations for the given locale. Called for every locale
  /// the app resolves to; return `lookupJsonFormLocalizations(locale)` (or a
  /// bundled class) for the ones this delegate does not customize.
  final JsonFormLocalizations Function(Locale locale) resolve;

  @override
  bool isSupported(Locale locale) => true;

  @override
  Future<JsonFormLocalizations> load(Locale locale) => SynchronousFuture(resolve(locale));

  @override
  bool shouldReload(JsonFormLocalizationsDelegate old) => false;
}
