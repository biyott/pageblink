# 🎥 데모 영상 제작 계획 (2분 · 에이전트 자동 녹화·편집)

> **작성일**: 2026-10-15 02:05 KST · **최종 수정**: 2026-10-15 02:17 KST
> **관련 문서**: [데모 대본 (006)](006-demo-script.md) · [제출 키트 (008)](008-submission-kit.md) · [README](../../README.md) · [ADR 010](../adr/010-acl-in-query.md) · [ADR 014](../adr/014-model-catalog-and-rotation.md) · [research 004 (마감)](../research/004-hackathon-deadline.md)
> **표기**: ✅ 이 세션에서 실제로 실행·확인 · ⚠️ 미확인(스파이크·리허설에서 확인)
> **언어**: 문서는 한국어, **내레이션·화면 문구는 영어**

제출 필수 항목 "Demo video: A working demo video (max 2 minutes)"를 위한 **실행 계획**입니다. [006](006-demo-script.md)의 대본을 바탕으로, 녹화·음성·자막·편집을 **에이전트가 최대한 자동으로** 처리하도록 다시 짰습니다. 목표는 **60~90분 안에 1080p MP4 완성**입니다. 최종 제출 마감은 **06:59 KST**입니다.

### 006에서 바뀐 점

| 006 | 009 (이 문서) | 이유 |
|---|---|---|
| "앱 UI는 한국어" | **UI는 영어** (`locale: 'en-US'`로 실행) | 앱이 EN 기본, KO는 자동 전환으로 바뀜 (README) |
| 로그인 장면 8초 | **삭제**. 로그인된 상태에서 시작 | 2:00 여유 확보. 로그인은 기능 시연 가치가 낮음 |
| 인용 클릭 시 화면 전환 | **데스크톱 3분할**: 인용된 노트가 가운데 창에 열림 | 최신 커밋 `da343eb` 레이아웃 |
| 노트 + PDF 시연 | **노트만** (PDF·프로젝트 초대 장면 없음) | 사용자 결정 (2026-10-15) |
| 사람이 녹화·편집 | Playwright 녹화 + edge-tts + ffmpeg 자동 조립 | 사용자 요청 |

### 영상은 전부 영어 (사용자 요구사항)

화면에 한국어가 **한 글자도 보이지 않게** 합니다.

| 대상 | 규칙 |
|---|---|
| 내레이션·자막·라벨·카드 | 영어만 |
| 앱 UI | Playwright `locale: 'en-US'` + Chrome `args: ['--lang=en-US']`로 실행. 로그인 후 **Settings → Language → English**로 한 번 명시 (프로필에 `ko`가 저장돼 있으면 덮어씀). 앱은 로케일이 `ko`가 아니면 영어가 기본 ✅ (README) |
| 시드 데이터 | 노트 제목·본문 모두 영어 (§3) |
| 질문 | 영어로 입력 → 답변도 영어로 스트리밍. ⚠️ 리허설에서 답변 언어 확인 |
| 브라우저 화면 | 주소창·탭 제목·북마크 바·OS 알림에 한국어가 없게. 녹화 전 프레임 QC에서 한국어가 보이면 재촬영 |

## 1. 컨셉과 훅

- **한 줄**: *Ask your notes. Blink to the source.*
- **범위 (사용자 결정 2026-10-15)**: **노트만** 보여 줍니다. PDF 업로드·PDF 페이지 점프 장면은 없습니다. 프로젝트 초대 장면도 없습니다 (기본값, 사용자 확인 대기). Higgsfield 대신 HTML 카드를 씁니다 (기본값).
- **이야기의 핵심**: *몇 초 전에 쓴 노트가 바로 검색되고, 답의 근거로 인용된다.* 질문 하나에 대한 답이 **두 노트를 각각 인용**하고, ⚡을 누르면 해당 노트가 인용 구절과 함께 열립니다.
- **훅 (첫 7초)**: "AI가 답은 주지만 출처는 안 준다." 문제를 먼저 말하고 바로 본편으로 들어갑니다.
- **원칙**: 앱 기능은 **100% 실제 화면 녹화**로만 보여 줍니다. 앱 UI를 생성하거나 흉내 내지 않습니다.
- **톤**: 빠른 컷, 대기 시간은 잘라 내거나 배속, 화면 상단에 짧은 라벨, 하단에 영어 자막.

