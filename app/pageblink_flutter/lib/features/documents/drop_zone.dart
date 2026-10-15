import 'dart:math' as math;

import 'package:desktop_drop/desktop_drop.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:pageblink_client/pageblink_client.dart';

import '../../app/app_icons.dart';
import '../../app/l10n.dart';
import '../../app/theme.dart';
import 'tier_sheet.dart';
import 'upload_controller.dart';
import 'upload_service.dart';

/// Phones and tablets with touch have no file drag (ADR 019): no overlay,
/// the "Upload PDF" button is the only way in.
bool get isTouchPlatform => switch (defaultTargetPlatform) {
  TargetPlatform.android ||
  TargetPlatform.iOS ||
  TargetPlatform.fuchsia => true,
  _ => false,
};

/// The one place drag-and-drop is detected: wrap the whole shell (ADR 019).
///
/// Web: `desktop_drop`'s web plugin installs `window.ondragenter/over/leave/
/// drop` with `preventDefault()` as soon as it is registered (0.8.4
/// `desktop_drop_web.dart` `_registerEvents`), so the browser never opens a
/// dropped PDF, wherever it lands in the window. Nothing else is needed.
class UploadDropHost extends StatefulWidget {
  const UploadDropHost({
    super.key,
    required this.controller,
    required this.projects,
    required this.child,
    this.paneKey,
    @visibleForTesting this.touch,
  });

  final UploadController controller;
  final ValueListenable<List<Project>> projects;

  /// The pane the zone covers; a position inside it (12 px grown) is "Over".
  /// Null or not laid out = the whole window is the pane.
  final GlobalKey? paneKey;
  final Widget child;
  final bool? touch;

  @override
  State<UploadDropHost> createState() => _UploadDropHostState();
}

class _UploadDropHostState extends State<UploadDropHost> {
  /// A second drop while the target sheet is up is ignored.
  bool _choosing = false;

  bool get _touch => widget.touch ?? isTouchPlatform;

  @override
  void initState() {
    super.initState();
    _wire();
  }

  @override
  void didUpdateWidget(UploadDropHost old) {
    super.didUpdateWidget(old);
    if (old.controller != widget.controller) {
      old.controller.onBatchDone = null;
      _wire();
    }
  }

  void _wire() {
    widget.controller
      ..dropEnabled = !_touch
      ..onBatchDone = _summary;
  }

  @override
  void dispose() {
    widget.controller.onBatchDone = null;
    super.dispose();
  }

  /// One snackbar per batch, whichever screen is up.
  void _summary(UploadReport report) {
    if (!mounted) return;
    final text = uploadSummary(context.l, report);
    if (text.isEmpty) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(text)));
  }

  bool _inPane(Offset global) {
    final box = widget.paneKey?.currentContext?.findRenderObject();
    if (box is! RenderBox || !box.attached || !box.hasSize) return true;
    return (Offset.zero & box.size)
        .inflate(12)
        .contains(box.globalToLocal(global));
  }

  void _hover(DropEventDetails d) =>
      widget.controller.drop.hover(inZone: _inPane(d.globalPosition));

  Future<void> _done(DropDoneDetails details) async {
    widget.controller.drop.reset();
    if (_choosing || details.files.isEmpty) return;
    final pdfs = <PickedPdf>[];
    final rejected = <RejectedFile>[];
    for (final item in details.files) {
      final name = item.name.isNotEmpty ? item.name : item.path;
      if (item is DropItemDirectory) {
        rejected.add(RejectedFile(name, isFolder: true));
      } else if (!name.toLowerCase().endsWith('.pdf')) {
        rejected.add(RejectedFile(name));
      } else {
        int? size;
        try {
          size = await item.length();
        } catch (_) {
          // Unknown size: the service reads the file and checks it then.
        }
        pdfs.add(PickedPdf(name: name, size: size, read: item.readAsBytes));
      }
    }
    if (!mounted) return;
    int? projectId;
    final projects = widget.projects.value;
    if (pdfs.isNotEmpty && projects.isNotEmpty) {
      _choosing = true;
      try {
        final chosen = await chooseUploadTier(context, projects);
        if (chosen == tierCancelled || !mounted) return;
        projectId = chosen;
      } finally {
        _choosing = false;
      }
    }
    widget.controller.enqueue(pdfs, projectId: projectId, rejected: rejected);
  }

  @override
  Widget build(BuildContext context) {
    final scoped = UploadScope(
      controller: widget.controller,
      child: widget.child,
    );
    if (_touch) return scoped;
    return DropTarget(
      onDragEntered: _hover,
      onDragUpdated: _hover,
      onDragExited: (_) => widget.controller.drop.leave(),
      onDragDone: _done,
      child: scoped,
    );
  }
}

