# 035 · 브랜드 마크 클릭 이펙트 레퍼런스 (PageBlink 로고 클릭 마이크로 인터랙션)

| 항목 | 값 |
|---|---|
| 조사일 | 2026-10-16 (KST, 문서화 17:29. 조사 수행 시각은 기록 없음 ⚠️) |
| 담당 | 서브에이전트 (웹 조사 + 저장소 읽기 전용. 저장소 수정 없음) |
| 질문 | 브랜드 마크(별 + `PageBlink`)를 눌렀을 때 재생할 마이크로 인터랙션을 "따라 하기" 좋게 보여 주는 레퍼런스 링크와 효과 유형·전문가 규칙·Flutter 구현 옵션은 무엇인가 |
| 결론 한 줄 | 가장 그대로 따라 하기 좋은 레퍼런스는 Josh Comeau 애니메이티드 스파클, Flutter 쿡북 쉬머, flutter_animate ShimmerEffect, Discord 로고 다회 클릭, Google I/O 2013 로고 5건. 구현은 의존성 없는 `AnimationController` + `Transform`/`CustomPainter`가 1순위 |
| 반영 | 디자인 기획 [`design/logo-click-effect/spec.md`](../design/logo-click-effect/spec.md) (제안 — 소유자 선택 대기) · 모션 규칙 기준 [`design/interaction-states/spec.md`](../design/interaction-states/spec.md) · [`design/ui-polish/spec.md`](../design/ui-polish/spec.md) |

> 상태: 조사 스냅샷. 효과 콘셉트 5안과 추천(A "Blink" + 5연타 "Page burst")은 위 spec에서 다룬다. 이 문서의 "추천 컨셉 5"(§5)는 조사 단계의 아이디어 목록이고, spec의 콘셉트 A~E와 번호·내용이 다르다.
> 검증 상태 표기: **열람** = 페이지를 직접 열어 확인함 · **검색결과** = 검색 결과에서만 봄, 내용 미확인 · ⚠️ 미확인 또는 불확실. 저장소는 읽기만 했고 아무것도 고치지 않았다.
> 본문 표기: 아래 본문의 `#N`은 §1 레퍼런스 표의 번호, "3절"·"§5" 등은 이 문서의 상세 절 번호다.

## 핵심 결론

가장 그대로 따라 하기 좋은 레퍼런스 5개입니다. 수치는 모두 아래 출처에서 확인한 값입니다.

1. **Josh Comeau 애니메이티드 스파클** (열람) — https://www.joshwcomeau.com/react/animated-sparkles-in-react/
   - 스파클은 곡선형 4점 별 SVG이고, 최종판 viewBox는 `0 0 68 68`, 기본색은 `#FFC700`입니다.
   - 래퍼는 scale 0→1→0을 700ms(`forwards`)로 돌립니다. SVG는 0deg→180deg를 `linear` 1000ms로 회전합니다.
   - 같은 속성을 건드리는 키프레임 두 개는 한 요소에 못 넣으므로 요소를 둘로 나눕니다.
   - 생성 간격은 50~450ms 사이 무작위입니다. 크기는 첫 버전에서 10~20이고, 위치는 top/left 백분율 무작위입니다.
   - 750ms가 지난 스파클은 제거합니다. 글에서 스스로, 1000ms 회전이 750ms 수명보다 길어서 회전이 끝나기 전에 제거된다고 지적합니다.
   - `pointer-events: none`으로 클릭을 막지 않습니다.
   - 모션 감소 시에는 생성을 멈추고 정적 스파클 3~4개를 렌더합니다. CSS 애니메이션은 `@media (prefers-reduced-motion: no-preference)` 안에 둡니다.
2. **Flutter 쿡북 쉬머** (열람) — https://docs.flutter.dev/cookbook/effects/shimmer-loading
   - `ShaderMask`에 `blendMode: BlendMode.srcATop`을 주면 자식이 이미 칠한 영역에만 셰이더 색이 입혀집니다.
   - 움직임은 `LinearGradient`의 `transform`(GradientTransform)으로 냅니다. `Matrix4.translationValues(bounds.width * slidePercent, 0.0, 0.0)`이고, `slidePercent`는 컨트롤러 값입니다.
   - 컨트롤러는 `AnimationController.unbounded(vsync: this)..repeat(min: -0.5, max: 1.5, period: const Duration(milliseconds: 1000))`입니다.
   - 그라디언트가 움직여도 자식이 스스로 다시 그리지 않으니, 컨트롤러를 `Listenable`로 노출해 구독하고 변경 때 `setState`를 호출해야 합니다.
