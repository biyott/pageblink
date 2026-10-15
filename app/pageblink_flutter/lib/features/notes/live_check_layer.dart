import 'dart:math' as math;

import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show RenderEditable;
import 'package:flutter/semantics.dart' show SemanticsProperties;

import 'markdown_live.dart';

typedef CheckTarget = ({CheckMarker item, Rect rect});

/// Where the checkbox of each checklist item near the viewport goes: the
/// rectangle of its (transparent) `- [ ] ` prefix in the coordinates of
/// [stack]. Read from [render] when called (paint, hit test), so scroll,
/// resize, font size and line wraps are already applied (research 024 T2/T10).
///
/// [topAir]: how far above [render]'s top text still shows (the field's top
/// content padding, which the screen's `ClipRect` leaves visible). Items in
/// that band are read too, so they are not dropped before the text is.
List<CheckTarget> checkBoxTargets(
  RenderEditable render,
  RenderBox stack,
  List<CheckMarker> items, {
  double topAir = 0,
}) {
  if (items.isEmpty ||
      !render.attached ||
      !stack.attached ||
      !render.hasSize ||
      render.debugNeedsLayout) {
    return const [];
  }
  if (render.plainText.length < items.last.end) return const []; // not laid out
  final xf = render.getTransformTo(stack);
  // Text offsets of the viewport's corners: only items in between are read.
  final lo = render.getPositionForPoint(
    render.localToGlobal(Offset(0, -topAir)),
  );
  final hi = render.getPositionForPoint(
    render.localToGlobal(render.size.bottomRight(Offset.zero)),
  );
  final out = <CheckTarget>[];
  for (final m in items) {
    if (m.end < lo.offset) continue;
    if (m.start > hi.offset) break;
    final boxes = render.getBoxesForSelection(
      TextSelection(baseOffset: m.start, extentOffset: m.end),
    );
    if (boxes.isEmpty) continue;
    var r = boxes.first.toRect();
    for (final b in boxes.skip(1)) {
      if ((b.toRect().center.dy - r.center.dy).abs() < r.height) {
        r = r.expandToInclude(b.toRect());
      }
    }
    out.add((item: m, rect: MatrixUtils.transformRect(xf, r)));
  }
  return out;
}

/// The clickable area of an item: its prefix, at least 28 px tall (44 on
/// touch), never left of the text area.
Rect checkHitRect(Rect prefix, {bool touch = false}) {
  final h = touch ? 44.0 : 28.0;
  return Rect.fromLTRB(
    math.max(0, prefix.left - 8),
    prefix.center.dy - h / 2,
    prefix.right,
    prefix.center.dy + h / 2,
  );
}

/// The item under [p] (stack coordinates), the nearest one if areas overlap.
CheckTarget? checkTargetAt(
  List<CheckTarget> targets,
  Offset p, {
  bool touch = false,
}) {
  CheckTarget? best;
  var bestDy = double.infinity;
  for (final t in targets) {
    if (!checkHitRect(t.rect, touch: touch).contains(p)) continue;
    final dy = (p.dy - t.rect.center.dy).abs();
    if (dy < bestDy) {
      best = t;
      bestDy = dy;
    }
  }
  return best;
}

/// Draws the checkboxes of a checklist over the note body field, exactly where
/// its transparent `- [ ] ` prefixes are (research 024, approach A), and turns
/// a tap on one into [onToggle]. The text is never changed here. Put it in the
/// [Stack] that holds the field, after it: it hit-tests only inside the boxes,
/// so everything else reaches the field, and a tap on a box does not move its
/// caret or focus (it is in the field's tap region).
///
/// Taps are handled here and not by a `TextSpan.recognizer` because
/// `RenderEditable` cannot describe semantics for a recognizer inside an
/// editable (assertion outside macOS, dropped text-field semantics in release).
class LiveCheckLayer extends StatelessWidget {
  const LiveCheckLayer({
    super.key,
    required this.controller,
    required this.scroll,
    required this.hover,
    required this.render,
    required this.stack,
    required this.accent,
    required this.onAccent,
    required this.border,
    required this.doneLabel,
    required this.todoLabel,
    required this.onToggle,
    this.touch = false,
    this.topAir = 0,
  });

  final LiveMarkdownController controller;
  final ScrollController scroll;

  /// Prefix start of the item under the mouse (null: none): hover outline.
  final ValueListenable<int?> hover;
  final ValueGetter<RenderEditable?> render;
  final ValueGetter<RenderBox?> stack;
  final Color accent, onAccent, border;
  final String doneLabel, todoLabel;

