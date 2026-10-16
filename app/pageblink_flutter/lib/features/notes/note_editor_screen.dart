import 'dart:async';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/gestures.dart' show kSecondaryMouseButton;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show RenderEditable;
import 'package:flutter/services.dart'
    show Clipboard, ClipboardData, LogicalKeyboardKey;
import 'package:pageblink_client/pageblink_client.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../app/app_icons.dart';
import '../../app/confirm_dialog.dart';
import '../../app/l10n.dart';
import '../../app/open_item_controller.dart';
import '../../app/pane_header.dart';
import '../../app/theme.dart';
import '../../client.dart';
import '../demo/demo.dart';
import '../viewer/cite_bar.dart';
import 'cite_layer.dart';
import 'link_popover.dart';
import 'live_check_layer.dart';
import 'live_code_layer.dart';
import 'markdown_live.dart';
import 'selection_mini_bar.dart';

/// Body column width cap (018): keeps lines readable on wide windows.
const noteColumnWidth = 680.0;

/// Note text sizes by window width (018): phone < 600, tablet < 1024, desktop.
/// Body is 16 everywhere; titles and h1-h3 shrink on smaller windows.
({double title, double bodyHeight, double h1, double h2, double h3}) noteSizes(
  double width,
) {
  if (width < 600) {
    return (title: 24, bodyHeight: 1.65, h1: 22, h2: 19, h3: 17);
  }
  if (width < 1024) {
    return (title: 26, bodyHeight: 1.7, h1: 24, h2: 20, h3: 18);
  }
  return (title: 28, bodyHeight: 1.7, h1: 24, h2: 20, h3: 18);
}

/// Vertical rhythm and gutters of the editor (note-editor-spacing spec §3),
/// by **pane** width (not window width: the column is as wide as the pane).
/// One source for the title, the body, the toolbar and the quote banner, so the
/// theme's field padding (18/14) never leaks into the layout.
class NoteSpacing {
  const NoteSpacing._({
    required this.gutter,
    required this.titleTop,
    required this.titleBottom,
    required this.bodyGap,
    required this.endAir,
    required this.scrollBottom,
    required this.bannerTop,
    required this.bannerToTitle,
  });

  /// Pane width classes: compact < 560 <= medium < 720 <= wide.
  /// [short]: window height / text scale < 600, which tightens the top.
  factory NoteSpacing.of(double paneWidth, {required bool short}) {
    final (gutter, endAir, scrollBottom) = paneWidth < 560
        ? (20.0, 64.0, 48.0)
        : paneWidth < 720
        ? (24.0, 96.0, 72.0)
        : (32.0, 120.0, 96.0);
    final top = paneWidth >= 720 ? 32.0 : 24.0;
    return NoteSpacing._(
      gutter: gutter,
      titleTop: short ? 16 : top,
      titleBottom: 8,
      bodyGap: short ? 16 : 24,
      endAir: short ? 48 : endAir,
      scrollBottom: scrollBottom,
      bannerTop: short ? 12 : 16,
      bannerToTitle: short ? 12 : 16,
    );
  }

  /// Text left edge, from the column edge: title, body, first toolbar icon and
  /// banner text all sit on this line.
  final double gutter;

  /// Header line -> title text (no banner).
  final double titleTop;

  /// Title text -> toolbar / divider (inside the title field).
  final double titleBottom;

  /// Air above the first line of the body (the body field's top
  /// `contentPadding`; the hairline sits right above it: under the toolbar on
  /// a desktop, under the title on a phone).
  final double bodyGap;

  /// Extra scroll range under the last line of a note that overflows.
  final double endAir;

  /// `scrollPadding.bottom`: caret distance from the bottom while typing.
  final double scrollBottom;

  /// Banner: header line -> banner, banner -> title text.
  final double bannerTop, bannerToTitle;

  /// Overlays (mini bar, link popover, code block bleed) stay this far inside
  /// the column edge; the body field's own padding is `gutter - overlayClear`.
  static const overlayClear = 8.0;

  static const bannerRadius = 12.0;

  /// Body field's left/right content padding.
  double get bodyInset => gutter - overlayClear;

  static bool isShort(BuildContext context) {
    final scale = MediaQuery.textScalerOf(context).scale(16) / 16;
    return MediaQuery.sizeOf(context).height / (scale < 1 ? 1 : scale) < 600;
  }
}

/// A [ScrollPosition] whose scroll range is [NoteScrollController.air] longer
/// than the content, but only when the content overflows (a short note stays
/// put). `expands: true` fields cannot get this from padding: their
/// `contentPadding` sits outside the scrolled area.
class _EndAirPosition extends ScrollPositionWithSingleContext {
  _EndAirPosition({
    required super.physics,
    required super.context,
    super.oldPosition,
    required this.owner,
  });

  /// The controller, not the value: a changed [NoteScrollController.air] is
  /// picked up by the next layout.
  final NoteScrollController owner;

  @override
  bool applyContentDimensions(double minScrollExtent, double maxScrollExtent) =>
      super.applyContentDimensions(
        minScrollExtent,
        maxScrollExtent > 0 ? maxScrollExtent + owner.air : maxScrollExtent,
      );
}

/// Body scroll controller with end air (see [_EndAirPosition]). Relies on
/// `ScrollPositionWithSingleContext`/`applyContentDimensions` (Flutter 3.47.7);
/// note_editor_spacing_test (T5/T6) fails if an upgrade changes that.
class NoteScrollController extends ScrollController {
  NoteScrollController([this.air = 0]);

  double air;

  @override
  ScrollPosition createScrollPosition(
    ScrollPhysics physics,
    ScrollContext context,
    ScrollPosition? oldPosition,
  ) => _EndAirPosition(
    physics: physics,
    context: context,
    oldPosition: oldPosition,
    owner: this,
  );
}

/// Phone only: 1px line under the title that appears once the body is scrolled
/// (a desktop has the always-visible rule under the toolbar). Its bottom is
/// the body field's top, where the text is clipped.
class _ScrolledHairline extends StatelessWidget {
  const _ScrolledHairline({
    super.key,
    required this.scroll,
    required this.color,
  });

  final ScrollController scroll;
  final Color color;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: scroll,
    builder: (context, _) {
      final shown = scroll.hasClients && scroll.position.pixels > 0.5;
      return SizedBox(
        height: 1,
        width: double.infinity,
        child: AnimatedOpacity(
          opacity: shown ? 1 : 0,
          duration: const Duration(milliseconds: 120),
          child: ColoredBox(color: color),
        ),
      );
    },
  );
}

/// Body family for a weight. Pretendard is one family with declared weights, so
/// Flutter picks the face from `fontWeight` (w700 -> the bundled 600 face).
String _inter(FontWeight w) => pbSansFamily;

