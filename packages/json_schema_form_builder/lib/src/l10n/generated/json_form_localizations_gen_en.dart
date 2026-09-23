// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'json_form_localizations_gen.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class JsonFormLocalizationsEn extends JsonFormLocalizations {
  JsonFormLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get resetValueTooltip => 'Reset value';

  @override
  String get setNullTooltip => 'Set to null';

  @override
  String get valueNotSetLabel => 'Not set';

  @override
  String get valueAbsentLabel => 'no value';

  @override
  String get enumNullOptionLabel => 'No value';

  @override
  String get enumNotSelectedLabel => 'Not selected';

  @override
  String get selectOptionLabel => 'Select an option';

  @override
  String variantLabel(int number) {
    return 'Option $number';
  }

  @override
  String get childrenHaveErrorsLabel => 'Contains errors in child fields';

  @override
  String get listFallbackTitle => 'List';

  @override
  String get objectFallbackTitle => 'Object';

  @override
  String itemsSummary(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count items',
      one: '1 item',
    );
    return '$_temp0';
  }

  @override
  String get valueFallbackLabel => 'Value';

  @override
  String editDialogTitle(String fieldTitle) {
    return 'Edit $fieldTitle';
  }

  @override
  String get addItemDialogTitle => 'Add item';

  @override
  String get addEntryDialogTitle => 'Add entry';

  @override
  String get editEntryDialogTitle => 'Edit entry';

  @override
  String get keyFieldLabel => 'Key';

  @override
  String get valueTypeLabel => 'Value type';

  @override
  String get keyEmptyError => 'Key cannot be empty';

  @override
  String get keyExistsError => 'Key already exists';

  @override
  String additionalPropertiesForbiddenError(String key) {
    return 'Property \"$key\" is not defined in schema and additional properties are forbidden';
  }

  @override
  String get invalidJsonError => 'Invalid JSON format';

  @override
  String get notAllowedByEnumError => 'Not allowed by the enum';

  @override
  String get noFileSelectedHint => 'No file selected';

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
  String get expandCycleButtonLabel => 'Expand cycle';

  @override
  String get cycleFieldHelperText => 'Recursive reference';
}
