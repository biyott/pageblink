import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/gestures.dart' show kSecondaryMouseButton;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show LogicalKeyboardKey;
import 'package:google_fonts/google_fonts.dart';
import 'package:pageblink_client/pageblink_client.dart';

import '../../app/app_icons.dart';
import '../../app/confirm_dialog.dart';
import '../../app/l10n.dart';
import '../../app/open_item_controller.dart';
import '../../app/pane_header.dart';
import '../../app/theme.dart';
import '../../client.dart';
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

/// True family names of a Google Font weight (google_fonts encodes the weight
/// in the family name, so `fontWeight` alone would be synthesized).
final _interFamilies = <FontWeight, String>{};
String _inter(FontWeight w) =>
    _interFamilies[w] ??= GoogleFonts.inter(fontWeight: w).fontFamily!;

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
    code: TextStyle(
      fontFamily: 'Menlo',
      fontFamilyFallback: [
        'Consolas',
        'Roboto Mono',
        'Noto Sans Mono',
        'monospace',
        ...?base.fontFamilyFallback,
      ],
      fontSize: 14,
      backgroundColor: theme.colorScheme.onSurface.withValues(alpha: 0.07),
    ),
    quote: TextStyle(color: pb.inkMuted),
    link: TextStyle(
      color: theme.colorScheme.primary,
      decoration: TextDecoration.underline,
    ),
    checked: TextStyle(
      color: pb.inkMuted,
      decoration: TextDecoration.lineThrough,
    ),
    // Same tint as the citation banner above the note.
    highlight: theme.colorScheme.secondaryContainer,
  );
}

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
    required this.embedded,
    required this.onClose,
    this.controller,
  });

  final Document? note;
  final int? projectId;

  /// A cited passage to show above the note (opened from an answer).
  final String? highlight;

  final bool embedded;

  /// Called after the pending edits were saved (or there was nothing to save).
  final VoidCallback onClose;

  /// Lets the shell save this editor before it is replaced or closed.
  final OpenItemController? controller;

  @override
  State<NoteEditorView> createState() => _NoteEditorViewState();
}

class _NoteEditorViewState extends State<NoteEditorView> {
  late final _title = TextEditingController(text: widget.note?.title ?? '');
  late final _body = LiveMarkdownController(
    text: widget.note?.body ?? '',
    styleOf: liveStylesFor,
  );
  final _bodyFocus = FocusNode();
  final _bodyKey = GlobalKey();
  final _stackKey = GlobalKey();
  final _bodyScroll = ScrollController();
  late int? _id = widget.note?.id;
  late String _savedTitle = widget.note?.title ?? '';
  late String _savedBody = widget.note?.body ?? '';
  bool _saving = false;

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

  bool get _changed => _title.text != _savedTitle || _body.text != _savedBody;

  @override
  void initState() {
    super.initState();
    widget.controller?.flushHandler = _flush;
    _body.quote = widget.highlight;
    _body.addListener(_syncBar);
    _bodyFocus.addListener(_syncBar);
    _bodyScroll.addListener(_syncBar);
  }

  @override
  void dispose() {
    final c = widget.controller;
    if (c != null && c.flushHandler == _flush) c.flushHandler = null;
    _title.dispose();
    _body.dispose();
    _bodyFocus.dispose();
    _bodyScroll.dispose();
    super.dispose();
  }

  /// Saves pending edits. False (with a snackbar) if saving failed.
  Future<bool> _flush() async {
    if (_deleted) return true;
    if (_saving || _deleting) return false;
    if (!_changed || _body.text.trim().isEmpty) return true;
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
      _savedTitle = _title.text;
      _savedBody = _body.text;
      boardRefresh.value++;
      if (mounted) setState(() => _saving = false);
      return true;
    } catch (e) {
      if (mounted) setState(() => _saving = false);
      messenger.showSnackBar(SnackBar(content: Text(l.saveFailed(e))));
      return false;
    }
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
      messenger.showSnackBar(SnackBar(content: Text(l.noteDeleteFailed)));
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
  void _apply(TextEditingValue Function(TextEditingValue) toggle) {
    _body.value = toggle(_body.value);
    _bodyFocus.requestFocus();
  }

  /// Inline formats shared by the toolbar, the mini bar and the touch menu.
  List<FormatAction> _inlineActions(L l) => [
    (l.fmtBold, AppIcons.bold, (v) => toggleInline(v, '**')),
    (l.fmtItalic, AppIcons.italic, (v) => toggleInline(v, '_')),
    (l.fmtCode, AppIcons.code, (v) => toggleInline(v, '`')),
    (l.fmtLink, AppIcons.link, toggleLink),
  ];

