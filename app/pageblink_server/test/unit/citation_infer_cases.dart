// Labeled synthetic cases for the token match of `inferCitations` (backlog
// 2-5). Everything here is invented: no user data, no model output. Used by
// citation_infer_test.dart, which pins "no mis-link, no regression".

/// Evidence lines ("packs"), as the retriever hands them over, in source order.
/// The `B`/`C` packs add a second source that collides with the first.
const packs = <String, List<String>>{
  'koA': _koA,
  'koB': [
    ..._koA,
    '- 11월 18일 프레스 킷 배포 예정', // 12
    '- 회의록 2026-11-18 작성 완료', // 13
  ],
  'koC': [..._koA, '- 팀 커뮤니케이션 도구는 슬랙'], // 12
  'enA': _enA,
  'enB': [
    ..._enA,
    '- Press kit goes out Nov 18', // 12
    '- Meeting notes dated 2026-11-18 filed', // 13
  ],
};

const _koA = [
  '- **출시일:** 2026년 11월 18일로 변경',
  '- **마케팅 예산:** 4분기 1,200만 원',
  '- 베타 테스터 모집 인원은 250명',
  '- 서버 점검은 매주 화요일 02:00에 진행',
  '- 2026년 11월 28일: 앱스토어 심사 제출',
  '- 고객 지원팀은 8명, 야간 근무는 2명',
  '- 이해관계자 커뮤니케이션 계획은 법무팀과 검토',
  '- 릴리스 노트 마무리 (3개 항목 남음)',
  '- 월 구독료는 9,900원, 연간 결제 시 99,000원',
  '- 베타 서버 응답 시간 목표는 300ms 이하',
  '- 목표 사용자 수는 12만 명',
  '- 팀 회식은 금요일 18:30',
];

const _enA = [
  '- **Launch date:** moved to Nov 18, 2026',
  '- **Marketing budget:** ₩12M for Q4',
  '- Beta tester cap is 250 users',
  '- Server maintenance every Tuesday at 02:00',
  '- App Store review submission on Nov 28, 2026',
  '- Support team has 8 agents, 2 on night shifts',
  '- Stakeholder communications plan reviewed by legal',
  '- Release notes: 3 items left',
  '- Subscription costs \$9.99 per month or \$99 per year',
  '- Beta response time target is under 300 ms',
  '- Target audience of 120,000 people',
  '- Team dinner on Friday at 18:30',
];

/// (id, category, pack, answer, truth): [truth] is what a careful reader would
/// link (0-based), also where the function is expected to stay silent.
///
/// Categories: `true` a narrative answer the token match should link,
/// `fn` a true answer it is expected to miss, `amb` ambiguous (a token in
/// two lines), `num` number-only / unit collision, `near` near-miss date or
/// amount, `neg` a "not found" answer, `old` forward / reverse behavior.
typedef Case = (String, String, String, String, List<int>);

