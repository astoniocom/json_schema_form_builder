import 'package:material_ui/material_ui.dart';

/// An invisible zero-width strut exactly as tall as a one-line [TextField]
/// (it IS a disabled TextField behind zero opacity, so the height follows
/// the ambient input decoration theme). Placed next to icon buttons that
/// share a row with a field, so the row never collapses below field height.
class MinHeightSetter extends StatelessWidget {
  /// Creates the strut.
  const MinHeightSetter({super.key});

  static const _showDebug = false;

  @override
  Widget build(BuildContext context) {
    return const Opacity(
      opacity: _showDebug ? 1 : 0,
      child: SizedBox(
        width: _showDebug ? 16 : 0,
        child: TextField(
          enabled: false,
        ),
      ),
    );
  }
}
