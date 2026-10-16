# 029 · 줄(블록) 단위 청킹, 맥락 접두, 재색인 마이그레이션 (방안 A)

| 항목 | 값 |
|---|---|
| 조사일 | 2026-10-16 11:01 (KST) |
| 담당 | 서브에이전트 (설계 담당 엔지니어, 읽기 전용: 저장소 무수정) |
| 질문 | 노트를 줄(블록) 단위로 청킹하고, 맥락 접두를 붙이고, 기존 문서를 재색인하려면 어떻게 하나 (방안 A) |
| 결론 한 줄 | 노트는 **마크다운 블록 인지 줄 단위**(청크 = 본문의 정확한 부분 문자열), PDF는 **문장 묶음 ≤300자**로 자르고, 맥락(제목 경로)은 **임베딩 입력의 `title:` 칸에만** 넣는다. DB 스키마는 바꾸지 않고(`Document.embeddingModel` 문자열에 청크 규칙 버전을 붙여 구버전 표식), 재색인은 **문서 단위 조건부 교체**(옛 청크 유지 → 새 청크 임베딩 → 한 트랜잭션에서 교체)로 부팅 후 백그라운드에서 천천히 돈다. |
| 반영 | [ADR 021](../adr/021-line-level-chunks-two-tier-context.md) · [devlog 011](../devlog/011-chunk-v2-two-tier-u2-locale-demo.md) |
| 근거 문서 | [research 027](../research/027-citation-span-highlight.md) §1·§2 A·§4, [research 028](../research/028-locale-samples.md), [ADR 002](../adr/002-embedding-embeddinggemma-768.md), [ADR 003](../adr/003-pdf-extract-on-client.md), [ADR 020](../adr/020-demo-account-shared-user.md), [research 006](../research/006-llm-embedding-providers.md) §4, [plan 003](../plan/003-tech-stack-and-prep.md) §5 |
| 작성 시점 상태 | 설계 완료, **구현 전**. 다른 엔지니어의 SamplePack 변경(`document_endpoint.dart` 등)이 병합된 뒤에 구현해야 충돌이 없다(§9). |

> 상태: 설계 완료·구현·배포 완료(9차, `2801184`). 재색인 켬(2026-10-16).

표기: ✅ 코드·실행으로 확인 · ⚠️ 미확인/추정. 줄 번호는 `main` HEAD `92d9835` + 작업 트리(SamplePack 진행 중) 기준.
프로토타입은 scratchpad의 `proto/`에서만 실행했다(`chunker_v2.dart`, `run.dart`, `fuzz.dart`, `big.dart`). 저장소 파일은 만들거나 고치지 않았다.

---

## 0. 핵심 결정 (8줄)

1. **노트 청크 = 줄/블록.** 목록 항목·문단 줄·인용 블록·표·코드 펜스 통째가 청크 1개, 제목은 청크가 아니라 경로, 6자 미만 조각만 이웃과 병합, 300자 초과 줄만 문장 단위로 쪼갠다. 겹침 없음. 청크 텍스트는 `body.substring(start, end)`와 **정확히 같다**(마크다운 기호 보존).
2. **맥락은 임베딩 전용.** `title: 문서제목 > H2 > H3 > 부모항목 | text: <청크>`. 저장·인용되는 텍스트에는 붙이지 않는다. 길이 상한 120자.
3. **PDF는 문장 묶음.** 줄바꿈은 공백으로 이어 붙이고 `다.` `요.` `?` `!` 등에서 끊어 목표 120자(최대 300자)로 묶는다. 페이지 경계 유지, 겹침 없음. 문서가 크면(>60,000자) 목표를 300으로 올려 임베딩 호출 수를 제한한다.
4. **스키마 변경 0.** `DocChunk` 필드 그대로. 경로·오프셋은 저장하지 않고 ask 시점에 순수 함수로 **재계산**한다(청크 텍스트 일치로 검증). `Citation`에 nullable `quoteStart`만 추가(비테이블 모델, `serverpod generate`만).
5. **구버전 표식 = `Document.embeddingModel`** 을 `<모델 id>#c2` 로. 구버전 판별은 `status='ready' AND embeddingModel <> 현재 태그`. 임베딩 공급자 교체도 같은 술어로 재색인된다(ADR 002 모델 전환 규칙의 빈틈을 메운다).
6. **재색인은 `_index`/`reindex`를 쓰지 않는 별도 경로.** 임베딩 → (한 트랜잭션) 행 잠금·버전 재확인 → 청크 교체 → `embeddingModel`만 갱신. `status`·`updatedAt`·`version`은 건드리지 않고, 실패하면 옛 청크 그대로 둔다.
7. **두 단 구조.** 작은 단위(위 규칙의 청크)만 임베딩·검색·인용하고, LLM에는 **큰 단위(노트=제목 구간, PDF=±2 창, 저장 안 함·읽을 때 계산)** 를 `EVIDENCE`/`CONTEXT`로 나눠 준다. `[n]`은 작은 단위 번호. top-k 8 → 16, 컨텍스트 6,000자, 문서당 3개 제한은 도입하지 않는다.
8. **배포 순서.** 청크 규칙(순수 함수) → 새 색인에 적용 → 재색인 잡(플래그 기본 끔 → 켬) → ask 컨텍스트·top-k 튜닝. 라이브 임베딩 평가는 단계마다 한 번.

---

## 1. 지금 코드에서 확인한 사실 (설계 전제)

| # | 사실 | 근거 |
|---|---|---|
| F1 | 청크는 `normalizeText`(공백 런→공백, 3줄 이상 개행→2줄)를 거치고 문단 사이를 `\n` 하나로 합치며 직전 청크 마지막 120자를 앞에 붙인다. **그래서 노트 청크는 본문의 부분 문자열이 아니다.** | ✅ `rag/chunker.dart:19-22, 44-60`; 프로토타입 §7.4 표 (노트 5개 모두 "아니오") |
| F2 | 지금 인용 하이라이트가 되는 것은 클라이언트 `findQuote`의 2·3단계(공백 허용 정규식)가 구제하기 때문이다. v2 청크는 1단계 `indexOf`에서 정확히 맞는다. | ✅ `markdown_live.dart:371-383`; §7.4 |
| F3 | 검색에는 `status`·`embeddingModel` 필터가 **없다**(소유자·프로젝트 범위만). 옛 청크와 새 청크가 같은 질의에서 함께 랭킹된다. | ✅ `ask_endpoint.dart:39-59` |
| F4 | `Document.embeddingModel`을 읽는 코드는 **없다**(쓰기만: 문서 삽입 시 `EmbeddingSpec.model`, `_index` 성공 시 `embedder.modelId`). 클라이언트도 읽지 않는다. | ✅ 서버·클라이언트 grep |
| F5 | `DocChunk.contentHash`를 읽는 코드는 **없다**(`_index`가 쓸 뿐). | ✅ grep (`document_endpoint.dart:456` 외 없음) |
| F6 | `_index`는 이미 "임베딩을 먼저 하고, 한 트랜잭션에서 옛 청크 삭제 + 새 청크 삽입"이다. 임베딩 실패 시 옛 청크는 남는다. 단 **실패하면 `status='failed'`+`lastError`** 를, 성공하면 **`updatedAt=now`** 를 쓴다. `list`는 `updatedAt desc`로 정렬한다. | ✅ `document_endpoint.dart:398-456`, `:477-481` |
| F7 | `reindex`는 `status='indexing'`을 먼저 쓰고(10분 지나면 `list`가 `failed/interrupted`로 바꿈), `_requireWrite`→`DemoGuard.requireNotSample`이 데모 샘플을 거부한다. | ✅ `:285-317`, `:346-362` |
| F8 | `DocPage`에 문서의 페이지별 원문(노트는 본문 1페이지)을 저장한다. PDF 원본 없이 재색인할 수 있다. `doc_page`는 2026-10-15 00:44 커밋(`3c9e3d5`)에서 생겼으므로 그 이전에 색인한 문서에는 없을 수 있다. | ✅ `_index:371-385`, `git log` ⚠️ 해당 문서 수는 운영 DB를 못 봐서 모름 |
| F9 | 배치: DeepInfra 32개, Gemini 100개씩 순차 요청, 요청당 60초 상한. `_staleIndexing` 주석은 "512 KiB 업로드 ≈ 19배치"를 가정한다. 색인은 업로드 요청 안에서 동기로 돈다. | ✅ `embedding_provider.dart`, `gemini_embedding_provider.dart`, `document_endpoint.dart:14-17` |
| F10 | 임베딩 공급자는 비밀값에 `geminiApiKey`가 있으면 Gemini(`gemini-embedding-001`, 768차원 절단), 없으면 DeepInfra EmbeddingGemma. 운영이 어느 쪽인지 코드로는 **알 수 없다.** | ✅ `rag_services.dart:26-34`, ⚠️ 운영 값 |
| F11 | Gemini 공급자는 문서 입력의 `title: (.*?) \| text: ` 를 정규식으로 떼어 `title` 파라미터로 보낸다. 제목 칸에 `\|` 가 들어가면 깨지므로 접두 규칙에서 치환한다. | ✅ `gemini_embedding_provider.dart:21-24, 71-78` |
| F12 | 서버 시드는 `contentHash`(본문 해시)를 표식으로 쓴다. 재색인은 `contentHash`를 바꾸지 않는다. | ✅ `sample_pack.dart:8-13`, ADR 020 §2 |
| F13 | 실제 PDF에서 뽑은 페이지 텍스트(PyMuPDF)는 하드 랩 줄바꿈이 있고, 러닝 헤더(`PageBlink guide · 1 / 3`)가 들어 있으며, 한글 공백이 빠진다(`문서추가하기`). 샘플의 `DocPage` 텍스트(상수)는 공백이 있다. | ✅ §7.6 (PyMuPDF; pdfium/pdfrx가 같은지는 ⚠️ 미확인) |

---

## 2. 노트 청크 규칙 (마크다운 블록 인지)

### 2.1 결론: 규칙 표

| 요소 | 단위 | 비고 |
|---|---|---|
| 일반 문단 줄 | **줄 1개 = 청크 1개** | 빈 줄·개행은 경계. 하드 랩 문단도 줄 단위(§2.4 한계) |
| 글머리·번호·체크리스트 항목 | **항목 1줄(+들여쓴 이어지는 줄) = 청크 1개** | `- [x]`/`[ ]` 표식은 청크 텍스트에 **그대로 둔다**(완료 여부가 질문 대상) |
| 중첩 목록 | 각 항목이 자기 청크 | 부모 항목 텍스트(≤40자)는 **맥락 경로에만** 붙는다 |
| 인용(`>`) | 연속한 `>` 줄 = 청크 1개 | |
| 코드 펜스 | **통째 1개**(≤600자). 초과 시 줄 경계로 ≤600자씩 묶음 | 줄 단위는 부적합(한 줄만으로는 의미 없음). 600자 넘는 한 줄은 그대로 둠 |
| 표 | 연속한 `\|` 줄 = 청크 1개, >300자면 줄 경계로 분할 | 분할 시 헤더 행 반복은 안 함(⚠️ 품질 미검증) |
| 제목(`#`) | **청크가 아니라 경로.** 내용 없는 말단 제목만 청크 | 자식 제목이 있는 제목(예: 문서 H1)은 청크가 아님 |
| 구분선·빈 줄·빈 체크박스·`>`만 있는 줄 | 청크 아님 | 보이는 글자가 0이면 버림 |
| 짧은 줄 | 보이는 글자(기호·강조 제외) **6자 미만**이면 같은 경로의 이웃과 병합(합계 ≤300) | 한글은 6자도 한 항목이라 임계값을 영어 기준(12자)보다 낮게 잡음 |
| 긴 줄·문단 | **300자 초과**일 때만 문장 단위로 묶음(목표 120자, 최대 300자), 문장이 300자를 넘으면 공백→하드 컷(서로게이트 쌍 보호) | PDF와 같은 분리 함수 |
| 겹침 | **없음** | 겹침은 인용 구절을 모호하게 하고 같은 문장이 두 청크에 중복된다. 맥락은 §4 인접 확장이 맡는다 |
| 큰 노트(>20,000자) | 같은 경로의 인접 줄을 300자까지 묶음(`packSmall`) | 줄 단위면 청크가 폭증한다. 119,180자 합성 노트 3,000청크 → 478청크 (§7.8) |

