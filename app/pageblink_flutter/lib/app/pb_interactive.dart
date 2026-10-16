import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'theme.dart';

// Interaction states: docs/design/ui-polish/spec.md §5.3 and the a11y state
// spec (focus ring = 2px neutral `ink`, 2px gap, keyboard only; hover 6%,
// pressed 12%; 120ms, instant with `disableAnimations`).

/// Desktop pointer layout (>= 1024 px): 36 px targets are fine there. Below
/// it (phone, tablet) every target is 44 px or more.
bool pbDesktop(BuildContext context) =>
    MediaQuery.sizeOf(context).width >= 1024;

/// Smallest target side for the current layout.
double pbTarget(BuildContext context) => pbDesktop(context) ? 36 : 44;

/// Targets follow the layout: below 1024 px (phone, tablet) Material controls
/// are 44-48 px (padded, standard density); the desktop pointer layout is one
/// density step under standard, 36 px (Material's `compact` is two steps and
/// gives 32). Wrap the app (`MaterialApp.builder`) in this.
Widget pbAdaptiveTargets(BuildContext context, Widget child) {
  final desktop = pbDesktop(context);
  return Theme(
    data: Theme.of(context).copyWith(
      materialTapTargetSize: desktop
          ? MaterialTapTargetSize.shrinkWrap
          : MaterialTapTargetSize.padded,
      visualDensity: desktop
          ? const VisualDensity(horizontal: -1, vertical: -1)
          : VisualDensity.standard,
    ),
    child: child,
  );
}

/// Colour/size transitions of the interaction states.
Duration pbFast(BuildContext context) => MediaQuery.disableAnimationsOf(context)
    ? Duration.zero
    : const Duration(milliseconds: 120);

/// Whether a ring should show at all right now: keyboard modality only. A
/// mouse click never moves focus to a button, and a tap switches to touch.
bool get pbKeyboardMode =>
    FocusManager.instance.highlightMode == FocusHighlightMode.traditional;

/// [PbContext.pb], or the plain light/dark tokens under a theme without them
/// (tests build screens in a stock MaterialApp).
Pb _pb(BuildContext context) {
  final t = Theme.of(context);
  return t.extension<Pb>() ??
      (t.brightness == Brightness.dark ? Pb.dark : Pb.light);
}

double _ringWidth(BuildContext context) =>
    MediaQuery.highContrastOf(context) ? 3 : 2;

/// The ring: [offset] px of gap, then a [width] px stroke around the box,
/// drawn outside it (nothing is laid out, the child keeps its size). The ring
/// follows the control's own [radius] (a pill passes a big one).
class PbRingPainter extends CustomPainter {
  const PbRingPainter({
    required this.visible,
    required this.color,
    required this.radius,
    this.offset = 2,
    this.width = 2,
  });

  final bool visible;
  final Color color;
  final double radius, offset, width;

  @override
  void paint(Canvas canvas, Size size) {
    if (!visible) return;
    final d = offset + width / 2;
    final r = math.min(radius, size.shortestSide / 2) + d;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        (Offset.zero & size).inflate(d),
        Radius.circular(r),
      ),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = width
        ..color = color,
    );
  }

  @override
  bool shouldRepaint(PbRingPainter o) =>
      o.visible != visible ||
      o.color != color ||
      o.radius != radius ||
      o.offset != offset ||
      o.width != width;
}

/// Key of the [CustomPaint] that carries the ring; its `foregroundPainter` is
/// a [PbRingPainter] whose `visible` says whether the ring shows.
const pbFocusRingKey = ValueKey('pb-focus-ring');

/// Draws the keyboard focus ring around [child] while the focusable inside it
/// has focus. Wrap an existing button, card or row (the Material ones keep
/// their own ink); [PbInteractive] has the same ring built in.
///
/// Without [focusNode] the ring shows when the child's own focus node (the
/// direct one, so a button inside a card does not light the card's ring) is
/// the primary focus, and only in keyboard mode. With a [focusNode] (a text
/// field, which shows focus whatever the input was) it follows that node;
/// [always] drops the keyboard-mode condition.
class PbFocusRing extends StatefulWidget {
  const PbFocusRing({
    super.key,
    required this.child,
    this.radius = 12,
    this.focusNode,
    this.always = false,
  });

