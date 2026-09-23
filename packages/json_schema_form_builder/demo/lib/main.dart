import 'dart:async';

import 'package:control_style/control_style.dart';
import 'package:file_selector/file_selector.dart';
import 'package:flutter/foundation.dart' show defaultTargetPlatform;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show SystemNavigator;
import 'package:json_schema_form_builder/json_schema_form_builder.dart';
import 'package:url_launcher/url_launcher.dart';

import 'models.dart';
import 'sample_db.dart';

/// Where the demo sends visitors interested in the package.
final Uri _pubDevUrl = Uri.parse('https://pub.dev/packages/json_schema_form_builder');

/// Source repository, linked from the AppBar.
final Uri _repositoryUrl = Uri.parse('https://github.com/astoniocom/json_schema_form_builder');

/// One-line pitch shown in the AppBar (wide layouts) and the drawer header.
const _tagline = 'Flutter forms generated live from JSON Schema';

void main() {
  runApp(const DemoApp());
}

/// File picker for `format: "data-url"` fields. The library packages carry
/// no file-picking plugin; the host app wires one in (here: file_selector).
Future<PickedFileData?> _pickFileForDataUrl() async {
  final file = await openFile();
  if (file == null) return null;
  return PickedFileData(
    name: file.name,
    bytes: await file.readAsBytes(),
    mimeType: file.mimeType,
  );
}

class DemoApp extends StatefulWidget {
  const DemoApp({super.key});

  /// On web defaultTargetPlatform reports the host OS, so desktop browsers
  /// get the compact look too.
  static bool get _isDesktop => switch (defaultTargetPlatform) {
    TargetPlatform.macOS || TargetPlatform.windows || TargetPlatform.linux => true,
    _ => false,
  };

  static const contentPadding = EdgeInsets.symmetric(horizontal: 20, vertical: 10);

  /// Desktop gets a macOS-like look: small dense fields with a thin gray
  /// hairline border, 6px rounding, white fill on a light-gray window
  /// background, 13px text and the system-blue focus highlight. Mobile keeps
  /// the stock Material look with finger-sized touch targets.
  static ThemeData _buildTheme(Brightness brightness) {
    final dark = brightness == Brightness.dark;
    // The macOS system palette for the given brightness.
    final background = dark ? const Color(0xFF1E1E20) : const Color(0xFFF5F5F7);
    final hairline = dark ? const Color(0xFF48484A) : const Color(0xFFC6C6C8);
    final fill = dark ? const Color(0xFF2C2C2E) : Colors.white;
    final disabledHairline = dark ? const Color(0xFF3A3A3C) : const Color(0xFFE3E3E5);
    final accent = dark ? const Color(0xFF0A84FF) : const Color(0xFF007AFF);

    final enabledBorder = OutlineInputBorder(
      borderSide: BorderSide(color: hairline),
    );

    final fieldDecorationTheme = InputDecorationTheme(
      filled: true,
      fillColor: fill,
      hoverColor: Colors.transparent,
      border: enabledBorder,
      enabledBorder: enabledBorder,
      // A disabled field casts no shadow: it must read as flat/inactive.
      disabledBorder: OutlineInputBorder(
        borderSide: BorderSide(color: disabledHairline),
      ),
      focusedBorder: DecoratedInputBorder(
        shadow: [
          BoxShadow(color: accent.withValues(alpha: 0.35), blurRadius: 6, spreadRadius: 1),
        ],
        child: OutlineInputBorder(
          borderSide: BorderSide(color: accent),
        ),
      ),
    );

    if (!_isDesktop) {
      // Same accent as the desktop look; stock Material sizes for touch.
      return ThemeData(
        colorScheme: .fromSeed(seedColor: accent, brightness: brightness),
        inputDecorationTheme: fieldDecorationTheme,
        scaffoldBackgroundColor: background,
      );
    }

    final desktopFieldDecorationTheme = fieldDecorationTheme.copyWith(
      isDense: true,
      contentPadding: const EdgeInsets.only(left: 10, top: 8, bottom: 8),
      // Without these, any suffix icon (the dropdown arrow, date pickers)
      // gets the default 48x48 min constraints (40x40 at compact density) and
      // stretches the field taller than icon-less dense fields (~28px).
      suffixIconConstraints: const BoxConstraints(minWidth: 26, minHeight: 26),
      prefixIconConstraints: const BoxConstraints(minWidth: 26, minHeight: 26),
      labelStyle: const TextStyle(fontSize: 13),
    );

    final base = ThemeData(
      colorScheme: ColorScheme.fromSeed(seedColor: accent, brightness: brightness).copyWith(primary: accent),
      visualDensity: VisualDensity.compact,
    );

    return base.copyWith(
      scaffoldBackgroundColor: background,
      textTheme: base.textTheme.copyWith(
        // TextField input text defaults to bodyLarge; 13px matches AppKit.
        bodyLarge: base.textTheme.bodyLarge?.copyWith(fontSize: 13),
      ),
      // Without this, fields with a suffix IconButton (dates, examples
      // dropdowns) are taller than plain text fields: the button's default
      // min constraints (~40px even at compact density) exceed the dense
      // field height (~34px). Shrunk buttons stop dictating field height.
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          iconSize: 18,
          padding: const EdgeInsets.all(4),
          minimumSize: const Size.square(26),
          maximumSize: const Size.square(26),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
      ),
      // AppBar builds its drawer/back buttons with an explicit
      // IconButton.styleFrom(iconSize: iconTheme.size ?? 24), which overrides
      // the 18px from iconButtonTheme above. A 24px glyph inside the 26px
      // buttons (18px content area) overflows and looks shifted off-center,
      // so the AppBar icon size must be set to 18 explicitly.
      appBarTheme: const AppBarThemeData(iconTheme: IconThemeData(size: 18)),
      inputDecorationTheme: desktopFieldDecorationTheme,
      // DropdownMenu (enum fields) reads its field decoration from
      // DropdownMenuTheme, not from the global InputDecorationTheme, so the
      // same decoration must be installed here as well.
      dropdownMenuTheme: DropdownMenuThemeData(
        inputDecorationTheme: desktopFieldDecorationTheme,
        textStyle: const TextStyle(fontSize: 13),
      ),
    );
  }

  @override
  State<DemoApp> createState() => _DemoAppState();
}