  /// Taps, and screen readers' tap: toggles the item whose prefix starts there.
  final ValueChanged<int> onToggle;

  /// Larger hit area on touch devices.
  final bool touch;

  /// The field's top content padding ([NoteSpacing.bodyGap]): text shows that
  /// far above the editable's top, so boxes are drawn and hit down to the same
  /// line the text is cut at, not at the editable's top.
  final double topAir;

  @override
  Widget build(BuildContext context) {
    final dir = Directionality.of(context);
    // A new painter per text / scroll change: that is what makes the semantics
    // (screen reader nodes, which a repaint alone does not refresh) follow.
    return ListenableBuilder(
      listenable: Listenable.merge([controller, scroll]),
      builder: (context, _) {
        final painter = _CheckPainter(this, dir);
        return Positioned.fill(
          child: TextFieldTapRegion(
            child: GestureDetector(
              behavior: HitTestBehavior.deferToChild,
              onTapUp: (d) {
                final hit = painter.targetAt(d.localPosition);
                if (hit != null) onToggle(hit.item.start);
              },
              child: CustomPaint(painter: painter),
            ),
          ),
        );
      },
    );
  }
}

class _CheckPainter extends CustomPainter {
  _CheckPainter(this.w, this.direction) : super(repaint: w.hover);

  final LiveCheckLayer w;
  final TextDirection direction;

  /// What the last paint drew; hit tests and taps use it, so they agree with
  /// the screen.
  List<CheckTarget>? _last;

  List<CheckTarget> _targets() {
    final r = w.render(), s = w.stack();
    if (r == null || s == null) return const [];
    return checkBoxTargets(r, s, w.controller.checks, topAir: w.topAir);
  }

  /// The editable's box in stack coordinates, extended up by [topAir]: where
  /// the text is visible, so where boxes are drawn and can be hit.
  Rect? _clip() {
    final r = w.render(), s = w.stack();
    if (r == null || s == null || !r.attached || !s.attached || !r.hasSize) {
      return null;
    }
    final v = MatrixUtils.transformRect(
      r.getTransformTo(s),
      Offset.zero & r.size,
    );
    return Rect.fromLTRB(v.left, v.top - w.topAir, v.right, v.bottom);
  }

  CheckTarget? targetAt(Offset p) {
    // Outside the clip nothing is drawn, so nothing is pressable either.
    if (!(_clip()?.contains(p) ?? false)) return null;
    return checkTargetAt(_last ?? _targets(), p, touch: w.touch);
  }

  @override
  bool? hitTest(Offset position) => targetAt(position) != null;

  @override
  void paint(Canvas canvas, Size size) {
    final targets = _last = _targets();
    final view = _clip();
    if (targets.isEmpty || view == null) return;
    final hot = w.hover.value;
    canvas.save();
    canvas.clipRect(view);
    for (final (:item, :rect) in targets) {
      final side = math.max(10.0, math.min(18.0, rect.width - 4));
      final box = Rect.fromLTWH(
        rect.left,
        rect.center.dy - side / 2,
        side,
        side,
      );
      final rr = RRect.fromRectAndRadius(box, const Radius.circular(5));
      if (item.done) {
        canvas.drawRRect(rr, Paint()..color = w.accent);
        final p = Path()
          ..moveTo(box.left + side * 0.27, box.top + side * 0.52)
          ..lineTo(box.left + side * 0.43, box.top + side * 0.68)
          ..lineTo(box.left + side * 0.74, box.top + side * 0.34);
        canvas.drawPath(
          p,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2
            ..strokeCap = StrokeCap.round
            ..strokeJoin = StrokeJoin.round
            ..color = w.onAccent,
        );
      } else {
        canvas.drawRRect(
          rr.deflate(0.75),
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.5
            ..color = hot == item.start ? w.accent : w.border,
        );
      }
    }
    canvas.restore();
  }

  @override
  SemanticsBuilderCallback? get semanticsBuilder =>
      (size) => [
        for (final (:item, :rect) in _targets())
          CustomPainterSemantics(
            key: ValueKey(item.start),
            rect: checkHitRect(rect, touch: w.touch),
            properties: SemanticsProperties(
              checked: item.done,
              enabled: true,
              label: item.done ? w.doneLabel : w.todoLabel,
              textDirection: direction,
              onTap: () => w.onToggle(item.start),
            ),
          ),
      ];

  @override
  bool shouldRepaint(_CheckPainter old) => true;

  @override
  bool shouldRebuildSemantics(_CheckPainter old) => true;
}
