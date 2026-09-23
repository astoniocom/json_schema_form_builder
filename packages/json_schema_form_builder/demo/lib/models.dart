import 'package:json_schema_form_builder/json_schema_form_builder.dart';

/// Sections of the sample catalog, in display order.
enum SampleCategory {
  basics('Basics'),
  arrays('Arrays'),
  objects('Objects'),
  references('References'),
  combinators('Combinators'),
  dependencies('Dependencies'),
  validation('Validation'),
  misc('Types & misc');

  const SampleCategory(this.label);

  final String label;
}

class Sample {
  const Sample({
    required this.title,
    required this.category,
    required this.jsonSchema,
    this.formData = const PresenceValue.absent(),
  });

  final String title;
  final SampleCategory category;
  final Map<String, dynamic>? jsonSchema;
  final PresenceValue<dynamic> formData;

  /// URL path segment identifying this sample, derived from the title
  /// (e.g. 'Schema dependencies' -> 'schema-dependencies'), so a link to a
  /// specific sample can be shared.
  String get slug => title.toLowerCase().replaceAll(RegExp('[^a-z0-9]+'), '-').replaceAll(RegExp(r'^-+|-+$'), '');
}