/// Live Markdown styles from the app theme and the 018 size table.
LiveStyles liveStylesFor(BuildContext context, TextStyle base) {
  final theme = Theme.of(context);
  final pb = context.pb;
  final sizes = noteSizes(MediaQuery.sizeOf(context).width);
  // titleLarge is the serif (Fraunces w600 + bundled Noto Sans KR subset fallback).
  final serif = theme.textTheme.titleLarge;
  TextStyle head(double size, double height) => TextStyle(
    fontFamily: serif?.fontFamily,
    fontFamilyFallback: serif?.fontFamilyFallback,
    fontSize: size,
    height: height,
    fontWeight: FontWeight.w600,
  );
  final codeFont = TextStyle(
    fontFamily: 'Menlo',
    fontFamilyFallback: [
      'Consolas',
      'Roboto Mono',
      'Noto Sans Mono',
      'monospace',
      ...?base.fontFamilyFallback,
    ],
    fontSize: 14,
  );
  return LiveStyles(
    h1: head(sizes.h1, 1.3),
    h2: head(sizes.h2, 1.35),
    h3: head(sizes.h3, 1.4),
    h4: TextStyle(
      fontFamily: _inter(FontWeight.w600),
      fontWeight: FontWeight.w600,
    ),
    marker: TextStyle(color: pb.inkMuted.withValues(alpha: 0.6)),
    bold: TextStyle(
      fontFamily: _inter(FontWeight.w700),
      fontWeight: FontWeight.w700,
    ),
    // Inline code keeps its tint; fenced blocks are painted as one rounded
    // block by LiveCodeBackLayer, so their lines carry no background.
    code: codeFont.copyWith(
      backgroundColor: theme.colorScheme.onSurface.withValues(alpha: 0.07),
    ),
    fence: codeFont,
    quote: TextStyle(color: pb.inkMuted),
    link: TextStyle(
      color: theme.colorScheme.primary,
      decoration: TextDecoration.underline,
    ),
    checked: TextStyle(
      color: pb.inkMuted,
      decoration: TextDecoration.lineThrough,
    ),
    // List prefix pieces: bullet / number in the accent, box by state.
    bullet: TextStyle(
      color: theme.colorScheme.primary,
      fontWeight: FontWeight.w700,
    ),
    number: TextStyle(color: theme.colorScheme.primary),
    todo: TextStyle(color: pb.inkMuted, fontWeight: FontWeight.w700),
    done: TextStyle(
      color: theme.colorScheme.primary,
      fontWeight: FontWeight.w700,
    ),
  );
}

const _citeAnim = Duration(milliseconds: 160);

/// Folds [child]'s height when it changes (not at all when motion is reduced:
/// `AnimatedSize` with a zero duration asserts in layout).
Widget _fold({required bool reduced, required Widget child}) => reduced
    ? child
    : AnimatedSize(
        duration: _citeAnim,
        alignment: Alignment.topCenter,
        child: child,
      );

/// A citation of the opened note in the answer: its number (`⚡n`) and quote.
/// [start]: the server's offset of the quote in the body (null: unknown).
typedef CiteRef = ({int number, String quote, int? start});

/// Keep-style note editor: title + Markdown body with live styling (or plain
/// source), and a formatting toolbar. Saves (and re-indexes) on close.
///
/// Embedded in the center pane ([embedded]) it has a "← Notes / title"
/// header with a close button; otherwise it is a full page with a back arrow.
class NoteEditorView extends StatefulWidget {
  const NoteEditorView({
    super.key,
    this.note,
    this.projectId,
    this.highlight,
    this.highlightNumber,
    this.highlightStart,
    this.relatedCites = const [],
    required this.embedded,
    required this.onClose,
    this.controller,
    this.openLink,
  });

  final Document? note;
  final int? projectId;

  /// A cited passage to show in the note (opened from an answer): a block
  /// behind the text, scrolled into view, with a bar above (research 027).
  final String? highlight;

  /// The citation number of [highlight] (`⚡n` on the bar), if it has one.
  final int? highlightNumber;

  /// `Citation.quoteStart` of [highlight]: where it starts in the body the
  /// server indexed. Used when it still matches, else the quote is searched.
  final int? highlightStart;

  /// All citations of this note in the same answer (including [highlight]):
  /// the bar steps through them in place.
  final List<CiteRef> relatedCites;

  final bool embedded;

  /// Called after the pending edits were saved (or there was nothing to save).
  final VoidCallback onClose;

  /// Lets the shell save this editor before it is replaced or closed.
  final OpenItemController? controller;

  /// Opens an allowed link outside the app (tests inject a fake). Default:
  /// the platform browser / mail app.
  final Future<bool> Function(Uri uri)? openLink;

  @override
  State<NoteEditorView> createState() => _NoteEditorViewState();
}

class _NoteEditorViewState extends State<NoteEditorView> {
  // Cited passage: the citations of this note, the one shown, whether the
  // highlight is still on (typing or the close button turn it off), and the
  // text it was found in.
  var _cites = <CiteRef>[];
  var _citeAt = 0;
  var _citeOn = false;
  var _citeText = '';
  var _citePulse = 0;
  Timer? _citeTimer;

  late final _title = TextEditingController(text: widget.note?.title ?? '');
  late final _body = LiveMarkdownController(
    text: widget.note?.body ?? '',
    styleOf: liveStylesFor,
    boxes: true, // a LiveCheckLayer over the field draws the checkboxes
    blocks: true, // a LiveCodeBackLayer behind it draws the code blocks
  );
  final _bodyFocus = FocusNode();
  final _bodyKey = GlobalKey();
  final _stackKey = GlobalKey();
  final _bodyScroll = NoteScrollController();
  late int? _id = widget.note?.id;
  late String _savedTitle = widget.note?.title ?? '';
  late String _savedBody = widget.note?.body ?? '';

  /// Last document the server returned (open, save, re-index): index status.
  late Document? _doc = widget.note;
  bool _saving = false; // saving or re-indexing (one spinner)

  // Checkbox layer: item under the mouse (hover outline, click cursor), and
  // the field's render object (looked up once, then reused while mounted).
  final _hover = ValueNotifier<int?>(null);
  EditableTextState? _editableCache;

  // Code blocks: which one the pointer is over (copy button), just copied.
  final _codeUi = CodeBlockUi();
  Offset? _hoverPos; // last pointer position over the body (stack coords)
  double _bodyGap = 0; // NoteSpacing.bodyGap of the last build (air above text)

  /// Deleting: no second tap. Deleted: the note is gone, so closing must not
  /// save it again (`saveNote` would fail with "Note not found").
  bool _deleting = false;
  bool _deleted = false;

  // Selection mini bar (desktop and web; touch apps extend the system menu).
  // Anchors are measured after layout, never while composing or dragging.
  TextSelectionToolbarAnchors? _barAnchors;
  TextSelection? _barDismissed; // Esc / right-click: hidden until it changes
  bool _barEnabled = false;
  bool _pointerDown = false;
  bool _barQueued = false;