  final Widget child;
  final double radius;
  final FocusNode? focusNode;
  final bool always;

  @override
  State<PbFocusRing> createState() => _PbFocusRingState();
}

class _PbFocusRingState extends State<PbFocusRing> {
  late FocusNode _node;
  bool _on = false;
  bool _kbd = pbKeyboardMode;

  /// Whether [_node] is ours (made in [_bind]) or the caller's.
  bool _own = true;

  @override
  void initState() {
    super.initState();
    _bind();
    FocusManager.instance.addHighlightModeListener(_mode);
  }

  void _bind() {
    _own = widget.focusNode == null;
    _node =
        widget.focusNode ??
        FocusNode(
          canRequestFocus: false,
          skipTraversal: true,
          debugLabel: 'PbFocusRing',
        );
    _node.addListener(_changed);
    // The primary focus moving from the control to something inside it does
    // not change this node's own hasFocus, so the manager is listened to.
    FocusManager.instance.addListener(_changed);
    _on = _compute();
  }

  void _unbind() {
    _node.removeListener(_changed);
    FocusManager.instance.removeListener(_changed);
    if (_own) _node.dispose();
  }

  @override
  void didUpdateWidget(PbFocusRing old) {
    super.didUpdateWidget(old);
    if (old.focusNode != widget.focusNode) {
      _unbind(); // disposes the node only when it was ours
      _bind();
    }
  }

  @override
  void dispose() {
    FocusManager.instance.removeHighlightModeListener(_mode);
    _unbind();
    super.dispose();
  }

  bool _compute() => _own
      ? _node.hasFocus && FocusManager.instance.primaryFocus?.parent == _node
      : _node.hasFocus;

  void _changed() {
    final on = _compute();
    if (on != _on && mounted) setState(() => _on = on);
  }

  void _mode(FocusHighlightMode m) {
    final kbd = m == FocusHighlightMode.traditional;
    if (kbd != _kbd && mounted) setState(() => _kbd = kbd);
  }

  @override
  Widget build(BuildContext context) {
    final painted = CustomPaint(
      key: pbFocusRingKey,
      foregroundPainter: PbRingPainter(
        visible: _on && (_kbd || widget.always),
        color: _pb(context).focusRing,
        radius: widget.radius,
        width: _ringWidth(context),
      ),
      child: widget.child,
    );
    if (!_own) return painted;
    return Focus(
      focusNode: _node,
      canRequestFocus: false,
      skipTraversal: true,
      includeSemantics: false,
      child: painted,
    );
  }
}

/// A 80 ms scale-down while a pointer is held on [child] (pressed feedback
/// for small controls; 0.97 for pills and icons, 0.985 for cards). Not with
/// reduced motion.
class PbPressScale extends StatefulWidget {
  const PbPressScale({super.key, required this.child, this.scale = 0.97});

  final Widget child;
  final double scale;

  @override
  State<PbPressScale> createState() => _PbPressScaleState();
}

class _PbPressScaleState extends State<PbPressScale> {
  bool _down = false;

  void _set(bool v) {
    if (_down != v && mounted) setState(() => _down = v);
  }

  @override
  Widget build(BuildContext context) {
    final reduced = MediaQuery.disableAnimationsOf(context);
    return Listener(
      onPointerDown: (_) => _set(true),
      onPointerUp: (_) => _set(false),
      onPointerCancel: (_) => _set(false),
      child: AnimatedScale(
        scale: _down && !reduced ? widget.scale : 1,
        duration: reduced ? Duration.zero : const Duration(milliseconds: 80),
        curve: Curves.easeOut,
        child: widget.child,
      ),
    );
  }
}

/// Outer ring as a button shape, for the filled buttons the theme restyles
/// (a ring on a violet fill would have to sit inside it; this one sits
/// outside, so it does not matter what colour the control is). Geometry,
/// side and everything else is [base]'s.
class PbRingBorder extends OutlinedBorder {
  const PbRingBorder(this.base, this.color, {this.offset = 2, this.width = 2});

  final OutlinedBorder base;
  final Color color;
  final double offset, width;

  @override
  BorderSide get side => base.side;

  @override
  OutlinedBorder copyWith({BorderSide? side}) => PbRingBorder(
    base.copyWith(side: side),
    color,
    offset: offset,
    width: width,
  );