구현은 **본문을 가공하지 않는다**: `normalizeText`를 노트에는 쓰지 않고, 줄 오프셋을 따라가며 `[start, end)`를 잡은 뒤 앞뒤 공백만 잘라낸다. `\r\n` 본문도 청크 내부 개행을 그대로 보존한다.

### 2.2 청크 텍스트가 본문의 부분 문자열이어야 하는 이유와 검증

- 클라이언트 `findQuote`는 `text.indexOf(quote)` → 공백 허용 정규식(전체/8단어/5단어) 순이다(`markdown_live.dart:371-383` ✅). 마크다운 기호를 떼어 저장하면 1단계가 실패하고, 기호가 사라진 자리에서 단어 정규식도 어긋난다(예: `**Nov 18**`, `- [ ]`).
- **검증 1 (현행):** v1 청크는 노트 5개 모두 본문의 부분 문자열이 **아니었다**(문단 사이가 `\n` 하나로 합쳐지고 공백이 접힘). 현재는 2단계 공백 정규식이 구제한다(§7.4).
- **검증 2 (설계):** 프로토타입은 샘플 노트 5개 + PDF에서 `body.substring(start,end) == text`를 전부 통과했다. 추가로 **무작위 마크다운 퍼저**(4,000 본문 × 29,669 청크: 제목·중첩 목록·표·펜스·`\r\n`·300자 초과 줄·한글 650자 무공백 줄 등)에서 위반 0건: 부분 문자열, 순서·비중첩, 앞뒤 공백 없음, 비코드 청크 ≤300자, PDF 청크 공백 제거 후 부분 문자열.
- 청크 텍스트에는 선행 공백(들여쓰기)이 빠진다. 이는 부분 문자열 성질을 깨지 않는다.

### 2.3 대안과 기각 사유

| 대안 | 기각 이유 |
|---|---|
| 섹션(제목 단위) 청크 | CTO 결정이 줄 단위. 섹션=번호 목록 전체라 하이라이트가 다시 넓어진다 |
| 문장 단위(마침표 기준) | 노트에는 마침표 없는 줄이 많다(research 027 D3). 목록 항목이 문장이다 |
| 모든 줄을 무조건 청크(병합 없음) | `- [ ] 우유` 같은 5자 줄의 벡터는 잡음이다. 6자 임계값으로 충분 |
| 제목을 청크 본문에 붙임 | 인용(하이라이트)에 제목 줄이 딸려 들어가 근거가 넓어지고, 같은 제목이 모든 청크에 중복 저장된다 |
| 마크다운 기호 제거 후 저장 | `findQuote` 1단계 실패, 오프셋 복원 불가 |
| 겹침 120자 유지 | 줄 단위에서는 이웃 줄이 곧 겹침이다. 인용 모호·중복 |

### 2.4 알려진 한계

- **하드 랩 문단**(이메일 붙여넣기처럼 문장 중간에서 개행)은 줄 단위로 쪼개져 문장이 두 청크로 갈린다. 라이브 에디터의 일반 작성 방식에서는 드물다고 판단하지만 ⚠️ 데이터로 확인하지 못했다. 필요하면 "앞 줄이 문장 부호 없이 끝나고 다음 줄이 소문자로 시작" 같은 이어붙임 규칙을 후속으로 둔다.
- **세트엑스트 제목**(`===`/`---` 밑줄)은 인식하지 않는다. 라이브 에디터가 ATX만 다루기 때문이다 ⚠️ 코드 확인은 안 함.
- 같은 줄이 문서 안에 두 번 있으면 `indexOf`는 첫 번째를 찾는다 → §5 `quoteStart`.

---

## 3. 맥락 접두 (임베딩 입력 전용)

### 3.1 결론

임베딩 입력 문자열은 기존 형식을 그대로 쓰되 **`title:` 칸을 문서 제목만이 아니라 경로로 확장**한다.

```
title: <문서 제목> > <H2> > <H3> > <부모 목록 항목> | text: <청크 텍스트 그대로>
```

규칙:

1. 문서 제목을 맨 앞에 둔다(현행 `EmbeddingSpec.document(title, text)`와 같은 칸이라 ADR 002 형식 유지).
2. 본문 첫 H1이 문서 제목을 포함하거나 문서 제목에 포함되면 H1은 생략한다(`Sample · My to-do list` ⊃ `My to-do list`).
3. 경로 각 항목은 마크다운 강조·링크 기호를 벗기고 `nfc()` 정규화, ` | `는 ` / `로 치환(F11).
4. 부모 목록 항목은 40자에서 `…`로 자른다. 전체 120자를 넘으면 **앞쪽을 자르고 뒤쪽(가까운 제목)을 남긴다.**
5. PDF는 문서 제목만(경로 없음). 페이지 번호·러닝 헤더는 넣지 않는다.
6. 질의 쪽은 변경 없음(`task: search result | query: …`).
7. **저장·인용되는 `DocChunk.text`에는 접두를 붙이지 않는다.** 경로는 저장하지 않고 필요할 때 §4.3·§4.4처럼 재계산한다.

예(프로토타입 출력, §7.3):

```
title: Q4 launch plan > Numbers | text: - **Launch date:** moved to Nov 18
title: 샘플 · 할 일 목록 > 내 할 일 목록 > 이번 주 | text: - [ ] 금요일 팀 회의 발표 자료 마무리
```

### 3.2 문서 제목 포함 여부와 `title:` 칸 선택

- 제목은 이미 `title:` 칸에 들어간다(✅ `embedding_spec.dart`). 줄 단위 청크는 `- [ ] Finalize the release notes` 처럼 주어가 없어서 제목이 없으면 어느 계획의 이야기인지 알 수 없다. 그래서 제목을 **유지**하고 경로를 이어 붙인다.
- 경로를 `text:` 칸 앞이 아니라 `title:` 칸에 넣는 이유: (1) EmbeddingGemma의 문서 프롬프트가 원래 `title:` 칸을 제목/구조 정보용으로 쓴다(⚠️ 모델 카드 원문은 이번에 직접 조회하지 않았다. ADR 002·research 006이 인용한 형식 그대로 사용), (2) Gemini 공급자가 이 칸을 `title` 파라미터로 옮겨 RETRIEVAL_DOCUMENT 입력을 구성하므로 두 공급자에서 같은 방식으로 동작한다(F11), (3) `text:` 칸은 인용 원문과 1:1을 유지한다.

### 3.3 검색에 도움이 되는가 (판단 근거)

- **구조적 근거:** 줄 단위 청크는 사람이 문서를 읽을 때 쓰는 맥락(어느 섹션, 어느 계획)을 잃는다. 경로가 그 맥락을 복원한다. 샘플 질문 "이번 주에 남은 일은 뭐야?"의 근거 3줄에는 `이번 주`라는 단어가 **줄 안에 없다**(제목 줄에만 있다). 제목이 청크가 아니므로 경로 없이는 의미 신호가 없다.
- **정적 대리 측정(어휘 BM25, 임베딩 아님 ⚠️):** 같은 질문 8개에서 경로를 임베딩 입력에 넣었을 때 근거 청크 순위가 `이번 주…` 질문 59위 → 1위, 출시 전 할 일 질문 7위 → 6위로 올랐고 나머지는 같았다(§7.7). 어휘 점수라 밀집 임베딩에서의 효과는 보장하지 않는다.
- **일반 관행:** 제목 경로를 청크 임베딩에 붙이는 방식(헤딩 인지 청킹, contextual retrieval)은 널리 쓰이지만 이번 세션에서 문서를 직접 조회해 확인하지는 않았다 ⚠️.
- **위험:** 같은 제목 아래 청크들의 벡터가 서로 가까워져 한 섹션이 통째로 올라올 수 있다(목록형 질문에는 유리, 단일 사실 질문에는 노이즈). 라이브 A/B(§8)로 `경로 있음/없음`을 비교한다.

---

## 4. 두 단 구조: 작은 단위(검색·인용) / 큰 단위(맥락) 와 LLM 컨텍스트

CTO 지시: 줄 단위 청크는 맥락이 사라지므로 **세부 검색용 작은 단위**와 **LLM에 넘기는 맥락용 큰 단위**를 나눈다. 기존 설계 항목 3(LLM 컨텍스트 구성)을 이 구조로 통합했다.

### 4.1 결론

| 층 | 노트 | PDF | 임베딩 | 저장 | 하는 일 |
|---|---|---|---|---|---|
| **작은 단위** (= `DocChunk`) | 줄·목록 항목·인용/표/코드 블록 (§2) | 문장 묶음, 목표 120자·최대 300자 (§6.3) | **예** (`title: 경로 \| text: 청크`) | `DocChunk` 행 (현행 테이블, 필드 변경 없음) | 검색 대상, `[n]` 마커 대상, 인용 `quote`, 하이라이트 |
| **큰 단위** | **제목 구간**(해당 줄이 속한 가장 안쪽 `#` 제목부터 다음 제목 줄 직전까지, 첫 제목 앞은 머리글 구간). 1,000자 초과면 히트를 중심으로 구간 안에서 작은 단위를 1,000자까지 확장 | 같은 페이지에서 히트 **±2 작은 단위**(합쳐서 약 700~900자), 겹치는 창은 합침 | **아니오** | **저장하지 않음**(필요할 때 계산, §4.4) | LLM에게 주는 근거 본문(맥락) |

- 큰 단위는 **임베딩하지 않는다.** 이유: ① 벡터·임베딩 호출이 두 배가 된다 ② 큰 단위 벡터는 여러 사실이 섞여 흐려지고 같은 사실이 작은 단위와 큰 단위 두 곳에서 히트해 중복이 생긴다 ③ 구간 제목은 이미 작은 단위의 `title:` 경로로 임베딩에 들어간다(§3). 라이브 평가에서 작은 단위 Recall이 부족하다고 확인될 때만 "큰 단위도 임베딩"(parent-child 하이브리드)을 후속으로 검토한다.
- 인용 `quote`·하이라이트·`[n]`이 가리키는 대상은 **항상 작은 단위**다. 큰 단위는 LLM 입력에만 쓰인다.

### 4.2 저장 시점 시나리오 (노트 저장, PDF 업로드)

```
saveNote(body)                                  upload(pages)
  DocPage(page 1, body) 저장 (현행)                DocPage(page i, text) 저장 (현행)
  smalls = chunkNote(body, docTitle)              smalls = chunkPdfPage(i, text) per page
  inputs[i] = "title: {경로} | text: {small}"     inputs[i] = "title: {문서제목} | text: {small}"
  vectors = embed(해시 미스만)                    vectors = embed(해시 미스만)
  tx: DocChunk 교체(작은 단위만), embeddingModel='…#c2'
  (큰 단위: 만들지도 저장하지도 않음)
```

- **무엇을 임베딩하는가:** 작은 단위만(경로 접두 포함). **무엇을 저장하는가:** 작은 단위 `DocChunk`, 원문 `DocPage`/`Document.body`(현행). 큰 단위 경계와 오프셋은 저장하지 않는다(§4.4 비교).
- **PDF 큰 단위를 "페이지"로 두지 않은 이유:** 실제 레이아웃 텍스트에는 빈 줄이 거의 없어 문단 경계가 불안정하다(§7.6). 페이지 통째는 1,500~2,500자라 컨텍스트 예산을 빨리 소진한다. 페이지가 800자 이하이면 ±2 창이 사실상 페이지 전체가 된다.

### 4.3 질문 시점 시나리오 (단계별)

