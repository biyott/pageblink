import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pageblink_client/pageblink_client.dart';
import 'package:pageblink_flutter/app/l10n.dart';
import 'package:pageblink_flutter/app/theme.dart';
import 'package:pageblink_flutter/features/documents/documents_screen.dart';
import 'package:pageblink_flutter/features/documents/index_status.dart';

final _t0 = DateTime.utc(2026, 10, 15, 12);

Document _doc(
  String status, {
  String? lastError,
  String kind = 'pdf',
  int id = 1,
  DateTime? updatedAt,
  String title = 'Report',
}) => Document(
  id: id,
  ownerId: UuidValue.fromString('00000000-0000-4000-8000-000000000001'),
  kind: kind,
  title: title,
  body: kind == 'note' ? 'milk and eggs' : null,
  contentHash: 'h$id',
  version: 1,
  pageCount: 3,
  status: status,
  lastError: lastError,
  embeddingModel: 'm',
  createdAt: _t0,
  updatedAt: updatedAt ?? _t0,
);

Widget _app(Widget child, {double w = 280, double h = 250}) => MaterialApp(
  theme: buildPbTheme(Brightness.light),
  home: Scaffold(
    body: Center(
      child: SizedBox(width: w, height: h, child: child),
    ),
  ),
);

void main() {
  final l = L.en;

  group('indexLine: (status, lastError) -> label, link', () {
    // code, label, link shown, tone
    const failedRows = <(String?, String, bool, IndexTone)>[
      ('quota', 'Indexing failed', true, IndexTone.warn),
      ('rate', 'Indexing failed', true, IndexTone.warn),
      ('outage', 'Indexing failed', true, IndexTone.warn),
      ('timeout', 'Indexing failed', true, IndexTone.warn),
      ('unknown', 'Indexing failed', true, IndexTone.warn),
      // Unmapped / missing codes behave like `unknown`.
      ('embedding timeout', 'Indexing failed', true, IndexTone.warn),
      (null, 'Indexing failed', true, IndexTone.warn),
      ('interrupted', 'Indexing interrupted', true, IndexTone.neutral),
      ('no_source', "Couldn't read any text", false, IndexTone.neutral),
      ('no_text', "Couldn't read any text", false, IndexTone.neutral),
      ('auth', 'Indexing failed · Check server setup', false, IndexTone.warn),
    ];
    for (final (code, label, link, tone) in failedRows) {
      test('failed / $code', () {
        final line = indexLine(l, _doc('failed', lastError: code))!;
        expect(line.label, label);
        expect(line.canRetry, link);
        expect(line.tone, tone);
        expect(line.pulse, isFalse);
        // Never the raw server string.
        expect(line.reason, isNot(contains('embedding')));
        expect(line.reason, isNotEmpty);
      });
    }

    test(
      'ready has no line',
      () => expect(indexLine(l, _doc('ready')), isNull),
    );

    test('re-indexing this card wins over any status', () {
      final line = indexLine(
        l,
        _doc('failed', lastError: 'quota'),
        reindexing: true,
      )!;
      expect(line.label, 'Re-indexing');
      expect(line.pulse, isTrue);
      expect(line.canRetry, isFalse);
    });

    test('isRetryableFailure skips reasons a retry cannot fix', () {
      bool r(String? c) => isRetryableFailure(_doc('failed', lastError: c));
      expect(r('quota'), isTrue);
      expect(r('interrupted'), isTrue);
      expect(r('no_source'), isFalse);
      expect(r('no_text'), isFalse);
      expect(r('auth'), isFalse);
      expect(isRetryableFailure(_doc('ready')), isFalse);
      expect(isRetryableFailure(_doc('indexing')), isFalse);
    });
  });

  group('indexing wording phases', () {
    String at(Duration e) => indexLine(l, _doc('indexing'), elapsed: e)!.label;

    test('0-20 s plain, 20 s-3 min long, 3 min+ very long', () {
      expect(at(Duration.zero), 'Indexing');
      expect(at(const Duration(seconds: 19)), 'Indexing');
      expect(
        at(const Duration(seconds: 20)),
        'Indexing · large files take a while',
      );
      expect(
        at(const Duration(minutes: 2, seconds: 59)),
        'Indexing · large files take a while',
      );
      expect(
        at(const Duration(minutes: 3)),
        'Taking longer than usual · re-index from ⋯',
      );
    });

    test('indexing is calm: never a warn tone, never an icon', () {
      final line = indexLine(l, _doc('indexing'))!;
      expect(line.tone, IndexTone.calm);
      expect(line.icon, isNull);
      expect(line.pulse, isTrue);
      expect(line.canRetry, isFalse);
    });
  });

  group('DocumentCard status line', () {
    testWidgets('wording changes at 20 s and 3 min without polling', (t) async {
      var now = _t0.add(const Duration(seconds: 1));
      await t.pumpWidget(
        _app(
          DocumentCard(
            _doc('indexing'),
            const [],
            now: () => now,
          ),
        ),
      );
      expect(find.text('Indexing'), findsOneWidget);

      now = _t0.add(const Duration(seconds: 21));
      await t.pump(const Duration(seconds: 20));
      expect(find.text('Indexing · large files take a while'), findsOneWidget);

      now = _t0.add(const Duration(minutes: 3, seconds: 1));
      await t.pump(const Duration(minutes: 2, seconds: 40));
      expect(
        find.text('Taking longer than usual · re-index from ⋯'),
        findsOneWidget,
      );
    });

    testWidgets('failed PDF: reason in the body, link under it', (t) async {
      var retried = 0;
      await t.pumpWidget(
        _app(
          DocumentCard(
            _doc('failed', lastError: 'quota'),
            const [],
            onRetry: () => retried++,
          ),
        ),
      );
      expect(find.text(l.indexingError('quota')), findsOneWidget);
      expect(find.text('Indexing failed'), findsOneWidget);
      await t.tap(find.widgetWithText(TextButton, 'Retry'));
      expect(retried, 1);
      expect(t.takeException(), isNull);
    });

    testWidgets('no_source hides the link (reason only)', (t) async {
      await t.pumpWidget(
        _app(
          DocumentCard(
            _doc('failed', lastError: 'no_source'),
            const [],
            onRetry: () {},
          ),
        ),
      );
      expect(find.text("Couldn't read any text"), findsOneWidget);
      expect(find.widgetWithText(TextButton, 'Retry'), findsNothing);
    });

    testWidgets('failed note keeps its preview; reason is a tooltip', (
      t,
    ) async {
      await t.pumpWidget(
        _app(
          DocumentCard(
            _doc(
              'failed',
              lastError: 'timeout',
              kind: 'note',
              title: 'Groceries',
            ),
            const [],
            onRetry: () {},
          ),
        ),
      );
      expect(find.text('milk and eggs'), findsOneWidget);
      expect(find.text(l.indexingError('timeout')), findsNothing);
      expect(
        find.byWidgetPredicate(
          (w) => w is Tooltip && w.message == l.indexingError('timeout'),
        ),
        findsOneWidget,
      );
    });

    testWidgets('failed card does not change colour or border', (t) async {
      await t.pumpWidget(
        _app(
          DocumentCard(_doc('failed', lastError: 'quota'), const []),
        ),
      );
      final card = t.widget<Card>(find.byType(Card));
      final pb = Pb.light;
      expect(card.color, pb.pdfPaper);
      expect(card.color, isNot(pb.warnTint));
      expect(
        ((card.shape! as RoundedRectangleBorder).side.width),
        1,
      );
      // No big warn container inside the card any more.
      expect(find.byType(OutlinedButton), findsNothing);
    });

    for (final (w, name) in [
      (274.0, '2-col desktop'),
      (175.0, 'phone 2-col'),
      (230.0, '3-col'),
    ]) {
      for (final (code, kind) in [
        ('quota', 'pdf'),
        ('interrupted', 'note'),
        ('auth', 'pdf'),
      ]) {
        testWidgets('fits 250 px, no overflow: $code $kind $name', (t) async {
          await t.pumpWidget(
            _app(
              DocumentCard(
                _doc(
                  'failed',
                  lastError: code,
                  kind: kind,
                  title: 'A fairly long document title that wraps to two lines',
                ),
                const [],
                onRetry: () {},
              ),
              w: w,
            ),
          );
          expect(t.takeException(), isNull);
        });
      }
    }

    testWidgets('indexing PDF fits too (skeleton + long wording)', (t) async {
      await t.pumpWidget(
        _app(
          DocumentCard(
            _doc('indexing', title: 'A fairly long document title that wraps'),
            const [],
            now: () => _t0.add(const Duration(minutes: 5)),
          ),
          w: 175,
        ),
      );
      expect(t.takeException(), isNull);
    });
  });

  group('new card flash', () {
    double ringAlpha(WidgetTester t) {
      final box = t.widget<DecoratedBox>(
        find.descendant(
          of: find.byType(Stack),
          matching: find.byWidgetPredicate(
            (w) =>
                w is DecoratedBox &&
                w.decoration is BoxDecoration &&
                (w.decoration as BoxDecoration).border != null &&
                (w.decoration as BoxDecoration).boxShadow != null,
          ),
        ),
      );
      return ((box.decoration as BoxDecoration).border! as Border).top.color.a;
    }

    Widget card(bool reduce) => MediaQuery(
      data: MediaQueryData(disableAnimations: reduce),
      child: _app(
        DocumentCard(_doc('ready'), const [], highlight: true),
      ),
    );

    testWidgets('ring pulses twice over 1540 ms and ends clear', (t) async {
      await t.pumpWidget(card(false));
      expect(ringAlpha(t), lessThan(0.05));
      var peaks = 0;
      var prev = 0.0;
      var rising = true;
      for (var ms = 0; ms < 1540; ms += 20) {
        await t.pump(const Duration(milliseconds: 20));
        final a = ringAlpha(t);
        if (rising && a < prev - 0.001) {
          peaks++;
          rising = false;
        } else if (!rising && a > prev + 0.001) {
          rising = true;
        }
        prev = a;
      }
      expect(peaks, 2);
      await t.pump(const Duration(milliseconds: 100));
      expect(ringAlpha(t), lessThan(0.05));
    });

    testWidgets('reduced motion: steady ring, then fades', (t) async {
      await t.pumpWidget(card(true));
      await t.pump(const Duration(milliseconds: 700));
      expect(ringAlpha(t), closeTo(0.9, 0.01));
      await t.pump(const Duration(milliseconds: 900));
      expect(ringAlpha(t), lessThan(0.05));
    });
  });

  test('tokens carry the spec values (light / dark)', () {
    expect(Pb.light.warnText, const Color(0xFF92400E));
    expect(Pb.dark.warnText, Pb.dark.warn);
    expect(Pb.light.linkInk, Pb.light.onAccentContainer);
    expect(Pb.dark.linkInk, Pb.dark.accent);
    expect(Pb.light.dropFill, const Color(0x146C4CF5));
    expect(Pb.dark.dropFillOver, const Color(0x38B7A6FF));
    expect(Pb.light.dropScrim, const Color(0x291E160C));
    expect(Pb.dark.paneVeil, const Color(0xED251C27));
    expect(Pb.light.dropSub, const Color(0xCC1F1B16));
  });
}