  // Link popover (view): the link under a collapsed caret, or the one the
  // link button was pressed on ([_linkForced], bound to that selection).
  // [uri] is null for a target the app will not open (shown, but disabled).
  _LinkView? _link;
  ({TextSelection sel})? _linkForced;

  // Link popover (edit): one session, bound to the text it was started on.
  _LinkEdit? _edit;
  TextSelectionToolbarAnchors? _editAnchors;

  bool get _changed => _title.text != _savedTitle || _body.text != _savedBody;

  /// Title + body as they were when the demo limit refused the save. The save
  /// can never succeed (full demo, locked sample), so the next close with the
  /// same text leaves instead of trapping the user in the editor (the text is
  /// dropped; the message has been shown once).
  String? _demoBlockedAt;
  String get _snapshot => '${_title.text}\u0000${_body.text}';

  @override
  void initState() {
    super.initState();
    widget.controller?.flushHandler = _flush;
    _initCites();
    _body.addListener(_onBodyChanged);
    _body.addListener(_syncBar);
    _bodyFocus.addListener(_syncBar);
    _bodyScroll.addListener(_syncBar);
  }

  void _initCites() {
    final q = widget.highlight;
    if (q == null || q.trim().isEmpty) return;
    final n = widget.highlightNumber ?? 0;
    final list = [...widget.relatedCites];
    if (!list.any((c) => c.number == n)) {
      list.add((number: n, quote: q, start: widget.highlightStart));
    }
    list.sort((a, b) => a.number.compareTo(b.number));
    _cites = list;
    _citeAt = list.indexWhere((c) => c.number == n);
    _citeOn = true;
    _citeText = _body.text;
    _showCite();
    _revealCite();
  }

  /// The shown citation is the body's quote; the other citations of this note
  /// join its block where their lines touch.
  void _showCite() {
    final c = _cites[_citeAt];
    _body.setQuote(
      c.quote,
      start: c.start,
      also: [
        for (var i = 0; i < _cites.length; i++)
          if (i != _citeAt) (quote: _cites[i].quote, start: _cites[i].start),
      ],
    );
  }

  /// Typing (any change of the text) turns the highlight off: the block fades
  /// and the bar folds away. Selection and caret moves do not.
  void _onBodyChanged() {
    if (_citeOn && _body.text != _citeText) _dismissCite();
  }

  void _dismissCite() {
    if (!_citeOn) return;
    setState(() => _citeOn = false);
    // Once the block has faded, stop looking for the quote on every edit.
    _citeTimer?.cancel();
    _citeTimer = Timer(const Duration(milliseconds: 250), () {
      if (mounted && !_citeOn) _body.quote = null;
    });
  }

  void _stepCite(int d) {
    final i = _citeAt + d;
    if (!_citeOn || i < 0 || i >= _cites.length) return;
    setState(() {
      _citeAt = i;
      _citePulse++;
    });
    _showCite();
    _revealCite(animate: true);
  }

