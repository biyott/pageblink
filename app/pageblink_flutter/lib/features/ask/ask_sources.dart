import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:pageblink_client/pageblink_client.dart';

import '../../app/app_icons.dart';
import '../../app/l10n.dart';
import '../../app/theme.dart';

// Spec: docs/design/ask-sources-v2/spec.md (slate pill with a filled yellow
// bolt, neutral rows, a rainbow outer glow that stays after the selection).

/// Row selection timeline (spec v2 §5.3): a 120ms start delay, then 1320ms in
/// four beats ending in a resting state that stays until another source is
/// picked (or a new turn starts). Total 1440ms.
///   rise    200ms  fill 0 -> 1, ring 0 -> 0.55          easeOutCubic
///   dip     340ms  fill 1 -> 0.35, ring 0.55 -> 0.30    easeInOutSine
///   rise2   220ms  fill 0.35 -> 0.85, ring 0.30 -> 0.60 easeInOutSine
///   settle  560ms  light from the centre; the inside goes back to the
///                  neutral row colour; the ring rises to 1.0 and the sweep
///                  turns from -50 degrees to 0
const sourceFlashLead = Duration(milliseconds: 120);
const sourceFlashDuration = Duration(milliseconds: 1440);

const _lead = 120.0,
    _rise = 200.0,
    _dip = 340.0,
    _rise2 = 220.0,
    _settle = 560.0;
const _total = _lead + _rise + _dip + _rise2 + _settle;

/// Share of the settle beat after which the centre light is fully out.
const _bloomEnd = 0.85;

/// The ring's start angle offset while it "rises" (-50 degrees).
const _sweepFrom = -50 * math.pi / 180;

/// What one source row shows.
class SourceFx {
  const SourceFx({
    this.fill = 0,
    this.halo = 0,
    this.sweep = 0,
    this.bloom = 0,
    this.bloomAlpha = 0,
  });

  /// Share of the inside that has moved from `rowFill` to `rowPulse` (one
  /// neutral grey step deeper); 0 = at rest. All values 0..1 except [sweep].
  final double fill;

  /// Strength of the rainbow ring (and its neutral shadow); 0 = nothing drawn.
  final double halo;

  /// Rotation of the ring's colours in radians; 0 = at rest.
  final double sweep;

  /// Radius progress and brightness of the centre-out light.
  final double bloom, bloomAlpha;

  static const none = SourceFx();

  /// The state after the animation, kept until another source is selected.
  static const settled = SourceFx(halo: 1);

  /// This look faded by [k] (1 = as is, 0 = gone), for the 200ms release.
  SourceFx faded(double k) => SourceFx(fill: fill * k, halo: halo * k);
}

double _ease(Curve c, double a, double b, double t) =>
    a + (b - a) * c.transform(t.clamp(0.0, 1.0));

/// The row's look at controller value [v] (0..1). [replay] keeps the ring at
/// 1.0 the whole time (the same source was picked again): only the inside and
/// the light play.
SourceFx sourceFx(double v, {bool replay = false}) {
  var t = v * _total;
  if (t <= _lead) return replay ? SourceFx.settled : SourceFx.none;
  t -= _lead;
  double ring(double x) => replay ? 1 : x;
  if (t < _rise) {
    final e = Curves.easeOutCubic.transform(t / _rise);
    return SourceFx(fill: e, halo: ring(0.55 * e));
  }
  t -= _rise;
  if (t < _dip) {
    return SourceFx(
      fill: _ease(Curves.easeInOutSine, 1, 0.35, t / _dip),
      halo: ring(_ease(Curves.easeInOutSine, 0.55, 0.30, t / _dip)),
    );
  }
  t -= _dip;
  if (t < _rise2) {
    return SourceFx(
      fill: _ease(Curves.easeInOutSine, 0.35, 0.85, t / _rise2),
      halo: ring(_ease(Curves.easeInOutSine, 0.30, 0.60, t / _rise2)),
    );
  }
  t -= _rise2;
  if (t < _settle) {
    final u = t / _settle;
    return SourceFx(
      // The inside waits until the light has crossed the middle.
      fill: _ease(Curves.easeInOutCubic, 0.85, 0, (u - 0.25) / 0.75),
      halo: ring(_ease(Curves.easeInOut, 0.60, 1, (u - 0.15) / 0.85)),
      sweep: replay ? 0 : _sweepFrom * (1 - Curves.easeInOut.transform(u)),
      bloom: Curves.easeOutCubic.transform(u),
      // The light is out by 85% of the settle, so the last 80ms show nothing
      // but the row's own colour coming back.
      bloomAlpha: math.sin(math.pi * math.min(1.0, u / _bloomEnd)),
    );
  }
  return SourceFx.settled;
}

