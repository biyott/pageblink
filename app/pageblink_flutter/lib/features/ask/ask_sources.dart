import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:pageblink_client/pageblink_client.dart';

import '../../app/app_icons.dart';
import '../../app/l10n.dart';
import '../../app/theme.dart';

// Spec: docs/design/ask-sources/spec.md (inline marker, source rows, motion).

/// Row selection timeline (after spec §3, revised 2026-10-15): a 140ms start
/// delay, then 1400ms in four beats ending in a resting state that stays until
/// another source is picked. 12.5% shorter than the 1760ms it replaces; every
/// beat is the old one x 0.875.
///   rise   245ms  fill and purple glow up to 1.0        easeOutCubic
///   dip    420ms  1.0 -> 0.35 (breathe)                 easeInOutSine
///   rise2  262ms  0.35 -> 0.85                          easeInOutSine
///   bloom  473ms  a light spreads from the centre; the inside goes back to
///                 the neutral row colour; the glow turns into the cool
///                 (violet-blue) halo that stays
const sourceFlashLead = Duration(milliseconds: 140);
const sourceFlashDuration = Duration(milliseconds: 1540);

const _lead = 140.0,
    _rise = 245.0,
    _dip = 420.0,
    _rise2 = 262.0,
    _bloomMs = 473.0;
const _total = _lead + _rise + _dip + _rise2 + _bloomMs;

/// What one source row shows. All values 0..1.
class SourceFx {
  const SourceFx({
    this.fill = 0,
    this.halo = 0,
    this.rainbow = 0,
    this.bloom = 0,
    this.bloomAlpha = 0,
  });

  /// Share of the inside that has moved from the neutral row colour
  /// (`chipBg`) to the pulse colour (`accentContainer`); 0 = at rest.
  final double fill;

  /// Strength of the outer glow; 0 = no shadows at all.
  final double halo;

  /// 0 = one purple glow, 1 = the resting cool-spectrum halo.
  final double rainbow;

  /// Radius progress and brightness of the centre-out light.
  final double bloom, bloomAlpha;

  static const none = SourceFx();

  /// The state after the animation, kept until another source is selected.
  static const settled = SourceFx(halo: 1, rainbow: 1);
}

double _ease(Curve c, double a, double b, double t) =>
    a + (b - a) * c.transform(t.clamp(0.0, 1.0));

/// The row's look at controller value [v] (0..1). [replay] starts from the
/// resting halo instead of nothing (the same source was picked again).
SourceFx sourceFx(double v, {bool replay = false}) {
  var t = v * _total;
  if (t <= _lead) return replay ? SourceFx.settled : SourceFx.none;
  t -= _lead;
  final from = replay ? 1.0 : 0.0;
  if (t < _rise) {
    final e = Curves.easeOutCubic.transform(t / _rise);
    return SourceFx(
      fill: e,
      halo: from + (1 - from) * e,
      rainbow: from * (1 - e),
    );
  }
  t -= _rise;
  if (t < _dip) {
    final g = _ease(Curves.easeInOutSine, 1, 0.35, t / _dip);
    return SourceFx(fill: g, halo: g);
  }
  t -= _dip;
  if (t < _rise2) {
    final g = _ease(Curves.easeInOutSine, 0.35, 0.85, t / _rise2);
    return SourceFx(fill: g, halo: g);
  }
  t -= _rise2;
  if (t < _bloomMs) {
    final u = t / _bloomMs;
    return SourceFx(
      // The inside waits until the light has crossed the middle.
      fill: _ease(Curves.easeInOutCubic, 0.85, 0, (u - 0.25) / 0.75),
      halo: _ease(Curves.easeInOut, 0.85, 1, u),
      rainbow: Curves.easeInOut.transform(u),
      bloom: Curves.easeOutCubic.transform(u),
      bloomAlpha: math.sin(math.pi * u),
    );
  }
  return SourceFx.settled;
}

/// Where the flash timeline sits right after the start delay.
final sourceFlashSkipLead = _lead / _total;

