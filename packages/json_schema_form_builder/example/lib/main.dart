// Minimal integration of json_schema_form_builder:
// one schema, a live-validated form generated from it, and a Submit button
// gated by the validation result.
import 'dart:convert';

import 'package:json_schema_form_builder/json_schema_form_builder.dart';
import 'package:material_ui/material_ui.dart';

/// The JSON Schema the form is generated from.
final Schema _personSchema = Schema.fromMap({
  'title': 'Person',
  'type': 'object',
  'required': ['name'],
  'properties': {
    'name': {'type': 'string', 'title': 'Name', 'minLength': 1},
    'age': {'type': 'integer', 'title': 'Age', 'minimum': 0},
    'email': {'type': 'string', 'title': 'E-mail', 'format': 'email'},
    'newsletter': {'type': 'boolean', 'title': 'Subscribe to newsletter', 'default': false},
    'tags': {
      'type': 'array',
      'title': 'Tags',
      'items': {'type': 'string'},
    },
  },
});

void main() {
  runApp(const ExampleApp());
}

class ExampleApp extends StatelessWidget {
  const ExampleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'json_schema_form_builder example',
      // The translations of the built-in form widgets (tooltips, dialog
      // buttons, fallback labels). Without this English is used.
      localizationsDelegates: JsonFormLocalizations.localizationsDelegates,
      supportedLocales: JsonFormLocalizations.supportedLocales,
      home: const FormPage(),
    );
  }
}

class FormPage extends StatefulWidget {
  const FormPage({super.key});

  @override
  State<FormPage> createState() => _FormPageState();
}

class _FormPageState extends State<FormPage> {
  /// The root form state as of the latest change: carries the edited value
  /// (`state.value`) and the validation verdict (`state.isValid`).
  JsonFieldState<Schema>? _formState;

  Future<void> _showResult(JsonFieldState<Schema> formState) {
    return showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Submitted value'),
        content: Text(
          const JsonEncoder.withIndent('  ').convert(formState.valueOrNull),
          style: Theme.of(context).textTheme.bodySmall?.copyWith(fontFamily: 'monospace'),
        ),
        actions: [TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Close'))],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final formState = _formState;

    return Scaffold(
      appBar: AppBar(title: const Text('Person form')),
      body: SingleChildScrollView(
        child: JsonSchemaForm(schema: _personSchema, onChanged: (state) => setState(() => _formState = state)),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: FilledButton(
            // isValid == validated clean; errors are already shown inline.
            onPressed: formState != null && formState.isValid ? () => _showResult(formState) : null,
            child: const Text('Submit'),
          ),
        ),
      ),
    );
  }
}
