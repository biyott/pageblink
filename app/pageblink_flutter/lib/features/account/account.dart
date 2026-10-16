import 'package:flutter/foundation.dart';
import 'package:pageblink_client/pageblink_client.dart';

import '../../client.dart';

/// Who is signed in (email for the account line). The client alone only knows
/// the auth user id, so the server's `account.me()` answers.

/// Test hook: replaces the server call.
@visibleForTesting
Future<AccountInfo> Function()? accountInfoCall;

/// Null until [loadAccountInfo] has an answer for the current signed-in
/// session. `isDemo` accounts have `email == null`. Like `demoStatus`, only
/// the shell resets and loads it, once per signed-in session.
final accountInfo = ValueNotifier<AccountInfo?>(null);

var _epoch = 0;

/// A new signed-in session starts (or the user signed out): forget the
/// previous account, so its email is never shown for the next one, and drop
/// any answer still on its way.
void resetAccountInfo() {
  _epoch++;
  accountInfo.value = null;
}

/// Reads `account.me()` into [accountInfo]. Never throws; a failed read leaves
/// the value as it was (null on a fresh session: the UI just shows no email).
/// An answer that arrives after [resetAccountInfo] is dropped.
Future<void> loadAccountInfo() async {
  final epoch = _epoch;
  try {
    final info = await (accountInfoCall ?? client.account.me)();
    if (epoch == _epoch) accountInfo.value = info;
  } catch (e) {
    // Never log the info itself; the error carries no email.
    debugPrint('account info unavailable: $e');
  }
}

/// Avatar letter for [email]: its first character, uppercased. Null when
/// there is nothing to show (null, empty, blank).
String? accountInitial(String? email) {
  final t = email?.trim();
  if (t == null || t.isEmpty) return null;
  return String.fromCharCode(t.runes.first).toUpperCase();
}