3. **flutter_animate ShimmerEffect** (열람) — https://pub.dev/documentation/flutter_animate/latest/flutter_animate/ShimmerEffect-class.html
   - 생성자 파라미터는 `delay`, `duration`, `curve`, `color`, `colors`, `stops`, `size`, `angle`, `blendMode`, `padding`입니다.
   - 기본 `blendMode`는 `BlendMode.srcATop`, 기본 `padding`은 `0.5`(ShaderMask 안티에일리어싱 문제 방지), 기본 색은 50% 흰색 그라디언트입니다.
   - `colors`를 안 주면 `[transparent, color, transparent]` 형태로 만듭니다.
   - `duration`과 `curve`는 생략하면 앞 효과를 이어받거나 `Animate.defaultDuration`, `Animate.defaultCurve`를 씁니다.
   - 수동 실행은 패키지 페이지(https://pub.dev/packages/flutter_animate, 열람)에 따라 외부 `controller`를 주고 `autoPlay`를 false로 두거나, `target`, `value`로 구동합니다.
   - ⚠️ 문서에 "모바일 웹 HTML 렌더러에서 문제 가능" 문구가 있습니다.
4. **Discord 로고 다회 클릭** (열람) — https://beebom.com/cool-discord-easter-eggs/amp/
   - 좌상단 Discord 로고를 짧은 시간에 **16번** 클릭하면 "Discordo" 시작음이 켜집니다. 다시 16번 클릭하면 꺼지고 확인음이 납니다.
   - 데스크톱과 웹 앱에서만 작동합니다.
   - ⚠️ Discord 고객센터 글(https://support.discord.com/hc/ko/community/posts/360029419792-Add-a-startup-sound-to-Discord, 검색결과)에는 "3번 클릭"이라는 다른 언급이 있어 횟수는 출처마다 다릅니다.
5. **Google I/O 2013 "Experiment" 로고** (열람) — https://web.dev/google-io-2013
   - 도형 윤곽의 점들이 각각 입자입니다. 점마다 무작위 가속도와 반발값(약 1.05~1.15)을 가집니다.
   - 탭 지점에서 바깥으로 밀려났다가, 프레임마다 감속되며 평형으로 돌아옵니다.
   - 전체화면 canvas를 쓰고, 픽셀 읽기(`getImageData`)는 1024x768에서 약 310만 항목을 초당 60번 갱신해 비쌉니다.
   - 지속시간과 easing 수치는 페이지에 없습니다.

## 상세

### 0. 현재 브랜드 마크 (저장소 확인)

- 마크는 `Icon(AppIcons.brand)`와 `Text('PageBlink')`를 묶은 형태입니다. `AppIcons.brand`는 `LucideIcons.sparkle`(4점 별)이고 색은 `pb.accent`입니다.
- 위치는 모바일 AppBar `main.dart:286-299`(별 24, 글자 22)와 데스크톱 사이드바 `main.dart:574-585`(별 26, 글자 24)입니다.
- 의존성에 `flutter_animate`, `rive`, `lottie`, `confetti`는 없습니다.
- 모션 감소는 이미 `MediaQuery.disableAnimationsOf`로 처리합니다(`pb_interactive.dart`의 `pbFast`, `ask_screen.dart`).

### 1. 레퍼런스 표 (19건)

| # | 이름 | URL | 상태 | 효과 | 기법 | 작동 이유 | 우리 앱 적합도 | 출처 품질 |
|---|---|---|---|---|---|---|---|---|
| 1 | Google I/O 2013 "Experiment" 로고 탭 | https://web.dev/google-io-2013 | 열람 | 로고 'I', 'O' 도형을 탭하면 윤곽 점들이 탭 지점에서 바깥으로 튀었다가 제자리로 돌아옴 | 전체화면 canvas와 입자 물리. 점마다 가속도와 반발값(약 1.05~1.15)이 무작위 | 점마다 값이 달라서 한꺼번에 움직이지 않고 유기적임. 목표를 지나쳤다가 서서히 평형으로 돌아옴 | 중. 구조(탭 지점에서 퍼졌다가 복귀)는 좋지만 캔버스 입자는 "차분한" 톤에 과함 | 상. Google 공식 케이스 스터디. 지속시간과 easing 수치는 없음 |
| 2 | Google iOS 앱 로고 글자 플릭 | https://9to5google.com/guides/google-for-iphone/ | 열람 | 로고 글자를 손가락으로 튕기면 흩어지고, 기기를 기울이면 글자가 쏠림 | ⚠️ 기법 미공개. 기울임은 센서 연동 | 로고 자체가 장난감이 되는 "발견의 즐거움" | 낮음. 글자 물리는 문서 앱의 차분함과 안 맞음 | 중. 뉴스 가이드이고 구현 설명 없음 |
| 3 | Google Doodle 첫 인터랙티브(팩맨, 2010) | https://en.wikipedia.org/wiki/Google_Doodle | 검색결과 | 로고가 미로가 되어 실제로 플레이됨 | HTML/JS | 로고를 "장소"로 바꾸는 발상의 원형 | 낮음. 규모가 과함. 사례로만 | 중상. 위키백과. 본문은 열지 않음 |
| 4 | Discord 로고 16회 클릭(Discordo) | https://beebom.com/cool-discord-easter-eggs/amp/ | 열람 | 좌상단 로고를 짧은 시간에 16번 클릭하면 시작음이 켜지고 확인음이 남. 다시 16번이면 꺼짐 | 클릭 카운터 | 많이 눌러야 보상이 나오는 "에스컬레이션" | 높음(개념). 소리 대신 시각 보상으로 응용 가능 | 중하. 블로그. ⚠️ Discord 고객센터 글(https://support.discord.com/hc/ko/community/posts/360029419792-Add-a-startup-sound-to-Discord, 검색결과)에는 "3번 클릭"이라는 다른 언급이 있어 횟수는 불확실 |
| 5 | Vercel 로고 호버 할로윈 이스터에그 | https://designspells.com/spells/halloween-easter-egg-when-hovering-on-vercels-logo | 열람 | 로고 호버 시 시즌 한정 애니메이션 | ⚠️ 페이지에 기법 정보 없음 | 시즌성 보상 | 중. "시즌 한정 변형"이라는 아이디어만 참고 | 중. 큐레이션 사이트이나 효과 설명이 없음 |
| 6 | Raycast "DVD 로고처럼 튕김" 커맨드 | https://designspells.com/spells/raycast-has-a-command-that-makes-it-bounce-around-like-the-dvd-logo | 열람 | 창이 DVD 로고처럼 화면을 튕겨 다님 | ⚠️ 설명 없음 | 개발자 유머 | 낮음. 로고 클릭이 아니라 커맨드 | 중하. 세부 정보가 없음 |
| 7 | GitHub Corners 옥토캣 손 흔들기 | https://tholman.com/post/github-corners | 열람 | 호버 시 옥토캣 팔이 흔들림 | SVG에서 팔을 분리하고 CSS `@keyframes` `octocat-wave`로 -25°↔10°를 반복(0/20/40/60/80/100%) | 한 부위만 움직여 캐릭터가 살아있게 느껴짐 | 중. 별 한 점만 움직이는 부분 모션으로 응용 가능 | 중. 개인 개발자 글. ⚠️ 지속시간과 easing은 확인 못함 |
| 8 | Rive "Logo interaction" (livechatai.com 로고) | https://rive.app/community/5132-10323-logo-interaction/ | 열람 | 로고가 커서 위치에 반응 | Rive 상태 머신. CC BY 4.0, Remix 가능 | 상태 머신으로 입력과 모션을 분리 | 중. 무료지만 Rive 에디터 작업이 필요 | 중상. 커뮤니티 파일. 상세 동작 설명은 페이지에 없음 |
| 9 | Rive "Animated logo"(emanuelcabezas) | https://www.rive.app/marketplace/21530-40624-animated-logo | 열람 | 마우스 따라 의사 3D 기울임, 눈이 커서를 따라감, 클릭 시 표정 전환 | Rive 상태 머신 | 눈과 표정으로 캐릭터성 부여. "Blink"와 직결 | 중상. 눈 깜빡임 컨셉의 발상 참고 | 중상. 2025-07 게시, CC BY. 우리 로고와는 별개 작품 |
| 10 | Rive 블로그 "12 best community designs of 2023" | https://rive.app/blog/12-best-rive-community-designs-of-2023 | 열람 | 위 #8 포함 커뮤니티 작품 선정 | 상태 머신, 리스너 | 상태 머신 중심의 인터랙션 사례 모음 | 참고용 | 중. 벤더 공식이라 홍보 성격 |
| 11 | Josh Comeau "Animated Sparkles" | https://www.joshwcomeau.com/react/animated-sparkles-in-react/ | 열람 | 텍스트 주변에 4점 별 반짝임 | SVG 별(viewBox 68). 래퍼는 scale 0→1→0(700ms), SVG는 0→180° 회전(1000ms, linear). 생성 간격 50~450ms 무작위, 750ms 지나면 제거 | 두 애니메이션을 겹쳐 쓰고 생성 간격을 불규칙하게 해서 "자연스럽게 흩뿌려진" 느낌. `pointer-events:none`으로 클릭을 막지 않음. reduced-motion이면 정적 별 3~4개로 대체 | 상. 이 앱이 이미 4점 별을 씀 | 상. 유명한 프런트엔드 교육자. 2020-05 글 |
| 12 | Magic UI "Sparkles Text" | https://magicui.design/docs/components/sparkles-text | 열람 | 텍스트 주변 지속 반짝임 | React 컴포넌트. `sparklesCount` 기본 10, 색 2종(`#A07CFE`, `#FE8FB5`) | 즉시 가져다 쓰는 형태 | 중. 지속 반복은 차분한 앱에는 과함. 클릭 1회 버스트로 줄여야 함 | 중. 컴포넌트 라이브러리. ⚠️ 내부 구현과 시간값은 페이지에 없음 |
| 13 | Amit Merchant "CSS shine on hover" | https://www.amitmerchant.com/shine-animation-on-hover-using-css | 열람 | 호버 시 광택 띠가 한 번 훑고 지나감 | `mask-image: linear-gradient(45deg,#000 25%,rgba(0,0,0,.2) 50%,#000 75%)`, mask-size 800%, 위치 0→120%, 2s ease | 반투명 띠를 큰 마스크로 한 번 이동시키는 단순 구조 | 상. 글자와 별 위를 훑는 샤인 스윕의 기본형. 2초는 길어서 600~900ms로 줄이길 권장 | 중. 개인 블로그. 2023-01 글 |
| 14 | Flutter 쿡북 "Shimmer loading" | https://docs.flutter.dev/cookbook/effects/shimmer-loading | 열람 | 자식 위로 빛 띠가 지나감 | `ShaderMask` + `BlendMode.srcATop` + `LinearGradient`의 `GradientTransform`으로 슬라이드. 컨트롤러는 1000ms 주기, 범위 -0.5~1.5 | 자식이 칠한 영역에만 셰이더가 적용되어 윤곽 밖으로 번지지 않음 | 상. 샤인 스윕을 별 아이콘과 글자에 그대로 적용 가능 | 상. Flutter 공식 |
| 15 | flutter_animate `ShimmerEffect` | https://pub.dev/documentation/flutter_animate/latest/flutter_animate/ShimmerEffect-class.html | 열람 | Flutter용 쉬머 효과 | 각도, 색, stops, `blendMode` 조절. 기본 `srcATop`, 기본색 50% 흰색 | 선언형으로 빠르게 구성 | 중. 새 의존성이 필요. 같은 일을 직접 짤 수도 있음 | 상. gskinner 발행(4.25k likes). ⚠️ "모바일 웹의 HTML 렌더러에서 문제 가능" 문구가 있으나, HTML 렌더러가 이미 제거됐다는 근거는 제3자 글뿐이라 불확실 |
| 16 | "Flutter Animated Logo with CustomPainter" (Dominik Roszkowski) | https://dev.to/orestesgaolin/flutter-animated-logo-with-custompainter-34en | 열람 | 로고 보를 CustomPainter로 그리고 회전, 클립 reveal | 하나의 `AnimationController`를 `Interval`로 쪼개 각 속성에 Tween 부여. `easeOutCubic`(reveal), `easeInOutQuad`(회전) | 원본 GIF를 프레임 단위로 분해해서 구간별 곡선을 줌 | 상(방식). 순수 Dart라 의존성이 없음 | 중. 2020-05 개인 글. ⚠️ 지속시간은 초 단위로 안 나옴. `shouldRepaint`가 항상 true라 최적화 여지 있음 |
| 17 | Framer "Interactive Logo" | https://www.framer.com/marketplace/components/interactive-logo/ | 열람 | SVG를 입자로 재구성해 숨쉬기와 커서 추적 | HTML5 canvas 입자 | 정지 로고가 아니라 "살아 있는" 로고 | 낮음. 어두운 입자 배경 톤이라 종이/잉크와 안 맞음 | 중하. 마켓플레이스 상품 설명뿐 |
| 18 | Duolingo 캐릭터 애니메이션 블로그 | https://blog.duolingo.com/world-character-visemes | 열람 | 캐릭터 상태를 Rive 상태 머신으로 제어 | Rive 상태 머신. 런타임 파일 하나로 전달하고 Android, iOS, Web을 모두 지원 | 상태를 겹쳐 쓸 수 있고 애니메이터와 엔지니어의 핸드오프가 깔끔함 | 참고용. 클릭 연출 자체가 아니라 상태 머신 도입 근거 | 상. 공식 블로그. ⚠️ 올빼미 클릭 반응은 이 글에 없음 |
| 19 | Android 빌드번호 연타 이스터에그 | https://www.droid-life.com/2015/10/05/video-googlers-post-a-brief-history-of-android-easter-eggs/ | 검색결과 | 설정에서 버전을 연타하면 숨은 그림이 나옴 | 탭 카운터 | 숨김과 발견 사이의 균형 | 개념만 | 중. 검색결과 스니펫만 봄. ⚠️ 정확한 연타 횟수는 출처마다 달라 불확실 |

### 2. 효과 유형 카탈로그

시간과 easing은 아래 3절의 NN/g, Flutter `Durations`, allsvgicons 등 열람한 출처와, Josh Comeau의 700ms/1000ms 같은 열람 수치를 근거로 한 **제안 범위**입니다. 출처가 직접 말한 값이 아닙니다.

| 유형 | 설명 | 권장 지속 / easing | 근거 |
|---|---|---|---|
| 샤인 스윕 / 스펙큘러 글린트 | 대각선 흰 띠가 한 번 훑고 지나감 | 500~900ms, ease-out 계열 | #13, #14(공식 쿡북의 1000ms 주기는 로딩용 반복 값) |
| 글로우 펄스 | 별 뒤 후광이 부풀었다 사라짐 | 600~1000ms, 투명도 0→0.6→0 | ⚠️ 일반 지침. 직접 출처는 없음 |
| 오버슈트 스핀 | 별이 90~180° 회전하며 목표를 살짝 넘었다 복귀 | 400~700ms, back/elastic 계열 | #11(180° 회전, 1000ms, linear). 오버슈트 curve 예는 allsvgicons(https://www.allsvgicons.com/blog/micro-interactions-svg-hover-click/, 열람) `cubic-bezier(0.175,0.885,0.32,1.275)` |
| 스쿼시 앤 스트레치 | 눌렸다가 늘어나며 튀어오름 | 200~350ms | ⚠️ 검색결과의 커뮤니티 스킬 가이드뿐(비권위). 부피 보존 원칙(눌리면 넓어짐) |
| 반짝 입자 / 색종이 | 작은 별 4~8개가 퍼졌다 사라짐 | 700~1000ms 수명 | #11(생성 간격 50~450ms, 수명 750ms) |
| 잉크 번짐 / 종이 접힘 / 페이지 넘김 | 종이와 잉크 은유 | 600~1000ms | ⚠️ 잉크 번짐은 SVG feTurbulence 검색결과(CSS-Tricks 등)를 봤으나 Flutter 적용은 미검증 |
| 눈 깜빡임 | 별 또는 글자 'i'/'B' 사이가 깜빡임 | 120~200ms 닫힘, 총 300ms 안팎 | #9(눈 추적과 표정 전환은 확인). ⚠️ 깜빡임 시간 수치는 직접 출처 없음 |
| 타자기 글자 웨이브 | 글자가 하나씩 튀어오름(stagger) | 글자당 40~60ms 시차, 합계 500~800ms | ⚠️ Codrops 글자 stagger를 검색결과에서 봄. 수치는 제 제안 |
| 그라데이션 무지개 스윕 | 글자에 색 띠가 지나감 | 700~1200ms | ⚠️ Mintlify/Framer 쉬머 텍스트를 검색결과에서 봄 |
| 마그네틱 / 탄성 바운스 | 누르면 따라 눌렸다가 스프링 복귀 | 250~450ms | ⚠️ 일반 지침 |
| 글리치 | 색 분리와 위치 어긋남 | 150~300ms | 문서 앱 톤에 부적합 |
| 3D 틸트 / 플립 | 카드 뒤집힘 | 350~600ms | #9(의사 3D 기울임) |
| 오빗 별 | 작은 별이 마크 주위를 한 바퀴 | 700~1000ms | ⚠️ 일반 지침 |

### 3. 전문가 규칙

#### 지속시간과 easing

- **NN/g** (https://www.nngroup.com/articles/animation-duration/, 열람)는 단순 피드백을 약 100ms로 봅니다. 큰 화면 변화는 200~300ms, 대부분은 100~500ms, 500ms부터는 "질질 끄는" 느낌이라고 했습니다. 기본은 ease-out이고 linear는 피하라고 했습니다. 등장이 퇴장보다 약간 길어야 한다는 말도 있습니다.
- **Flutter `Durations`** (https://api.flutter.dev/flutter/material/Durations-class.html, 열람)는 short1 50ms부터 extralong4 1000ms까지 16단계를 제공합니다. Material 곡선은 `Easing` (https://api.flutter.dev/flutter/material/Easing-class.html, 열람)에 있습니다.
- 요청서의 300~1200ms는 NN/g의 100~500ms보다 깁니다. 로고 마크는 보상을 주는 일회성 효과라 길어도 되지만, 입력을 가로막지 않는다는 조건이 필수입니다. 이 구분은 제 판단입니다.
- 오버슈트 곡선은 allsvgicons(열람)가 `cubic-bezier(0.175, 0.885, 0.32, 1.275)`를 "spring-like"로 소개합니다. 이 글은 100~300ms를 권합니다.
- ⚠️ Emil Kowalski의 "300ms 이내, ease-out 기본"은 제3자가 정리한 스킬 파일(https://instagit.com/emilkowalski/skills/why-ease-in-feels-sluggish-vs-ease-out-ui.md, 검색결과)만 확인했습니다. 1차 출처는 미확인입니다.

#### 모션 감소

- **MDN** (https://developer.mozilla.org/en-US/docs/Web/CSS/Reference/At-rules/@media/prefers-reduced-motion, 열람)은 `prefers-reduced-motion`에서 비필수 모션을 줄이거나 대체하라고 합니다. 크게 확대하거나 이동하는 것은 전정 장애 유발 요인입니다. 예시는 확대 펄스를 투명도 기반의 부드러운 효과로 바꾸는 것입니다.
- **Josh Comeau**(#11)는 모션 감소 시 생성을 멈추고 정적 별 몇 개만 둡니다.
- **Flutter `MediaQueryData.disableAnimations`** (https://api.flutter.dev/flutter/widgets/MediaQueryData/disableAnimations.html, 열람)는 Android의 "애니메이션 제거"에 대응합니다. iOS의 reduce motion은 이 플래그를 설정하지 않고 `AccessibilityFeatures.reduceMotion`이 따로 있습니다. ⚠️ 웹 매핑은 이 페이지에 없어서 미확인입니다.
- 모션 감소 시에는 효과를 끄지 말고 "대체"합니다. 예를 들어 회전과 스윕 대신 별 색만 잠깐 진해지게 하면 클릭 피드백은 유지됩니다.

#### 클릭 처리

- allsvgicons는 연타 시 클래스를 제거하고 리플로우한 뒤 다시 붙여 처음부터 재생합니다. Flutter의 `controller.forward(from: 0)`이 같은 역할입니다.
- Josh Comeau는 `pointer-events: none`으로 장식 요소가 클릭을 막지 않게 합니다.
- 에스컬레이션은 Discord의 16회 클릭 사례(#4)가 근거입니다. 횟수는 출처마다 달라 참고 수치입니다. "5번 연타는 더 큰 효과" 같은 구체 횟수는 제안이고 출처가 없습니다.
- ⚠️ 소리는 기본 꺼짐이 맞다고 보지만 직접 출처는 찾지 못했습니다. Discordo도 시작음을 "켜는" 방식이었습니다(#4).

#### Flutter 웹 성능

- Flutter 공식 성능 문서 (https://docs.flutter.dev/perf/best-practices, 열람)는 `ShaderMask`를 `saveLayer`를 부를 수 있는 위젯으로 꼽습니다. 과도한 `saveLayer`는 jank의 원인이고, `Opacity`는 꼭 필요할 때만 쓰며 애니메이션 중에는 피하라고 합니다. 클리핑도 애니메이션 중에는 피하라고 합니다.
- 같은 문서는 `AnimatedBuilder`의 `child` 인자로 변하지 않는 서브트리를 재빌드하지 말라고 합니다.
- `RepaintBoundary` (https://api.flutter.dev/flutter/widgets/RepaintBoundary-class.html, 열람)는 애니메이션이 형제와 조상까지 다시 그리게 하는 것을 막습니다. 사이드바 브랜드 한 줄을 감싸는 정도가 적절합니다.
- 프래그먼트 셰이더 문서 (https://docs.flutter.dev/ui/design/graphics/fragment-shaders, 열람)는 Skia에서 셰이더 로딩이 비쌀 수 있으니 애니메이션 전에 `FragmentProgram`을 미리 로드하고, `FragmentShader`는 프레임마다 새로 만들지 말고 재사용하라고 합니다. ⚠️ 웹 지원 여부는 이 페이지에 언급이 없어 미확인입니다.
- 웹 렌더러 (https://docs.flutter.dev/platform-integration/web/renderers, 검색결과)는 기본 빌드가 CanvasKit 전용이고 `--wasm`이면 skwasm 또는 CanvasKit입니다. ⚠️ CanvasKit 크기 약 1.5MB 같은 수치는 제3자 글(https://startdebugging.net/2026/09/canvaskit-vs-skwasm-for-flutter-web-in-2026/, https://ecorpit.com/flutter-web-wasm-production-guide-2026/, 검색결과)에서만 봤습니다. HTML 렌더러 제거도 제3자 글의 주장이며 공식 릴리스 노트로는 확인하지 못했습니다.

### 4. Flutter 구현 옵션

| 옵션 | 장점 | 단점 | 이 앱에서의 판단 |
|---|---|---|---|
| **A. `AnimationController` + `Transform`/`CustomPainter`** | 의존성 0. 이미 `disableAnimationsOf` 패턴이 있음. #16이 방식을 보여줌. 스핀, 오버슈트, 입자, 샤인 모두 가능 | 코드를 직접 작성. 입자는 수동 관리 | **권장 1순위** |
| **B. `ShaderMask` + `LinearGradient` 슬라이드** (#14 방식) | 윤곽 안에만 빛이 지나감. 공식 레시피 | `saveLayer` 비용. 반드시 `RepaintBoundary`로 격리. 클릭 시 600~900ms만 짧게 실행 | 샤인 스윕에 적합. 마크 크기가 작아 비용은 제한적이지만 ⚠️ 웹 실측은 필요 |
| **C. `flutter_animate`** (#15) | 선언형. shimmer, scale, shake를 체인으로 구성. Flutter Favorite | 새 의존성. "필요 시 실행"은 컨트롤러 또는 `target`으로 해야 함. 가이드에 모션 감소 언급 없음 | 효과가 3개 이상으로 늘어나면 고려. 지금은 A로 충분 |
| **D. Rive** (#8, #9, #18) — https://pub.dev/packages/rive (열람) | 상태 머신, 눈 깜빡임, 표정 등 캐릭터형에 최적. Duolingo가 채택 | `rive` 0.14는 `rive_native`에 의존. ⚠️ Flutter 웹에서 wasm 크기 영향은 미확인(Rive JS 런타임 wasm이 brotli 약 261kb라는 건 Rive JS 쪽 수치뿐). Rive 에디터 작업 필요 | 마스코트 캐릭터를 만들 때만. 현재 별 아이콘 하나에는 과함 |
| **E. Lottie** — https://pub.dev/packages/lottie (열람) | After Effects 에셋 재생. 컨트롤러로 재생 제어 가능 | After Effects 작업물 필요. 문서가 CanvasKit만 언급. 에너지 소비 때문에 `renderCache` 옵션이 있음 | 디자이너가 별도 애니를 납품할 때만 |
| **F. `FragmentProgram` 셰이더** | 가장 화려한 글린트 | ⚠️ 위 3절대로 웹 지원과 성능이 미확인. 로딩 비용 | 이번에는 비추천. 검증 후 보너스로 |

### 5. 이 브랜드를 위한 추천 컨셉 5

공통 방향: 별(sparkle) 자체가 이미 "반짝임"의 문법이고, 'Blink'라는 이름이 윙크나 깜빡임과 직결됩니다. 종이와 잉크의 차분함을 해치지 않도록 파스텔 `pb.accent` 한 가지 색, 총 길이 1초 이내를 지키는 안을 골랐습니다.

1. **윙크 스핀 + 샤인 스윕 (기본 클릭)**
   - 클릭하면 별이 -20°로 살짝 웅크렸다가(anticipation) 90° 돌며 1.15배로 오버슈트하고 복귀합니다. 동시에 대각선 광택 띠가 별에서 'PageBlink' 글자 위로 한 번 훑습니다.
   - 총 약 700ms입니다. 근거는 #13(샤인 스윕), #14(ShaderMask 레시피), allsvgicons(오버슈트 곡선)입니다.
   - 우리 앱에서 가장 "예쁘면서 재밌는" 균형점이라고 봅니다. 구현은 옵션 A와 B의 조합이고 의존성이 없습니다.
2. **별 버스트 (Josh Comeau식 미니 스파클)**
   - 클릭 지점 주변에 4점 별 4~6개가 0→1→0으로 부풀었다 사라집니다(수명 약 750ms). 크기와 위치는 무작위, 색은 accent의 명도 변형 두 가지입니다.
   - 근거는 #11이고, `IgnorePointer`로 클릭을 막지 않습니다. 모션 감소 시에는 별 1개만 표시합니다.
   - 컨셉 1에 덧붙이는 용도로 가장 안전합니다.
3. **5연타 에스컬레이션 (이스터에그)**
   - 1~4번째 클릭은 컨셉 1입니다. 5번째에는 별 주위로 작은 별 3개가 궤도를 한 바퀴 돌고 글자 'PageBlink'가 한 글자씩 파도치듯 튀어오릅니다(합계 약 1초). 쿨다운은 몇 초 둡니다.
   - 근거는 #4(Discord 연타 보상)입니다. 횟수 설계는 제안이고, 사운드는 넣지 않습니다.
   - 숨은 즐거움을 주면서 평소에는 방해하지 않습니다.
4. **눈 깜빡임 (Blink 말장난)**
   - 별을 눈으로 해석해, 클릭하면 수직으로 가늘어졌다(scaleY 0.15) 다시 열리는 깜빡임을 한 번 줍니다. 총 약 300ms입니다. 가끔 글자 'i'에 작은 하이라이트가 따라 켜집니다.
   - 근거는 #9(눈과 표정 전환)와 스쿼시 앤 스트레치 가이드(비권위)입니다. 브랜드명 'Blink'와 가장 직접 연결되는 컨셉입니다.
   - ⚠️ 눈처럼 보이도록 별 모양에 약간의 조정이 필요할 수 있습니다. 시각 확인이 필요합니다.
5. **종이 잉크 한 방울 (톤 맞춤 리빌)**
   - 클릭하면 별 위치에서 accent 색 잉크가 원형으로 번지며 글자 윤곽 안에 스며들었다가 빠집니다(약 900ms). 원형 마스크 `ClipPath`를 키우는 방식이면 셰이더 없이도 가능합니다.
   - 근거는 SVG feTurbulence 잉크 번짐 검색결과를 참고한 것이고, ⚠️ Flutter에 맞는 재현은 검증하지 못했습니다. 클리핑은 애니메이션 중 비용이 큰 편이라 마크 크기 제한이 필요합니다.
   - "종이와 잉크" 정체성을 가장 잘 살리지만 나머지 넷보다 구현 위험이 큽니다.

## 미확인 · 리스크

- ⚠️ Reddit(r/webdev, r/FlutterDev 등), Hacker News, Qiita, Zenn, velog, GeekNews에서 로고 클릭 효과를 다룬 구체적 글은 한 건도 찾지 못했습니다. "extended" 검색도 같았습니다.
- ⚠️ Awwwards, FWA, CSSDA, Shadertoy, Mobbin의 개별 작품 페이지는 열지 못했습니다. Dribbble은 검색 목록만 보았고(예: Milkinside "Logo microanimation", https://dribbble.com/shots/14995709-Logo-microanimation, 검색결과), 클릭 트리거인지 확인하지 못했습니다.
- ⚠️ Stripe, Linear, Notion, Slack, Duolingo 올빼미의 로고 클릭, Apple 쉬머 텍스트, GitHub 옥토캣의 공식 클릭 이스터에그는 확인하지 못했습니다. 옥토캣은 서드파티 프로젝트(#7)만 확인했습니다.
- ⚠️ Vercel 사례(#5)와 Raycast 사례(#6)는 효과 설명과 구현 정보가 거의 없습니다.
- ⚠️ Flutter 프래그먼트 셰이더가 웹에서 어떻게 동작하는지, Rive/Lottie 웹 번들 크기, `ShaderMask`의 실제 웹 프레임 비용은 직접 근거가 없어서 실측이 필요합니다.
- ⚠️ 효과별 권장 시간(500~900ms, 40~60ms 시차 등)은 NN/g, Flutter `Durations`, Josh Comeau를 바탕으로 제가 정리한 제안값입니다. 출처가 그 수치를 직접 말한 것이 아닙니다.
- ⚠️ Emil Kowalski의 지침은 제3자 정리본뿐입니다. 스쿼시 앤 스트레치 수치도 비권위 스킬 카탈로그입니다.
- ⚠️ 이 앱의 모션 정책 문서(`docs/`)와 기존 `pb_interactive.dart`의 시간 규칙을 읽지 않았습니다. 구현 전에 맞춰볼 필요가 있습니다.
- 위 마지막 항목(이 앱의 모션 정책 문서를 읽지 않았다)에 대해: 정책 문서와의 충돌 대조는 후속 기획 [`design/logo-click-effect/spec.md`](../design/logo-click-effect/spec.md) §2에서 했다.

## 출처

열람:

- https://web.dev/google-io-2013
- https://9to5google.com/guides/google-for-iphone/
- https://beebom.com/cool-discord-easter-eggs/amp/
- https://designspells.com/spells/halloween-easter-egg-when-hovering-on-vercels-logo
- https://designspells.com/spells/raycast-has-a-command-that-makes-it-bounce-around-like-the-dvd-logo
- https://tholman.com/post/github-corners
- https://rive.app/community/5132-10323-logo-interaction/
- https://www.rive.app/marketplace/21530-40624-animated-logo
- https://rive.app/blog/12-best-rive-community-designs-of-2023
- https://www.joshwcomeau.com/react/animated-sparkles-in-react/
- https://magicui.design/docs/components/sparkles-text
- https://www.amitmerchant.com/shine-animation-on-hover-using-css
- https://docs.flutter.dev/cookbook/effects/shimmer-loading
- https://pub.dev/documentation/flutter_animate/latest/flutter_animate/ShimmerEffect-class.html
- https://pub.dev/packages/flutter_animate
- https://dev.to/orestesgaolin/flutter-animated-logo-with-custompainter-34en
- https://www.framer.com/marketplace/components/interactive-logo/
- https://blog.duolingo.com/world-character-visemes
- https://www.nngroup.com/articles/animation-duration/
- https://api.flutter.dev/flutter/material/Durations-class.html
- https://api.flutter.dev/flutter/material/Easing-class.html
- https://api.flutter.dev/flutter/widgets/MediaQueryData/disableAnimations.html
- https://developer.mozilla.org/en-US/docs/Web/CSS/Reference/At-rules/@media/prefers-reduced-motion
- https://docs.flutter.dev/perf/best-practices
- https://api.flutter.dev/flutter/widgets/RepaintBoundary-class.html
- https://docs.flutter.dev/ui/design/graphics/fragment-shaders
- https://pub.dev/packages/lottie
- https://pub.dev/packages/rive
- https://www.allsvgicons.com/blog/micro-interactions-svg-hover-click/
- https://ics.media/en/entry/15130/
- https://www.carmenansio.com/articles/animated-icon-libraries/

검색결과만:

- https://en.wikipedia.org/wiki/Google_Doodle
- https://support.discord.com/hc/ko/community/posts/360029419792-Add-a-startup-sound-to-Discord
- https://www.droid-life.com/2015/10/05/video-googlers-post-a-brief-history-of-android-easter-eggs/
- https://docs.flutter.dev/platform-integration/web/renderers (열람 시도 시 개요 페이지만 반환, 렌더러 상세는 검색결과 스니펫)
- https://startdebugging.net/2026/09/canvaskit-vs-skwasm-for-flutter-web-in-2026/
- https://ecorpit.com/flutter-web-wasm-production-guide-2026/
- https://instagit.com/emilkowalski/skills/why-ease-in-feels-sluggish-vs-ease-out-ui.md
- https://dribbble.com/shots/14995709-Logo-microanimation

저장소에서 읽은 파일:

- `/Volumes/Nova/00-src/70-github@biyott/pageblink/app/pageblink_flutter/lib/main.dart`
- `/Volumes/Nova/00-src/70-github@biyott/pageblink/app/pageblink_flutter/lib/app/app_icons.dart`
- `/Volumes/Nova/00-src/70-github@biyott/pageblink/app/pageblink_flutter/lib/app/pb_interactive.dart`
- `/Volumes/Nova/00-src/70-github@biyott/pageblink/app/pageblink_flutter/pubspec.yaml`
