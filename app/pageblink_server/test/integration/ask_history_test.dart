import 'dart:async';
import 'dart:io';

import 'package:pageblink_server/src/demo/demo_config.dart';
import 'package:pageblink_server/src/demo/demo_guard.dart';
import 'package:pageblink_server/src/demo/demo_seed.dart';
import 'package:pageblink_server/src/demo/demo_user.dart';
import 'package:pageblink_server/src/generated/protocol.dart';
import 'package:pageblink_server/src/providers/embedding_provider.dart';
import 'package:pageblink_server/src/providers/llm_provider.dart';
import 'package:pageblink_server/src/rag/embedding_spec.dart';
import 'package:pageblink_server/src/rag_endpoints/ask_admin_endpoint.dart';
import 'package:pageblink_server/src/sample/sample_pack.dart';
import 'package:pageblink_server/src/services/ask_config.dart';
import 'package:pageblink_server/src/services/ask_history_store.dart';
import 'package:pageblink_server/src/services/llm_catalog.dart';
import 'package:pageblink_server/src/services/maintenance_timer.dart';
import 'package:pageblink_server/src/services/rag_services.dart';
import 'package:serverpod/protocol.dart' as internal;
import 'package:serverpod/serverpod.dart';
import 'package:serverpod_auth_idp_server/core.dart';
import 'package:serverpod_auth_idp_server/providers/email.dart';
import 'package:test/test.dart';

import 'test_tools/serverpod_test_tools.dart';

/// Run with the embedding/LLM keys unset (`env -u GEMINI_API_KEY ...`).
/// The history is written by sessions of its own (they do not join the test
/// transaction), so this group does not roll back: every test starts by
/// emptying the history tables.
class _Embedder implements EmbeddingProvider {
  @override
  String get modelId => 'fake/embed';
  final inputs = <String>[];

  @override
  Future<List<List<double>>> embed(List<String> texts) async {
    inputs.addAll(texts);
    return [for (final t in texts) vector(t)];
  }

  static List<double> vector(String text) {
    final v = List<double>.filled(EmbeddingSpec.dimensions, 0);
    v[0] = 0.1;
    for (final m in RegExp(r'[a-z0-9가-힣]+').allMatches(text.toLowerCase())) {
      var h = 0x811c9dc5;
      for (final u in m.group(0)!.codeUnits) {
        h = ((h ^ u) * 0x01000193) & 0x7fffffff;
      }
      v[1 + h % (EmbeddingSpec.dimensions - 1)] += 1;
    }
    var n = 0.0;
    for (final x in v) {
      n += x * x;
    }
    n = n == 0 ? 1 : n;
    return [for (final x in v) x / n];
  }
}

class _Llm implements LlmProvider {
  final histories = <List<ChatTurn>>[];
  final questions = <String>[];

  /// Replaces the default answer.
  Stream<LlmEvent> Function(List<SourcePassage> sources, int call)? script;

  @override
  Stream<LlmEvent> answer(
    String question,
    List<SourcePassage> sources, {
    List<ChatTurn> history = const [],
  }) {
    final call = questions.length;
    questions.add(question);
    histories.add(history);
    return (script ?? _default)(sources, call);
  }

  static Stream<LlmEvent> _default(List<SourcePassage> sources, int call) =>
      Stream.fromIterable([
        LlmModelUsed('fake/model'),
        LlmText('Answer ${call + 1} [1]'),
        if (sources.isNotEmpty) LlmCitation(0, ''),
        LlmDone('stop'),
      ]);
}

const _note =
    '# Q4 launch plan\n\n'
    '## Numbers\n'
    '- **Marketing budget:** 12M for Q4\n'
    '- **Launch date:** moved to Nov 18\n';

/// The refusal of `askAdmin.listSessions`: a serialized exception with the
/// rule that applied, never a bare AccessDeniedException (HTTP 500 + ERROR).
Matcher _denied(AskAdminReason reason) => isA<AskAdminException>().having(
  (e) => e.reason,
  'reason',
  reason,
);