/// Where the flash timeline sits right after the start delay.
final sourceFlashSkipLead = _lead / _total;

/// Fade-out of the previous pick's ring when another source is picked.
const sourceReleaseDuration = Duration(milliseconds: 200);

/// Share of [SourceFx] left [v] (0..1) into the release.
double sourceReleaseKeep(double v) => 1 - Curves.easeOut.transform(v);

/// Marker acknowledgement (spec §3.2): up 0-120ms, hold to 200ms, ease out to
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

/// WCAG 2.x contrast ratio of two opaque colours (1..21).
double contrastRatio(Color a, Color b) {
  final la = a.computeLuminance(), lb = b.computeLuminance();
  return (math.max(la, lb) + 0.05) / (math.min(la, lb) + 0.05);
}

/// Twelve pastel hues around the wheel (OKLCH, ~30 degrees apart; spec §5.1).
/// Never used as an inside fill, only for the ring.
const _rainbowLight = [
  Color(0xFFFE9FA6),
  Color(0xFFFEA47C),
  Color(0xFFFBC369),
  Color(0xFFEEE276),
  Color(0xFFA0DA8D),
  Color(0xFF70DCB6),
  Color(0xFF65D9DF),
  Color(0xFF6DCAF8),
  Color(0xFF9BBEFE),
  Color(0xFFBCADFE),
  Color(0xFFE2A3EC),
  Color(0xFFF69FC8),
];
const _rainbowDark = [
  Color(0xFFFFA9AF),
  Color(0xFFFEAE8B),
  Color(0xFFFCCB7E),
  Color(0xFFF2E88B),
  Color(0xFFACDE9B),
  Color(0xFF85E0BE),
  Color(0xFF7EDDE2),
  Color(0xFF82CFF7),
  Color(0xFFA5C5FE),
  Color(0xFFC2B5FD),
  Color(0xFFE4ADED),
  Color(0xFFF6A9CD),
];

/// The colours of the sources area (spec v2 §2). Kept here, not in `Pb`,
/// until they are promoted app-wide.
///
/// Light is the app's tile tone (`Pb.light.tile`, ink 8%: the same grey as the
/// tier icon tiles in the sidebar) with an ink digit and a yellow bolt that
/// carries a thin ink outline: a yellow fill cannot reach 3:1 on a pale grey
/// (spec §1), so the outline is what keeps the bolt readable (13:1).
@immutable
class SourceTones {
  const SourceTones({
    required this.pill,
    required this.digit,
    required this.bolt,
    required this.boltOutline,
    required this.headerBolt,
    required this.rowFill,
    required this.rowPulse,
    required this.rowBorder,
    required this.rowBorderSelected,
    required this.sub,
    required this.rowHover,
    required this.rowPress,
    required this.markerOverlay,
    required this.markerAlpha,
    required this.bloom,
    required this.bloomPeak,
    required this.rainbow,
    required this.ringTight,
    required this.ringWide,
    required this.shadow,
  });

  /// Marker pill and number badge; [digit] is the number on it and [bolt] the
  /// filled bolt on the pill.
  final Color pill, digit, bolt;

  /// Thin outline under the pill's bolt; null = none (dark: the slate is dark
  /// enough for the yellow fill to hold 3:1 on its own).
  final Color? boltOutline;

  /// The bolt of the `⚡ Sources N` header (sits on the bubble, decorative).
  final Color headerBolt;

  /// Row: face, one step deeper while pulsing, border, border when picked.
  final Color rowFill, rowPulse, rowBorder, rowBorderSelected;

