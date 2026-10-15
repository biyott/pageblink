import 'package:flutter/widgets.dart';

/// Locales PageBlink ships. English is the default; anything that isn't
/// Korean resolves to English (see `localeResolutionCallback` in main.dart).
const supportedLocales = [Locale('en'), Locale('ko')];

/// Picks the strings for the locale in scope: `context.l.save`.
extension LContext on BuildContext {
  L get l => Localizations.localeOf(this).languageCode == 'ko' ? L.ko : L.en;
}

/// Every user-facing string, in English and Korean. Lightweight on purpose:
/// no codegen, just getters (and methods for strings with parameters).
/// Product names (PageBlink, ⚡, Cloak, Shared Vision, Sources) stay as-is.
class L {
  const L._(this._ko);

  static const en = L._(false);
  static const ko = L._(true);

  final bool _ko;

  String _t(String en, String ko) => _ko ? ko : en;

  // ── Common ────────────────────────────────────────────────────────────
  String get cancel => _t('Cancel', '취소');
  String get ok => _t('OK', '확인');
  String get save => _t('Save', '저장');
  String get delete => _t('Delete', '삭제');
  String get cannotUndo => _t("This can't be undone.", '되돌릴 수 없어요.');
  String get moreActions => _t('More', '더 보기');

  bool get isKorean => _ko;

  // ── Settings ──────────────────────────────────────────────────────────
  String get settings => _t('Settings', '설정');
  String get language => _t('Language', '언어');
  String get languageSystem => _t('System default', '시스템 설정');
  String get languageEnglish => 'English';
  String get languageKorean => '한국어';
  // Sign-in screen switcher: the button's tooltip / screen-reader label.
  String get changeLanguage => _t('Change language', '언어 변경');

  // ── Shell (main.dart) ─────────────────────────────────────────────────
  String get tabAsk => _t('Ask', '질문');
  String get tabNotes => _t('Notes', '노트');
  String get tabProjects => _t('Projects', '프로젝트');
  String get signOut => _t('Sign out', '로그아웃');

  // ── Sign-in ───────────────────────────────────────────────────────────
  String get pwLowerAndNumber => _t('Lowercase letter + number', '소문자 + 숫자 포함');
  String get pwUppercaseOrSpecial => _t(
    'At least 1 uppercase letter or special character',
    '대문자 또는 특수문자 1개 이상',
  );
  String get resendCode =>
      _t("Didn't receive? Send a new code", '코드를 못 받으셨나요? 새 코드 보내기');
  String get userAuthenticated => _t('Signed in.', '로그인했어요.');
  String authFailed(Object error) =>
      _t('Authentication failed: $error', '인증에 실패했어요: $error');

  // ── Projects (Shared Vision) ──────────────────────────────────────────
  String get newProject => _t('New project', '새 프로젝트');
  String get newProjectHint => _t('e.g. 2026 Hackathon', '예: 2026 해커톤');
  String inviteTo(String project) => _t('Invite to $project', '$project에 초대');
  String get teammateEmail => _t('Teammate email', '팀원 이메일');
  String get invite => _t('Invite', '초대');
  String invited(String email) => _t('Invited $email.', '$email 님을 초대했어요.');
  String inviteFailed(Object error) =>
      _t('Invite failed: $error', '초대 실패: $error');
  String get renameProject => _t('Rename', '이름 변경');
  String get renameProjectTitle => _t('Rename project', '프로젝트 이름 변경');
  String get projectNameTooLong =>
      _t('Use 60 characters or fewer.', '60자 이하로 입력해 주세요.');
  String get projectRenameFailed => _t(
    'Could not rename the project. Please try again.',
    '프로젝트 이름을 바꾸지 못했어요. 잠시 후 다시 시도해 주세요.',
  );
  String get projectDeleteFailed => _t(
    'Could not delete the project. Please try again.',
    '프로젝트를 삭제하지 못했어요. 잠시 후 다시 시도해 주세요.',
  );
  String deleteProjectTitle(String project) =>
      _t('Delete "$project"?', '"$project" 프로젝트를 삭제할까요?');

  /// Shown when the project still holds documents; they are deleted with it.
  String projectDeleteWarning(int notes, int pdfs) => _t(
    '$notes ${notes == 1 ? 'note' : 'notes'} and '
        '$pdfs ${pdfs == 1 ? 'PDF' : 'PDFs'} will be deleted with it. '
        "This can't be undone.",
    '노트 $notes개, PDF $pdfs개가 함께 삭제됩니다. 되돌릴 수 없어요.',
  );
  String get projectsEmpty => _t(
    'Create a project to share notes and documents\n'
        'with your team and ask together. (Shared Vision)',
    '프로젝트를 만들면 팀원과 문서를 공유하고\n함께 질문할 수 있어요. (Shared Vision)',
  );