void main() {
  final embedder = _Embedder();
  final llm = _Llm();

  setUpAll(() {
    AuthServices.set(
      tokenManagerBuilders: [JwtConfigFromPasswords()],
      identityProviderBuilders: [
        ServerpodCloudEmailIdpConfig(appDisplayName: 'pageblink'),
      ],
    );
  });

  withServerpod(
    'Given Ask history',
    rollbackDatabase: RollbackDatabase.disabled,
    (sb, endpoints) {
      late UuidValue ownerId;
      late TestSessionBuilder user;

      TestSessionBuilder as(UuidValue id) => sb.copyWith(
        authentication: AuthenticationOverride.authenticationInfo(
          id.toString(),
          {},
        ),
      );

      /// One searchable chunk, so that the model is asked (no indexing run).
      Future<void> seedDoc(UuidValue owner) async {
        final now = DateTime.now().toUtc();
        final d = await Document.db.insertRow(
          sb.build(),
          Document(
            ownerId: owner,
            kind: 'note',
            title: 'Q4 launch plan',
            body: _note,
            contentHash: 'seed-$owner',
            version: 1,
            pageCount: 1,
            status: 'ready',
            embeddingModel: 'fake/embed#c2',
            createdAt: now,
            updatedAt: now,
          ),
        );
        await DocChunk.db.insertRow(
          sb.build(),
          DocChunk(
            documentId: d.id!,
            ownerId: owner,
            page: 1,
            ordinal: 0,
            text: '- **Launch date:** moved to Nov 18',
            contentHash: 'seed-chunk-$owner',
            embedding: Vector(_Embedder.vector('launch date Nov 18')),
          ),
        );
      }

      /// A signed-in user who has something to ask about.
      Future<TestSessionBuilder> member() async {
        final id = const Uuid().v4obj();
        await seedDoc(id);
        return as(id);
      }

      Future<void> clean() async {
        final s = sb.build();
        await AskSession.db.deleteWhere(s, where: (t) => t.id > 0);
      }

      setUp(() async {
        await clean();
        AskConfig.debugValues
          ..clear()
          ..['ASK_HISTORY_ENABLED'] = 'true';
        AskStore.debugResetSweep();
        embedder.inputs.clear();
        llm
          ..histories.clear()
          ..questions.clear()
          ..script = null;
        RagServices.debugEmbedding = embedder;
        RagServices.debugLlm = llm;
        DemoConfig.debugOverride = true;
        DemoSeed.debugDisabled = true;
        DemoGuard.askCounter = DailyCounter(demoAskDailyLimit);
        DemoUser.debugReset();
        ownerId = const Uuid().v4obj();
        user = as(ownerId);
        await Document.db.deleteWhere(
          sb.build(),
          where: (t) => t.contentHash.like('seed-%'),
        );
        await DocChunk.db.deleteWhere(
          sb.build(),
          where: (t) => t.contentHash.like('seed-chunk-%'),
        );
        await seedDoc(ownerId);
      });

      tearDown(() async {
        RagServices.debugEmbedding = null;
        RagServices.debugLlm = null;
        DemoConfig.debugOverride = null;
        DemoUser.debugReset();
        AskConfig.debugValues.clear();
        await AskStore.sweeping;
      });

      Stream<AnswerEvent> ask(
        TestSessionBuilder who,
        String q, {
        int? sessionId = 0,
        String? key,
        String? model,
        String? locale,
      }) => endpoints.ask.ask(who, q, [], true, model, locale, sessionId, key);

      Future<List<AnswerEvent>> askAll(
        TestSessionBuilder who,
        String q, {
        int? sessionId = 0,
        String? key,
      }) => ask(who, q, sessionId: sessionId, key: key).toList();

      Future<int> newSession(TestSessionBuilder who, String q) async {
        final events = await askAll(who, q);
        return events.firstWhere((e) => e.type == 'session').sessionId!;
      }

      Future<List<AskMessage>> messagesOf(int id) => AskMessage.db.find(
        sb.build(),
        where: (t) => t.sessionId.equals(id),
        orderBy: (t) => t.seq,
      );

      Future<AskSession> row(int id) async =>
          (await AskSession.db.findById(sb.build(), id))!;

      Future<void> setActive(int id, {Duration? ago, Duration? streaming}) =>
          AskSession.db.updateWhere(
            sb.build(),
            columnValues: (t) => [
              if (ago != null)
                t.lastActiveAt(DateTime.now().toUtc().subtract(ago)),
              if (streaming != null)
                t.streamingSince(DateTime.now().toUtc().subtract(streaming)),
            ],
            where: (t) => t.id.equals(id),
            noReturn: true,
          );

      Matcher refused(AskLimitReason reason) => throwsA(
        isA<AskLimitException>().having((e) => e.reason, 'reason', reason),
      );

      group('a conversation', () {
        test('history off: no session event, nothing stored', () async {
          AskConfig.debugValues['ASK_HISTORY_ENABLED'] = 'false';
          final events = await askAll(user, 'hello?');
          expect(events.map((e) => e.type), isNot(contains('session')));
          expect(events.last.type, 'done');
          expect(await AskSession.db.count(sb.build()), 0);
          // restore / open / status are empty, not errors
          final status = await endpoints.askHistory.historyStatus(user);
          expect(status.enabled, isFalse);
          expect(status.isAdmin, isFalse);
          expect((await endpoints.askHistory.restore(user)).recent, isEmpty);
          expect(await endpoints.askHistory.open(user, 1), isNull);
        });

        test(
          'new question: session event first, then stored as done',
          () async {
            final events = await askAll(user, 'When is the launch date?');
            expect(events.first.type, 'session');
            final e = events.first;
            expect([e.questionCount, e.questionLimit], [1, 10]);
            expect(events.last.type, 'done');

            final id = e.sessionId!;
            final s = await row(id);
            expect(s.title, 'When is the launch date?');
            expect(s.questionCount, 1);
            expect(s.streamingSince, isNull);
            expect(s.hiddenAt, isNull);
            expect(s.isDemo, isFalse);
            final m = (await messagesOf(id)).single;
            expect(
              [m.seq, m.status, m.question],
              [1, 'done', 'When is the launch date?'],
            );
            expect(m.answer, 'Answer 1 [1]');
            expect(m.modelId, 'fake/model');
            expect(m.citations!.single.index, 1);
            expect(
              m.fallback,
              isTrue,
              reason: 'asked for the default, got other',
            );
          },
        );

        test('fallback compares with the model asked for', () async {
          final events = await ask(user, 'q', model: 'fake/model').toList();
          final id = events.first.sessionId!;
          expect((await messagesOf(id)).single.fallback, isFalse);
          llm.script = (_, _) => Stream.fromIterable([
            LlmModelUsed(LlmCatalog.defaultModelId),
            LlmText('x'),
            LlmDone('stop'),
          ]);
          final again = await askAll(user, 'q2');
          expect(
            (await messagesOf(again.first.sessionId!)).single.fallback,
            isFalse,
            reason: 'Auto: the default model answered',
          );
        });

        test('the next question goes on in the same conversation', () async {
          final id = await newSession(user, 'first');
          final events = await askAll(user, 'second', sessionId: id);
          expect(events.first.sessionId, id);
          expect(events.first.questionCount, 2);
          final ms = await messagesOf(id);
          expect(ms.map((m) => m.seq), [1, 2]);
          expect((await row(id)).questionCount, 2);
        });

        test('someone else\'s conversation id is refused as expired', () async {
          final id = await newSession(user, 'mine');
          final other = as(const Uuid().v4obj());
          await expectLater(
            ask(other, 'steal', sessionId: id).toList(),
            refused(AskLimitReason.expired),
          );
          await expectLater(
            ask(user, 'nope', sessionId: 999999).toList(),
            refused(AskLimitReason.expired),
          );
          expect(await messagesOf(id), hasLength(1));
        });

        test('an old app (no id): recorded hidden, never limited', () async {
          AskConfig.debugValues['ASK_SESSION_MAX_QUESTIONS'] = '3';
          for (var i = 0; i < 5; i++) {
            final events = await askAll(user, 'legacy $i', sessionId: null);
            expect(events.map((e) => e.type), isNot(contains('session')));
            expect(events.last.type, 'done');
          }
          final rows = await AskSession.db.find(sb.build());
          expect(rows, hasLength(5));
          expect(rows.every((r) => r.hiddenAt != null), isTrue);
          expect(
            llm.histories.every((h) => h.isEmpty),
            isTrue,
            reason: 'no earlier turns for a legacy request',
          );
          final restore = await endpoints.askHistory.restore(user);
          expect(restore.recent, isEmpty);
          expect(restore.current, isNull);
        });

        test(
          'the question limit counts failed answers; 11th is refused',
          () async {
            AskConfig.debugValues['ASK_SESSION_MAX_QUESTIONS'] = '3';
            final id = await newSession(user, 'one');
            llm.script = (_, _) => Stream.error(LlmException('boom'));
            final failed = await askAll(user, 'two', sessionId: id);
            expect(failed.last.type, 'error');
            await askAll(user, 'three', sessionId: id);
            await expectLater(
              ask(user, 'four', sessionId: id).toList(),
              throwsA(
                isA<AskLimitException>()
                    .having(
                      (e) => e.reason,
                      'reason',
                      AskLimitReason.questionLimit,
                    )
                    .having((e) => e.limit, 'limit', 3),
              ),
            );
            expect(await messagesOf(id), hasLength(3));
            final view = (await endpoints.askHistory.open(user, id))!;
            expect([view.questionCount, view.questionLimit], [3, 3]);
          },
        );

        test('the viewing window: 29 minutes ok, 31 expired', () async {
          final id = await newSession(user, 'q');
          await setActive(id, ago: const Duration(minutes: 29));
          expect(await endpoints.askHistory.open(user, id), isNotNull);
          expect(
            (await endpoints.askHistory.restore(user)).recent.map((r) => r.id),
            [id],
          );
          await askAll(user, 'still fine', sessionId: id);
          // asking renewed it; now let it lapse
          await setActive(id, ago: const Duration(minutes: 31));
          expect(await endpoints.askHistory.open(user, id), isNull);
          expect((await endpoints.askHistory.restore(user)).recent, isEmpty);
          await expectLater(
            ask(user, 'late', sessionId: id).toList(),
            refused(AskLimitReason.expired),
          );
          // kept on the server, though
          expect(await row(id), isNotNull);
        });

        test(
          'resume: within 30 seconds the latest conversation comes back',
          () async {
            final id = await newSession(user, 'q');
            await setActive(id, ago: const Duration(seconds: 29));
            final fresh = await endpoints.askHistory.restore(user);
            expect(fresh.current!.id, id);
            expect(fresh.current!.messages.single.answer, 'Answer 1 [1]');
            expect(fresh.current!.messages.single.status, 'done');
            await setActive(id, ago: const Duration(seconds: 31));
            final later = await endpoints.askHistory.restore(user);
            expect(later.current, isNull);
            expect(later.recent.map((r) => r.id), [id]);
          },
        );

        test(
          'the list shows the 5 newest; the 6th pushes the oldest out',
          () async {
            final ids = <int>[];
            for (var i = 0; i < 6; i++) {
              ids.add(await newSession(user, 'topic $i'));
              await setActive(ids.last, ago: Duration(minutes: 20 - i * 3));
            }
            final recent = (await endpoints.askHistory.restore(user)).recent;
            expect(recent.map((r) => r.id), ids.reversed.take(5).toList());
            expect(recent.first.title, 'topic 5');
            expect(await AskSession.db.count(sb.build()), 6, reason: 'kept');
          },
        );

        test('hide: gone from the list, kept on the server', () async {
          final id = await newSession(user, 'secret-ish');
          await endpoints.askHistory.hide(user, id);
          expect((await endpoints.askHistory.restore(user)).recent, isEmpty);
          expect(await endpoints.askHistory.open(user, id), isNull);
          await expectLater(
            ask(user, 'again', sessionId: id).toList(),
            refused(AskLimitReason.expired),
          );
          expect((await row(id)).hiddenAt, isNotNull);
          // someone else cannot hide mine
          final id2 = await newSession(user, 'mine');
          await endpoints.askHistory.hide(as(const Uuid().v4obj()), id2);
          expect((await row(id2)).hiddenAt, isNull);
        });

        test('questions are cut to 2,000 characters', () async {
          final events = await askAll(user, ' ${'x' * 2500} ');
          final m = (await messagesOf(events.first.sessionId!)).single;
          expect(m.question.length, 2000);
          expect(llm.questions.single.length, 2000);
        });

        test('with the table gone, Ask still answers (no history)', () async {
          final s = sb.build();
          await s.db.unsafeExecute(
            'ALTER TABLE ask_message RENAME TO ask_message_gone',
          );
          addTearDown(
            () => sb.build().db.unsafeExecute(
              'ALTER TABLE ask_message_gone RENAME TO ask_message',
            ),
          );
          final events = await askAll(user, 'still works');
          expect(events.map((e) => e.type), isNot(contains('session')));
          expect(events.last.type, 'done');
        });
      });

      group('streaming', () {
        test('two questions at once: the second is refused as busy', () async {
          final id = await newSession(user, 'first');
          final gate = StreamController<LlmEvent>();
          llm.script = (_, _) => gate.stream;
          final events = <AnswerEvent>[];
          final sub = ask(user, 'slow', sessionId: id).listen(events.add);
          await _until(() => events.any((e) => e.type == 'session'));
          await expectLater(
            ask(user, 'impatient', sessionId: id).toList(),
            refused(AskLimitReason.busy),
          );
          gate
            ..add(LlmText('done'))
            ..add(LlmDone('stop'));
          await gate.close();
          await sub.asFuture<void>();
          expect((await row(id)).streamingSince, isNull);
          expect((await messagesOf(id)).map((m) => m.status), ['done', 'done']);
        });

        test('an abandoned stream (31 s old) no longer blocks', () async {
          final id = await newSession(user, 'first');
          await AskMessage.db.updateWhere(
            sb.build(),
            columnValues: (t) => [t.status('streaming')],
            where: (t) => t.sessionId.equals(id),
            noReturn: true,
          );
          await setActive(id, streaming: const Duration(seconds: 5));
          await expectLater(
            ask(user, 'too soon', sessionId: id).toList(),
            refused(AskLimitReason.busy),
          );
          await setActive(id, streaming: const Duration(seconds: 31));
          await askAll(user, 'now fine', sessionId: id);
          final ms = await messagesOf(id);
          expect(ms.map((m) => m.status), ['interrupted', 'done']);
        });

        test(
          'a stale streaming message reads as interrupted (no write)',
          () async {
            final id = await newSession(user, 'first');
            final old = DateTime.now().toUtc().subtract(
              const Duration(seconds: 40),
            );
            await AskMessage.db.updateWhere(
              sb.build(),
              columnValues: (t) => [t.status('streaming'), t.updatedAt(old)],
              where: (t) => t.sessionId.equals(id),
              noReturn: true,
            );
            await setActive(id, streaming: const Duration(seconds: 40));
            var view = (await endpoints.askHistory.open(user, id))!;
            expect(view.messages.single.status, 'interrupted');
            expect((await messagesOf(id)).single.status, 'streaming');
            // a fresh one is still streaming
            final now = DateTime.now().toUtc();
            await AskMessage.db.updateWhere(
              sb.build(),
              columnValues: (t) => [t.updatedAt(now)],
              where: (t) => t.sessionId.equals(id),
              noReturn: true,
            );
            await setActive(id, streaming: const Duration(seconds: 2));
            view = (await endpoints.askHistory.open(user, id))!;
            expect(view.messages.single.status, 'streaming');
          },
        );

        test(
          'the app disconnects mid-answer: partial answer saved as interrupted',
          () async {
            final gate = StreamController<LlmEvent>();
            llm.script = (_, _) => gate.stream;
            final events = <AnswerEvent>[];
            final sub = ask(
              user,
              'When is the launch date?',
            ).listen(events.add);
            gate
              ..add(LlmModelUsed('fake/model'))
              ..add(LlmText('The launch '))
              ..add(LlmCitation(0, ''));
            await _until(() => events.any((e) => e.type == 'citation'));
            final id = events.first.sessionId!;
            // disconnect; the generator notices at its next event
            final cancelled = sub.cancel();
            gate.add(LlmText('is Nov 18'));
            await cancelled.timeout(const Duration(seconds: 10));
            await gate.close();

            final m = (await messagesOf(id)).single;
            expect(m.status, 'interrupted');
            expect(m.answer, startsWith('The launch '));
            expect(m.citations, hasLength(1));
            expect(m.modelId, 'fake/model');
            expect((await row(id)).streamingSince, isNull);
            final view = (await endpoints.askHistory.open(user, id))!;
            expect(view.messages.single.status, 'interrupted');
            // it counts toward the limit, and the next question may be asked
            expect(view.questionCount, 1);
            await askAll(user, 'ask again', sessionId: id);
            // an interrupted turn is not handed to the model as history
            expect(llm.histories.last, isEmpty);
          },
        );

        test(
          'a failed answer is stored as error with a short code only',
          () async {
            llm.script = (_, _) => Stream.fromIterable([
              LlmText('partial'),
            ]).concatWith(Stream.error(LlmException('SECRET provider body')));
            final events = await askAll(user, 'q');
            expect(events.last.type, 'error');
            final m = (await messagesOf(events.first.sessionId!)).single;
            expect(
              [m.status, m.errorCode, m.answer],
              ['error', 'llm', 'partial'],
            );
            expect(m.toString(), isNot(contains('SECRET')));

            llm.script = (_, _) => Stream.error(LlmBusyException('cap'));
            final busy = await askAll(user, 'q2');
            final b = (await messagesOf(busy.first.sessionId!)).single;
            expect([b.status, b.errorCode], ['error', 'busy']);
          },
        );

        test('"nothing found" is a finished answer', () async {
          final events = await askAll(
            as(const Uuid().v4obj()),
            'no notes yet',
          );
          expect(events.last.type, 'done');
          final m = (await messagesOf(events.first.sessionId!)).single;
          expect(m.status, 'done');
          expect(m.answer, contains('Nothing relevant found'));
        });
      });

      group('multi-turn', () {
        test('earlier answers reach the model, markers removed', () async {
          final id = await newSession(user, 'What is the budget?');
          await askAll(user, 'And the launch date?', sessionId: id);
          await askAll(user, 'Who decides?', sessionId: id);
          expect(llm.histories[0], isEmpty);
          expect(llm.histories[1].map((t) => t.question), [
            'What is the budget?',
          ]);
          expect(llm.histories[1].single.answer, 'Answer 1');
          expect(llm.histories[2].map((t) => t.question), [
            'What is the budget?',
            'And the launch date?',
          ]);
          expect(llm.histories[2].map((t) => t.answer), [
            'Answer 1',
            'Answer 2',
          ]);
          // stored as streamed: the marker is still there
          expect((await messagesOf(id)).first.answer, 'Answer 1 [1]');
        });

        test(
          'only finished turns count; the budget keeps the newest',
          () async {
            final id = await newSession(user, 'first question here');
            llm.script = (_, _) => Stream.error(LlmException('x'));
            await askAll(user, 'failing one', sessionId: id);
            llm.script = null;
            await askAll(user, 'third question', sessionId: id);
            expect(llm.histories.last.map((t) => t.question), [
              'first question here',
            ], reason: 'the failed turn is not history');

            AskConfig.debugValues['ASK_CONTEXT_BUDGET_CHARS'] = '120';
            await askAll(user, 'fourth question', sessionId: id);
            // budget fits one turn (each costs ~40+q+a): the newest
            expect(llm.histories.last.map((t) => t.question), [
              'third question',
            ]);
          },
        );

        test(
          'the search query is the question plus the previous one (cut)',
          () async {
            final first = 'budget ${'z' * 700}';
            final id = await newSession(user, first);
            embedder.inputs.clear();
            await askAll(user, 'and the date?', sessionId: id);
            final sent = embedder.inputs.single;
            expect(
              sent,
              EmbeddingSpec.query('and the date?\n${first.substring(0, 600)}'),
            );
            // the model is asked only the current question
            expect(llm.questions.last, 'and the date?');
          },
        );

        test('a first question searches on its own', () async {
          embedder.inputs.clear();
          await askAll(user, 'launch date?');
          expect(embedder.inputs.single, EmbeddingSpec.query('launch date?'));
        });
      });

      group('demo visitors', () {
        late UuidValue demoId;
        late TestSessionBuilder demo;
        final keyA = 'A' * 22;
        final keyB = 'B' * 22;

        setUp(() async {
          demoId = await DemoUser.ensure(sb.build(), SamplePacks.demoEn);
          demo = as(demoId);
          await seedDoc(demoId);
        });

        test('each browser key sees only its own conversations', () async {
          final a = (await ask(
            demo,
            'from A',
            key: keyA,
          ).toList()).first.sessionId!;
          final b = (await ask(
            demo,
            'from B',
            key: keyB,
          ).toList()).first.sessionId!;
          expect(
            (await endpoints.askHistory.restore(
              demo,
              keyA,
            )).recent.map((r) => r.id),
            [a],
          );
          expect(
            (await endpoints.askHistory.restore(
              demo,
              keyB,
            )).recent.map((r) => r.id),
            [b],
          );
          expect(await endpoints.askHistory.open(demo, a, keyB), isNull);
          await endpoints.askHistory.hide(demo, a, keyB);
          expect((await row(a)).hiddenAt, isNull);
          await expectLater(
            ask(demo, 'hijack', sessionId: a, key: keyB).toList(),
            refused(AskLimitReason.expired),
          );
          final s = await row(a);
          expect([s.isDemo, s.visitorKeyHash], [true, isNot(keyA)]);
          expect(
            s.visitorKeyHash,
            hasLength(64),
            reason: 'a hash, not the key',
          );
        });

        test(
          'no key (or a bad one): answered, nothing recorded or shown',
          () async {
            for (final key in [
              null,
              'short',
              'has spaces and symbols !!!!!!',
            ]) {
              final events = await askAll(demo, 'hello', key: key);
              expect(events.map((e) => e.type), isNot(contains('session')));
              expect(events.last.type, 'done');
              final r = await endpoints.askHistory.restore(demo, key);
              expect([r.current, r.recent], [isNull, isEmpty]);
            }
            expect(await AskSession.db.count(sb.build()), 0);
            // a normal user's rows are not visible to demo either
            await newSession(user, 'normal');
            expect(
              (await endpoints.askHistory.restore(demo, keyA)).recent,
              isEmpty,
            );
          },
        );

        test(
          'every question of a conversation uses one of the daily 50',
          () async {
            DemoGuard.askCounter = DailyCounter(4);
            final id = (await ask(
              demo,
              'one',
              key: keyA,
            ).toList()).first.sessionId!;
            await askAll(demo, 'two', sessionId: id, key: keyA);
            expect(DemoGuard.askCounter.remaining, 2);
            // a refused question (limit) uses nothing
            AskConfig.debugValues['ASK_SESSION_MAX_QUESTIONS'] = '2';
            await expectLater(
              ask(demo, 'three', sessionId: id, key: keyA).toList(),
              refused(AskLimitReason.questionLimit),
            );
            expect(DemoGuard.askCounter.remaining, 2);
            // the daily limit still ends the stream as before
            AskConfig.debugValues.remove('ASK_SESSION_MAX_QUESTIONS');
            DemoGuard.askCounter = DailyCounter(0);
            await expectLater(
              ask(demo, 'four', sessionId: id, key: keyA).toList(),
              throwsA(isA<DemoLimitException>()),
            );
          },
        );

        test('status: demo gets the shorter keeping time', () async {
          final s = await endpoints.askHistory.historyStatus(demo);
          expect([s.enabled, s.retentionDays, s.isAdmin], [true, 7, false]);
          final n = await endpoints.askHistory.historyStatus(user);
          expect(
            [n.retentionDays, n.questionLimit, n.visibleMinutes],
            [30, 10, 30],
          );
          expect(n.questionMaxChars, 2000);
        });
      });

      group('keeping time', () {
        Future<int> seed(
          UuidValue owner,
          Duration age, {
          bool demo = false,
          int messages = 2,
        }) async {
          final at = DateTime.now().toUtc().subtract(age);
          final s = await AskSession.db.insertRow(
            sb.build(),
            AskSession(
              ownerId: owner,
              visitorKeyHash: demo ? 'h' * 64 : null,
              isDemo: demo,
              title: 't',
              questionCount: messages,
              createdAt: at,
              lastActiveAt: at,
            ),
          );
          for (var i = 1; i <= messages; i++) {
            await AskMessage.db.insertRow(
              sb.build(),
              AskMessage(
                sessionId: s.id!,
                seq: i,
                question: 'q',
                status: 'done',
                createdAt: at,
                updatedAt: at,
              ),
            );
          }
          return s.id!;
        }

        Future<int> purge({int batch = 200}) => AskStore.run(
          sb.build(),
          (s) => AskStore.purge(s, AskConfig.of(s), batch: batch),
        );

        test(
          '30 days for everyone, 7 for demo; messages go with them',
          () async {
            final old = await seed(ownerId, const Duration(days: 31));
            final young = await seed(ownerId, const Duration(days: 29));
            final demoOld = await seed(
              ownerId,
              const Duration(days: 8),
              demo: true,
            );
            final demoYoung = await seed(
              ownerId,
              const Duration(days: 6),
              demo: true,
            );
            expect(await purge(), 2);
            final left = (await AskSession.db.find(
              sb.build(),
            )).map((r) => r.id);
            expect(left, unorderedEquals([young, demoYoung]));
            expect(await AskMessage.db.count(sb.build()), 4);
            expect(left, isNot(contains(old)));
            expect(left, isNot(contains(demoOld)));
            expect(await purge(), 0, reason: 'idempotent');
          },
        );

        test('works through batches', () async {
          for (var i = 0; i < 7; i++) {
            await seed(ownerId, Duration(days: 40 + i), messages: 1);
          }
          final keep = await seed(ownerId, const Duration(days: 1));
          expect(await purge(batch: 3), 7);
          expect((await AskSession.db.find(sb.build())).single.id, keep);
        });

        test('two runs at once do no harm', () async {
          for (var i = 0; i < 5; i++) {
            await seed(ownerId, const Duration(days: 40), messages: 1);
          }
          final both = await Future.wait([purge(batch: 2), purge(batch: 2)]);
          expect(both.fold<int>(0, (a, b) => a + b), greaterThanOrEqualTo(5));
          expect(await AskSession.db.count(sb.build()), 0);
        });

        test('the hourly job runs even while history is off', () async {
          AskConfig.debugValues['ASK_HISTORY_ENABLED'] = 'false';
          await seed(ownerId, const Duration(days: 31));
          final deleted = await MaintenanceTimer.askHistory.run(sb.build());
          expect(deleted, 1);
        });

        test('an answer abandoned while streaming is settled', () async {
          final id = await seed(
            ownerId,
            const Duration(minutes: 20),
            messages: 1,
          );
          await AskMessage.db.updateWhere(
            sb.build(),
            columnValues: (t) => [t.status('streaming')],
            where: (t) => t.sessionId.equals(id),
            noReturn: true,
          );
          await setActive(id, streaming: const Duration(minutes: 10));
          await purge();
          expect((await messagesOf(id)).single.status, 'interrupted');
          expect((await row(id)).streamingSince, isNull);
        });

        test(
          'a new conversation also sweeps a few expired ones, at most every 5 minutes',
          () async {
            for (var i = 0; i < 25; i++) {
              await seed(ownerId, const Duration(days: 60), messages: 1);
            }
            await newSession(user, 'first');
            await AskStore.sweeping;
            expect(await AskSession.db.count(sb.build()), 5 + 1);
            await newSession(user, 'second');
            await AskStore.sweeping;
            expect(
              await AskSession.db.count(sb.build()),
              5 + 2,
              reason: 'not again so soon',
            );
          },
        );
      });

      group('administrators', () {
        late UuidValue adminId;
        late TestSessionBuilder admin;

        setUp(() {
          adminId = const Uuid().v4obj();
          admin = as(adminId);
          AskConfig.debugValues['ADMIN_USER_IDS'] =
              ' ${adminId.toString().toUpperCase()} ,junk';
        });

        test(
          'only listed users; the answer is decided on every call',
          () async {
            expect(
              (await endpoints.askHistory.historyStatus(admin)).isAdmin,
              isTrue,
            );
            expect(
              (await endpoints.askHistory.historyStatus(user)).isAdmin,
              isFalse,
            );
            await expectLater(
              endpoints.askAdmin.listSessions(user, AskAdminFilter()),
              throwsA(_denied(AskAdminReason.notAdmin)),
            );
            // list emptied: no administrator any more
            AskConfig.debugValues['ADMIN_USER_IDS'] = '';
            await expectLater(
              endpoints.askAdmin.listSessions(admin, AskAdminFilter()),
              throwsA(_denied(AskAdminReason.notAdmin)),
            );
            expect(
              (await endpoints.askHistory.historyStatus(admin)).isAdmin,
              isFalse,
            );
          },
        );

        test('history off: no administrator either', () async {
          AskConfig.debugValues['ASK_HISTORY_ENABLED'] = 'false';
          expect(
            (await endpoints.askHistory.historyStatus(admin)).isAdmin,
            isFalse,
          );
          await expectLater(
            endpoints.askAdmin.listSessions(admin, AskAdminFilter()),
            throwsA(_denied(AskAdminReason.disabled)),
          );
        });

        test('a shared demo account can never be an administrator', () async {
          final demoId = await DemoUser.ensure(sb.build(), SamplePacks.demoEn);
          AskConfig.debugValues['ADMIN_USER_IDS'] = demoId.toString();
          final demo = as(demoId);
          expect(
            (await endpoints.askHistory.historyStatus(demo)).isAdmin,
            isFalse,
          );
          await expectLater(
            endpoints.askAdmin.listSessions(demo, AskAdminFilter()),
            throwsA(_denied(AskAdminReason.demo)),
          );
        });

        test(
          'lists everyone\'s conversations (hidden, demo) with messages, read only',
          () async {
            final u2 = await member();
            final a = await newSession(user, 'by user one');
            final b = await newSession(u2, 'by user two');
            await endpoints.askHistory.hide(user, a);
            final demoId = await DemoUser.ensure(
              sb.build(),
              SamplePacks.demoKo,
            );
            final c = (await ask(
              as(demoId),
              '데모 질문',
              key: 'D' * 22,
              locale: 'ko',
            ).toList()).first.sessionId!;

            final page = await endpoints.askAdmin.listSessions(
              admin,
              AskAdminFilter(),
            );
            expect(page.items.map((i) => i.id), [c, b, a]);
            final byId = {for (final i in page.items) i.id: i};
            expect(byId[a]!.hidden, isTrue);
            expect(byId[a]!.messages.single.question, 'by user one');
            expect(byId[a]!.messages.single.answer, 'Answer 1 [1]');
            expect(byId[c]!.isDemo, isTrue);
            expect(byId[c]!.ownerLabel, 'demo-ko');
            expect(byId[c]!.locale, 'ko');
            expect(byId[b]!.ownerLabel, byId[b]!.ownerId);
            expect(page.nextBeforeActiveAt, isNull);
          },
        );

        test(
          'filters by user and period; pages by keyset without overlap',
          () async {
            final uid = const Uuid().v4obj();
            final u = as(uid);
            final ids = <int>[];
            for (var i = 0; i < 5; i++) {
              ids.add(await newSession(u, 'q$i'));
              await setActive(ids.last, ago: Duration(hours: 10 - i));
            }
            final other = await newSession(user, 'other user');

            final mine = await endpoints.askAdmin.listSessions(
              admin,
              AskAdminFilter(userId: uid.toString().toUpperCase()),
            );
            expect(mine.items.map((i) => i.id), ids.reversed.toList());
            expect(mine.items.map((i) => i.id), isNot(contains(other)));

            final seen = <int>[];
            var filter = AskAdminFilter(userId: uid.toString(), pageSize: 2);
            for (var i = 0; i < 5; i++) {
              final p = await endpoints.askAdmin.listSessions(admin, filter);
              seen.addAll(p.items.map((x) => x.id));
              if (p.nextBeforeActiveAt == null) break;
              filter = AskAdminFilter(
                userId: uid.toString(),
                pageSize: 2,
                beforeActiveAt: p.nextBeforeActiveAt,
                beforeId: p.nextBeforeId,
              );
            }
            expect(seen, ids.reversed.toList());

            final now = DateTime.now().toUtc();
            final ranged = await endpoints.askAdmin.listSessions(
              admin,
              AskAdminFilter(
                userId: uid.toString(),
                from: now.subtract(const Duration(hours: 8, minutes: 30)),
                to: now.subtract(const Duration(hours: 6, minutes: 30)),
              ),
            );
            expect(ranged.items.map((i) => i.id), [ids[3], ids[2]]);

            final bad = await endpoints.askAdmin.listSessions(
              admin,
              AskAdminFilter(userId: 'not a uuid'),
            );
            expect(bad.items, isEmpty);
          },
        );

        test('summarises answers and fallbacks per model', () async {
          llm.script = (_, call) => Stream.fromIterable([
            LlmModelUsed(call.isEven ? 'a/one' : 'b/two'),
            LlmText('x'),
            LlmDone('stop'),
          ]);
          await ask(user, 'q1', model: 'a/one').toList(); // a/one: asked, got
          await ask(user, 'q2', model: 'a/one').toList(); // b/two: fell back
          await ask(user, 'q3', model: 'a/one').toList(); // a/one
          final page = await endpoints.askAdmin.listSessions(
            admin,
            AskAdminFilter(),
          );
          final stats = {
            for (final m in page.models) m.modelId: (m.answers, m.fallbacks),
          };
          expect(stats, {'a/one': (2, 0), 'b/two': (1, 1)});
          final none = await endpoints.askAdmin.listSessions(
            admin,
            AskAdminFilter(userId: const Uuid().v4()),
          );
          expect(none.models, isEmpty);
        });

        test('console lines: list and denied, ids and counts only', () async {
          final lines = <String>[];
          AskAdminEndpoint.out = lines.add;
          addTearDown(() => AskAdminEndpoint.out = stdout.writeln);
          final u = await member();
          await newSession(u, 'QUESTION-TEXT-ZEBRA');
          await endpoints.askAdmin.listSessions(
            admin,
            AskAdminFilter(userId: ownerId.toString(), pageSize: 7),
          );
          await expectLater(
            endpoints.askAdmin.listSessions(user, AskAdminFilter()),
            throwsA(_denied(AskAdminReason.notAdmin)),
          );
          expect(lines, [
            'ask-admin: list by=$adminId user=yes from=no to=no page=7 '
                'returned=0',
            'ask-admin: denied by=$ownerId',
          ]);
          expect(lines.join(), isNot(contains('ZEBRA')));
          expect(lines.join(), isNot(contains('Answer')));
        });

        test(
          'the access line names who and what scope, never content',
          () async {
            final line = AskAdminEndpoint.adminAccessLine(
              adminId,
              AskAdminFilter(userId: ownerId.toString(), pageSize: 5),
              3,
            );
            expect(
              line,
              startsWith('ask-admin: list by=$adminId user=$ownerId'),
            );
            expect(line, endsWith('returned=3'));
          },
        );
      });

      group('the query log', () {
        Future<List<String>> loggedQueries() async {
          // sessions flush their log when they close
          await Future<void>.delayed(const Duration(milliseconds: 500));
          return [
            for (final q in await internal.QueryLogEntry.db.find(sb.build()))
              q.query,
          ];
        }

        test(
          'never holds a question or an answer, though every query is logged',
          () async {
            final pod = sb.build().serverpod;
            await pod.updateRuntimeSettings(
              internal.RuntimeSettings(
                logSettings: internal.LogSettings(
                  logLevel: internal.LogLevel.debug,
                  logAllSessions: true,
                  logAllQueries: true,
                  logSlowSessions: true,
                  logStreamingSessionsContinuously: true,
                  logSlowQueries: true,
                  logFailedSessions: true,
                  logFailedQueries: true,
                  slowSessionDuration: 1,
                  slowQueryDuration: 0.0001,
                ),
                logSettingsOverrides: [],
                logServiceCalls: false,
                logMalformedCalls: false,
              ),
            );
            addTearDown(
              () => pod.updateRuntimeSettings(
                internal.RuntimeSettings(
                  logSettings: internal.LogSettings(
                    logLevel: internal.LogLevel.info,
                    logAllSessions: false,
                    logAllQueries: false,
                    logSlowSessions: true,
                    logStreamingSessionsContinuously: true,
                    logSlowQueries: true,
                    logFailedSessions: true,
                    logFailedQueries: true,
                    slowSessionDuration: 1,
                    slowQueryDuration: 1,
                  ),
                  logSettingsOverrides: [],
                  logServiceCalls: false,
                  logMalformedCalls: false,
                ),
              ),
            );
            final logged = sb.copyWith(enableLogging: true);

            // proof the setup logs SQL text: a write on a logged session shows
            final canary = AskSession(
              ownerId: ownerId,
              title: 'CANARY-in-a-logged-session',
              questionCount: 0,
              createdAt: DateTime.now().toUtc(),
              lastActiveAt: DateTime.now().toUtc(),
            );
            final s = logged.build();
            await AskSession.db.insertRow(s, canary);
            await s.close();

            llm.script = (_, _) => Stream.fromIterable([
              LlmModelUsed('fake/model'),
              LlmText('ANSWER-TEXT-ZEBRA'),
              LlmDone('stop'),
            ]);
            final who = as(ownerId).copyWith(enableLogging: true);
            final id = (await ask(
              who,
              'QUESTION-TEXT-ZEBRA',
            ).toList()).first.sessionId!;
            await ask(who, 'SECOND-ZEBRA', sessionId: id).toList();
            await endpoints.askHistory.restore(who);

            final queries = await loggedQueries();
            expect(
              queries.any((q) => q.contains('CANARY-in-a-logged-session')),
              isTrue,
              reason: 'the check can see SQL values at all',
            );
            expect(queries.where((q) => q.contains('ZEBRA')), isEmpty);
            // the history really was written
            expect((await messagesOf(id)).map((m) => m.question), [
              'QUESTION-TEXT-ZEBRA',
              'SECOND-ZEBRA',
            ]);
          },
        );
      });
    },
  );
}

/// Polls [test] until true (or fails after [timeout]).
Future<void> _until(
  bool Function() test, {
  Duration timeout = const Duration(seconds: 10),
}) async {
  final end = DateTime.now().add(timeout);
  while (!test()) {
    if (DateTime.now().isAfter(end)) fail('condition not reached in time');
    await Future<void>.delayed(const Duration(milliseconds: 20));
  }
}

extension on Stream<LlmEvent> {
  Stream<LlmEvent> concatWith(Stream<LlmEvent> next) async* {
    yield* this;
    yield* next;
  }
}