## 2. 스토리보드 (목표 약 1:40, 상한 2:00)

내레이션 길이는 edge-tts 실측으로 다시 맞춥니다 (§5.3). 아래 초 단위는 목표값입니다. ⚠️ 실측 후 조정.

| # | 시간 | 화면 (소스) | 내레이션 (EN) | 화면 문구 (라벨) |
|---|---|---|---|---|
| S1 | 0:00–0:07 | 🖼 인트로 카드 (로고 + 문제 문장) | "We write things down so we don't have to remember them. But when we ask an AI about our notes, the answer comes with no source we can check." | **PageBlink** |
| S2 | 0:07–0:15 | 🎬 `pageblink.serverpod.space`, 로그인된 데스크톱 3분할 (사이드바 · 노트 보드 · Ask 패널). 보드에 노트 A *Launch plan — PageBlink beta* | "This is PageBlink, live on Serverpod Cloud: a Keep-style board of Markdown notes. Here's our launch plan, with a budget and a checklist." | Live on Serverpod Cloud |
| S3 | 0:15–0:33 | 🎬 "New note" → 노트 B *Standup — Oct 15* 타이핑 (편집에서 약 2배속) → 뒤로(저장) → 카드가 **Indexing** 상태에서 벗어나는 것까지 | "Now a quick standup note: the launch moved to November eighteenth. Go back, and it's saved. The server chunks and embeds it right away, so it's searchable in seconds." | A note written seconds ago… |
| S4 | 0:33–0:55 | 🎬 Ask 패널 → 답변 모델 선택기 잠깐 열었다 닫기 → 질문 타이핑 → 답변 스트리밍 + ⚡ 칩 (대기 구간 1.5배속) | "Ask in plain language: when is the launch, and who approves spending over the budget? One question searches every note. Free OpenRouter models are the default, and the server rotates to another one if a model is busy. The answer streams in, with a lightning-bolt citation for every source." | One question · every note |
| S5 | 0:55–1:15 | 🎬 ⚡(*Standup — Oct 15*) 탭 → 가운데 창에 노트가 열리고 상단에 인용 구절 → ⚡(*Launch plan*) 탭 → 같은 방식 | "Tap a bolt, and the note opens right here, with the quote on top. The launch date comes from the standup note I wrote seconds ago. The approval rule comes from the launch plan. Every claim is one tap from its source." | ⚡ Blink to the source |
| S6 | 1:15–1:30 | 🖼 아키텍처 카드 (HTML → PNG, 천천히 확대) | "Under the hood, it's Flutter talking to Serverpod 4: the ORM with pgvector and an HNSW index, a streaming endpoint for answers, built-in auth, and team projects with access control inside the vector query. All deployed on Serverpod Cloud." | Flutter · Serverpod 4 · pgvector HNSW · Streaming · Auth · ACL in the query |
| S7 | 1:30–1:38 | 🖼 아웃트로 카드: 로고 + 태그라인 + URL + GitHub | "PageBlink. Ask your notes. Blink to the source." | pageblink.serverpod.space · github.com/biyott/pageblink |

- 🎬 = Playwright 실제 녹화, 🖼 = HTML 카드 렌더링. 기능 장면(S2–S5)은 전부 🎬입니다.
- 넘칠 때 줄이는 순서: S4 모델 선택기 생략 → S2 설명 단축.
- 선택(여유가 있을 때만): S5 뒤에 모바일 뷰포트(390×844) 3초 컷 "Same app on your phone." ⚠️ 2:00을 넘기면 넣지 않음.
- 프로젝트(Shared Vision)와 ACL은 화면 시연 없이 S6 내레이션으로만 언급합니다 (README에 ✅ 구현 기록, [ADR 010](../adr/010-acl-in-query.md)).

## 3. 시연 데이터