class _DemoAppState extends State<DemoApp> {
  /// Follows the system until the AppBar toggle pins an explicit theme.
  ThemeMode _themeMode = ThemeMode.system;

  void _toggleTheme(Brightness current) {
    setState(() => _themeMode = current == Brightness.dark ? ThemeMode.light : ThemeMode.dark);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'JSON Schema Form Builder Demo',
      theme: DemoApp._buildTheme(Brightness.light),
      darkTheme: DemoApp._buildTheme(Brightness.dark),
      themeMode: _themeMode,
      // The bundled form translations (en, ru): picked by the system locale.
      localizationsDelegates: JsonFormLocalizations.localizationsDelegates,
      supportedLocales: JsonFormLocalizations.supportedLocales,
      builder: (context, child) => FormTheme(
        data: const FormThemeData(
          // A bundled monospace font for the JSON editors (tabs and dialogs):
          // the generic 'monospace' family does not resolve on macOS/web and
          // silently falls back to a proportional font.
          codeTextStyle: TextStyle(fontFamily: 'JetBrainsMono', fontSize: 13),
        ),
        child: child!,
      ),
      home: MyHomePage(title: 'JSON Schema Form Builder', onToggleTheme: _toggleTheme),
    );
  }
}

/// How the form is validated: on every change (as you type) or only when the
/// user presses the Validate button.
enum _ValidationMode { instant, onDemand }

class MyHomePage extends StatefulWidget {
  const MyHomePage({required this.title, required this.onToggleTheme, super.key});

  final String title;

