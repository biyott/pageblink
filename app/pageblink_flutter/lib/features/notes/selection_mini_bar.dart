import 'package:flutter/material.dart';

/// One inline format: tooltip, icon, the pure toggle from markdown_live and
/// whether the selection is already in that format (see `formatState`).
typedef FormatAction = (
  String,
  IconData,
  TextEditingValue Function(TextEditingValue),
  bool,
);

/// Icon button of a format. Active (selection already in the format) uses the
/// same container colours as the heading button; pressing it again clears it.
class FormatButton extends StatelessWidget {
  const FormatButton({
    super.key,
    required this.tooltip,
    required this.icon,
    required this.active,
    required this.onPressed,
  });

  final String tooltip;
  final IconData icon;
  final bool active;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return IconButton(
      tooltip: tooltip,
      icon: Icon(icon),
      isSelected: active,
      visualDensity: VisualDensity.compact,
      style: active
          ? IconButton.styleFrom(
              backgroundColor: scheme.primaryContainer,
              foregroundColor: scheme.onPrimaryContainer,
            )
          : null,
      onPressed: onPressed,
    );
  }
}

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
/// math the stock toolbar uses, so it is clamped to the text area. [selection]
/// anchors to another range (the link chip uses the link) and works for a
/// collapsed caret too.
TextSelectionToolbarAnchors? miniBarAnchors(
  EditableTextState editable,
  RenderBox stack, {
  TextSelection? selection,
}) {
  final render = editable.renderEditable;
  if (!render.attached) return null;
  final points = render.getEndpointsForSelection(
    selection ?? editable.textEditingValue.selection,
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

/// Floats [child] above [anchors] (below if there is no room), filling the
/// stack but taking pointer events only on the child. Never takes focus.
///
/// The child sits in a [TextFieldTapRegion] (same group as the text field), so
/// a press on it is a tap *inside* the field. Without it desktop and web run
/// the field's tap-outside default (`unfocus`), the bar's own focus check then
/// removes it between pointer down and up, and `onPressed` never fires.
class _Floating extends StatelessWidget {
  const _Floating({required this.anchors, required this.child});

  final TextSelectionToolbarAnchors anchors;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: CustomSingleChildLayout(
        delegate: TextSelectionToolbarLayoutDelegate(
          // A little air between the bar and the text.
          anchorAbove: anchors.primaryAnchor - const Offset(0, 6),
          anchorBelow: anchors.secondaryAnchor! + const Offset(0, 6),
        ),
        child: TextFieldTapRegion(
          child: ExcludeFocus(
            child: Material(
              elevation: 3,
              borderRadius: BorderRadius.circular(8),
              color: Theme.of(context).colorScheme.surfaceContainerHigh,
              child: child,
            ),
          ),
        ),
      ),
    );
  }
}

/// Small floating format bar. Put it in a [Stack] over the text field: it
/// fills the stack but only the bar itself takes pointer events. Buttons never
/// take focus, so the body keeps its caret and selection.
///
/// With [onHeading] it ends in compact H1 H2 H3 buttons; [headingLevel] (see
/// `headingLevel` in markdown_live) marks the current one, and pressing it
/// again clears the heading (that is [onHeading]'s job: `setHeading` toggles).
class SelectionMiniBar extends StatelessWidget {
  const SelectionMiniBar({
    super.key,
    required this.anchors,
    required this.actions,
    required this.onApply,
    this.headingLevel = 0,
    this.onHeading,
  });

  final TextSelectionToolbarAnchors anchors;
  final List<FormatAction> actions;
  final void Function(TextEditingValue Function(TextEditingValue)) onApply;
  final int headingLevel;
  final void Function(int level)? onHeading;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return _Floating(
      anchors: anchors,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final (tip, icon, toggle, active) in actions)
            FormatButton(
              tooltip: tip,
              icon: icon,
              active: active,
              onPressed: () => onApply(toggle),
            ),
          if (onHeading != null)
            for (final level in const [1, 2, 3])
              Tooltip(
                message: 'H$level',
                child: InkWell(
                  borderRadius: BorderRadius.circular(6),
                  onTap: () => onHeading!(level),
                  child: Container(
                    key: ValueKey('mini-h$level'),
                    width: 32,
                    height: 32,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: headingLevel == level
                          ? scheme.primaryContainer
                          : null,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      'H$level',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: headingLevel == level
                            ? scheme.onPrimaryContainer
                            : scheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ),
              ),
        ],
      ),
    );
  }
}

/// "Open" chip over a link under the caret. Same floating layout as the bar.
class LinkOpenChip extends StatelessWidget {
  const LinkOpenChip({
    super.key,
    required this.anchors,
    required this.label,
    required this.url,
    required this.icon,
    required this.onPressed,
  });

  final TextSelectionToolbarAnchors anchors;
  final String label;

  /// Shown as the tooltip, so the target is visible before opening.
  final String url;
  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return _Floating(
      anchors: anchors,
      child: Tooltip(
        message: url,
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: onPressed,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(label, style: Theme.of(context).textTheme.labelLarge),
                const SizedBox(width: 6),
                Icon(icon, size: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