무료 모델은 프롬프트를 기록할 수 있으므로 **가상의 공개 가능한 내용만** 씁니다 ([ADR 014](../adr/014-model-catalog-and-rotation.md)). 모두 영어입니다.

### 노트 A (사용자가 촬영 전에 직접 작성 · 영상 시작 시 이미 보드에 있음)

제목: `Launch plan — PageBlink beta`

```markdown
## Goal
Ship the PageBlink public beta to 500 early users.
## Budget
- Marketing budget: **$12,000** for Q4
- Anything above $12,000 needs approval from **Maya (Finance lead)**
## Checklist
- [x] Landing page live
- [x] Serverpod Cloud deployment
- [ ] Record the demo video
- [ ] Send invites to the waitlist
```

### 노트 B (영상 S3에서 "New note"로 작성 · Playwright가 타이핑)

제목: `Standup — Oct 15`

```markdown
- Launch date moved to **Nov 18** (was Nov 4)
- Waitlist invites go out **one week before launch**
- [ ] Ask Maya to review the ad budget
```

### 질문 (S4, 영어로 입력)

`When is the launch, and who approves spending over the budget?`

**기대 답변**: Nov 18 → ⚡ *Standup — Oct 15*, $12,000 초과 지출은 Maya (Finance lead) 승인 → ⚡ *Launch plan — PageBlink beta*.

**하드 게이트 (리허설)**: 같은 질문으로 **두 노트 인용이 둘 다** 나와야 합니다. 노트 B 저장 후 카드가 **Indexing 상태를 벗어난 뒤** 질문합니다. 안 나오면 질문 문구를 고쳐 다시 시도하고, 통과한 문구만 녹화에 씁니다. ⚠️ 답변이 "was Nov 4"를 날짜로 잘못 집지 않는지도 확인.

**재촬영 정리**: S3은 노트 B를 실제로 만듭니다. 리허설·실패 테이크 뒤에는 **노트 B를 지우고** 다시 찍습니다 (중복 카드·중복 인용 방지). 노트 A는 지우지 않습니다.

## 4. 실제 녹화 vs 생성 영상

| 구간 | 소스 | 비고 |
|---|---|---|
| S2–S5 (앱 기능 전체) | **Playwright 녹화** (실제 Cloud 배포본) | 가짜 화면 금지 |
| S1, S7 | **HTML 카드** (무료, 결정적) | Higgsfield는 쓰지 않음 (기본값). 사용자가 원하면 배경만 교체 |
| S6 아키텍처 | HTML 카드 → PNG → 느린 확대(ffmpeg `zoompan`) | 006 §3 다이어그램 기준. 수치(지연·정확도)는 넣지 않음 |

### Higgsfield (기본값: 사용 안 함 · 사용자가 원할 때만 수동)

- 이 환경에는 Higgsfield CLI·API 키가 없고, cli-hub 카탈로그에도 없습니다 (✅ `cli-hub search higgsfield` → 결과 없음). 따라서 **사용자가 웹에서 직접 생성**해 MP4를 작업 폴더에 넣는 방식입니다.
- 상한: **최대 2클립(인트로·아웃트로) + 재시도 1회**. 1클립 4~5초, 1080p 또는 16:9.
- 크레딧: ⚠️ 모델·길이별 단가를 확인하지 못했습니다. 생성 전에 Higgsfield 화면에서 단가를 확인하고, **총 100 크레딧 이하**로 쓰도록 권장합니다 (보유 212, 사용 가능 약 200).
- 프롬프트 예 (인트로): *"Macro shot of scattered paper notes drifting in a dark studio; a single lightning bolt flashes and the notes snap into one glowing card. Cinematic, shallow depth of field, no text, no logos, no UI."*
- 프롬프트 예 (아웃트로): *"Slow push-in on a single glowing page on a clean desk, soft light, calm, no text, no UI."*
- **시간이 빠듯하면 Higgsfield는 건너뜁니다.** HTML 카드만으로 완성품이 나옵니다.

## 5. 자동화 파이프라인

작업 폴더는 저장소 밖에 둡니다: `~/pageblink-video/` (스크립트·녹화·중간 산출물). 저장소의 `README.md`·`app/`는 건드리지 않습니다.

