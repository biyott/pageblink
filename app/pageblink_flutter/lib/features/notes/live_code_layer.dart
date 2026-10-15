import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show RenderEditable;
import 'package:flutter/semantics.dart' show SemanticsProperties;

import '../../app/app_icons.dart';
import 'markdown_live.dart';

/// How far a block background reaches past the text area on each side, and
/// the vertical air between the first / last line and the edge (research 024
/// stage 2). The text itself does not move.
const kFenceBleed = 12.0;
const _padY = 4.0;
const _radius = 10.0;
const _buttonSize = 24.0;

typedef FenceTarget = ({FenceBlock block, Rect rect, Rect? head});

/// Where the background of each fenced block near the viewport goes, in the
/// coordinates of [stack]: the union of the line boxes of its range, widened
/// to the text area plus [kFenceBleed]. A block that continues above / below
/// the viewport is extended past it (the painter clips), so its corners are
/// not drawn there. [FenceTarget.head] is the box of the opening fence line
/// when that line is visible (label, copy button).
///
/// Read from [render] when called (paint, hover, hit test), so scroll, resize
/// and line wraps are already applied (research 024 T2 / T10).
///
/// [topAir]: how far above [render]'s top text still shows (the field's top
/// content padding under the screen's `ClipRect`). The viewport's top is that
/// much higher, so blocks keep their background (and head) as long as the text.
List<FenceTarget> fenceTargets(
  RenderEditable render,
  RenderBox stack,
  List<FenceBlock> blocks, {
  double topAir = 0,
}) {
  if (blocks.isEmpty ||
      !render.attached ||
      !stack.attached ||
      !render.hasSize ||
      render.debugNeedsLayout) {
    return const [];
  }
  final plain = render.plainText;
  if (plain.length < blocks.last.end) return const []; // not laid out
  final xf = render.getTransformTo(stack);
  final box = MatrixUtils.transformRect(xf, Offset.zero & render.size);
  final view = Rect.fromLTRB(box.left, box.top - topAir, box.right, box.bottom);
  final lo = render.getPositionForPoint(
    render.localToGlobal(Offset(0, -topAir)),
  );
  final hi = render.getPositionForPoint(
    render.localToGlobal(render.size.bottomRight(Offset.zero)),
  );
  final out = <FenceTarget>[];
  for (final b in blocks) {
    if (b.end < lo.offset) continue;
    if (b.start > hi.offset) break;
    final from = math.max(b.start, lo.offset);
    final to = math.min(b.end, hi.offset);
    if (to < from) continue;
    Rect? r;
    for (final tb in render.getBoxesForSelection(
      TextSelection(baseOffset: from, extentOffset: to),
    )) {
      r = r == null ? tb.toRect() : r.expandToInclude(tb.toRect());
    }
    // An empty last line (unclosed fence ending in a newline) has no box of
    // its own; the caret rectangle of the end position is its line.
    if (to == plain.length && to > from && plain.codeUnitAt(to - 1) == 0x0a) {
      final c = render.getLocalRectForCaret(TextPosition(offset: to));
      r = r == null ? c : r.expandToInclude(c);
    }
    if (r == null && from == to) {
      r = render.getLocalRectForCaret(TextPosition(offset: from));
    }
    if (r == null) continue;
    final v = MatrixUtils.transformRect(xf, r);
    final top = b.start >= lo.offset ? v.top - _padY : view.top - 4 * _radius;
    final bottom = b.end <= hi.offset
        ? v.bottom + _padY
        : view.bottom + 4 * _radius;
    Rect? head;
    if (b.start >= lo.offset) {
      for (final tb in render.getBoxesForSelection(
        TextSelection(baseOffset: b.start, extentOffset: b.openEnd),
      )) {
        final t = MatrixUtils.transformRect(xf, tb.toRect());
        head = head == null ? t : head.expandToInclude(t);
      }
    }
    out.add((
      block: b,
      rect: Rect.fromLTRB(
        view.left - kFenceBleed,
        top,
        view.right + kFenceBleed,
        bottom,
      ),
      head: head,
    ));
  }
  return out;
}

/// The block under [p] (stack coordinates), if any.
FenceTarget? fenceTargetAt(List<FenceTarget> targets, Offset p) {
  for (final t in targets) {
    if (t.rect.contains(p)) return t;
  }
  return null;
}

/// The copy button of [t] (inside the text area, on the opening fence line),
/// or null when that line is not visible.
Rect? copyButtonRect(FenceTarget t) {
  final h = t.head;
  if (h == null) return null;
  final right = t.rect.right - kFenceBleed - 4;
  return Rect.fromLTWH(
    right - _buttonSize,
    h.center.dy - _buttonSize / 2,
    _buttonSize,
    _buttonSize,
  );
}

/// What the pointer does to the code blocks: which block it is over (the copy
/// button of that block shows), whether it is over the button, and which block
/// was just copied (a short "Copied" instead of the button).
class CodeBlockUi extends ChangeNotifier {
  int? _hovered, _copied;
  bool _overButton = false;
  Timer? _timer;