| 단계 | 동작 | 결과 |
|---|---|---|
| 1 | 질문 임베딩 `task: search result \| query: …` (현행) | 질의 벡터 |
| 2 | 소유자·프로젝트 범위 안에서 **작은 단위 top-k**(k=16) 코사인 검색 (현행 쿼리, 상수만 변경) | `hits[0..k)` 순위순 |
| 3 | 히트 문서의 본문(노트는 `Document.body` — 이미 `find`로 읽음, PDF는 해당 페이지의 `DocPage`)을 읽고 같은 순수 함수로 작은 단위 목록을 **재계산**, `chunks[ordinal].text == hit.text`이면 위치(오프셋)·경로 확보 (불일치면 확장 없이 현행 동작) | 히트별 `(path, start, end)` |
| 4 | 히트마다 큰 단위로 **확장**: 노트 = 제목 구간, PDF = ±2 창 | `(히트 → 큰 단위 키)` |
| 5 | **같은 큰 단위 중복 제거**: 큰 단위 키(문서·페이지·구간 시작·끝)로 묶고, 첫(최상위) 히트가 큰 단위 본문을 한 번만 싣는다. 같은 큰 단위의 나머지 히트는 근거 줄만 따로 둔다 | 큰 단위 목록 + 히트 매핑 |
| 6 | **예산 적용**(총 6,000자): 순위 낮은 큰 단위의 맥락부터 빼고(근거 줄은 유지), 그래도 넘으면 순위 낮은 히트부터 제거 | 최종 `hits'`(길이·순서가 `sources`와 동일) |
| 7 | LLM에 전달: 출처마다 `evidence`(작은 단위)와 `context`(큰 단위) (§4.5 프롬프트) | `[n]` = `hits'[n-1]` |
| 8 | 답변 스트림에서 `[n]` 감지 → `hits'[n-1]` 매핑 (현행 로직 `ask_endpoint.dart:132-137`) → `Citation(index: n, quote: hit.text, quoteStart: hit.start)` | 인용은 작은 단위 |

의사코드(핵심만):

```dart
final hits = await vectorSearch(question, limit: 16);          // 작은 단위
final docs = await loadDocs(hits);                              // Document(+body), 필요한 DocPage
final plan = <SourcePlan>[];
final claimed = <String>{};                                     // 이미 싣은 큰 단위
for (final h in hits) {                                         // 순위순
  final ctx = resolve(h, docs);          // 재계산·검증: path, start, big(range) | null
  final big = ctx?.big;                  // null이면 확장 없음(옛 청크·불일치)
  final first = big != null && claimed.add(big.key);
  plan.add(SourcePlan(hit: h, path: ctx?.path, context: first ? big.text : null,
                      contextRef: big != null && !first ? big.firstIndex : null));
}
final fitted = fitBudget(plan, maxChars: 6000);  // 맥락부터 제거 → 히트 제거
final sources = [for (final p in fitted) p.toPassage()];        // sources[i] ↔ fitted[i].hit
llm.answer(question, sources);                                  // [n] == fitted[n-1]
// 인용: hit = fitted[n-1].hit; quote = hit.text; quoteStart = fitted[n-1].start
```

핵심 불변식: **마커 번호는 작은 단위(히트) 번호다.** 큰 단위는 번호를 갖지 않는다. 그러므로 같은 큰 단위에 히트가 3개 있으면 `[1][2][3]` 세 개 마커가 있고 각각 자기 줄을 인용한다.

### 4.4 큰 단위를 어떻게 구하나: 계산 vs 저장

| 항목 | **A. 읽을 때 계산 (추천)** | B. 컬럼·오프셋 저장 |
|---|---|---|
| 방식 | `Document.body`/`DocPage`에서 같은 청커를 다시 돌려 작은 단위의 위치를 찾고 제목 구간·±2 창을 계산 | `DocChunk`에 `bigStart`, `bigEnd`(또는 `DocParent` 테이블) 저장 |
| 스키마 | **변경 없음** | **마이그레이션 필요**(nullable 컬럼 추가). 값은 재색인이 채움 |
| 비용 | ask당 히트 문서 수만큼 청커 실행(수십 µs~ms, 노트는 이미 `body`를 읽음). PDF는 `DocPage` 1쿼리 추가 | 쓰기 증가(청크마다 2 정수), 읽기는 추가 계산 없음 |
| 불일치 위험 | 색인 이후 본문 편집(수 초) → 텍스트 검증 실패 시 확장 없이 후퇴 | 같은 문제: 오프셋도 색인 시점 본문 기준이라 편집 시 어긋남 → 본문과 비교해야 함 |
| 규칙 변경 | 청커/큰 단위 규칙을 바꿔도 **재색인 없이** 즉시 반영(큰 단위는 색인 산출물이 아님). 작은 단위가 바뀔 때만 `#c` 버전 증가 | 큰 단위 규칙만 바꿔도 전체 재색인 |
| 롤백 | 상수·플래그 | 컬럼 유지 + 재색인 |
| 구버전(v1) 청크 | 텍스트 불일치 → 자동으로 확장 없음 | 컬럼이 null → 같은 후퇴 |

**추천: A(계산).** 큰 단위는 "읽는 방식"의 문제이지 색인 산출물이 아니므로 규칙을 자유롭게 튜닝할 수 있어야 하고, 저장해도 본문과 대조 검증이 필요해 이점이 작다. B는 ask 지연이 측정으로 문제가 되거나 재계산 불일치 후퇴가 잦다고 확인될 때의 예비안이다.

### 4.5 LLM 컨텍스트에서 "여기가 근거 줄"을 표시하는 프롬프트 구성

설계 원칙: **번호는 근거 줄에만 붙이고, 맥락은 번호 없이 따로 둔다.** 모델이 맥락 본문 안의 숫자(`1. Oct 28…`)를 마커로 오해하지 않도록 근거와 맥락을 라벨로 분리한다.

시스템 프롬프트 변경(현행 `_system`에 두 문장 추가):

```
Each source has an EVIDENCE line (the passage to cite) and, when available, its
surrounding CONTEXT. Cite only the number of the source whose EVIDENCE supports
the sentence; use CONTEXT only to understand it. Cite like [1] or [2][3].
```

사용자 메시지(질문 1, 샘플 `Q4 launch plan`):

```
Sources:

[1] Q4 launch plan › Numbers (note)
EVIDENCE: - **Launch date:** moved to Nov 18
CONTEXT:
- **Marketing budget:** ₩12M for Q4
- **Launch date:** moved to Nov 18
- **Beta testers:** 20 people

[2] Q4 launch plan › Numbers (note)
EVIDENCE: - **Marketing budget:** ₩12M for Q4
(same context as [1])

[3] Q4 launch plan › Timeline (note)
EVIDENCE: 3. Nov 18: public launch
CONTEXT:
1. Oct 28: feature freeze
2. Nov 4: beta invites
3. Nov 18: public launch

Question: When is the launch, and what is the budget?
```

- 마커 `[n]`은 헤더 줄에만 나온다. 맥락 본문은 원문 그대로 둔다(번호 목록이 마커와 혼동되지 않도록 `[n]`은 대괄호, 목록은 `1.`).
- 이 구성에서도 현행 마커 정규식 `\[(\d{1,2})\]`(`openrouter_llm_provider.dart:28`)가 그대로 동작한다. 단 **맥락 본문에 사용자가 `[3]` 같은 문자열을 쓰면** 모델이 따라 쓸 수 있다는 점은 현행과 같은 한계다.
- **대안(인라인 표시):** 큰 단위 본문 안의 근거 줄 앞에 `[1]▸`를 붙이는 방식. 한 큰 단위에 여러 히트가 있을 때 한눈에 들어오지만 맥락 본문이 원문과 달라져 `cited_text` 일관성이 깨지고(Claude 경로) 마크다운 목록을 오염시킨다. 라이브 평가에서 `EVIDENCE/CONTEXT` 방식의 모델 준수율이 낮을 때만 전환한다.
- **구현 변경점:** `SourcePassage`에 `context` 필드(nullable) 추가(`llm_provider.dart`), OpenRouter 프로바이더의 렌더링 한 곳, Claude 직접 경로는 passage 텍스트를 `evidence`로 두고 큰 단위는 `context`(문서 블록의 비인용 컨텍스트 필드로 보내는 방식 ⚠️ API 지원 미확인) 또는 같은 텍스트 블록에 이어 붙이는 대안을 선택한다.

### 4.6 한도 · 중복 제거 · 대안

| 항목 | 값 | 근거 |
|---|---|---|
| top-k | **8 → 16** | 작은 단위는 평균 25~110자(§7.1). §7.7: "출시 전 할 일" 질문의 근거가 어휘 대리 검색에서 6~7위까지 밀림 → 8개로는 부족 |
| 컨텍스트 총 길이 | **6,000자** (현행 최악 8×900=7,200자) | 비용·지연·무료 모델 컨텍스트. 근거 줄은 항상 유지, 맥락부터 줄임 |
| 큰 단위 길이 | 노트 구간 ≤1,000자(초과 시 창), PDF 창 ≤약 900자 | 샘플 노트의 제목 구간은 10~346자(§7.9) |
| 중복 제거 | 큰 단위 키 기준 한 번만 싣기 | §4.3 5단계 |
| 문서당 상한 | **도입하지 않음** | plan 003 §5의 "문서당 최대 3개"는 코드에 없고, 목록형 답변은 한 노트의 여러 줄이 필요 |
| 거리 임계값 | 도입하지 않음 | 근거 없는 `<0.6`. 평가셋 후 결정 |
| 출처 제목 | 노트 `문서제목 › 경로 (note)`, PDF `문서제목 (p.N)` | 경로를 LLM에도 보여 줌 |

| 대안 | 기각 이유 |
|---|---|
| 큰 단위에 번호를 붙이고 모델이 큰 단위 번호를 인용 | 인용을 작은 단위로 되돌리려면 모델의 문장 선택이 필요해진다(B1, 폐기됨) |
| 맥락 없이 k만 키움 | 목록 항목이 조건과 값으로 나뉜 서술형에서 근거가 잘림 |
| 인용도 큰 단위 | CTO 결정(하이라이트를 좁힘)과 모순 |
| 큰 단위를 `\n`으로 이어 붙인 청크 모음 | 본문과 달라져 Claude 경로 `cited_text`가 본문의 부분 문자열이 아니게 됨. 노트 큰 단위는 **본문의 연속 구간**으로 만든다 |

### 4.7 멀티턴 대비 (후속 질문)

현재는 질문 한 개씩 독립이다(`ask`에 대화 이력 없음 ✅). 이전 질문을 검색 질의에 합치면 줄 단위 작은 단위는 질의 이동(topic drift)에 더 민감하다: 합친 질의가 이전 주제 쪽 줄을 끌어올 수 있다. 권장은 **현재 질문만 임베딩하거나, LLM이 다시 쓴 독립 질문을 임베딩**하고, 합친 질의를 쓴다면 `현재`와 `이전+현재` 두 질의의 top-k를 합집합으로 쓰는 것이다. 마커 번호는 턴마다 독립이고 큰 단위·인용 규칙은 변하지 않는다.

### 4.8 `ask_endpoint.dart`에서의 불일치 후퇴

색인과 본문이 어긋나면(편집 직후, 아직 옛 청크) `resolve`가 null을 돌려 해당 히트는 경로·큰 단위 없이 `EVIDENCE`만 싣는다. 이 경우는 현행 동작과 같다.

---

## 5. 인용 오프셋: 중복 줄 처리 (결정 필요, 추천안 포함)

§7.5: 본문에 `- [ ] 전화하기`가 두 섹션에 있으면 두 번째 청크의 `quote`를 `findQuote`로 찾을 때 첫 번째 줄을 가리킨다(실행으로 확인 ✅).

| 선택지 | 내용 | 비용 | 평가 |
|---|---|---|---|
| **A. `Citation.quoteStart` (추천)** | `Citation`에 `int? quoteStart`(노트 본문 UTF-16 오프셋, PDF·불명은 null) 추가. 서버가 §4.4의 재계산으로 채움. 클라이언트는 `text.startsWith(quote, quoteStart)`가 참이면 그 위치, 아니면 기존 `findQuote` | 비테이블 모델이므로 **DB 마이그레이션 없음**, `serverpod generate`(서버·클라이언트 생성물)만. 서버 +~15줄, 클라이언트 +~10줄 | 구 클라이언트는 필드를 무시해야 한다. 생성된 `Citation.fromJson`은 알려진 키만 읽는다(✅ 코드 확인: `citation.dart:36-45`). 실제 와이어에서의 동작은 ⚠️ 미확인 |
| B. `DocChunk`에 `startOffset`·`context` 컬럼 | 재계산 불필요 | **테이블 마이그레이션 필요**(nullable 컬럼 추가 + 백필은 재색인과 합쳐짐). 프로토콜 변경은 같음 | 재계산이 불안정하다고 판명될 때의 예비안 |
| C. 보류 | 첫 출현 매칭을 알려진 한계로 둠 | 0 | 체크리스트에서 같은 줄이 반복되는 노트(예: 매일 같은 항목)에서 틀린 줄이 칠해진다 |

추천 시점: §10 단계 4(ask 변경)와 함께. 표시(U2)와 `findQuote` 클라이언트 변경은 별도 단계다.

