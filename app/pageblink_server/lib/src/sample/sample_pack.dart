import '../rag/chunker.dart';

/// Sample content, in one place (research 028 §4.1): the notes, the PDF and
/// the example questions that are answered by exactly that content. Change a
/// note and its questions in the same edit: `sample_pack_test.dart` fails when
/// a question's `evidence` is no longer in the text.
///
/// Markers: a document is a sample of a pack when its `contentHash` is the
/// hash of the pack's body (as `saveNote` stores it), so no extra column or
/// table is needed. Changing a body changes its hash: add the old hash to
/// [SamplePacks.demoLegacy] (demo) or keep serving the old row (signup).
enum SampleAudience { signup, demo }

/// One sample note. Notes are indexed line by line (design 029), so a
/// question's evidence is a few short chunks of one note, and the heading
/// section around them reaches the model as context.
class SampleNote {
  final String title;
  final String body;

  const SampleNote(this.title, this.body);

  String get hash => sha256Hex(body);
}

/// An example question shown on the Ask screen. [evidence] strings must all
/// occur in the pack's note or PDF text (unit test), so the answer exists.
class SampleQuestion {
  final String text;
  final List<String> evidence;

  const SampleQuestion(this.text, this.evidence);
}

/// The sample PDF (demo only; both languages share it).
class SamplePdf {
  final String title;

  /// Where the original ships. `web/` is the one folder the deploy bundle is
  /// known to contain (research 026 §10). Relative to the working directory.
  final String assetPath;

  /// Per-page text. It must match [assetPath] (the same source produced both)
  /// or citation page numbers drift.
  final List<String> pages;

  SamplePdf({
    required this.title,
    required this.assetPath,
    required this.pages,
  });

  late final String hash = sha256Hex(pages.join('\u0000'));
}

class SamplePack {
  /// `signup-en` `signup-ko` `demo-en` `demo-ko`.
  final String id;

  /// Language of the content (and of [questions]): `en` or `ko`.
  final String locale;
  final SampleAudience audience;
  final List<SampleNote> notes;
  final SamplePdf? pdf;
  final List<SampleQuestion> questions;

  /// Demo packs only: the shared account that holds the pack. `.invalid` is a
  /// reserved TLD (RFC 2606): mail never arrives, so nobody can reset the
  /// password (research 026 §1, §4).
  final String? accountEmail;

  SamplePack({
    required this.id,
    required this.locale,
    required this.audience,
    required this.notes,
    required this.questions,
    this.pdf,
    this.accountEmail,
  });

  /// Marker hashes of the notes and the PDF.
  late final Set<String> hashes = {
    for (final n in notes) n.hash,
    ?pdf?.hash,
  };

  /// All text that an answer may come from.
  String get text => [
    for (final n in notes) '${n.title}\n${n.body}',
    ...?pdf?.pages,
  ].join('\n\n');
}

abstract final class SamplePacks {
  // ── Sign-up samples (research 021 §G) ─────────────────────────────────
  // The hook always inserts the English note (the server does not know the
  // language at sign-up); the first login localizes it (`ensureSample`).
  // Title prefixes `Sample · ` / `샘플 · ` are only a label for the user.

  static final signupEn = SamplePack(
    id: 'signup-en',
    locale: 'en',
    audience: SampleAudience.signup,
    notes: const [
      SampleNote('Sample · My to-do list', '''
# My to-do list

## Today
- [x] Reply to Sam about the venue
- [x] Buy coffee beans
- [ ] Send the invoice to Acme (due 5 pm)

## This week
- [ ] Book the dentist (call before Wednesday)
- [ ] Finish the slides for Friday's team meeting
- [ ] Renew passport (needs 2 photos)

## Later
- [ ] Plan a weekend trip to Busan
- [ ] Clean out the garage
'''),
    ],
    questions: const [
      SampleQuestion('What is left to do this week?', [
        '## This week',
        'Book the dentist',
      ]),
      SampleQuestion('What have I already finished?', [
        '- [x] Buy coffee beans',
      ]),
      SampleQuestion('What is due today?', ['due 5 pm']),
      SampleQuestion('What do I need to renew my passport?', [
        'Renew passport (needs 2 photos)',
      ]),
    ],
  );

