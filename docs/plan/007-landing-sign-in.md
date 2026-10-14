# 🚪 첫 화면(랜딩 + 로그인) 기획

> **작성일**: 2026-10-15 KST · **최종 수정**: 2026-10-15 KST
> **관련 문서**: [AB Glass Paper 스펙](../design/ab-glass-paper/spec.md) · [디자인 레퍼런스 규칙](../design/references/README.md) · [README](../../README.md) · [데모 대본 (006)](006-demo-script.md)
> **표기**: ✅ 코드·문서로 확인 · ⚠️ 미확인/구현 시 점검 필요
> **범위**: `app/pageblink_flutter/lib/screens/sign_in_screen.dart` 한 화면. 앱 코드는 이 문서에서 수정하지 않는다(설계만).

현재 첫 화면은 `Center(SignInWidget)` 하나뿐이라, 처음 온 사람이 제품 이름도 용도도 알 수 없다. 이 문서는 **제품 소개 + 로그인/가입**을 한 화면에 담는 레이아웃과 영/한 문구를 정한다.

## 1. 목적 · 5초 안에 전달할 것

심사위원·첫 방문자가 스크롤 없이(데스크톱) 또는 한 번의 짧은 스크롤로(모바일) 아래 4가지를 알아야 한다.

| # | 전달할 것 | 담당 요소 |
|---|---|---|
| 1 | 이름은 **⚡ PageBlink** | 워드마크 (Fraunces) |
| 2 | 노트와 PDF에 **질문**하는 서비스 | 헤드라인 + 서브 헤드라인 |
| 3 | 답변의 **⚡ 인용이 출처로 바로 이동**한다 (차별점) | 불릿 2번 + 미리보기 카드 |
| 4 | 로그인/가입은 **여기서 바로** 된다 | 오른쪽(모바일은 아래) 유리 카드 |

원칙: 마케팅 문구는 실제 구현된 기능만 말한다(README "Implemented now" 기준). Cloak은 "coming soon"으로만 표기한다. 가격/플랜 배지 없음, 마이크·이모지 아이콘 없음(⚡ 브랜드 글리프 제외).

## 2. 카피 (EN 기본 / KO는 로케일 ko일 때)

제품명 `⚡ PageBlink`는 번역하지 않는다(상수). 언어는 브라우저/기기 로케일이 `ko`면 한국어, 그 외는 영어.

| 요소 | English (기본) | 한국어 |
|---|---|---|
| 헤드라인 | **Ask your notes. Every answer shows its source.** | **내 노트에 물어보세요. 답마다 출처가 보여요.** |
| 서브 헤드라인 | Keep notes and PDFs in one place, then ask in plain words. PageBlink answers from your own files and links each answer to the exact note or page. | 메모와 PDF를 한곳에 모아 두고 편하게 물어보세요. PageBlink가 내 자료에서 답을 찾고, 근거가 된 메모나 페이지로 바로 데려다 드려요. |
| 불릿 1 · 아이콘 `sticky_note_2_outlined` | **Notes and PDFs together** — Jot down notes or upload PDFs — both can answer your questions. | **메모와 PDF를 한곳에** — 메모를 쓰거나 PDF를 올리면, 둘 다 질문에 답할 수 있어요. |
| 불릿 2 · 아이콘 `bolt` (accent) | **Answers you can check** — Tap ⚡ next to an answer to open the page it came from. | **확인할 수 있는 답** — 답 옆의 ⚡를 누르면 근거가 된 페이지가 열려요. |
| 불릿 3 · 아이콘 `groups_outlined` | **Share with your team** — Put files in a project and teammates can ask them too. | **팀과 함께** — 프로젝트에 넣어 두면 팀원도 같은 자료에 물어볼 수 있어요. |
| 불릿 4 (선택) · 아이콘 `shield_outlined` | **Private by default** — Only you can see your notes unless you share them. Device-only notes are coming soon. | **기본은 나만 보기** — 공유하지 않으면 나만 볼 수 있어요. 기기에만 두는 메모 기능도 곧 나와요. |
| 신뢰 줄 | Built with Flutter + Serverpod · Free models via OpenRouter | Flutter + Serverpod로 제작 · OpenRouter 무료 모델 사용 |
| 로그인 카드 제목 | Sign in or create an account | 로그인 또는 가입 |
| 로그인 카드 부제 | Your notes stay private unless you share a project. | 프로젝트로 공유하지 않는 한 노트는 나만 볼 수 있어요. |
| 푸터 | Built for Build Something Real: The Serverpod Hackathon · GitHub | Build Something Real: The Serverpod Hackathon 출품작 · GitHub |
| 푸터 링크 | `https://github.com/<org>/<repo>` ⚠️ 저장소 주소 확인 후 교체 | 동일 |