  /// Secondary line, chevron, kind icon and header label.
  final Color sub;

  /// Row overlays on hover and press.
  final Color rowHover, rowPress;

  /// Pill overlay (darker the more it is pressed) and its strength per state.
  final Color markerOverlay;
  final ({double hover, double press, double picked, double ack}) markerAlpha;

  /// The centre-out light: a soft neutral highlight no brighter than its
  /// [bloomPeak] alpha lets the row become (never pure white at full alpha).
  /// Peak: about +6% white over `rowFill` in light, subtle in dark.
  final Color bloom;
  final double bloomPeak;

  /// Ring colours (12) and the alpha of its sharp and wide layers.
  final List<Color> rainbow;
  final double ringTight, ringWide;

  /// The one neutral shadow under a picked row.
  final Color shadow;

  /// The 12 colours and the first again, so the sweep closes.
  List<Color> get rainbowClosed => [...rainbow, rainbow.first];

  static const light = SourceTones(
    // The tile tone, kept translucent like `Pb.tile` so it reads the same on
    // the bubble (ink 8% over it = #EDEBEB, 1.17:1) and on a row face (the
    // number badge: #E1E2E4 on #F2F3F5, still a step darker than the row).
    // The ring painter clips out the pill's own shape and the overlay below
    // is plain source-over, so translucency changes nothing else. A test pins
    // this to `Pb.light.tile`. Digit and outline are `Pb.ink`: 14:1 at rest,
    // 8:1 at the strongest overlay (ack, black 24%). Bolt: yellow fill + ink
    // outline (the fill alone is 1.3:1, the outline is the shape).
    pill: Color(0x141F1B16),
    digit: Color(0xFF1F1B16),
    bolt: Color(0xFFFFCB2E),
    boltOutline: Color(0xFF1F1B16),
    headerBolt: Color(0xFFE3A500),
    rowFill: Color(0xFFF2F3F5),
    rowPulse: Color(0xFFE1E3E8),
    rowBorder: Color(0xFFDADDE3),
    rowBorderSelected: Color(0xFF858B96),
    sub: Color(0xFF555B67),
    rowHover: Color(0x0A1F1B16),
    rowPress: Color(0x141F1B16),
    markerOverlay: Color(0xFF000000),
    markerAlpha: (hover: 0.08, press: 0.16, picked: 0.14, ack: 0.24),
    bloom: Color(0xFFF4F4F8),
    bloomPeak: 0.5,
    rainbow: _rainbowLight,
    ringTight: 0.95,
    ringWide: 0.75,
    shadow: Color(0x0F000000),
  );

  static const dark = SourceTones(
    pill: Color(0xFF626874),
    digit: Color(0xFFFFFFFF),
    bolt: Color(0xFFFFD54A),
    boltOutline: null,
    headerBolt: Color(0xFFFFD54A),
    rowFill: Color(0x0FFFFFFF),
    rowPulse: Color(0x1AFFFFFF),
    rowBorder: Color(0x24FFFFFF),
    rowBorderSelected: Color(0xFFB4B9C4),
    sub: Color(0xFFD2D4DA),
    rowHover: Color(0x0FFFFFFF),
    rowPress: Color(0x1AFFFFFF),
    markerOverlay: Color(0xFF000000),
    markerAlpha: (hover: 0.08, press: 0.16, picked: 0.14, ack: 0.24),
    bloom: Color(0xFFFFFFFF),
    bloomPeak: 0.08,
    rainbow: _rainbowDark,
    ringTight: 0.85,
    ringWide: 0.60,
    shadow: Color(0x47000000),
  );

  static SourceTones of(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark ? dark : light;
}

/// A filled lightning bolt (Feather `zap` polygon on a 24 grid) with a round
/// 0.9px join in the same colour, so it keeps its mass at 11-12px where an
/// outline icon would be a hairline. [outline] (if any) is drawn underneath,
/// 0.75px wider all round.
class BoltPainter extends CustomPainter {
  const BoltPainter(this.color, {this.outline});

  final Color color;
  final Color? outline;