  static final signupKo = SamplePack(
    id: 'signup-ko',
    locale: 'ko',
    audience: SampleAudience.signup,
    notes: const [
      SampleNote('샘플 · 할 일 목록', '''
# 내 할 일 목록

## 오늘
- [x] 민수에게 장소 관련 답장 보내기
- [x] 커피 원두 사기
- [ ] 한빛상사에 청구서 보내기 (오후 5시까지)

## 이번 주
- [ ] 치과 예약하기 (수요일 전에 전화)
- [ ] 금요일 팀 회의 발표 자료 마무리
- [ ] 여권 갱신하기 (사진 2장 필요)

## 나중에
- [ ] 주말 부산 여행 계획 세우기
- [ ] 창고 정리하기
'''),
    ],
    questions: const [
      SampleQuestion('이번 주에 남은 일은 뭐야?', ['## 이번 주', '치과 예약하기']),
      SampleQuestion('이미 끝낸 일은 뭐야?', ['- [x] 커피 원두 사기']),
      SampleQuestion('오늘 마감인 일은?', ['오후 5시까지']),
      SampleQuestion('여권 갱신에 뭐가 필요해?', ['여권 갱신하기 (사진 2장 필요)']),
    ],
  );

  // ── Demo samples (plan 014 §8) ────────────────────────────────────────
  // Written for PageBlink; no third-party text. Titles must not start with
  // `Sample · ` / `샘플 · `.

  /// The PDF both demo packs share: one page text with English and Korean
  /// together, so one `pdfHash` and one stored original.
  static final demoPdf = SamplePdf(
    title: 'PageBlink guide',
    assetPath: 'web/samples/pageblink-guide.pdf',
    pages: const [
      r'''
Adding your documents

PageBlink turns what you write and what you upload into something you can ask questions of.

Write a note: tap New note, write in Markdown, and save. A note can be searched a few seconds after saving.

Upload a PDF: tap Upload PDF and choose a file. PageBlink reads the text page by page, so an answer can point to the exact page. Scanned PDFs without text cannot be searched.

문서 추가하기

직접 쓴 노트와 올린 PDF에 질문할 수 있도록 PageBlink가 내용을 정리해 둡니다.

노트 쓰기: 새 노트를 누르고 마크다운으로 쓴 뒤 저장하세요. 저장하고 몇 초 뒤부터 검색됩니다.

PDF 올리기: PDF 올리기를 누르고 파일을 고르세요. 페이지별로 글자를 읽기 때문에 답변이 정확한 페이지를 가리킵니다. 글자가 없는 스캔본 PDF는 검색할 수 없습니다.''',
      r'''
Asking questions

Open the Ask tab and type a question in plain words, for example: What does the guide say about uploading a PDF?

PageBlink finds the most relevant passages in your notes and PDFs and writes an answer from them only. If nothing relevant is found, it tells you instead of guessing.

Tip: mention a topic or a document name in your question to get a more precise answer.

질문하기

질문 탭을 열고 평소 말투로 질문을 적어 보세요. 예: 가이드에서 PDF 올리기는 어떻게 설명하나요?

PageBlink는 내 노트와 PDF에서 가장 관련 있는 부분을 찾아 그 내용만으로 답변을 만듭니다. 관련 내용이 없으면 지어내지 않고 못 찾았다고 알려 줍니다.

팁: 질문에 주제나 문서 이름을 넣으면 더 정확한 답변을 받을 수 있습니다.''',
      r'''
Sources and the demo account

Every answer carries small lightning-bolt markers. Tap one to jump to the note or the PDF page that the answer came from, and check it yourself.

About the demo account: everyone who tries the demo shares one account, so please do not enter personal information. You can create up to 5 notes or PDFs of your own, and they are removed after 24 hours. The sample items cannot be edited or deleted. Questions are limited to 50 per day across all demo visitors. Sign up to keep your work.

출처와 데모 계정

답변마다 작은 번개 모양 표시가 붙습니다. 누르면 답변의 근거가 된 노트나 PDF 페이지로 바로 이동하니 직접 확인해 보세요.

데모 계정 안내: 데모를 체험하는 모든 사람이 하나의 계정을 함께 쓰므로 개인정보는 넣지 마세요. 직접 만들 수 있는 노트와 PDF는 최대 5개이며, 24시간 뒤에 삭제됩니다. 샘플 항목은 수정하거나 삭제할 수 없습니다. 질문은 데모 방문자 전체가 하루 50회까지 할 수 있습니다. 가입하면 계속 쓸 수 있어요.''',
    ],
  );