  // ── Viewer ────────────────────────────────────────────────────────────
  String get originalMissing => _t(
    "The original PDF isn't on this device, so only the quoted passage is shown.",
    '원본 PDF가 이 기기에 없어 인용 구절만 보여 드려요.',
  );

  // ── Note editor ───────────────────────────────────────────────────────
  String saveFailed(Object error) => _t('Save failed: $error', '저장 실패: $error');
  String get edit => _t('Edit', '편집');
  String get preview => _t('Preview', '미리보기');
  String get titleHint => _t('Title', '제목');
  String get noteHint =>
      _t('Take a note… (Markdown supported)', '메모하기… (Markdown 지원)');
  String get deleteNoteTitle => _t('Delete this note?', '이 노트를 삭제할까요?');
  String get noteDeleteFailed => _t(
    'Could not delete the note. Please try again.',
    '노트를 삭제하지 못했어요. 잠시 후 다시 시도해 주세요.',
  );
  String get fmtHeading => _t('Heading', '제목');
  String get fmtBold => _t('Bold', '굵게');
  String get fmtItalic => _t('Italic', '기울임');
  String get fmtList => _t('List', '목록');
  String get fmtCheckbox => _t('Checkbox', '체크박스');
  String get fmtQuote => _t('Quote', '인용');
  String get fmtCode => _t('Code', '코드');
  String get fmtLink => _t('Link', '링크');
  String get fmtBodyText => _t('Body text', '본문');
  String get fmtStrike => _t('Strikethrough', '취소선');
  String get fmtOrderedList => _t('Numbered list', '번호 목록');
  String get openLink => _t('Open', '열기');
  String get linkOpenFailed => _t('Could not open the link.', '링크를 열지 못했어요.');
  String get modeLive => _t('Live', '라이브');
  String get modeSource => _t('Source', '소스');

  // ── Documents ─────────────────────────────────────────────────────────
  String get uploadPdf => _t('Upload PDF', 'PDF 올리기');
  String get newNote => _t('New note', '새 노트');
  String get emptyNotes => _t(
    'No notes yet.\nWrite a note or upload a PDF, then ask about it.',
    '아직 노트가 없어요.\n메모를 쓰거나 PDF를 올리고 질문해 보세요.',
  );
  String get reindex => _t('Re-index', '다시 색인');
  String get reindexAll => _t('Re-index all', '모두 다시 색인');
  String get indexing => _t('Indexing', '색인 중');
  String get indexingFailed => _t('Indexing failed', '색인 실패');
  String failedBanner(int n) => _t(
    '$n ${n == 1 ? 'document' : 'documents'} failed to index and '
        '${n == 1 ? 'is' : 'are'} left out of Ask.',
    '색인 실패 $n개 — 질문 검색에서 빠져 있어요.',
  );
  String pdfPages(int n) =>
      _t('PDF · $n ${n == 1 ? 'page' : 'pages'}', 'PDF · $n쪽');
  String get shared => _t('Shared', '공유');

  String reading(String file) => _t('Reading $file…', '$file 읽는 중…');
  String indexingFile(String file, int pages) => _t(
    'Indexing $file… ($pages ${pages == 1 ? 'page' : 'pages'})',
    '$file 색인 중… ($pages쪽)',
  );
  String storingOriginal(String file) =>
      _t('Saving original of $file…', '$file 원본 저장 중…');
  String uploadFailed(Object error) =>
      _t('Upload failed: $error', '업로드 실패: $error');
  String originalSkipped(Object error) => _t(
    'Skipped saving the original (still viewable on this device): $error',
    '원본 저장은 건너뛰었어요 (이 기기에서는 열람 가능): $error',
  );
  String reindexing(String title) =>
      _t('Re-indexing $title…', '$title 다시 색인 중…');
  String indexed(String title) => _t('Indexed: $title', '색인 완료: $title');
  String reindexFailed(Object error) =>
      _t('Re-index failed: $error', '다시 색인 실패: $error');
  String get reindexingFailedItems =>
      _t('Re-indexing failed items…', '실패한 항목 다시 색인 중…');
  String reindexedCount(int n) => _t('$n re-indexed', '$n개 색인 완료');
  String get deleteQuestion => _t('Delete?', '삭제할까요?');
  String deleteFailed(Object error) =>
      _t('Delete failed: $error', '삭제 실패: $error');

