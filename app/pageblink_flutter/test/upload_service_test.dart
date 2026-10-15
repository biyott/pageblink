import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:pageblink_client/pageblink_client.dart';
import 'package:pageblink_flutter/app/l10n.dart';
import 'package:pageblink_flutter/features/documents/upload_service.dart';

Uint8List _pdf([String body = 'x']) =>
    Uint8List.fromList(utf8.encode('%PDF-1.7\n$body'));

Document _doc(int id, {String status = 'ready', String? lastError}) => Document(
  id: id,
  ownerId: UuidValue.fromString('00000000-0000-4000-8000-000000000001'),
  title: 't',
  contentHash: 'h$id',
  version: 1,
  pageCount: 1,
  status: status,
  lastError: lastError,
  embeddingModel: 'm',
  createdAt: DateTime.utc(2026),
  updatedAt: DateTime.utc(2026),
);

class _Fake {
  final uploaded = <String>[];
  final originals = <int>[];
  int _next = 1;
  List<PageText> Function(String name) pages = (_) => [
    PageText(page: 1, text: 'hello'),
  ];
  Future<Document> Function(String title, int id)? onUpload;

  UploadApi get api => UploadApi(
    extractPages: (bytes, name) async => pages(name),
    upload: (title, pages, hash, projectId) async {
      uploaded.add(title);
      final id = _next++;
      return onUpload != null ? onUpload!(title, id) : _doc(id);
    },
    storeOriginal: (id, bytes) async {
      originals.add(id);
      return true;
    },
  );
}

PickedPdf _file(String name, [Uint8List? bytes]) =>
    PickedPdf.bytes(name, bytes ?? _pdf(name));