  @override
  EdgeInsetsGeometry get dimensions => base.dimensions;

  @override
  Path getInnerPath(Rect rect, {TextDirection? textDirection}) =>
      base.getInnerPath(rect, textDirection: textDirection);

  @override
  Path getOuterPath(Rect rect, {TextDirection? textDirection}) =>
      base.getOuterPath(rect, textDirection: textDirection);

  @override
  void paint(Canvas canvas, Rect rect, {TextDirection? textDirection}) {
    base.paint(canvas, rect, textDirection: textDirection);
    final d = offset + width / 2;
    final radius = base is RoundedRectangleBorder
        ? (base as RoundedRectangleBorder).borderRadius
              .resolve(textDirection)
              .toRRect(rect)
              .tlRadius
              .x
        : rect.shortestSide / 2; // stadium, circle
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        rect.inflate(d),
        Radius.circular(math.min(radius, rect.shortestSide / 2) + d),
      ),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = width
        ..color = color,
    );
  }

  @override
  ShapeBorder scale(double t) => PbRingBorder(
    base.scale(t) as OutlinedBorder,
    color,
    offset: offset,
    width: width,
  );

  @override
  bool operator ==(Object other) =>
      other is PbRingBorder &&
      other.base == base &&
      other.color == color &&
      other.offset == offset &&
      other.width == width;

  @override
  int get hashCode => Object.hash(base, color, offset, width);
}

typedef PbStateBuilder =
    Widget Function(BuildContext context, Set<WidgetState> states);

/// One wrapper for the custom controls made of plain containers (the Ask
/// pills, the sources toggle, example questions, the sidebar items). The
/// states are drawn by [builder] into its own `decoration` (see [pbTint]), so
/// no translucent face between the control and a `Material` can hide them,
/// which is what made an `InkWell` there look dead.
///
/// - hover from a `MouseRegion` (not the focus detector, which only reports
///   it in keyboard mode: a tablet with a mouse would see none), click cursor
/// - pressed from the pointer, with a 0.97 scale (not with reduced motion)
/// - focus: the ring, in keyboard mode only; Enter / Space run [onTap]
/// - semantics: button, enabled, [selected], [expanded]; with a [label] it
///   replaces what [builder] draws (no double reading), without one the
///   drawn text is the name
/// - [onTap] null = disabled: basic cursor, no states, not focusable
///
/// [minHit] is the hit area (transparent beyond the drawn control); the ring
/// follows the drawn control, not the hit area.
class PbInteractive extends StatefulWidget {
  const PbInteractive({
    super.key,
    required this.builder,
    required this.onTap,
    this.radius = 12,
    this.pressScale = 0.97,
    this.minHit = const Size(44, 44),
    this.expand = false,
    this.selected = false,
    this.expanded,
    this.label,
    this.focusNode,
  });

  final PbStateBuilder builder;
  final VoidCallback? onTap;
  final double radius, pressScale;
  final Size minHit;

  /// Fill the width the parent gives (a card) instead of hugging the content.
  final bool expand;
  final bool selected;

  /// Menus and disclosures: the open / closed state for the screen reader.
  final bool? expanded;
  final String? label;
  final FocusNode? focusNode;

  @override
  State<PbInteractive> createState() => _PbInteractiveState();
}

class _PbInteractiveState extends State<PbInteractive> {
  bool _hover = false, _focus = false, _down = false;