PDF는 페이지가 이미 정해져 있고 중복 문장이 드물어 오프셋 없이 공백 무시 매칭만 쓴다(§6.4).

---

## 6. 저장 모델, PDF 규칙

### 6.1 `DocChunk` / `Document` 필드

| 항목 | 변경 | 설명 |
|---|---|---|
| `DocChunk.text` | 의미만 변경 | 노트: 본문 부분 문자열. PDF: 공백이 접힌 문장 묶음. **인용 `quote` = `hit.text`**(OpenRouter 경로, `ask_endpoint.dart:147`). Claude 직접 경로의 `cited_text`는 소스 텍스트의 부분 문자열 |
| `DocChunk.ordinal` | 그대로 | 문서 전체에서 0..n-1 연속(페이지 순). 노트는 페이지 1개이므로 재계산 인덱스와 같다 |
| `DocChunk.contentHash` | **정의 변경(권장)** | `sha256('<태그>\n<title 칸>\n<text>')` — 임베딩 입력의 해시. 저장 시 기존 청크와 해시가 같으면 **벡터를 재사용**하고 미스만 임베딩한다(노트 한 줄 수정 시 임베딩 1개). 읽는 코드가 없으므로(F5) 안전. 기존 행은 옛 정의라 전부 미스 → 재임베딩(무해) |
| 경로·시작 오프셋 | **저장하지 않음** | §4.4 재계산 |
| `Document.embeddingModel` | **값 형식 변경** | `<modelId>#c2` (§7.1). 컬럼은 그대로 |
| `Citation` | `int? quoteStart` 추가(§5 A) | 비테이블 |

**DB 스키마 변경: 없음**(`Citation`은 `table:`이 없는 직렬화 모델). `serverpod generate`만 필요하고 `create-migration`은 필요 없다.

### 6.2 `embeddingModel` 태그가 의미를 갖는 조건

삽입 경로(`upload`, `saveNote`, `sample_seed`)는 색인 전에 `EmbeddingSpec.model`(맨 모델명)을 쓰고, 색인이 성공해야만 `<modelId>#c<N>`으로 바뀐다. 따라서 태그는 **`status='ready'`일 때만** 신뢰한다. 구버전 판별은 `ready`만 대상으로 한다.

### 6.3 PDF 청크 규칙

1. **줄바꿈 → 공백(재흐름).** PDF 텍스트의 개행은 레이아웃이다. 빈 줄 또는 글머리 기호(`•`, `-`, `1.`, `(1)` 등)로 시작하는 줄에서만 문단을 나눈다.
2. **문장 분리** (마침표 뒤 공백 또는 문장 끝일 때 분리):
   - 종결: `.` `!` `?` `…` `。` `！` `？`(전각은 공백 없이도 분리), 닫는 따옴표·괄호(`" ' ” ’ ) ] 」 』`)는 문장에 포함. 한국어 `다.` `요.` `죠.` `?` `!`는 모두 이 규칙으로 처리된다(별도 사전 없음).
   - **보호:** 소수·버전(`3.14`, `v1.2.3`)은 점 뒤에 공백이 없어 분리되지 않음, 1~3자리 숫자 뒤 점(목록 번호 `1.`), 약어(`e.g` `i.e` `etc` `vs` `Dr` `Mr` `Fig` `No` `p` `pp` `Inc` 월 약어 `Nov` 등), 한 글자 영문 뒤 점(이니셜), 점 뒤 다음 단어가 영문 소문자로 시작하는 경우.
   - 한계: `3. 결과`처럼 4자리 이상 숫자 뒤의 점이나 한국어 약어(`약 5 m.`)는 규칙 밖이다. 분리가 잘못돼도 청크는 여전히 본문의 부분 문자열이다.
3. **묶음:** 문장을 순서대로 **목표 120자**가 넘을 때까지 담고 **최대 300자**를 넘기지 않는다. 문장이 300자를 넘으면 공백(창 150~300자 중 마지막 공백)에서, 공백이 없으면 300자에서 자른다(서로게이트 쌍 보호). 문단 경계는 넘지 않되, 40자 미만의 짧은 문단(제목 같은)은 **다음 문단 앞에 붙인다**. 마지막 40자 미만 꼬리는 앞 청크에 합친다.
4. **큰 문서 적응:** 페이지 합계가 60,000자를 넘으면 목표를 **300**으로 올린다. 이유는 §6.5.
5. 겹침 없음. 페이지 경계 유지(청크는 한 페이지, `page` 필드 그대로).

### 6.4 `PdfPageText` 매칭을 위한 공백 정규화

- 저장된 청크는 공백이 접혀 있고(`" "` 단일) 원문의 개행 위치 정보가 없다. 뷰어의 `PdfPageText.fullText`와 **공백 무시 비교**가 필요하다.
- **매칭 규칙(클라이언트, 다음 단계 구현):** 양쪽에서 **모든 공백 문자를 제거**하고 제거 전 인덱스 맵(제거 후 위치→원문 위치)을 유지한다. 청크의 공백 제거 문자열을 페이지 공백 제거 문자열에서 찾고, 맵으로 원문 구간을 복원해 `charRects`를 칠한다.
- **공백을 "접는 것"만으로는 부족하다.** 실제 데모 PDF의 한글 구간은 PyMuPDF로 뽑으면 공백이 없다(`문서추가하기`, `직접쓴노트와올린PDF에질문할수있도록`). 서버에 저장된 샘플 `DocPage`는 공백이 있는 상수라 서로 다르다(F13). 사용자 업로드 PDF는 클라이언트가 같은 추출기로 올리므로 같다고 기대하지만 ⚠️ pdfrx(pdfium)가 PyMuPDF와 같은 공백을 내는지는 미확인이다.
- **러닝 헤더가 첫 청크에 붙는다.** 레이아웃 텍스트에서는 `PageBlink guide · 1 / 3 Adding your documents …`(§7.6)가 페이지 첫 청크가 된다. 매칭에는 문제없지만(부분 문자열) 임베딩에는 잡음이다. 반복 헤더 제거는 이번 범위 밖이다(청크가 연속 구간이어야 하므로 중간 줄 삭제는 하지 않고, 하려면 그 줄에서 청크를 끊는 방식).

### 6.5 PDF 임베딩 호출 수 / 요청 시간

색인은 업로드 요청 안에서 순차 배치로 돈다(F9). 청크가 많아지면 요청이 길어진다.

| 입력 | v1 청크 | v2 목표 120 | v2 목표 300 | 배치(32) v1 → 120 → 300 |
|---|---|---|---|---|
| 합성 영문 산문 500,000자(≈512 KiB 업로드 상한) | ≈556 (900자/청크 추정) | 2,694 | 1,796 | ≈18 → 85 → 57 |
| 샘플 PDF 3페이지(1,973자) | 3 | 19 | 17 | 1 → 1 → 1 |

- 한 배치 지연은 측정하지 못했다 ⚠️. 배치당 1~2초라고 가정하면 85배치는 1.5~3분으로 `_staleIndexing`(10분) 안이지만 게이트웨이 요청 시간 한도는 ⚠️ 미확인이다.
- 그래서 **적응 규칙**(합계 >60,000자면 목표 300)을 두어 큰 문서의 배치를 v1의 약 3배 이내로 묶는다. 60,000자 이하에서는 청크 수가 v1 최악(≈600청크, 19배치) 수준을 넘지 않는다.
- 더 줄이려면 임베딩 배치를 4개 병렬로 보내는 변경이 별도로 가능하다(이번 범위 밖, 공급자 레이트 한도 ⚠️ 미확인).
- 목표 120과 200의 차이: 샘플 PDF 한국어 근거 질문의 인용 길이가 50자(120)와 174자(200)로 달라진다. 하이라이트 정밀도를 우선해 **120**을 기본으로 한다.

---

## 7. 프로토타입 시뮬레이션 결과

실행: `dart --packages=<app/.dart_tool/package_config.json> proto/run.dart` (scratchpad). 입력은 작업 트리의 `sample_pack.dart`(SamplePack 진행 중 상태)에서 복사한 노트 본문·PDF 페이지 상수와, 실제 `web/samples/pageblink-guide.pdf`를 PyMuPDF로 추출한 레이아웃 텍스트다. v1은 저장소의 `chunker.dart` 복사본이다.

### 7.1 청크 수 (노트·PDF 페이지별), v1(현행) → v2(설계)

| 문서 | 종류 | 길이(자) | v1 청크 | v2 청크 | v2 길이 min/평균/max |
|---|---|---|---|---|---|
| PageBlink tour: try it in 5 minutes | note | 728 | 1 | 10 | 39 / 63 / 103 |
| Q4 launch plan | note | 439 | 1 | 11 | 22 / 34 / 58 |
| Weekly sync: week 3 of October | note | 430 | 1 | 9 | 19 / 38 / 51 |
| PageBlink guide | pdf | 1973 | 3 | 19 | 42 / 102 / 203 |
| Sample · My to-do list | note | 347 | 1 | 8 | 22 / 36 / 49 |
| 샘플 · 할 일 목록 | note | 216 | 1 | 8 | 13 / 22 / 29 |

부분 문자열 검증(노트: `body.substring(start,end)==text`, PDF: 공백 제거 후 포함): **전부 통과**


### 7.2 청크별 상세

#### PageBlink tour: try it in 5 minutes (note)

| # | p | 종류 | 맥락 경로(임베딩 전용) | 청크 텍스트(저장·인용) | 길이 |
|---|---|---|---|---|---|
| 0 | 1 | para |  | `PageBlink is **Markdown notes + PDFs you can ask questions to**. Every answer links back to its source.` | 103 |
| 1 | 1 | list | Try these | `- [x] Open this note, you are reading a sample` | 46 |
| 2 | 1 | list | Try these | `- [ ] Ask: *When is the launch, and what is the budget?*` | 56 |
| 3 | 1 | list | Try these | `- [ ] Tap ⚡ on the answer to jump to the exact line` | 51 |
| 4 | 1 | list | Try these | `- [ ] Create your own note with **New note** (up to 5 in the demo)` | 66 |
| 5 | 1 | list | What the editor understands | `1. **Bold**, *italic*, ~~strikethrough~~ and `inline code`` | 58 |
| 6 | 1 | list | What the editor understands | `2. Bullet lists, numbered lists and `- [ ]` checklists` | 54 |
| 7 | 1 | list | What the editor understands | `3. Quotes with `>` and rules with `---`` | 39 |
| 8 | 1 | list | What the editor understands | `4. Links, like [PageBlink on GitHub](https://github.com/biyott/pageblink)` | 73 |
| 9 | 1 | para | What the editor understands | `Samples are locked. Type these markers in your own note and watch them come alive.` | 82 |

#### Q4 launch plan (note)

| # | p | 종류 | 맥락 경로(임베딩 전용) | 청크 텍스트(저장·인용) | 길이 |
|---|---|---|---|---|---|
| 0 | 1 | quote |  | `> Goal: ship the new onboarding before the holiday freeze.` | 58 |
| 1 | 1 | list | Numbers | `- **Marketing budget:** ₩12M for Q4` | 35 |
| 2 | 1 | list | Numbers | `- **Launch date:** moved to Nov 18` | 34 |
| 3 | 1 | list | Numbers | `- **Beta testers:** 20 people` | 29 |
| 4 | 1 | list | Timeline | `1. Oct 28: feature freeze` | 25 |
| 5 | 1 | list | Timeline | `2. Nov 4: beta invites` | 22 |
| 6 | 1 | list | Timeline | `3. Nov 18: public launch` | 24 |
| 7 | 1 | list | To do | `- [x] Book the launch-day support rota` | 38 |
| 8 | 1 | list | To do | `- [ ] Finalize the release notes` | 32 |
| 9 | 1 | list | To do | `- [ ] Send the beta invite emails` | 33 |
| 10 | 1 | para | To do | `Details: https://github.com/biyott/pageblink` | 44 |

#### Weekly sync: week 3 of October (note)

