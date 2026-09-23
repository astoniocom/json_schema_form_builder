// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'json_form_localizations_gen.dart';

// ignore_for_file: type=lint

/// The translations for Polish (`pl`).
class JsonFormLocalizationsPl extends JsonFormLocalizations {
  JsonFormLocalizationsPl([String locale = 'pl']) : super(locale);

  @override
  String get resetValueTooltip => 'Zresetuj wartość';

  @override
  String get setNullTooltip => 'Ustaw null';

  @override
  String get valueNotSetLabel => 'Nie ustawiono';

  @override
  String get valueAbsentLabel => 'brak wartości';

  @override
  String get enumNullOptionLabel => 'Brak wartości';

  @override
  String get enumNotSelectedLabel => 'Nie wybrano';

  @override
  String get selectOptionLabel => 'Wybierz opcję';

  @override
  String variantLabel(int number) {
    return 'Opcja $number';
  }

  @override
  String get childrenHaveErrorsLabel => 'Zawiera błędy w polach podrzędnych';

  @override
  String get listFallbackTitle => 'Lista';

  @override
  String get objectFallbackTitle => 'Obiekt';

  @override
  String itemsSummary(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count elementu',
      many: '$count elementów',
      few: '$count elementy',
      one: '1 element',
    );
    return '$_temp0';
  }

  @override
  String get valueFallbackLabel => 'Wartość';

  @override
  String editDialogTitle(String fieldTitle) {
    return 'Edycja $fieldTitle';
  }

  @override
  String get addItemDialogTitle => 'Dodaj element';

  @override
  String get addEntryDialogTitle => 'Dodaj właściwość';

  @override
  String get editEntryDialogTitle => 'Edytuj właściwość';

  @override
  String get keyFieldLabel => 'Klucz';

  @override
  String get valueTypeLabel => 'Typ wartości';

  @override
  String get keyEmptyError => 'Klucz nie może być pusty';

  @override
  String get keyExistsError => 'Klucz już istnieje';

  @override
  String additionalPropertiesForbiddenError(String key) {
    return 'Właściwość \"$key\" nie jest zdefiniowana w schemacie, a dodatkowe właściwości są zabronione';
  }

  @override
  String get invalidJsonError => 'Nieprawidłowy format JSON';

  @override
  String get notAllowedByEnumError => 'Wartość niedozwolona przez enum';

  @override
  String get noFileSelectedHint => 'Nie wybrano pliku';

  @override
  String get typeNameString => 'String';

  @override
  String get typeNameInt => 'Int';

  @override
  String get typeNameDouble => 'Double';

  @override
  String get typeNameBool => 'Bool';

  @override
  String get typeNameArray => 'Array';

  @override
  String get typeNameObject => 'Object';

  @override
  String get typeNameNull => 'Null';

  @override
  String get typeNameEnum => 'Enum';

  @override
  String get typeNameRaw => 'Raw';

  @override
  String get typeNameUnknown => 'Unknown';

  @override
  String get expandCycleButtonLabel => 'Rozwiń cykl';

  @override
  String get cycleFieldHelperText => 'Odwołanie rekurencyjne';
}
