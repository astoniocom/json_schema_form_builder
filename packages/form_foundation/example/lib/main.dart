// form_foundation carries no schema logic: the app owns the values, the
// validation, and the layout, and composes the form from the package's
// primitives — typed field widgets, a group frame, removable rows, an add
// button — all themed through FormTheme.
import 'package:flutter/material.dart';
import 'package:form_foundation/form_foundation.dart';

void main() {
  runApp(const ExampleApp());
}

class ExampleApp extends StatelessWidget {
  const ExampleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'form_foundation example',
      // FormTheme configures every form_foundation widget below it, the way
      // Material component themes do.
      home: const FormTheme(
        data: FormThemeData(
          fieldPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        ),
        child: ContactPage(),
      ),
    );
  }
}

class ContactPage extends StatefulWidget {
  const ContactPage({super.key});

  @override
  State<ContactPage> createState() => _ContactPageState();
}

class _ContactPageState extends State<ContactPage> {
  // The app owns the data: plain Dart values, no form state objects.
  String _name = '';
  int? _age;
  double? _height;
  bool? _newsletter = false;
  String _birthday = '';
  final List<String> _phones = [];

  // The app owns the validation too; the widgets only display the messages.
  String? get _nameError => _name.trim().isEmpty ? 'Name is required' : null;

  List<String> get _formErrors => [
    if (_nameError != null) 'Name is required',
    if (_age != null && _age! < 0) 'Age cannot be negative',
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Contact form')),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            StringField(
              title: 'Name',
              required: true,
              value: _name,
              error: _nameError,
              helpText: 'How should we address you?',
              onChanged: (value) => setState(() => _name = value),
            ),
            IntField(
              title: 'Age',
              value: _age,
              examples: const [18, 30, 65],
              onChanged: (value) => setState(() => _age = value),
            ),
            DoubleField(
              title: 'Height, m',
              value: _height,
              onChanged: (value) => setState(() => _height = value),
            ),
            StringDateField(
              title: 'Birthday',
              value: _birthday,
              onChanged: (value) => setState(() => _birthday = value),
            ),
            BoolField(
              title: 'Subscribe to newsletter',
              value: _newsletter,
              onChanged: (value) => setState(() => _newsletter = value),
            ),
            // A hand-rolled collection editor: EditorGroup draws the frame,
            // RemovableRow adds the per-row delete button, AddButton appends.
            // (For handler-driven collections see ListEditor/NodeEditor.)
            EditorGroup(
              title: 'Phones',
              content: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final (index, phone) in _phones.indexed)
                    RemovableRow(
                      field: StringField(
                        title: 'Phone ${index + 1}',
                        value: phone,
                        onChanged: (value) => setState(() => _phones[index] = value),
                      ),
                      onRemove: () => setState(() => _phones.removeAt(index)),
                    ),
                  Padding(
                    padding: FormTheme.fieldPaddingOf(context),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        AddButton<void>(
                          typesToAdd: [NewItemOption(title: 'Phone', data: null)],
                          onAdd: (_) => setState(() => _phones.add('')),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            ErrorsPanel(errors: _formErrors),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: FilledButton(
            onPressed: _formErrors.isEmpty ? () => _showResult(context) : null,
            child: const Text('Submit'),
          ),
        ),
      ),
    );
  }

  Future<void> _showResult(BuildContext context) {
    final value = {
      'name': _name,
      if (_age != null) 'age': _age,
      if (_height != null) 'height': _height,
      if (_birthday.isNotEmpty) 'birthday': _birthday,
      'newsletter': _newsletter,
      'phones': _phones,
    };
    return showDialog<void>(
      context: context,
      // FormDialog aligns the title and actions with the form fields.
      builder: (context) => FormDialog(
        title: const Text('Submitted value'),
        content: Padding(
          padding: FormTheme.fieldPaddingOf(context),
          child: Text('$value', style: FormTheme.codeTextStyleOf(context)),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Close')),
        ],
      ),
    );
  }
}
