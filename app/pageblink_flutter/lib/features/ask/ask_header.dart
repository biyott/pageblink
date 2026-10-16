import 'package:flutter/material.dart';
import 'package:pageblink_client/pageblink_client.dart';

import '../../app/app_icons.dart';
import '../../app/l10n.dart';
import '../../app/pb_interactive.dart';
import '../../app/theme.dart';
import 'ask_chat.dart';

// The Ask header with the conversation controls (history on):
//   `[Recent v] [+ New chat]`, plus the title on the desktop layout; the
//   recent-chats list (popover / bottom sheet); the question counter.

/// Width of [s] as the Text widgets below draw it (their text scale included).
double _textWidth(BuildContext context, String s, TextStyle style) {
  final p = TextPainter(
    text: TextSpan(
      text: s,
      style: DefaultTextStyle.of(context).style.merge(style),
    ),
    textDirection: Directionality.of(context),
    textScaler: MediaQuery.textScalerOf(context),
    maxLines: 1,
  )..layout();
  final w = p.width;
  p.dispose();
  return w;
}

const _pillText = TextStyle(fontSize: 13, fontWeight: FontWeight.w500);
const _newText = TextStyle(fontSize: 13, fontWeight: FontWeight.w600);

/// `[Recent v] [+ New chat]`. Desktop (>= 1024): the Ask title on the left
/// and the buttons where the old "new question" icon was. Below that there
/// was no header, so a row of just the two buttons. "New chat" folds to its
/// icon when the line is too narrow for both labels.
class AskHeader extends StatelessWidget {
  const AskHeader({
    super.key,
    required this.recentOpen,
    required this.recentAnchor,
    required this.recentFocus,
    required this.onRecent,
    required this.onNew,
  });

  final bool recentOpen;

  /// On the pair of buttons: the popover opens under it.
  final GlobalKey recentAnchor;
  final FocusNode recentFocus;
  final VoidCallback onRecent;
  final VoidCallback onNew;

