import 'dart:async';

import 'package:cupertino_ui/cupertino_ui.dart' show GlobalCupertinoLocalizations;
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart' show GlobalWidgetsLocalizations;
import 'package:intl/intl.dart' as intl;
import 'package:material_ui/material_ui.dart' show GlobalMaterialLocalizations;

import 'json_form_localizations_gen_en.dart';
import 'json_form_localizations_gen_pl.dart';
import 'json_form_localizations_gen_ru.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of JsonFormLocalizations
/// returned by `JsonFormLocalizations.of(context)`.
///
/// Applications need to include `JsonFormLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'generated/json_form_localizations_gen.dart';
///
/// return MaterialApp(
///   localizationsDelegates: JsonFormLocalizations.localizationsDelegates,
///   supportedLocales: JsonFormLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the JsonFormLocalizations.supportedLocales
/// property.
abstract class JsonFormLocalizations {
  JsonFormLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static JsonFormLocalizations of(BuildContext context) {
    return Localizations.of<JsonFormLocalizations>(
      context,
      JsonFormLocalizations,
    )!;
  }

  static const LocalizationsDelegate<JsonFormLocalizations> delegate =
      _JsonFormLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('pl'),
    Locale('ru'),
  ];

  /// Tooltip of the null-field button clearing an explicit null (the key is removed from the document).
  ///
  /// In en, this message translates to:
  /// **'Reset value'**
  String get resetValueTooltip;

  /// Tooltip of the null-field button writing an explicit JSON null.
  ///
  /// In en, this message translates to:
  /// **'Set to null'**
  String get setNullTooltip;

  /// Shown by the null field when the key is absent from the document.
  ///
  /// In en, this message translates to:
  /// **'Not set'**
  String get valueNotSetLabel;

  /// Shown by the unknown-type field for an absent value.
  ///
  /// In en, this message translates to:
  /// **'no value'**
  String get valueAbsentLabel;

  /// Label of an enum option whose value is JSON null.
  ///
  /// In en, this message translates to:
  /// **'No value'**
  String get enumNullOptionLabel;

  /// Shown by the enum field when the key is absent from the document.
  ///
  /// In en, this message translates to:
  /// **'Not selected'**
  String get enumNotSelectedLabel;

  /// Fallback field label of an enum without a title, and the hint of the variant (anyOf/oneOf) switcher when nothing is selected.
  ///
  /// In en, this message translates to:
  /// **'Select an option'**
  String get selectOptionLabel;

  /// Label of an untitled variant (anyOf/oneOf) alternative; the number is 1-based.
  ///
  /// In en, this message translates to:
  /// **'Option {number}'**
  String variantLabel(int number);

  /// Shown on a collapsed container whose children failed validation (the child errors themselves are visible only inside the editor).
  ///
  /// In en, this message translates to:
  /// **'Contains errors in child fields'**
  String get childrenHaveErrorsLabel;

  /// Fallback title of an untitled array field.
  ///
  /// In en, this message translates to:
  /// **'List'**
  String get listFallbackTitle;

  /// Fallback title of an untitled object field.
  ///
  /// In en, this message translates to:
  /// **'Object'**
  String get objectFallbackTitle;

  /// Collapsed-array summary prefix, e.g. '3 items'.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 item} other{{count} items}}'**
  String itemsSummary(num count);

  /// Fallback label of an untitled raw JSON field.
  ///
  /// In en, this message translates to:
  /// **'Value'**
  String get valueFallbackLabel;

  /// Title of the field editor dialog; fieldTitle is the field's title.
  ///
  /// In en, this message translates to:
  /// **'Edit {fieldTitle}'**
  String editDialogTitle(String fieldTitle);

  /// Title of the dialog entering a new array item.
  ///
  /// In en, this message translates to:
  /// **'Add item'**
  String get addItemDialogTitle;

  /// Title of the dialog adding an object property.
  ///
  /// In en, this message translates to:
  /// **'Add entry'**
  String get addEntryDialogTitle;

  /// Title of the dialog editing an existing object property.
  ///
  /// In en, this message translates to:
  /// **'Edit entry'**
  String get editEntryDialogTitle;

  /// Label of the property-name input in the entry dialog.
  ///
  /// In en, this message translates to:
  /// **'Key'**
  String get keyFieldLabel;

  /// Label of the type selector in the entry dialog.
  ///
  /// In en, this message translates to:
  /// **'Value type'**
  String get valueTypeLabel;

  /// Entry dialog: the property name is empty.
  ///
  /// In en, this message translates to:
  /// **'Key cannot be empty'**
  String get keyEmptyError;

  /// Entry dialog: the property name is already present in the object.
  ///
  /// In en, this message translates to:
  /// **'Key already exists'**
  String get keyExistsError;

  /// Entry dialog: the property name is not declared and additionalProperties is false.
  ///
  /// In en, this message translates to:
  /// **'Property \"{key}\" is not defined in schema and additional properties are forbidden'**
  String additionalPropertiesForbiddenError(String key);

  /// Raw JSON field: the entered text is not valid JSON.
  ///
  /// In en, this message translates to:
  /// **'Invalid JSON format'**
  String get invalidJsonError;

  /// Enum array: the item value is not one of the allowed enum values.
  ///
  /// In en, this message translates to:
  /// **'Not allowed by the enum'**
  String get notAllowedByEnumError;

  /// Hint of the data-url file field when no file is selected.
  ///
  /// In en, this message translates to:
  /// **'No file selected'**
  String get noFileSelectedHint;

  /// Display name of the string type in the 'Value type' selector and array add-item options.
  ///
  /// In en, this message translates to:
  /// **'String'**
  String get typeNameString;

  /// Display name of the integer type.
  ///
  /// In en, this message translates to:
  /// **'Int'**
  String get typeNameInt;

  /// Display name of the floating-point number type.
  ///
  /// In en, this message translates to:
  /// **'Double'**
  String get typeNameDouble;

  /// Display name of the boolean type.
  ///
  /// In en, this message translates to:
  /// **'Bool'**
  String get typeNameBool;

  /// Display name of the array type.
  ///
  /// In en, this message translates to:
  /// **'Array'**
  String get typeNameArray;

  /// Display name of the object type.
  ///
  /// In en, this message translates to:
  /// **'Object'**
  String get typeNameObject;

  /// Display name of the null type.
  ///
  /// In en, this message translates to:
  /// **'Null'**
  String get typeNameNull;

  /// Display name of the enum pseudo-type.
  ///
  /// In en, this message translates to:
  /// **'Enum'**
  String get typeNameEnum;

  /// Display name of the raw-JSON pseudo-type.
  ///
  /// In en, this message translates to:
  /// **'Raw'**
  String get typeNameRaw;

  /// Display name of an unknown type.
  ///
  /// In en, this message translates to:
  /// **'Unknown'**
  String get typeNameUnknown;

  /// Button on a field collapsed by the cycle guard (its $ref repeats an ancestor's schema); pressing it reveals one more level of the recursive structure.
  ///
  /// In en, this message translates to:
  /// **'Expand cycle'**
  String get expandCycleButtonLabel;

  /// Helper text of a field collapsed by the cycle guard, explaining why it is not expanded.
  ///
  /// In en, this message translates to:
  /// **'Recursive reference'**
  String get cycleFieldHelperText;
}

class _JsonFormLocalizationsDelegate
    extends LocalizationsDelegate<JsonFormLocalizations> {
  const _JsonFormLocalizationsDelegate();

  @override
  Future<JsonFormLocalizations> load(Locale locale) {
    return SynchronousFuture<JsonFormLocalizations>(
      lookupJsonFormLocalizations(locale),
    );
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'pl', 'ru'].contains(locale.languageCode);

  @override
  bool shouldReload(_JsonFormLocalizationsDelegate old) => false;
}

JsonFormLocalizations lookupJsonFormLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return JsonFormLocalizationsEn();
    case 'pl':
      return JsonFormLocalizationsPl();
    case 'ru':
      return JsonFormLocalizationsRu();
  }

  throw FlutterError(
    'JsonFormLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
