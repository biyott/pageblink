import 'dart:typed_data';

import 'package:pageblink_server/src/demo/demo_config.dart';
import 'package:pageblink_server/src/demo/demo_guard.dart';
import 'package:pageblink_server/src/demo/demo_samples.dart';
import 'package:pageblink_server/src/demo/demo_seed.dart';
import 'package:pageblink_server/src/demo/demo_user.dart';
import 'package:pageblink_server/src/generated/protocol.dart';
import 'package:pageblink_server/src/rag/chunker.dart';
import 'package:serverpod/serverpod.dart';
import 'package:serverpod_auth_idp_server/core.dart';
import 'package:serverpod_auth_idp_server/providers/email.dart';
import 'package:test/test.dart';

import 'test_tools/serverpod_test_tools.dart';

/// Run with the embedding/LLM keys unset (`env -u GEMINI_API_KEY ...`): the
/// documents then end `failed` without any network call. Nothing here depends
/// on a document being `ready`.
void main() {
  setUpAll(() {
    AuthServices.set(
      tokenManagerBuilders: [JwtConfigFromPasswords()],
      identityProviderBuilders: [
        ServerpodCloudEmailIdpConfig(appDisplayName: 'pageblink'),
      ],
    );
  });

  withServerpod('Given the demo account', (sb, endpoints) {
    late UuidValue demoId;
    late TestSessionBuilder demo;
    late TestSessionBuilder visitor; // not logged in
    late UuidValue otherId;
    late TestSessionBuilder other; // a normal user
    late TestSessionBuilder seed;

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
      demoId = await DemoUser.ensure(sb.build());
      demo = as(demoId);
      seed = as(demoId, authId: demoSeedAuthId);
      visitor = sb;
      otherId = const Uuid().v4obj();
      other = as(otherId);
    });

    tearDown(() {
      DemoConfig.debugOverride = null;
      DemoUser.demoUserId = null;
    });

    Future<Document> sampleRow(
      String hash, {
      String status = 'ready',
      String kind = 'note',
    }) {
      final now = DateTime.now().toUtc();
      return Document.db.insertRow(
        sb.build(),
        Document(
          ownerId: demoId,
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

    test('ensure is idempotent: one user, one email account', () async {
      final again = await DemoUser.ensure(sb.build());
      expect(again, demoId);
      final accounts = await EmailAccount.db.count(
        sb.build(),
        where: (t) => t.email.equals(demoEmail),
      );
      expect(accounts, 1);
    });

    test('flag off: status is only enabled=false, signIn refuses, '
        'nothing is created', () async {
      DemoConfig.debugOverride = false;
      DemoUser.demoUserId = null;
      await EmailAccount.db.deleteWhere(
        sb.build(),
        where: (t) => t.email.equals(demoEmail),
      );

      final status = await endpoints.demo.status(visitor);
      expect(status.enabled, isFalse);
      expect(status.isDemo, isFalse);
      expect(status.createLimit, 0);
      expect(status.createRemaining, isNull);
      await expectLater(endpoints.demo.signIn(visitor), throwsA(anything));
      expect(
        await EmailAccount.db.count(
          sb.build(),
          where: (t) => t.email.equals(demoEmail),
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
      await sampleRow(DemoSamples.noteEn.hash);
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
      await sampleRow(DemoSamples.noteKo.hash);

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
        sampleNote = await sampleRow(DemoSamples.noteEn.hash);
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
        final pdf = await sampleRow(DemoSamples.pdfHash, kind: 'pdf');
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
          await sampleRow(DemoSamples.pdfHash, status: 'failed');
          await expectLater(
            endpoints.document.upload(
              demo,
              'fake',
              pages('visitor text'),
              DemoSamples.pdfHash,
              null,
            ),
            locked(),
          );
          final row = await Document.db.findFirstRow(
            sb.build(),
            where: (t) => t.contentHash.equals(DemoSamples.pdfHash),
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
            DemoSamples.noteEn.body,
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
            DemoSamples.noteEn.body,
            null,
          ),
          locked(),
        );
      });

      test(
        '4. reindexFailed skips a failed sample instead of failing',
        () async {
          await sampleRow(DemoSamples.pdfHash, status: 'failed');
          expect(await endpoints.document.reindexFailed(demo), 0);
        },
      );

      test('the internal seed session is not blocked', () async {
        final doc = await endpoints.document.saveNote(
          seed,
          null,
          DemoSamples.noteKo.title,
          DemoSamples.noteKo.body,
          null,
        );
        expect(doc.contentHash, DemoSamples.noteKo.hash);
      });
    });

    test('seeding is idempotent and stores the sample PDF original', () async {
      Future<List<Document>> samples() => Document.db.find(
        sb.build(),
        where: (t) =>
            t.ownerId.equals(demoId) & t.contentHash.inSet(DemoSamples.markers),
      );
      await DemoSeed.run(seed.build(), demoId);
      await DemoSeed.run(seed.build(), demoId);
      final rows = await samples();
      expect(rows, hasLength(3));
      final pdf = rows.singleWhere((d) => d.kind == 'pdf');
      expect(pdf.pageCount, DemoSamples.pdfPages.length);
      expect(pdf.storagePath, 'pdfs/${pdf.id}.pdf');
      // They do not take a visitor slot.
      expect(await DemoGuard.countOwn(sb.build(), demoId), 0);
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
          demoEmail,
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
      DemoUser.demoUserId = null;
      expect(await DemoUser.load(sb.build()), demoId);

      await expectLater(
        endpoints.document.saveNote(demo, null, 'x', 'one more', null),
        throwsA(isA<DemoLimitException>()),
      );
      await expectLater(
        endpoints.project.create(demo, 'Team'),
        throwsA(isA<DemoLimitException>()),
      );
      expect(await Document.db.findById(sb.build(), expired.id!), isNotNull);
    });

    test('signIn purges documents and tokens older than 24 hours', () async {
      final old = await ownRow(age: const Duration(hours: 25));
      final fresh = await ownRow(age: const Duration(hours: 1));
      final oldSample = await sampleRow(DemoSamples.noteEn.hash);
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

    test('a normal user is not affected by any demo rule', () async {
      for (var i = 0; i < demoCreateLimit + 2; i++) {
        await endpoints.document.saveNote(other, null, 't$i', 'n$i', null);
      }
      final copy = await endpoints.document.saveNote(
        other,
        null,
        'copy',
        DemoSamples.noteEn.body,
        null,
      );
      expect(copy.ownerId, otherId);
      await endpoints.document.saveNote(other, copy.id, 'edit', 'new', null);
      await endpoints.document.upload(
        other,
        'p',
        pages('x'),
        DemoSamples.pdfHash,
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