  // Storage tiers.
  String get whereToPut => _t('Where should it go?', '어디에 둘까요?');
  String get cloakTitle => _t('Cloak · This device only', 'Cloak · 이 기기에만');
  String get cloakSubtitle =>
      _t('Offline-only documents — coming soon', '오프라인 전용 문서 — 곧 지원');
  String get myCloud => _t('My cloud', '내 클라우드');
  String get onlyYou => _t('Only you can see it', '나만 볼 수 있어요');
  String sharedVision(String project) => 'Shared Vision · $project';
  String get shareWithMembers =>
      _t('Shared with project members', '프로젝트 멤버와 공유');

  /// Maps the server's `Document.lastError` code to friendly text. Unknown
  /// strings (e.g. an older Korean sentence from the server) pass through.
  String indexingError(String? code) => switch (code) {
    null => '',
    'quota' => _t(
      'The AI usage quota has been reached. Try again later.',
      'AI 사용 한도에 도달했어요. 잠시 후 다시 시도해 주세요.',
    ),
    'auth' => _t(
      "The AI provider rejected the server's API key. Check the server setup.",
      'AI 제공업체가 서버의 API 키를 거부했어요. 서버 설정을 확인해 주세요.',
    ),
    'rate' => _t(
      'Too many requests right now. Try again in a moment.',
      '요청이 너무 많아요. 잠시 후 다시 시도해 주세요.',
    ),
    'outage' => _t(
      'The AI service is temporarily unavailable. Try again later.',
      'AI 서비스가 일시적으로 응답하지 않아요. 나중에 다시 시도해 주세요.',
    ),
    'no_source' => _t(
      'No text could be extracted from the source (e.g. a scanned PDF).',
      '원본에서 텍스트를 추출하지 못했어요 (스캔한 PDF 등).',
    ),
    'unknown' => _t(
      'Indexing failed for an unknown reason. Try again.',
      '알 수 없는 이유로 색인에 실패했어요. 다시 시도해 주세요.',
    ),
    _ => code,
  };

  // ── Ask ───────────────────────────────────────────────────────────────
  String get askHint => _t('Ask your notes…', '내 노트에 질문하기…');
  String get askTooltip => _t('Ask', '질문');
  String get answerModel => _t('Answer model', '답변 모델');
  String get myDocs => _t('My documents', '내 문서');
  String get askEmptyTitle => _t('Ask your notes & documents', '노트와 문서에 질문하세요');
  String get askEmptySubtitle => _t(
    'Every answer links back to its ⚡ sources',
    '모든 답변은 ⚡ 출처로 연결됩니다',
  );
  List<String> get askSuggestions => _ko
      ? const [
          '이번 주 할 일 정리해줘',
          '회의록에서 결정된 사항은?',
          '이 PDF의 핵심 요약',
          '예산과 마감일 알려줘',
        ]
      : const [
          "Sum up this week's to-dos",
          'What was decided in the meeting notes?',
          'Summarize the key points of this PDF',
          'What are the budget and the deadline?',
        ];

  /// Questions the sign-up sample note answers; shown first while it exists.
  List<String> get sampleSuggestions => _ko
      ? const [
          '이번 주에 남은 일은 뭐야?',
          '이미 끝낸 일은 뭐야?',
          '오늘 마감인 일은?',
          '여권 갱신에 뭐가 필요해?',
        ]
      : const [
          'What is left to do this week?',
          'What have I already finished?',
          'What is due today?',
          'What do I need to renew my passport?',
        ];