  /// Start offset of the block under the pointer.
  int? get hovered => _hovered;
  bool get overButton => _overButton;
  int? get copied => _copied;

  /// The copy control (button or "Copied") is shown for the block at [start].
  bool shows(int start) => _hovered == start || _copied == start;

  void hover(int? start, {bool button = false}) {
    if (start == _hovered && button == _overButton) return;
    _hovered = start;
    _overButton = start != null && button;
    notifyListeners();
  }

  void flashCopied(int start) {
    _timer?.cancel();
    _copied = start;
    notifyListeners();
    _timer = Timer(const Duration(milliseconds: 1500), () {
      _copied = null;
      notifyListeners();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}

TextPainter _text(String s, TextStyle style) => TextPainter(
  text: TextSpan(text: s, style: style),
  textDirection: TextDirection.ltr,
  maxLines: 1,
  ellipsis: '…',
);

void _paintIcon(Canvas canvas, IconData icon, Offset center, Color color) {
  final tp = TextPainter(
    text: TextSpan(
      text: String.fromCharCode(icon.codePoint),
      style: TextStyle(
        fontSize: 16,
        fontFamily: icon.fontFamily,
        package: icon.fontPackage,
        color: color,
      ),
    ),
    textDirection: TextDirection.ltr,
  )..layout();
  tp.paint(canvas, center - Offset(tp.width / 2, tp.height / 2));
}

/// Paints the block backgrounds and language labels *behind* the note body
/// field (research 024, approach A): one rounded rectangle per fenced block,
/// from the line boxes the field reports, so scroll, resize and line wraps
/// follow in the same frame. Put it first in the [Stack] that holds the field,
/// and give the stack `clipBehavior: Clip.none` (the fill reaches
/// [kFenceBleed] past the text). It takes no pointer events.
class LiveCodeBackLayer extends StatelessWidget {
  const LiveCodeBackLayer({
    super.key,
    required this.enabled,
    required this.controller,
    required this.scroll,
    required this.ui,
    required this.render,
    required this.stack,
    required this.fill,
    required this.labelStyle,
    this.copyEnabled = true,
    this.topAir = 0,
  });

  /// False (source mode): nothing is painted.
  final bool enabled;
  final LiveMarkdownController controller;
  final ScrollController scroll;
  final CodeBlockUi ui;
  final ValueGetter<RenderEditable?> render;
  final ValueGetter<RenderBox?> stack;
  final Color fill;

  /// Language label style (11 px, muted).
  final TextStyle labelStyle;

  /// The copy button can show, so the label makes room for it.
  final bool copyEnabled;

  /// The field's top content padding ([NoteSpacing.bodyGap]): the fill is cut
  /// that far above the editable's top, where the text is cut.
  final double topAir;

  @override
  Widget build(BuildContext context) {
    if (!enabled) return const SizedBox.shrink();
    return Positioned.fill(
      child: IgnorePointer(
        child: ListenableBuilder(
          listenable: Listenable.merge([controller, scroll]),
          builder: (context, _) => CustomPaint(painter: _BackPainter(this)),
        ),
      ),
    );
  }
}

class _BackPainter extends CustomPainter {
  _BackPainter(this.w) : super(repaint: w.ui);

  final LiveCodeBackLayer w;

  @override
  void paint(Canvas canvas, Size size) {
    final r = w.render(), s = w.stack();
    if (r == null || s == null) return;
    final targets = fenceTargets(
      r,
      s,
      w.controller.fences,
      topAir: w.topAir,
    );
    if (targets.isEmpty) return;
    final view = MatrixUtils.transformRect(
      r.getTransformTo(s),
      Offset.zero & r.size,
    );
    canvas.save();
    canvas.clipRect(
      Rect.fromLTRB(
        view.left - kFenceBleed,
        view.top - w.topAir,
        view.right + kFenceBleed,
        view.bottom,
      ),
    );
    final paint = Paint()..color = w.fill;
    for (final t in targets) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(t.rect, const Radius.circular(_radius)),
        paint,
      );
      final head = t.head, lang = t.block.lang;
      if (head == null || lang.isEmpty || w.ui.copied == t.block.start) {
        continue;
      }
      final room = w.copyEnabled && w.ui.shows(t.block.start)
          ? _buttonSize + 8
          : 4.0;
      final right = t.rect.right - kFenceBleed - room;
      final tp = _text(lang, w.labelStyle)..layout(maxWidth: 160);
      tp.paint(
        canvas,
        Offset(right - tp.width, head.center.dy - tp.height / 2),
      );
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_BackPainter old) => true;
}

/// The copy button of the code block under the pointer, drawn over the field
/// (hover only: touch has the context menu). Same structure as the checkbox
/// layer: a tap region, a hit test only inside the button, no recognizer in
/// the text. Copies [fenceBody] through [onCopy] and shows [copiedLabel] for a
/// moment.
class LiveCodeCopyLayer extends StatelessWidget {
  const LiveCodeCopyLayer({
    super.key,
    required this.controller,
    required this.scroll,
    required this.ui,
    required this.render,
    required this.stack,
    required this.color,
    required this.hoverFill,
    required this.accent,
    required this.labelStyle,
    required this.copyLabel,
    required this.copiedLabel,
    required this.onCopy,
    this.topAir = 0,
  });

  final LiveMarkdownController controller;
  final ScrollController scroll;
  final CodeBlockUi ui;
  final ValueGetter<RenderEditable?> render;
  final ValueGetter<RenderBox?> stack;
  final Color color, hoverFill, accent;
  final TextStyle labelStyle;
  final String copyLabel, copiedLabel;

  /// Start offset of the block to copy.
  final ValueChanged<int> onCopy;

  /// See [LiveCodeBackLayer.topAir]: the button is cut and pressable down to
  /// the same line the text is cut at.
  final double topAir;

  @override
  Widget build(BuildContext context) {
    final dir = Directionality.of(context);
    return ListenableBuilder(
      listenable: Listenable.merge([controller, scroll]),
      builder: (context, _) {
        final painter = _CopyPainter(this, dir);
        return Positioned.fill(
          child: TextFieldTapRegion(
            child: GestureDetector(
              behavior: HitTestBehavior.deferToChild,
              onTapUp: (d) {
                final hit = painter.buttonAt(d.localPosition);
                if (hit != null) onCopy(hit.block.start);
              },
              child: CustomPaint(painter: painter),
            ),
          ),
        );
      },
    );
  }
}

class _CopyPainter extends CustomPainter {
  _CopyPainter(this.w, this.direction) : super(repaint: w.ui);

  final LiveCodeCopyLayer w;
  final TextDirection direction;
  List<FenceTarget>? _last;

  List<FenceTarget> _targets() {
    final r = w.render(), s = w.stack();
    if (r == null || s == null) return const [];
    return fenceTargets(r, s, w.controller.fences, topAir: w.topAir);
  }

  /// The editable's box in stack coordinates, extended up by [topAir].
  Rect? _clip() {
    final r = w.render(), s = w.stack();
    if (r == null || s == null || !r.attached || !s.attached || !r.hasSize) {
      return null;
    }
    final v = MatrixUtils.transformRect(
      r.getTransformTo(s),
      Offset.zero & r.size,
    );
    return Rect.fromLTRB(
      v.left - kFenceBleed,
      v.top - w.topAir,
      v.right + kFenceBleed,
      v.bottom,
    );
  }

  /// The block whose button is shown and under [p].
  FenceTarget? buttonAt(Offset p) {
    // Outside the clip the button is not drawn, so it cannot be pressed.
    if (!(_clip()?.contains(p) ?? false)) return null;
    for (final t in _last ?? _targets()) {
      if (!w.ui.shows(t.block.start)) continue;
      final b = copyButtonRect(t);
      if (b != null && b.inflate(2).contains(p)) return t;
    }
    return null;
  }

  @override
  bool? hitTest(Offset position) => buttonAt(position) != null;

  @override
  void paint(Canvas canvas, Size size) {
    final targets = _last = _targets();
    final clip = _clip();
    if (clip == null) return;
    canvas.save();
    canvas.clipRect(clip);
    for (final t in targets) {
      if (!w.ui.shows(t.block.start)) continue;
      final b = copyButtonRect(t);
      if (b == null) continue;
      if (w.ui.copied == t.block.start) {
        _paintIcon(canvas, AppIcons.check, b.center, w.accent);
        final tp = _text(w.copiedLabel, w.labelStyle.copyWith(color: w.accent))
          ..layout(maxWidth: 140);
        tp.paint(
          canvas,
          Offset(b.left - 4 - tp.width, b.center.dy - tp.height / 2),
        );
      } else {
        if (w.ui.overButton && w.ui.hovered == t.block.start) {
          canvas.drawRRect(
            RRect.fromRectAndRadius(b, const Radius.circular(6)),
            Paint()..color = w.hoverFill,
          );
        }
        _paintIcon(canvas, AppIcons.copy, b.center, w.color);
      }
    }
    canvas.restore();
  }

  @override
  SemanticsBuilderCallback? get semanticsBuilder =>
      (size) => [
        for (final t in _targets())
          if (copyButtonRect(t) case final b?)
            CustomPainterSemantics(
              key: ValueKey(t.block.start),
              rect: b,
              properties: SemanticsProperties(
                button: true,
                enabled: true,
                label: w.copyLabel,
                textDirection: direction,
                onTap: () => w.onCopy(t.block.start),
              ),
            ),
      ];

  @override
  bool shouldRepaint(_CopyPainter old) => true;

  @override
  bool shouldRebuildSemantics(_CopyPainter old) => true;
}