### 5.1 도구 (이 세션에서 확인)

| 도구 | 상태 | 용도 |
|---|---|---|
| `imageio-ffmpeg` (pip, venv) → ffmpeg 7.0.2 static | ✅ 설치·실행 확인. `libx264`, `aac`, `subtitles`/`ass`(libass), `xfade`, `concat`, `amix`, `loudnorm`, `x11grab` 있음. ⚠️ `drawtext` 없음 → 텍스트는 ASS 또는 HTML로 | 편집·인코딩 |
| Playwright 내장 ffmpeg (`~/.cache/ms-playwright/ffmpeg-1011`) | ✅ 확인: MJPEG→VP8 WebM만 가능. 편집에는 못 씀 | Playwright 녹화 내부용 |
| `edge-tts` (pip, venv) | ✅ `en-US-AndrewNeural`로 MP3 + 문장 단위 SRT 생성 확인 (2.47초 샘플) | 내레이션 + 자막 타이밍 |
| `npx playwright` 1.64.1 + 시스템 Chrome (`channel: 'chrome'`) | ✅ 버전 확인. ⚠️ Flutter 웹 조작은 스파이크에서 확인 | 녹화 |
| WSLg 디스플레이 | ✅ `DISPLAY=:0`, `WAYLAND_DISPLAY=wayland-0` 있음 → headed Chrome 가능 ⚠️ 실제 창 표시는 미확인 | 사용자 1회 로그인, 화면 캡처 대안 |

설치 (약 2분): `python3 -m venv ~/pageblink-video/venv && ~/pageblink-video/venv/bin/pip install edge-tts imageio-ffmpeg` 후 ffmpeg 경로를 `FFMPEG` 환경변수로 씁니다. 작업 폴더에서 `npm i -D playwright@1.64.1` (브라우저는 시스템 Chrome 사용).

### 5.2 녹화 (Playwright)

- `chromium.launchPersistentContext('~/pageblink-video/profile', { channel: 'chrome', headless: false, locale: 'en-US', viewport, deviceScaleFactor, recordVideo: { dir, size: { width: 1920, height: 1080 } } })`
  - `size`를 주지 않으면 800×800 안쪽으로 축소되므로 **반드시 지정**합니다.
  - 해상도·글자 크기 후보 두 가지를 스파이크에서 비교합니다: (a) viewport 1920×1080, DSF 1 / (b) viewport 1440×810, DSF 1.333. ⚠️ 프레임을 뽑아 글자가 읽히는 쪽을 고릅니다.
- **장면별 분할 녹화**: S2~S5를 장면마다 별도 컨텍스트(또는 별도 페이지)로 녹화합니다. 한 장면이 실패해도 그 장면만 다시 찍습니다.
- **타임스탬프 로그**: 동작마다 `{scene, event, t}`를 `marks.json`에 남깁니다 (예: `answer_first_token`, `answer_done`, `note_indexed`). 편집 단계에서 이 값으로 대기 구간을 계산해 자르거나 배속합니다. 무료 모델 스트리밍 시간이 매번 달라서 고정 타임라인은 안 맞습니다.
- **Flutter 웹 조작** ⚠️ 스파이크 대상:
  - Flutter 웹은 canvas에 그리므로 기본 상태에서는 텍스트·역할 선택자가 안 잡힐 수 있습니다. 페이지 로드 후 `document.querySelector('flt-semantics-placeholder')?.click()`으로 semantics를 켜고, `getByRole('button', { name: 'New note' })`, `'Ask'`, `'Answer model'`, 입력창 `'Ask your notes…'` 등이 잡히는지 확인합니다 (라벨 문구는 `l10n.dart` ✅).
  - 안 잡히면 대안: 스크린샷 기준 **좌표 클릭** (뷰포트 고정이라 재현 가능).
  - 텍스트 입력: 포커스 시 Flutter가 만드는 실제 `<input>`/`<textarea>`에 `page.keyboard.type(text, { delay: 25 })`.
