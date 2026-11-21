import 'package:flutter/rendering.dart';
import 'package:material_ui/material_ui.dart';

/// Builds [wideBuilder] when the incoming width constraint is at least
/// [minWidth], otherwise [narrowBuilder].
///
/// Unlike [LayoutBuilder] this widget is intrinsics-safe: form editors sit
/// inside [AlertDialog]s and [IntrinsicHeight]-measured list rows, where a
/// LayoutBuilder throws "does not support returning intrinsic dimensions".
/// The trade-off is one measurement frame: the incoming width is read during
/// layout and applied post-frame, so the first frame renders nothing.
class WidthThresholdBuilder extends StatefulWidget {
  /// Creates a builder switching variants at [minWidth].
  const WidthThresholdBuilder({
    required this.minWidth,
    required this.wideBuilder,
    required this.narrowBuilder,
    super.key,
  });

  /// The threshold: at least this wide builds [wideBuilder].
  final double minWidth;

  /// Builds the variant for widths of [minWidth] and above.
  final WidgetBuilder wideBuilder;

  /// Builds the variant for widths below [minWidth].
  final WidgetBuilder narrowBuilder;

  @override
  State<WidthThresholdBuilder> createState() => _WidthThresholdBuilderState();
}

class _WidthThresholdBuilderState extends State<WidthThresholdBuilder> {
  /// Null until the first layout pass reports the available width.
  bool? _isWide;

  void _onWidth(double width) {
    final isWide = width >= widget.minWidth;
    if (isWide != _isWide && mounted) {
      setState(() => _isWide = isWide);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isWide = _isWide;
    return _WidthReporter(
      onWidth: _onWidth,
      child: switch (isWide) {
        null => const SizedBox(width: double.infinity),
        true => widget.wideBuilder(context),
        false => widget.narrowBuilder(context),
      },
    );
  }
}

class _WidthReporter extends SingleChildRenderObjectWidget {
  const _WidthReporter({required this.onWidth, super.child});

  final ValueChanged<double> onWidth;

  @override
  RenderObject createRenderObject(BuildContext context) => _RenderWidthReporter(onWidth);

  @override
  void updateRenderObject(BuildContext context, _RenderWidthReporter renderObject) {
    renderObject.onWidth = onWidth;
  }
}

class _RenderWidthReporter extends RenderProxyBox {
  _RenderWidthReporter(this.onWidth);

  ValueChanged<double> onWidth;
  double? _lastReportedWidth;

  @override
  void performLayout() {
    super.performLayout();

    // The available width comes from the constraints, not from the child
    // size, so with a parent whose constraints are content-independent
    // switching variants cannot oscillate. Inside intrinsic-sizing parents
    // (an AlertDialog shrink-wraps content by intrinsic width) this is NOT
    // sufficient: the constraints then depend on the built variant and the
    // choice can flip every frame — such hosts must pin the width instead
    // (see FormDialog.contentMaxWidth).
    final width = constraints.hasBoundedWidth ? constraints.maxWidth : double.infinity;
    if (width == _lastReportedWidth) return;
    _lastReportedWidth = width;

    // setState is illegal during layout; apply on the next frame.
    WidgetsBinding.instance.addPostFrameCallback((_) => onWidth(width));
  }
}
