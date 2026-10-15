import 'dart:async';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:pageblink_server/src/generated/protocol.dart';
import 'package:pageblink_server/src/providers/embedding_provider.dart';
import 'package:pageblink_server/src/rag_endpoints/document_endpoint.dart';
import 'package:serverpod/serverpod.dart' show UuidValue;
import 'package:test/test.dart';

Document _note(String status, {String body = 'b', String title = 't'}) =>
    Document(
      ownerId: UuidValue.fromString('00000000-0000-0000-0000-000000000001'),
      kind: 'note',
      title: title,
      body: body,
      contentHash: 'h',
      version: 1,
      pageCount: 1,
      status: status,
      embeddingModel: 'm',
      createdAt: DateTime.utc(2026),
      updatedAt: DateTime.utc(2026),
    );

void main() {
  final now = DateTime.utc(2026, 10, 15, 12);

  test('only indexing documents older than 10 minutes are stale', () {
    final old = now.subtract(const Duration(minutes: 11));
    final fresh = now.subtract(const Duration(minutes: 9));
    expect(isStaleIndexing('indexing', old, now), isTrue);
    expect(isStaleIndexing('indexing', fresh, now), isFalse);
    expect(isStaleIndexing('ready', old, now), isFalse);
    expect(isStaleIndexing('failed', old, now), isFalse);
  });

  test('saveNote shortcut only for unchanged ready notes', () {
    expect(isUnchangedReadyNote(_note('ready'), 'b', 't'), isTrue);
    expect(isUnchangedReadyNote(_note('failed'), 'b', 't'), isFalse);
    expect(isUnchangedReadyNote(_note('indexing'), 'b', 't'), isFalse);
    expect(isUnchangedReadyNote(_note('ready'), 'b2', 't'), isFalse);
    expect(isUnchangedReadyNote(_note('ready'), 'b', 't2'), isFalse);
  });

  test('error codes map to the codes the app localizes', () {
    expect(
      friendlyIndexingError(EmbeddingException('DeepInfra 402: x')),
      'quota',
    );
    expect(friendlyIndexingError(EmbeddingException('Gemini 429: x')), 'rate');
    expect(
      friendlyIndexingError(EmbeddingException('Gemini 503: x')),
      'outage',
    );
    expect(
      friendlyIndexingError(
        EmbeddingException('timeout: no response within 60s'),
      ),
      'timeout',
    );
    expect(friendlyIndexingError(TimeoutException('x')), 'timeout');
    expect(friendlyIndexingError(StateError('boom')), 'unknown');
  });

  test('text-less PDFs fail with no_text, empty notes stay ready', () {
    expect(isNoTextFailure('pdf', 0), isTrue);
    expect(isNoTextFailure('pdf', 3), isFalse);
    expect(isNoTextFailure('note', 0), isFalse);
    expect(friendlyIndexingError(NoTextException()), 'no_text');
  });

  test('a stalled embedding request becomes a timeout EmbeddingException', () {
    final client = MockClient((_) => Completer<http.Response>().future);
    expect(
      postEmbeddingRequest(
        client,
        Uri.parse('https://example.test'),
        headers: const {},
        body: '{}',
        timeout: const Duration(milliseconds: 50),
      ),
      throwsA(
        isA<EmbeddingException>().having(
          (e) => friendlyIndexingError(e),
          'code',
          'timeout',
        ),
      ),
    );
  });
}