  static final demoEn = SamplePack(
    id: 'demo-en',
    locale: 'en',
    audience: SampleAudience.demo,
    accountEmail: 'demo@pageblink.invalid',
    pdf: demoPdf,
    notes: const [
      SampleNote('PageBlink tour: try it in 5 minutes', r'''
# PageBlink tour: try it in 5 minutes

PageBlink is **Markdown notes + PDFs you can ask questions to**. Every answer links back to its source.

## Try these
- [x] Open this note, you are reading a sample
- [ ] Ask: *When is the launch, and what is the budget?*
- [ ] Tap ⚡ on the answer to jump to the exact line
- [ ] Create your own note with **New note** (up to 5 in the demo)

## What the editor understands
1. **Bold**, *italic*, ~~strikethrough~~ and `inline code`
2. Bullet lists, numbered lists and `- [ ]` checklists
3. Quotes with `>` and rules with `---`
4. Links, like [PageBlink on GitHub](https://github.com/biyott/pageblink)

---
Samples are locked. Type these markers in your own note and watch them come alive.
'''),
      SampleNote('Q4 launch plan', r'''
# Q4 launch plan

> Goal: ship the new onboarding before the holiday freeze.

## Numbers
- **Marketing budget:** ₩12M for Q4
- **Launch date:** moved to Nov 18, 2026
- **Beta testers:** 20 people

## Timeline
1. Oct 28, 2026: feature freeze
2. Nov 4, 2026: beta invites
3. Nov 18, 2026: public launch

## To do
- [x] Book the launch-day support rota
- [ ] Finalize the release notes
- [ ] Send the beta invite emails

Details: https://github.com/biyott/pageblink
'''),
      SampleNote('Weekly sync: week 3 of October', r'''
# Weekly sync: week 3 of October

Attendees: Mina, Joon, Seoyeon

## Decisions
1. Launch date confirmed for **Nov 18, 2026**
2. Limit the beta to 20 testers
3. ~~Deploy twice a week~~ → deploy once a week

## Action items
- [ ] Draft the release notes (Mina, by Friday)
- [ ] Send the beta invite email (Joon)
- [x] Check staging

## Notes
Staging deploy command: `./deploy.sh --env staging`
More at https://github.com/biyott/pageblink
'''),
    ],
    questions: const [
      SampleQuestion('When is the launch, and what is the budget?', [
        'Nov 18, 2026',
        '₩12M',
      ]),
      SampleQuestion('What is left to do in the Q4 launch plan?', [
        'Finalize the release notes',
        'Send the beta invite emails',
      ]),
      SampleQuestion("What changed in this week's decisions?", [
        '~~Deploy twice a week~~',
        'deploy once a week',
      ]),
      SampleQuestion('How do I upload a PDF?', [
        'Upload a PDF: tap Upload PDF',
      ]),
    ],
  );

