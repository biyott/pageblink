import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:pageblink_client/pageblink_client.dart';
import 'package:pageblink_flutter/features/account/account.dart';

void main() {
  setUp(() {
    accountInfoCall = null;
    resetAccountInfo();
  });
  tearDown(() => accountInfoCall = null);

  group('accountInitial', () {
    test('first letter uppercased', () {
      expect(accountInitial('alice@example.com'), 'A');
      expect(accountInitial('  bob@example.com'), 'B');
      expect(accountInitial('9lives@example.com'), '9');
      expect(accountInitial('ñandú@example.com'), 'Ñ');
    });
    test('keeps a character outside the BMP whole', () {
      expect(accountInitial('😀@example.com'), '😀');
    });
    test('null, empty and blank give null', () {
      expect(accountInitial(null), isNull);
      expect(accountInitial(''), isNull);
      expect(accountInitial('   '), isNull);
    });
  });

  group('accountInfo', () {
    test('starts null, load fills it', () async {
      accountInfoCall = () async =>
          AccountInfo(email: 'a@example.com', isDemo: false);
      expect(accountInfo.value, isNull);
      await loadAccountInfo();
      expect(accountInfo.value?.email, 'a@example.com');
      expect(accountInfo.value?.isDemo, isFalse);
    });

    test('a demo account has no email', () async {
      accountInfoCall = () async => AccountInfo(isDemo: true);
      await loadAccountInfo();
      expect(accountInfo.value?.isDemo, isTrue);
      expect(accountInfo.value?.email, isNull);
    });

    test('reset clears the previous user', () async {
      accountInfoCall = () async =>
          AccountInfo(email: 'a@example.com', isDemo: false);
      await loadAccountInfo();
      resetAccountInfo();
      expect(accountInfo.value, isNull);
    });

    test('a failed load never throws and keeps the value', () async {
      accountInfoCall = () async =>
          AccountInfo(email: 'a@example.com', isDemo: false);
      await loadAccountInfo();
      accountInfoCall = () async => throw Exception('offline');
      await loadAccountInfo();
      expect(accountInfo.value?.email, 'a@example.com');
      resetAccountInfo();
      await loadAccountInfo();
      expect(accountInfo.value, isNull);
    });

    test('an answer for the previous user is dropped after a reset', () async {
      final slow = Completer<AccountInfo>();
      accountInfoCall = () => slow.future;
      final pending = loadAccountInfo();
      resetAccountInfo(); // user switched while the call was in flight
      slow.complete(AccountInfo(email: 'old@example.com', isDemo: false));
      await pending;
      expect(accountInfo.value, isNull);
    });

    test('notifies listeners when loaded', () async {
      accountInfoCall = () async => AccountInfo(isDemo: true);
      var n = 0;
      void l() => n++;
      accountInfo.addListener(l);
      await loadAccountInfo();
      accountInfo.removeListener(l);
      expect(n, 1);
    });
  });
}
