# 010 · 제품 이름 후보 30선

| 항목 | 값 |
|---|---|
| 조사일 | 2026-10-14 (KST) |
| 담당 | 서브에이전트 (general-purpose) |
| 질문 | "ragpod"는 너무 기술적이다. 귀엽고 쉽고 와닿는 이름 30개와 추천 이유·충돌 여부는? |
| 결론 한 줄 | Top 5: **Dotori · Mureobwa(물어봐) · Jumeoni(주머니) · Hamzzi(햄찌) · Pagepin** — 사용자 결정 대기 |
| 반영 | 결정 후 ADR로 기록 (앱 표시 이름 · Cloud 프로젝트 ID. 코드 패키지명 `ragpod_*`는 유지 권장) |

## 조사 방법과 한계
- pub.dev: 30개 모두 `pub.dev/api/packages/<name>` 정확 일치 조회 → 전부 404(미등록) ✅
- 웹 검색 8회(묶음 4 + 단독 4). Play/App Store 직접 확인 아님 → "낮음" = 검색에 안 잡힘 ⚠️. 상표·스토어 등록 여부는 별도 확인 필요
- Cloud ID는 소문자·하이픈, Dart 접두사는 `_` (예: `dotori-docs` → `dotori_docs`)

## 후보 표

| # | 이름 | 발음 | 의미·유래 | 추천 이유 | 마스코트/브랜딩 | Cloud ID | 충돌 위험(근거) |
|---|---|---|---|---|---|---|---|
| 1 | Dotori | 도토리 | 도토리 | 다람쥐가 도토리를 모으듯 문서를 폰에 저장하고 겨울에 꺼내 봄 | 도토리 모자 다람쥐, 껍질=폰·열매=클라우드 | `dotori-docs` | **중간** 한국 App Store에 "도토리" 일기·RSS 리더 앱 |
| 2 | Acornote | 에이콘노트 | acorn+note | #1의 영어판 | 도토리 모양 노트 | `acornote` | **높음** App Store AI 노트 앱 "Acornote" |
| 3 | Hamzzi | 햄찌 | 햄스터 애칭 | 볼주머니 = 기기 내 저장 | 볼 빵빵 햄스터, 승급 = 볼→집 | `hamzzi` | 낮음 |
| 4 | Kkachi | 까치 | 까치 | 반짝이는 걸 모으고 좋은 소식을 물어다 줌 | 문서 물고 오는 까치 | `kkachi` | 낮음 |
| 5 | Kokkiri | 코끼리 | 코끼리·"끼리끼리" | 잊지 않는 코끼리 + 팀이 같이 봄 | 코로 페이지 넘기는 코끼리 | `kokkiri` | 낮음 |
| 6 | Buong | 부엉 | 부엉이 울음 | 읽고 대답하는 지식의 상징 | 책 위 부엉이 | `buong` | 낮음 |
| 7 | Pouchy | 파우치 | pouch | 캥거루 주머니처럼 내 폰 속 보관 | 문서가 쏙 들어가는 주머니 | `pouchy` | 낮음 |
| 8 | Pagemole | 페이지몰 | page+두더지 | 땅속(폰 안)에서 페이지를 파서 찾음 | 안경 쓴 두더지 | `pagemole` | 낮음 |
| 9 | Daramzzi | 다람찌 | 다람쥐+찌 | #1의 더 귀여운 버전 | 다람쥐 캐릭터 | `daramzzi` | 낮음 |
| 10 | Stashy | 스태시 | stash(쟁여두기) | 도토리 쟁이기의 영어판 | 뭉툭한 다람쥐 | `stashy` | 낮음~중간 (흔한 단어형) |
| 11 | Mureobwa | 물어봐 | "물어봐!" | 기능이 곧 이름 | 말풍선 물음표 캐릭터 | `mureobwa` | 낮음 |
| 12 | Pagepin | 페이지핀 | page+pin | 인용 탭 → 페이지 점프라는 핵심 UX | 핀 로고 | `pagepin` | 낮음 |
| 13 | Peekapage | 피카페이지 | peek-a-boo+page | 까꿍 하듯 페이지가 튀어나옴 | 페이지 뒤에서 눈만 내민 캐릭터 | `peekapage` | 낮음 |
| 14 | Eodiya | 어디야 | "어디야?" | "그 내용 어디 있지?" | 위치 핀 + 돋보기 | `eodiya` | 낮음~중간 (일반 표현) |
| 15 | Galpi | 갈피 | 책갈피·"갈피를 잡다" | 페이지 점프 + 감을 잡게 해 줌 | 책갈피 리본 | `galpi` | 낮음 |
| 16 | Jjokji | 쪽지 | 쪽(페이지)+쪽지 | "쪽" = 페이지 → 인용과 연결 | 접힌 포스트잇 | `jjokji` | 중간 (카톡·네이버 쪽지 기능) |
| 17 | Jumeoni | 주머니 | 주머니 | 폰 주머니·복주머니(소중한 것) | 전통 복주머니 | `jumeoni` | 낮음 |
| 18 | Dungji | 둥지 | 둥지 | 프로젝트 문서를 팀이 공유하는 보금자리 | 둥지 속 알 = 문서 | `dungji` | 낮음 |
| 19 | Saseo | 사서 | 사서(librarian) | 질문하면 찾아 주는 AI 사서 | 안경 쓴 사서 | `saseo` | 낮음 |
| 20 | Seorap | 서랍 | 서랍 | 비밀 문서는 내 서랍에 | 칸마다 색이 다른 서랍 | `seorap` | 중간 (노트 앱 기능명으로 흔함) |
| 21 | Bomul | 보물 | 보물 | 소중한 문서를 지킴 | 보물상자 | `bomul` | 낮음 |
| 22 | Cubby | 커비 | cubbyhole | 개인·클라우드·프로젝트 칸 나누기 | 칸칸 보관함 | `cubby-app` | **높음** AI 리서치 워크스페이스 "Cubby" |
| 23 | Gieok | 기억 | 기억 | 내 문서를 기억해 줌 | 깜빡이는 점 | `gieok` | 낮음 (발음·철자 모호) |
| 24 | Memoo | 메무 | memo+moo | 귀엽고 짧음 | 젖소 무늬 메모지 | `memoo` | 낮음~중간 (memo류 많음) |
| 25 | Rememo | 리메모 | re+memo | 기억을 되살림 | 되감기 화살표 | `rememo` | 중간 |
| 26 | Pagi | 파기 | page+어미 | 짧고 쉬움 | 둥근 페이지 캐릭터 | `pagi` | 낮음 (한국어 "파기=폐기"는 부정적) |
| 27 | Tucky | 터키 | tuck away | 폰 속에 쏙 넣어 둠 | 이불 속 캐릭터 | `tucky-app` | **중간~높음** macOS AI 노트 앱 Tucky, "터키" 국가명 오독 |
| 28 | Mungchi | 뭉치 | 뭉치 | 프로젝트 문서 묶음 | 솜뭉치 | `mungchi` | 낮음 |
| 29 | Ttokttok | 똑똑 | 똑똑·노크 | 노크하듯 묻고 똑똑하게 답함 | 문 두드리는 손 | `ttokttok` | 중간 (흔한 일상어) |
| 30 | Moaboa | 모아보아 | 모아서 본다 | 문서를 한곳에 모아 봄 | 모으는 손 | `moaboa` | 낮음 |