  // ── Landing / sign-in (docs/plan/007) ─────────────────────────────────
  String get landingHeadline => _t(
    'Ask your notes. Every answer shows its source.',
    '내 노트에 물어보세요. 답마다 출처가 보여요.',
  );
  String get landingSub => _t(
    'Keep notes and PDFs in one place, then ask in plain words. PageBlink answers from your own files and links each answer to the exact note or page.',
    '메모와 PDF를 한곳에 모아 두고 편하게 물어보세요. PageBlink가 내 자료에서 답을 찾고, 근거가 된 메모나 페이지로 바로 데려다 드려요.',
  );
  String get landingFeatureBoardTitle => _t(
    'Notes and PDFs together',
    '메모와 PDF를 한곳에',
  );
  String get landingFeatureBoardBody => _t(
    'Jot down notes or upload PDFs — both can answer your questions.',
    '메모를 쓰거나 PDF를 올리면, 둘 다 질문에 답할 수 있어요.',
  );
  String get landingFeatureCiteTitle => _t(
    'Answers you can check',
    '확인할 수 있는 답',
  );
  String get landingFeatureCiteBody => _t(
    'Tap ⚡ next to an answer to open the page it came from.',
    '답 옆의 ⚡를 누르면 근거가 된 페이지가 열려요.',
  );
  String get landingFeatureShareTitle => _t(
    'Share with your team',
    '팀과 함께',
  );
  String get landingFeatureShareBody => _t(
    'Put files in a project and teammates can ask them too.',
    '프로젝트에 넣어 두면 팀원도 같은 자료에 물어볼 수 있어요.',
  );
  String get landingFeaturePrivacyTitle => _t(
    'Private by default',
    '기본은 나만 보기',
  );
  String get landingFeaturePrivacyBody => _t(
    'Only you can see your notes unless you share them. Device-only notes are coming soon.',
    '공유하지 않으면 나만 볼 수 있어요. 기기에만 두는 메모 기능도 곧 나와요.',
  );
  String get landingTrust => _t(
    'Built with Flutter + Serverpod · Free models via OpenRouter',
    'Flutter + Serverpod로 제작 · OpenRouter 무료 모델 사용',
  );
  String get landingFreeModelNote =>
      _t('Free models may log prompts.', '무료 모델은 프롬프트를 기록할 수 있어요.');
  String get signInTitle => _t('Sign in or create an account', '로그인 또는 가입');
  String get signInSubtitle => _t(
    'Your notes stay private unless you share a project.',
    '프로젝트로 공유하지 않는 한 노트는 나만 볼 수 있어요.',
  );
  String get signInHelper => _t(
    'New here? Tap Sign up below the button — we\'ll email you a verification code.',
    '처음이신가요? 로그인 버튼 아래의 가입을 누르면 인증 코드를 메일로 보내 드려요.',
  );
  String get landingFooterCredit => _t(
    'Built for Build Something Real: The Serverpod Hackathon',
    'Build Something Real: The Serverpod Hackathon 출품작',
  );
  String get landingPreviewNoteTitle => _t('Budget memo', '예산 메모');
  String get landingPreviewNoteBody => _t(
    'Q4 marketing budget: ₩12M. Launch moved to Nov 18.',
    '4분기 마케팅 예산 1,200만 원. 출시는 11/18로 연기.',
  );
  String get landingPreviewAnswerA =>
      _t('The Q4 budget is ₩12M', '4분기 예산은 1,200만 원이고');
  String get landingPreviewAnswerB =>
      _t('and the launch moved to Nov 18', '출시는 11월 18일로 미뤄졌어요');

  // ── AB v2 shell / board ───────────────────────────────────────────────
  String get tagline => _t(
    'Ask your notes & documents. Every answer shows its source.',
    '노트와 문서에 물어보세요. 답마다 출처가 보여요.',
  );
  String get tiers => _t('Tiers', '계층');
  String get soon => _t('Soon', '곧');
  String get deviceOnly => _t('device only', '기기 전용');
  String get privateToYou => _t('private to you', '나만 보기');
  String get sharedVisionName => 'Shared Vision';
  String get projectsNone => _t('no projects yet', '프로젝트 없음');
  String get searchHint => _t('Search notes & PDFs…', '노트와 PDF 검색…');
  String boardCount(int notes, int pdfs) => _t(
    '${notes + pdfs} items · $notes ${notes == 1 ? 'note' : 'notes'}, '
        '$pdfs ${pdfs == 1 ? 'PDF' : 'PDFs'}',
    '${notes + pdfs}개 항목 · 노트 $notes개, PDF $pdfs개',
  );
  String get filterAll => _t('All', '전체');
  String get filterNotes => _t('Notes', '노트');
  String get filterPdfs => 'PDFs';
  String needsAttention(int n) => _t('$n needs attention', '확인 필요 $n');
  String get recent => _t('Recent', '최근');
  String get noMatches => _t('Nothing matches.', '일치하는 항목이 없어요.');
  String get keywordOnly => _t('Keyword search only', '키워드 검색만 가능');
  String noteMeta(String ago) => _t('Note · $ago', '노트 · $ago');
  String pdfMeta(int pages) =>
      _t('PDF · $pages ${pages == 1 ? 'page' : 'pages'}', 'PDF · $pages쪽');

