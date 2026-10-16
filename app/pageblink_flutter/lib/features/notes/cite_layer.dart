import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show RenderEditable;

import 'live_code_layer.dart' show kFenceBleed;
import 'markdown_live.dart';

export 'markdown_live.dart' show citeLineRange, locateQuote;

/// Cited passage as one soft block behind the note body (research 027, U2):
/// the lines the quote touches, widened to the text area, with a 3px rail on
/// the left and a short pulse when it appears. Same pattern as
/// `LiveCodeBackLayer`: it reads the line boxes from the field's
/// `RenderEditable`, so scroll, resize and wraps follow in the same frame, and
/// it never touches the text, the selection or the IME composition.

/// Air above the first and below the last line of the block.
const kCitePadY = 4.0;
const _radius = 10.0;
const _railWidth = 3.0;
const _pulseMs = 600;

/// One rectangle from the line boxes of a quote: their union, widened to
/// [left]..[right] (the text area plus the bleed) and [padY] above and below.
/// Null for no boxes. Pure, so the merge of several line boxes is testable.
Rect? citeBlockRect(
  Iterable<Rect> lineBoxes, {
  required double left,
  required double right,
  double padY = kCitePadY,
}) {
  Rect? u;
  for (final b in lineBoxes) {
    u = u == null ? b : u.expandToInclude(b);
  }
  if (u == null) return null;
  return Rect.fromLTRB(left, u.top - padY, right, u.bottom + padY);
}

/// Union of the line boxes of [range] in the coordinates of [render] (scroll
/// included). Null while the field is not laid out for that text or the range
/// has no box.
Rect? citeLocalBounds(RenderEditable render, String text, TextRange range) {
  if (!render.attached || !render.hasSize || render.debugNeedsLayout) {
    return null;
  }
  final lines = citeLineRange(text, range);
  if (lines.isCollapsed || render.plainText.length < lines.end) return null;
  return citeBlockRect(
    [
      for (final b in render.getBoxesForSelection(
        TextSelection(baseOffset: lines.start, extentOffset: lines.end),
      ))
        b.toRect(),
    ],
    left: 0,
    right: 0,
    padY: 0,
  );
}

/// Where the block of [range] goes, and the rectangle it is cut to, in the
/// coordinates of [stack]. A block that continues past the viewport is
/// extended beyond it, so its rounded corners are not drawn there.
///
/// The field is only as tall as its text while the text is shorter than the
/// viewport (`RenderEditable` sizes to `min(text, viewport)`), so the clip
/// leaves the block's bottom air visible then; a longer text is cut at the
/// field's bottom edge, as the text is.
({Rect rect, Rect clip})? citeTarget(
  RenderEditable render,
  RenderBox stack,
  String text,
  TextRange range, {
  double topAir = 0,
}) {
  if (!stack.attached) return null;
  final local = citeLocalBounds(render, text, range);
  if (local == null) return null;
  final xf = render.getTransformTo(stack);
  final view = MatrixUtils.transformRect(xf, Offset.zero & render.size);
  final v = MatrixUtils.transformRect(xf, local);
  final end = render
      .getLocalRectForCaret(TextPosition(offset: render.plainText.length))
      .bottom;
  final fits = end <= render.size.height + 0.5;
  final clip = Rect.fromLTRB(
    view.left - kFenceBleed,
    view.top - topAir,
    view.right + kFenceBleed,
    fits ? view.bottom + kCitePadY : view.bottom,
  );
  final top = v.top - kCitePadY;
  final bottom = v.bottom + kCitePadY;
  return (
    rect: Rect.fromLTRB(
      clip.left,
      top < clip.top ? clip.top - 4 * _radius : top,
      clip.right,
      bottom > clip.bottom ? clip.bottom + 4 * _radius : bottom,
    ),
    clip: clip,
  );
}