void main() {
  group('validatePdf', () {
    test('extension is case-insensitive and the %PDF- header is required', () {
      expect(validatePdf(_pdf(), 'a.PDF'), isNull);
      expect(validatePdf(_pdf(), 'a.txt'), UploadKind.notPdf);
      expect(
        validatePdf(Uint8List.fromList(utf8.encode('hello')), 'a.pdf'),
        UploadKind.notPdf,
      );
      expect(validatePdf(Uint8List(0), 'a.pdf'), UploadKind.notPdf);
    });

    test('over 50 MB is rejected', () {
      final big = Uint8List(UploadLimits.maxFileBytes + 1)
        ..setAll(0, utf8.encode('%PDF-'));
      expect(validatePdf(big, 'a.pdf'), UploadKind.tooBig);
    });
  });

  group('uploadPdfs', () {
    test('processes at most 10 files, in order, and says so', () async {
      final fake = _Fake();
      final report = await uploadPdfs([
        for (var i = 0; i < 12; i++) _file('f$i.pdf'),
      ], api: fake.api);
      expect(fake.uploaded, [for (var i = 0; i < 10; i++) 'f$i']);
      expect(report.added, 10);
      expect(report.skippedOverLimit, 2);
      expect(
        uploadSummary(L.ko, report),
        '10개 추가\n한 번에 10개까지만 올릴 수 있어요. 2개는 건너뛰었어요.',
      );
    });

    test('summary lists failures by file with a fixed reason', () async {
      final fake = _Fake();
      final report = await uploadPdfs([
        _file('a.pdf'),
        _file('b.pdf'),
        _file('c.txt'),
        _file('d.pdf', Uint8List.fromList(utf8.encode('nope'))),
      ], api: fake.api);
      expect(report.added, 2);
      expect(report.failed, 2);
      expect(
        uploadSummary(L.ko, report),
        '2개 추가, 2개 실패: c.txt — PDF 파일이 아니에요; '
        'd.pdf — PDF 파일이 아니에요',
      );
      expect(
        uploadSummary(L.en, report),
        '2 added, 2 failed: c.txt — Not a PDF file; '
        'd.pdf — Not a PDF file',
      );
    });

    test('too much text is refused before any server call', () async {
      final fake = _Fake()
        ..pages = (_) => [
          for (var p = 1; p <= 4; p++)
            PageText(page: p, text: 'a' * (200 * 1024)),
        ];
      final report = await uploadPdfs([_file('big.pdf')], api: fake.api);
      expect(fake.uploaded, isEmpty);
      final o = report.outcomes.single;
      expect(o.kind, UploadKind.tooMuchText);
      expect(o.pagesFit, 2);
      expect(
        uploadSummary(L.ko, report),
        '1개 실패: big.pdf — 텍스트가 너무 많아요(약 2쪽 초과) — 나눠서 올려 주세요',
      );
    });

    test('Korean text is budgeted by UTF-8 bytes, not characters', () {
      // 3 bytes per Hangul syllable: 170k chars ~ 510 KB > 480 KiB.
      final b = textBudget([PageText(page: 1, text: '가' * 170000)]);
      expect(b.bytes, greaterThan(UploadLimits.maxTextBytes));
      expect(b.fittingPages, 0);
    });

    test('pages without any text never reach the server', () async {
      final fake = _Fake()
        ..pages = (_) => [
          PageText(page: 1, text: ' \n'),
          PageText(page: 2, text: ''),
        ];
      final report = await uploadPdfs([_file('scan.pdf')], api: fake.api);
      expect(fake.uploaded, isEmpty);
      expect(report.outcomes.single.kind, UploadKind.noText);
      expect(
        uploadSummary(L.en, report),
        '1 failed: scan.pdf — No readable text in this PDF (it may be a scan)',
      );
    });

    test('a server-side no_text failure is reported as noText', () async {
      final fake = _Fake()
        ..onUpload = (t, id) async =>
            _doc(id, status: 'failed', lastError: 'no_text');
      final report = await uploadPdfs([_file('a.pdf')], api: fake.api);
      expect(report.outcomes.single.kind, UploadKind.noText);
      expect(fake.originals, [1]);
    });

    test('other index failures keep the server code as the reason', () async {
      final fake = _Fake()
        ..onUpload = (t, id) async =>
            _doc(id, status: 'failed', lastError: 'quota');
      final report = await uploadPdfs([_file('a.pdf')], api: fake.api);
      expect(report.outcomes.single.kind, UploadKind.indexFailed);
      expect(uploadSummary(L.en, report), contains('usage quota'));
    });

    test('a ready document already on the board is a duplicate', () async {
      final fake = _Fake()..onUpload = (t, id) async => _doc(7);
      final report = await uploadPdfs(
        [_file('a.pdf')],
        api: fake.api,
        existing: [_doc(7)],
      );
      expect(report.outcomes.single.kind, UploadKind.duplicate);
      expect(fake.originals, isEmpty, reason: 'no second original upload');
      expect(uploadSummary(L.ko, report), '1개는 이미 추가된 문서예요');
    });

    test(
      'a failed document on the board is retried, not a duplicate',
      () async {
        final fake = _Fake()..onUpload = (t, id) async => _doc(7);
        final report = await uploadPdfs(
          [_file('a.pdf')],
          api: fake.api,
          existing: [_doc(7, status: 'failed')],
        );
        expect(report.outcomes.single.kind, UploadKind.added);
      },
    );

    test('the same file twice in one batch: second is a duplicate', () async {
      final fake = _Fake()..onUpload = (t, id) async => _doc(3);
      final report = await uploadPdfs([
        _file('a.pdf'),
        _file('a.pdf'),
      ], api: fake.api);
      expect(
        [for (final o in report.outcomes) o.kind],
        [
          UploadKind.added,
          UploadKind.duplicate,
        ],
      );
    });

    test('files go one at a time and cancel stops the queue', () async {
      final fake = _Fake();
      final gate = Completer<void>();
      final cancel = UploadCancel();
      var running = 0;
      var maxRunning = 0;
      fake.onUpload = (t, id) async {
        maxRunning = ++running > maxRunning ? running : maxRunning;
        await gate.future;
        running--;
        return _doc(id);
      };
      final progress = <String>[];
      final future = uploadPdfs(
        [_file('a.pdf'), _file('b.pdf'), _file('c.pdf')],
        api: fake.api,
        cancel: cancel,
        onProgress: (p) => progress.add('${p.index}/${p.total} ${p.name}'),
      );
      await Future<void>.delayed(Duration.zero);
      cancel.cancel();
      gate.complete();
      final report = await future;
      expect(maxRunning, 1);
      expect(fake.uploaded, ['a']);
      expect(
        [for (final o in report.outcomes) o.kind],
        [
          UploadKind.added,
          UploadKind.cancelled,
          UploadKind.cancelled,
        ],
      );
      expect(progress.first, '1/3 a.pdf');
      expect(uploadSummary(L.ko, report), '1개 추가, 2개 취소');
    });

    test(
      'a thrown error never leaks its text and the queue continues',
      () async {
        final fake = _Fake()
          ..onUpload = (t, id) async =>
              id == 1 ? throw ServerpodClientInternalServerError() : _doc(id);
        final report = await uploadPdfs(
          [_file('a.pdf'), _file('b.pdf')],
          api: fake.api,
          projectId: 4,
        );
        expect(report.outcomes.first.kind, UploadKind.serverOrPermission);
        expect(report.outcomes.last.kind, UploadKind.added);
        final text = uploadSummary(L.ko, report);
        expect(text, isNot(contains('Exception')));
        expect(text, contains('보기 전용 멤버'));
      },
    );
  });

  group('classifyUploadError', () {
    test('maps client exceptions to kinds', () {
      expect(
        classifyUploadError(TimeoutException('x')),
        UploadKind.timeout,
      );
      expect(
        classifyUploadError(
          const ServerpodClientNetworkException('Request timed out. (x)'),
        ),
        UploadKind.timeout,
      );
      expect(
        classifyUploadError(
          const ServerpodClientNetworkException('Connection refused'),
        ),
        UploadKind.network,
      );
      expect(
        classifyUploadError(ServerpodClientForbidden()),
        UploadKind.permission,
      );
      expect(
        classifyUploadError(ServerpodClientUnauthorized()),
        UploadKind.permission,
      );
      expect(
        classifyUploadError(ServerpodClientInternalServerError()),
        UploadKind.server,
      );
      expect(
        classifyUploadError(ServerpodClientInternalServerError(), projectId: 1),
        UploadKind.serverOrPermission,
      );
      expect(
        classifyUploadError(ServerpodClientUnknownHttpException('big', 413)),
        UploadKind.tooMuchText,
      );
      expect(
        classifyUploadError(ServerpodClientUnknownHttpException('', 504)),
        UploadKind.timeout,
      );
      expect(classifyUploadError(StateError('x')), UploadKind.unknown);
    });
  });
}
