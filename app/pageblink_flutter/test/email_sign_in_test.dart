import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pageblink_client/pageblink_client.dart';
import 'package:pageblink_flutter/screens/email_sign_in.dart';
import 'package:serverpod_auth_idp_flutter/serverpod_auth_idp_flutter.dart';

class _FakeAuth extends EmailAuthController {
  _FakeAuth() : super(client: Client('http://localhost:8080/'));
  int logins = 0;

  @override
  Future<void> login() async => logins++;
}

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
}
