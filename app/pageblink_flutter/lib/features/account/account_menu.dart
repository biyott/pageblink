import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:serverpod_auth_idp_flutter/serverpod_auth_idp_flutter.dart';

import '../../app/app_icons.dart';
import '../../app/l10n.dart';
import '../../app/pb_interactive.dart';
import '../../app/theme.dart';
import '../../client.dart';
import '../demo/demo.dart';
import 'account.dart';

/// Test hook: replaces `client.auth.signOutDevice()`.
@visibleForTesting
Future<void> Function()? signOutCall;

/// Signing out replaces the whole HomeShell, so nothing else needs closing.
Future<void> signOut() => (signOutCall ?? client.auth.signOutDevice)();

/// Rebuilds with who is signed in. A demo account (either source says so) has
/// no email to show.
class AccountListener extends StatelessWidget {
  const AccountListener({super.key, required this.builder});

  final Widget Function(BuildContext context, String? email, bool demo) builder;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: Listenable.merge([accountInfo, demoStatus]),
    builder: (context, _) {
      final demo =
          (accountInfo.value?.isDemo ?? false) ||
          (demoStatus.value?.isDemo ?? false);
      return builder(context, demo ? null : accountInfo.value?.email, demo);
    },
  );
}

/// Name shown for the account: the email, "My account" while it is unknown,
/// "Demo account" for the shared demo.
String accountLabel(L l, String? email, bool demo) =>
    demo ? l.demoAccount : (email ?? l.myAccount);

/// Round avatar: the email's first letter, a person while it is unknown, the
/// brand star for the demo account.
class AccountAvatar extends StatelessWidget {
  const AccountAvatar({
    super.key,
    required this.size,
    required this.email,
    required this.demo,
  });

  final double size;
  final String? email;
  final bool demo;

  @override
  Widget build(BuildContext context) {
    final pb = context.pb;
    final initial = demo ? null : accountInitial(email);
    final glyph = size * 0.5;
    return ExcludeSemantics(
      child: Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: pb.accentContainer,
          shape: BoxShape.circle,
        ),
        child: initial != null
            ? Text(
                initial,
                style: TextStyle(
                  fontSize: size >= 40 ? 18 : 14,
                  fontWeight: FontWeight.w600,
                  color: pb.onAccentContainer,
                  height: 1,
                ),
              )
            : Icon(
                demo ? AppIcons.brand : AppIcons.account,
                size: glyph,
                color: pb.onAccentContainer,
              ),
      ),
    );
  }
}

/// "Shared account" pill of the demo account.
class SharedAccountChip extends StatelessWidget {
  const SharedAccountChip({super.key});

  @override
  Widget build(BuildContext context) {
    final pb = context.pb;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: pb.tile,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        context.l.sharedAccount,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(fontSize: 11, height: 1.3, color: pb.inkMuted),
      ),
    );
  }
}

/// Avatar + "Signed in as" + the account name (and the shared chip for the
/// demo account): header of the menu, the sheet and the settings group.
class AccountIdentity extends StatelessWidget {
  const AccountIdentity({super.key, required this.avatarSize});

  final double avatarSize;