  void _syncBar() {
    if (_barQueued) return;
    _barQueued = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _barQueued = false;
      if (!mounted) return;
      final next = _measureBar();
      final cur = _barAnchors;
      if (next?.primaryAnchor != cur?.primaryAnchor ||
          next?.secondaryAnchor != cur?.secondaryAnchor) {
        setState(() => _barAnchors = next);
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

  Widget _toolbar(BuildContext context) {
    final l = context.l;
    final inline = _inlineActions(l);
    Widget button(
      String tip,
      IconData icon,
      TextEditingValue Function(TextEditingValue) f,
    ) => IconButton(
      tooltip: tip,
      icon: Icon(icon),
      visualDensity: VisualDensity.compact,
      onPressed: () => _apply(f),
    );
    // ExcludeFocus: tapping a button must not take focus from the body.
    return ExcludeFocus(
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            PopupMenuButton<int>(
              tooltip: l.fmtHeading,
              icon: const Icon(AppIcons.heading),
              onSelected: (level) => _apply((v) => setHeading(v, level)),
              itemBuilder: (_) {
                final cur = headingLevel(_body.value);
                return [
                  for (final (level, label) in [
                    (0, l.fmtBodyText),
                    (1, 'H1'),
                    (2, 'H2'),
                    (3, 'H3'),
                  ])
                    CheckedPopupMenuItem(
                      value: level,
                      checked: cur == level || (level == 0 && cur > 3),
                      child: Text(label),
                    ),
                ];
              },
            ),
            button(inline[0].$1, inline[0].$2, inline[0].$3),
            button(inline[1].$1, inline[1].$2, inline[1].$3),
            button(l.fmtList, AppIcons.bulletList, toggleBullet),
            button(l.fmtCheckbox, AppIcons.checklist, toggleCheck),
            button(l.fmtQuote, AppIcons.quote, toggleQuote),
            button(inline[2].$1, inline[2].$2, inline[2].$3),
            button(inline[3].$1, inline[3].$2, inline[3].$3),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l;
    final theme = Theme.of(context);
    final width = MediaQuery.sizeOf(context).width;
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
      child: Column(
        children: [
          PaneHeader(
            embedded: widget.embedded,
            onBack: _saveAndClose,
            onClose: _saveAndClose,
            title: ValueListenableBuilder(
              valueListenable: _title,
              builder: (context, value, _) => Text(
                value.text.trim().isNotEmpty
                    ? value.text.trim()
                    : (widget.note == null ? l.newNote : l.titleHint),
              ),
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
                    icon: width < 400 ? const Icon(AppIcons.modeLive) : null,
                    tooltip: l.modeLive,
                  ),
                  ButtonSegment(
                    value: false,
                    label: width < 400 ? null : Text(l.modeSource),
                    icon: width < 400 ? const Icon(AppIcons.modeSource) : null,
                    tooltip: l.modeSource,
                  ),
                ],
                selected: {_body.live},
                onSelectionChanged: (s) => setState(() => _body.live = s.first),
              ),
              // Only an existing note can be deleted.
              if (_id != null)
                IconButton(
                  tooltip: l.delete,
                  icon: const Icon(AppIcons.delete),
                  onPressed: _saving || _deleting ? null : _confirmDelete,
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
          // Title, quote banner and body share one column (Column centers it).
          if (widget.highlight != null)
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: noteColumnWidth),
              child: Container(
                width: double.infinity,
                color: theme.colorScheme.secondaryContainer,
                padding: const EdgeInsets.all(12),
                child: Text(
                  '⚡ “${widget.highlight}”',
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: noteColumnWidth),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: TextField(
                controller: _title,
                style: titleStyle,
                decoration: InputDecoration(
                  hintText: context.l.titleHint,
                  filled: false,
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  disabledBorder: InputBorder.none,
                ),
              ),
            ),
          ),
          // Desktop/tablet: toolbar pinned above the body, on the 680 column.
          if (wide) ...[
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: noteColumnWidth),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: _toolbar(context),
              ),
            ),
            const Divider(height: 1),
          ],
          Expanded(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: noteColumnWidth),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Stack(
                  key: _stackKey,
                  children: [
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
                          if (_barAnchors != null)
                            const SingleActivator(
                              LogicalKeyboardKey.escape,
                            ): () {
                              _barDismissed = _body.selection;
                              _syncBar();
                            },
                        },
                        child: TextField(
                          key: _bodyKey,
                          controller: _body,
                          focusNode: _bodyFocus,
                          scrollController: _bodyScroll,
                          contextMenuBuilder: (context, state) {
                            final sel = state.textEditingValue.selection;
                            return AdaptiveTextSelectionToolbar.buttonItems(
                              anchors: state.contextMenuAnchors,
                              buttonItems: [
                                ...state.contextMenuButtonItems,
                                if (sel.isValid && !sel.isCollapsed)
                                  for (final (tip, _, toggle) in _inlineActions(
                                    context.l,
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
                          textAlignVertical: TextAlignVertical.top,
                          decoration: InputDecoration(
                            hintText: context.l.noteHint,
                            filled: false,
                            border: InputBorder.none,
                            enabledBorder: InputBorder.none,
                            focusedBorder: InputBorder.none,
                            disabledBorder: InputBorder.none,
                          ),
                        ),
                      ),
                    ),
                    if (_barAnchors != null)
                      SelectionMiniBar(
                        anchors: _barAnchors!,
                        actions: _inlineActions(l),
                        onApply: _apply,
                      ),
                  ],
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
                child: _toolbar(context),
              ),
            ),
        ],
      ),
    );
  }
}