- **커서 표시**: Playwright 녹화에는 마우스 포인터가 안 찍힙니다. `addInitScript`로 `pointer-events: none`, 최상위 `z-index`의 커서 점 + 클릭 파문 DOM을 넣고, `page.mouse.move(x, y, { steps: 20 })`로 부드럽게 움직입니다. ⚠️ canvas 위에 보이는지 스파이크에서 확인.
- **로그인**: 영상에는 넣지 않습니다. §7의 방법으로 한 번만 로그인하고, 같은 프로필 폴더를 재사용합니다.

### 5.3 음성 (TTS)

| 옵션 | 판단 |
|---|---|
| **edge-tts (기본)** | ✅ 동작 확인. 무료, 자연스러운 뉴럴 음성. 장면별 `--write-media S{n}.mp3 --write-subtitles S{n}.srt`. 음성 후보: `en-US-AndrewNeural`(확인함), `en-US-AriaNeural`, `en-US-GuyNeural` ⚠️(뒤의 둘은 미청취). 속도는 `--rate=+5%` 정도로 조정 ⚠️. 비공식 서비스라 갑자기 막힐 수 있음 |
| 사용자 직접 녹음 | 대안. 휴대폰으로 장면별 녹음 → 파일만 넘기면 나머지는 동일 |
| 유료 TTS (ElevenLabs·MiniMax) | 키 없음. 쓰지 않음 |

**내레이션 우선 편집**: 장면별 MP3 길이를 ffmpeg로 먼저 재고, 영상 클립을 그 길이에 맞춥니다 (§5.5).

### 5.4 자막·화면 문구

- **YouTube CC용 SRT**: 장면별 edge-tts SRT를 시작 오프셋만큼 밀어 하나의 `captions.srt`로 합칩니다. 업로드 시 YouTube에 따로 올립니다.
- **화면 하단 자막 + 상단 라벨 (영상에 굽기)**: `captions.ass`에 스타일 2개(`Caption` 하단 중앙, `Label` 좌상단)를 만들어 `subtitles=captions.ass:fontsdir=/usr/share/fonts/truetype/dejavu` 필터로 굽습니다. ✅ `subtitles`/`ass` 필터 있음. ⚠️ static 빌드의 fontconfig 동작은 미확인 → `fontsdir` 지정. 폰트가 어색하면 라벨은 HTML 카드로 처리.

### 5.5 편집·내보내기 (ffmpeg 스크립트)

1. 녹화 WebM → `marks.json` 기준으로 장면별 구간 잘라내기 (`trim`), 대기 구간 배속 (`setpts=PTS/1.5`), 내레이션보다 짧으면 마지막 프레임 연장 (`tpad=stop_mode=clone`).
2. HTML 카드(S1·S6·S7)를 Playwright로 1920×1080 PNG 렌더링 → `zoompan`으로 느린 확대 영상 생성. (선택: Higgsfield 클립을 배경으로 깔고 카드 텍스트는 ASS로 얹음)
3. 장면 연결: `xfade`(0.3초) 또는 `concat`.
4. 오디오: 장면별 MP3를 시작 시점에 맞춰 `amix`/`concat`, `loudnorm=I=-14:TP=-1.5`(YouTube 기준). 배경음악은 라이선스 문제로 넣지 않음.
5. 자막 굽기 (`captions.ass`).
6. 내보내기: `-c:v libx264 -preset slow -crf 18 -pix_fmt yuv420p -r 30 -c:a aac -b:a 192k -movflags +faststart` → `pageblink-demo-1080p.mp4`.
7. QC: 길이 `< 2:00` 확인 (`ffprobe` 대신 `ffmpeg -i`의 Duration), 장면마다 프레임 1장씩 뽑아 글자 가독성·커서·자막 위치 확인 → 사용자에게 보여 주고 승인.

## 6. 실행 순서와 시간 (약 75~85분)