  /// Pins the app theme to the opposite of the given current brightness.
  final void Function(Brightness current) onToggleTheme;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> with WidgetsBindingObserver {
  final JsonHandlerRegistry _jsonHandlerRegistry = standardJsonHandlerRegistry(
    arrayInline: true,
    filePicker: _pickFileForDataUrl,
    // Substituting the fallback for schema-less values:
    // unknownFieldHandler: (registry) => RawFieldHandler(registryGetter: registry),
  );

  Schema? _schema;

  /// The schema as the JSON map shown in the Schema editor tab (the source
  /// of [_schema]).
  Map<String, dynamic>? _schemaMap;
  JsonFieldState? _formState;
  Sample? _sample;
  final _scaffoldKey = GlobalKey<ScaffoldState>();

  /// Bumped on every sample load (switch or reset). Keys the editor tabs, so
  /// they are recreated from the new sample data even while holding an
  /// unparseable draft (which the RawField sync deliberately preserves).
  int _sampleGeneration = 0;

  /// Demo-side error of the Schema tab: the text parses but is not a JSON
  /// object. Parse errors are handled inside RawField itself.
  String? _schemaEditError;

  /// Per-tab format generation, bumped by the Format button: the editor is
  /// keyed by it, so the bump recreates the editor, which renders the current
  /// value pretty-printed (the editor never reformats live text on its own —
  /// that would fight the caret).
  final Map<String, int> _formatGeneration = {};

  /// Per-tab "the current text does not parse" flag (reported by the editor's
  /// onChanged): formatting renders the last PARSED value, so with a broken
  /// draft it would destroy the user's text — the button is disabled instead.
  final Map<String, bool> _editorParseError = {};

  _ValidationMode _validationMode = _ValidationMode.instant;

  /// Rebuilding _formState is asynchronous; fast typing in the editors can
  /// finish out of order, so only the latest rebuild is allowed to apply.
  late final LatestRequestGuard _rebuildGuard = LatestRequestGuard(isAlive: () => mounted);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    // A shared link like /#/schema-dependencies opens its sample directly.
    // On the web the slug is read from the URL fragment (more reliable than
    // defaultRouteName, which the engine may override from the saved history
    // state); elsewhere Uri.base has no fragment and the default route is
    // used.
    final fragment = Uri.base.fragment;
    final initialRoute = fragment.isNotEmpty ? fragment : WidgetsBinding.instance.platformDispatcher.defaultRouteName;
    unawaited(_setSample(_sampleByRoute(initialRoute) ?? samples.first));
  }

  static Sample? _sampleByRoute(String route) {
    final slug = Uri.parse(route).path.replaceAll(RegExp(r'^/+|/+$'), '');
    for (final sample in samples) {
      if (sample.slug == slug) return sample;
    }
    return null;
  }