- 불릿 4와 신뢰 줄 아래 "무료 모델은 프롬프트를 기록할 수 있어요 / Free models may log prompts" 한 줄(12, `inkMuted`)은 **선택**. README의 데모 주의사항([ADR 014](../adr/014-model-catalog-and-rotation.md))과 맞춘다. 공개 제출 전에 넣을지 결정.
- ⚠️ `EmailSignInWidget` 안의 필드 라벨·버튼·가입 링크·인증 코드 문구는 `serverpod_auth_idp_flutter`가 제공하는 문자열이다. 한국어로 바꿀 수 있는 옵션이 있는지 구현 중 확인하고, 없으면 영어로 남는다(카드 제목/부제만 현지화).
- 미리보기 목업 문구(장식용, 접근성 트리에서 제외):

| 요소 | English | 한국어 |
|---|---|---|
| 노트 제목 / 본문 | Budget memo / Q4 marketing budget: ₩12M. Launch moved to Nov 18. | 예산 메모 / 4분기 마케팅 예산 1,200만 원. 출시는 11/18로 연기. |
| 답변 | The Q4 budget is ₩12M ⚡1 and the launch moved to Nov 18 ⚡2. | 4분기 예산은 1,200만 원이고 ⚡1 출시는 11월 18일로 미뤄졌어요 ⚡2. |
| 출처 칩 | `⚡1 · Budget memo` `⚡2 · Spec.pdf p.4` | `⚡1 · 예산 메모` `⚡2 · Spec.pdf p.4` |

## 3. 레이아웃 (AB Glass Paper 토큰)

배경은 이미 `MaterialApp.builder`의 `PbBackground`(라벤더 → 피치 그라데이션 + 블러 원 2개)가 깐다 ✅. 이 화면은 배경을 다시 그리지 않는다. 글자색은 항상 `ink`/`inkMuted`(그라데이션 위 13:1 이상). 바이올렛(`accent`)은 ⚡, 기본 버튼, 포커스에만 쓰고 그라데이션 면은 화면당 1개 이하(여기서는 로그인 기본 버튼). 그래서 미리보기에는 질문 말풍선(그라데이션)을 넣지 않는다.

### 3.1 데스크톱 ≥ 1024 (분할)

```
┌──────────────────────────────────────────────────────────────┐
│ 바깥 패딩 32 · 최대 폭 1120 중앙 · 세로 중앙 정렬              │
│  ┌─ 왼쪽 히어로 (Expanded) ───────┐ gap 48 ┌─ 로그인 카드 420 ┐ │
│  │ ⚡ PageBlink (Fraunces 28/600) │        │ GlassPanel r24     │ │
│  │ 헤드라인 Fraunces 52/600/1.15  │        │ 패딩 32            │ │
│  │ 서브 Inter 18/1.5 inkMuted     │        │ 제목 Fraunces 24   │ │
│  │ 불릿 4행 (간격 16)             │        │ 부제 Inter 14      │ │
│  │ 미리보기 카드 (폭 ≤ 460)       │        │ SignInWidget       │ │
│  │ 신뢰 줄                        │        └────────────────────┘ │
│  └────────────────────────────────┘                              │
│  푸터 (하단 중앙, Inter 12 inkMuted)                              │
└──────────────────────────────────────────────────────────────┘
```

- 히어로 폭 = 남는 공간, 텍스트 최대 폭 560. 헤드라인 최대 2줄(KO는 **44**로 줄여 2줄 유지), 서브 최대 폭 520.
- 불릿 행: 아이콘 타일 40×40(radius 12, `glassStrong` + 1px `glassBorder`, 아이콘 22 `ink`; 불릿 2의 `bolt`만 `accent`) · 오른쪽에 제목 Inter 15/600 `ink` + 설명 Inter 14/1.45 `inkMuted`. 행 간격 16.
- 로그인 카드: `GlassPanel(radius: 24, strong: true)`, 폭 `min(420, 가용폭)`, 세로로는 히어로와 중앙 맞춤. 높이가 화면보다 크면(가입 폼 펼침, 짧은 창) 전체를 `SingleChildScrollView`로 감싸 카드가 잘리지 않게 한다.
- 푸터는 본문 아래 24 간격, 화면이 짧으면 본문과 함께 스크롤.