  @override
  Widget build(BuildContext context) {
    final l = context.l;
    final pb = context.pb;
    return AccountListener(
      builder: (context, email, demo) => Row(
        children: [
          AccountAvatar(size: avatarSize, email: email, demo: demo),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l.accountSignedInAs,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    height: 1.3,
                    color: pb.inkMuted,
                  ),
                ),
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        accountLabel(l, email, demo),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 14,
                          height: 1.3,
                          fontWeight: FontWeight.w600,
                          color: pb.ink,
                        ),
                      ),
                    ),
                    if (demo) ...[
                      const SizedBox(width: 8),
                      const Flexible(child: SharedAccountChip()),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── The menu (desktop, tablet) and the sheet (phone) ──────────────────────

enum _Act { signUp, signOut }

const _menuWidth = 272.0;
// PopupMenu pads 8 above and below its items.
const _menuPad = 16.0;

/// A non-selectable block inside a popup menu (a header, a divider).
class _MenuBlock extends PopupMenuEntry<_Act> {
  const _MenuBlock({required this.height, required this.child});

  @override
  final double height;
  final Widget child;

  @override
  bool represents(_Act? value) => false;

  @override
  State<_MenuBlock> createState() => _MenuBlockState();
}

class _MenuBlockState extends State<_MenuBlock> {
  @override
  Widget build(BuildContext context) => widget.child;
}

TextStyle _noteStyle(BuildContext context) =>
    TextStyle(fontSize: 12, height: 1.4, color: context.pb.inkMuted);

Widget _demoNote(BuildContext context) =>
    Text(context.l.demoPrivacyNote, style: _noteStyle(context));

Widget _rowContent(
  BuildContext context,
  IconData icon,
  String text, {
  Color? color,
  FontWeight weight = FontWeight.w500,
}) {
  final c = color ?? context.pb.ink;
  return Row(
    children: [
      Icon(icon, size: 20, color: c),
      const SizedBox(width: 12),
      Expanded(
        child: Text(
          text,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(fontSize: 14, fontWeight: weight, color: c),
        ),
      ),
    ],
  );
}

/// Opens the account menu at [anchor] (the drawn control): over it
/// ([above], the sidebar's bottom row) or under it, right edges aligned (the
/// AppBar avatar).
Future<void> showAccountMenu(
  BuildContext context,
  GlobalKey anchor, {
  required bool above,
}) async {
  final box = anchor.currentContext?.findRenderObject();
  final overlay = Navigator.of(context).overlay?.context.findRenderObject();
  if (box is! RenderBox || overlay is! RenderBox) return;
  final l = context.l;
  final demo =
      (accountInfo.value?.isDemo ?? false) ||
      (demoStatus.value?.isDemo ?? false);

  // Items have fixed heights so that an upward menu can end right above the
  // anchor: showMenu only knows where the top edge goes.
  var headerHeight = 72.0;
  if (demo) {
    final note = TextPainter(
      text: TextSpan(text: l.demoPrivacyNote, style: _noteStyle(context)),
      textDirection: Directionality.of(context),
      textScaler: MediaQuery.textScalerOf(context),
    )..layout(maxWidth: _menuWidth - 32);
    headerHeight = 16 + 40 + 10 + note.height + 16;
    note.dispose();
  }
  final items = <PopupMenuEntry<_Act>>[
    _MenuBlock(
      height: headerHeight,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: demo
            ? Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const AccountIdentity(avatarSize: 40),
                  const SizedBox(height: 10),
                  _demoNote(context),
                ],
              )
            : const AccountIdentity(avatarSize: 40),
      ),
    ),
    const _MenuBlock(height: 1, child: Divider(height: 1)),
    if (demo)
      PopupMenuItem<_Act>(
        value: _Act.signUp,
        height: 44,
        child: _rowContent(
          context,
          AppIcons.invite,
          l.demoSignUp,
          color: context.pb.linkInk,
          weight: FontWeight.w600,
        ),
      ),
    PopupMenuItem<_Act>(
      value: _Act.signOut,
      height: 44,
      child: _rowContent(context, AppIcons.signOut, l.signOut),
    ),
  ];
  final height = _menuPad + items.fold<double>(0, (h, e) => h + e.height);

  final topLeft = box.localToGlobal(Offset.zero, ancestor: overlay);
  final bottomRight = box.localToGlobal(
    box.size.bottomRight(Offset.zero),
    ancestor: overlay,
  );
  final left = above ? topLeft.dx : bottomRight.dx - _menuWidth;
  final top = above ? topLeft.dy - 8 - height : bottomRight.dy + 4;
  final picked = await showMenu<_Act>(
    context: context,
    position: RelativeRect.fromRect(
      Rect.fromLTWH(left, math.max(top, 8), 0, 0),
      Offset.zero & overlay.size,
    ),
    items: items,
    constraints: const BoxConstraints.tightFor(width: _menuWidth),
  );
  await _run(picked);
}

Future<void> _run(_Act? act) async {
  switch (act) {
    case _Act.signUp:
      await demoSignUp();
    case _Act.signOut:
      await signOut();
    case null:
  }
}