/// Marker acknowledgement (spec §3.3): up 0-120ms, hold to 200ms, ease out to
/// 600ms.
const citeAckDuration = Duration(milliseconds: 600);
final citeAckCurve = TweenSequence<double>([
  TweenSequenceItem(tween: Tween(begin: 0.0, end: 1.0), weight: 120),
  TweenSequenceItem(tween: ConstantTween(1), weight: 80),
  TweenSequenceItem(
    tween: Tween(
      begin: 1.0,
      end: 0.0,
    ).chain(CurveTween(curve: Curves.easeOutCubic)),
    weight: 400,
  ),
]);

/// Five or more sources show three and fold the rest, once the answer is done.
const sourcesCollapseFrom = 5;
const sourcesCollapsedShow = 3;

/// Secondary text: dark `inkMuted` misses AA on the bubble, so dark uses ink
/// 75%.
Color subInkFor(Pb pb, {required bool dark}) =>
    dark ? pb.ink.withValues(alpha: 0.75) : pb.inkMuted;

Color subInk(BuildContext context) => subInkFor(
  context.pb,
  dark: Theme.of(context).brightness == Brightness.dark,
);

/// WCAG 2.x contrast ratio of two opaque colours (1..21).
double contrastRatio(Color a, Color b) {
  final la = a.computeLuminance(), lb = b.computeLuminance();
  return (math.max(la, lb) + 0.05) / (math.min(la, lb) + 0.05);
}

/// The `⚡n` pill: a neutral grey, the same for every number (no source or
/// kind tint), with a yellow bolt and an `ink` digit. Opaque so the pill reads
/// the same on any bubble colour.
Color citeMarkerFill({required bool dark}) =>
    dark ? const Color(0xFF4A4850) : const Color(0xFFE9E8E6);

/// The bolt only is yellow. Light uses a deepened amber: a lighter yellow is
/// under 1.7:1 on the light grey (this amber: 2.0, 1.8 picked) (3:1 would need a brown, so it is not met).
Color citeMarkerBolt({required bool dark}) =>
    dark ? const Color(0xFFFFD54A) : const Color(0xFFD99A00);

/// The picked number's pill: `ink` 5% over [fill], barely deeper.
Color citeMarkerPicked(Pb pb, Color fill) =>
    Color.alphaBlend(pb.ink.withValues(alpha: 0.05), fill);

/// The inline `⚡n` pill. The tap itself comes from the markdown package's
/// `asWidgetSpan` wrapper; this widget adds the look and hover/press/focus.
class CiteMarker extends StatefulWidget {
  const CiteMarker({
    super.key,
    required this.index,
    required this.height,
    required this.ack,
    required this.ackValue,
    required this.reduced,
    required this.selected,
    this.onTap,
  });

  final int index;
  final double height;

  /// Ticks while some marker is acknowledging or the pick changes; [ackValue]
  /// and [selected] are read on each tick (the markdown package does not
  /// rebuild the pill when its inputs change).
  final Listenable ack;
  final double Function() ackValue;
  final bool reduced;

  /// This number's source is the one currently picked: a slightly deeper fill.
  final bool Function() selected;
  final VoidCallback? onTap;

  @override
  State<CiteMarker> createState() => _CiteMarkerState();
}