### 3.2 태블릿 600–1024

- 같은 좌우 분할. 바깥 패딩 24, gap 32, 카드 폭 **380**, 헤드라인 **40**(KO 36), 서브 16.
- 불릿은 3개만(4번째 숨김), 설명은 유지. 미리보기 카드는 화면 높이 ≥ 720일 때만 표시(폭 ≤ 400), 아니면 생략.

### 3.3 모바일 < 600 (세로 스택)

```
패딩 좌우 16 · 상단 24 (SafeArea)
⚡ PageBlink            Fraunces 24/600
헤드라인               Fraunces 32/600/1.15 (KO 30), 최대 3줄
서브                   Inter 15/1.5 inkMuted
불릿 3행 (컴팩트)      아이콘 20 + 제목만 Inter 14/600, 행 높이 36, 설명·4번째 숨김
─ 간격 24 ─
[ 로그인 카드 ]        GlassPanel r24, 폭 전체, 패딩 20
신뢰 줄 / 푸터         카드 아래 (Inter 12 inkMuted, 가운데)
```

- 미리보기 카드는 숨긴다(로그인 도달성 우선). 히어로 총 높이 약 340–380이라 일반 폰(세로 ≥ 700)에서 카드 제목이 첫 화면 아래쪽에 걸쳐 보이고 스크롤 한 번이면 폼 전체가 보인다.
- 키보드가 올라오면 `SingleChildScrollView` + `resizeToAvoidBottomInset`로 포커스된 필드가 보이게 한다.

### 3.4 미리보기 카드 (장식 목업, 데스크톱 · 큰 태블릿)

- 컨테이너 없이 두 요소를 살짝 겹쳐 쌓는다(`Stack`, 좌측 정렬). 1) **노트 카드**: `pb.notes[0]`(버터), radius 16, 패딩 16, 1px `hairline`(또는 noteBorder), 그림자 `ink` 6%/blur 8/y 2, 폭 220, 제목 Fraunces 18/600, 본문 Inter 14 3줄, 약간 기울임 없음. 2) **답변 말풍선**: 노트 오른쪽 아래로 겹침(offset 약 (120, 64)), `pb.glassStrong` + `glassBorder`, radius 18(좌상단 6), 폭 ≤ 300, 패딩 14, 본문 Inter 14/1.5.
- 인라인 `⚡1` pill: `accentContainer` 배경, `Icons.bolt` 12 `accent` + 숫자 12/600 `onAccentContainer`, 높이 18. 답변 아래 칩 2개: 높이 28, 1px `accent`, 글자 `onAccentContainer` 12/500.
- 노트 카드와 답변 말풍선 사이 `⚡1` 칩에서 노트로 향하는 **0.6s 링 펄스 1회**(`accent` 40%, 로드 시 한 번만, `MediaQuery.disableAnimations`면 생략). 반복 애니메이션 없음.
- BackdropFilter는 로그인 카드(`GlassPanel`)에만. 노트 카드는 단색, 말풍선은 `glassStrong` 색만 사용(블러 없음).

## 4. Flutter 구현 노트

**제약**: 새 패키지 없음(`google_fonts`, `flutter_localizations` 기존 ✅). 토큰은 `Pb`(`context.pb`), 표면은 `GlassPanel`, 배경은 기존 `PbBackground`. ⚠️ 이 문서 작성 시점에 `lib/app/l10n.dart`는 저장소에 없다(`lib/app/`에는 `local_pdfs.dart`, `theme.dart`뿐). 다른 작업에서 추가될 예정이면 그 `L` 클래스에 아래 getter를 더하고, 없으면 `extension LContext on BuildContext { L get l => ... }`를 먼저 만든다.

### 4.1 로케일 (main.dart 한 곳)

`MaterialApp`에 `supportedLocales: [Locale('en'), Locale('ko')]`와 `GlobalMaterial/Widgets/CupertinoLocalizations.delegate`를 지정한다. 지원 목록의 **첫 항목이 en**이므로 ko 외 모든 로케일은 영어로 폴백(기본 영어). 웹은 브라우저 언어, 앱은 기기 언어를 Flutter가 `ko`로 넘긴다. `L`은 `Localizations.localeOf(context).languageCode == 'ko'`로 분기.

### 4.2 위젯 트리