/// Dim veil over a side panel (sidebar, rail, Ask) while a file is dragged.
class DropScrim extends StatelessWidget {
  const DropScrim({super.key, required this.child, this.radius = 24});

  final Widget child;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final controller = UploadScope.maybeOf(context);
    if (controller == null) return child;
    final pb = context.pb;
    final reduced = MediaQuery.disableAnimationsOf(context);
    return Stack(
      // Same constraints for the panel as without the veil.
      fit: StackFit.passthrough,
      children: [
        child,
        Positioned.fill(
          child: IgnorePointer(
            child: ValueListenableBuilder<DropPhase>(
              valueListenable: controller.drop.phase,
              builder: (context, phase, _) => AnimatedOpacity(
                opacity: phase == DropPhase.idle ? 0 : 1,
                duration: reduced
                    ? Duration.zero
                    : const Duration(milliseconds: 160),
                curve: Curves.easeOut,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: pb.dropScrim,
                    borderRadius: BorderRadius.circular(radius),
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

/// The dashed drop zone. Place it as the last child of the pane's [Stack]
/// (`clipBehavior: Clip.none`); it grows [grow] px past the pane.
class DropZone extends StatefulWidget {
  const DropZone({
    super.key,
    required this.projects,
    this.editorOpen = false,
    this.grow = 12,
  });

  final ValueListenable<List<Project>> projects;

  /// A note is open: say the drop adds a new document, the note is untouched.
  final bool editorOpen;
  final double grow;

  @override
  State<DropZone> createState() => _DropZoneState();
}

class _DropZoneState extends State<DropZone> with TickerProviderStateMixin {
  late final _fade = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 200),
    reverseDuration: const Duration(milliseconds: 120),
  );
  late final _bounce = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 550),
  );
  UploadController? _controller;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final next = UploadScope.maybeOf(context);
    if (next != _controller) {
      _controller?.drop.phase.removeListener(_sync);
      _controller = next;
      _controller?.drop.phase.addListener(_sync);
    }
    _sync();
  }

  @override
  void dispose() {
    _controller?.drop.phase.removeListener(_sync);
    _fade.dispose();
    _bounce.dispose();
    super.dispose();
  }

  void _sync() {
    final phase = _controller?.drop.phase.value ?? DropPhase.idle;
    final reduced = MediaQuery.disableAnimationsOf(context);
    // Reduced motion: opacity only, 120 ms.
    _fade.duration = Duration(milliseconds: reduced ? 120 : 200);
    if (phase == DropPhase.idle) {
      _fade.reverse();
    } else {
      _fade.forward();
    }
    // The icon only bobs while hovering, and never with reduced motion.
    if (phase == DropPhase.over && !reduced) {
      if (!_bounce.isAnimating) _bounce.repeat(reverse: true);
    } else {
      _bounce.stop();
      _bounce.value = 0;
    }
  }

  @override
  Widget build(BuildContext context) {
    // Always a Positioned: a plain child would make the pane's Stack size
    // itself to it (0x0) instead of to its Positioned.fill siblings.
    const idle = Positioned(
      left: 0,
      top: 0,
      width: 0,
      height: 0,
      child: SizedBox.shrink(),
    );
    final controller = _controller;
    if (controller == null) return idle;
    return AnimatedBuilder(
      animation: Listenable.merge([_fade, controller.drop.phase]),
      builder: (context, _) {
        final phase = controller.drop.phase.value;
        if (phase == DropPhase.idle && _fade.isDismissed) return idle;
        return Positioned(
          left: -widget.grow,
          top: -widget.grow,
          right: -widget.grow,
          bottom: -widget.grow,
          child: IgnorePointer(child: _zone(context, phase)),
        );
      },
    );
  }

  Widget _zone(BuildContext context, DropPhase phase) {
    final l = context.l;
    final pb = context.pb;
    final text = Theme.of(context).textTheme;
    final reduced = MediaQuery.disableAnimationsOf(context);
    final noProjects = widget.projects.value.isEmpty;
    final editor = widget.editorOpen;
    final sub = noProjects
        ? (editor ? l.dropSubEditor(l.myDocs) : l.dropSub(l.myDocs))
        : (editor ? l.dropSubEditorChoose : l.dropSubChoose);
    final title = editor ? l.dropTitleEditor : l.dropTitle;
    final over = phase == DropPhase.over;
    final enter = CurvedAnimation(
      parent: _fade,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeIn,
    );
    return Semantics(
      container: true,
      liveRegion: true,
      label: l.a11yDropZone(noProjects ? l.myDocs : l.myCloud),
      child: FadeTransition(
        opacity: enter,
        child: ScaleTransition(
          scale: reduced
              ? const AlwaysStoppedAnimation(1)
              : Tween(begin: 0.985, end: 1.0).animate(enter),
          child: TweenAnimationBuilder<double>(
            tween: Tween(end: over ? 1 : 0),
            duration: reduced
                ? Duration.zero
                : const Duration(milliseconds: 140),
            curve: Curves.easeOut,
            builder: (context, t, _) {
              final lift = reduced ? 0.0 : Curves.easeOutBack.transform(t) * 6;
              final tile = 72 + 8 * t;
              return Stack(
                children: [
                  Positioned.fill(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: pb.paneVeil,
                        borderRadius: BorderRadius.circular(24),
                      ),
                    ),
                  ),
                  Positioned.fill(
                    child: CustomPaint(
                      painter: _DashedZonePainter(
                        fill: Color.lerp(pb.dropFill, pb.dropFillOver, t)!,
                        stroke: Color.lerp(pb.dropBorder, pb.accent, t)!,
                        width: 1.5 + t,
                        dash: 8 + 4 * t,
                        gap: 8,
                      ),
                    ),
                  ),
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          AnimatedBuilder(
                            animation: _bounce,
                            builder: (context, child) => Transform.translate(
                              offset: Offset(
                                0,
                                -lift -
                                    4 *
                                        Curves.easeInOut.transform(
                                          _bounce.value,
                                        ),
                              ),
                              child: child,
                            ),
                            child: SizedBox(
                              width: 124,
                              height: 124,
                              child: Stack(
                                alignment: Alignment.center,
                                children: [
                                  // One flat circle, no blur (web cost).
                                  Opacity(
                                    opacity: t,
                                    child: DecoratedBox(
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: pb.accent.withValues(
                                          alpha: 0.16,
                                        ),
                                      ),
                                      child: const SizedBox.square(
                                        dimension: 124,
                                      ),
                                    ),
                                  ),
                                  Container(
                                    width: tile,
                                    height: tile,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: pb.accentContainer,
                                      border: Border.all(
                                        color: pb.accent.withValues(
                                          alpha: 0.5 + 0.5 * t,
                                        ),
                                        width: 1.5,
                                      ),
                                    ),
                                    child: Icon(
                                      AppIcons.fileUp,
                                      size: 34 + 4 * t,
                                      color: pb.onAccentContainer,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            title,
                            textAlign: TextAlign.center,
                            style: text.titleSmall?.copyWith(
                              fontSize: 20,
                              fontWeight: FontWeight.w700,
                              color: pb.ink,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            sub,
                            textAlign: TextAlign.center,
                            style: text.bodyMedium?.copyWith(
                              fontSize: 13.5,
                              color: pb.dropSub,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _DashedZonePainter extends CustomPainter {
  _DashedZonePainter({
    required this.fill,
    required this.stroke,
    required this.width,
    required this.dash,
    required this.gap,
  });

  final Color fill, stroke;
  final double width, dash, gap;

  @override
  void paint(Canvas canvas, Size size) {
    final rrect = RRect.fromRectAndRadius(
      (Offset.zero & size).deflate(width / 2),
      const Radius.circular(24),
    );
    canvas.drawRRect(rrect, Paint()..color = fill);
    final paint = Paint()
      ..color = stroke
      ..style = PaintingStyle.stroke
      ..strokeWidth = width
      ..strokeCap = StrokeCap.round;
    final path = Path()..addRRect(rrect);
    for (final metric in path.computeMetrics()) {
      for (var d = 0.0; d < metric.length; d += dash + gap) {
        canvas.drawPath(
          metric.extractPath(d, math.min(d + dash, metric.length)),
          paint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(_DashedZonePainter o) =>
      o.fill != fill ||
      o.stroke != stroke ||
      o.width != width ||
      o.dash != dash ||
      o.gap != gap;
}