class _CiteMarkerState extends State<CiteMarker> {
  bool _hover = false;
  bool _focus = false;
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    final pb = context.pb;
    final onPrimary = Theme.of(context).colorScheme.onPrimary;
    final base = Theme.of(context).textTheme.bodyMedium;
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Semantics(
      button: true,
      label: context.l.citeMarkerLabel(widget.index),
      excludeSemantics: true,
      onTap: widget.onTap,
      child: FocusableActionDetector(
        mouseCursor: SystemMouseCursors.click,
        onShowHoverHighlight: (v) => setState(() => _hover = v),
        onShowFocusHighlight: (v) => setState(() => _focus = v),
        actions: {
          ActivateIntent: CallbackAction<ActivateIntent>(
            onInvoke: (_) {
              widget.onTap?.call();
              return null;
            },
          ),
        },
        child: Listener(
          onPointerDown: (_) => setState(() => _down = true),
          onPointerUp: (_) => setState(() => _down = false),
          onPointerCancel: (_) => setState(() => _down = false),
          // The transparent 2px either side widens the hit area to ~34x18.
          child: ColoredBox(
            color: Colors.transparent,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              child: AnimatedBuilder(
                animation: widget.ack,
                builder: (context, _) {
                  final a = widget.ackValue();
                  var fill = citeMarkerFill(dark: dark);
                  if (widget.selected()) fill = citeMarkerPicked(pb, fill);
                  final tint = _down ? 0.24 : (_hover ? 0.12 : 0.0);
                  if (tint > 0) {
                    fill = Color.alphaBlend(
                      pb.accent.withValues(alpha: tint),
                      fill,
                    );
                  }
                  fill = Color.lerp(fill, pb.accent, a)!;
                  return Transform.scale(
                    scale: widget.reduced ? 1 : 1 + 0.08 * a,
                    child: DecoratedBox(
                      decoration: ShapeDecoration(
                        color: fill,
                        shape: StadiumBorder(
                          side: _focus
                              ? BorderSide(color: pb.accent, width: 2)
                              : BorderSide.none,
                        ),
                      ),
                      child: SizedBox(
                        height: widget.height,
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(4, 0, 6, 0),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                AppIcons.citationMarker,
                                size: 10,
                                color: Color.lerp(
                                  citeMarkerBolt(dark: dark),
                                  onPrimary,
                                  a,
                                ),
                              ),
                              const SizedBox(width: 2),
                              Text(
                                '${widget.index}',
                                textScaler: TextScaler.noScaling,
                                style: base?.copyWith(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  height: 1,
                                  letterSpacing: 0,
                                  decoration: TextDecoration.none,
                                  fontFeatures: const [
                                    FontFeature.tabularFigures(),
                                  ],
                                  color: Color.lerp(pb.ink, onPrimary, a),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// One source under an answer: number badge, title, kind · page, chevron.
/// [fx] is the selection look; the keyed [DecoratedBox] carries the glow as
/// `ShapeDecoration.shadows` (null when the row is not selected). The glow is
/// clipped away from the row's inside so the resting inside is exactly the
/// neutral `chipBg`; the kind shows only in the icon and the second line.
class SourceRow extends StatefulWidget {
  const SourceRow({
    super.key,
    required this.citation,
    required this.fx,
    required this.onTap,
  });

  final Citation citation;
  final SourceFx fx;
  final VoidCallback onTap;

  @override
  State<SourceRow> createState() => _SourceRowState();
}

class _SourceRowState extends State<SourceRow> {
  bool _hover = false;
  bool _down = false;
  bool _focus = false;

  @override
  Widget build(BuildContext context) {
    final pb = context.pb;
    final l = context.l;
    final c = widget.citation;
    final fx = widget.fx;
    final isNote = c.kind == 'note';
    final dark = Theme.of(context).brightness == Brightness.dark;
    final sub = subInkFor(pb, dark: dark);
    final radius = BorderRadius.circular(14);
    final shape = RoundedRectangleBorder(
      borderRadius: radius,
      side: _focus
          ? BorderSide(color: pb.accent, width: 2)
          : BorderSide(
              color: Color.lerp(
                pb.hairline,
                pb.accent.withValues(alpha: 0.55),
                fx.fill,
              )!,
            ),
    );
    final subtitle = isNote ? l.kindNote : '${l.kindPdf} · ${l.pageN(c.page)}';
    return Stack(
      // The halo spills over the row's edge; the stack must not clip it.
      clipBehavior: Clip.none,
      children: [
        Positioned.fill(
          child: IgnorePointer(
            child: ClipPath(
              clipper: const _OutsideClip(14),
              child: DecoratedBox(
                key: ValueKey('source-chip-${c.index}'),
                decoration: ShapeDecoration(
                  shape: RoundedRectangleBorder(borderRadius: radius),
                  shadows: _halo(pb, dark, fx),
                ),
              ),
            ),
          ),
        ),
        Semantics(
          button: true,
          label: l.sourceRowLabel(
            c.index,
            c.documentTitle,
            isNote: isNote,
            page: c.page,
          ),
          excludeSemantics: true,
          onTap: widget.onTap,
          child: Material(
            color: Color.lerp(pb.chipBg, pb.accentContainer, fx.fill),
            shape: shape,
            child: InkWell(
              customBorder: shape,
              onTap: widget.onTap,
              onHover: (v) => setState(() => _hover = v),
              onHighlightChanged: (v) => setState(() => _down = v),
              onFocusChange: (v) => setState(() => _focus = v),
              overlayColor: WidgetStateProperty.resolveWith((s) {
                if (s.contains(WidgetState.pressed)) {
                  return pb.accent.withValues(alpha: 0.14);
                }
                if (s.contains(WidgetState.hovered)) {
                  return pb.accent.withValues(alpha: 0.08);
                }
                return null;
              }),
              child: Stack(
                children: [
                  if (fx.bloomAlpha > 0)
                    Positioned.fill(
                      child: IgnorePointer(
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            borderRadius: radius,
                            gradient: _bloom(pb, dark, fx),
                          ),
                        ),
                      ),
                    ),
                  ConstrainedBox(
                    constraints: const BoxConstraints(minHeight: 44),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      child: Row(
                        children: [
                          _Badge(c.index),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  c.documentTitle,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: pb.ink,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Row(
                                  children: [
                                    Icon(
                                      isNote ? AppIcons.note : AppIcons.pdf,
                                      size: 14,
                                      color: sub,
                                    ),
                                    const SizedBox(width: 4),
                                    Flexible(
                                      child: Text(
                                        subtitle,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: sub,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Icon(
                            AppIcons.next,
                            size: 16,
                            color: _hover || _down ? pb.accent : sub,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Cool-spectrum halo. [SourceFx.rainbow] 0 is one purple glow (offset down
/// 2, as the old flash); 1 is four glows that stay within violet to sky blue
/// (hue -50..+12 from the accent, no pink, orange or yellow) and sit on
/// different sides of the row.
List<BoxShadow>? _halo(Pb pb, bool dark, SourceFx fx) {
  if (fx.halo <= 0) return null;
  final hsl = HSLColor.fromColor(pb.accent);
  const turn = [-50.0, -30.0, -10.0, 12.0]; // sky, blue, indigo, violet
  const at = [Offset(-7, 0), Offset(0, 6), Offset(7, 0), Offset(0, -5)];
  final r = fx.rainbow;
  final alpha = (dark ? 0.34 : 0.30) * fx.halo;
  return [
    for (var i = 0; i < 4; i++)
      BoxShadow(
        color: Color.lerp(
          pb.accent,
          hsl
              .withHue((hsl.hue + turn[i]) % 360)
              .withSaturation(dark ? 0.9 : 0.8)
              .withLightness(dark ? 0.74 : 0.62)
              .toColor(),
          r,
        )!.withValues(alpha: alpha * (0.4 + 0.6 * r) * (i == 3 ? 0.8 : 1)),
        blurRadius: 20,
        offset: Offset.lerp(const Offset(0, 2), at[i], r)!,
      ),
  ];
}

/// The light that spreads from the middle of the row (an ellipse, so it
/// reaches the long edges at the same time as the short ones).
RadialGradient _bloom(Pb pb, bool dark, SourceFx fx) {
  // Neutral white in both modes; only its strength differs.
  const c = Colors.white;
  final a = (dark ? 0.3 : 0.8) * fx.bloomAlpha;
  return RadialGradient(
    radius: 0.08 + 0.7 * fx.bloom,
    colors: [
      c.withValues(alpha: a),
      c.withValues(alpha: a * 0.5),
      c.withValues(alpha: 0),
    ],
    stops: const [0, 0.55, 1],
    transform: const _Ellipse(),
  );
}

class _Ellipse extends GradientTransform {
  const _Ellipse();

  @override
  Matrix4? transform(Rect bounds, {TextDirection? textDirection}) {
    final cx = bounds.center.dx;
    return Matrix4.translationValues(cx, 0, 0)
      ..multiply(Matrix4.diagonal3Values(bounds.width / bounds.height, 1, 1))
      ..multiply(Matrix4.translationValues(-cx, 0, 0));
  }
}

/// Everything except the row itself: the halo must not tint the inside.
class _OutsideClip extends CustomClipper<Path> {
  const _OutsideClip(this.radius);

  final double radius;

  @override
  Path getClip(Size size) => Path()
    ..fillType = PathFillType.evenOdd
    ..addRect((Offset.zero & size).inflate(80))
    ..addRRect(
      RRect.fromRectAndRadius(Offset.zero & size, Radius.circular(radius)),
    );

  @override
  bool shouldReclip(_OutsideClip old) => old.radius != radius;
}

class _Badge extends StatelessWidget {
  const _Badge(this.n);

  final int n;

  @override
  Widget build(BuildContext context) {
    final pb = context.pb;
    return Container(
      width: 22,
      height: 22,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: pb.accentContainer,
        shape: BoxShape.circle,
      ),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Text(
          '$n',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: pb.onAccentContainer,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
      ),
    );
  }
}

/// Divider, header (`⚡ SOURCES 3`), the rows in 1 or 2 columns and, from
/// [sourcesCollapseFrom] on, the "N more" toggle.
class SourcesList extends StatefulWidget {
  const SourcesList({
    super.key,
    required this.citations,
    required this.collapsible,
    required this.expanded,
    required this.snap,
    required this.onToggle,
    required this.rowBuilder,
  });

  final List<Citation> citations;

  /// Fold to [sourcesCollapsedShow] rows unless [expanded].
  final bool collapsible;
  final bool expanded;

  /// Expand/collapse without animating (a marker tap expands, then scrolls).
  final bool snap;
  final VoidCallback onToggle;
  final Widget Function(Citation c) rowBuilder;

  @override
  State<SourcesList> createState() => _SourcesListState();
}

class _SourcesListState extends State<SourcesList> {
  // The glow of a flashing row must not be clipped at rest; the size
  // animation clips while it runs so rows do not paint over what follows.
  bool _animating = false;

  @override
  void didUpdateWidget(SourcesList old) {
    super.didUpdateWidget(old);
    if (old.expanded != widget.expanded && !widget.snap) _animating = true;
  }

  @override
  Widget build(BuildContext context) {
    final pb = context.pb;
    final l = context.l;
    final all = widget.citations;
    final hidden = widget.collapsible && !widget.expanded
        ? all.length - sourcesCollapsedShow
        : 0;
    final shown = hidden > 0 ? all.take(sourcesCollapsedShow).toList() : all;
    final sub = subInk(context);
    final headStyle = Theme.of(context).textTheme.labelSmall?.copyWith(
      fontSize: 11,
      fontWeight: FontWeight.w600,
      letterSpacing: 0.8,
      color: sub,
    );
    final instant = widget.snap || MediaQuery.disableAnimationsOf(context);
    // 2 columns only when each row keeps >= 240px (inner >= 488).
    final grid = LayoutBuilder(
      builder: (context, box) {
        final cols = ((box.maxWidth + 8) / 248).floor().clamp(1, 2);
        final w = (box.maxWidth - 8 * (cols - 1)) / cols;
        return Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final c in shown)
              SizedBox(width: w, child: widget.rowBuilder(c)),
          ],
        );
      },
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 16),
        Divider(height: 1, thickness: 1, color: pb.hairline),
        const SizedBox(height: 12),
        MergeSemantics(
          child: Semantics(
            header: true,
            child: Row(
              children: [
                Icon(AppIcons.citation, size: 12, color: pb.accent),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    l.sourcesLabel.toUpperCase(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: headStyle,
                  ),
                ),
                const SizedBox(width: 8),
                Text('${all.length}', style: headStyle),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        // No AnimatedSize at all when instant: a zero duration re-dirties its
        // render object during its own layout.
        if (instant)
          grid
        else
          AnimatedSize(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOutCubic,
            alignment: Alignment.topCenter,
            clipBehavior: _animating ? Clip.hardEdge : Clip.none,
            onEnd: () {
              if (_animating && mounted) setState(() => _animating = false);
            },
            child: grid,
          ),
        if (widget.collapsible)
          Semantics(
            button: true,
            expanded: widget.expanded,
            label: widget.expanded ? l.lessSources : l.moreSources(hidden),
            excludeSemantics: true,
            onTap: widget.onToggle,
            child: Align(
              alignment: Alignment.centerLeft,
              child: InkWell(
                key: const ValueKey('sources-toggle'),
                borderRadius: BorderRadius.circular(8),
                onTap: widget.onToggle,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: 44),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Flexible(
                          child: Text(
                            widget.expanded
                                ? l.lessSources
                                : l.moreSources(hidden),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: pb.ink,
                            ),
                          ),
                        ),
                        const SizedBox(width: 4),
                        RotatedBox(
                          quarterTurns: widget.expanded ? 2 : 0,
                          child: Icon(AppIcons.expand, size: 16, color: pb.ink),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
