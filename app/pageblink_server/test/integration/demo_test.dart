import 'dart:typed_data';

import 'package:pageblink_server/src/demo/demo_config.dart';
import 'package:pageblink_server/src/demo/demo_guard.dart';
import 'package:pageblink_server/src/demo/demo_seed.dart';
import 'package:pageblink_server/src/demo/demo_user.dart';
import 'package:pageblink_server/src/generated/protocol.dart';
import 'package:pageblink_server/src/rag/chunker.dart';
import 'package:pageblink_server/src/sample/sample_pack.dart';
import 'package:pageblink_server/src/services/maintenance_timer.dart';
import 'package:serverpod/serverpod.dart';
import 'package:serverpod_auth_idp_server/core.dart';
import 'package:serverpod_auth_idp_server/providers/email.dart';
import 'package:test/test.dart';

import 'test_tools/serverpod_test_tools.dart';

/// Run with the embedding/LLM keys unset (`env -u GEMINI_API_KEY ...`): the
/// documents then end `failed` without any network call. Nothing here depends
/// on a document being `ready`.
void main() {
  final pack = SamplePacks.demoEn;
  final koPack = SamplePacks.demoKo;

  setUpAll(() {
    AuthServices.set(
      tokenManagerBuilders: [JwtConfigFromPasswords()],
      identityProviderBuilders: [
        ServerpodCloudEmailIdpConfig(appDisplayName: 'pageblink'),
      ],
    );
  });

  withServerpod('Given the demo account', (sb, endpoints) {
    late UuidValue demoId; // the English account (the original one)
    late UuidValue koId;
    late TestSessionBuilder demo;
    late TestSessionBuilder demoKo;
    late TestSessionBuilder visitor; // not logged in
    late UuidValue otherId;
    late TestSessionBuilder other; // a normal user
    late TestSessionBuilder seed;
    late TestSessionBuilder seedKo;

    TestSessionBuilder as(UuidValue id, {String? authId}) => sb.copyWith(
      authentication: AuthenticationOverride.authenticationInfo(
        id.toString(),
        {},
        authId: authId,
      ),
    );

    setUp(() async {
      DemoConfig.debugOverride = true;
      DemoSeed.debugDisabled = true;
      DemoGuard.askCounter = DailyCounter(demoAskDailyLimit);
      DemoUser.debugReset();
      demoId = await DemoUser.ensure(sb.build(), pack);
      koId = await DemoUser.ensure(sb.build(), koPack);
      demo = as(demoId);
      demoKo = as(koId);
      seed = as(demoId, authId: demoSeedAuthId);
      seedKo = as(koId, authId: demoSeedAuthId);
      visitor = sb;
      otherId = const Uuid().v4obj();
      other = as(otherId);
    });

    tearDown(() {
      DemoConfig.debugOverride = null;
      DemoUser.debugReset();
    });

    Future<Document> sampleRow(
      String hash, {
      String status = 'ready',
      String kind = 'note',
      UuidValue? owner,
    }) {
      final now = DateTime.now().toUtc();
      return Document.db.insertRow(
        sb.build(),
        Document(
          ownerId: owner ?? demoId,
          kind: kind,
          title: 'sample',
          body: 'x',
          contentHash: hash,
          version: 1,
          pageCount: 1,
          status: status,
          embeddingModel: 'm',
          createdAt: now,
          updatedAt: now,
        ),
      );
    }

    Future<Document> ownRow({required Duration age, UuidValue? owner}) {
      final created = DateTime.now().toUtc().subtract(age);
      return Document.db.insertRow(
        sb.build(),
        Document(
          ownerId: owner ?? demoId,
          kind: 'note',
          title: 'own',
          body: 'mine ${age.inMinutes}',
          contentHash: sha256Hex('mine ${age.inMinutes} ${owner ?? ''}'),
          version: 1,
          pageCount: 1,
          status: 'ready',
          embeddingModel: 'm',
          createdAt: created,
          updatedAt: created,
        ),
      );
    }

    List<PageText> pages(String t) => [PageText(page: 1, text: t)];

    test('ensure is idempotent: one user, one email account each', () async {
      expect(koId, isNot(demoId));
      expect(await DemoUser.ensure(sb.build(), pack), demoId);
      expect(await DemoUser.ensure(sb.build(), koPack), koId);
      await DemoUser.ensureAll(sb.build());
      for (final p in [pack, koPack]) {
        final accounts = await EmailAccount.db.count(
          sb.build(),
          where: (t) => t.email.equals(p.accountEmail!),
        );
        expect(accounts, 1, reason: p.id);
      }
      expect(DemoUser.packOf(demoId), same(pack));
      expect(DemoUser.packOf(koId), same(koPack));
      expect(DemoUser.isDemo(otherId), isFalse);
      expect(DemoUser.isDemo(null), isFalse);
    });

    test('the original account is the English one', () {
      expect(pack.accountEmail, 'demo@pageblink.invalid');
      expect(koPack.accountEmail, 'demo-ko@pageblink.invalid');
    });

    test('flag off: status is only enabled=false, signIn refuses, '
        'nothing is created', () async {
      DemoConfig.debugOverride = false;
      DemoUser.debugReset();
      await EmailAccount.db.deleteWhere(
        sb.build(),
        where: (t) =>
            t.email.equals(pack.accountEmail!) |
            t.email.equals(koPack.accountEmail!),
      );

      final status = await endpoints.demo.status(visitor);
      expect(status.enabled, isFalse);
      expect(status.isDemo, isFalse);
      expect(status.createLimit, 0);
      expect(status.createRemaining, isNull);
      await expectLater(endpoints.demo.signIn(visitor), throwsA(anything));
      await expectLater(
        endpoints.demo.signIn(visitor, 'ko'),
        throwsA(anything),
      );
      expect(
        await EmailAccount.db.count(
          sb.build(),
          where: (t) =>
              t.email.equals(pack.accountEmail!) |
              t.email.equals(koPack.accountEmail!),
        ),
        0,
      );
    });

    test('flag on: status for a visitor, for the demo user', () async {
      final v = await endpoints.demo.status(visitor);
      expect(v.enabled, isTrue);
      expect(v.isDemo, isFalse);
      expect(v.createLimit, demoCreateLimit);
      expect(v.askLimit, demoAskDailyLimit);
      expect(v.createRemaining, isNull);

      await ownRow(age: const Duration(minutes: 1));
      await sampleRow(pack.notes[0].hash);
      final d = await endpoints.demo.status(demo);
      expect(d.isDemo, isTrue);
      expect(d.createRemaining, demoCreateLimit - 1); // sample not counted
      expect(d.askRemaining, demoAskDailyLimit);

      final o = await endpoints.demo.status(other);
      expect(o.isDemo, isFalse);
    });

    test('signIn issues a demo token for the demo user', () async {
      final ok = await endpoints.demo.signIn(visitor);
      expect(ok.authUserId, demoId);
      final tokens = await RefreshToken.db.count(
        sb.build(),
        where: (t) => t.authUserId.equals(demoId) & t.method.equals('demo'),
      );
      expect(tokens, 1);
    });

    test('creating the 6th own document throws DemoLimitException', () async {
      for (var i = 0; i < 3; i++) {
        await endpoints.document.saveNote(demo, null, 't$i', 'body $i', null);
      }
      for (var i = 0; i < 2; i++) {
        await endpoints.document.upload(
          demo,
          'p$i',
          pages('pdf $i'),
          sha256Hex('pdf $i'),
          null,
        );
      }
      // Samples do not use a slot.
      await sampleRow(pack.notes[2].hash);

      await expectLater(
        endpoints.document.saveNote(demo, null, 'six', 'body six', null),
        throwsA(
          isA<DemoLimitException>()
              .having((e) => e.reason, 'reason', DemoLimitReason.createLimit)
              .having((e) => e.limit, 'limit', demoCreateLimit),
        ),
      );
      await expectLater(
        endpoints.document.upload(
          demo,
          'six',
          pages('six'),
          sha256Hex('six'),
          null,
        ),
        throwsA(isA<DemoLimitException>()),
      );
      // Updating an existing own note is not a new slot.
      final own = await Document.db.findFirstRow(
        sb.build(),
        where: (t) => t.ownerId.equals(demoId) & t.kind.equals('note'),
      );
      await endpoints.document.saveNote(demo, own!.id, 'again', 'edited', null);
    });

    test('an expired own document frees its slot at the next create', () async {
      for (var i = 0; i < demoCreateLimit - 1; i++) {
        await ownRow(age: Duration(minutes: i + 1));
      }
      final old = await ownRow(age: const Duration(hours: 25));
      await endpoints.document.saveNote(demo, null, 'new', 'fresh body', null);
      expect(await Document.db.findById(sb.build(), old.id!), isNull);
    });

    group('sample protection (4 places)', () {
      late Document sampleNote;
      setUp(() async {
        sampleNote = await sampleRow(pack.notes[0].hash);
      });

      Matcher locked() => throwsA(
        isA<DemoLimitException>().having(
          (e) => e.reason,
          'reason',
          DemoLimitReason.sampleLocked,
        ),
      );

      test('1. _requireWrite: edit, delete, re-index, PDF original', () async {
        await expectLater(
          endpoints.document.saveNote(demo, sampleNote.id, 't', 'edited', null),
          locked(),
        );
        await expectLater(
          endpoints.document.delete(demo, sampleNote.id!),
          locked(),
        );
        await expectLater(
          endpoints.document.reindex(demo, sampleNote.id!),
          locked(),
        );
        expect(
          await Document.db.findById(sb.build(), sampleNote.id!),
          isNotNull,
        );
        final pdf = await sampleRow(pack.pdf!.hash, kind: 'pdf');
        await expectLater(
          endpoints.document.pdfUploadDescription(demo, pdf.id!),
          locked(),
        );
        await expectLater(
          endpoints.document.confirmPdfUpload(demo, pdf.id!),
          locked(),
        );
      });

      test(
        '2. upload retry of a failed sample PDF cannot overwrite it',
        () async {
          await sampleRow(pack.pdf!.hash, status: 'failed');
          await expectLater(
            endpoints.document.upload(
              demo,
              'fake',
              pages('visitor text'),
              pack.pdf!.hash,
              null,
            ),
            locked(),
          );
          final row = await Document.db.findFirstRow(
            sb.build(),
            where: (t) => t.contentHash.equals(pack.pdf!.hash),
          );
          expect(row!.status, 'failed');
          expect(row.title, 'sample');
        },
      );

      test('3. a note with a sample body is refused (new and edit)', () async {
        await expectLater(
          endpoints.document.saveNote(
            demo,
            null,
            'copy',
            pack.notes[0].body,
            null,
          ),
          locked(),
        );
        final own = await ownRow(age: const Duration(minutes: 1));
        await expectLater(
          endpoints.document.saveNote(
            demo,
            own.id,
            'copy',
            pack.notes[0].body,
            null,
          ),
          locked(),
        );
      });

      test(
        '4. reindexFailed skips a failed sample instead of failing',
        () async {
          await sampleRow(pack.pdf!.hash, status: 'failed');
          expect(await endpoints.document.reindexFailed(demo), 0);
        },
      );

      test('the internal seed session is not blocked', () async {
        final doc = await endpoints.document.saveNote(
          seed,
          null,
          pack.notes[2].title,
          pack.notes[2].body,
          null,
        );
        expect(doc.contentHash, pack.notes[2].hash);
      });
    });

    test('seeding is idempotent and stores the sample PDF original', () async {
      Future<List<Document>> samples() => Document.db.find(
        sb.build(),
        where: (t) =>
            t.ownerId.equals(demoId) &
            t.contentHash.inSet(SamplePacks.demoMarkers),
      );
      await DemoSeed.run(seed.build(), demoId, pack);
      await DemoSeed.run(seed.build(), demoId, pack);
      final rows = await samples();
      expect(rows, hasLength(4)); // 3 notes + 1 PDF
      final pdf = rows.singleWhere((d) => d.kind == 'pdf');
      expect(pdf.pageCount, pack.pdf!.pages.length);
      expect(pdf.storagePath, 'pdfs/${pdf.id}.pdf');
      // They do not take a visitor slot.
      expect(await DemoGuard.countOwn(sb.build(), demoId), 0);
    });

    test('seeding deletes legacy samples once and leaves the rest', () async {
      final legacyRows = [
        for (final h in SamplePacks.demoLegacy) await sampleRow(h),
      ];
      final own = await ownRow(age: const Duration(minutes: 1));
      expect(
        await DemoGuard.countOwn(sb.build(), demoId),
        SamplePacks.demoLegacy.length + 1,
      );

      await DemoSeed.run(seed.build(), demoId, pack);
      await DemoSeed.run(seed.build(), demoId, pack);

      final s = sb.build();
      for (final d in legacyRows) {
        expect(await Document.db.findById(s, d.id!), isNull);
      }
      expect(await Document.db.findById(s, own.id!), isNotNull);
      expect(await DemoGuard.countOwn(s, demoId), 1); // only the visitor's own
      final samples = await Document.db.count(
        s,
        where: (t) =>
            t.ownerId.equals(demoId) &
            t.contentHash.inSet(SamplePacks.demoMarkers),
      );
      expect(samples, 4);
    });

    test('demo cannot create projects or be invited', () async {
      await expectLater(
        endpoints.project.create(demo, 'Team'),
        throwsA(
          isA<DemoLimitException>().having(
            (e) => e.reason,
            'reason',
            DemoLimitReason.projectLocked,
          ),
        ),
      );
      final project = await endpoints.project.create(other, 'Team');
      await expectLater(
        endpoints.project.addMember(
          other,
          project.id!,
          pack.accountEmail!,
          'viewer',
        ),
        throwsA(isA<DemoLimitException>()),
      );
    });

    test('the shared daily question limit ends the stream with '
        'DemoLimitException', () async {
      DemoGuard.askCounter = DailyCounter(0);
      await expectLater(
        endpoints.ask.ask(demo, 'hello?', [], true, null),
        emitsError(
          isA<DemoLimitException>()
              .having((e) => e.reason, 'reason', DemoLimitReason.askLimit)
              .having((e) => e.limit, 'limit', demoAskDailyLimit),
        ),
      );
    });

    test('flag off: a lingering demo session stays limited, nothing is '
        'purged', () async {
      for (var i = 0; i < demoCreateLimit; i++) {
        await ownRow(age: Duration(minutes: i + 1));
      }
      final expired = await ownRow(age: const Duration(hours: 30));
      // Boot with the flag off: lookup only.
      DemoConfig.debugOverride = false;
      DemoUser.debugReset();
      await DemoUser.load(sb.build());
      expect(DemoUser.isDemo(demoId), isTrue);
      expect(DemoUser.isDemo(koId), isTrue);

      await expectLater(
        endpoints.document.saveNote(demo, null, 'x', 'one more', null),
        throwsA(isA<DemoLimitException>()),
      );
      await expectLater(
        endpoints.project.create(demo, 'Team'),
        throwsA(isA<DemoLimitException>()),
      );
      await expectLater(
        endpoints.project.create(demoKo, 'Team'),
        throwsA(isA<DemoLimitException>()),
      );
      expect(await Document.db.findById(sb.build(), expired.id!), isNotNull);
    });

    test('signIn purges documents older than 24 hours and tokens past the '
        'absolute limit', () async {
      final old = await ownRow(age: const Duration(hours: 25));
      final fresh = await ownRow(age: const Duration(hours: 1));
      final oldSample = await sampleRow(pack.notes[0].hash);
      await Document.db.updateRow(
        sb.build(),
        oldSample.copyWith(
          createdAt: DateTime.now().toUtc().subtract(const Duration(days: 3)),
        ),
      );
      Future<RefreshToken> token(Duration age, String method) =>
          RefreshToken.db.insertRow(
            sb.build(),
            RefreshToken(
              authUserId: demoId,
              scopeNames: {},
              method: method,
              fixedSecret: ByteData(16),
              rotatingSecretHash: 'x',
              createdAt: DateTime.now().toUtc().subtract(age),
              lastUpdatedAt: DateTime.now().toUtc(),
            ),
          );
      final oldToken = await token(const Duration(hours: 25), 'demo');
      final keepEmail = await token(const Duration(hours: 25), 'email');

      await endpoints.demo.signIn(visitor);

      final s = sb.build();
      expect(await Document.db.findById(s, old.id!), isNull);
      expect(await Document.db.findById(s, fresh.id!), isNotNull);
      expect(await Document.db.findById(s, oldSample.id!), isNotNull);
      expect(await RefreshToken.db.findById(s, oldToken.id!), isNull);
      expect(await RefreshToken.db.findById(s, keepEmail.id!), isNotNull);
    });

    group('demo token expiry (idle 60 min, absolute 240 min)', () {
      late UuidValue regularId; // a real AuthUser: the token table has an FK
      setUp(() async {
        regularId = (await AuthServices.instance.authUsers.create(
          sb.build(),
        )).id;
      });

      Future<RefreshToken> token(
        UuidValue user,
        String method, {
        required Duration created,
        required Duration updated,
      }) {
        final now = DateTime.now().toUtc();
        return RefreshToken.db.insertRow(
          sb.build(),
          RefreshToken(
            authUserId: user,
            scopeNames: {},
            method: method,
            fixedSecret: ByteData(16),
            rotatingSecretHash: 'x',
            createdAt: now.subtract(created),
            lastUpdatedAt: now.subtract(updated),
          ),
        );
      }

      Future<bool> alive(RefreshToken t) async =>
          await RefreshToken.db.findById(sb.build(), t.id!) != null;

      Future<Map<String, RefreshToken>> fixture() async => {
        'idle61': await token(
          demoId,
          'demo',
          created: const Duration(minutes: 90),
          updated: const Duration(minutes: 61),
        ),
        'max241': await token(
          koId,
          'demo',
          created: const Duration(minutes: 241),
          updated: const Duration(minutes: 1),
        ),
        'both': await token(
          demoId,
          'demo',
          created: const Duration(days: 2),
          updated: const Duration(days: 1),
        ),
        'active': await token(
          demoId,
          'demo',
          created: const Duration(minutes: 239),
          updated: const Duration(minutes: 59),
        ),
        'fresh': await token(
          koId,
          'demo',
          created: const Duration(minutes: 1),
          updated: const Duration(minutes: 1),
        ),
        'emailOld': await token(
          regularId,
          'email',
          created: const Duration(days: 9),
          updated: const Duration(days: 9),
        ),
        // Only method 'demo' is ever touched, whoever owns the row.
        'emailOnDemoUser': await token(
          demoId,
          'email',
          created: const Duration(days: 9),
          updated: const Duration(days: 9),
        ),
      };

      test('only the idle and the over-age demo tokens go', () async {
        final t = await fixture();
        final gone = await DemoGuard.purgeExpiredTokens(sb.build());
        expect(gone, 3);
        for (final k in ['idle61', 'max241', 'both']) {
          expect(await alive(t[k]!), isFalse, reason: k);
        }
        for (final k in ['active', 'fresh', 'emailOld', 'emailOnDemoUser']) {
          expect(await alive(t[k]!), isTrue, reason: k);
        }
      });

      test('running it again deletes nothing more', () async {
        await fixture();
        expect(await DemoGuard.purgeExpiredTokens(sb.build()), 3);
        expect(await DemoGuard.purgeExpiredTokens(sb.build()), 0);
      });

      test('flag off: nothing is deleted', () async {
        final t = await fixture();
        DemoConfig.debugOverride = false;
        expect(await DemoGuard.purgeExpiredTokens(sb.build()), 0);
        await MaintenanceTimer.demoTokens.run(sb.build());
        expect(await alive(t['idle61']!), isTrue);
      });

      test('the timer job deletes them and finds accounts by itself', () async {
        final t = await fixture();
        DemoUser.debugReset(); // as after a boot that could not load them
        await MaintenanceTimer.demoTokens.run(sb.build());
        expect(await alive(t['idle61']!), isFalse);
        expect(await alive(t['active']!), isTrue);
      });

      test('the auth job removes expired tokens of every method', () async {
        final old = await token(
          regularId,
          'email',
          created: const Duration(days: 30),
          updated: const Duration(days: 15),
        );
        final recent = await token(
          regularId,
          'email',
          created: const Duration(days: 30),
          updated: const Duration(days: 13),
        );
        await MaintenanceTimer.authTokens.run(sb.build());
        expect(await alive(old), isFalse);
        expect(await alive(recent), isTrue);
      });
    });

    group('one account per language', () {
      Future<List<Document>> samplesOf(UuidValue id) => Document.db.find(
        sb.build(),
        where: (t) =>
            t.ownerId.equals(id) & t.contentHash.inSet(SamplePacks.demoMarkers),
      );

      test(
        'signIn picks the account by locale; none or unknown is English',
        () async {
          Future<UuidValue> who(String? locale) async =>
              (await endpoints.demo.signIn(visitor, locale)).authUserId;
          final plain = await endpoints.demo.signIn(visitor);
          expect(plain.authUserId, demoId);
          expect(await who(null), demoId);
          expect(await who('en'), demoId);
          expect(await who('ja'), demoId);
          expect(await who(''), demoId);
          expect(await who('ko'), koId);
          expect(await who('ko-KR'), koId);
          expect(await who('KO'), koId);
          final koTokens = await RefreshToken.db.count(
            sb.build(),
            where: (t) => t.authUserId.equals(koId) & t.method.equals('demo'),
          );
          expect(koTokens, 3);
        },
      );

      test(
        'signIn falls back to the English account when the locale account '
        'is missing and cannot be created',
        () async {
          await EmailAccount.db.deleteWhere(
            sb.build(),
            where: (t) => t.email.equals(koPack.accountEmail!),
          );
          DemoUser.debugFailCreate.add(koPack.id);
          final ok = await endpoints.demo.signIn(visitor, 'ko');
          expect(ok.authUserId, demoId);
          expect(ok.authUserId, isNot(koId));
        },
      );

      test('signIn still fails when the English account cannot be created '
          'either', () async {
        await EmailAccount.db.deleteWhere(
          sb.build(),
          where: (t) => t.email.equals(pack.accountEmail!),
        );
        DemoUser.debugFailCreate.add(pack.id);
        await expectLater(endpoints.demo.signIn(visitor), throwsA(anything));
        await expectLater(
          endpoints.demo.signIn(visitor, 'ko'),
          completion(isA<AuthSuccess>()),
        );
      });

      test('status: both accounts are demo accounts', () async {
        for (final s in [demo, demoKo]) {
          final st = await endpoints.demo.status(s);
          expect(st.enabled, isTrue);
          expect(st.isDemo, isTrue);
          expect(st.createRemaining, demoCreateLimit);
        }
      });

      test('seeding: 3 notes + 1 PDF each, in their own language', () async {
        await DemoSeed.run(seed.build(), demoId, pack);
        expect(await samplesOf(koId), isEmpty); // nothing leaks over
        await DemoSeed.run(seedKo.build(), koId, koPack);
        await DemoSeed.run(seedKo.build(), koId, koPack); // idempotent

        for (final (id, p) in [(demoId, pack), (koId, koPack)]) {
          final rows = await samplesOf(id);
          expect(rows, hasLength(4), reason: p.id);
          expect({for (final d in rows) d.contentHash}, p.hashes);
          expect(
            {for (final d in rows.where((d) => d.kind == 'note')) d.title},
            {for (final n in p.notes) n.title},
          );
          final pdf = rows.singleWhere((d) => d.kind == 'pdf');
          expect(pdf.storagePath, 'pdfs/${pdf.id}.pdf');
          expect(await DemoGuard.countOwn(sb.build(), id), 0);
        }
        // The shared PDF is one row per account, not one row in total.
        final pdfRows = await Document.db.count(
          sb.build(),
          where: (t) => t.contentHash.equals(pack.pdf!.hash),
        );
        expect(pdfRows, 2);
      });

      test('create limits are independent', () async {
        for (var i = 0; i < demoCreateLimit; i++) {
          await ownRow(age: Duration(minutes: i + 1));
        }
        await expectLater(
          endpoints.document.saveNote(demo, null, 'x', 'one more', null),
          throwsA(isA<DemoLimitException>()),
        );
        expect(await DemoGuard.countOwn(sb.build(), koId), 0);
        final doc = await endpoints.document.saveNote(
          demoKo,
          null,
          'ko',
          'hello',
          null,
        );
        expect(doc.ownerId, koId);
        expect((await endpoints.demo.status(demo)).createRemaining, 0);
        expect(
          (await endpoints.demo.status(demoKo)).createRemaining,
          demoCreateLimit - 1,
        );
      });

      test(
        "samples are protected per account, by that account's pack",
        () async {
          final koNote = await sampleRow(koPack.notes[1].hash, owner: koId);
          Matcher locked() => throwsA(
            isA<DemoLimitException>().having(
              (e) => e.reason,
              'reason',
              DemoLimitReason.sampleLocked,
            ),
          );
          await expectLater(
            endpoints.document.delete(demoKo, koNote.id!),
            locked(),
          );
          await expectLater(
            endpoints.document.saveNote(
              demoKo,
              null,
              'copy',
              koPack.notes[0].body,
              null,
            ),
            locked(),
          );
          // The Korean body is only a normal note in the English account.
          final copy = await endpoints.document.saveNote(
            demo,
            null,
            'copy',
            koPack.notes[0].body,
            null,
          );
          expect(await DemoGuard.countOwn(sb.build(), demoId), 1);
          await endpoints.document.delete(demo, copy.id!);
        },
      );

      test(
        'purge: each account loses only its own expired documents',
        () async {
          final oldEn = await ownRow(age: const Duration(hours: 25));
          final oldKo = await ownRow(
            age: const Duration(hours: 25),
            owner: koId,
          );
          final freshKo = await ownRow(
            age: const Duration(hours: 1),
            owner: koId,
          );
          final enSample = await sampleRow(pack.notes[0].hash);
          final koSample = await sampleRow(koPack.notes[0].hash, owner: koId);
          for (final d in [enSample, koSample]) {
            await Document.db.updateRow(
              sb.build(),
              d.copyWith(
                createdAt: DateTime.now().toUtc().subtract(
                  const Duration(days: 3),
                ),
              ),
            );
          }

          await endpoints.demo.signIn(visitor, 'ko');

          final s = sb.build();
          expect(await Document.db.findById(s, oldEn.id!), isNull);
          expect(await Document.db.findById(s, oldKo.id!), isNull);
          expect(await Document.db.findById(s, freshKo.id!), isNotNull);
          expect(await Document.db.findById(s, enSample.id!), isNotNull);
          expect(await Document.db.findById(s, koSample.id!), isNotNull);
        },
      );

      test('legacy cleanup runs per account', () async {
        final legacy = SamplePacks.demoLegacy.first;
        final en = await sampleRow(legacy);
        final ko = await sampleRow(legacy, owner: koId);
        await DemoSeed.run(seed.build(), demoId, pack);
        final s = sb.build();
        expect(await Document.db.findById(s, en.id!), isNull);
        expect(await Document.db.findById(s, ko.id!), isNotNull);
        await DemoSeed.run(seedKo.build(), koId, koPack);
        expect(await Document.db.findById(s, ko.id!), isNull);
      });

      test(
        'the daily question limit is one counter for both accounts',
        () async {
          DemoGuard.askCounter = DailyCounter(2);
          DemoGuard.consumeAsk(demo.build(), demoId);
          DemoGuard.consumeAsk(demoKo.build(), koId);
          expect(
            () => DemoGuard.consumeAsk(demoKo.build(), koId),
            throwsA(isA<DemoLimitException>()),
          );
          expect(
            () => DemoGuard.consumeAsk(demo.build(), demoId),
            throwsA(isA<DemoLimitException>()),
          );
          expect((await endpoints.demo.status(demoKo)).askRemaining, 0);
          // The seed session and regular users do not use it.
          DemoGuard.consumeAsk(seedKo.build(), koId);
          DemoGuard.consumeAsk(other.build(), otherId);
        },
      );

      test(
        'the shared limit also ends an Ask stream of the ko account',
        () async {
          DemoGuard.askCounter = DailyCounter(0);
          await expectLater(
            endpoints.ask.ask(demoKo, '질문?', [], true, null, 'ko'),
            emitsError(isA<DemoLimitException>()),
          );
        },
      );

      test('neither account can create a project or be invited', () async {
        final project = await endpoints.project.create(other, 'Team');
        for (final (s, p) in [(demoKo, koPack), (demo, pack)]) {
          await expectLater(
            endpoints.project.create(s, 'Team'),
            throwsA(isA<DemoLimitException>()),
          );
          await expectLater(
            endpoints.project.addMember(
              other,
              project.id!,
              p.accountEmail!,
              'viewer',
            ),
            throwsA(isA<DemoLimitException>()),
          );
        }
      });
    });

    group('sampleHints', () {
      Future<Document> noteOf(
        UuidValue owner,
        SampleNote n, {
        String status = 'ready',
        String kind = 'note',
        int? projectId,
      }) {
        final now = DateTime.now().toUtc();
        return Document.db.insertRow(
          sb.build(),
          Document(
            ownerId: owner,
            projectId: projectId,
            kind: kind,
            title: n.title,
            body: n.body,
            contentHash: n.hash,
            version: 1,
            pageCount: 1,
            status: status,
            embeddingModel: 'm',
            createdAt: now,
            updatedAt: now,
          ),
        );
      }

      List<String> ids(List<SampleHint> h) => [for (final x in h) x.packId];

      test('a plain account without a sample gets nothing', () async {
        expect(await endpoints.document.sampleHints(other), isEmpty);
      });

      test('sign-up sample: only while ready, in its own language', () async {
        final en = SamplePacks.signupEn;
        final ko = SamplePacks.signupKo;
        final indexing = await noteOf(
          otherId,
          en.notes.first,
          status: 'indexing',
        );
        expect(await endpoints.document.sampleHints(other), isEmpty);

        await Document.db.updateRow(
          sb.build(),
          indexing.copyWith(status: 'ready'),
        );
        var hints = await endpoints.document.sampleHints(other);
        expect(ids(hints), ['signup-en']);
        expect(hints.single.locale, 'en');
        expect(hints.single.questions, [for (final q in en.questions) q.text]);

        // Localized by ensureSample: the hash is the Korean body's.
        await Document.db.updateRow(
          sb.build(),
          indexing.copyWith(
            status: 'ready',
            title: ko.notes.first.title,
            body: ko.notes.first.body,
            contentHash: ko.notes.first.hash,
          ),
        );
        hints = await endpoints.document.sampleHints(other);
        expect(ids(hints), ['signup-ko']);
        expect(hints.single.questions, [for (final q in ko.questions) q.text]);

        // Edited (hash changes) or deleted: the questions go away.
        await Document.db.updateRow(
          sb.build(),
          indexing.copyWith(status: 'ready', contentHash: sha256Hex('mine')),
        );
        expect(await endpoints.document.sampleHints(other), isEmpty);
        await Document.db.deleteRow(sb.build(), indexing);
        expect(await endpoints.document.sampleHints(other), isEmpty);
      });

      test('a sample copy in a project or a PDF does not count', () async {
        final n = SamplePacks.signupEn.notes.first;
        final project = await endpoints.project.create(other, 'Team');
        await noteOf(otherId, n, projectId: project.id);
        await noteOf(otherId, n, kind: 'pdf');
        expect(await endpoints.document.sampleHints(other), isEmpty);
      });

      test('a demo account gets its pack at once, ready or not', () async {
        for (final (s, p) in [(demo, pack), (demoKo, koPack)]) {
          final hints = await endpoints.document.sampleHints(s);
          expect(ids(hints), [p.id]);
          expect(hints.single.locale, p.locale);
          expect(hints.single.questions, [for (final q in p.questions) q.text]);
        }
      });
    });

    test('a normal user is not affected by any demo rule', () async {
      for (var i = 0; i < demoCreateLimit + 2; i++) {
        await endpoints.document.saveNote(other, null, 't$i', 'n$i', null);
      }
      final copy = await endpoints.document.saveNote(
        other,
        null,
        'copy',
        pack.notes[0].body,
        null,
      );
      expect(copy.ownerId, otherId);
      await endpoints.document.saveNote(other, copy.id, 'edit', 'new', null);
      await endpoints.document.upload(
        other,
        'p',
        pages('x'),
        pack.pdf!.hash,
        null,
      );
      await endpoints.document.reindex(other, copy.id!);
      expect(await endpoints.document.reindexFailed(other), isA<int>());
      await endpoints.document.delete(other, copy.id!);
      expect(await endpoints.project.create(other, 'Team'), isNotNull);
      // An exhausted shared counter does not touch a normal user.
      DemoGuard.askCounter = DailyCounter(0);
      DemoGuard.consumeAsk(other.build(), otherId);
    });
  });
}