```
SignInScreen (State: 기존 authInfoListenable 로직 유지; 로그인 시 widget.child)
└ Scaffold(backgroundColor: transparent)   // PbBackground가 이미 뒤에 있음
  └ SafeArea
    └ LayoutBuilder (w = maxWidth)
      └ SingleChildScrollView
        └ ConstrainedBox(minHeight: constraints.maxHeight)
          └ Center → ConstrainedBox(maxWidth 1120) → Padding(w<600 ? 16 : w<1024 ? 24 : 32)
            └ Column
              ├ (w ≥ 600) Row(crossAxisAlignment: center)
              │    ├ Expanded(_Hero(compact:false, showPreview: ...))
              │    ├ SizedBox(width: w ≥ 1024 ? 48 : 32)
              │    └ SizedBox(width: w ≥ 1024 ? 420 : 380, child: _SignInCard())
              ├ (w < 600) Column[_Hero(compact:true), SizedBox(24), _SignInCard()]
              └ _Footer()  // 신뢰 줄(모바일은 여기) + 푸터
```

- `_Hero`: `Semantics(header: true)` 헤드라인, 워드마크 `Text('⚡ PageBlink', style: GoogleFonts.fraunces(fontSize: 28, fontWeight: w600, fontFamilyFallback: ['Noto Serif KR']))`. 헤드라인/서브/불릿 텍스트는 `Theme.textTheme`에서 `copyWith(fontSize: ...)`; 한글 폴백은 기존 테마 설정을 따른다 ✅(`theme.dart`).
- `_Bullet(icon, title, body, compact)`, `_PreviewCard()`(`ExcludeSemantics`), `_Footer()`는 같은 파일의 private 위젯. 파일이 300줄을 넘으면 `lib/screens/landing/`으로 분리.
- `_SignInCard`: `GlassPanel(radius: 24, strong: true, child: Padding(EdgeInsets.all(w<600 ? 20 : 32), child: Column[Text(l.signInTitle, Fraunces 24/600), SizedBox(4), Text(l.signInSubtitle, Inter 14 inkMuted), SizedBox(20), Material(type: transparency, child: SignInWidget(client: client, emailSignInWidget: EmailSignInWidget(client: client, passwordRequirements: pageBlinkPasswordRequirements), onAuthenticated: ..., onError: ...))]))`. 기존 콜백·`pageBlinkPasswordRequirements` 유지.
- ⚠️ `SignInWidget`이 자체 최대 폭/패딩을 갖는지 확인하고, 카드 안쪽 폭(데스크톱 356)에서 넘치면 `SizedBox(width: double.infinity)`로 감싸거나 `FittedBox`가 아니라 위젯 옵션으로 조정. 제목이 위젯 안에 이미 있으면 중복되므로 하나만 둔다.
- 하드코딩 영문 문구(`'User authenticated.'`, `'Authentication failed: $error'`, 비밀번호 규칙 `description`)도 `l`로 이동한다(아래 표). `pageBlinkPasswordRequirements`는 `final` 전역이라 `BuildContext`가 없다 → 함수 `pageBlinkPasswordRequirementsFor(L l)`로 바꾸고, 나머지 `PasswordRequirement.minLength` 등 기본 설명은 위젯 기본 영문 유지(⚠️).
- `url_launcher`는 pubspec에 없다 ✅(2026-10-15 확인). 새 패키지 금지이므로 푸터의 GitHub는 우선 텍스트로만 두고, 링크 동작은 패키지 추가 승인 후 붙인다.
- 다크 모드: 모든 색이 `Pb`에서 오므로 자동 대응. 하드코딩 색 금지.

### 4.3 추가할 `L` getter (EN / KO)