  void _set(void Function() f) {
    if (mounted) setState(f);
  }

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onTap != null;
    final reduced = MediaQuery.disableAnimationsOf(context);
    final states = <WidgetState>{
      if (!enabled) WidgetState.disabled,
      if (enabled && _hover) WidgetState.hovered,
      if (enabled && _focus) WidgetState.focused,
      if (enabled && _down) WidgetState.pressed,
      if (widget.selected) WidgetState.selected,
    };
    var visual = widget.builder(context, states);
    if (widget.label != null) visual = ExcludeSemantics(child: visual);
    final ring = CustomPaint(
      key: pbFocusRingKey,
      foregroundPainter: PbRingPainter(
        visible: _focus && enabled,
        color: _pb(context).focusRing,
        radius: widget.radius,
        width: _ringWidth(context),
      ),
      child: visual,
    );
    final scaled = AnimatedScale(
      scale: _down && !reduced ? widget.pressScale : 1,
      duration: reduced ? Duration.zero : const Duration(milliseconds: 80),
      curve: Curves.easeOut,
      child: ring,
    );
    final hit = ConstrainedBox(
      constraints: BoxConstraints(
        minWidth: widget.minHit.width,
        minHeight: widget.minHit.height,
      ),
      child: widget.expand
          ? scaled
          : Center(widthFactor: 1, heightFactor: 1, child: scaled),
    );
    return Semantics(
      button: true,
      enabled: enabled,
      selected: widget.selected,
      expanded: widget.expanded,
      label: widget.label,
      // No onTap here: the GestureDetector below already adds the tap action,
      // and two taps make the configs incompatible, which splits one control
      // into two semantics nodes (a button, and an empty focusable inside).
      child: FocusableActionDetector(
        enabled: enabled,
        focusNode: widget.focusNode,
        // Hover is NOT taken from onShowHoverHighlight: the detector reports
        // it only in keyboard mode. The MouseRegion below has no such gate.
        onShowFocusHighlight: (v) => _set(() => _focus = v),
        actions: {
          ActivateIntent: CallbackAction<ActivateIntent>(
            onInvoke: (_) {
              widget.onTap?.call();
              return null;
            },
          ),
        },
        child: MouseRegion(
          cursor: enabled ? SystemMouseCursors.click : SystemMouseCursors.basic,
          onEnter: (_) => _set(() => _hover = true),
          onExit: (_) => _set(() => _hover = false),
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapDown: enabled ? (_) => _set(() => _down = true) : null,
            onTapUp: (_) => _set(() => _down = false),
            onTapCancel: () => _set(() => _down = false),
            onTap: widget.onTap,
            child: hit,
          ),
        ),
      ),
    );
  }
}

/// The state tint of a [PbInteractive] face: nothing at rest, `hover` /
/// `press` over it. Blend it onto the face colour (`Color.alphaBlend`) or use
/// it as the face itself when the face is clear. [filled] = a violet fill,
/// where a dark tint keeps the white text readable. [pressed] shows the
/// pressed look without a press (an open menu).
Color pbTint(
  Pb pb,
  Set<WidgetState> states, {
  bool filled = false,
  bool pressed = false,
  Color? hover,
}) {
  if (states.contains(WidgetState.disabled)) return Colors.transparent;
  if (pressed || states.contains(WidgetState.pressed)) {
    return filled ? pb.filledPress : pb.press;
  }
  if (states.contains(WidgetState.hovered)) {
    return filled ? pb.filledHover : (hover ?? pb.hover);
  }
  return Colors.transparent;
}

/// Opens a popup menu over [anchor] (the drawn control of a [PbInteractive]),
/// the way [PopupMenuButton] does. The control is a [PbInteractive] so that
/// its own states are visible; a [PopupMenuButton] around it would put its
/// ink under the control's face and a second tab stop on it.
///
/// [constraints] (e.g. a tight width) replace the menu's default 112-280 px.
/// [below] opens it under the control instead of over it; with
/// [alignEnd] and a tight width in [constraints] its right edge lines up with
/// the control's (the screen edge still wins).
Future<T?> pbShowMenu<T>(
  BuildContext context,
  GlobalKey anchor,
  List<PopupMenuEntry<T>> items, {
  BoxConstraints? constraints,
  bool below = false,
  bool alignEnd = false,
}) async {
  final box = anchor.currentContext?.findRenderObject();
  final overlay = Navigator.of(context).overlay?.context.findRenderObject();
  if (box is! RenderBox || overlay is! RenderBox) return null;
  final topLeft = box.localToGlobal(Offset.zero, ancestor: overlay);
  final bottomRight = box.localToGlobal(
    box.size.bottomRight(Offset.zero),
    ancestor: overlay,
  );
  final left = alignEnd && constraints != null && constraints.hasTightWidth
      ? bottomRight.dx - constraints.maxWidth
      : topLeft.dx;
  return showMenu<T>(
    context: context,
    position: RelativeRect.fromRect(
      Rect.fromPoints(
        Offset(left, below ? bottomRight.dy + 4 : topLeft.dy),
        Offset(bottomRight.dx, below ? bottomRight.dy + 4 : bottomRight.dy),
      ),
      Offset.zero & overlay.size,
    ),
    items: items,
    constraints: constraints,
  );
}
