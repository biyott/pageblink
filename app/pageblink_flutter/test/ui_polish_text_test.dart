import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:pageblink_flutter/app/l10n.dart';
import 'package:pageblink_flutter/app/text_wrap.dart';
import 'package:pageblink_flutter/app/theme.dart';

/// WCAG 2.x contrast ratio of two opaque colors.
double contrast(Color a, Color b) {
  final la = a.computeLuminance(), lb = b.computeLuminance();
  final hi = la > lb ? la : lb, lo = la > lb ? lb : la;
  return (hi + 0.05) / (lo + 0.05);
}

/// [top] (with its alpha) over opaque [bottom].
Color over(Color top, Color bottom) => Color.alphaBlend(top, bottom);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    GoogleFonts.config.allowRuntimeFetching = false;
    // The test engine only has Ahem; load the bundled faces so layout and the
    // U+2060 glyph behave like the app (family names as in pubspec.yaml).
    for (final (family, asset) in [
      (pbSansFamily, 'assets/fonts/Pretendard-400-subset.otf'),
      (pbHangulSerifFamily, 'assets/fonts/NotoSerifKR-600-subset.ttf'),
    ]) {
      final loader = FontLoader(family)..addFont(rootBundle.load(asset));
      await loader.load();
    }
  });

  group('contrast helper', () {
    test('black on white is 21:1, same color is 1:1', () {
      expect(contrast(Colors.black, Colors.white), closeTo(21, 0.01));
      expect(contrast(Colors.white, Colors.white), closeTo(1, 0.001));
    });
  });

  group(
    'inkMuted contrast (spec §3.1: backgrounds composed over the app bg)',
    () {
      // Light bg #F2E7F2 under glass 62%/74% white; dark bg #241C2A under 8%/14%.
      for (final (name, pb, bg) in [
        ('light', Pb.light, const Color(0xFFF2E7F2)),
        ('dark', Pb.dark, const Color(0xFF241C2A)),
      ]) {
        test('$name: secondary text >= 4.5:1 on glass, glassStrong, notes', () {
          final surfaces = {
            'glass': over(pb.glass, bg),
            'glassStrong': over(pb.glassStrong, bg),
            for (var i = 0; i < pb.notes.length; i++) 'note$i': pb.notes[i],
          };
          for (final e in surfaces.entries) {
            expect(
              contrast(pb.inkMuted, e.value),
              greaterThanOrEqualTo(4.5),
              reason: '$name inkMuted on ${e.key}',
            );
            expect(
              contrast(pb.ink, e.value),
              greaterThanOrEqualTo(7),
              reason: '$name ink on ${e.key}',
            );
          }
        });
      }

      test('spec values', () {
        expect(Pb.light.inkMuted, const Color(0xFF5C5348));
        expect(Pb.dark.inkMuted, const Color(0xFFB5AD9F));
        expect(Pb.dark.glassStrong, const Color(0x24FFFFFF)); // 14%
      });
    },
  );

  group('type scale (spec §3)', () {
    final t = buildPbTheme(Brightness.light).textTheme;
    void expectRole(TextStyle? s, double size, FontWeight w, double h) {
      expect(s!.fontSize, size);
      expect(s.fontWeight, w);
      expect(s.height, h);
    }

    test('sizes, weights, line heights', () {
      expectRole(t.headlineMedium, 32, FontWeight.w600, 1.25);
      expectRole(t.titleLarge, 20, FontWeight.w600, 1.3);
      expectRole(t.titleMedium, 18, FontWeight.w600, 1.3);
      expectRole(t.bodyLarge, 15, FontWeight.w400, 1.5);
      expectRole(t.bodyMedium, 15, FontWeight.w400, 1.6);
      expectRole(t.bodySmall, 12, FontWeight.w500, 1.35);
      expectRole(t.labelLarge, 14, FontWeight.w600, 1.2);
      expectRole(t.labelMedium, 13, FontWeight.w500, 1.2);
      expectRole(t.labelSmall, 12, FontWeight.w600, 1.3);
    });

    test('no positive tracking on sans roles; small sizes are w500+', () {
      for (final s in [
        t.bodyLarge,
        t.bodyMedium,
        t.bodySmall,
        t.labelLarge,
        t.labelMedium,
        t.labelSmall,
        t.titleSmall,
      ]) {
        expect(s!.letterSpacing, 0);
        if (s.fontSize! <= 13) {
          expect(s.fontWeight!.value, greaterThanOrEqualTo(500));
        }
      }
      expect(t.headlineMedium!.letterSpacing, -0.3);
    });
  });

  group('keepAllKorean', () {
    const wj = '⁠';

    test('joins Hangul neighbours only', () {
      expect(keepAllKorean('출처가'), '출$wj처$wj가');
      expect(keepAllKorean('모든 답변은'), '모$wj든 답$wj변$wj은');
    });

    test(
      'Hangul next to Latin/digits stays whole; pure Latin/digits do not',
      () {
        expect(keepAllKorean('PDF를'), 'PDF$wj를');
        expect(keepAllKorean('12쪽'), '12$wj쪽');
        expect(keepAllKorean('PDF 2 items'), 'PDF 2 items');
        expect(keepAllKorean('Shared Vision'), 'Shared Vision');
      },
    );

    test('spaces, punctuation, newline and emoji are untouched', () {
      expect(
        keepAllKorean('아니요, 좋아요.\n끝!'),
        '아$wj니$wj요, 좋$wj아$wj요.\n끝!',
      );
      expect(keepAllKorean('⚡ 출처'), '⚡ 출$wj처');
      expect(keepAllKorean('😀😀'), '😀😀');
      expect(keepAllKorean(''), '');
      expect(keepAllKorean(' '), ' ');
    });

    test('idempotent; length grows by the inserted joiners only', () {
      const s = '노트와 문서에 질문하세요 · PDF 12쪽';
      final once = keepAllKorean(s);
      expect(keepAllKorean(once), once);
      expect(once.replaceAll(wj, ''), s);
      expect(once.length - s.length, wj.allMatches(once).length);
    });

    test('L.ko long copy is keep-all, L.en is unchanged', () {
      expect(L.ko.aiDisclaimer, contains(wj));
      expect(
        L.ko.aiDisclaimer.replaceAll(wj, ''),
        'AI는 틀릴 수 있어요. ⚡ 출처를 확인하세요.',
      );
      expect(L.en.aiDisclaimer, isNot(contains(wj)));
      // Suggested questions are sent to the server as-is.
      for (final q in [...L.ko.askSuggestions, ...L.ko.sampleSuggestions]) {
        expect(q, isNot(contains(wj)));
      }
    });
  });

  group('rendering (bundled fonts)', () {
    const wj = '⁠';

    List<String> lines(String text, TextStyle style, double width) {
      final p = TextPainter(
        text: TextSpan(text: text, style: style),
        textDirection: TextDirection.ltr,
      )..layout(maxWidth: width);
      final out = <String>[];
      var start = 0;
      for (final m in p.computeLineMetrics()) {
        final end = p
            .getLineBoundary(TextPosition(offset: start))
            .end
            .clamp(0, text.length);
        out.add(text.substring(start, end));
        start = end;
        if (m.lineNumber >= p.computeLineMetrics().length - 1) break;
      }
      return out;
    }

    testWidgets('U+2060 is zero-width in sans and serif styles', (t) async {
      final theme = buildPbTheme(Brightness.light);
      await t.pumpWidget(MaterialApp(theme: theme, home: const SizedBox()));
      for (final style in [
        theme.textTheme.bodyMedium!,
        theme.textTheme.titleLarge!, // Fraunces -> Noto Serif KR -> Pretendard
      ]) {
        double w(String s) => (TextPainter(
          text: TextSpan(text: s, style: style),
          textDirection: TextDirection.ltr,
        )..layout()).width;
        expect(w('가$wj나'), closeTo(w('가나'), 0.01));
      }
    });

    testWidgets('keep-all stops mid-word breaks at a narrow width', (t) async {
      final theme = buildPbTheme(Brightness.light);
      await t.pumpWidget(MaterialApp(theme: theme, home: const SizedBox()));
      final style = theme.textTheme.bodyMedium!;
      const s = '모든 답변은 출처로 연결됩니다 질문하면 시작하기';
      // Wider than the longest word (5 syllables), narrower than the sentence.
      final width = style.fontSize! * 6.2;
      final plain = lines(s, style, width);
      final kept = lines(keepAllKorean(s), style, width);

      int midWordBreaks(List<String> ls) => [
        for (var i = 0; i < ls.length - 1; i++)
          if (!ls[i].endsWith(' ') && !ls[i + 1].startsWith(' ')) i,
      ].length;

      expect(midWordBreaks(plain), greaterThan(0), reason: '$plain');
      expect(midWordBreaks(kept), 0, reason: '$kept');
      expect(kept.length, greaterThanOrEqualTo(plain.length - 1));
    });
  });
}