  String ago(DateTime t) {
    final d = DateTime.now().difference(t);
    if (d.inMinutes < 1) return _t('just now', '방금');
    if (d.inMinutes < 60) return _t('${d.inMinutes}m ago', '${d.inMinutes}분 전');
    if (d.inHours < 24) return _t('${d.inHours}h ago', '${d.inHours}시간 전');
    if (d.inDays < 7) return _t('${d.inDays}d ago', '${d.inDays}일 전');
    return _t('${t.month}/${t.day}', '${t.month}월 ${t.day}일');
  }

  // ── AB v2 Ask ─────────────────────────────────────────────────────────
  String get askPlaceholder =>
      _t('Ask your notes & documents…', '노트와 문서에 질문하기…');
  String get sourcesLabel => _t('Sources', '출처');

  /// Spoken label of the tappable ⚡n marker inside an answer.
  String citeMarkerLabel(int n) => _t('Source $n', '출처 $n');

  /// Spoken label of one source row under an answer.
  String sourceRowLabel(
    int n,
    String title, {
    required bool isNote,
    int? page,
  }) {
    final en = isNote ? 'note' : 'PDF page $page';
    final ko = isNote ? '노트' : 'PDF $page쪽';
    return _t('Source $n: $title, $en', '출처 $n: $title, $ko');
  }

  String moreSources(int n) => _t('Show $n more', '외 $n개 더 보기');
  String get lessSources => _t('Show fewer', '접기');
  String get copy => _t('Copy', '복사');
  String get copied => _t('Copied', '복사했어요');
  String get scope => _t('Search scope', '검색 범위');
  String get scopeSubtitle => _t(
    'Answers come from notes and PDFs in the checked places',
    '선택한 곳의 노트와 PDF에서 답을 찾아요',
  );
  String get scopeEmpty => _t('Nothing selected to search', '검색할 곳이 없어요');
  String get selectAll => _t('Select all', '모두 선택');
  String get clearAll => _t('Clear all', '모두 해제');
  String get done => _t('Done', '완료');

  /// Summary button text for the chosen sources (`projects` = checked count).
  String scopeSummary(bool personal, int projects) {
    if (!personal && projects == 0) return scopeEmpty;
    final p = _t(
      '$projects ${projects == 1 ? 'project' : 'projects'}',
      '프로젝트 $projects개',
    );
    final what = !personal
        ? p
        : projects == 0
        ? _t('My documents only', '내 문서만')
        : _t('My documents + $p', '내 문서 + $p');
    return _t('Sources: $what', '출처: $what');
  }

  String get modelAuto => _t('Auto', '자동');
  String get modelAutoRotates =>
      _t('Auto · rotates free models', '자동 · 무료 모델 순환');
  String get askFailed => _t(
    'Could not get an answer. Please try again shortly.',
    '답변을 받지 못했어요. 잠시 후 다시 시도해 주세요.',
  );

  /// The server's catalog notes are English and repeat what the badge says.
  /// Drops the "free" / "paid $…" parts and translates known phrases; unknown
  /// phrases pass through unchanged. Null when nothing is left.
  String? modelNote(String? note) {
    if (note == null) return null;
    final parts = [
      for (final p in note.split(' · '))
        if (p != 'free' && !p.startsWith('paid')) _ko ? (_noteKo[p] ?? p) : p,
    ];
    return parts.isEmpty ? null : parts.join(' · ');
  }

  static const _noteKo = {
    'recommended': '추천',
    'multilingual': '다국어',
    'fast': '빠름',
    'large model': '큰 모델',
    'lightweight': '가벼움',
    'largest': '가장 큼',
    'may be slow': '느릴 수 있음',
    'reasoning': '추론형',
    'slower first token': '첫 글자가 느림',
    'quality': '고품질',
  };
  String get aiDisclaimer => _t(
    'AI can make mistakes. Check the ⚡ sources.',
    'AI는 틀릴 수 있어요. ⚡ 출처를 확인하세요.',
  );
  String get free => _t('Free', '무료');
  String get paid => _t('Paid', '유료');

  // ── Citation sheet ────────────────────────────────────────────────────
  String get citedInAnswer => _t('Cited in AI answer', 'AI 답변에서 인용됨');
  String sourceNofM(int n, int m) => _t('Source $n of $m', '출처 $n / $m');
  String get openFullPage => _t('Open full page', '전체 페이지 열기');
  String pageN(int n) => _t('Page $n', '$n쪽');
  String get kindNote => _t('Note', '노트');
  String get kindPdf => 'PDF';
  String get back => _t('Back', '뒤로');
  String get closeEsc => _t('Close (Esc)', '닫기 (Esc)');
  String get newChat => _t('New question', '새 질문');
}