| getter | EN | KO |
|---|---|---|
| `landingHeadline` | Ask your notes. Every answer shows its source. | 내 노트에 물어보세요. 답마다 출처가 보여요. |
| `landingSub` | Keep notes and PDFs in one place, then ask in plain words. PageBlink answers from your own files and links each answer to the exact note or page. | 메모와 PDF를 한곳에 모아 두고 편하게 물어보세요. PageBlink가 내 자료에서 답을 찾고, 근거가 된 메모나 페이지로 바로 데려다 드려요. |
| `landingFeatureBoardTitle` | Notes and PDFs together | 메모와 PDF를 한곳에 |
| `landingFeatureBoardBody` | Jot down notes or upload PDFs — both can answer your questions. | 메모를 쓰거나 PDF를 올리면, 둘 다 질문에 답할 수 있어요. |
| `landingFeatureCiteTitle` | Answers you can check | 확인할 수 있는 답 |
| `landingFeatureCiteBody` | Tap ⚡ next to an answer to open the page it came from. | 답 옆의 ⚡를 누르면 근거가 된 페이지가 열려요. |
| `landingFeatureShareTitle` | Share with your team | 팀과 함께 |
| `landingFeatureShareBody` | Put files in a project and teammates can ask them too. | 프로젝트에 넣어 두면 팀원도 같은 자료에 물어볼 수 있어요. |
| `landingFeaturePrivacyTitle` | Private by default | 기본은 나만 보기 |
| `landingFeaturePrivacyBody` | Only you can see your notes unless you share them. Device-only notes are coming soon. | 공유하지 않으면 나만 볼 수 있어요. 기기에만 두는 메모 기능도 곧 나와요. |
| `landingTrust` | Built with Flutter + Serverpod · Free models via OpenRouter | Flutter + Serverpod로 제작 · OpenRouter 무료 모델 사용 |
| `landingFreeModelNote` (선택) | Free models may log prompts. | 무료 모델은 프롬프트를 기록할 수 있어요. |
| `signInTitle` | Sign in or create an account | 로그인 또는 가입 |
| `signInSubtitle` | Your notes stay private unless you share a project. | 프로젝트로 공유하지 않는 한 노트는 나만 볼 수 있어요. |
| `landingFooterCredit` | Built for Build Something Real: The Serverpod Hackathon | Build Something Real: The Serverpod Hackathon 출품작 |
| `landingFooterGitHub` | GitHub | GitHub |
| `landingPreviewNoteTitle` | Budget memo | 예산 메모 |
| `landingPreviewNoteBody` | Q4 marketing budget: ₩12M. Launch moved to Nov 18. | 4분기 마케팅 예산 1,200만 원. 출시는 11/18로 연기. |
| `landingPreviewAnswer` | The Q4 budget is ₩12M ⚡1 and the launch moved to Nov 18 ⚡2. | 4분기 예산은 1,200만 원이고 ⚡1 출시는 11월 18일로 미뤄졌어요 ⚡2. |
| `landingPreviewChipNote` | Budget memo | 예산 메모 |
| `signInSuccess` | Signed in. | 로그인되었습니다. |
| `signInFailed(Object e)` | Sign-in failed: $e | 로그인에 실패했습니다: $e |
| `passwordNeedsUpperOrSpecial` | At least 1 uppercase letter or special character | 대문자 또는 특수문자를 1개 이상 포함 |

미리보기의 `Spec.pdf p.4` 칩은 고유명사라 번역하지 않고 위젯에 상수로 둔다. `⚡n` pill은 `Icons.bolt` + 숫자 위젯으로 그리고 문자열 안의 `⚡`는 텍스트 글리프로 표시된다(폰트 폴백 확인 ⚠️: 이모지로 렌더되면 `Icons.bolt` `WidgetSpan`으로 대체).

## 5. 수용 기준

- [ ] 데스크톱(1280×800)에서 스크롤 없이 워드마크 · 헤드라인 · 서브 · 불릿 3개 이상 · 로그인 카드가 모두 보이고, 카드는 오른쪽에 폭 420 이하다.
- [ ] 모바일(390×844)에서 히어로(워드마크 · 헤드라인 · 서브 · 컴팩트 불릿 3행) 바로 아래에 로그인 카드가 이어지고, 가로 오버플로가 없으며, 이메일 로그인/가입을 끝까지 수행할 수 있다(키보드가 올라와도 필드가 가려지지 않음).
- [ ] 브라우저/기기 로케일이 `ko`이면 모든 새 문구(카드 제목, 스낵바 포함)가 한국어, 그 외 로케일은 영어이며, 영어 폴백이 기본이다.
- [ ] 라이트/다크 모두에서 `Pb` 토큰만 사용하고(하드코딩 색 없음) 본문 대비가 4.5:1 이상이며, 바이올렛은 ⚡ · 기본 버튼 · 포커스에만 쓰이고 그라데이션 면은 1개다.
- [ ] 기존 로그인 동작(이메일 가입/로그인, `authInfoListenable` 구독, 로그인 시 `HomeShell` 전환, 비밀번호 규칙)이 그대로 동작한다.
- [ ] 미리보기 카드는 `ExcludeSemantics`이고 헤드라인은 `Semantics(header: true)`이며, 모든 터치 타깃은 48dp 이상이다. 기능 설명에 구현되지 않은 기능이 없다(Cloak은 "coming soon").
- [ ] `flutter analyze`가 새 경고 없이 통과하고 새 패키지가 추가되지 않았다.