  /// Scrolls the cited block to the middle of the field (top-aligned when it
  /// is taller than the field). Runs after the layout of this frame.
  void _revealCite({bool animate = false}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_citeOn || !_bodyScroll.hasClients) return;
      final r = _bodyRender(), range = _body.quoteRange;
      if (r == null || range == null) return;
      final local = citeLocalBounds(r, _body.text, range);
      if (local == null) return;
      final pos = _bodyScroll.position;
      final target = citeScrollTarget(
        top: local.top + pos.pixels - kCitePadY,
        height: local.height + 2 * kCitePadY,
        viewport: r.size.height,
        min: pos.minScrollExtent,
        max: pos.maxScrollExtent,
      );
      if ((target - pos.pixels).abs() < 1) return;
      if (animate && !MediaQuery.disableAnimationsOf(context)) {
        _bodyScroll.animateTo(
          target,
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
        );
      } else {
        _bodyScroll.jumpTo(target);
      }
    });
  }

  @override
  void dispose() {
    final c = widget.controller;
    if (c != null && c.flushHandler == _flush) c.flushHandler = null;
    _citeTimer?.cancel();
    _title.dispose();
    _body.removeListener(_onBodyChanged);
    _body.dispose();
    _hover.dispose();
    _codeUi.dispose();
    _bodyFocus.dispose();
    _bodyScroll.dispose();
    super.dispose();
  }

  /// Saves pending edits. False (with a snackbar) if saving failed; [failure]
  /// replaces the default "Save failed" text with the error appended.
  Future<bool> _flush({String? failure}) async {
    if (_deleted) return true;
    if (_saving || _deleting) return false;
    if (!_changed || _body.text.trim().isEmpty) return true;
    if (_demoBlockedAt == _snapshot) return true;
    final l = context.l;
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _saving = true);
    try {
      final saved = await client.document.saveNote(
        _id,
        _title.text,
        _body.text,
        widget.note?.projectId ?? widget.projectId,
      );
      _id = saved.id;
      _doc = saved;
      _savedTitle = _title.text;
      _savedBody = _body.text;
      boardRefresh.value++;
      if (mounted) setState(() => _saving = false);
      return true;
    } catch (e) {
      if (mounted) setState(() => _saving = false);
      if (e is DemoLimitException) {
        _demoBlockedAt = _snapshot;
        showDemoLimit(messenger, l, e);
      } else {
        messenger.showSnackBar(
          SnackBar(content: Text(failure ?? l.saveFailed(e))),
        );
      }
      return false;
    }
  }

  /// Header menu "Re-index". Unsaved edits are saved first and that save *is*
  /// the re-index (`saveNote` indexes what it stores), so no second call is
  /// made; without edits the stored text is re-indexed. The server's reason is
  /// never shown here, only the fixed text (the header icon has the detail).
  Future<void> _reindex() async {
    final id = _id;
    if (id == null || _saving || _deleting) return;
    final l = context.l;
    final messenger = ScaffoldMessenger.of(context);
    void report(Document d) => messenger.showSnackBar(
      SnackBar(
        content: Text(
          d.status == 'ready' ? l.indexed(d.title) : l.reindexFailed,
        ),
      ),
    );
    if (_changed && _body.text.trim().isNotEmpty) {
      if (!await _flush(failure: l.reindexFailed)) return;
      final d = _doc;
      if (d != null) report(d);
      return;
    }
    setState(() => _saving = true);
    try {
      final d = await client.document.reindex(id);
      _doc = d;
      boardRefresh.value++;
      report(d);
    } catch (e) {
      debugPrint('reindex failed: $e');
      if (e is DemoLimitException) {
        showDemoLimit(messenger, l, e);
      } else {
        messenger.showSnackBar(SnackBar(content: Text(l.reindexFailed)));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  RenderEditable? _bodyRender() {
    var e = _editableCache;
    if (e == null || !e.mounted) {
      e = _editableCache = findEditableText(_bodyKey.currentContext);
    }
    return e != null && e.mounted ? e.renderEditable : null;
  }

  RenderBox? _stackBox() {
    final r = _stackKey.currentContext?.findRenderObject();
    return r is RenderBox ? r : null;
  }

  /// The checklist item whose box is under [p] (stack coordinates), if any.
  CheckTarget? _checkAt(Offset p) {
    final r = _bodyRender(), st = _stackBox();
    if (!_body.live || r == null || st == null) return null;
    return checkTargetAt(
      checkBoxTargets(r, st, _body.checks, topAir: _bodyGap),
      p,
      touch: _touchDevice,
    );
  }

  bool get _touchDevice => switch (Theme.of(context).platform) {
    TargetPlatform.android ||
    TargetPlatform.iOS ||
    TargetPlatform.fuchsia => true,
    _ => false,
  };

  /// Flips one item's box. The text keeps its length, so caret and selection
  /// stay put and focus is not touched. Nothing happens while an IME
  /// composition is open.
  void _toggleCheck(int markerStart) {
    final c = _body.value.composing;
    if (c.isValid && !c.isCollapsed) return;
    _body.value = toggleCheckAt(_body.value, markerStart);
  }

  /// Copy button of a code block: the lines between the fences go to the
  /// clipboard (the fence lines do not), and the block says "Copied".
  Future<void> _copyCode(int start) async {
    FenceBlock? block;
    for (final f in _body.fences) {
      if (f.start == start) block = f;
    }
    if (block == null) return;
    try {
      await Clipboard.setData(
        ClipboardData(text: fenceBody(_body.text, block)),
      );
    } catch (e) {
      debugPrint('copy code failed: $e');
      return;
    }
    if (mounted) _codeUi.flashCopied(start);
  }

  /// Pointer moved over the body (or the layout moved under a still pointer):
  /// checkbox hover, and the code block whose copy button shows.
  void _updateHover(Offset p) {
    _hoverPos = p;
    _hover.value = _checkAt(p)?.item.start;
    final r = _bodyRender(), st = _stackBox();
    if (!_body.live || _touchDevice || r == null || st == null) {
      _codeUi.hover(null);
      return;
    }
    final t = fenceTargetAt(
      fenceTargets(r, st, _body.fences, topAir: _bodyGap),
      p,
    );
    final b = t == null ? null : copyButtonRect(t);
    _codeUi.hover(
      t?.block.start,
      button: b != null && b.inflate(2).contains(p),
    );
  }

  Future<void> _confirmDelete() async {
    final id = _id;
    if (id == null || _deleting || _saving) return;
    final l = context.l;
    final messenger = ScaffoldMessenger.of(context);
    final ok = await confirmDestructive(
      context,
      title: l.deleteNoteTitle,
      message: l.cannotUndo,
    );
    if (!ok || !mounted) return;
    setState(() => _deleting = true);
    try {
      await client.document.delete(id);
    } catch (e) {
      debugPrint('delete note failed: $e');
      if (mounted) setState(() => _deleting = false);
      if (e is DemoLimitException) {
        showDemoLimit(messenger, l, e);
      } else {
        messenger.showSnackBar(SnackBar(content: Text(l.noteDeleteFailed)));
      }
      return;
    }
    _deleted = true;
    boardRefresh.value++;
    if (!mounted) return;
    setState(() => _deleting = false);
    widget.onClose();
  }

  Future<void> _saveAndClose() async {
    if (await _flush() && mounted) widget.onClose();
  }

  /// Applies a toggle result to the body and keeps typing focus there.
  /// Every format entry point (toolbar, mini bar, menu, shortcuts) comes
  /// here; nothing is applied while an IME composition is open.
  void _apply(TextEditingValue Function(TextEditingValue) toggle) {
    final c = _body.value.composing;
    if (c.isValid && !c.isCollapsed) return;
    _body.value = toggle(_body.value);
    _bodyFocus.requestFocus();
  }

  /// Inline formats shared by the toolbar, the mini bar and the touch menu.
  /// [on] is the current `formatState` (button highlight); one parse per build.
  List<FormatAction> _inlineActions(L l, FormatState on) => [
    (l.fmtBold, AppIcons.bold, (v) => toggleInline(v, '**'), on.bold),
    (l.fmtItalic, AppIcons.italic, (v) => toggleInline(v, '_'), on.italic),
    (l.fmtCode, AppIcons.code, toggleCode, on.code),
    (l.fmtLink, AppIcons.link, _linkAction, on.link),
  ];

  /// Link button (toolbar, mini bar, touch menu): opens the popover instead of
  /// toggling. On a link: its view popover. On text (or a caret): the edit
  /// popover, the text filled from the selection and the address from a URL on
  /// the clipboard. Several lines (or a code block) keep the old wrapping.
  /// Called through `_apply`, which keeps the body focused; the popover then
  /// takes the focus for its inputs once it is built.
  TextEditingValue _linkAction(TextEditingValue v) {
    final t = linkTarget(v);
    if (t == null) return toggleLink(v);
    final link = t.link;
    if (link != null) {
      _edit = null;
      _barDismissed = null;
      setState(() => _linkForced = (sel: v.selection));
      _syncBar();
      return v;
    }
    _beginEdit(
      _LinkEdit(
        start: t.start,
        end: t.end,
        text: v.text.substring(t.start, t.end),
        url: '',
        prefill: _clipboardUrl(),
        baseText: v.text,
        baseSel: v.selection,
      ),
    );
    return v;
  }

  /// A `http(s)://` address on the clipboard, if any. Reading may be refused
  /// (the web asks for permission): that is just "nothing to fill".
  Future<String?> _clipboardUrl() async {
    try {
      final s = (await Clipboard.getData(Clipboard.kTextPlain))?.text?.trim();
      if (s != null &&
          RegExp(r'^https?://\S+$', caseSensitive: false).hasMatch(s)) {
        return s;
      }
    } catch (e) {
      debugPrint('clipboard read failed: $e');
    }
    return null;
  }

  void _beginEdit(_LinkEdit e) {
    setState(() {
      _edit = e;
      _linkForced = null;
      _editAnchors = _measureRange(e.start, e.end);
    });
    _syncBar();
  }

  /// "Edit" of the view popover.
  void _editLink() {
    final l = _link;
    if (l == null) return;
    final text = _body.text;
    final link = (start: l.start, end: l.end, url: l.url);
    _beginEdit(
      _LinkEdit(
        start: l.start,
        end: l.end,
        text: linkLabel(text, link),
        url: l.url,
        link: link,
        baseText: text,
        baseSel: _body.selection,
      ),
    );
  }

  /// "Remove" of the view popover: `[text](url)` becomes `text`.
  void _removeLink() {
    final l = _link;
    if (l == null) return;
    _apply((v) => removeLink(v, (start: l.start, end: l.end, url: l.url)));
  }

  /// Confirms the edit: one new value for the body (one undo step).
  void _applyEdit(_LinkEdit e, String text, String url) {
    if (_edit != e) return;
    setState(() {
      _edit = null;
      _editAnchors = null;
      _linkForced = null;
    });
    _body.value = setLink(_body.value, e.start, e.end, text, url, link: e.link);
    _bodyFocus.requestFocus();
    _syncBar();
  }

  /// Esc / Cancel ([refocus]), or the focus left the popover (no refocus: it
  /// went somewhere the user chose). Nothing in the text changes. After
  /// cancelling the edit of a link, the view popover stays hidden until the
  /// caret moves.
  void _cancelEdit(_LinkEdit e, {required bool refocus}) {
    if (_edit != e) return;
    if (e.link != null) _barDismissed = _body.selection;
    setState(() {
      _edit = null;
      _editAnchors = null;
    });
    if (refocus) _bodyFocus.requestFocus();
    _syncBar();
  }

  TextSelectionToolbarAnchors? _measureRange(int start, int end) {
    if (end > _body.text.length) return null;
    final editable = findEditableText(_bodyKey.currentContext);
    final stack = _stackKey.currentContext?.findRenderObject();
    if (editable == null || stack is! RenderBox || !stack.attached) return null;
    if (!editable.renderEditable.attached) return null;
    return miniBarAnchors(
      editable,
      stack,
      selection: TextSelection(baseOffset: start, extentOffset: end),
    );
  }

  void _syncBar() {
    if (_barQueued) return;
    _barQueued = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _barQueued = false;
      if (!mounted) return;
      final hp = _hoverPos;
      if (hp != null) _updateHover(hp); // layout / scroll moved under it
      // An edit belongs to the text it started on; the text (or caret) moving
      // on means there is nothing to apply it to.
      var edit = _edit;
      if (edit != null &&
          (_body.text != edit.baseText || _body.selection != edit.baseSel)) {
        edit = _edit = null;
        _bodyFocus.requestFocus(); // the popover's input held it
      }
      final editAnchors = edit == null
          ? null
          : _measureRange(edit.start, edit.end);
      final next = _measureBar();
      final cur = _barAnchors;
      final link = _measureLink();
      final curLink = _link;
      final curEdit = _editAnchors;
      if (next?.primaryAnchor != cur?.primaryAnchor ||
          next?.secondaryAnchor != cur?.secondaryAnchor ||
          link?.url != curLink?.url ||
          link?.uri != curLink?.uri ||
          link?.start != curLink?.start ||
          link?.anchors.primaryAnchor != curLink?.anchors.primaryAnchor ||
          link?.anchors.secondaryAnchor != curLink?.anchors.secondaryAnchor ||
          editAnchors?.primaryAnchor != curEdit?.primaryAnchor ||
          editAnchors?.secondaryAnchor != curEdit?.secondaryAnchor) {
        setState(() {
          _barAnchors = next;
          _link = link;
          _editAnchors = editAnchors;
        });
      }
    });
    WidgetsBinding.instance.scheduleFrame();
  }

  TextSelectionToolbarAnchors? _measureBar() {
    final v = _body.value, sel = v.selection;
    // Hangul/IME composing: stay out of the way until it is committed.
    final composing = v.composing.isValid && !v.composing.isCollapsed;
    if (!_barEnabled ||
        _pointerDown ||
        composing ||
        !_bodyFocus.hasFocus ||
        !sel.isValid ||
        sel.isCollapsed ||
        sel == _barDismissed) {
      return null;
    }
    final editable = findEditableText(_bodyKey.currentContext);
    final stack = _stackKey.currentContext?.findRenderObject();
    if (editable == null || stack is! RenderBox || !stack.attached) return null;
    return miniBarAnchors(editable, stack);
  }

  /// The popover is for a caret inside a link (strictly), or the link the
  /// button was pressed on while it is still the same selection. With another
  /// selection the mini bar (or the system menu on touch) owns that spot.
  _LinkView? _measureLink() {
    final v = _body.value, sel = v.selection;
    final composing = v.composing.isValid && !v.composing.isCollapsed;
    if (_edit != null || _pointerDown || composing || !sel.isValid) {
      return null;
    }
    LiveLink? link;
    final forced = _linkForced;
    if (forced != null && sel == forced.sel && sel != _barDismissed) {
      link = linkTarget(v)?.link;
    }
    if (link == null) {
      _linkForced = null;
      if (!_bodyFocus.hasFocus || !sel.isCollapsed || sel == _barDismissed) {
        return null;
      }
      link = linkAt(v.text, sel.baseOffset);
    }
    if (link == null) return null;
    final anchors = _measureRange(link.start, link.end);
    if (anchors == null) return null;
    return (
      anchors: anchors,
      url: link.url,
      uri: safeLinkUri(link.url),
      start: link.start,
      end: link.end,
      bracket: isBracketLink(v.text, link),
    );
  }

  Future<void> _openLink(Uri uri) async {
    final messenger = ScaffoldMessenger.of(context);
    final failed = context.l.linkOpenFailed;
    try {
      final open =
          widget.openLink ??
          (u) => launchUrl(u, mode: LaunchMode.externalApplication);
      if (await open(uri)) return;
    } catch (e) {
      debugPrint('open link failed: $e');
    }
    messenger.showSnackBar(SnackBar(content: Text(failed)));
  }

  /// Heading button: icon plus the current level (H1-H6) while the caret is
  /// in a heading; plain icon for body text or a mixed selection.
  Widget _headingButton(L l, ThemeData theme) {
    final level = headingLevel(_body.value);
    final active = level > 0;
    final fg = active
        ? theme.colorScheme.onPrimaryContainer
        : theme.colorScheme.onSurfaceVariant;
    return PopupMenuButton<int>(
      tooltip: l.fmtHeading,
      padding: EdgeInsets.zero,
      onSelected: (level) => _apply((v) => setHeading(v, level)),
      itemBuilder: (_) {
        final cur = headingLevel(_body.value);
        return [
          for (final (level, label) in [
            (0, l.fmtBodyText),
            for (var n = 1; n <= 6; n++) (n, 'H$n'),
          ])
            CheckedPopupMenuItem(
              value: level,
              checked: cur == level,
              child: Text(label),
            ),
        ];
      },
      child: Container(
        key: const ValueKey('heading-button'),
        constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
        padding: const EdgeInsets.symmetric(horizontal: 8),
        decoration: BoxDecoration(
          color: active ? theme.colorScheme.primaryContainer : null,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(AppIcons.heading, color: fg),
            if (active)
              Padding(
                padding: const EdgeInsets.only(left: 2),
                child: Text(
                  'H$level',
                  style: TextStyle(
                    color: fg,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  /// The only place that insets the toolbar: its first icon sits on the text
  /// line ([NoteSpacing.gutter]; the heading button has 8 of its own padding).
  Widget _toolbar(BuildContext context, NoteSpacing sp) {
    final l = context.l;
    Widget button(
      String tip,
      IconData icon,
      TextEditingValue Function(TextEditingValue) f, [
      bool active = false,
    ]) => FormatButton(
      tooltip: tip,
      icon: icon,
      active: active,
      onPressed: () => _apply(f),
    );
    // ExcludeFocus: tapping a button must not take focus from the body, and
    // the tap region keeps a press here from running the field's tap-outside
    // unfocus (desktop / web), so the caret and selection stay live.
    // Rebuilt with the body so the heading button shows the current level.
    return TextFieldTapRegion(
      child: ExcludeFocus(
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: EdgeInsets.only(left: sp.bodyInset),
          child: ListenableBuilder(
            listenable: _body,
            builder: (context, _) {
              final on = formatState(_body.value);
              final [bold, italic, code, link] = _inlineActions(l, on);
              return Row(
                children: [
                  _headingButton(l, Theme.of(context)),
                  button(bold.$1, bold.$2, bold.$3, bold.$4),
                  button(italic.$1, italic.$2, italic.$3, italic.$4),
                  button(
                    l.fmtStrike,
                    AppIcons.strikethrough,
                    (v) => toggleInline(v, '~~'),
                    on.strike,
                  ),
                  button(l.fmtList, AppIcons.bulletList, toggleBullet),
                  button(l.fmtOrderedList, AppIcons.orderedList, toggleOrdered),
                  button(l.fmtCheckbox, AppIcons.checklist, toggleCheck),
                  button(l.fmtQuote, AppIcons.quote, toggleQuote),
                  button(code.$1, code.$2, code.$3, code.$4),
                  button(link.$1, link.$2, link.$3, link.$4),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l;
    final theme = Theme.of(context);
    final width = MediaQuery.sizeOf(context).width;
    final reduced = MediaQuery.disableAnimationsOf(context);
    final sizes = noteSizes(width);
    final titleStyle = theme.textTheme.titleLarge?.copyWith(
      fontSize: sizes.title,
      height: 1.25,
      fontWeight: FontWeight.w600,
    );
    final bodyStyle = theme.textTheme.bodyLarge?.copyWith(
      fontSize: 16,
      height: sizes.bodyHeight,
    );
    // Toolbar above the body on desktops at any window width (a narrow or
    // zoomed browser window is still a desktop); below it only on touch
    // devices, where it sits above the keyboard.
    final desktop =
        theme.platform == TargetPlatform.macOS ||
        theme.platform == TargetPlatform.windows ||
        theme.platform == TargetPlatform.linux;
    final wide = width >= 600 || desktop;
    _barEnabled = kIsWeb || desktop;
    // Cmd on Apple platforms, Ctrl elsewhere (Ctrl+B/I are caret moves on Mac).
    final apple =
        theme.platform == TargetPlatform.macOS ||
        theme.platform == TargetPlatform.iOS;
    SingleActivator key(LogicalKeyboardKey k) =>
        SingleActivator(k, meta: apple, control: !apple);
    return PopScope(
      // Embedded: back is handled by the shell. Full page: save first.
      canPop: widget.embedded,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _saveAndClose();
      },
      child: LayoutBuilder(
        builder: (context, box) {
          // Rhythm and gutters follow the pane (the column's real width).
          final sp = NoteSpacing.of(
            box.maxWidth,
            short: NoteSpacing.isShort(context),
          );
          _bodyScroll.air = sp.endAir;
          _bodyGap = sp.bodyGap;
          return Column(
            children: [
              PaneHeader(
                embedded: widget.embedded,
                onBack: _saveAndClose,
                onClose: _saveAndClose,
                title: Row(
                  children: [
                    Flexible(
                      child: ValueListenableBuilder(
                        valueListenable: _title,
                        builder: (context, value, _) => Text(
                          value.text.trim().isNotEmpty
                              ? value.text.trim()
                              : (widget.note == null ? l.newNote : l.titleHint),
                        ),
                      ),
                    ),
                    // Index state of a stored note, small and quiet.
                    if (_doc?.status == 'failed')
                      Tooltip(
                        message: _doc?.lastError == null
                            ? l.indexingFailed
                            : l.indexingError(_doc?.lastError),
                        child: Padding(
                          padding: const EdgeInsets.only(left: 8),
                          child: Icon(
                            AppIcons.warning,
                            key: const ValueKey('index-failed'),
                            size: 16,
                            color: theme.colorScheme.error,
                          ),
                        ),
                      )
                    else if (_doc?.status == 'indexing')
                      Padding(
                        padding: const EdgeInsets.only(left: 8),
                        child: Text(
                          '${l.indexing}…',
                          key: const ValueKey('index-running'),
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: context.pb.inkMuted,
                          ),
                        ),
                      ),
                  ],
                ),
                actions: [
                  // Labeled Live | Source toggle; icons only on narrow phones.
                  SegmentedButton<bool>(
                    showSelectedIcon: false,
                    style: const ButtonStyle(
                      visualDensity: VisualDensity.compact,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    segments: [
                      ButtonSegment(
                        value: true,
                        label: width < 400 ? null : Text(l.modeLive),
                        icon: width < 400
                            ? const Icon(AppIcons.modeLive)
                            : null,
                        tooltip: l.modeLive,
                      ),
                      ButtonSegment(
                        value: false,
                        label: width < 400 ? null : Text(l.modeSource),
                        icon: width < 400
                            ? const Icon(AppIcons.modeSource)
                            : null,
                        tooltip: l.modeSource,
                      ),
                    ],
                    selected: {_body.live},
                    onSelectionChanged: (s) =>
                        setState(() => _body.live = s.first),
                  ),
                  // Only a stored note can be re-indexed or deleted.
                  if (_id != null)
                    PopupMenuButton<bool>(
                      tooltip: l.moreActions,
                      icon: const Icon(AppIcons.more),
                      enabled: !_saving && !_deleting,
                      onSelected: (reindex) =>
                          reindex ? _reindex() : _confirmDelete(),
                      itemBuilder: (_) => [
                        PopupMenuItem(value: true, child: Text(l.reindex)),
                        PopupMenuItem(value: false, child: Text(l.delete)),
                      ],
                    ),
                  if (_saving)
                    const Padding(
                      padding: EdgeInsets.all(16),
                      child: SizedBox.square(
                        dimension: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    )
                  else
                    IconButton(
                      tooltip: l.save,
                      icon: const Icon(AppIcons.check),
                      onPressed: _saveAndClose,
                    ),
                ],
              ),
              // Title, citation bar and body share one column (Column centers it).
              // Everything starts on the gutter line (text, not box). The bar
              // folds away (and the title's top air grows) once the highlight
              // is off, so typing does not make the page jump.
              _fold(
                reduced: reduced,
                child: !_citeOn
                    ? const SizedBox(width: double.infinity)
                    : ConstrainedBox(
                        constraints: const BoxConstraints(
                          maxWidth: noteColumnWidth,
                        ),
                        child: Container(
                          key: const ValueKey('cite-bar'),
                          width: double.infinity,
                          margin: EdgeInsets.fromLTRB(
                            sp.gutter - NoteSpacing.bannerRadius,
                            sp.bannerTop,
                            sp.gutter - NoteSpacing.bannerRadius,
                            0,
                          ),
                          child: CiteBar(
                            number: _cites[_citeAt].number == 0
                                ? null
                                : _cites[_citeAt].number,
                            text: _body.quoteRange == null
                                ? _cites[_citeAt].quote
                                : null,
                            position: _citeAt + 1,
                            count: _cites.length,
                            onPrevious: _citeAt > 0
                                ? () => _stepCite(-1)
                                : null,
                            onNext: _citeAt < _cites.length - 1
                                ? () => _stepCite(1)
                                : null,
                            onDismiss: _dismissCite,
                          ),
                        ),
                      ),
              ),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: noteColumnWidth),
                // The field's contentPadding is the only padding (the theme's 18/14
                // would otherwise leak in): top is the gap to the header or bar.
                child: TweenAnimationBuilder<double>(
                  tween: Tween(end: _citeOn ? sp.bannerToTitle : sp.titleTop),
                  duration: reduced ? Duration.zero : _citeAnim,
                  builder: (context, top, _) => TextField(
                    controller: _title,
                    style: titleStyle,
                    scrollPadding: const EdgeInsets.all(20),
                    decoration: InputDecoration(
                      hintText: context.l.titleHint,
                      filled: false,
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      disabledBorder: InputBorder.none,
                      contentPadding: EdgeInsets.fromLTRB(
                        sp.gutter,
                        top,
                        sp.gutter,
                        sp.titleBottom,
                      ),
                    ),
                  ),
                ),
              ),
              // Desktop/tablet: toolbar pinned above the body, on the 680 column,
              // starting at the left line (a scroll view would shrink and center).
              if (wide)
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: noteColumnWidth),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: _toolbar(context, sp),
                  ),
                ),
              // Full-width rule right under the toolbar (no gap: the toolbar
              // reads as a band between header/title and body, as before the
              // spacing change). Phone: no toolbar here, so the rule only
              // shows while the body is scrolled under the title.
              if (wide)
                SizedBox(
                  key: const ValueKey('note-hairline'),
                  height: 1,
                  width: double.infinity,
                  child: ColoredBox(color: context.pb.hairline),
                )
              else
                _ScrolledHairline(
                  key: const ValueKey('note-hairline'),
                  scroll: _bodyScroll,
                  color: context.pb.hairline,
                ),
              Expanded(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: noteColumnWidth),
                  child: Padding(
                    // Overlays (mini bar, popovers, code bleed) keep this far
                    // inside the column; the text line is `gutter` (field padding).
                    padding: const EdgeInsets.symmetric(
                      horizontal: NoteSpacing.overlayClear,
                    ),
                    // Pointer over a box: outline, and the click cursor (the field's
                    // own cursor is not under the pointer there, the layer is).
                    child: ListenableBuilder(
                      listenable: Listenable.merge([_hover, _codeUi]),
                      builder: (context, stack) => MouseRegion(
                        opaque: false,
                        cursor: _hover.value == null && !_codeUi.overButton
                            ? MouseCursor.defer
                            : SystemMouseCursors.click,
                        onHover: (e) => _updateHover(e.localPosition),
                        onExit: (_) {
                          _hoverPos = null;
                          _hover.value = null;
                          _codeUi.hover(null);
                        },
                        child: stack,
                      ),
                      child: Stack(
                        key: _stackKey,
                        // Code block backgrounds reach past the text area.
                        clipBehavior: Clip.none,
                        children: [
                          // Behind the field: code block backgrounds and labels.
                          LiveCodeBackLayer(
                            enabled: _body.live,
                            controller: _body,
                            scroll: _bodyScroll,
                            ui: _codeUi,
                            render: _bodyRender,
                            stack: _stackBox,
                            fill: theme.brightness == Brightness.dark
                                ? context.pb.ink.withValues(alpha: 0.10)
                                : context.pb.ink.withValues(alpha: 0.055),
                            labelStyle:
                                (theme.textTheme.labelSmall ??
                                        const TextStyle())
                                    .copyWith(
                                      fontSize: 11,
                                      color: context.pb.inkMuted,
                                    ),
                            copyEnabled: !_touchDevice,
                            topAir: sp.bodyGap,
                          ),
                          // The cited passage: one soft block with a rail,
                          // behind the field (selection paints over it).
                          if (_cites.isNotEmpty)
                            CiteBackLayer(
                              controller: _body,
                              scroll: _bodyScroll,
                              render: _bodyRender,
                              stack: _stackBox,
                              fill: context.pb.citeFill,
                              pulse: context.pb.citePulse,
                              edge: context.pb.citeEdge,
                              visible: _citeOn,
                              pulseKey: _citePulse,
                              topAir: sp.bodyGap,
                            ),
                          Listener(
                            onPointerDown: (e) {
                              _pointerDown = true;
                              if (e.buttons == kSecondaryMouseButton) {
                                _barDismissed = _body.selection; // context menu
                              }
                              _syncBar();
                            },
                            onPointerUp: (_) {
                              _pointerDown = false;
                              _syncBar();
                            },
                            onPointerCancel: (_) {
                              _pointerDown = false;
                              _syncBar();
                            },
                            child: CallbackShortcuts(
                              bindings: {
                                key(LogicalKeyboardKey.keyB): () =>
                                    _apply((v) => toggleInline(v, '**')),
                                key(LogicalKeyboardKey.keyI): () =>
                                    _apply((v) => toggleInline(v, '_')),
                                // Check / uncheck the item(s) on the caret's lines.
                                key(LogicalKeyboardKey.enter): () =>
                                    _apply(toggleDone),
                                if (_barAnchors != null || _link != null)
                                  const SingleActivator(
                                    LogicalKeyboardKey.escape,
                                  ): () {
                                    _barDismissed = _body.selection;
                                    _syncBar();
                                  },
                              },
                              // The air above the text is the field's top
                              // padding, which is outside the scrolled area:
                              // the field's own clip is off and this one
                              // (field box = from the rule down) takes over,
                              // so scrolled text slides up into the air and
                              // is cut at the rule, not 24px below it.
                              child: ClipRect(
                                child: TextField(
                                  key: _bodyKey,
                                  controller: _body,
                                  focusNode: _bodyFocus,
                                  scrollController: _bodyScroll,
                                  clipBehavior: Clip.none,
                                  contextMenuBuilder: (context, state) {
                                    final sel =
                                        state.textEditingValue.selection;
                                    return AdaptiveTextSelectionToolbar.buttonItems(
                                      anchors: state.contextMenuAnchors,
                                      buttonItems: [
                                        ...state.contextMenuButtonItems,
                                        if (sel.isValid && !sel.isCollapsed)
                                          for (final (tip, _, toggle, _)
                                              in _inlineActions(
                                                context.l,
                                                formatState(
                                                  state.textEditingValue,
                                                ),
                                              ))
                                            ContextMenuButtonItem(
                                              label: tip,
                                              onPressed: () {
                                                state.hideToolbar(false);
                                                _apply(toggle);
                                              },
                                            ),
                                      ],
                                    );
                                  },
                                  style: bodyStyle,
                                  autofocus: widget.note == null,
                                  maxLines: null,
                                  expands: true,
                                  keyboardType: TextInputType.multiline,
                                  inputFormatters: const [
                                    ListContinuationFormatter(),
                                  ],
                                  textAlignVertical: TextAlignVertical.top,
                                  // Caret stays this far above the bottom while typing
                                  // (the air under the last line is the scroll range).
                                  scrollPadding: EdgeInsets.fromLTRB(
                                    20,
                                    20,
                                    20,
                                    sp.scrollBottom,
                                  ),
                                  decoration: InputDecoration(
                                    hintText: context.l.noteHint,
                                    filled: false,
                                    border: InputBorder.none,
                                    enabledBorder: InputBorder.none,
                                    focusedBorder: InputBorder.none,
                                    disabledBorder: InputBorder.none,
                                    // Top: the air under the rule (text paints
                                    // into it, see the ClipRect). Bottom 0: a
                                    // padding there is a dead band outside the
                                    // scrolled area (below is the end air).
                                    contentPadding: EdgeInsets.fromLTRB(
                                      sp.bodyInset,
                                      sp.bodyGap,
                                      sp.bodyInset,
                                      0,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          // Checkboxes over the field (live mode only; source mode
                          // shows the plain `- [ ]`).
                          if (_body.live)
                            LiveCheckLayer(
                              controller: _body,
                              scroll: _bodyScroll,
                              hover: _hover,
                              render: _bodyRender,
                              stack: _stackBox,
                              accent: theme.colorScheme.primary,
                              onAccent: theme.colorScheme.onPrimary,
                              border: context.pb.hairline,
                              doneLabel: l.checkDone,
                              todoLabel: l.checkTodo,
                              onToggle: _toggleCheck,
                              touch: _touchDevice,
                              topAir: sp.bodyGap,
                            ),
                          if (_barAnchors != null)
                            ListenableBuilder(
                              listenable: _body,
                              builder: (context, _) {
                                final c = checkState(_body.value, _body.checks);
                                return SelectionMiniBar(
                                  anchors: _barAnchors!,
                                  actions: [
                                    ..._inlineActions(
                                      l,
                                      formatState(_body.value),
                                    ),
                                    // Only when the selection holds checklist items.
                                    if (c.any)
                                      (
                                        c.allDone
                                            ? l.fmtUncheckAll
                                            : l.fmtCheckAll,
                                        AppIcons.checklist,
                                        toggleDone,
                                        c.allDone,
                                      ),
                                  ],
                                  onApply: _apply,
                                  headingLevel: headingLevel(_body.value),
                                  onHeading: (level) =>
                                      _apply((v) => setHeading(v, level)),
                                );
                              },
                            ),
                          // Copy button of the code block under the mouse.
                          if (_body.live && !_touchDevice)
                            LiveCodeCopyLayer(
                              controller: _body,
                              scroll: _bodyScroll,
                              ui: _codeUi,
                              render: _bodyRender,
                              stack: _stackBox,
                              color: context.pb.inkMuted,
                              hoverFill: context.pb.ink.withValues(alpha: 0.08),
                              accent: theme.colorScheme.primary,
                              labelStyle:
                                  (theme.textTheme.labelSmall ??
                                          const TextStyle())
                                      .copyWith(fontSize: 11),
                              copyLabel: l.codeCopy,
                              copiedLabel: l.copied,
                              onCopy: _copyCode,
                              topAir: sp.bodyGap,
                            ),
                          if (_edit case final e? when _editAnchors != null)
                            LinkEditPopover(
                              key: ValueKey(e),
                              anchors: _editAnchors!,
                              initialText: e.text,
                              initialUrl: e.url,
                              prefill: e.prefill,
                              onApply: (text, url) => _applyEdit(e, text, url),
                              onCancel: () => _cancelEdit(e, refocus: true),
                              onLeave: () => _cancelEdit(e, refocus: false),
                            )
                          else if (_link != null &&
                              (_barAnchors == null || _linkForced != null))
                            LinkPopover(
                              key: const ValueKey('link-popover'),
                              anchors: _link!.anchors,
                              url: _link!.url,
                              openEnabled: _link!.uri != null,
                              canRemove: _link!.bracket,
                              onOpen: () => _openLink(_link!.uri!),
                              onEdit: _editLink,
                              onRemove: _removeLink,
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              // Phone: toolbar above the keyboard, as before.
              if (!wide)
                SafeArea(
                  top: false,
                  child: Material(
                    color: theme.colorScheme.surfaceContainer,
                    // Rule above the bar: it does not float over the body
                    // (with or without the keyboard).
                    child: DecoratedBox(
                      key: const ValueKey('note-toolbar-top-rule'),
                      decoration: BoxDecoration(
                        border: Border(
                          top: BorderSide(color: context.pb.hairline),
                        ),
                      ),
                      child: _toolbar(context, sp),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

/// The link popover's target: its range in the text, the address as written,
/// and the openable URI (null: not allowed, shown but disabled).
typedef _LinkView = ({
  TextSelectionToolbarAnchors anchors,
  String url,
  Uri? uri,
  int start,
  int end,
  bool bracket,
});

/// One link edit: the range `[start, end)` it replaces (an existing link, or
/// the selected text / the caret), the inputs' start values, and the text and
/// selection it is bound to.
class _LinkEdit {
  _LinkEdit({
    required this.start,
    required this.end,
    required this.text,
    required this.url,
    required this.baseText,
    required this.baseSel,
    this.link,
    this.prefill,
  });

  final int start, end;
  final String text, url;
  final LiveLink? link;
  final Future<String?>? prefill;
  final String baseText;
  final TextSelection baseSel;
}