## 카테고리
- **귀여운 캐릭터형 (10)**: Dotori, Acornote, Hamzzi, Kkachi, Kokkiri, Buong, Pouchy, Pagemole, Daramzzi, Stashy
- **직관적 기능형 (6)**: Mureobwa, Pagepin, Peekapage, Eodiya, Galpi, Jjokji
- **은유형 (7)**: Jumeoni, Dungji, Saseo, Seorap, Bomul, Cubby, Gieok
- **조어형 (7)**: Memoo, Rememo, Pagi, Tucky, Mungchi, Ttokttok, Moaboa

## 조사자 추천 Top 5
1. **Dotori** — "다람쥐가 도토리를 모은다"는 이야기가 프라이버시 3계층(폰에 둠 → 클라우드로 승급 → 같이 봄)과 그대로 맞고, 데모 스토리로 기억에 남음. 단점: 동명 앱 존재 → `Dotori Docs` 또는 #9 Daramzzi
2. **Mureobwa (물어봐)** — 이름이 곧 사용법. 충돌 없음. 단점: 비한국어권 발음·철자 → 영어 부제("Ask your documents")
3. **Jumeoni (주머니)** — "민감한 건 폰에"를 가장 자연스럽게 전달, 한국적 정체성 + 영어로는 "pocket"으로 설명. 로고(주머니에서 세 칸이 열림) 쉬움
4. **Hamzzi (햄찌)** — 볼주머니 = 오프라인 저장의 시각 메타포가 가장 강하고 승급 애니메이션이 데모 장면으로 좋음. 단점: 업무 도구 이미지와 거리
5. **Pagepin** — 영어권 개발자 심사위원에게 가장 직관적(인용 핀 → 페이지 점프). 캐릭터 이름을 서브 마스코트로 조합 가능

## 다음 단계
- 1~2개로 좁힌 뒤 App Store · Play Store · KIPRIS(특허정보검색) · 도메인(.app/.dev) 직접 확인
- Serverpod Cloud ID 사용 가능 여부 확인 (`serverpod cloud project create <id>`)

## 출처
- https://apps.apple.com/app/id6781121640 (Acornote)
- https://apps.apple.com/ug/app/dotori-diary-ai-diary/id6476303528
- https://apps.apple.com/us/app/%EB%8F%84%ED%86%A0%EB%A6%AC-%EB%A6%AC%EB%8D%94%EA%B8%B0/id6737737182
- https://neuronfeed.com/startups/cubby · https://futuretools.io/tools/cubby
- https://www.producthunt.com/posts/1243162 (Tucky)
- https://get.mem.ai