| 단계 | 시간 | 내용 | 게이트 |
|---|---|---|---|
| T0 설치 | 5분 | venv(edge-tts·imageio-ffmpeg), 작업 폴더 Playwright | — |
| T1 스파이크 | 15분 | Flutter semantics 선택자, 키보드 입력, 파일 선택, 1080p 10초 테스트 녹화 → 프레임 가독성, 커서 오버레이 | **실패 시 §6.1 수동 녹화로 전환** |
| T2 로그인·시드·리허설 | 10분 | 사용자 가입·1회 로그인·English 설정·노트 A 작성, 노트 B로 질문 리허설 후 노트 B 삭제 | **두 노트 인용 동시 출현** |
| T3 TTS | 5분 | 장면별 MP3·SRT, 길이 측정 → 스토리보드 초 조정 | 합계 ≤ 1:55 |
| T4 녹화 | 20분 | S2~S5 장면별, 장면당 최대 3테이크 | 장면별 성공 |
| T5 조립 | 15분 | 카드 렌더링, 컷·배속, 자막, 오디오, 내보내기, QC | 길이 < 2:00 |
| T6 검토·업로드 | 5~10분 | 사용자 확인 → YouTube 업로드 | 링크 확보 |

마감 06:59 KST 기준, 02:10에 시작하면 03:40 전후 완료 예상. ⚠️ 실패 테이크가 많으면 늘어남.

### 6.1 대안 (스파이크 실패 시)

- **반자동**: 사용자가 Windows Game Bar(`Win+Alt+R`) 또는 OBS로 대본대로 화면을 녹화해 파일만 넘깁니다. TTS·자막·카드·조립·내보내기는 에이전트가 그대로 합니다.
- **x11grab**: headed Chrome 창을 ffmpeg `x11grab`으로 캡처 ✅ 필터 존재 / ⚠️ WSLg에서 캡처 가능 여부 미확인.

## 7. 사용자가 직접 할 일

| # | 할 일 | 언제 | 비고 |
|---|---|---|---|
| 1 | 데모 계정 준비: 기존 계정 사용 또는 Live 앱에서 새로 가입(인증 코드는 메일함) | T2 전 | 로그인 자체는 이메일+비밀번호. 인증 코드는 가입 때만 필요. 로그인 화면은 곧 **로그인 폼이 먼저** 열리고 버튼 아래에 Sign up 링크가 있는 형태로 배포됨 (리드 전달, ⚠️ 배포 후 확인) |
| 2 | Playwright가 띄운 Chrome 창에서 **한 번 로그인** (또는 셸에 `DEMO_EMAIL`/`DEMO_PASSWORD` 설정 → 스크립트가 입력) | T2 | 비밀번호를 파일·문서·커밋에 남기지 않음. 프로필 폴더는 저장소 밖 |
| 3 | 초대 장면 생략 확정 (기본값 생략) | T2 | — |
| 4 | Higgsfield 사용 여부 확정 (기본값: 사용 안 함). 쓰면 배경 MP4를 `~/pageblink-video/broll/`에 | T3~T4 사이 | §4 상한 준수 |
| 5 | 완성본 확인·승인 | T6 | — |
| 6 | **YouTube 업로드** (공개 또는 일부 공개), `captions.srt` 자막 업로드, 링크 공유 | T6 | 업로드 자동화(YouTube Data API OAuth)는 시간 대비 이득이 없어 하지 않음 |
| 7 | 리드가 README의 `<VIDEO_URL>`과 제출 양식에 링크 반영 | 업로드 후 | 이 문서 범위 밖 |

### 로그인 방식 비교

| 방식 | 판단 |
|---|---|
| **Live 앱 + 사용자 1회 로그인 + 영구 프로필** (권장) | 비밀번호가 에이전트에 안 넘어감. 화면에 실제 배포 URL이 나옴. ⚠️ 로그인 상태가 프로필에 유지되는지(웹 저장소) 스파이크에서 확인 |
| Live 앱 + 환경변수 자격증명 | 빠름. 셸 환경변수에만 두고 출력하지 않음 |
| 로컬 서버 (`serverpod start`, 인증 코드가 콘솔에) | 비권장: Postgres·키 준비가 필요하고, 화면에 `localhost`가 나와 "Serverpod Cloud에서 동작" 메시지가 약해짐 |

