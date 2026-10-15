import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pageblink_client/pageblink_client.dart';
import 'package:pageblink_flutter/app/l10n.dart';
import 'package:pageblink_flutter/screens/email_sign_in.dart';
import 'package:pageblink_flutter/screens/sign_in_screen.dart';
import 'package:serverpod_auth_idp_flutter/serverpod_auth_idp_flutter.dart';

class _FakeAuth extends EmailAuthController {
  _FakeAuth()
    : super(
        client: Client('http://localhost:8080/'),
        passwordRequirements: pageBlinkPasswordRequirements(L.en),
      );
  int logins = 0;
  int registrations = 0;
  int finishes = 0;
  int resets = 0;
  int verifies = 0;

  @override
  Future<void> login() async => logins++;

  @override
  Future<void> startRegistration() async => registrations++;

  @override
  Future<void> finishRegistration() async => finishes++;

  @override
  Future<void> startPasswordReset() async => resets++;

  @override
  Future<void> verifyRegistrationCode() async => verifies++;
}

Future<_FakeAuth> _pump(WidgetTester tester, EmailFlowScreen screen) async {
  final auth = _FakeAuth();
  addTearDown(auth.dispose);
  auth.navigateTo(screen);
  await tester.pumpWidget(
    MaterialApp(
      home: Material(child: PageBlinkEmailSignIn(controller: auth)),
    ),
  );
  return auth;
}

List<String> _hints(WidgetTester tester, Finder f) =>
    tester.widget<TextField>(f).autofillHints!.toList();

void main() {
  testWidgets('Enter submits login; email Enter moves on until filled', (
    tester,
  ) async {
    final auth = _FakeAuth();
    addTearDown(auth.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: Material(child: PageBlinkEmailSignIn(controller: auth)),
      ),
    );

    final email = find.byType(TextField).first;
    final password = find.byType(TextField).last;

    // Both fields carry hints so the password manager can fill and save.
    expect(
      tester.widget<TextField>(email).autofillHints,
      contains(AutofillHints.username),
    );
    expect(
      tester.widget<TextField>(password).autofillHints,
      contains(AutofillHints.password),
    );
    expect(find.byType(AutofillGroup), findsOneWidget);

    await tester.enterText(email, 'a@b.co');
    await tester.testTextInput.receiveAction(TextInputAction.next);
    await tester.pump();
    expect(auth.logins, 0); // password still empty: only focus moved

    await tester.enterText(password, 'secret-password');
    await tester.pump(const Duration(seconds: 1)); // email debounce
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();
    expect(auth.logins, 1);
  });

  testWidgets('sign-up start: Enter on email starts registration once', (
    tester,
  ) async {
    final auth = await _pump(tester, EmailFlowScreen.startRegistration);
    final email = find.byType(TextField);

    expect(find.byType(AutofillGroup), findsOneWidget);
    expect(_hints(tester, email), contains(AutofillHints.username));
    expect(_hints(tester, email), contains(AutofillHints.email));

    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();
    expect(auth.registrations, 0); // empty email: nothing to submit

    await tester.enterText(email, 'a@b.co');
    await tester.pump(const Duration(seconds: 1)); // email debounce
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();
    expect(auth.registrations, 1);
  });

  testWidgets('verify code: oneTimeCode hint, Enter verifies', (tester) async {
    final auth = await _pump(tester, EmailFlowScreen.verifyRegistration);
    final code = find.byType(TextField);

    expect(find.byType(AutofillGroup), findsOneWidget);
    expect(_hints(tester, code), [AutofillHints.oneTimeCode]);

    await tester.enterText(code, '1234');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();
    expect(auth.verifies, 1);
    await tester.pump(const Duration(minutes: 2)); // resend timer
  });

  testWidgets('set password: Enter submits only when the rules are met', (
    tester,
  ) async {
    final auth = await _pump(tester, EmailFlowScreen.completeRegistration);
    final password = find.byType(TextField).last;

    expect(find.byType(AutofillGroup), findsOneWidget);
    expect(_hints(tester, password), [AutofillHints.newPassword]);
    // The (read-only) email field gives the browser the username to pair.
    expect(
      _hints(tester, find.byType(TextField).first),
      contains(AutofillHints.username),
    );

    await tester.enterText(password, 'short');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();
    expect(auth.finishes, 0);

    await tester.enterText(password, 'correct-Horse-battery-9');
    await tester.pump();
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();
    expect(auth.finishes, 1);
  });

  testWidgets('password reset request/set-new forms carry autofill hints', (
    tester,
  ) async {
    final auth = await _pump(tester, EmailFlowScreen.requestPasswordReset);
    expect(find.byType(AutofillGroup), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'a@b.co');
    await tester.pump(const Duration(seconds: 1));
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();
    expect(auth.resets, 1);

    auth.navigateTo(EmailFlowScreen.completePasswordReset);
    await tester.pump();
    expect(find.byType(AutofillGroup), findsOneWidget);
    expect(_hints(tester, find.byType(TextField).last), [
      AutofillHints.newPassword,
    ]);
  });
}