const cases = <Case>[
  // -- true: Korean, particles and endings differ from the evidence ---------
  ('k01', 'true', 'koA', '출시일은 2026년 11월 18일입니다.', [0]),
  ('k02', 'true', 'koA', '앱 출시는 2026년 11월 18일로 변경되었습니다.', [0]),
  ('k03', 'true', 'koA', '앱스토어 심사는 2026년 11월 28일에 제출합니다.', [4]),
  ('k04', 'true', 'koA', '4분기 마케팅 예산은 1,200만원이에요.', [1]),
  ('k05', 'true', 'koA', '베타 테스터는 최대 250명까지 모집합니다.', [2]),
  ('k06', 'true', 'koA', '구독료는 월 9,900원, 연간 결제 시 99,000원입니다.', [8]),
  ('k07', 'true', 'koA', '고객 지원팀은 8명이고, 야간 근무는 2명입니다.', [5]),
  ('k08', 'true', 'koA', '이해관계자 커뮤니케이션 계획은 법무팀과 검토합니다.', [6]),
  ('k09', 'true', 'koA', '응답 시간 목표는 300ms 이하입니다.', [9]),
  ('k10', 'true', 'koA', '목표 사용자는 12만 명입니다.', [10]),
  (
    'k11',
    'true',
    'koA',
    '출시일은 2026년 11월 18일입니다. 마케팅 예산은 4분기 1,200만 원입니다.',
    [0, 1],
  ),
  ('k12', 'true', 'koA', '11월 28일에 앱스토어 심사를 제출합니다.', [4]),
  ('p01', 'true', 'koA', '출시일이 2026-11-18로 확정됐습니다.', [0]),
  ('p02', 'true', 'koA', '예산은 4분기에 1,200만 원이 책정됐습니다.', [1]),
  (
    'p03',
    'true',
    'koA',
    '출시일은 2026년 11월 18일이며, 앱스토어 심사 제출은 2026년 11월 28일입니다.',
    [0, 4],
  ),
  ('p05', 'true', 'koA', '이해관계자와의 커뮤니케이션은 법무팀이 검토합니다.', [6]),
  (
    'a06',
    'true',
    'koA',
    '응답 시간 목표는 300ms 이하이고, 출시일은 2026년 11월 18일입니다.',
    [0, 9],
  ),
  ('m13', 'true', 'koA', '목표 사용자는 12만 명이고 응답 시간은 300ms입니다.', [9, 10]),
  ('m15', 'fn', 'koA', '월 구독료는 9,900원입니다.', [8]), // one shared word
  // -- true: English --------------------------------------------------------
  ('e01', 'true', 'enA', 'The launch date is November 18, 2026.', [0]),
  ('e02', 'true', 'enA', 'The launch was moved to 18 November 2026.', [0]),
  (
    'e03',
    'true',
    'enA',
    'The App Store review is submitted on Nov 28, 2026.',
    [4],
  ),
  ('e04', 'true', 'enA', 'The marketing budget for Q4 is ₩12M.', [1]),
  (
    'e05',
    'true',
    'enA',
    'Up to 250 users can join the beta tester program.',
    [2],
  ),
  ('e10', 'true', 'enA', 'Stakeholder communications matter a lot.', [6]),
  (
    'e06',
    'true',
    'enA',
    'Stakeholder communications are reviewed by legal.',
    [6],
  ),
  ('e07', 'true', 'enA', 'The response time target is under 300 ms.', [9]),
  (
    'e08',
    'true',
    'enA',
    'A subscription costs \$9.99 monthly or \$99 yearly.',
    [8],
  ),
  ('e09', 'true', 'enA', 'The target audience is 120,000 people.', [10]),
  (
    'e11',
    'true',
    'enA',
    'The launch date is Nov 18, 2026. The response time target is 300 ms.',
    [0, 9],
  ),
  ('e12', 'true', 'enA', 'App Store review submission happens on Nov 28.', [4]),
  // -- fn: right answers the conservative rules are expected to miss -------
  ('k13', 'fn', 'koA', '서버 점검은 매주 화요일 새벽 2시에 합니다.', [3]),
  ('k14', 'fn', 'koA', '릴리스 노트는 3개 항목이 남았습니다.', [7]),
  ('k16', 'fn', 'koA', '출시일: 2026.11.18', [0]),
  ('k17', 'fn', 'koA', '출시일은 2026년 11월쯤입니다.', [0]),
  // the unit swallows "users": only "beta" is left to share
  ('e05b', 'fn', 'enA', 'Up to 250 users can join the beta.', [2]),
  ('m21', 'fn', 'enA', 'Nov 28, 2026 is the date.', [4]),
  // the forward match of source 9 covers the whole phrase: no token pass
  (
    'a06b',
    'fn',
    'koA',
    '베타 서버 응답 시간 목표는 300ms 이하이고, 출시일은 2026년 11월 18일입니다.',
    [0, 9],
  ),
  // -- amb: a token that two evidence lines share ---------------------------
  ('a01', 'amb', 'koB', '출시일은 2026년 11월 18일입니다.', [0]),
  ('a02', 'amb', 'koB', '프레스 킷은 11월 18일에 배포됩니다.', [12]),
  ('a03', 'amb', 'enB', 'The launch date is November 18, 2026.', [0]),
  ('a04', 'amb', 'enB', 'The press kit goes out on Nov 18.', [12]),
  ('a07', 'amb', 'koC', '커뮤니케이션 계획을 세웠습니다.', [6]),
  // -- num: a number or a unit that only looks the same ---------------------
  ('c01', 'num', 'koA', '이번 설문에는 8명이 응답했습니다.', []),
  ('c02', 'num', 'koA', '회의 안건은 3개 항목입니다.', []),
  ('c03', 'num', 'koA', '지난달 로딩 시간은 300ms였습니다.', []),
  ('c04', 'num', 'enA', 'Only 250 days passed since then.', []),
  ('c05', 'num', 'enA', 'Page load takes 300 ms on mobile.', []),
  ('c06', 'num', 'enA', 'We shipped 12 items last week.', []),
  ('c07', 'num', 'enA', 'Only 8 users complained.', []),
  ('c08', 'num', 'koA', '문의는 2026년 10월 3일에 접수되었습니다.', []),
  ('c09', 'num', 'koA', '목표 사용자 수는 12명입니다.', []),
  // -- near: right subject with a wrong date / amount, or the reverse -------
  ('n01', 'near', 'koA', '출시일은 2026년 11월 19일입니다.', []),
  ('n02', 'near', 'koA', '출시일은 2025년 11월 18일입니다.', []),
  ('n03', 'near', 'koA', '앱스토어 심사는 2026년 11월 18일에 제출합니다.', []),
  ('n05', 'near', 'koA', '마케팅 예산은 1,500만 원입니다.', []),
  ('n06', 'near', 'koA', '베타 테스터는 최대 520명입니다.', []),
  ('en01', 'near', 'enA', 'The launch date is November 19, 2026.', []),
  (
    'en02',
    'near',
    'enA',
    'App Store review submission is on Nov 18, 2026.',
    [],
  ),
  ('en03', 'near', 'enA', 'Beta testers number 520 users.', []),
  ('en04', 'near', 'enA', 'The Q4 budget is \$12 million.', []),
  ('n07', 'near', 'koA', '베타 테스터 모집은 2026년 11월 18일에 시작합니다.', []),
  ('n08', 'near', 'enA', 'The launch date is not Nov 28, 2026.', []),
  ('m19', 'num', 'koA', '3천 명이 가입했습니다.', []),
  ('m22', 'num', 'enA', 'The communications team is large.', []),
  // -- neg: "not found" answers that still repeat a date --------------------
  ('g01', 'neg', 'koA', '2026년 11월 18일 출시일 정보는 문서에서 찾을 수 없습니다.', []),
  (
    'g02',
    'neg',
    'enA',
    'I could not find a launch on Nov 18, 2026 in the documents.',
    [],
  ),
  ('g03', 'neg', 'koA', '문서에서 찾을 수 없습니다.', []),
  // -- old: forward / reverse behavior stays --------------------------------
  ('o01', 'old', 'koA', '- **출시일:** 2026년 11월 18일로 변경', [0]),
  ('o02', 'old', 'enB', 'Nov 18, 2026', [0]),
  ('o03', 'old', 'enA', '₩12M for Q4', [1]),
  ('o04', 'old', 'koA', '1,200만 원', [1]),
  (
    'o05',
    'old',
    'koA',
    '릴리스 노트 마무리 (3개 항목 남음)와 출시일은 2026년 11월 18일입니다.',
    [0, 7],
  ),
];

