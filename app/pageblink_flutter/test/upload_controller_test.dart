import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:pageblink_client/pageblink_client.dart';
import 'package:pageblink_flutter/app/open_item_controller.dart';
import 'package:pageblink_flutter/features/documents/upload_controller.dart';
import 'package:pageblink_flutter/features/documents/upload_service.dart';

Document _doc(int id, {String status = 'ready', String? lastError}) => Document(
  id: id,
  ownerId: UuidValue.fromString('00000000-0000-4000-8000-000000000001'),
  title: 't$id',
  contentHash: 'h$id',
  version: 1,
  pageCount: 4,
  status: status,
  lastError: lastError,
  embeddingModel: 'm',
  createdAt: DateTime.utc(2026),
  updatedAt: DateTime.utc(2026),
);

PickedPdf _pdf(String name) => PickedPdf.bytes(
  name,
  Uint8List.fromList(utf8.encode('%PDF-1.7 $name')),
);

/// `upload` waits on a per-title gate so tests see the in-between states.
class _Fake {
  final gates = <String, Completer<Document>>{};
  final uploaded = <String>[];
  final projects = <int?>[];
  int _id = 0;

  UploadApi get api => UploadApi(
    extractPages: (b, n) async => [PageText(page: 1, text: n)],
    upload: (title, pages, hash, projectId) {
      uploaded.add(title);
      projects.add(projectId);
      return (gates[title] ??= Completer<Document>()).future;
    },
    storeOriginal: (id, bytes) async => true,
  );

  void finish(String title, {String status = 'ready', String? error}) =>
      (gates[title] ??= Completer<Document>()).complete(
        _doc(++_id, status: status, lastError: error),
      );

  void fail(String title, Object e) =>
      (gates[title] ??= Completer<Document>()).completeError(e);
}

Future<void> _settle() => Future<void>.delayed(Duration.zero);