| # | p | 종류 | 맥락 경로(임베딩 전용) | 청크 텍스트(저장·인용) | 길이 |
|---|---|---|---|---|---|
| 0 | 1 | para |  | `Attendees: Mina, Joon, Seoyeon` | 30 |
| 1 | 1 | list | Decisions | `1. Launch date confirmed for **Nov 18**` | 39 |
| 2 | 1 | list | Decisions | `2. Limit the beta to 20 testers` | 31 |
| 3 | 1 | list | Decisions | `3. ~~Deploy twice a week~~ → deploy once a week` | 47 |
| 4 | 1 | list | Action items | `- [ ] Draft the release notes (Mina, by Friday)` | 47 |
| 5 | 1 | list | Action items | `- [ ] Send the beta invite email (Joon)` | 39 |
| 6 | 1 | list | Action items | `- [x] Check staging` | 19 |
| 7 | 1 | para | Notes | `Staging deploy command: `./deploy.sh --env staging`` | 51 |
| 8 | 1 | para | Notes | `More at https://github.com/biyott/pageblink` | 43 |

#### PageBlink guide (pdf)

| # | p | 종류 | 맥락 경로(임베딩 전용) | 청크 텍스트(저장·인용) | 길이 |
|---|---|---|---|---|---|
| 0 | 1 | pdf |  | `Adding your documents PageBlink turns what you write and what you upload into something you can ask questions of.` | 113 |
| 1 | 1 | pdf |  | `Write a note: tap New note, write in Markdown, and save. A note can be searched a few seconds after saving.` | 107 |
| 2 | 1 | pdf |  | `Upload a PDF: tap Upload PDF and choose a file. PageBlink reads the text page by page, so an answer can point to the exact page.` | 128 |
| 3 | 1 | pdf |  | `Scanned PDFs without text cannot be searched.` | 45 |
| 4 | 1 | pdf |  | `문서 추가하기 직접 쓴 노트와 올린 PDF에 질문할 수 있도록 PageBlink가 내용을 정리해 둡니다.` | 58 |
| 5 | 1 | pdf |  | `노트 쓰기: 새 노트를 누르고 마크다운으로 쓴 뒤 저장하세요. 저장하고 몇 초 뒤부터 검색됩니다.` | 54 |
| 6 | 1 | pdf |  | `PDF 올리기: PDF 올리기를 누르고 파일을 고르세요. 페이지별로 글자를 읽기 때문에 답변이 정확한 페이지를 가리킵니다. 글자가 없는 스캔본 PDF는 검색할 수 없습니다.` | 96 |
| 7 | 2 | pdf |  | `Asking questions Open the Ask tab and type a question in plain words, for example: What does the guide say about uploading a PDF?` | 129 |
| 8 | 2 | pdf |  | `PageBlink finds the most relevant passages in your notes and PDFs and writes an answer from them only. If nothing relevant is found, it tells you instead of guessing.` | 166 |
| 9 | 2 | pdf |  | `Tip: mention a topic or a document name in your question to get a more precise answer.` | 86 |
| 10 | 2 | pdf |  | `질문하기 질문 탭을 열고 평소 말투로 질문을 적어 보세요. 예: 가이드에서 PDF 올리기는 어떻게 설명하나요?` | 61 |
| 11 | 2 | pdf |  | `PageBlink는 내 노트와 PDF에서 가장 관련 있는 부분을 찾아 그 내용만으로 답변을 만듭니다. 관련 내용이 없으면 지어내지 않고 못 찾았다고 알려 줍니다.` | 90 |
| 12 | 2 | pdf |  | `팁: 질문에 주제나 문서 이름을 넣으면 더 정확한 답변을 받을 수 있습니다.` | 42 |
| 13 | 3 | pdf |  | `Sources and the demo account Every answer carries small lightning-bolt markers. Tap one to jump to the note or the PDF page that the answer came from, and check it yourself.` | 173 |
| 14 | 3 | pdf |  | `About the demo account: everyone who tries the demo shares one account, so please do not enter personal information. You can create up to 5 notes or PDFs of your own, and they are removed after 24 hours.` | 203 |
| 15 | 3 | pdf |  | `The sample items cannot be edited or deleted. Questions are limited to 50 per day across all demo visitors. Sign up to keep your work.` | 134 |
| 16 | 3 | pdf |  | `출처와 데모 계정 답변마다 작은 번개 모양 표시가 붙습니다. 누르면 답변의 근거가 된 노트나 PDF 페이지로 바로 이동하니 직접 확인해 보세요.` | 80 |
| 17 | 3 | pdf |  | `데모 계정 안내: 데모를 체험하는 모든 사람이 하나의 계정을 함께 쓰므로 개인정보는 넣지 마세요. 직접 만들 수 있는 노트와 PDF는 최대 5개이며, 24시간 뒤에 삭제됩니다. 샘플 항목은 수정하거나 삭제할 수 없습니다.` | 123 |
| 18 | 3 | pdf |  | `질문은 데모 방문자 전체가 하루 50회까지 할 수 있습니다. 가입하면 계속 쓸 수 있어요.` | 50 |

#### Sample · My to-do list (note)

| # | p | 종류 | 맥락 경로(임베딩 전용) | 청크 텍스트(저장·인용) | 길이 |
|---|---|---|---|---|---|
| 0 | 1 | list | Today | `- [x] Reply to Sam about the venue` | 34 |
| 1 | 1 | list | Today | `- [x] Buy coffee beans` | 22 |
| 2 | 1 | list | Today | `- [ ] Send the invoice to Acme (due 5 pm)` | 41 |
| 3 | 1 | list | This week | `- [ ] Book the dentist (call before Wednesday)` | 46 |
| 4 | 1 | list | This week | `- [ ] Finish the slides for Friday's team meeting` | 49 |
| 5 | 1 | list | This week | `- [ ] Renew passport (needs 2 photos)` | 37 |
| 6 | 1 | list | Later | `- [ ] Plan a weekend trip to Busan` | 34 |
| 7 | 1 | list | Later | `- [ ] Clean out the garage` | 26 |

#### 샘플 · 할 일 목록 (note)

| # | p | 종류 | 맥락 경로(임베딩 전용) | 청크 텍스트(저장·인용) | 길이 |
|---|---|---|---|---|---|
| 0 | 1 | list | 내 할 일 목록 > 오늘 | `- [x] 민수에게 장소 관련 답장 보내기` | 23 |
| 1 | 1 | list | 내 할 일 목록 > 오늘 | `- [x] 커피 원두 사기` | 14 |
| 2 | 1 | list | 내 할 일 목록 > 오늘 | `- [ ] 한빛상사에 청구서 보내기 (오후 5시까지)` | 29 |
| 3 | 1 | list | 내 할 일 목록 > 이번 주 | `- [ ] 치과 예약하기 (수요일 전에 전화)` | 25 |
| 4 | 1 | list | 내 할 일 목록 > 이번 주 | `- [ ] 금요일 팀 회의 발표 자료 마무리` | 24 |
| 5 | 1 | list | 내 할 일 목록 > 이번 주 | `- [ ] 여권 갱신하기 (사진 2장 필요)` | 24 |
| 6 | 1 | list | 내 할 일 목록 > 나중에 | `- [ ] 주말 부산 여행 계획 세우기` | 21 |
| 7 | 1 | list | 내 할 일 목록 > 나중에 | `- [ ] 창고 정리하기` | 13 |


### 7.3 임베딩 입력 문자열 예 (v2)

- `title: Q4 launch plan > Numbers | text: - **Launch date:** moved to Nov 18`
- `title: Q4 launch plan > Timeline | text: 2. Nov 4: beta invites`
- `title: Q4 launch plan > To do | text: - [ ] Finalize the release notes`
- `title: 샘플 · 할 일 목록 > 내 할 일 목록 > 이번 주 | text: - [ ] 금요일 팀 회의 발표 자료 마무리`
- `title: PageBlink guide | text: Write a note: tap New note, write in Markdown, and save. A note can be searched a few seconds after saving.`


### 7.4 v1(현행) 청크가 본문의 부분 문자열인가 / findQuote 단계

| 문서 | v1 청크가 본문 부분 문자열 | findQuote(v1 quote) | v2 청크 부분 문자열 | findQuote(v2 quote) |
|---|---|---|---|---|
| PageBlink tour: try it in 5 minutes | **아니오** | ws-tolerant(134 words) | 예(전부) | exact |
| Q4 launch plan | **아니오** | ws-tolerant(78 words) | 예(전부) | exact |
| Weekly sync: week 3 of October | **아니오** | ws-tolerant(74 words) | 예(전부) | exact |
| Sample · My to-do list | **아니오** | ws-tolerant(78 words) | 예(전부) | exact |
| 샘플 · 할 일 목록 | **아니오** | ws-tolerant(70 words) | 예(전부) | exact |


### 7.5 중복 줄에서 indexOf 모호성 (오프셋 힌트 필요성)

