import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app/app_icons.dart';
import '../../app/l10n.dart';
import '../../app/theme.dart';

const _gap = 6.0;
const _width = 360.0;

/// Puts its child just below the link (above if there is no room), centred on
/// it and clamped into the stack; fills the stack but takes pointer events only
/// on the child. The child is in a [TextFieldTapRegion] (same group as the
/// note body), so a press on it is a tap *inside* the field: desktop and web
/// do not run the field's tap-outside `unfocus` and the popover is not removed
/// between pointer down and up (same reason as the mini bar).
class _Below extends StatelessWidget {
  const _Below({required this.anchors, required this.child});

  final TextSelectionToolbarAnchors anchors;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final pb = context.pb;
    return Positioned.fill(
      child: CustomSingleChildLayout(
        delegate: _BelowDelegate(anchors),
        child: TextFieldTapRegion(
          child: Semantics(
            container: true,
            label: context.l.fmtLink,
            child: Material(
              elevation: 3,
              borderRadius: BorderRadius.circular(10),
              color: Theme.of(context).colorScheme.surfaceContainerHigh,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: pb.hairline),
                ),
                child: child,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _BelowDelegate extends SingleChildLayoutDelegate {
  _BelowDelegate(this.anchors);

  final TextSelectionToolbarAnchors anchors;

  @override
  BoxConstraints getConstraintsForChild(BoxConstraints c) => BoxConstraints(
    maxWidth: math.min(_width, c.maxWidth),
    maxHeight: c.maxHeight,
  );

  @override
  Offset getPositionForChild(Size size, Size child) {
    final x = (anchors.primaryAnchor.dx - child.width / 2)
        .clamp(0.0, math.max(0.0, size.width - child.width))
        .toDouble();
    final below = (anchors.secondaryAnchor ?? anchors.primaryAnchor).dy + _gap;
    if (below + child.height <= size.height) return Offset(x, below);
    final above = anchors.primaryAnchor.dy - _gap - child.height;
    if (above >= 0) return Offset(x, above);
    return Offset(
      x,
      below.clamp(0.0, math.max(0.0, size.height - child.height)).toDouble(),
    );
  }

  @override
  bool shouldRelayout(_BelowDelegate old) =>
      old.anchors.primaryAnchor != anchors.primaryAnchor ||
      old.anchors.secondaryAnchor != anchors.secondaryAnchor;
}

/// The popover of a link under the caret: its address on one line and icon
/// buttons open / copy / edit / remove. An address the app will not open
/// (`javascript:` ...) shows with [openEnabled] false and a warning; nothing
/// ever opens it. Buttons never take focus, so the body keeps its caret.
class LinkPopover extends StatefulWidget {
  const LinkPopover({
    super.key,
    required this.anchors,
    required this.url,
    required this.openEnabled,
    required this.canRemove,
    required this.onOpen,
    required this.onEdit,
    required this.onRemove,
  });

  final TextSelectionToolbarAnchors anchors;
  final String url;
  final bool openEnabled;

  /// False for autolinks: they have no markers to take off.
  final bool canRemove;
  final VoidCallback onOpen, onEdit, onRemove;

  @override
  State<LinkPopover> createState() => _LinkPopoverState();
}

class _LinkPopoverState extends State<LinkPopover> {
  Timer? _timer;
  bool _copied = false;

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _copy() async {
    try {
      await Clipboard.setData(ClipboardData(text: widget.url));
    } catch (e) {
      debugPrint('copy link failed: $e');
      return;
    }
    if (!mounted) return;
    setState(() => _copied = true);
    _timer?.cancel();
    _timer = Timer(const Duration(milliseconds: 1500), () {
      if (mounted) setState(() => _copied = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l;
    final theme = Theme.of(context);
    final pb = context.pb;
    Widget button(String tip, IconData icon, VoidCallback? onTap, {Key? key}) =>
        IconButton(
          key: key,
          tooltip: tip,
          icon: Icon(icon, size: 18),
          visualDensity: VisualDensity.compact,
          constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
          padding: EdgeInsets.zero,
          onPressed: onTap,
        );
    return _Below(
      anchors: widget.anchors,
      child: ExcludeFocus(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 4, 4, 4),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Tooltip(
                      message: widget.url,
                      child: Text(
                        widget.url.isEmpty ? '—' : widget.url,
                        key: const ValueKey('link-url'),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: pb.inkMuted,
                        ),
                      ),
                    ),
                  ),
                  button(
                    l.openLink,
                    AppIcons.openLink,
                    widget.openEnabled ? widget.onOpen : null,
                    key: const ValueKey('link-open'),
                  ),
                  button(
                    l.linkCopy,
                    _copied ? AppIcons.check : AppIcons.copy,
                    _copy,
                    key: const ValueKey('link-copy'),
                  ),
                  button(
                    l.linkEdit,
                    AppIcons.edit,
                    widget.onEdit,
                    key: const ValueKey('link-edit'),
                  ),
                  button(
                    l.linkRemove,
                    AppIcons.unlink,
                    widget.canRemove ? widget.onRemove : null,
                    key: const ValueKey('link-remove'),
                  ),
                ],
              ),
              if (!widget.openEnabled)
                Padding(
                  padding: const EdgeInsets.only(bottom: 6, right: 8),
                  child: Row(
                    children: [
                      Icon(
                        AppIcons.warning,
                        size: 14,
                        color: theme.colorScheme.error,
                      ),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          l.linkUnsafe,
                          key: const ValueKey('link-unsafe'),
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.error,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Edit mode of the popover: two inputs (text, address), Enter applies, Esc or
/// leaving the popover cancels. The inputs take the focus; the note body keeps
/// its selection and caret (they live in its controller), so nothing is lost.
/// [prefill] may complete later with an address to put in the empty field
/// (the clipboard); its failure is the caller's to ignore.
class LinkEditPopover extends StatefulWidget {
  const LinkEditPopover({
    super.key,
    required this.anchors,
    required this.initialText,
    required this.initialUrl,
    required this.onApply,
    required this.onCancel,
    required this.onLeave,
    this.prefill,
  });

  final TextSelectionToolbarAnchors anchors;
  final String initialText, initialUrl;
  final Future<String?>? prefill;
  final void Function(String text, String url) onApply;

  /// Esc or the Cancel button.
  final VoidCallback onCancel;

  /// The focus left the popover (the user went elsewhere).
  final VoidCallback onLeave;

  @override
  State<LinkEditPopover> createState() => _LinkEditPopoverState();
}

/// What a new link's address field starts with; left as it is, it is no
/// address at all ([_blank]).
const _urlDefault = 'https://';

bool _blank(String url) {
  final u = url.trim().toLowerCase();
  return u.isEmpty || u == _urlDefault || u == 'http://';
}

class _LinkEditPopoverState extends State<LinkEditPopover> {
  late final _text = TextEditingController(text: widget.initialText);
  late final _url = TextEditingController(
    text: widget.initialUrl.isEmpty ? _urlDefault : widget.initialUrl,
  );
  final _textFocus = FocusNode();
  final _urlFocus = FocusNode();
  bool _hadFocus = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _urlFocus.requestFocus();
      // Default `https://`: caret behind it, ready to type. An address being
      // edited is selected whole, to replace it. (A frame later: gaining
      // focus on desktop selects all, and must not win.)
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        if (widget.initialUrl.isEmpty) {
          // not when the clipboard address already came in (selected)
          if (_url.text == _urlDefault) {
            _url.selection = TextSelection.collapsed(offset: _url.text.length);
          }
        } else {
          _url.selection = TextSelection(
            baseOffset: 0,
            extentOffset: _url.text.length,
          );
        }
      });
      WidgetsBinding.instance.scheduleFrame();
    });
    widget.prefill?.then((u) {
      if (!mounted || u == null || _url.text != _urlDefault) return;
      _url.value = TextEditingValue(
        text: u,
        selection: TextSelection(baseOffset: 0, extentOffset: u.length),
      );
    }, onError: (_) {});
  }

  @override
  void dispose() {
    _text.dispose();
    _url.dispose();
    _textFocus.dispose();
    _urlFocus.dispose();
    super.dispose();
  }

  void _apply() {
    final url = _url.text.trim();
    if (_blank(url)) {
      _urlFocus.requestFocus();
      return;
    }
    widget.onApply(_text.text, url);
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l;
    InputDecoration deco(String label) => InputDecoration(
      isDense: true,
      labelText: label,
      border: const OutlineInputBorder(),
      enabledBorder: const OutlineInputBorder(),
      focusedBorder: const OutlineInputBorder(),
    );
    return _Below(
      anchors: widget.anchors,
      child: CallbackShortcuts(
        bindings: {
          const SingleActivator(LogicalKeyboardKey.escape): widget.onCancel,
        },
        child: Focus(
          canRequestFocus: false,
          skipTraversal: true,
          onFocusChange: (has) {
            if (has) {
              _hadFocus = true;
            } else if (_hadFocus) {
              widget.onLeave();
            }
          },
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextField(
                  key: const ValueKey('link-text-field'),
                  controller: _text,
                  focusNode: _textFocus,
                  decoration: deco(l.linkText),
                  textInputAction: TextInputAction.next,
                  onSubmitted: (_) => _apply(),
                ),
                const SizedBox(height: 8),
                TextField(
                  key: const ValueKey('link-url-field'),
                  controller: _url,
                  focusNode: _urlFocus,
                  decoration: deco(l.linkUrl),
                  keyboardType: TextInputType.url,
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => _apply(),
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      key: const ValueKey('link-cancel'),
                      onPressed: widget.onCancel,
                      child: Text(l.cancel),
                    ),
                    const SizedBox(width: 4),
                    ListenableBuilder(
                      listenable: _url,
                      builder: (context, _) => FilledButton(
                        key: const ValueKey('link-apply'),
                        onPressed: _blank(_url.text) ? null : _apply,
                        child: Text(l.ok),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