  static const _points = [
    Offset(13, 2),
    Offset(3, 14),
    Offset(12, 14),
    Offset(11, 22),
    Offset(21, 10),
    Offset(12, 10),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width / 24;
    final path = Path()..addPolygon([for (final p in _points) p * s], true);
    if (outline != null) {
      canvas.drawPath(
        path,
        Paint()
          ..color = outline!
          ..style = PaintingStyle.stroke
          ..strokeWidth = 0.9 + 1.5
          ..strokeJoin = StrokeJoin.round,
      );
    }
    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..style = PaintingStyle.fill,
    );
    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.9
        ..strokeJoin = StrokeJoin.round,
    );
  }

  @override
  bool shouldRepaint(BoltPainter old) =>
      old.color != color || old.outline != outline;
}

class _Bolt extends StatelessWidget {
  const _Bolt({required this.size, required this.color, this.outline});

  final double size;
  final Color color;
  final Color? outline;

  @override
  Widget build(BuildContext context) => SizedBox.square(
    dimension: size,
    child: CustomPaint(painter: BoltPainter(color, outline: outline)),
  );
}

/// A closed rainbow ring around a rounded rectangle: a [SweepGradient] stroke
/// drawn twice (wide and soft, then thin and sharp) with `MaskFilter.blur`.
/// [colors] is the 12 hues plus the first again. [strength] scales the alpha
/// (0 paints nothing); [sweep] rotates the colours in radians.
class RainbowRingPainter extends CustomPainter {
  const RainbowRingPainter({
    required this.colors,
    required this.strength,
    required this.tightAlpha,
    required this.wideAlpha,
    this.sweep = 0,
    this.radius = 14,
    this.tightWidth = 3.5,
    this.tightSigma = 1.3,
    this.wideWidth = 9,
    this.wideSigma = 3.0,
    this.clipInset,
  });

  final List<Color> colors;
  final double strength, sweep, tightAlpha, wideAlpha;
  final double radius, tightWidth, tightSigma, wideWidth, wideSigma;

  /// Paint only this far outside the shape (the markers: the glow must not
  /// reach the neighbouring lines). null = no clip, the caller clips.
  final double? clipInset;

  @override
  void paint(Canvas canvas, Size size) {
    if (strength <= 0) return;
    final rect = Offset.zero & size;
    final rr = RRect.fromRectAndRadius(
      rect,
      Radius.circular(math.min(radius, size.shortestSide / 2)),
    );
    if (clipInset != null) {
      canvas.clipPath(
        Path()
          ..fillType = PathFillType.evenOdd
          ..addRect(rect.inflate(clipInset!))
          ..addRRect(rr),
      );
    }
    void layer(double width, double sigma, double alpha) {
      final a = (alpha * strength).clamp(0.0, 1.0);
      canvas.drawRRect(
        rr,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = width
          ..shader = SweepGradient(
            colors: [for (final c in colors) c.withValues(alpha: a)],
            transform: GradientRotation(sweep),
          ).createShader(rect)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, sigma),
      );
    }