  /// Browser back/forward between samples (web pushes the new route here).
  @override
  Future<bool> didPushRouteInformation(RouteInformation routeInformation) async {
    final sample = _sampleByRoute(routeInformation.uri.path);
    if (sample == null || sample == _sample) return false;
    await _setSample(sample, updateUrl: false);
    return true;
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  Future<void> _setSample(Sample sample, {bool updateUrl = true}) {
    _sample = sample;
    _sampleGeneration++;
    _schemaEditError = null;
    // The recreated editors start from the sample's parsed data.
    _editorParseError.clear();
    if (updateUrl) {
      // Reflects the sample in the browser URL (a no-op outside the web), so
      // a link to a specific sample can be shared.
      unawaited(SystemNavigator.routeInformationUpdated(uri: Uri(path: '/${sample.slug}')));
    }
    return _setSchema(
      jsonSchema: sample.jsonSchema,
      value: sample.formData,
    );
  }

  Future<void> _setSchema({
    required PresenceValue<dynamic> value,
    Map<String, dynamic>? jsonSchema,
  }) async {
    _schemaMap = jsonSchema;
    final schema = jsonSchema != null ? Schema.fromMap(jsonSchema) : null;

    await _rebuildState(schema: schema, value: value);
  }

  Future<void> _setNewValue(PresenceValue<dynamic> value) => _rebuildState(schema: _schema, value: value);

  /// Re-validates the current value and applies the errors to the form.
  /// Used by the Validate button in [_ValidationMode.onDemand].
  Future<void> _validateNow() => _rebuildState(
    schema: _schema,
    value: _formState?.value ?? const PresenceValue.absent(),
    validate: true,
    notifyResult: true,
  );

  void _setValidationMode(_ValidationMode mode) {
    if (mode == _validationMode) return;
    setState(() => _validationMode = mode);

    // Instant mode must immediately reflect the current value; switching to
    // on-demand keeps the already shown errors until the next edit.
    if (mode == _ValidationMode.instant) {
      unawaited(_setNewValue(_formState?.value ?? const PresenceValue.absent()));
    }
  }

  /// Rebuilds the form state for the given schema/value pair.
  ///
  /// [validate] overrides the current [_validationMode]: in on-demand mode
  /// regular rebuilds skip validation (previous errors are dropped on edit),
  /// while the Validate button forces it. When [notifyResult] is true, the
  /// validation outcome is reported with a SnackBar.
  Future<void> _rebuildState({
    required Schema? schema,
    required PresenceValue<dynamic> value,
    bool? validate,
    bool notifyResult = false,
  }) {
    final shouldValidate = validate ?? _validationMode == _ValidationMode.instant;

    return _rebuildGuard.run(
      () async {
        final errors = shouldValidate ? await validateDataBySchema(schema, value.valueOrNull) : null;

        final newState = await _jsonHandlerRegistry.withValidationContext(
          itemSchema: schema,
          rootSchema: null,
          body: (validationContext) => _jsonHandlerRegistry.buildState(
            FieldBuildRequest(
              value: value,
              schemaSource: SchemaWithContext.maybe(schema, validationContext),
              title: schema?.title,
              errors: errors,
              resolveContext: FieldResolveContext(path: [], rootSchema: schema),
            ),
          ),
        );

        return (schema: schema, state: newState?.applyErrors(errors ?? []), errors: errors);
      },
      (result) {
        setState(() {
          _schema = result.schema;
          _formState = result.state;
        });

        if (notifyResult) {
          final errorCount = result.errors?.length ?? 0;
          ScaffoldMessenger.of(context)
            ..hideCurrentSnackBar()
            ..showSnackBar(
              SnackBar(
                content: Text(errorCount == 0 ? 'Validation passed: no errors' : 'Validation found $errorCount error(s)'),
              ),
            );
        }
      },
    );
  }

  /// Schema tab edits: parse errors are handled (and shown) by RawField
  /// itself; here only the demo-level rule "a schema is a JSON object" is
  /// enforced before the schema is applied.
  void _onSchemaEdited(PresenceValue<dynamic> value, String? parseError) {
    if (parseError != null) return;

    Map<String, dynamic>? schemaMap;
    if (value.present) {
      final decoded = value.valueOrNull;
      if (decoded is! Map<String, dynamic>) {
        setState(() => _schemaEditError = 'JSON Schema must be a JSON object');
        return;
      }
      schemaMap = decoded;
    }

    setState(() => _schemaEditError = null);
    unawaited(
      _setSchema(
        value: _formState?.value ?? const PresenceValue.absent(),
        jsonSchema: schemaMap,
      ),
    );
  }

  void _onJsonEdited(PresenceValue<dynamic> value, String? parseError) {
    if (parseError != null) return;
    unawaited(_setNewValue(value));
  }

  /// An editor tab is the library's own [JsonEditor] in the full-pane mode:
  /// the demo gets the JSON highlighting, pretty-printing and the careful
  /// external-value sync for free.
  Widget _buildEditorTab({
    required String title,
    required PresenceValue<dynamic> value,
    required void Function(PresenceValue<dynamic> value, String? parseError) onChanged,
    String? errorText,
  }) {
    final hasParseError = _editorParseError[title] ?? false;

    return Padding(
      padding: DemoApp.contentPadding,
      child: Stack(
        children: [
          Positioned.fill(
            child: JsonEditor(
              // Recreated per sample load (the sample data must replace the
              // text even when the tab holds an unparseable draft) and per
              // Format press (the recreated editor pretty-prints the value).
              key: ValueKey((title, _sampleGeneration, _formatGeneration[title] ?? 0)),
              expands: true,
              value: value,
              errorText: errorText,
              onChanged: (newValue, parseError) {
                final hasError = parseError != null;
                if ((_editorParseError[title] ?? false) != hasError) {
                  setState(() => _editorParseError[title] = hasError);
                }
                onChanged(newValue, parseError);
              },
            ),
          ),
          Positioned(
            top: 8,
            right: 16,
            child: IconButton(
              tooltip: 'Format',
              icon: const Icon(Icons.format_align_left),
              // Formatting renders the last PARSED value; with an unparseable
              // draft or no value there is nothing safe to format.
              onPressed: value.present && !hasParseError ? () => setState(() => _formatGeneration[title] = (_formatGeneration[title] ?? 0) + 1) : null,
            ),
          ),
        ],
      ),
    );
  }

  /// Editor tabs pane; on wide layouts the Form is shown beside it, on narrow
  /// layouts the Form becomes the first tab.
  Widget _buildTabsPane({required Widget? formTab}) {
    return DefaultTabController(
      length: formTab == null ? 2 : 3,
      child: Column(
        children: [
          TabBar(
            tabs: [
              if (formTab != null) const Tab(text: 'Form'),
              const Tab(text: 'Schema'),
              const Tab(text: 'JSON'),
            ],
          ),
          Expanded(
            child: TabBarView(
              children: [
                if (formTab != null) formTab,
                _buildEditorTab(
                  title: 'Schema',
                  value: _schemaMap == null ? const PresenceValue.absent() : PresenceValue(_schemaMap),
                  errorText: _schemaEditError,
                  onChanged: _onSchemaEdited,
                ),
                _buildEditorTab(
                  title: 'Value',
                  value: _formState?.value ?? const PresenceValue.absent(),
                  onChanged: _onJsonEdited,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    Widget form = const SizedBox();
    final formStateLoc = _formState;
    if (formStateLoc != null) {
      final fieldHandler = _jsonHandlerRegistry.handlerForField(formStateLoc);

      form = fieldHandler.buildField(
        context: context,
        fieldState: formStateLoc,
        displayContext: FieldDisplayContext.root(formState: formStateLoc),
        // The Value tab follows automatically: it renders _formState.value,
        // and the RawField inside syncs its text on external value changes.
        onChanged: (newState) => unawaited(_setNewValue(newState.value)),
      );
    }

    const verticalSpacing = 16.0;

    // Demo chrome below the form: the validation mode, the Validate button
    // (manual mode) and the sample reset. Kept out of the AppBar so the form
    // owns the top of the screen; a divider separates it from the generated
    // form so it does not read as form content.
    final formFooter = Column(
      children: [
        const SizedBox(height: 40),
        Padding(
          padding: DemoApp.contentPadding.copyWith(top: 0, bottom: 0),
          child: Divider(height: 1, color: theme.dividerColor),
        ),
        const SizedBox(height: verticalSpacing),
        Container(
          padding: DemoApp.contentPadding.copyWith(top: 0, bottom: 0),
          width: double.infinity,
          child: Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            alignment: WrapAlignment.spaceBetween,
            spacing: 32,
            runSpacing: verticalSpacing,
            children: [
              Tooltip(
                message: 'When off, validation runs only via the Validate button',
                child: InkWell(
                  borderRadius: BorderRadius.circular(6),
                  onTap: () => _setValidationMode(
                    _validationMode == _ValidationMode.instant ? _ValidationMode.onDemand : _ValidationMode.instant,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Checkbox(
                        value: _ValidationMode.instant == _validationMode,
                        onChanged: (value) => _setValidationMode(value == true ? _ValidationMode.instant : _ValidationMode.onDemand),
                      ),
                      Text('Live validation', style: theme.textTheme.labelMedium),
                      const SizedBox(width: 8),
                    ],
                  ),
                ),
              ),
              if (_validationMode == _ValidationMode.onDemand)
                FilledButton.icon(
                  icon: const Icon(Icons.rule),
                  label: const Text('Validate'),
                  onPressed: _formState == null ? null : () => unawaited(_validateNow()),
                ),
              TextButton.icon(
                icon: const Icon(Icons.restart_alt),
                label: const Text('Reset sample'),
                onPressed: _sample == null ? null : () => unawaited(_setSample(_sample!)),
              ),
            ],
          ),
        ),
        const SizedBox(height: 64),
      ],
    );

    final formScroll = SingleChildScrollView(
      padding: DemoApp.contentPadding.copyWith(left: 0, right: 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          form,
          formFooter,
        ],
      ),
    );

    final width = MediaQuery.sizeOf(context).width;
    // Narrow (mobile): the form and the editors become full-width tabs.
    final narrow = width < 700;
    // Wide enough for the sample catalog to stay visible as a sidebar
    // instead of hiding behind the drawer.
    final showSidebar = width >= 1100;

    return Scaffold(
      key: _scaffoldKey,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(48),
        child: Theme(
          // Derived from the ambient theme (a fresh ThemeData here would
          // paint the dark mode AppBar with light-theme colors); only the
          // desktop 26px icon-button cap is lifted to fit the 48px bar.
          data: theme.copyWith(
            iconButtonTheme: IconButtonThemeData(style: IconButton.styleFrom(minimumSize: const Size(40, 40))),
          ),
          child: AppBar(
            backgroundColor: theme.colorScheme.inversePrimary,
            // Without the sidebar the catalog is hidden in the drawer, so the
            // current sample name is the more useful title; the package pitch
            // still lives in the drawer header.
            title: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(showSidebar ? widget.title : (_sample?.title ?? widget.title)),
                Text(_tagline, style: theme.textTheme.bodySmall),
              ],
            ),
            actions: [
              IconButton(
                icon: Icon(theme.brightness == Brightness.dark ? Icons.light_mode_outlined : Icons.dark_mode_outlined),
                tooltip: 'Toggle light/dark theme',
                onPressed: () => widget.onToggleTheme(theme.brightness),
              ),
              IconButton(
                icon: const Icon(Icons.open_in_new),
                tooltip: 'json_schema_form_builder on pub.dev',
                onPressed: () => unawaited(launchUrl(_pubDevUrl)),
              ),
              const SizedBox(width: 12),
            ],
          ),
        ),
      ),
      drawer: showSidebar ? null : Drawer(child: _buildSampleCatalog()),
      body: narrow
          ? _buildTabsPane(formTab: formScroll)
          : Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (showSidebar)
                  Container(
                    width: 280,
                    decoration: BoxDecoration(
                      border: BorderDirectional(end: BorderSide(color: theme.dividerColor)),
                    ),
                    child: _buildSampleCatalog(),
                  ),
                Expanded(child: formScroll),
                Expanded(child: _buildTabsPane(formTab: null)),
              ],
            ),
    );
  }