/// Phone: the same content as a bottom sheet (avatar 48, rows 56).
Future<void> showAccountSheet(BuildContext context) async {
  final pb = context.pb;
  final act = await showModalBottomSheet<_Act>(
    context: context,
    showDragHandle: true,
    backgroundColor: Color.alphaBlend(pb.sheet, pb.pdfPaper),
    builder: (sheet) {
      final l = sheet.l;
      return SafeArea(
        child: AccountListener(
          builder: (context, email, demo) => Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const AccountIdentity(avatarSize: 48),
                    if (demo) ...[
                      const SizedBox(height: 12),
                      _demoNote(context),
                    ],
                  ],
                ),
              ),
              const Divider(height: 1),
              if (demo)
                ListTile(
                  minTileHeight: 56,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 20),
                  title: _rowContent(
                    context,
                    AppIcons.invite,
                    l.demoSignUp,
                    color: pb.linkInk,
                    weight: FontWeight.w600,
                  ),
                  onTap: () => Navigator.pop(sheet, _Act.signUp),
                ),
              ListTile(
                minTileHeight: 56,
                contentPadding: const EdgeInsets.symmetric(horizontal: 20),
                title: _rowContent(context, AppIcons.signOut, l.signOut),
                onTap: () => Navigator.pop(sheet, _Act.signOut),
              ),
            ],
          ),
        ),
      );
    },
  );
  await _run(act);
}

// ── Where the menu is opened from ─────────────────────────────────────────

/// Desktop sidebar's bottom row: avatar, account name, chevron (52 high).
class AccountRow extends StatefulWidget {
  const AccountRow({super.key});

  @override
  State<AccountRow> createState() => _AccountRowState();
}

class _AccountRowState extends State<AccountRow> {
  final _anchor = GlobalKey();
  bool _open = false;

  Future<void> _show() async {
    setState(() => _open = true);
    try {
      await showAccountMenu(context, _anchor, above: true);
    } finally {
      if (mounted) setState(() => _open = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l;
    final pb = context.pb;
    return AccountListener(
      builder: (context, email, demo) {
        final name = accountLabel(l, email, demo);
        return Tooltip(
          message: l.account,
          child: PbInteractive(
            onTap: _show,
            radius: 14,
            pressScale: 0.985,
            expand: true,
            minHit: const Size(0, 52),
            expanded: _open,
            label: l.accountMenuSemantics(name),
            builder: (context, states) => AnimatedContainer(
              key: _anchor,
              duration: pbFast(context),
              height: 52,
              padding: const EdgeInsets.symmetric(horizontal: 10),
              decoration: BoxDecoration(
                color: pbTint(pb, states, pressed: _open),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                children: [
                  AccountAvatar(size: 32, email: email, demo: demo),
                  const SizedBox(width: 10),
                  Expanded(
                    child: demo
                        ? Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: _nameStyle(pb),
                              ),
                              const Align(
                                alignment: Alignment.centerLeft,
                                child: SharedAccountChip(),
                              ),
                            ],
                          )
                        : Text(
                            name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: _nameStyle(pb),
                          ),
                  ),
                  const SizedBox(width: 4),
                  // The menu opens upward.
                  Transform.rotate(
                    angle: math.pi,
                    child: Icon(AppIcons.expand, size: 16, color: pb.inkMuted),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  TextStyle _nameStyle(Pb pb) =>
      TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: pb.ink);
}

/// AppBar (below 1024): a 32 avatar in a 48 target. A menu from 600 px, a
/// bottom sheet on phones.
class AccountAvatarButton extends StatefulWidget {
  const AccountAvatarButton({super.key});

  @override
  State<AccountAvatarButton> createState() => _AccountAvatarButtonState();
}

class _AccountAvatarButtonState extends State<AccountAvatarButton> {
  final _anchor = GlobalKey();
  bool _open = false;

  Future<void> _show() async {
    setState(() => _open = true);
    try {
      if (MediaQuery.sizeOf(context).width >= 600) {
        await showAccountMenu(context, _anchor, above: false);
      } else {
        await showAccountSheet(context);
      }
    } finally {
      if (mounted) setState(() => _open = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l;
    return AccountListener(
      builder: (context, email, demo) => Tooltip(
        message: l.account,
        child: PbInteractive(
          onTap: _show,
          radius: 16,
          minHit: const Size(48, 48),
          expanded: _open,
          label: l.accountMenuSemantics(accountLabel(l, email, demo)),
          builder: (context, states) => KeyedSubtree(
            key: _anchor,
            child: AccountAvatar(size: 32, email: email, demo: demo),
          ),
        ),
      ),
    );
  }
}
