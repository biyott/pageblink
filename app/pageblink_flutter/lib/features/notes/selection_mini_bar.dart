import 'package:flutter/material.dart';

/// One inline format: tooltip, icon and the pure toggle from markdown_live.
typedef FormatAction = (
  String,
  IconData,
  TextEditingValue Function(TextEditingValue),
);

/// The [EditableTextState] under [context] (TextField does not expose it).
EditableTextState? findEditableText(BuildContext? context) {
  EditableTextState? found;
  void visit(Element e) {
    if (found != null) return;
    final s = e is StatefulElement ? e.state : null;
    if (s is EditableTextState) {
      found = s;
    } else {
      e.visitChildren(visit);
    }
  }

  (context as Element?)?.visitChildren(visit);
  return found;
}

/// Anchors of the selection (above its first line, below its last) in the
/// coordinates of [stack]; null if the selection has no geometry yet. Same
/// math the stock toolbar uses, so it is clamped to the text area.
TextSelectionToolbarAnchors? miniBarAnchors(
  EditableTextState editable,
  RenderBox stack,
) {
  final render = editable.renderEditable;
  if (!render.attached) return null;
  final points = render.getEndpointsForSelection(
    editable.textEditingValue.selection,
  );
  if (points.isEmpty) return null;
  final (:startGlyphHeight, :endGlyphHeight) = editable.getGlyphHeights();
  final global = TextSelectionToolbarAnchors.fromSelection(
    renderBox: render,
    startGlyphHeight: startGlyphHeight,
    endGlyphHeight: endGlyphHeight,
    selectionEndpoints: points,
  );
  final below = global.secondaryAnchor;
  if (below == null) return null;
  return TextSelectionToolbarAnchors(
    primaryAnchor: stack.globalToLocal(global.primaryAnchor),
    secondaryAnchor: stack.globalToLocal(below),
  );
}

/// Small floating format bar. Put it in a [Stack] over the text field: it
/// fills the stack but only the bar itself takes pointer events. Buttons never
/// take focus, so the body keeps its caret and selection.
class SelectionMiniBar extends StatelessWidget {
  const SelectionMiniBar({
    super.key,
    required this.anchors,
    required this.actions,
    required this.onApply,
  });

  final TextSelectionToolbarAnchors anchors;
  final List<FormatAction> actions;
  final void Function(TextEditingValue Function(TextEditingValue)) onApply;

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: CustomSingleChildLayout(
        delegate: TextSelectionToolbarLayoutDelegate(
          // A little air between the bar and the text.
          anchorAbove: anchors.primaryAnchor - const Offset(0, 6),
          anchorBelow: anchors.secondaryAnchor! + const Offset(0, 6),
        ),
        child: ExcludeFocus(
          child: Material(
            elevation: 3,
            borderRadius: BorderRadius.circular(8),
            color: Theme.of(context).colorScheme.surfaceContainerHigh,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final (tip, icon, toggle) in actions)
                  IconButton(
                    tooltip: tip,
                    icon: Icon(icon),
                    visualDensity: VisualDensity.compact,
                    onPressed: () => onApply(toggle),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