void main() {
  late _Fake fake;
  setUp(() {
    fake = _Fake();
    boardRefresh.value = 0;
  });

  UploadController make({
    Future<Document> Function(int)? reindex,
    Iterable<Document> Function()? existing,
  }) {
    final c = UploadController(
      api: fake.api,
      existing: existing,
      reindex: reindex,
      autoClearAfter: const Duration(milliseconds: 40),
      flashFor: const Duration(milliseconds: 40),
    );
    addTearDown(c.dispose);
    return c;
  }

  test(
    'files go one at a time, in order; progress is visible per stage',
    () async {
      final c = make();
      c.enqueue([_pdf('a.pdf'), _pdf('b.pdf')]);
      await _settle();
      expect(fake.uploaded, ['a']);
      expect(c.rows[0].state, RowState.indexing);
      expect(c.rows[0].pages, 1);
      expect(c.rows[1].state, RowState.waiting);
      expect(c.rows[1].canCancel, isTrue);

      fake.finish('a');
      await _settle();
      await _settle();
      expect(c.rows[0].state, RowState.done);
      expect(fake.uploaded, ['a', 'b']);
      fake.finish('b');
      await _settle();
      await _settle();
      expect(c.rows.map((r) => r.state), [RowState.done, RowState.done]);
      expect(boardRefresh.value, 2, reason: 'board refreshes per added card');
    },
  );

  test(
    'cancel removes a waiting file; the running one cannot be cancelled',
    () async {
      final c = make();
      final reports = <UploadReport>[];
      c.onBatchDone = reports.add;
      c.enqueue([_pdf('a.pdf'), _pdf('b.pdf')]);
      await _settle();
      expect(c.rows[0].canCancel, isFalse);
      c.cancel(c.rows[0]); // no-op
      expect(c.rows, hasLength(2));
      c.cancel(c.rows[1]);
      expect(c.rows, hasLength(1));
      fake.finish('a');
      await _settle();
      await _settle();
      expect(fake.uploaded, ['a'], reason: 'b never started');
      expect(reports, hasLength(1));
      expect(reports.single.added, 1);
      expect(reports.single.cancelled, 1);
    },
  );

  test('batch summary fires once, when the last file ends', () async {
    final c = make();
    final reports = <UploadReport>[];
    c.onBatchDone = reports.add;
    c.enqueue([_pdf('a.pdf'), _pdf('b.pdf')]);
    await _settle();
    fake.finish('a');
    await _settle();
    await _settle();
    expect(reports, isEmpty);
    fake.fail('b', TimeoutException('x'));
    await _settle();
    await _settle();
    expect(reports, hasLength(1));
    expect(reports.single.added, 1);
    expect(reports.single.failed, 1);
    expect(c.rows[1].state, RowState.failed);
    expect(c.rows[1].canRetry, isTrue, reason: 'timeouts are worth a retry');
  });

  test('retry runs the same file again', () async {
    final c = make();
    c.enqueue([_pdf('a.pdf')]);
    await _settle();
    fake.fail('a', TimeoutException('x'));
    await _settle();
    await _settle();
    final row = c.rows.single;
    expect(row.state, RowState.failed);
    fake.gates.remove('a');
    c.retry(row);
    await _settle();
    expect(row.state, RowState.indexing);
    fake.finish('a');
    await _settle();
    await _settle();
    expect(row.state, RowState.done);
    expect(fake.uploaded, ['a', 'a']);
  });

  test('a created-but-unindexed card retries by re-indexing it', () async {
    final reindexed = <int>[];
    final c = make(
      reindex: (id) async {
        reindexed.add(id);
        return _doc(id);
      },
    );
    c.enqueue([_pdf('a.pdf')]);
    await _settle();
    fake.finish('a', status: 'failed', error: 'quota');
    await _settle();
    await _settle();
    final row = c.rows.single;
    expect(row.state, RowState.failed);
    expect(row.outcome!.kind, UploadKind.indexFailed);
    expect(row.canRetry, isTrue);
    c.retry(row);
    await _settle();
    await _settle();
    expect(reindexed, [row.document!.id]);
    expect(fake.uploaded, ['a'], reason: 'no second upload');
    expect(row.state, RowState.done);
  });

  test('non-PDF rows need no work and are never read', () async {
    final c = make();
    final reports = <UploadReport>[];
    c.onBatchDone = reports.add;
    c.enqueue(
      const [],
      rejected: const [
        RejectedFile('notes.docx'),
        RejectedFile('photos', isFolder: true),
      ],
    );
    expect(c.rows.map((r) => r.state), [RowState.failed, RowState.failed]);
    expect(c.rows[0].rejected!.ext, '.docx');
    expect(c.rows[1].rejected!.ext, '');
    expect(c.rows[0].canRetry, isFalse);
    expect(fake.uploaded, isEmpty);
    expect(reports.single.failed, 2);
  });

  test('at most 10 files per drop; the rest is reported as skipped', () async {
    final c = make();
    final reports = <UploadReport>[];
    c.onBatchDone = reports.add;
    c.enqueue([for (var i = 0; i < 12; i++) _pdf('f$i.pdf')]);
    expect(c.rows, hasLength(10));
    for (var i = 0; i < 10; i++) {
      await _settle();
      fake.finish('f$i');
      await _settle();
    }
    await _settle();
    expect(reports.single.skippedOverLimit, 2);
    expect(fake.uploaded, hasLength(10));
  });

  test(
    'project id is passed through; a repeat of the same card is a duplicate',
    () async {
      final c = make();
      c.enqueue([_pdf('a.pdf')], projectId: 7);
      await _settle();
      expect(fake.projects, [7]);
      fake.finish('a'); // id 1
      await _settle();
      await _settle();
      // Same document again: the server hands back id 1 -> duplicate.
      fake.gates['a'] = Completer<Document>()..complete(_doc(1));
      c.enqueue([_pdf('a.pdf')], projectId: 7);
      await _settle();
      await _settle();
      expect(c.rows.last.outcome!.kind, UploadKind.duplicate);
    },
  );

  test(
    'done rows leave after the delay, failed rows stay; new cards flash',
    () async {
      final c = make();
      c.enqueue([_pdf('a.pdf'), _pdf('b.pdf')]);
      await _settle();
      fake.finish('a');
      await _settle();
      await _settle();
      fake.fail('b', ArgumentError('boom'));
      await _settle();
      await _settle();
      expect(c.flash.value, isNotEmpty);
      await Future<void>.delayed(const Duration(milliseconds: 120));
      expect(c.rows.map((r) => r.state), [RowState.failed]);
      expect(c.flash.value, isEmpty);
    },
  );

  test('close hides a running tray, new work shows it again', () async {
    final c = make();
    c.enqueue([_pdf('a.pdf')]);
    await _settle();
    c.close();
    expect(c.hidden, isTrue);
    expect(c.rows, hasLength(1), reason: 'work continues');
    c.enqueue([_pdf('b.pdf')]);
    expect(c.hidden, isFalse);
  });

  group('DropMachine', () {
    test('entered -> armed; over the pane -> over', () {
      final m = DropMachine();
      addTearDown(m.dispose);
      m.hover(inZone: false);
      expect(m.phase.value, DropPhase.armed);
      m.hover(inZone: true);
      expect(m.phase.value, DropPhase.over);
    });

    testWidgets('leave ends after 150 ms, a move in between cancels it', (
      t,
    ) async {
      final m = DropMachine();
      addTearDown(m.dispose);
      m.hover(inZone: true);
      m.leave();
      await t.pump(const Duration(milliseconds: 149));
      expect(m.phase.value, DropPhase.over);
      await t.pump(const Duration(milliseconds: 2));
      expect(m.phase.value, DropPhase.idle);

      m.hover(inZone: true);
      m.leave();
      await t.pump(const Duration(milliseconds: 100));
      m.hover(inZone: true); // Chrome's fake exit over a TextField
      await t.pump(const Duration(milliseconds: 100));
      expect(m.phase.value, DropPhase.over);
      m.reset();
    });

    testWidgets('no signal for 400 ms ends it (Esc / left the window)', (
      t,
    ) async {
      final m = DropMachine();
      addTearDown(m.dispose);
      m.hover(inZone: false);
      await t.pump(const Duration(milliseconds: 399));
      expect(m.phase.value, DropPhase.armed);
      await t.pump(const Duration(milliseconds: 2));
      expect(m.phase.value, DropPhase.idle);
      // A steady dragover (every 50 ms) keeps it up.
      m.hover(inZone: true);
      for (var i = 0; i < 20; i++) {
        await t.pump(const Duration(milliseconds: 50));
        m.hover(inZone: true);
      }
      expect(m.phase.value, DropPhase.over);
      m.reset();
    });
  });

  test('engine down: queued files fail together, prepare runs once', () async {
    var prepared = 0;
    var extracted = 0;
    final c = UploadController(
      api: UploadApi(
        extractPages: (b, n) async {
          extracted++;
          return [PageText(page: 1, text: n)];
        },
        upload: fake.api.upload,
        storeOriginal: (id, bytes) async => true,
        prepare: () async {
          prepared++;
          throw UnimplementedError(
            'PdfrxEntryFunctions.instance is not initialized',
          );
        },
      ),
      autoClearAfter: const Duration(milliseconds: 40),
    );
    addTearDown(c.dispose);
    UploadReport? report;
    c.onBatchDone = (r) => report = r;
    c.enqueue([_pdf('a.pdf'), _pdf('b.pdf'), _pdf('c.pdf')]);
    await _settle();
    await _settle();
    expect(prepared, 1);
    expect(extracted, 0);
    expect(
      c.rows.map((r) => r.outcome?.kind),
      everyElement(UploadKind.engineUnavailable),
    );
    expect(c.rows.every((r) => r.state == RowState.failed), isTrue);
    expect(c.rows.every((r) => r.canRetry), isTrue);
    expect(report?.failed, 3);
  });
}
