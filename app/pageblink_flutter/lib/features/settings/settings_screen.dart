import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pageblink_client/pageblink_client.dart';
import 'package:serverpod_auth_idp_flutter/serverpod_auth_idp_flutter.dart';

import '../../app/app_icons.dart';
import '../../app/app_version.dart';
import '../../app/l10n.dart';
import '../../app/locale_controller.dart';
import '../../app/pane_header.dart';
import '../../app/theme.dart';
import '../../client.dart';
import '../account/account_menu.dart';
import '../ask/ask_chat.dart' show historyStatus;
import 'admin_history_screen.dart';

/// Test hook: the signed-in user's id (null = not signed in).
@visibleForTesting
String? Function()? accountIdCall;

String? _accountId() =>
    (accountIdCall ?? () => client.auth.authInfo?.authUserId.toString())();

/// First 8 characters, an ellipsis, the last 4 (short ids stay whole).
String shortAccountId(String id) => id.length <= 14
    ? id
    : '${id.substring(0, 8)}…${id.substring(id.length - 4)}';

/// Taps on the version line that reveal the account ID row for a regular
/// account, and the idle time after which the count starts over.
const _revealTaps = 7;
const _revealIdle = Duration(seconds: 3);

/// Account, language, conversation history and the app version. Opens like a
/// note: in the center pane ([embedded]) or as a page on phones.
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({
    super.key,
    required this.embedded,
    required this.onClose,
  });

  final bool embedded;
  final VoidCallback onClose;

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  static const _system = 'system';

  int _taps = 0;
  Timer? _idle;

  /// Set by [_revealTaps] taps on the version line; for this visit only.
  bool _revealed = false;

  @override
  void dispose() {
    _idle?.cancel();
    super.dispose();
  }

  void _tapVersion() {
    if (_revealed) return;
    _idle?.cancel();
    if (++_taps >= _revealTaps) {
      setState(() => _revealed = true);
      ScaffoldMessenger.maybeOf(
        context,
      )?.showSnackBar(SnackBar(content: Text(context.l.accountId)));
      return;
    }
    _idle = Timer(_revealIdle, () => _taps = 0);
  }

  Future<void> _copy(String id) async {
    await Clipboard.setData(ClipboardData(text: id));
    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(context.l.accountIdCopied)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l;
    final pb = context.pb;
    final text = Theme.of(context).textTheme;
    Widget heading(String s) => Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 16, 8),
      child: Text(s, style: text.titleSmall),
    );
    return Column(
      children: [
        PaneHeader(
          embedded: widget.embedded,
          onBack: widget.onClose,
          onClose: widget.onClose,
          backLabel: l.back,
          title: Text(l.settings),
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.only(bottom: 16),
            children: [
              heading(l.account),
              AccountListener(
                builder: (context, email, demo) =>
                    ValueListenableBuilder<AskHistoryStatus?>(
                      valueListenable: historyStatus,
                      builder: (context, status, _) {
                        final id = _accountId();
                        final showId =
                            !demo &&
                            id != null &&
                            ((status?.isAdmin ?? false) || _revealed);
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _Group(
                              children: [
                                const Padding(
                                  padding: EdgeInsets.all(16),
                                  child: AccountIdentity(avatarSize: 40),
                                ),
                                if (showId)
                                  ListTile(
                                    title: Text(l.accountId),
                                    subtitle: Text(shortAccountId(id)),
                                    trailing: IconButton(
                                      icon: const Icon(AppIcons.copy),
                                      tooltip: l.copyAccountId,
                                      onPressed: () => _copy(id),
                                    ),
                                    onTap: () => _copy(id),
                                  ),
                                ListTile(
                                  leading: const Icon(AppIcons.signOut),
                                  title: Text(l.signOut),
                                  onTap: signOut,
                                ),
                              ],
                            ),
                            if (showId)
                              Padding(
                                padding: const EdgeInsets.fromLTRB(
                                  20,
                                  8,
                                  16,
                                  0,
                                ),
                                child: Text(
                                  l.accountIdHint,
                                  style: text.bodySmall?.copyWith(
                                    color: pb.inkMuted,
                                  ),
                                ),
                              ),
                          ],
                        );
                      },
                    ),
              ),
              heading(l.language),
              ValueListenableBuilder<Locale?>(
                valueListenable: localeController,
                builder: (context, locale, _) => RadioGroup<String>(
                  groupValue: locale?.languageCode ?? _system,
                  onChanged: (code) => localeController.choose(
                    code == null || code == _system ? null : Locale(code),
                  ),
                  child: _Group(
                    children: [
                      RadioListTile<String>(
                        value: _system,
                        title: Text(l.languageSystem),
                      ),
                      RadioListTile<String>(
                        value: 'en',
                        title: Text(l.languageEnglish),
                      ),
                      RadioListTile<String>(
                        value: 'ko',
                        title: Text(l.languageKorean),
                      ),
                    ],
                  ),
                ),
              ),
              ValueListenableBuilder<AskHistoryStatus?>(
                valueListenable: historyStatus,
                builder: (context, status, _) {
                  if (status == null || !status.enabled) {
                    return const SizedBox.shrink();
                  }
                  return Column(
                    children: [
                      if (status.isAdmin)
                        ListTile(
                          leading: const Icon(AppIcons.ask),
                          title: Text(l.adminHistory),
                          trailing: const Icon(AppIcons.next),
                          onTap: () => Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) => const AdminHistoryPage(),
                            ),
                          ),
                        ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(20, 8, 16, 8),
                        child: Text(
                          l.historyNotice(status.retentionDays),
                          style: text.bodySmall?.copyWith(color: pb.inkMuted),
                        ),
                      ),
                    ],
                  );
                },
              ),
              // Not a control: seven taps quietly reveal the account ID row.
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: _tapVersion,
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 20),
                  child: Center(
                    child: Text(
                      l.appVersionLabel(appVersion),
                      style: text.bodySmall?.copyWith(
                        fontSize: 12,
                        color: pb.inkMuted,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Paper surface, 16 radius, 1 hairline; rows are split by hairlines. A
/// [Material] (not a decorated box) so the rows' ink shows above the paper.
class _Group extends StatelessWidget {
  const _Group({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final pb = context.pb;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Material(
        color: pb.pdfPaper,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: pb.hairline),
        ),
        child: Column(
          children: [
            for (var i = 0; i < children.length; i++) ...[
              if (i > 0) const Divider(height: 1),
              children[i],
            ],
          ],
        ),
      ),
    );
  }
}
