import 'dart:async';

import 'package:flutter/material.dart';
import 'package:pageblink_client/pageblink_client.dart';
import 'package:serverpod_auth_idp_flutter/serverpod_auth_idp_flutter.dart';

import '../../app/l10n.dart';
import '../../client.dart';

/// Demo account client logic (docs/plan/014-demo-account.md §3, §5.2, §9).
///
/// The server decides everything: the app only asks `demo.status()` whether to
/// show the button / banner. Any failure of that call means "no demo".

/// How long the login screen waits for `status()` before it gives up and
/// simply shows no demo button (the default call timeout is 120 s).
const demoStatusTimeout = Duration(seconds: 8);

/// Test hooks: replace the two server calls.
@visibleForTesting
Future<DemoStatus> Function()? demoStatusCall;
@visibleForTesting
Future<void> Function()? demoSignInCall;

/// `demo.status()`, or null when it fails, times out or the server is too old
/// to know the endpoint. Never throws.
Future<DemoStatus?> fetchDemoStatus() async {
  try {
    return await (demoStatusCall ?? client.demo.status)().timeout(
      demoStatusTimeout,
    );
  } catch (e) {
    debugPrint('demo status unavailable: $e');
    return null;
  }
}

/// Signs in as the demo account: leave a current session first (the server
/// refuses a sign-in over another user), then hand the result to the session
/// manager. Throws on failure.
Future<void> signInAsDemo() async {
  final hook = demoSignInCall;
  if (hook != null) return hook();
  if (client.auth.isAuthenticated) await client.auth.signOutDevice();
  final success = await client.demo.signIn();
  await client.auth.updateSignedInUser(success);
}

// ── Status of the signed-in session (banner, create gate) ─────────────────

/// Null until the shell has asked; then what the server said. Only the shell
/// ([HomeShell]) resets and refreshes it, once per signed-in session.
final demoStatus = ValueNotifier<DemoStatus?>(null);

var _epoch = 0;
var _inFlight = false;
var _dirty = false;

/// A new signed-in session starts: forget the previous one's status.
void resetDemoStatus() {
  _epoch++;
  demoStatus.value = null;
}

/// Re-reads the status. A no-op for a regular account (known after the first
/// answer); overlapping calls collapse into one more read; a failed read keeps
/// the last value.
Future<void> refreshDemoStatus() async {
  final known = demoStatus.value;
  if (known != null && !known.isDemo) return;
  if (_inFlight) {
    _dirty = true;
    return;
  }
  _inFlight = true;
  try {
    do {
      _dirty = false;
      final epoch = _epoch;
      final s = await fetchDemoStatus();
      if (s != null && epoch == _epoch) demoStatus.value = s;
    } while (_dirty);
  } finally {
    _inFlight = false;
  }
}

/// True when the last status says the demo has no new-item slot left.
bool get demoCreateFull {
  final s = demoStatus.value;
  return s != null && s.isDemo && s.createRemaining == 0;
}

/// Gate for "new note" / "upload PDF": false lets the action go on. When the
/// last status says the slots are used up it asks the server again first (other
/// visitors free slots too), and only then shows the limit message. A failed
/// read lets the action go on: the server is the judge.
Future<bool> demoBlocksCreate(BuildContext context) async {
  if (!demoCreateFull) return false;
  final l = context.l;
  final messenger = ScaffoldMessenger.of(context);
  final s = await fetchDemoStatus();
  if (s == null) return false;
  demoStatus.value = s;
  if (!(s.isDemo && s.createRemaining == 0)) return false;
  if (context.mounted) {
    showDemoLimit(
      messenger,
      l,
      DemoLimitException(
        reason: DemoLimitReason.createLimit,
        limit: s.createLimit,
      ),
    );
  }
  return true;
}

// ── Limit messages ────────────────────────────────────────────────────────

/// The user-facing sentence for a [DemoLimitException].
String demoLimitText(L l, DemoLimitException e) => switch (e.reason) {
  DemoLimitReason.createLimit => l.demoCreateLimit(e.limit),
  DemoLimitReason.askLimit => l.demoAskLimit(e.limit),
  DemoLimitReason.sampleLocked => l.demoSampleLocked,
  DemoLimitReason.projectLocked => l.demoProjectLocked,
};

/// Signing up fixes a count limit, not a locked sample or project.
bool demoLimitOffersSignUp(DemoLimitException e) =>
    e.reason == DemoLimitReason.createLimit ||
    e.reason == DemoLimitReason.askLimit;

/// Snackbar with the limit message (and a Sign up action where it helps).
void showDemoLimit(
  ScaffoldMessengerState messenger,
  L l,
  DemoLimitException e,
) {
  messenger.showSnackBar(
    SnackBar(
      content: Text(demoLimitText(l, e)),
      duration: const Duration(seconds: 8),
      action: demoLimitOffersSignUp(e)
          ? SnackBarAction(label: l.demoSignUp, onPressed: demoSignUp)
          : null,
    ),
  );
}

// ── Sign up ───────────────────────────────────────────────────────────────

/// Set by [demoSignUp]; the sign-in screen opens on the registration form once
/// and clears it.
var demoSignUpRequested = false;

/// "Sign up" from the demo: leave the shared account; the sign-in screen
/// comes back, on its registration form.
Future<void> demoSignUp() async {
  demoSignUpRequested = true;
  try {
    await client.auth.signOutDevice();
  } catch (e) {
    demoSignUpRequested = false;
    debugPrint('demo sign up (sign out) failed: $e');
  }
}
