import 'package:flutter/material.dart';
import 'package:pageblink_client/pageblink_client.dart';

import '../../app/app_icons.dart';
import '../../app/l10n.dart';
import '../../app/theme.dart';

// Spec: docs/design/ask-sources/spec.md (inline marker, source rows, motion).

/// Row flash timeline (spec §3.2) behind a 160ms start delay: 1.0 -> 0.35 ->
/// 0.75 -> 0 over 1600ms. Evaluate with the controller value.
const sourceFlashLead = Duration(milliseconds: 160);
const sourceFlashDuration = Duration(milliseconds: 1760);
const sourceFlashReducedDuration = Duration(milliseconds: 1200);

final sourceFlashCurve = TweenSequence<double>([
  TweenSequenceItem(tween: ConstantTween(0), weight: 160),
  TweenSequenceItem(
    tween: Tween(
      begin: 0.0,
      end: 1.0,
    ).chain(CurveTween(curve: Curves.easeOutCubic)),
    weight: 280,
  ),
  TweenSequenceItem(
    tween: Tween(
      begin: 1.0,
      end: 0.35,
    ).chain(CurveTween(curve: Curves.easeInOutSine)),
    weight: 480,
  ),
  TweenSequenceItem(
    tween: Tween(
      begin: 0.35,
      end: 0.75,
    ).chain(CurveTween(curve: Curves.easeInOutSine)),
    weight: 300,
  ),
  TweenSequenceItem(
    tween: Tween(
      begin: 0.75,
      end: 0.0,
    ).chain(CurveTween(curve: Curves.easeInOutSine)),
    weight: 540,
  ),
]);

/// Where the flash timeline sits right after the start delay.
final sourceFlashSkipLead =
    sourceFlashLead.inMilliseconds / sourceFlashDuration.inMilliseconds;

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

/// Secondary text: dark `inkMuted` misses AA on the bubble, so dark uses ink 75%.
Color subInk(BuildContext context) {
  final pb = context.pb;
  return Theme.of(context).brightness == Brightness.dark
      ? pb.ink.withValues(alpha: 0.75)
      : pb.inkMuted;
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
    this.onTap,
  });

  final int index;
  final double height;

  /// Ticks while some marker is acknowledging; [ackValue] is read on each tick.
  final Listenable ack;
  final double Function() ackValue;
  final bool reduced;
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
                  var fill = pb.accentContainer;
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
                                color: Color.lerp(pb.accent, onPrimary, a),
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
                                  color: Color.lerp(
                                    pb.onAccentContainer,
                                    onPrimary,
                                    a,
                                  ),
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
/// [glow] is the flash value g in 0..1; the keyed [DecoratedBox] carries the
/// glow as `ShapeDecoration.shadows` (null at rest).
class SourceRow extends StatefulWidget {
  const SourceRow({
    super.key,
    required this.citation,
    required this.glow,
    required this.reduced,
    required this.onTap,
  });

  final Citation citation;
  final double glow;
  final bool reduced;
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
    final g = widget.glow;
    final isNote = c.kind == 'note';
    final sub = subInk(context);
    final dark = Theme.of(context).brightness == Brightness.dark;
    final radius = BorderRadius.circular(14);
    final shape = RoundedRectangleBorder(
      borderRadius: radius,
      side: _focus
          ? BorderSide(color: pb.accent, width: 2)
          : BorderSide(
              color: Color.lerp(
                pb.hairline,
                pb.accent.withValues(alpha: 0.55),
                g,
              )!,
            ),
    );
    final subtitle = isNote ? l.kindNote : '${l.kindPdf} · ${l.pageN(c.page)}';
    return DecoratedBox(
      key: ValueKey('source-chip-${c.index}'),
      decoration: ShapeDecoration(
        shape: RoundedRectangleBorder(borderRadius: radius),
        shadows: g == 0
            ? null
            : [
                BoxShadow(
                  color: pb.accent.withValues(alpha: (dark ? 0.38 : 0.30) * g),
                  blurRadius: widget.reduced ? 12 : 20,
                  offset: const Offset(0, 2),
                ),
              ],
      ),
      child: Semantics(
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
          color: Color.lerp(pb.chipBg, pb.accentContainer, g),
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
            child: ConstrainedBox(
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
                                size: 12,
                                color: sub,
                              ),
                              const SizedBox(width: 4),
                              Flexible(
                                child: Text(
                                  subtitle,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(fontSize: 12, color: sub),
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
          ),
        ),
      ),
    );
  }
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