/// What `inferCitations` returned for each case before the token match (the
/// commit before it), so that the test can tell a regression from a gain.
const oldLinks = <String, List<int>>{
  'k01': [],
  'k02': [],
  'k03': [],
  'k04': [],
  'k05': [],
  'k06': [],
  'k07': [],
  'k08': [6],
  'k09': [],
  'k10': [],
  'k11': [],
  'k12': [],
  'p01': [],
  'p02': [],
  'p03': [],
  'p05': [],
  'a06': [],
  'm13': [],
  'm15': [],
  'e01': [],
  'e02': [],
  'e03': [],
  'e04': [],
  'e05': [],
  'e10': [],
  'e06': [],
  'e07': [],
  'e08': [],
  'e09': [],
  'e11': [],
  'e12': [],
  'k13': [],
  'k14': [],
  'k16': [],
  'k17': [],
  'e05b': [],
  'm21': [],
  'a06b': [9],
  'a01': [],
  'a02': [],
  'a03': [],
  'a04': [],
  'a07': [],
  'c01': [],
  'c02': [],
  'c03': [],
  'c04': [],
  'c05': [],
  'c06': [],
  'c07': [],
  'c08': [],
  'c09': [],
  'n01': [],
  'n02': [],
  'n03': [],
  'n05': [],
  'n06': [],
  'en01': [],
  'en02': [],
  'en03': [],
  'en04': [],
  'n07': [],
  'n08': [],
  'm19': [],
  'm22': [],
  'g01': [],
  'g02': [],
  'g03': [],
  'o01': [0],
  'o02': [0],
  'o03': [1],
  'o04': [1],
  'o05': [7],
};
