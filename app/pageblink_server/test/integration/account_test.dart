import 'package:pageblink_server/src/demo/demo_user.dart';
import 'package:pageblink_server/src/sample/sample_pack.dart';
import 'package:serverpod/serverpod.dart';
import 'package:serverpod_auth_idp_server/core.dart';
import 'package:serverpod_auth_idp_server/providers/email.dart';
import 'package:test/test.dart';

import 'test_tools/serverpod_test_tools.dart';

void main() {
  setUpAll(() {
    AuthServices.set(
      tokenManagerBuilders: [JwtConfigFromPasswords()],
      identityProviderBuilders: [
        ServerpodCloudEmailIdpConfig(appDisplayName: 'pageblink'),
      ],
    );
  });

  withServerpod('Given AccountEndpoint.me', (sb, endpoints) {
    TestSessionBuilder as(UuidValue id) => sb.copyWith(
      authentication: AuthenticationOverride.authenticationInfo(
        id.toString(),
        {},
      ),
    );

    setUp(DemoUser.debugReset);
    tearDown(DemoUser.debugReset);

    Future<UuidValue> signUp(String email) async {
      final s = sb.build();
      final user = await AuthServices.instance.authUsers.create(s);
      await AuthServices.instance.emailIdp.admin.createEmailAuthentication(
        s,
        authUserId: user.id,
        email: email,
        password: 'Passw0rd!x',
      );
      return user.id;
    }

    test('an email user gets their own email, not isDemo', () async {
      final a = await signUp('a@example.com');
      final b = await signUp('b@example.com');
      final me = await endpoints.account.me(as(a));
      expect(me.email, 'a@example.com');
      expect(me.isDemo, isFalse);
      expect((await endpoints.account.me(as(b))).email, 'b@example.com');
    });

    test('a demo user gets isDemo and no email', () async {
      final id = await DemoUser.ensure(sb.build(), SamplePacks.demoEn);
      final me = await endpoints.account.me(as(id));
      expect(me.isDemo, isTrue);
      expect(me.email, isNull);
    });

    test('a user without an email account gets null, not an error', () async {
      final me = await endpoints.account.me(as(const Uuid().v4obj()));
      expect(me.email, isNull);
      expect(me.isDemo, isFalse);
    });

    test('unauthenticated is rejected', () async {
      await expectLater(
        endpoints.account.me(sb),
        throwsA(isA<ServerpodUnauthenticatedException>()),
      );
    });
  });
}
