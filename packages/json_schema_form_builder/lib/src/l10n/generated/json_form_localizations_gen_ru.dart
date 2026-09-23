// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'json_form_localizations_gen.dart';

// ignore_for_file: type=lint

/// The translations for Russian (`ru`).
class JsonFormLocalizationsRu extends JsonFormLocalizations {
  JsonFormLocalizationsRu([String locale = 'ru']) : super(locale);

  @override
  String get resetValueTooltip => 'Сбросить значение';

  @override
  String get setNullTooltip => 'Установить null';

  @override
  String get valueNotSetLabel => 'Не задано';

  @override
  String get valueAbsentLabel => 'значение отсутствует';

  @override
  String get enumNullOptionLabel => 'Значение не задано';

  @override
  String get enumNotSelectedLabel => 'Не выбрано';

  @override
  String get selectOptionLabel => 'Выберите опцию';

  @override
  String variantLabel(int number) {
    return 'Вариант $number';
  }

  @override
  String get childrenHaveErrorsLabel => 'Содержит ошибки в дочерних полях';

  @override
  String get listFallbackTitle => 'Список';

  @override
  String get objectFallbackTitle => 'Объект';

  @override
  String itemsSummary(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count элемента',
      many: '$count элементов',
      few: '$count элемента',
      one: '$count элемент',
    );
    return '$_temp0';
  }

  @override
  String get valueFallbackLabel => 'Значение';

  @override
  String editDialogTitle(String fieldTitle) {
    return 'Редактирование $fieldTitle';
  }

  @override
  String get addItemDialogTitle => 'Добавить элемент';

  @override
  String get addEntryDialogTitle => 'Добавить свойство';

  @override
  String get editEntryDialogTitle => 'Изменить свойство';

  @override
  String get keyFieldLabel => 'Ключ';

  @override
  String get valueTypeLabel => 'Тип значения';

  @override
  String get keyEmptyError => 'Ключ не может быть пустым';

  @override
  String get keyExistsError => 'Ключ уже существует';

  @override
  String additionalPropertiesForbiddenError(String key) {
    return 'Свойство \"$key\" не описано в схеме, а дополнительные свойства запрещены';
  }

  @override
  String get invalidJsonError => 'Неверный формат JSON';

  @override
  String get notAllowedByEnumError => 'Не входит в допустимые значения enum';

  @override
  String get noFileSelectedHint => 'Файл не выбран';

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
  String get expandCycleButtonLabel => 'Развернуть цикл';

  @override
  String get cycleFieldHelperText => 'Рекурсивная ссылка';
}
