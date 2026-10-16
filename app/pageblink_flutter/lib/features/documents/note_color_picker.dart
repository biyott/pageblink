import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../app/app_icons.dart';
import '../../app/l10n.dart';
import '../../app/theme.dart';

/// Layout width below which the picker is a bottom sheet, else a popover.
const noteColorSheetBreakpoint = 600.0;

/// Display order (spec: docs/design/note-color/spec.md §3.1). null = Auto.
/// Stored `colorIndex` and display order are separate: 0..4 [Pb.notes],
/// 5..7 [Pb.notesExtra], 8 rainbow.
const _order = <List<int?>>[
  [null, 5, 2, 0, 7],
  [1, 6, 3, 4, 8],
];

const _fade = Duration(milliseconds: 120);

/// Bottom sheet for phones. Tapping a swatch applies it at once ([onPick]);
/// the sheet stays open until dismissed.
Future<void> showNoteColorSheet(
  BuildContext context,
  int? current,
  ValueChanged<int?> onPick,
) => showModalBottomSheet<void>(
  context: context,
  useRootNavigator: true,
  showDragHandle: true,
  builder: (context) => SafeArea(
    child: Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
      child: Center(
        heightFactor: 1,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 320),
          child: NoteColorGrid(current: current, onPick: onPick, sheet: true),
        ),
      ),
    ),
  ),
);

/// The popover for wide layouts: put this in `MenuAnchor.menuChildren` and use
/// [noteColorMenuStyle].
class NoteColorPopover extends StatelessWidget {
  const NoteColorPopover({
    super.key,
    required this.current,
    required this.onPick,
  });

  final int? current;
  final ValueChanged<int?> onPick;

  @override
  Widget build(BuildContext context) =>
      NoteColorGrid(current: current, onPick: onPick, sheet: false);
}

/// Popover surface: the same sheet color as popup menus, r14, 272 wide.
MenuStyle noteColorMenuStyle(Pb pb) => MenuStyle(
  backgroundColor: WidgetStatePropertyAll(
    Color.alphaBlend(pb.sheet, pb.pdfPaper),
  ),
  surfaceTintColor: const WidgetStatePropertyAll(Colors.transparent),
  shadowColor: WidgetStatePropertyAll(pb.glassShadow),
  elevation: const WidgetStatePropertyAll(8),
  padding: const WidgetStatePropertyAll(EdgeInsets.all(14)),
  fixedSize: const WidgetStatePropertyAll(Size.fromWidth(272)),
  shape: WidgetStatePropertyAll(
    RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
  ),
);

/// Title, 5x2 grid and (sheet only) the name of the chosen color.
/// Keeps its own selection so the ring moves the moment a swatch is tapped.
class NoteColorGrid extends StatefulWidget {
  const NoteColorGrid({
    super.key,
    required this.current,
    required this.onPick,
    required this.sheet,
  });

  /// `colorIndex` at open time; null = Auto.
  final int? current;
  final ValueChanged<int?> onPick;
  final bool sheet;

  @override
  State<NoteColorGrid> createState() => _NoteColorGridState();
}

class _NoteColorGridState extends State<NoteColorGrid> {
  late int? _selected = widget.current;