/// The scroll offset that shows a block `[top, top + height)` (content
/// coordinates, from the field's top) in a viewport of [viewport] px: centered
/// when it fits, top-aligned with a little air when it is taller. Clamped to
/// `[min, max]`. Pure.
double citeScrollTarget({
  required double top,
  required double height,
  required double viewport,
  required double min,
  required double max,
  double air = 16,
}) {
  final centered = top - (viewport - height) / 2;
  final target = height > viewport - 2 * air ? top - air : centered;
  return target.clamp(min, math.max(min, max));
}

/// Paints the cited block *behind* the note field. Put it in the [Stack] that
/// holds the field (after `LiveCodeBackLayer`, so a cited code block still
/// shows it), with `clipBehavior: Clip.none`. Takes no pointer events.
///
/// The pulse (28% -> 12%, 600 ms) runs when the layer is built and whenever
/// [pulseKey] changes (another citation); it is skipped when the platform asks
/// for fewer animations. [visible] false fades the block out.
class CiteBackLayer extends StatefulWidget {
  const CiteBackLayer({
    super.key,
    required this.controller,
    required this.scroll,
    required this.render,
    required this.stack,
    required this.fill,
    required this.pulse,
    required this.edge,
    this.visible = true,
    this.pulseKey,
    this.topAir = 0,
  });

  final LiveMarkdownController controller;
  final ScrollController scroll;
  final ValueGetter<RenderEditable?> render;
  final ValueGetter<RenderBox?> stack;

  /// Resting fill, first-frame fill, and the rail.
  final Color fill, pulse, edge;
  final bool visible;
  final Object? pulseKey;

  /// See `LiveCodeBackLayer.topAir`.
  final double topAir;

  @override
  State<CiteBackLayer> createState() => _CiteBackLayerState();
}

class _CiteBackLayerState extends State<CiteBackLayer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _anim = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: _pulseMs),
    value: 1,
  );
  bool _started = false;

  bool get _reduced => MediaQuery.disableAnimationsOf(context);

  void _pulse() {
    if (_reduced) {
      _anim.value = 1;
    } else {
      _anim.forward(from: 0);
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_started) {
      _started = true;
      _pulse();
    }
  }

  @override
  void didUpdateWidget(CiteBackLayer old) {
    super.didUpdateWidget(old);
    if (old.pulseKey != widget.pulseKey && widget.visible) _pulse();
  }

  @override
  void dispose() {
    _anim.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Positioned.fill(
    child: IgnorePointer(
      child: AnimatedOpacity(
        opacity: widget.visible ? 1 : 0,
        duration: _reduced ? Duration.zero : const Duration(milliseconds: 180),
        child: ListenableBuilder(
          listenable: Listenable.merge([widget.controller, widget.scroll]),
          builder: (context, _) => CustomPaint(
            key: const ValueKey('cite-back'),
            painter: _CitePainter(this),
          ),
        ),
      ),
    ),
  );
}

class _CitePainter extends CustomPainter {
  _CitePainter(this.s) : super(repaint: s._anim);

  final _CiteBackLayerState s;

  @override
  void paint(Canvas canvas, Size size) {
    final w = s.widget;
    final range = w.controller.quoteRange;
    final r = w.render(), st = w.stack();
    if (range == null || r == null || st == null) return;
    final target = citeTarget(
      r,
      st,
      w.controller.text,
      range,
      topAir: w.topAir,
    );
    if (target == null) return;
    final rect = target.rect;
    canvas.save();
    canvas.clipRect(target.clip);
    final t = Curves.easeOut.transform(s._anim.value);
    final color = t <= 0
        ? w.pulse
        : t >= 1
        ? w.fill
        : Color.lerp(w.pulse, w.fill, t)!;
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(_radius)),
      Paint()..color = color,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(
          rect.left,
          rect.top + kCitePadY,
          _railWidth,
          math.max(rect.height - 2 * kCitePadY, 0),
        ),
        const Radius.circular(_railWidth / 2),
      ),
      Paint()..color = w.edge,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(_CitePainter old) => true;
}