  /// The sample catalog: a header pitching the package (with the outbound
  /// links) above the samples grouped by [SampleCategory]. Used both as the
  /// drawer content and as the permanent sidebar on wide layouts.
  Widget _buildSampleCatalog() {
    final theme = Theme.of(context);

    return ListView(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('json_schema_form_builder', style: theme.textTheme.titleSmall),
              const SizedBox(height: 4),
              Text(
                '$_tagline. Pick a sample, then edit the Schema and JSON tabs and watch the form rebuild.',
                style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              ),
              const SizedBox(height: 4),
              // Wrap, not Row: both link buttons do not fit the drawer's
              // width side by side, so the second one flows to the next line.
              Wrap(
                children: [
                  TextButton.icon(
                    icon: const Icon(Icons.open_in_new, size: 14),
                    label: const Text('pub.dev'),
                    onPressed: () => unawaited(launchUrl(_pubDevUrl)),
                  ),
                  TextButton.icon(
                    icon: const Icon(Icons.code, size: 14),
                    label: const Text('Source'),
                    onPressed: () => unawaited(launchUrl(_repositoryUrl)),
                  ),
                ],
              ),
            ],
          ),
        ),
        for (final category in SampleCategory.values) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
            child: Text(
              category.label.toUpperCase(),
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                letterSpacing: 1.1,
              ),
            ),
          ),
          ...samples
              .where((s) => s.category == category)
              .map(
                (s) => ListTile(
                  dense: true,
                  title: Text(s.title),
                  selected: _sample == s,
                  onTap: () {
                    unawaited(_setSample(s));
                    final scaffold = _scaffoldKey.currentState;
                    if (scaffold != null && scaffold.isDrawerOpen) scaffold.closeDrawer();
                  },
                ),
              ),
        ],
      ],
    );
  }
}