  static final demoKo = SamplePack(
    id: 'demo-ko',
    locale: 'ko',
    audience: SampleAudience.demo,
    accountEmail: 'demo-ko@pageblink.invalid',
    pdf: demoPdf,
    notes: const [
      SampleNote('PageBlink 둘러보기: 5분이면 충분해요', r'''
# PageBlink 둘러보기: 5분이면 충분해요

PageBlink는 **마크다운 노트와 PDF에 질문하는 앱**이에요. 답변마다 출처로 바로 이동할 수 있습니다.

## 먼저 해 보세요
- [x] 이 노트 열어 보기 (지금 읽고 있는 샘플이에요)
- [ ] 질문하기: *출시일이 언제고 예산은 얼마야?*
- [ ] 답변의 ⚡를 눌러 근거가 된 줄로 이동하기
- [ ] **새 노트**로 내 노트 만들기 (데모에서는 최대 5개)

## 에디터가 알아듣는 문법
1. **굵게**, *기울임*, ~~취소선~~, `인라인 코드`
2. 글머리 목록, 번호 목록, `- [ ]` 체크리스트
3. `>` 인용과 `---` 구분선
4. 링크: [GitHub의 PageBlink](https://github.com/biyott/pageblink)

---
샘플은 잠겨 있어요. 이 문법을 내 노트에 직접 입력해 보세요.
'''),
      SampleNote('4분기 출시 계획', r'''
# 4분기 출시 계획

> 목표: 연말 배포 동결 전에 새 온보딩을 선보인다.

## 주요 수치
- **마케팅 예산:** 4분기 1,200만 원
- **출시일:** 2026년 11월 18일로 변경
- **베타 테스터:** 20명

## 일정
1. 2026년 10월 28일: 기능 동결
2. 2026년 11월 4일: 베타 초대
3. 2026년 11월 18일: 정식 출시

## 할 일
- [x] 출시 당일 지원 근무표 짜기
- [ ] 릴리스 노트 마무리
- [ ] 베타 초대 메일 발송

자세한 내용: https://github.com/biyott/pageblink
'''),
      SampleNote('주간 회의: 10월 셋째 주', r'''
# 주간 회의: 10월 셋째 주

참석자: 미나, 준, 서연

## 결정 사항
1. 출시일은 **2026년 11월 18일**로 확정
2. 베타는 테스터 20명으로 제한
3. ~~배포는 주 2회~~ → 주 1회로 변경

## 후속 작업
- [ ] 릴리스 노트 초안 작성 (미나, 금요일까지)
- [ ] 베타 초대 메일 발송 (준)
- [x] 스테이징 확인

## 메모
스테이징 배포 명령: `./deploy.sh --env staging`
더 보기: https://github.com/biyott/pageblink
'''),
    ],
    questions: const [
      SampleQuestion('출시일이 언제고 예산은 얼마야?', [
        '2026년 11월 18일',
        '1,200만 원',
      ]),
      SampleQuestion('4분기 출시 계획에서 남은 일이 뭐야?', [
        '릴리스 노트 마무리',
        '베타 초대 메일 발송',
      ]),
      SampleQuestion('이번 주 결정에서 바뀐 게 뭐야?', [
        '~~배포는 주 2회~~',
        '주 1회로 변경',
      ]),
      SampleQuestion('PDF는 어떻게 올려?', ['PDF 올리기: PDF 올리기를 누르고']),
    ],
  );

  static final all = [signupEn, signupKo, demoEn, demoKo];

  static Iterable<SamplePack> get demo =>
      all.where((p) => p.audience == SampleAudience.demo);

  /// `ko*` gets the Korean pack, everything else English. This one line is
  /// the whole notion of a supported language.
  static SamplePack forLocale(String? locale, SampleAudience audience) {
    final ko = (locale ?? '').toLowerCase().startsWith('ko');
    final want = ko ? 'ko' : 'en';
    final packs = all.where((p) => p.audience == audience);
    return packs.firstWhere(
      (p) => p.locale == want,
      orElse: () => packs.firstWhere((p) => p.locale == 'en'),
    );
  }

  /// The pack whose note has this body hash, or null. A PDF hash matches too
  /// (the first pack that holds it).
  static SamplePack? byHash(String hash, {SampleAudience? audience}) {
    for (final p in all) {
      if ((audience == null || p.audience == audience) &&
          p.hashes.contains(hash)) {
        return p;
      }
    }
    return null;
  }

  /// Hashes of every demo sample (notes and PDF): a demo document with one
  /// of these is protected, not counted, never purged.
  static final demoMarkers = <String>{for (final p in demo) ...p.hashes};

  /// Hashes of the sign-up sample notes.
  static final signupMarkers = <String>{
    for (final p in all)
      if (p.audience == SampleAudience.signup) ...p.hashes,
  };

  /// SHA-256 of bodies of demo samples that earlier releases seeded. They are
  /// no longer markers, so a copy in the database would count against the
  /// visitor limit; `DemoSeed.run` deletes the demo accounts' documents with
  /// these hashes (with chunks, pages and the PDF file), then it is a no-op.
  static const demoLegacy = <String>{
    // `Getting started with PageBlink`, `답변의 출처 따라가기`
    '51ca2e449a6443b9eeaa66eaf88845adbb12a890d5b5a1a2a7dd5edc4b4e279b',
    '491865012632aab48c5b91f1743082933d68c509729aa47e3b4c7f4e47ed576b',
    // `Q4 launch plan` and `Weekly sync: week 3 of October` before the dates
    // got their year ("Nov 18" made the model guess one).
    'cb10c39384dc3add3387954c8b7ce45ade3a2e82e9d92bda891fa654a2f52c2c',
    'f4cbe995efc2cd50e128c2c5985f44c01b650e33c9d0454dbd1ded0614681857',
  };
}