본문: `## 오늘⏎- [ ] 전화하기⏎⏎## 내일⏎- [ ] 전화하기⏎` → 청크 2개: #0 [6,16) `- [ ] 전화하기`, #1 [24,34) `- [ ] 전화하기`
두 번째 청크(#1, 오프셋 24)를 findQuote로 찾으면 시작 6(exact) → **첫 번째 줄을 가리킴(오답)**


### 7.6 실제 PDF 레이아웃 텍스트(줄바꿈·헤더 포함, PyMuPDF 추출)에 PDF 규칙 적용

| p | # | 길이 | 청크 텍스트 |
|---|---|---|---|
| 1 | 0 | 137 | `PageBlink guide · 1 / 3 Adding your documents PageBlink turns what you write and what you upload into something you can ask questions of.` |
| 1 | 1 | 155 | `Write a note: tap New note, write in Markdown, and save. A note can be searched a few seconds after saving. Upload a PDF: tap Upload PDF and choose a file.` |
| 1 | 2 | 126 | `PageBlink reads the text page by page, so an answer can point to the exact page. Scanned PDFs without text cannot be searched.` |
| 1 | 3 | 172 | `문서추가하기 직접쓴노트와올린PDF에질문할수있도록PageBlink가내용을정리해둡니다. 노트쓰기: 새노트를누르고마크다운으로쓴뒤저장하세요. 저장하고몇초뒤부터검색됩니다. PDF 올리기: PDF 올리기를누르고파일을고르세요. 페이지별로글자를읽기때문에답변이정확한 페이지를가리킵니다. 글자가없는스캔본PDF는검색할수없습니다.` |
| 2 | 0 | 153 | `PageBlink guide · 2 / 3 Asking questions Open the Ask tab and type a question in plain words, for example: What does the guide say about uploading a PDF?` |
| 2 | 1 | 166 | `PageBlink finds the most relevant passages in your notes and PDFs and writes an answer from them only. If nothing relevant is found, it tells you instead of guessing.` |
| 2 | 2 | 138 | `Tip: mention a topic or a document name in your question to get a more precise answer. 질문하기 질문탭을열고평소말투로질문을적어보세요. 예: 가이드에서PDF 올리기는어떻게설명하나요?` |
| 2 | 3 | 104 | `PageBlink는내노트와PDF에서가장관련있는부분을찾아그내용만으로답변을만듭니다. 관련 내용이없으면지어내지않고못찾았다고알려줍니다. 팁: 질문에주제나문서이름을넣으면더정확한답변을받을수있습니다.` |
| 3 | 0 | 197 | `PageBlink guide · 3 / 3 Sources and the demo account Every answer carries small lightning-bolt markers. Tap one to jump to the note or the PDF page that the answer came from, and check it yourself.` |
| 3 | 1 | 203 | `About the demo account: everyone who tries the demo shares one account, so please do not enter personal information. You can create up to 5 notes or PDFs of your own, and they are removed after 24 hours.` |
| 3 | 2 | 134 | `The sample items cannot be edited or deleted. Questions are limited to 50 per day across all demo visitors. Sign up to keep your work.` |
| 3 | 3 | 143 | `출처와데모계정 답변마다작은번개모양표시가붙습니다. 누르면답변의근거가된노트나PDF 페이지로바로이동하니 직접확인해보세요. 데모계정안내: 데모를체험하는모든사람이하나의계정을함께쓰므로개인정보는넣지마세요. 직접 만들수있는노트와PDF는최대5개이며, 24시간뒤에삭제됩니다.` |
| 3 | 4 | 59 | `샘플항목은수정하거나삭제할수 없습니다. 질문은데모방문자전체가하루50회까지할수있습니다. 가입하면계속쓸수있어요.` |

공백 제거 후 부분 문자열 검증: **통과**


### 7.7 평가 세트 정적 점검 + 어휘(BM25) 대리 검색

| # | 질문 | 기대 근거 | v1: 근거 청크 길이 | v2: 근거 청크 수 / 합계 길이 | v2 최소 인용 길이 |
|---|---|---|---|---|---|
| 1 | When is the launch, and what is the budget? | Nov 18 / ₩12M | 433 | 3 / 93 | 24 |
| 2 | What is left to do before the launch? | Finalize the release notes / Send the beta invite emails | 433 | 2 / 65 | 32 |
| 3 | What changed in this week's decisions? | ~~Deploy twice a week~~ | 425 | 1 / 47 | 47 |
| 4 | How do I upload a PDF? | Upload a PDF: tap Upload PDF | 607 | 1 / 128 | 128 |
| 5 | What is due today? | due 5 pm | 343 | 1 / 41 | 41 |
| 6 | What do I need to renew my passport? | Renew passport (needs 2 photos) | 343 | 1 / 37 | 37 |
| 7 | 이번 주에 남은 일은 뭐야? | 치과 예약하기 / 발표 자료 마무리 / 여권 갱신하기 | 212 | 3 / 73 | 24 |
| 8 | 데모 방문자는 하루 몇 번까지 질문할 수 있어? | 하루 50회 | 768 | 1 / 50 | 50 |

대리 검색(어휘 BM25, 임베딩 아님 ⚠️): 전체 코퍼스 6문서, v1 8청크 / v2 65청크.

| # | v1 근거 문서 순위 | v2(경로 없음) 첫 근거 청크 순위 | v2(경로 포함) 첫 근거 청크 순위 | v2(경로 포함) 근거 전부가 top-12 안 |
|---|---|---|---|---|
| 1 | 2 | 2 | 2 | 예 |
| 2 | 1 | 7 | 6 | 예 |
| 3 | 1 | 1 | 1 | 예 |
| 4 | 1 | 1 | 1 | 예 |
| 5 | 1 | 1 | 1 | 예 |
| 6 | 1 | 1 | 1 | 예 |
| 7 | 1 | 61 | 1 | 예 |
| 8 | 1 | 1 | 1 | 예 |



### 7.8 큰 노트 / 큰 PDF 합성 입력 (`big.dart`)

```
body=119180 chars lines-level=3000 packed=478 avgPacked=246
substring ok=true
pdf target=120 chunks=19 avg=102
pdf target=200 chunks=17 avg=114
pdf target=300 chunks=17 avg=114
500k-char english prose target=120 chunks=2694 batches32=85
500k-char english prose target=200 chunks=1796 batches32=57
500k-char english prose target=300 chunks=1796 batches32=57
```

### 7.9 작은 단위 → 큰 단위 매핑 (두 단 구조, `run2.dart`)

#### 큰 단위 목록(노트: 제목 구간)

| 문서 | 큰 단위 수(제목 구간/페이지 창) | 길이(자) |
|---|---|---|
| PageBlink tour: try it in 5 minutes | 3 | 142 / 235 / 346 |
| Q4 launch plan | 4 | 76 / 111 / 85 / 160 |
| Weekly sync: week 3 of October | 4 | 64 / 132 / 123 / 104 |
| Sample · My to-do list | 4 | 15 / 108 / 147 / 70 |
| 샘플 · 할 일 목록 | 4 | 10 / 74 / 83 / 42 |

#### 질문별 작은 → 큰 단위 매핑 (BM25 대리 검색)

| # | 질문 | k | 작은 단위(점수>0) | 큰 단위(중복 제거) | 큰 단위 합계(자) | 근거 전부 큰 단위 안 | 근거 전부 작은 단위 안 |
|---|---|---|---|---|---|---|---|
| 1 | When is the launch, and what is the budget? | 5 | 5 | 4 | 591 | 예 | 예 |
| 1 | When is the launch, and what is the budget? | 16 | 13 | 6 | 799 | 예 | 예 |
| 2 | What is left to do before the launch? | 5 | 5 | 5 | 579 | 예 | 아니오 |
| 2 | What is left to do before the launch? | 16 | 14 | 7 | 946 | 예 | 예 |
| 3 | What changed in this week's decisions? | 5 | 5 | 2 | 279 | 예 | 예 |
| 3 | What changed in this week's decisions? | 16 | 12 | 5 | 570 | 예 | 예 |
| 4 | How do I upload a PDF? | 5 | 5 | 3 | 1514 | 예 | 예 |
| 4 | How do I upload a PDF? | 16 | 10 | 3 | 1973 | 예 | 예 |
| 5 | What is due today? | 5 | 3 | 1 | 108 | 예 | 예 |
| 5 | What is due today? | 16 | 3 | 1 | 108 | 예 | 예 |
| 6 | What do I need to renew my passport? | 5 | 1 | 1 | 147 | 예 | 예 |
| 6 | What do I need to renew my passport? | 16 | 1 | 1 | 147 | 예 | 예 |
| 7 | 이번 주에 남은 일은 뭐야? | 5 | 3 | 1 | 83 | 예 | 예 |
| 7 | 이번 주에 남은 일은 뭐야? | 16 | 3 | 1 | 83 | 예 | 예 |
| 8 | 데모 방문자는 하루 몇 번까지 질문할 수 있어? | 5 | 5 | 3 | 1236 | 예 | 예 |
| 8 | 데모 방문자는 하루 몇 번까지 질문할 수 있어? | 16 | 9 | 4 | 1514 | 예 | 예 |


**질문 1** `When is the launch, and what is the budget?` (k=5)

- 큰 단위 `PageBlink tour: try it in 5 minutes` p1 [144,379) section, 235자, 포함된 작은 단위 히트 1개: #2
- 큰 단위 `Q4 launch plan` p1 [78,189) section, 111자, 포함된 작은 단위 히트 2개: #1, #2
- 큰 단위 `Q4 launch plan` p1 [191,276) section, 85자, 포함된 작은 단위 히트 1개: #6
- 큰 단위 `Q4 launch plan` p1 [278,438) section, 160자, 포함된 작은 단위 히트 1개: #7

**질문 2** `What is left to do before the launch?` (k=5)

- 큰 단위 `Q4 launch plan` p1 [0,76) section, 76자, 포함된 작은 단위 히트 1개: #0
- 큰 단위 `Q4 launch plan` p1 [191,276) section, 85자, 포함된 작은 단위 히트 1개: #6
- 큰 단위 `Q4 launch plan` p1 [278,438) section, 160자, 포함된 작은 단위 히트 1개: #7
- 큰 단위 `Q4 launch plan` p1 [78,189) section, 111자, 포함된 작은 단위 히트 1개: #2
- 큰 단위 `Sample · My to-do list` p1 [127,274) section, 147자, 포함된 작은 단위 히트 1개: #3

**질문 3** `What changed in this week's decisions?` (k=5)

- 큰 단위 `Weekly sync: week 3 of October` p1 [66,198) section, 132자, 포함된 작은 단위 히트 3개: #3, #2, #1
- 큰 단위 `Sample · My to-do list` p1 [127,274) section, 147자, 포함된 작은 단위 히트 2개: #5, #4

**질문 5** `What is due today?` (k=5)

- 큰 단위 `Sample · My to-do list` p1 [17,125) section, 108자, 포함된 작은 단위 히트 3개: #2, #0, #1

**질문 6** `What do I need to renew my passport?` (k=5)

- 큰 단위 `Sample · My to-do list` p1 [127,274) section, 147자, 포함된 작은 단위 히트 1개: #5

**질문 7** `이번 주에 남은 일은 뭐야?` (k=5)

- 큰 단위 `샘플 · 할 일 목록` p1 [88,171) section, 83자, 포함된 작은 단위 히트 3개: #5, #3, #4

읽는 법: 노트의 큰 단위는 제목 구간(§4.1)이다. `k=5`/`16`은 어휘 대리 검색의 상위 k 중 점수가 0보다 큰 작은 단위만 센 것이다(밀집 검색은 항상 k개를 채우므로 실제 값은 더 클 수 있다). **질문 2**: 작은 단위 5개만으로는 근거 둘 중 하나가 빠지지만, 큰 단위(`To do` 구간)로 확장하면 모두 들어온다("근거 전부 큰 단위 안"). 이것이 큰 단위가 필요한 사례다. **질문 3·5·7**: 같은 제목 구간의 여러 히트가 큰 단위 1~2개로 합쳐져 컨텍스트가 83~279자에 그친다(v1은 청크 하나가 343~768자). PDF 질문(4·8)은 ±2 창이라 1,236~1,973자까지 늘어난다 → 6,000자 예산과 `packSmall`형 완화가 필요한 쪽이다.

### 7.10 퍼저 (`fuzz.dart`)

```
chunks=29669 bad=0 maxNonCodeLen<=300 check done; maxLen=700
empty: 0 0 0
onlyHeading: [# Hi]
```

---

## 8. 품질 평가 방법

### 8.1 평가 세트 (샘플 노트 + PDF, 질문 8개)

| # | 언어 | 질문 | 기대 근거 문서 | 기대 근거 텍스트(청크에 포함돼야 함) |
|---|---|---|---|---|
| 1 | en | When is the launch, and what is the budget? | Q4 launch plan | `Nov 18`, `₩12M` |
| 2 | en | What is left to do before the launch? | Q4 launch plan | `Finalize the release notes`, `Send the beta invite emails` |
| 3 | en | What changed in this week's decisions? | Weekly sync | `~~Deploy twice a week~~ → deploy once a week` |
| 4 | en | How do I upload a PDF? | PageBlink guide p.1 | `Upload a PDF: tap Upload PDF` |
| 5 | en | What is due today? | Sample · My to-do list | `due 5 pm` |
| 6 | en | What do I need to renew my passport? | Sample · My to-do list | `Renew passport (needs 2 photos)` |
| 7 | ko | 이번 주에 남은 일은 뭐야? | 샘플 · 할 일 목록 | `치과 예약하기`, `발표 자료 마무리`, `여권 갱신하기` |
| 8 | ko | 데모 방문자는 하루 몇 번까지 질문할 수 있어? | PageBlink guide p.3 | `하루 50회` |

(질문 1~7 중 일부는 `sample_pack.dart`의 샘플 질문과 같다. 7·8과 3의 일부는 이 문서에서 추가했다.)

### 8.2 지표

| 지표 | 정의 | 목표(제안) |
|---|---|---|
| Hit@k | 상위 k 청크 중 기대 근거 텍스트를 포함한 청크가 1개 이상 | v2 ≥ v1 (k=8, 16 모두) |
| AllEvidence@k | 기대 근거 텍스트 **전부**가 상위 k 청크 안에 있음(질문 1·2·7) | k=16에서 100% |
| 인용 길이 | 기대 근거를 담은 청크의 글자 수(중앙값) | v1 대비 70% 이상 감소(노트) |
| 인용/본문 비율 | 인용 길이 ÷ 노트 본문 길이 | v1 ≈ 100% → v2 ≤ 15% |
| 인용 정확도(수동) | LLM이 `[n]`을 단 문장의 근거가 실제 그 청크에 있는가 | 8문항 × 2모델 |
| 컨텍스트 길이 | 질문당 LLM에 보낸 총 글자 수(큰 단위 포함) | ≤ 6,000, 노트 질문 중앙값 ≤ 1,000 |

### 8.3 정적으로 할 수 있는 것 (API 불필요) 과 라이브에서만 되는 것

| 구분 | 항목 | 결과/방법 |
|---|---|---|
| 정적 ✅ | 청크 텍스트가 본문 부분 문자열(노트) / 공백 무시 부분 문자열(PDF) | 샘플 + 퍼저 통과 (§7, §2.2) |
| 정적 ✅ | 기대 근거 텍스트가 정확히 의도한 청크(들)에 들어 있음, 인용 길이 | §7.7 표 |
| 정적 ✅ | 결정성: 같은 입력 → 같은 청크(재계산 가능성) | 순수 함수. 골든 스냅샷 단위 테스트로 규칙 변경이 리뷰에 드러나게 함 |
| 정적 ✅ | 청크 수·배치 수·저장량 추정 | §7.1, §6.5 |
| 정적(대리) ⚠️ | 어휘 BM25 순위 | §7.7. **밀집 임베딩 품질의 대체가 아니다** |
| 라이브 | Recall@k(실제 EmbeddingGemma/Gemini 벡터), 경로 접두 A/B, k=8/12/16/24 | 별도 로컬 DB에 같은 문서를 `#c1`·`#c2`로 각각 색인하고 질문 8개의 임베딩 + 벡터 검색만 실행(LLM 불필요) |
| 라이브 | 답변 완성도, 인용이 근거 줄을 가리키는가, 큰 단위 확장 on/off, `EVIDENCE/CONTEXT` 표기의 모델 준수율(마커를 근거 줄 번호로 쓰는가) | 무료·유료 모델 각 1개로 8문항 수동 판정 |
| 라이브 | 임베딩 호출 지연·레이트 한도, 큰 PDF 색인 시간 | 로컬에서 합성 문서로 배치당 지연 측정, 운영은 로그로 |
| 라이브 | 실제 pdfium 텍스트에서의 공백 무시 매칭 | 클라이언트 구현 단계에서 확인 |

`tools/eval`(ADR 002가 요구한 한국어 30문항)은 이 저장소에서 찾지 못했다 ⚠️. 8문항은 이를 대신하지 못한다. 한국어 노트·PDF 질문을 20~30개로 늘리는 것을 후속으로 권한다.

---

## 9. 재색인(마이그레이션) 전략

### 9.1 왜 기존 경로를 못 쓰는가

`_index`와 `reindex`를 그대로 백필에 쓰면 안 된다(F6, F7).

| 문제 | 결과 |
|---|---|
| 실패 시 `status='failed'`+`lastError` | 429/타임아웃 한 번에 멀쩡한 문서가 사용자 화면에서 "실패"로 바뀐다 |
| 성공 시 `updatedAt=now` | `list`가 `updatedAt desc` 정렬이라 모든 사용자의 문서 목록 순서가 뒤섞인다 |
| `reindex`는 `status='indexing'`을 먼저 씀 | 스피너 노출, 프로세스가 죽으면 10분 뒤 `failed/interrupted` |
| `_requireWrite` → `DemoGuard.requireNotSample` | 데모 샘플을 거부 |
| `DocPage` 전체 삭제·재삽입 | 불필요한 쓰기 |

> ADR 020은 "시드 하나 때문에 색인 핫패스(`_index`)를 건드리지 않는다"는 이유로 `_index` 추출안을 기각했다. 청크 규칙 교체는 어차피 `_index`를 수정하므로 **그 기각 사유는 이번에는 성립하지 않는다.** 청킹·입력 생성·교체 트랜잭션을 `lib/src/services/`의 공용 함수로 뽑아 `_index`와 재색인 잡이 같이 쓰되, 상태 전이는 호출자가 가진다.

### 9.2 (a) 구버전 표식

- **표식:** `Document.embeddingModel` = `'${embedder.modelId}#c${ChunkSpec.version}'`. 예: `google/embeddinggemma-300m#c2`, `google/gemini-embedding-001@768#c2`.
- **술어(SQL, 스키마 변경 없음):** `status = 'ready' AND embedding_model <> :현재태그`. 현재 태그는 `RagServices.embedding(session).modelId + '#c' + ChunkSpec.version`.
- **장점:** 컬럼·마이그레이션 0. 임베딩 모델(공급자) 교체와 청크 규칙 교체를 **한 술어**로 처리한다. 현재는 공급자를 바꿔도 옛 벡터가 새 질의 벡터와 다른 공간에 남는데 아무것도 알려 주지 않는다. ADR 002의 "청크마다 `embeddingModel` 기록"은 실제로는 문서 단위로만 구현돼 있고(F4) 읽는 곳도 없었다. 이 술어가 처음으로 그 값을 쓴다.
- **ADR 002 모델 전환 규칙과의 관계:** ADR이 말하는 "새 컬럼 백필 절차"(research 006 §4)는 **차원이 바뀔 때**의 이야기다. 모델만 바뀌고 768차원이면 기존 `Vector(768)` 컬럼에 덮어쓰기(교체)로 충분하다. 이 문서의 교체 트랜잭션이 그 경로다. 모델 전환 시에도 문서 단위 원자 교체이므로 섞인 벡터 공간이 문서 안에는 생기지 않는다(문서 사이에서는 재색인이 끝날 때까지 섞임).
- **단점:** (1) 문자열 접미사 규약이라 관례에 의존한다(ADR에 문서화). (2) `failed`/`indexing` 문서는 태그가 부정확하다 → 대상에서 제외(사용자의 재시도는 새 규칙으로 색인된다). (3) 실패한 백필 문서는 다음 패스에서 다시 시도된다(의도).
- **기각한 대안:** `Document`에 `chunkVersion int` 컬럼 추가 — 마이그레이션 1건이 필요하고(`ALTER TABLE ... ADD COLUMN ... DEFAULT 1`) 얻는 것이 문자열 접미사와 같다. 태그가 부족해지면 그때 전환한다. `DocChunk`에 버전 컬럼 — 청크 수만큼 쓰기, 불필요.

검색(F3)에는 필터가 없으므로 태그가 달라도 옛 청크와 새 청크가 같은 질의에 섞여 랭킹된다. **같은 임베딩 모델이면 문제없다**(같은 벡터 공간). 공급자까지 바뀐 경우는 이미 현재도 깨져 있다.

### 9.3 (b)(c) 문서 단위 조건부 교체 절차

```
reembed(documentId):                    // 문서마다 짧은 세션 하나
  doc = Document.findById(id)
  skip unless doc.status=='ready' && doc.embeddingModel != tag
  (v, hash, title) = (doc.version, doc.contentHash, doc.title)      // 스냅샷
  pages = DocPage.find(documentId)  ||  (note ? [body] : skip('no_source'))
  chunks = chunker(kind).run(pages)
  existing = DocChunk.find(documentId)  // 해시가 같으면 벡터 재사용 (§6.1)
  vectors = embed(미스만)                // 락 없이, 느린 구간
  tx:
    n = Document.updateWhere(            // 행 잠금 + 조건 확인을 한 번에
          where: id==documentId & status=='ready' & version==v & contentHash==hash & title==title,
          set:   embeddingModel = tag )   // status, updatedAt, version 미변경
    if n.isEmpty: rollback('changed')    // 그 사이 편집·삭제·실패 → 아무것도 안 바뀜
    DocChunk.deleteWhere(documentId); DocChunk.insert(new)
```

- **원자성:** 삭제+삽입은 한 트랜잭션(현행 `_index`와 같은 방식 ✅ F6). 읽기는 커밋 전까지 옛 청크를 본다 → **검색이 끊기지 않는다.** 임베딩이 실패하면 트랜잭션에 들어가지 않으므로 옛 청크·`status`·`updatedAt`이 그대로다.
- `lockMode: forUpdate`로 읽는 방법도 가능하다(✅ `Document.db.findById(..., lockMode:)` 시그니처 확인). 위 `updateWhere`는 조건 확인과 잠금을 한 문장에 해서 더 단순하다. 임베딩 HTTP 호출 동안 행 잠금을 **쥐지 않는다.**
- **페이지 원본 재작성 없음:** `DocPage`는 읽기만 한다. PDF 원본 파일은 필요 없다(F8).

### 9.4 (d) 사용자 편집과의 경합

- 백필이 임베딩하는 동안 사용자가 저장하면 `saveNote`가 `version+1`로 행을 갱신하므로 백필의 `updateWhere`가 0행 → **백필 폐기**(편집 쪽 `_index`가 새 규칙으로 색인).
- 백필이 `updateWhere`로 행을 잠근 뒤라면 편집의 `updateRow`가 커밋까지 대기한 뒤 진행하고, 편집의 색인이 마지막에 청크를 교체한다. 어느 순서든 최종 청크는 최신 본문이다.
- 문서 삭제: `updateWhere` 0행 → 폐기. 삭제 후 `deleteWhere`/`insert`가 남지 않는다.
- 편집 쪽 `_index`의 마지막 `Document.db.updateRow`는 행 전체를 쓰므로 `embeddingModel`을 `_index`가 계산한 새 태그로 덮는다(정상).

### 9.5 (e) 다중 인스턴스

- 정합성은 위 조건부 교체가 보장한다(두 인스턴스가 같은 문서를 처리해도 한쪽만 `n>0`이고 다른 쪽은 폐기되거나 같은 내용을 한 번 더 쓴다).
- 중복 작업을 막는 잠금은 두지 않는다(임베딩 호출 동안 DB 행 잠금을 쥐면 편집을 막는다). 롤링 배포 중 두 인스턴스가 겹치면 같은 문서를 두 번 임베딩할 수 있다 — 비용만 최대 2배이고 짧은 구간이다.
- 인스턴스 내부 중복은 정적 `_running` 플래그(`DemoSeed._running` 패턴)로 막는다.

### 9.6 (b) 실행 방식: 부팅 후 백그라운드, 속도 제한, 재개

- 위치: `server.dart`의 `await DemoSeed.boot(pod)` 다음 줄에서 `unawaited(ChunkMigration.start(pod))`. `DemoSeed.startBackground`와 같은 패턴: 클로저 안에서 세션을 열고 **모든 예외를 잡는다**(미처리 예외는 프로세스를 종료시킨다 — research 026 R-B). `maintenance` 역할은 건너뛴다.
- 순회: `id` 오름차순 커서로 20건씩 조회(`ready` & 태그 불일치 & `id > cursor`), 문서마다 새 세션. 커서 덕분에 `no_source`로 건너뛴 문서가 같은 실행에서 무한 반복되지 않는다.
- **속도:** 문서 사이 1.5초 대기(≈ 분당 40문서). 임베딩 배치 자체는 기존 공급자 구현(32/100개씩)을 그대로 쓴다. 무료 한도의 RPM/RPD는 ⚠️ 확인하지 못했다.
- **백오프:** `EmbeddingException`이 429/402/5xx/타임아웃이면 30초 → 60초 → 120초로 대기하고 같은 문서를 재시도, **연속 5회 실패 시 이번 실행을 중단**한다(`friendlyIndexingError`의 분류를 재사용). 인증 오류(401/403)는 즉시 중단.
- **재개:** 진행 상태를 따로 저장하지 않는다. 술어 자체가 상태이므로 재시작·재배포하면 남은 문서부터 이어진다(멱등).
- 실행 시간 추정: 문서 1,000개 ≈ 40분 + 임베딩 시간. 운영 문서 수는 ⚠️ 모른다.
- **재색인 중 사용자 질의:** 질의 임베딩이 같은 공급자 레이트 한도를 쓰므로 백필이 한도를 소진하면 질문이 키워드 폴백으로 떨어진다(`ask_endpoint.dart:60-89`). 지연·백오프가 이를 줄이지만 보장하지는 않는다 → 점검 시간대 실행을 권한다.

### 9.7 (f) 끄기 / 되돌리기

| 값 | 읽는 곳 | 기본 | 효과 |
|---|---|---|---|
| `REINDEX_ON_BOOT` / 비밀값 `reindexOnBoot` | `ChunkMigration.start` | **1차 배포 false → 확인 후 true** | false면 잡을 시작하지 않는다(새 색인은 계속 v2 규칙) |
| `CHUNKER_VERSION` / 비밀값 `chunkerVersion` | `_index`, 잡, 태그 | 2 | 1이면 v1 청커(`chunkPages`, 코드에 유지)로 색인하고 태그는 `#c1`. 잡이 켜져 있으면 **v1으로 되돌려 재색인**한다 |

환경 변수는 `scloud variable set` 후 **재배포로 반영**된다(✅ ADR 020 배포 후 기록). v1 청커를 지우지 않는 것이 되돌리기의 전제다.

### 9.8 (g) 진행 로그

`stdout`/`stderr`에 한 줄씩(`DemoSeed`와 같은 방식, Cloud 로그에서 검색 가능):

```
chunk-migration: start tag=google/embeddinggemma-300m#c2 pending=137
chunk-migration: doc=42 kind=note chunks 1->9 ok 0.8s
chunk-migration: doc=57 kind=pdf  chunks 31->96 ok 2.4s
chunk-migration: doc=61 skip(no_source)
chunk-migration: doc=70 skip(changed)
chunk-migration: doc=71 fail(rate) backoff 30s
chunk-migration: done ok=130 skipped=5 failed=2 elapsed=412s
```

### 9.9 (h) PDF 원본 필요 여부

**필요 없다.** `DocPage`에 클라이언트가 올린 페이지 텍스트가 있고(ADR 003 ✅), `reindex`도 이미 이것으로 재색인한다. 예외: `DocPage`가 없는 문서(`doc_page` 도입 이전 색인) — 노트는 `Document.body`로 처리하고, PDF는 `no_source`로 건너뛰어 **옛 청크를 유지**한다(깨지지 않고 동작은 현행과 동일). 이런 PDF를 새 규칙으로 바꾸려면 사용자가 지우고 다시 올려야 한다(같은 해시는 `ready`면 기존 문서를 돌려주므로 재업로드만으로는 갱신되지 않는다). 해당 문서 수는 ⚠️ 운영 DB를 못 봐서 모른다.

### 9.10 (i) 데모 계정 샘플 문서

- 잡은 DB 행을 직접 다루므로 `DemoGuard`를 지나지 않는다 → 샘플도 일반 문서처럼 재색인된다. `contentHash`·`version`·`body`를 바꾸지 않으므로 **시드 마커(본문 해시, F12)가 그대로** 유지된다.
- `DemoSeed.run`의 `ensureDoc`은 `ready`이면 아무것도 하지 않고, `failed`/`stale`이면 `endpoint.reindex`(→ `_index`, 새 규칙)를 호출한다 → 잡과 충돌하지 않는다. 시드가 `indexing` 중인 문서는 잡이 건너뛴다.
- 샘플 본문을 바꾸는 쪽(SamplePack 진행 중)은 해시가 바뀌면 새 문서로 시드되고 옛 것은 `demoLegacy`로 정리되는 기존 방식이라 이 설계와 독립이다.
- **샘플 질문의 전제가 바뀐다:** `sample_pack.dart:14` 주석("한 청크라 질문이 한 번에 찾는다")과 `sample_pack_test.dart:29-34`("every note fits one chunk")는 더 이상 참이 아니다(§11).

---

## 10. 영향 범위 · 규모 · 순서 · 되돌리기

### 10.1 변경 파일

| 파일 | 변경 | 규모(추정) |
|---|---|---|
| `app/pageblink_server/lib/src/rag/chunker.dart` | `chunkNote`, `chunkPdfPage`, 문장 분리, `ChunkSpec`(버전·규칙) 추가. **`chunkPages`(v1)는 유지**(롤백) | +~230 |
| `lib/src/rag/embedding_spec.dart` | `chunkVersion`, `indexTag(modelId)`, 제목 경로 조립(`documentTitle(docTitle, path)`) | +~30 |
| `lib/src/rag_endpoints/document_endpoint.dart` | `_index`: 종류별 청커, 경로 입력, 태그, 해시 재사용 | +~60 / -15 |
| `lib/src/services/chunk_migration.dart` (신규) | 잡, 교체 트랜잭션, 백오프, 로그 | +~160 |
| `lib/server.dart` | 잡 시작 1줄 | +3 |
| `lib/src/rag_endpoints/ask_endpoint.dart` + 순수 함수 파일(`context_builder.dart`, 신규) | k=16, 재계산·큰 단위 확장·중복 제거·예산, `quoteStart` | +~220 / -20 |
| `lib/src/providers/llm_provider.dart`, `openrouter_llm_provider.dart` | `SourcePassage.context`, `EVIDENCE/CONTEXT` 렌더링, 시스템 프롬프트 | +~35 |
| `lib/src/models/citation.spy.yaml` + 생성물(서버·클라이언트 protocol) | `quoteStart: int?` | +1 / 생성 |
| 클라이언트 `markdown_live.dart`, PDF 하이라이트 | `quoteStart` 사용, 공백 무시 매칭 — **표시 단계(U2)** | +~40 |
| `test/unit/*` | 아래 | +~350 |
| 문서 | ADR 002 부기(태그·교체 규칙), 새 ADR(청크 규칙·재색인), plan 003 §5 "청킹" 줄, research 028 §4.7 #2 | - |

규모 합계(코드, 콘텐츠 제외): 서버 +~700/-35, 테스트 +~400, 클라이언트 +~40(후속).

### 10.2 영향받는 기존 테스트·주석 (작업 트리 기준 grep)

| 위치 | 내용 | 조치 |
|---|---|---|
| `test/unit/sample_pack_test.dart:29-34` | "every note fits one chunk"(`chunkPages`, `hasLength(1)`, `<900`) | 신규 규칙 기준으로 교체: 각 청크가 본문 부분 문자열, 청크 수 ≥ 줄 수의 절반 등 |
| `test/unit/sample_pack_test.dart:147` | `chunkPages(...)` PDF 페이지가 비어 있지 않음 | `chunkPdfPage`로 교체 |
| `lib/src/sample/sample_pack.dart:14` | 문서 주석 "한 청크(900자) 이내라 질문이 한 번에 찾는다" | 주석 수정(코드 아님, SamplePack 담당자와 조율) |
| `test/unit/chunker_test.dart` | v1 `chunkPages` 시험 | 그대로 유지(롤백 경로 보호) + v2 시험 추가 |
| `test/unit/demo_rules_test.dart` | 작업 트리에서는 `chunkPages` 사용 없음 ✅ (HEAD에서는 있었음) | 병합 후 재확인 |
| `docs/research/028-locale-samples.md` §4.7 #2 | "각 노트 본문 ≤900자(한 청크)" 테스트 설계 | 문서 갱신 |
| `docs/plan/003-tech-stack-and-prep.md:368` | "청킹: 약 400토큰, overlap 15%" | 문서 갱신 |

신규 테스트: 규칙별 단위 시험(펜스·중첩·표·`\r\n`·긴 줄·한글 무공백), 부분 문자열 불변식 속성 시험(퍼저 이식), 샘플 골든 스냅샷, 문장 분리 표 시험, 태그·술어 시험, 컨텍스트 빌더(인접 중복 제거·예산) 순수 함수 시험, 교체 트랜잭션 통합 시험(편집 경합 시 폐기).

### 10.3 단계

| 단계 | 내용 | 배포 | 규모 | 되돌리기 |
|---|---|---|---|---|
| 0 | SamplePack 변경 병합 대기(`document_endpoint.dart` 충돌 방지) | - | - | - |
| 1 | 청크 규칙 + 태그 + 단위 시험 (순수 함수, `_index`에 아직 연결 안 함) | 불필요 | S | 커밋 되돌리기 |
| 2 | `_index`에 연결(`CHUNKER_VERSION`, 새 색인만) + 해시 재사용 | 서버 1회 | S~M | `CHUNKER_VERSION=1` |
| 3 | 재색인 잡(`REINDEX_ON_BOOT=false`로 배포 → 새 문서 확인 → true) | 서버 1~2회 | M | 플래그 끔; v1로 재색인 |
| 4 | ask: 큰 단위 확장·`EVIDENCE/CONTEXT`·예산·k=16·`quoteStart` | 서버 1회(+ 생성 클라이언트) | M | 플래그/상수 |
| 5 | 라이브 평가, k·목표 길이·경로 접두 튜닝 | - | S | 상수 |
| 후속 | 표시 U2, PDF 본문 하이라이트, `findQuote` 오프셋 사용 | 클라이언트 | M | - |

### 10.4 위험

| # | 위험 | 가능성/영향 | 완화 |
|---|---|---|---|
| R1 | 줄 단위로 맥락을 잃어 검색 품질이 떨어짐(특히 한국어 단문) | 중/높음 | 경로 접두, 인접 확장, k=16, 라이브 A/B, `CHUNKER_VERSION=1` 롤백 |
| R2 | 임베딩 호출·저장량 증가: 샘플 8 → 65청크(8배), 큰 PDF ≈3배, 노트는 `packSmall` | 확실/중 | 큰 문서 적응 규칙. 운영 DB 용량(Neon 한도·HNSW 크기)은 ⚠️ 미확인 — **운영 청크 수와 DB 한도를 먼저 확인** |
| R3 | PDF 업로드 요청 시간 증가(동기 색인) | 중/중 | 적응 목표, 필요 시 배치 병렬화 |
| R4 | 백필이 무료 임베딩 한도를 써서 사용자 질문이 키워드 폴백으로 떨어짐 | 중/중 | 지연·백오프·플래그, 저부하 시간대 |
| R5 | 백필 중 문서마다 청크 규칙이 달라 랭킹이 섞임 | 확실/낮음(일시) | 같은 모델 공간이라 검색은 유지 |
| R6 | `document_endpoint.dart`를 다른 엔지니어가 수정 중 → 병합 충돌 | 높음/낮음 | 단계 0 |
| R7 | `Citation.quoteStart`를 구 클라이언트(웹 캐시)가 어떻게 처리하는지 | 낮음/낮음 | `fromJson`이 알려진 키만 읽음(✅ 코드). 와이어 동작 ⚠️ 라이브 확인 |
| R8 | 하드 랩 문단의 문장 분할 | 낮음/낮음 | §2.4 |
| R9 | 한글 PDF에서 pdfium 공백이 서버 저장 텍스트와 다름 | 중/중 | 공백 제거 매칭(§6.4), 구현 시 실측 |
| R10 | `[n]` 마커가 k=16에서 두 자리 — 현행 정규식 `\[(\d{1,2})\]`는 99까지 | 낮음 | 변경 불필요 |
| R11 | 운영 임베딩 공급자 비가시 | 낮음 | 태그가 공급자를 포함해 어느 쪽이든 동작 |

---

## 11. CTO 판단이 필요한 것

| # | 결정 | 선택지 | 추천 |
|---|---|---|---|
| D1 | 재색인 잡을 부팅 시 자동 실행할지 | (a) 1차 배포는 끄고 새 문서만 v2 → 확인 후 켬 (b) 처음부터 켬 (c) 잡을 만들지 않고 사용자가 노트를 다시 저장할 때만 | **(a)** |
| D2 | `Citation.quoteStart` 추가 | (A) 지금(비테이블, generate만) (B) `DocChunk` 컬럼(마이그레이션) (C) 보류(중복 줄은 첫 줄을 칠함) | **(A)** |
| D3 | PDF 목표 길이 | 120(정밀) / 200 / 300(호출 수 최소). 큰 문서(>60,000자)는 자동 300 | **120 + 적응** |
| D4 | 두 단 구조(큰 단위 = 노트 제목 구간 / PDF ±2 창, 저장 안 함) | (a) 계산으로 시작(추천) (b) 컬럼 저장 (c) 큰 단위 없이 k만 증가 / 현행 유지. k=16, 총 6,000자 | **(a)+k=16, 라이브 평가로 확정. 큰 단위 임베딩은 보류** |
| D5 | 운영 DB 규모 확인 | 청크 수·Neon 한도·문서 수(`DocPage` 없는 문서 포함)를 먼저 조회해 달라 | **구현 전 확인 필요** |
| D6 | 샘플 질문 문구의 전제("한 번에 한 청크") | 샘플 팩 코멘트·테스트 수정을 SamplePack 담당자와 합의 | 단계 0에서 조율 |
| D7 | 하드 랩 문단 이어붙임 규칙을 이번 범위에 넣을지 | 넣지 않음(§2.4) / 넣음 | **넣지 않음** |

---

## 12. ⚠️ 미확인

- 운영 임베딩 공급자·무료 한도(RPM/RPD)·배치당 실제 지연, 게이트웨이 요청 시간 한도.
- 운영 DB의 문서·청크 수, `DocPage` 없는 문서 수, Neon 저장 한도.
- 실제 EmbeddingGemma/Gemini 임베딩에서 경로 접두와 줄 단위 청크의 Recall(정적 대리 측정만 수행).
- pdfrx(pdfium)가 서버 저장 텍스트와 같은 공백을 내는지, 구 클라이언트의 `Citation` 새 필드 처리(와이어).
- 라이브 에디터가 세트엑스트 제목을 렌더하는지.
- 헤딩 인지 청킹/contextual retrieval 관행, EmbeddingGemma 문서 프롬프트의 `title:` 칸 의도는 이번 세션에서 원문을 조회하지 않았다.

---

## 출처 (코드·문서, 저장소 내)

- 문서: [research 027](027-citation-span-highlight.md) · [research 028](028-locale-samples.md) · [research 006](006-llm-embedding-providers.md) §4 · [ADR 002](../adr/002-embedding-embeddinggemma-768.md) · [ADR 003](../adr/003-pdf-extract-on-client.md) · [ADR 020](../adr/020-demo-account-shared-user.md) · [plan 003](../plan/003-tech-stack-and-prep.md) §5
- 코드: §1 표의 `파일:줄` 근거. 줄 번호는 `main` HEAD `92d9835` + 작업 트리 기준
- 프로토타입: 작성자의 scratchpad `proto/`(`chunker_v2.dart`, `run.dart`, `fuzz.dart`, `big.dart`). 저장소 밖 임시 경로라 사라졌을 수 있음 ⚠️