## 8. 위험과 대응

| 위험 | 대응 |
|---|---|
| Flutter 웹에서 선택자가 안 잡힘 ⚠️ | semantics 활성화 → 좌표 클릭 → 수동 녹화(§6.1) 순서로 내려감 |
| Playwright 녹화 화질(VP8 비트레이트)이 낮아 글자가 뭉개짐 ⚠️ | 스파이크에서 프레임 확인. DSF로 글자 키우기, 안 되면 x11grab 또는 수동 녹화 |
| 무료 모델 혼잡·느림·쿼터(README 기록값: 일 50회·분 20회 ⚠️) | 리허설에서 응답 빠른 모델을 골라 고정. 테이크 수 제한. 대기는 배속·컷 |
| 질문이 두 노트 인용을 동시에 못 만듦 | T2 하드 게이트. 질문 문구 수정 |
| 노트 B 인덱싱이 끝나기 전에 질문함 | 카드의 Indexing 상태가 사라질 때까지 대기(`note_indexed` 마크), 대기 구간은 편집에서 컷 |
| 재촬영 시 중복 노트 | 테이크 전에 노트 B 삭제 |
| edge-tts 서비스 차단 | 사용자 직접 녹음으로 대체 |
| 2:00 초과 | §2의 줄이는 순서 적용. 내보내기 전 길이 확인 |
| 마감 압박 | Higgsfield·모바일 컷 등 선택 항목부터 버림 |

## 9. cli-anything / cli-hub로 가능한가 (솔직한 답)

**결론: 이번 작업에는 필요 없습니다. 체크리스트로만 참고합니다.**

이 세션에서 venv에 `cli-anything-hub`를 설치해 직접 확인했습니다 (✅).

- `cli-hub`는 pip 패키지 래퍼입니다. 각 도구(`cli-anything-<name>`)를 별도 pip 패키지로 설치합니다.
- `cli-hub matrix preflight video-creation` 결과: **19개 기능 중 7개만 충족**, 82개 제공자 중 6개 사용 가능. 충족된 7개는 대부분 "에이전트가 직접 계획" 같은 항목입니다.
- 화면 녹화 제공자는 `cli-anything-openscreen`, `cli-anything-obs-studio`(OBS GUI 앱 필요), `ffmpeg x11grab`입니다. 편집 제공자는 `cli-anything-kdenlive`·`shotcut`(GUI 앱 설치 필요)입니다. 영상 생성은 Veo·Runway·Kling(유료 키 필요)이고, TTS는 MiniMax·ElevenLabs(유료 키 필요)입니다.
- **Higgsfield는 카탈로그에 없습니다** (`cli-hub search higgsfield` → 결과 없음).
- preflight가 "ffmpeg missing"이라고 한 건 PATH에 ffmpeg가 없어서입니다. 위의 imageio-ffmpeg를 PATH에 걸면 충족됩니다.

정리하면, cli-hub가 추천하는 경로는 결국 ffmpeg + 녹화 도구 + TTS입니다. 그 조합(Playwright + imageio-ffmpeg + edge-tts)은 이미 이 환경에서 2분 안에 확보했습니다. GUI 편집기 하네스를 더 설치하면 시간과 실패 지점만 늘어납니다.

## 10. 변경 이력

- `2026-10-15 02:17` 사용자 결정 반영: **노트만** 시연(PDF·초대 장면 삭제, Higgsfield 대신 HTML 카드), 스토리보드 S1–S7(약 1:40) 재작성, 시드 노트 A·B와 질문 확정, 리허설 게이트를 "두 노트 인용"으로 변경
- `2026-10-15 02:07` 영어 전용 규칙 추가 (UI·시드·질문·자막 모두 영어, 한국어 노출 금지), 로그인 화면 변경 메모
- `2026-10-15 02:05` 최초 작성. 도구 확인(imageio-ffmpeg 7.0.2 필터·인코더, edge-tts 샘플, Playwright 1.64.1, cli-hub preflight)은 이 세션에서 실행. Flutter 웹 자동 조작·녹화 화질·리허설은 ⚠️ 미확인