  @override
  Widget build(BuildContext context) {
    final l = context.l;
    final pb = context.pb;
    final desktop = pbDesktop(context);
    final h = desktop ? 36.0 : 40.0;
    final title = Theme.of(
      context,
    ).textTheme.headlineMedium?.copyWith(fontSize: 28);
    return Padding(
      padding: desktop
          ? const EdgeInsets.fromLTRB(20, 18, 12, 4)
          : const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: LayoutBuilder(
        builder: (context, box) {
          // pill = 12 + icon 16 + 6 + label (+ 4 + chevron 16) + 12, +2 border.
          final recentW =
              _textWidth(context, l.recentShort, _pillText) +
              12 +
              16 +
              6 +
              4 +
              16 +
              12 +
              2;
          final newW =
              _textWidth(context, l.newConversation, _newText) +
              12 +
              16 +
              6 +
              12 +
              2;
          final titleW = desktop
              ? 26 + 6 + _textWidth(context, l.tabAsk, title!) + 8
              : 0.0;
          final iconOnly = titleW + recentW + 8 + newW + 2 > box.maxWidth;
          // Still too tight (a huge text size): the title goes, it only
          // repeats the tab name.
          final showTitle =
              desktop && titleW + recentW + 8 + h + 2 <= box.maxWidth;
          return Row(
            children: [
              if (showTitle) ...[
                Icon(AppIcons.ask, size: 26, color: pb.accent),
                const SizedBox(width: 6),
                Text(l.tabAsk, style: title),
              ],
              // The pair is the popover's anchor: it opens under both and, on
              // the desktop layout, ends at the pair's right edge.
              Expanded(
                child: Align(
                  alignment: desktop
                      ? Alignment.centerRight
                      : Alignment.centerLeft,
                  child: Row(
                    key: recentAnchor,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Flexible(
                        child: _RecentButton(
                          height: h,
                          open: recentOpen,
                          focus: recentFocus,
                          onTap: onRecent,
                        ),
                      ),
                      const SizedBox(width: 8),
                      _NewButton(height: h, iconOnly: iconOnly, onTap: onNew),
                    ],
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

class _RecentButton extends StatelessWidget {
  const _RecentButton({
    required this.height,
    required this.open,
    required this.focus,
    required this.onTap,
  });

  final double height;
  final bool open;
  final FocusNode focus;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l = context.l;
    final pb = context.pb;
    return PbInteractive(
      key: const ValueKey('ask-recent'),
      onTap: onTap,
      radius: 999,
      focusNode: focus,
      minHit: Size(0, pbTarget(context)),
      expanded: open,
      label: l.recentChats,
      builder: (context, states) => AnimatedContainer(
        duration: pbFast(context),
        height: height,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: Color.alphaBlend(
            pbTint(pb, states, pressed: open),
            pb.chipBg,
          ),
          border: Border.all(
            color: states.contains(WidgetState.hovered) || open
                ? pb.ink.withValues(alpha: 0.28)
                : pb.hairline,
          ),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(AppIcons.history, size: 16),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                l.recentShort,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: _pillText,
              ),
            ),
            const SizedBox(width: 4),
            AnimatedRotation(
              turns: open ? 0.5 : 0,
              duration: pbFast(context),
              child: const Icon(AppIcons.expand, size: 16),
            ),
          ],
        ),
      ),
    );
  }
}

class _NewButton extends StatelessWidget {
  const _NewButton({
    required this.height,
    required this.iconOnly,
    required this.onTap,
  });

  final double height;
  final bool iconOnly;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l = context.l;
    final pb = context.pb;
    final button = PbInteractive(
      key: const ValueKey('ask-new-chat'),
      onTap: onTap,
      radius: 999,
      minHit: Size(iconOnly ? pbTarget(context) : 0, pbTarget(context)),
      label: l.newConversation,
      builder: (context, states) => AnimatedContainer(
        duration: pbFast(context),
        height: height,
        width: iconOnly ? height : null,
        alignment: Alignment.center,
        padding: iconOnly ? null : const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: Color.alphaBlend(pbTint(pb, states), pb.accentContainer),
          borderRadius: BorderRadius.circular(999),
        ),
        child: DefaultTextStyle.merge(
          style: _newText.copyWith(color: pb.onAccentContainer),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(AppIcons.newQuestion, size: 16, color: pb.onAccentContainer),
              if (!iconOnly) ...[
                const SizedBox(width: 6),
                Text(l.newConversation, maxLines: 1),
              ],
            ],
          ),
        ),
      ),
    );
    if (!iconOnly) return button;
    return Tooltip(
      message: l.newConversation,
      excludeFromSemantics: true,
      child: button,
    );
  }
}

// ── The question counter (under the input, opposite the model pill) ───────

/// `Question 3/10`; from 8 of 10 on `⚠ Question 8/10 · 2 left` in the warn
/// colour. Plain text: it is not a button.
class AskCounter extends StatelessWidget {
  const AskCounter({super.key, required this.chat});

  final AskChat chat;

  static bool shows(AskChat c) {
    final n = c.count, m = c.limit ?? c.status?.questionLimit;
    return c.on && n != null && m != null && n >= 1;
  }