    layer(wideWidth, wideSigma, wideAlpha);
    layer(tightWidth, tightSigma, tightAlpha);
  }

  @override
  bool shouldRepaint(RainbowRingPainter o) =>
      o.strength != strength ||
      o.sweep != sweep ||
      o.colors != colors ||
      o.tightAlpha != tightAlpha ||
      o.wideAlpha != wideAlpha ||
      o.wideWidth != wideWidth ||
      o.wideSigma != wideSigma;
}

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
    required this.pick,
    this.onTap,
  });

  final int index;
  final double height;

  /// Ticks while some marker is acknowledging, the pick changes or a pick is
  /// fading; [ackValue], [selected] and [pick] are read on each tick (the
  /// markdown package does not rebuild the pill when its inputs change).
  final Listenable ack;
  final double Function() ackValue;
  final bool reduced;

  /// This number's source is the one currently picked (semantics).
  final bool Function() selected;

  /// How much of the picked look this pill shows, 0..1: 1 while picked, fading
  /// to 0 over the 200ms release.
  final double Function() pick;
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
    final tones = SourceTones.of(context);
    final base = Theme.of(context).textTheme.bodyMedium;
    final label = context.l.citeMarkerLabel(widget.index);
    return AnimatedBuilder(
      animation: widget.ack,
      builder: (context, _) {
        final a = widget.ackValue();
        final pick = widget.pick();
        final m = tones.markerAlpha;
        final overlay = math.max(
          _down ? m.press : (_hover ? m.hover : 0.0),
          math.max(m.picked * pick, m.ack * a),
        );
        final ring = math.max(0.65 * pick, a);
        return Semantics(
          button: true,
          selected: widget.selected(),
          label: label,
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
                  child: Transform.scale(
                    scale: widget.reduced ? 1 : 1 + 0.08 * a,
                    // The ring is painted behind the pill by a painter, not
                    // laid out: picking never moves the line.
                    child: CustomPaint(
                      painter: RainbowRingPainter(
                        colors: tones.rainbowClosed,
                        strength: ring,
                        tightAlpha: tones.ringTight,
                        wideAlpha: tones.ringWide,
                        radius: 999,
                        tightWidth: 1.8,
                        tightSigma: 0.6,
                        wideWidth: 4.5 + a,
                        wideSigma: 1.3 + 0.5 * a,
                        clipInset: 5,
                      ),
                      child: DecoratedBox(
                        decoration: ShapeDecoration(
                          color: Color.alphaBlend(
                            tones.markerOverlay.withValues(alpha: overlay),
                            tones.pill,
                          ),
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
                                _Bolt(
                                  size: 11,
                                  color: tones.bolt,
                                  outline: tones.boltOutline,
                                ),
                                const SizedBox(width: 2),
                                Text(
                                  '${widget.index}',
                                  textScaler: TextScaler.noScaling,
                                  style: base?.copyWith(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    height: 1,
                                    letterSpacing: 0,
                                    decoration: TextDecoration.none,
                                    fontFeatures: const [
                                      FontFeature.tabularFigures(),
                                    ],
                                    color: tones.digit,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// How far the ring may spill sideways: 12px in one column, 8px in two (the
/// gap between the columns). [SourcesList] sets it per row.
class _RingInset extends InheritedWidget {
  const _RingInset({required this.horizontal, required super.child});

  final double horizontal;

  static double of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<_RingInset>()?.horizontal ??
      12;

  @override
  bool updateShouldNotify(_RingInset old) => old.horizontal != horizontal;
}

/// One source under an answer: number badge, title, kind · page, chevron.
/// [fx] is the selection look. A keyed [DecoratedBox] (`source-chip-n`) carries
/// one neutral shadow as `ShapeDecoration.shadows` (null when the row is not
/// selected) and, inside it, a [RepaintBoundary] with the rainbow ring
/// (`source-ring-n`). Both are clipped away from the row's inside, 8px
/// vertically and 12px sideways at most, so the inside stays exactly the
/// neutral `rowFill` and a neighbour is never painted over.
class SourceRow extends StatefulWidget {
  const SourceRow({
    super.key,
    required this.citation,
    required this.fx,
    required this.onTap,
    this.selected = false,
  });

  final Citation citation;
  final SourceFx fx;
  final VoidCallback onTap;

  /// This is the picked source (semantics; set at once on tap).
  final bool selected;

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
    final tones = SourceTones.of(context);
    final l = context.l;
    final c = widget.citation;
    final fx = widget.fx;
    final isNote = c.kind == 'note';
    final sub = tones.sub;
    final radius = BorderRadius.circular(14);
    // The picked row's border (the 3:1 state signal) stays after the glow.
    final picked = math.max(fx.fill, fx.halo).clamp(0.0, 1.0);
    final shape = RoundedRectangleBorder(
      borderRadius: radius,
      side: _focus
          ? BorderSide(color: pb.accent, width: 2)
          : BorderSide(
              color: Color.lerp(
                tones.rowBorder,
                tones.rowBorderSelected,
                picked,
              )!,
            ),
    );
    final subtitle = isNote ? l.kindNote : '${l.kindPdf} · ${l.pageN(c.page)}';
    return Stack(
      // The ring spills over the row's edge; the stack must not clip it.
      clipBehavior: Clip.none,
      children: [
        Positioned.fill(
          child: IgnorePointer(
            child: ClipPath(
              clipper: _OutsideClip(14, horizontal: _RingInset.of(context)),
              child: DecoratedBox(
                key: ValueKey('source-chip-${c.index}'),
                decoration: ShapeDecoration(
                  shape: RoundedRectangleBorder(borderRadius: radius),
                  shadows: fx.halo <= 0
                      ? null
                      : [
                          BoxShadow(
                            color: tones.shadow.withValues(
                              alpha: tones.shadow.a * fx.halo,
                            ),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                ),
                child: fx.halo <= 0
                    ? null
                    : RepaintBoundary(
                        child: CustomPaint(
                          key: ValueKey('source-ring-${c.index}'),
                          painter: RainbowRingPainter(
                            colors: tones.rainbowClosed,
                            strength: fx.halo,
                            sweep: fx.sweep,
                            tightAlpha: tones.ringTight,
                            wideAlpha: tones.ringWide,
                          ),
                        ),
                      ),
              ),
            ),
          ),
        ),
        Semantics(
          button: true,
          selected: widget.selected,
          label: l.sourceRowLabel(
            c.index,
            c.documentTitle,
            isNote: isNote,
            page: c.page,
          ),
          excludeSemantics: true,
          onTap: widget.onTap,
          child: Material(
            color: Color.lerp(tones.rowFill, tones.rowPulse, fx.fill),
            shape: shape,
            child: InkWell(
              customBorder: shape,
              onTap: widget.onTap,
              onHover: (v) => setState(() => _hover = v),
              onHighlightChanged: (v) => setState(() => _down = v),
              onFocusChange: (v) => setState(() => _focus = v),
              overlayColor: WidgetStateProperty.resolveWith((s) {
                if (s.contains(WidgetState.pressed)) return tones.rowPress;
                if (s.contains(WidgetState.hovered)) return tones.rowHover;
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
                            gradient: _bloom(tones, fx),
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

/// The light that spreads from the middle of the row (an ellipse, so it
/// reaches the long edges at the same time as the short ones). Soft and
/// capped: it only lifts the pulse back towards the row's own colour and is
/// at 0 before the settle ends, so the end state is exactly `rowFill`.
RadialGradient _bloom(SourceTones tones, SourceFx fx) {
  final a = tones.bloomPeak * fx.bloomAlpha;
  final c = tones.bloom;
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

/// Everything except the row itself, up to 8px above and below and
/// [horizontal]px either side: the glow must not tint the inside, and must
/// stay inside the 8px gap to the next row.
class _OutsideClip extends CustomClipper<Path> {
  const _OutsideClip(this.radius, {this.horizontal = 12});

  final double radius, horizontal;

  static const vertical = 8.0;

  @override
  Path getClip(Size size) => Path()
    ..fillType = PathFillType.evenOdd
    ..addRect(
      Rect.fromLTRB(
        -horizontal,
        -vertical,
        size.width + horizontal,
        size.height + vertical,
      ),
    )
    ..addRRect(
      RRect.fromRectAndRadius(Offset.zero & size, Radius.circular(radius)),
    );

  @override
  bool shouldReclip(_OutsideClip old) =>
      old.radius != radius || old.horizontal != horizontal;
}

class _Badge extends StatelessWidget {
  const _Badge(this.n);

  final int n;

  @override
  Widget build(BuildContext context) {
    final tones = SourceTones.of(context);
    return Container(
      width: 22,
      height: 22,
      alignment: Alignment.center,
      decoration: BoxDecoration(color: tones.pill, shape: BoxShape.circle),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Text(
          '$n',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: tones.digit,
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
  // The ring of a picked row must not be clipped at rest; the size
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
    final tones = SourceTones.of(context);
    final sub = tones.sub;
    final headStyle = Theme.of(context).textTheme.labelSmall?.copyWith(
      fontSize: 12,
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
              SizedBox(
                width: w,
                child: _RingInset(
                  horizontal: cols == 2 ? 8 : 12,
                  child: widget.rowBuilder(c),
                ),
              ),
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
                // Decorative: the label carries the meaning.
                ExcludeSemantics(
                  child: _Bolt(size: 12, color: tones.headerBolt),
                ),
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