  void _pick(int? i) {
    setState(() => _selected = i);
    widget.onPick(i);
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l;
    final pb = context.pb;
    final theme = Theme.of(context);
    final gap = widget.sheet ? 8.0 : 4.0;
    final caption = _selected == null
        ? l.noteColorAuto
        : l.noteColorName(_selected!);
    return Semantics(
      container: true,
      label: l.noteColor,
      child: FocusTraversalGroup(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l.noteColor,
              style: widget.sheet
                  ? theme.textTheme.titleLarge
                  : theme.textTheme.labelMedium?.copyWith(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: pb.ink,
                    ),
            ),
            SizedBox(height: widget.sheet ? 12 : 8),
            for (var r = 0; r < _order.length; r++) ...[
              if (r > 0) SizedBox(height: gap),
              Row(
                mainAxisAlignment: widget.sheet
                    ? MainAxisAlignment.spaceBetween
                    : MainAxisAlignment.start,
                mainAxisSize: MainAxisSize.max,
                spacing: widget.sheet ? 0 : 4,
                children: [
                  for (final i in _order[r])
                    _Swatch(
                      index: i,
                      selected: i == _selected,
                      onTap: () => _pick(i),
                    ),
                ],
              ),
            ],
            if (widget.sheet) ...[
              const SizedBox(height: 12),
              Text(
                caption,
                style: theme.textTheme.bodySmall?.copyWith(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: pb.inkMuted,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _Swatch extends StatefulWidget {
  const _Swatch({
    required this.index,
    required this.selected,
    required this.onTap,
  });

  /// null = Auto.
  final int? index;
  final bool selected;
  final VoidCallback onTap;

  @override
  State<_Swatch> createState() => _SwatchState();
}

class _SwatchState extends State<_Swatch> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    final l = context.l;
    final pb = context.pb;
    final i = widget.index;
    final name = i == null ? l.noteColorAuto : l.noteColorName(i);
    final reduced = MediaQuery.disableAnimationsOf(context);
    final d = reduced ? Duration.zero : _fade;
    final ringWidth = MediaQuery.highContrastOf(context) ? 3.0 : 2.0;

    final isRainbow = i == Pb.rainbowIndex;
    final fill = isRainbow
        ? null
        : i == null
        ? pb.pdfPaper
        : pb.noteColor(null, colorIndex: i);
    final sweep = isRainbow
        ? SweepGradient(
            colors: [...pb.noteRainbow, pb.noteRainbow.first],
            transform: const GradientRotation(-math.pi / 2),
          )
        : null;

    return Semantics(
      button: true,
      selected: widget.selected,
      inMutuallyExclusiveGroup: true,
      label: name,
      excludeSemantics: true,
      onTap: widget.onTap,
      child: Tooltip(
        message: name,
        waitDuration: const Duration(milliseconds: 400),
        child: SizedBox(
          key: ValueKey('note-color-${i ?? 'auto'}'),
          width: 48,
          height: 48,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Keyboard focus: an outer ring, apart from the inner selection.
              Positioned.fill(
                child: AnimatedContainer(
                  duration: d,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: _focused
                        ? Border.all(color: pb.ink, width: ringWidth)
                        : null,
                  ),
                ),
              ),
              InkResponse(
                onTap: widget.onTap,
                onFocusChange: (f) => setState(() => _focused = f),
                customBorder: const CircleBorder(),
                containedInkWell: true,
                highlightShape: BoxShape.circle,
                radius: 24,
                hoverColor: pb.ink.withValues(alpha: 0.06),
                highlightColor: pb.ink.withValues(alpha: 0.12),
                splashColor: Colors.transparent,
                child: SizedBox(
                  width: 48,
                  height: 48,
                  child: Center(
                    child: AnimatedContainer(
                      duration: d,
                      width: 40,
                      height: 40,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: fill,
                        gradient: sweep,
                        border: Border.all(
                          color: widget.selected ? pb.ink : pb.controlEdge,
                          width: widget.selected ? 2 : 1,
                        ),
                      ),
                      child: i == null
                          ? ExcludeSemantics(
                              child: Text(
                                'A',
                                style: Theme.of(context).textTheme.titleLarge
                                    ?.copyWith(
                                      fontSize: 18,
                                      color: pb.inkMuted,
                                      height: 1,
                                    ),
                              ),
                            )
                          : null,
                    ),
                  ),
                ),
              ),
              IgnorePointer(
                child: AnimatedOpacity(
                  duration: d,
                  opacity: widget.selected ? 1 : 0,
                  child: Icon(AppIcons.check, size: 18, color: pb.ink),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
