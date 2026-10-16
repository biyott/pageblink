import 'dart:async';

import 'package:flutter/material.dart';

import '../../app/app_icons.dart';
import '../../app/l10n.dart';
import '../../app/theme.dart';

/// Why the app signed the user out on its own.
enum SessionEnd { demo, expired }

/// Set when the server ended the session and the app signed the user out; the
/// sign-in screen shows the matching notice and clears it. Null otherwise.
final sessionEnded = ValueNotifier<SessionEnd?>(null);

/// Signs the user out when the server no longer accepts the session.
///
/// The server deletes refresh tokens (demo sessions after 60 idle / 240
/// total minutes, others after 14 days). An open tab is not told: its calls
/// just keep failing with 401. The client calls [onUnauthorized] for a 401 of
/// a call that carried credentials, after the library's own refresh and retry
/// failed. This then asks the library to validate the session
/// (`validateAuthentication`): it signs the device out only when the refresh
/// token is refused or the server says the user is not signed in. A network
/// error, a timeout or a server error are not a reason to sign out.
class SessionGuard {
  SessionGuard({
    required this.isSignedIn,
    required this.validate,
    required this.isDemo,
    ValueNotifier<SessionEnd?>? notice,
    DateTime Function()? now,
    this.cooldown = const Duration(seconds: 30),
  }) : _notice = notice ?? sessionEnded,
       _now = now ?? DateTime.now;

  final bool Function() isSignedIn;
  final Future<void> Function() validate;

  /// Whether the current session is the demo account (for the wording).
  final bool Function() isDemo;
  final ValueNotifier<SessionEnd?> _notice;
  final DateTime Function() _now;

  /// After a check that kept the user signed in, further 401s are ignored for
  /// this long, so a call that keeps failing for another reason cannot loop
  /// into refresh requests.
  final Duration cooldown;

  bool _busy = false;
  DateTime? _checkedAt;

  Future<void> onUnauthorized() async {
    // Signed out already (public call, or the check below ran): nothing to do.
    if (_busy || !isSignedIn()) return;
    final last = _checkedAt;
    if (last != null && _now().difference(last) < cooldown) return;
    _busy = true;
    final demo = isDemo();
    try {
      await validate();
      if (!isSignedIn()) {
        _notice.value = demo ? SessionEnd.demo : SessionEnd.expired;
      }
    } catch (e) {
      debugPrint('session check failed, staying signed in: $e');
    } finally {
      _checkedAt = _now();
      _busy = false;
    }
  }
}

/// The notice above the sign-in card after [SessionGuard] signed the user out.
class SessionEndNotice extends StatelessWidget {
  const SessionEndNotice({super.key, required this.reason});

  final SessionEnd reason;

  @override
  Widget build(BuildContext context) {
    final l = context.l;
    final pb = context.pb;
    final text = reason == SessionEnd.demo
        ? l.sessionEndedDemo
        : l.sessionExpired;
    return Semantics(
      liveRegion: true,
      child: Material(
        color: pb.accentContainer,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 4, 4, 4),
          child: Row(
            children: [
              Icon(AppIcons.info, size: 18, color: pb.onAccentContainer),
              const SizedBox(width: 10),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Text(
                    text,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: pb.onAccentContainer,
                    ),
                  ),
                ),
              ),
              IconButton(
                tooltip: l.dismiss,
                icon: const Icon(AppIcons.close, size: 18),
                color: pb.onAccentContainer,
                onPressed: () => sessionEnded.value = null,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