  @override
  Widget build(BuildContext context) {
    if (!shows(chat)) return const SizedBox.shrink();
    final l = context.l;
    final pb = context.pb;
    final n = chat.count!, m = chat.limit ?? chat.status!.questionLimit;
    final close = chat.level >= 1;
    final reached = chat.level >= 2;
    final color = close ? pb.warnText : pb.inkMuted;
    return Semantics(
      label: l.askCountLabel(n, m),
      excludeSemantics: true,
      child: Row(
        key: const ValueKey('ask-count'),
        mainAxisSize: MainAxisSize.min,
        children: [
          if (close) ...[
            Icon(AppIcons.warning, size: 14, color: color),
            const SizedBox(width: 4),
          ],
          Flexible(
            child: Text(
              l.askCount(n, m) +
                  (close && !reached ? ' · ${l.askCountLeft(m - n)}' : ''),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: close ? 13 : 12,
                color: color,
                fontWeight: close ? FontWeight.w700 : FontWeight.w400,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Recent chats: popover entry and the list itself ───────────────────────

/// The whole popover content as one menu entry ([pbShowMenu] shows it; a row
/// is a [PbInteractive] with its own two tab stops, not a menu item). A pick
/// pops with the chosen id.
class AskRecentMenuEntry extends PopupMenuEntry<int> {
  const AskRecentMenuEntry({super.key, required this.chat});

  final AskChat chat;

  @override
  double get height => 56;

  @override
  bool represents(int? value) => false;

  @override
  State<AskRecentMenuEntry> createState() => _AskRecentMenuEntryState();
}

class _AskRecentMenuEntryState extends State<AskRecentMenuEntry> {
  @override
  Widget build(BuildContext context) => AskRecentList(chat: widget.chat);
}

/// Title, the recent conversations (current one marked, "hide" with an
/// in-row confirmation), and the footer. Repaints when the chat changes.
/// [sheet]: the bottom sheet (touch): taller rows, hide always shown.
class AskRecentList extends StatefulWidget {
  const AskRecentList({super.key, required this.chat, this.sheet = false});

  final AskChat chat;
  final bool sheet;

  @override
  State<AskRecentList> createState() => _AskRecentListState();
}

class _AskRecentListState extends State<AskRecentList> {
  /// The row asking "hide this chat?".
  int? _confirm;
  final _select = <int, FocusNode>{};
  final _hide = <int, FocusNode>{};
  bool _focused = false;

  AskChat get _chat => widget.chat;

  FocusNode _node(Map<int, FocusNode> m, int id) =>
      m.putIfAbsent(id, FocusNode.new);

  @override
  void dispose() {
    for (final n in [..._select.values, ..._hide.values]) {
      n.dispose();
    }
    super.dispose();
  }

  /// Keyboard and screen reader land on the current row (or the first).
  void _focusFirst(int id) {
    if (_focused) return;
    _focused = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _select[id]?.requestFocus();
    });
  }

  Future<void> _confirmHide(AskSessionSummary s) async {
    final wasCurrent = s.id == _chat.sessionId;
    setState(() => _confirm = null);
    final nav = Navigator.of(context);
    // From the keyboard: focus goes on to the open (or first) row.
    if (pbKeyboardMode) _focused = false;
    await _chat.hideSession(s.id);
    // Hiding the open chat started a new one: nothing left to look at here.
    if (wasCurrent && _chat.sessionId != s.id && mounted) nav.pop();
  }

  void _cancel(int id) {
    setState(() => _confirm = null);
    if (pbKeyboardMode) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _hide[id]?.requestFocus();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l;
    final pb = context.pb;
    return ListenableBuilder(
      listenable: _chat,
      builder: (context, _) {
        final minutes = _chat.status?.visibleMinutes ?? 0;
        final days = _chat.status?.retentionDays ?? 0;
        final limit = _chat.status?.questionLimit ?? _chat.limit ?? 0;
        final now = DateTime.now().toUtc();
        final recent = _chat.recent;
        final target = recent.any((s) => s.id == _chat.sessionId)
            ? _chat.sessionId
            : recent.firstOrNull?.id;
        if (target != null) _focusFirst(target);
        return SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Semantics(
                header: true,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                  child: Text(
                    l.recentChats,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: pb.inkMuted,
                    ),
                  ),
                ),
              ),
              if (recent.isEmpty)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                  child: Column(
                    children: [
                      Icon(AppIcons.history, size: 22, color: pb.inkMuted),
                      const SizedBox(height: 8),
                      Text(
                        l.recentChatsEmpty(minutes),
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        l.recentChatsNote(minutes),
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 12, color: pb.inkMuted),
                      ),
                    ],
                  ),
                ),
              for (final s in recent)
                AnimatedSwitcher(
                  duration: pbFast(context),
                  child: _confirm == s.id
                      ? _HideConfirm(
                          key: ValueKey('confirm-${s.id}'),
                          title: s.title,
                          current: s.id == _chat.sessionId,
                          touch: widget.sheet,
                          onHide: () => _confirmHide(s),
                          onCancel: () => _cancel(s.id),
                        )
                      : _RecentRow(
                          key: ValueKey('recent-${s.id}'),
                          title: s.title,
                          count: s.questionCount,
                          limit: limit,
                          minutesAgo: now
                              .difference(s.lastActiveAt.toUtc())
                              .inMinutes,
                          current: s.id == _chat.sessionId,
                          sheet: widget.sheet,
                          selectFocus: _node(_select, s.id),
                          hideFocus: _node(_hide, s.id),
                          onPick: () => Navigator.of(context).pop(s.id),
                          onHide: () => setState(() => _confirm = s.id),
                        ),
                ),
              Container(
                margin: const EdgeInsets.only(top: 4),
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                decoration: BoxDecoration(
                  border: Border(top: BorderSide(color: pb.hairline)),
                ),
                child: Text(
                  l.recentFooter(minutes, days),
                  style: TextStyle(fontSize: 12, color: pb.inkMuted),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// One conversation: the pick area, and "hide" beside it (shown on hover or
/// focus, and always for the current row and on touch layouts). Its face is
/// the row's own decoration (current = accent container); states are drawn
/// into the two controls.
class _RecentRow extends StatefulWidget {
  const _RecentRow({
    super.key,
    required this.title,
    required this.count,
    required this.limit,
    required this.minutesAgo,
    required this.current,
    required this.sheet,
    required this.selectFocus,
    required this.hideFocus,
    required this.onPick,
    required this.onHide,
  });

  final String title;
  final int count, limit, minutesAgo;
  final bool current, sheet;
  final FocusNode selectFocus, hideFocus;
  final VoidCallback onPick, onHide;

  @override
  State<_RecentRow> createState() => _RecentRowState();
}

class _RecentRowState extends State<_RecentRow> {
  bool _hover = false, _within = false;

  @override
  Widget build(BuildContext context) {
    final l = context.l;
    final pb = context.pb;
    final w = widget;
    final touch = w.sheet || !pbDesktop(context);
    final side = touch ? 44.0 : 36.0;
    final minH = w.sheet ? 64.0 : 56.0;
    final close = w.limit > 0 && w.limit - w.count <= 2;
    final meta = l.chatMeta(w.count, w.limit, w.minutesAgo);
    final ink = w.current ? pb.onAccentContainer : pb.ink;
    final muted = w.current ? pb.onAccentContainer : pb.inkMuted;
    final showHide = touch || w.current || _hover || _within;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: w.current ? pb.accentContainer : null,
        borderRadius: BorderRadius.circular(12),
      ),
      // Room for the 2px ring + 2px gap around the controls inside the face.
      padding: const EdgeInsets.all(4),
      child: MouseRegion(
        onEnter: (_) => setState(() => _hover = true),
        onExit: (_) => setState(() => _hover = false),
        child: Focus(
          canRequestFocus: false,
          skipTraversal: true,
          includeSemantics: false,
          onFocusChange: (f) => setState(() => _within = f),
          child: Row(
            children: [
              Expanded(
                child: PbInteractive(
                  onTap: w.onPick,
                  radius: 10,
                  expand: true,
                  focusNode: w.selectFocus,
                  selected: w.current,
                  minHit: Size(0, minH - 8),
                  label: l.chatRowLabel(w.title, meta, w.current),
                  builder: (context, states) => AnimatedContainer(
                    duration: pbFast(context),
                    constraints: BoxConstraints(minHeight: minH - 8),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: pbTint(pb, states),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(
                          width: 20,
                          child: w.current
                              ? Padding(
                                  padding: const EdgeInsets.only(top: 1),
                                  child: Icon(
                                    AppIcons.check,
                                    size: 16,
                                    color: ink,
                                  ),
                                )
                              : null,
                        ),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                w.title,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 14,
                                  height: 1.3,
                                  fontWeight: w.current
                                      ? FontWeight.w700
                                      : FontWeight.w500,
                                  color: ink,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Wrap(
                                spacing: 4,
                                crossAxisAlignment: WrapCrossAlignment.center,
                                children: [
                                  if (w.current) ...[
                                    Text(
                                      l.currentChat,
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w700,
                                        color: ink,
                                      ),
                                    ),
                                    Text(
                                      '·',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: muted,
                                      ),
                                    ),
                                  ],
                                  if (close)
                                    Icon(
                                      AppIcons.warning,
                                      size: 13,
                                      color: pb.warnText,
                                    ),
                                  Text(
                                    meta,
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: close
                                          ? FontWeight.w600
                                          : FontWeight.w400,
                                      color: close ? pb.warnText : muted,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 4),
              AnimatedOpacity(
                opacity: showHide ? 1 : 0,
                duration: pbFast(context),
                // Hidden, not removed: Tab and the screen reader still get it.
                alwaysIncludeSemantics: true,
                child: Tooltip(
                  message: l.hideFromList,
                  excludeFromSemantics: true,
                  child: PbInteractive(
                    onTap: w.onHide,
                    radius: 999,
                    focusNode: w.hideFocus,
                    minHit: Size.square(side),
                    label: l.hideFromListTitle(w.title),
                    builder: (context, states) => Container(
                      width: side,
                      height: side,
                      decoration: BoxDecoration(
                        color: pbTint(pb, states),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(AppIcons.hideChat, size: 18, color: muted),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// "Hide this chat?" in the row itself. The server can only hide, not bring
/// back, so it asks once. Cancel has the focus; Esc, Cancel, or focus moving
/// out of the row all cancel.
class _HideConfirm extends StatefulWidget {
  const _HideConfirm({
    super.key,
    required this.title,
    required this.current,
    required this.touch,
    required this.onHide,
    required this.onCancel,
  });

  final String title;
  final bool current, touch;
  final VoidCallback onHide, onCancel;

  @override
  State<_HideConfirm> createState() => _HideConfirmState();
}

class _HideConfirmState extends State<_HideConfirm> {
  final _cancelFocus = FocusNode(debugLabel: 'hide-cancel');

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _cancelFocus.requestFocus();
    });
  }

  @override
  void dispose() {
    _cancelFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l;
    final pb = context.pb;
    final w = widget;
    final h = w.touch || !pbDesktop(context) ? 44.0 : 36.0;
    Widget pill({
      required String text,
      required VoidCallback onTap,
      required bool filled,
      Key? key,
      FocusNode? focus,
    }) => PbInteractive(
      key: key,
      onTap: onTap,
      radius: 999,
      focusNode: focus,
      minHit: Size(0, h),
      builder: (context, states) => AnimatedContainer(
        duration: pbFast(context),
        height: h > 40 ? 40 : 34,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: filled
              ? Color.alphaBlend(pbTint(pb, states, filled: true), pb.warnText)
              : Color.alphaBlend(pbTint(pb, states), Colors.transparent),
          border: filled ? null : Border.all(color: pb.warnBorder),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          text,
          maxLines: 1,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: filled ? pb.warnContainer : pb.warnText,
          ),
        ),
      ),
    );
    return Actions(
      actions: {
        DismissIntent: CallbackAction<DismissIntent>(
          onInvoke: (_) {
            w.onCancel();
            return null;
          },
        ),
      },
      child: Focus(
        canRequestFocus: false,
        skipTraversal: true,
        includeSemantics: false,
        onFocusChange: (f) {
          if (!f) w.onCancel();
        },
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          padding: const EdgeInsets.fromLTRB(14, 10, 10, 10),
          decoration: BoxDecoration(
            color: pb.warnContainer,
            border: Border.all(color: pb.warnBorder),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                w.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: pb.warnText,
                ),
              ),
              const SizedBox(height: 2),
              Semantics(
                liveRegion: true,
                child: Text(
                  w.current ? l.hideAskCurrent : l.hideAsk,
                  style: TextStyle(fontSize: 13, color: pb.warnText),
                ),
              ),
              const SizedBox(height: 6),
              Align(
                alignment: Alignment.centerRight,
                child: Wrap(
                  spacing: 8,
                  children: [
                    pill(
                      key: const ValueKey('hide-cancel'),
                      text: l.cancel,
                      onTap: w.onCancel,
                      filled: false,
                      focus: _cancelFocus,
                    ),
                    pill(
                      key: const ValueKey('hide-confirm'),
                      text: l.hide,
                      onTap: w.onHide,
                      filled: true,
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
