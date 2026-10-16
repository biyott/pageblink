# 027 · 출처 클릭 시 본문 전체가 음영이 되는 문제: 임베딩 단위, 근거 구간 하이라이트 방안, 표시 UX

| 항목 | 값 |
|---|---|
| 조사일 | 2026-10-16 10:28 (KST) |
| 담당 | 서브에이전트 (general-purpose, 읽기 전용. 저장소 파일 무수정) |
| 질문 | 출처를 누르면 본문 전체가 음영이 된다. (1) 임베딩 단위가 지금 얼마이고 어떻게 변해야 하는가 (2) 답변에 실제로 쓴 부분만 블록 처리하는 방안 (3) "마우스로 긁은 것 같은" 표시를 인용 전용 UX로 바꾸는 방안 |
| 결론 한 줄 | 전체 음영의 원인은 **임베딩 단위가 아니라 인용 데이터**다. OpenRouter 경로가 `quote`를 항상 빈 문자열로 보내 서버가 청크 전체(≈900자)를 `quote`로 채우고, 노트는 대부분 청크 1개라 본문 100%가 칠해진다. 청크를 줄이지 않고도 **서버가 청크 안에서 1~2문장만 골라 `quote`로 보내는 B2**가 가장 싸고 되돌리기 쉽다. |
| 반영 | 결정 대기 (ADR 없음). 관련: [plan 005 §3 인용 하이라이트](../plan/005-follow-up-spec.md), [ADR 013](../adr/013-llm-via-openrouter.md), [research 024](024-live-editor-visual-ui-checkbox-codeblock-link.md) |

> 상태: 조사 완료, CTO 결정 대기(2026-10-16). 추천: 근거 구간 B2(서버 문장 선택) + 표시 U2, 선택 색 중립화.

표기: ✅ 코드 또는 실행으로 확인 · ⚠️ 미확인/추정.

---

## 1. 현재 동작 (✅ 사실)

### 1.1 임베딩 단위

| 항목 | 값 | 근거 |
|---|---|---|
| 청크 기준 | 페이지 안에서 문단(`\n\s*\n`) 단위로 모아 `maxChars=900`, `overlapChars=120`. 청크는 페이지를 넘지 않는다 ✅ | `app/pageblink_server/lib/src/rag/chunker.dart:25-60` |
| 긴 문단 | 900자를 넘는 문단은 `[.!?。]` 뒤 공백에서 문장 단위로 쪼개고, 그래도 길면 900자씩 하드 래핑 ✅ | `chunker.dart` `_splitLong` |
| 겹침 | 직전 청크의 **마지막 120자**를 `substring`으로 잘라 다음 청크 앞에 붙인다. 단어·문장 중간에서 시작할 수 있다 ✅ | `chunker.dart:44-48` |
| 정규화 | `[ \t]+`→공백, `\n{3,}`→`\n\n`. **마크다운 기호는 제거하지 않는다.** 청크 안에서 문단 사이는 빈 줄이 아니라 `\n` 하나로 합쳐진다 ✅ | `chunker.dart:19-22`, `fresh.write('$piece\n')` |
| 코드 주석의 "~400 토큰" | 코드 주석일 뿐 토큰 수를 실측한 값은 아니다 ⚠️ | `chunker.dart:20` |
| 임베딩 모델·차원 | `google/embeddinggemma-300m`, **768차원**, L2 정규화. 문서 프리픽스 `title: <제목> \| text: <청크>`, 질의 프리픽스 `task: search result \| query: <질문>` ✅ | `embedding_spec.dart`, `embedding_provider.dart` |
| 대체 공급자 | `geminiApiKey`가 있으면 `gemini-embedding-001`(768차원으로 절단 후 재정규화)를 쓴다. 두 모델은 벡터 공간이 달라 섞을 수 없다 ✅. **운영이 어느 쪽인지는 비밀값을 볼 수 없어 ⚠️** | `rag_services.dart:26-34`, `gemini_embedding_provider.dart` |
| 노트 | **노트 한 개 = 페이지 1개**(`PageText(page: 1, text: body)`)로 색인한다. 본문이 900자 이하면 청크 1개 ✅ | `document_endpoint.dart:115` 부근 `saveNote` → `_index` |
| PDF | 클라이언트가 pdfrx `loadStructuredText().fullText`로 **페이지별** 텍스트를 뽑아 올리고, 서버가 페이지마다 청크로 나눈다 ✅ | `lib/features/documents/pdf_text.dart`, ADR 003 |
| 원문 보관 | `DocPage`(문서·페이지별 원문)를 따로 저장하므로 재색인에 재업로드가 필요 없다 ✅ | `doc_page.spy.yaml`, `document_endpoint.dart:285-` `reindex` |
| `DocChunk` 필드 | `documentId, projectId, ownerId, page, ordinal, text, contentHash, embedding Vector(768)` + HNSW cosine 인덱스 ✅ | `doc_chunk.spy.yaml` |
| 청크 수 실측 (데모 샘플) | 노트 3개: 728자→**1청크**(723자), 439자→**1청크**, 430자→**1청크**. 샘플 PDF 3페이지: 614/586/773자→**페이지당 1청크**. 합성 2,206자(12문단)→3청크(899/839/683자) ✅ | `lib/src/demo/demo_samples.dart` + `chunkPages` 직접 실행 |
| 실제 한국어 PDF 한 페이지 | 보통 1,500~2,500자 → 2~3청크 ⚠️ (합성 2,206자 결과에서 추정, 실제 PDF 실측 없음) | - |

### 1.2 검색과 LLM 컨텍스트

| 항목 | 값 | 근거 |
|---|---|---|
| top-k | **8**. 코사인 거리 오름차순 `limit: 8` ✅ | `ask_endpoint.dart:16, 54-59` |
| 임계값 | **없음**. 관련이 없어도 8개를 항상 채운다 ✅ | `ask_endpoint.dart` |
| 문서당 상한 | **없음**. 한 문서가 8개를 독식할 수 있다 ✅ | 같음 |
| plan과 코드의 차이 | plan 003 §검색은 "top-k=8, 코사인 거리 < 0.6 필터, 문서당 최대 3개"인데 **코드에는 둘 다 구현되어 있지 않다** ✅ | `docs/plan/003-tech-stack-and-prep.md:368` ↔ `ask_endpoint.dart` |
| 키워드 폴백 | 질의 임베딩이 `EmbeddingException`이면 단어 6개 `ILIKE`로 같은 limit 8 ✅ | `ask_endpoint.dart:60-89` |
| LLM에 넘기는 형태 | OpenRouter: `[1] 제목 (p.N)\n<청크 전문>` 번호 목록을 user 메시지에 이어 붙임 ✅. 청크 8개 ≈ 최대 7~8천자 | `openrouter_llm_provider.dart:42-68` |

### 1.3 인용 데이터 흐름

```
OpenRouter 스트림 → 청크 델타를 LlmText로 yield
                  → 누적 텍스트에서 [n] 정규식 → 처음 보인 n마다 LlmCitation(n-1, '')   (citedText 항상 '')
ask_endpoint     → hit = hits[sourceIndex]; quote = citedText.isEmpty ? hit.text : citedText
                  → 결과: quote = 청크 전문 (≈900자)
클라이언트        → turn.citations[c.index] = c  (같은 index는 덮어씀)
```

- `Citation` 필드: `index, documentId, documentTitle, kind(note|pdf), page, quote` ✅ (`citation.spy.yaml`). **구간 오프셋 필드는 없다.**
- `quote`는 청크 전체다. LLM은 `[n]` 마커만 출력하고 **구간(span)은 출력하지 않는다** ✅. 마커→청크 매핑은 `n-1`이 `hits` 인덱스다.
- 같은 청크를 여러 번 인용해도 `cited.add(sourceIndex)`가 두 번째부터 버린다. 그래서 인용 하나는 청크 하나, 구간은 한 번만이다 ✅ (`ask_endpoint.dart:132-136`, `openrouter_llm_provider.dart:115`).
- Claude 직접 경로(`ClaudeLlmProvider`, `anthropicApiKey`만 있을 때)는 네이티브 `citations_delta`의 `cited_text`를 받으므로 **이미 문장 단위**다 ✅. 단 `start_char_index/end_char_index`는 읽지 않고 버린다 (`llm_provider.dart:141-147`). 운영이 OpenRouter 경로라는 점은 ADR 013·014와 `RagServices.llm` 선택 순서로 **미루어 짐작**할 뿐 비밀값은 못 봤다 ⚠️.

### 1.4 클라이언트 표시 경로와 전체 음영의 원인

**세 군데 표시 면이 모두 청크 전체를 보여 준다.**

| 면 | 동작 | 근거 |
|---|---|---|
| 노트 편집기(데스크톱 센터 패널·폰 풀페이지) | `OpenItem.citation(c)` → `_CitedNote` → `NoteEditorView(highlight: citation.quote)` → `_body.quote = highlight` → `LiveMarkdownController.buildTextSpan`이 `findQuote(text, quote)`로 범위를 찾아 `TextStyle(backgroundColor: styles.highlight)`를 **글자 단위로** 덮는다 ✅ | `open_item_view.dart:127-133`, `note_editor_screen.dart:371`, `markdown_live.dart:196-205, 321-338` |
| 편집기 상단 배너 | `⚡ “<quote>”` 최대 3줄 ellipsis, 배경 `secondaryContainer` ✅ | `note_editor_screen.dart:1098-1120` |
| 폰 인용 시트(Blink) | `c.quote` **전문**을 스크롤 박스에 넣고 `accent` 18% 배경. 박스 색 `0xFFF7F3EA`, 글자색 `0xFF1F1B16`을 **하드코딩**해서 다크 모드를 따르지 않는다 ✅ | `citation_sheet.dart:164-186` |
| PDF 뷰어 | `PdfViewer(..., initialPageNumber: page)` **페이지 이동만** 한다. 본문 위 하이라이트도, 해당 위치로의 스크롤도 없다. 상단 `QuoteBanner`가 quote를 3줄 ellipsis로 보여 줄 뿐이다 ✅ | `page_viewer_screen.dart:57-69, 79-93` |

**왜 전부 칠해지는가 (실행으로 입증).**

1. `quote` = `hit.text`(정규화된 청크 전문)이고 노트 본문은 대개 청크 1개다.
2. 청크 문단 사이가 `\n` 하나로 합쳐져 있어 `body.indexOf(quote)`는 **실패**한다 (3개 샘플 노트 모두 `body.contains(chunk) == false` ✅ 실행 확인).
3. 그러면 `findQuote`의 2단계가 동작한다. 청크의 **모든 단어를 `\s+`로 이은 정규식**이 본문 전체에 맞는다.
4. 결과: 샘플 노트 3개 모두 **본문의 100%**(727/727, 438/438, 429/429자)가 하이라이트 범위가 된다 ✅ (`findQuote` 로직을 그대로 복제해 실행).

> 즉 "임베딩 단위가 커서"가 아니라 "단위와 무관하게 quote가 청크 전체이기 때문"이다. 노트가 900자 이하면 청크를 아무리 줄여도 이 경로는 그대로이므로, 청크 축소(A)만으로는 이 증상이 고쳐지지 않는다. 청크가 300자로 줄면 노트는 3청크가 되어 1/3만 칠해질 뿐이다.

추가로 확인된 사실 (✅).

- **선택 영역과 색이 같은 계열이다.** 편집기 하이라이트는 `secondaryContainer`(= `accentContainer`)이며 라이트 `#EAE4FD`(흰색 대비 1.23:1), 다크 `#3A2F7A`다. 마우스 드래그 선택은 `theme.dart`에 `TextSelectionThemeData`가 **없어서** Flutter 기본값 `colorScheme.primary` 40%로 칠해진다. 라이트에서 `#6C4CF5` 40% ≈ `#C4B7FB`, 다크에서 `#B7A6FF` 40%다 (Flutter SDK 3.47.7 `material/text_field.dart:1641` `primary.withOpacity(0.40)`). 둘 다 바이올렛 채움이라 "긁은 것처럼" 보인다.
- **모양도 선택 영역과 같다.** `backgroundColor`는 글자 줄 박스마다 그려지는 사각형이라 둥근 블록이 아니고 줄 사이가 끊긴다.
- **자동 스크롤이 없다.** 편집기는 하이라이트 범위로 스크롤하지 않는다 (`jumpTo/animateTo/ensureVisible` 사용처에 하이라이트 범위가 없음 ✅). 긴 노트에서는 근거가 화면 밖일 수 있다.
- **배너가 본문 첫머리를 되풀이한다.** quote가 본문 전체라 배너(`⚡ “…”` 3줄)는 노트 앞부분과 똑같은 글이다.
- **`findQuote` 부분 일치가 범위를 줄인다.** 정확·공백 허용 일치가 실패하면 처음 8단어, 5단어만 칠한다(`markdown_live.dart:371-383`). 인용 문장이 본문에서 수정되었으면 문장의 앞 5단어만 칠해질 수 있다.

### 1.5 디자인 토큰

| 토큰 | 라이트 | 다크 | 용도 / 비고 |
|---|---|---|---|
| `accent`(primary) | `#6C4CF5` | `#B7A6FF` | **spec: "사용처 한정 ⚡ 인용, 기본 버튼, 활성 내비. 그 외 면에 쓰지 않는다"** (`ab-glass-paper/spec.md:19`) |
| `accentContainer` | `#EAE4FD` | `#3A2F7A` | 선택 칩, ⚡n pill, 현재 인용 하이라이트와 배너 |
| `onAccentContainer` | `#2E1F85` | `#E9E3FC` | |
| `ink` / `inkMuted` | `#1F1B16` / `#5C5348` | `#F2EDE3` / `#B5AD9F` | |
| `warn` | `#B45309`(앰버) | `#FBBF24` | spec상 **경고 전용**. 인용 하이라이트에 쓰면 오해 소지 |
| 텍스트 선택 | primary 40% (기본값) | primary 40% | 명시 토큰 없음 |

- 인용 표시를 바이올렛으로 하는 것은 spec과 맞다. 문제는 **선택 색이 spec에 없는 채로 기본값 바이올렛**이라는 점이다.
- 계산한 대비(ink 대비, 배경은 흰색 / 라이트 그라데이션 중간 `#F7E8EE`): accent 22% 채움 12.5 / 10.8, 현재 `#EAE4FD` 13.9, 선택 40% 9.4 / 8.3. 다크(배경 `#251C27`): accent 22% 9.0, 28% 7.8, 선택 40% 6.0. 글자 가독성은 어느 쪽이든 AA(4.5)를 크게 넘는다. 문제는 글자 대비가 아니라 **채움과 배경의 구분 가능성**(1.23:1)과 **선택 색과의 구분**이다.
- 인-에디터 검색 매치 하이라이트는 없다 ✅ (노트 편집기 안 검색 기능 없음). PDF 뷰어에도 `PdfTextSearcher`를 쓰지 않는다. 즉 겹칠 상대는 **텍스트 선택** 하나다.

---

## 2. 방안 비교

공통 전제: **B2의 입력인 "답변 문장"은 이미 만들 수 있다.** 시스템 프롬프트가 "근거를 쓴 문장 뒤에 `[n]`을 붙이라"고 하므로 마커 직전 문장이 곧 "근거로 쓴 주장"이다 (`openrouter_llm_provider.dart:34-39` ✅). `ask_endpoint`는 이미 모든 `LlmText`를 받으므로 거기서 버퍼링해도 된다.

### 2.1 비교표

| 항목 | A. 청크 자체를 줄임 (300~400자 / 문장 윈도우) | B1. LLM이 근거 문장을 원문 그대로 출력 + 서버 검증 | B2. 서버가 청크를 문장·줄로 쪼개 상위 1~2개 선택 | C. 혼합 (B2 기본 + LLM 구조화 인용 우선) |
|---|---|---|---|---|
| 정확도 | 단위가 작아지면 근거 범위가 좁아진다. 그러나 선택은 여전히 "청크 단위"이고 노트가 짧으면 효과 없음 | LLM이 의도한 문장이므로 의미상 가장 정확. 단 무료 모델(Gemma 등)의 원문 복사 신뢰도 ⚠️ 미측정 | 답변 문장과 어휘가 겹치는 문장을 고르므로 대체로 맞고, 바꿔 쓴 답변은 틀릴 수 있다 | B1이 검증을 통과하면 그것, 아니면 B2 |
| 지연 | 색인 때 청크 수만 증가. 질의 지연 변화 없음 | 답변 끝에 근거 블록이 붙어 **스트림 종료까지 ⚡ 구간 확정이 늦다**. 출력 토큰 +인용당 30~80 ⚠️ 추정 | 어휘 기반이면 **추가 네트워크 0**, 마커 시점에 즉시 계산. 임베딩 기반이면 임베딩 호출 1~2회(+수백 ms ⚠️ 미측정) | B2 즉시 + 종료 시 B1로 갱신(클라이언트 맵 덮어쓰기로 반영) |
| 비용 | 청크 수 3배 가정 시 임베딩 토큰은 겹침 분만 증가, EmbeddingGemma@DeepInfra $0.002/1M 토큰 ([research 006](006-llm-embedding-providers.md) 표 ⚠️ 운영 미확인)이라 금액은 미미. Gemini 무료 한도 사용 시 호출·일 한도는 ⚠️ 미확인 | LLM 출력 토큰 증가(무료 모델은 0원, 유료 $0.50/1M 출력 수준) | 어휘: 0. 문장 임베딩: 질문당 임베딩 요청 1~2건 추가 | B2 + 선택적 B1 |
| 마이그레이션 | **전체 재임베딩 필요.** `reindex`는 문서 단위·본인 권한이고 `reindexFailed`는 실패 문서만 건드린다. **전체 재색인 경로가 코드에 없다** ✅. 원문은 `DocPage`에 있어 재업로드는 불필요. 운영 중 구/신 청크 혼재 처리와 모델 전환 규칙(ADR 002)이 따른다 | 없음 | 없음. `Citation`에 필드를 더할 경우에도 테이블이 아니라 `serverpod generate`만 필요(DB 마이그레이션 없음 ✅ `Citation`은 table 없음) | 없음 |
| 검색 품질 | 맥락 손실로 질의-청크 의미 매칭이 약해질 수 있고 top-k=8에 담기는 총 컨텍스트가 줄어(8×300=2,400자) k를 올려야 한다. 한국어 검색 품질은 이미 ⚠️ 미검증(ADR 002) | 영향 없음 | 영향 없음 (검색은 그대로) | 영향 없음 |
| 페이지 인용 번호 | 청크는 페이지를 넘지 않으므로 번호 의미 유지. 단 한 페이지 인용이 더 많은 청크로 갈라져 같은 페이지가 여러 인용으로 보이는 일이 늘 수 있다 | 영향 없음 | 영향 없음 | 영향 없음 |
| PDF 적용성 | 구간이 좁아져도 **뷰어가 하이라이트를 못 그려서** 표시 문제는 그대로(§1.4) | 가능. 단 PDF 텍스트는 줄바꿈·하이픈이 섞여 원문 복사 검증이 더 까다롭다 | 가능. 뽑은 문장을 뷰어에서 `PdfPageText.allMatches`로 찾아 좌표 사각형을 칠한다 | 같음 |
| 노트 적용성 | 노트 ≤ 400자는 변화 없음. 샘플 노트 3개는 모두 1청크라 **그대로 100%** | 마크다운 기호 문제: LLM은 `**`, `- [ ]`를 떼고 인용하는 경향이 있어 본문 매칭이 깨질 수 있다 ⚠️ | 선택 문장이 청크(= 원문에서 온 마크다운 포함 텍스트)에서 나오므로 기호가 그대로 있어 `findQuote`에 안전하다. 목록 항목·제목은 마침표가 없으므로 **줄 단위**로도 쪼개야 한다 | 같음 |
| 환각(원문에 없는 문장) | 없음 | **있음.** 반드시 서버 검증(공백 허용 부분 일치 + 비율 임계값) 후 실패 시 폴백해야 한다. Claude 네이티브 citations는 이 위험이 없지만 **구조화 출력과 함께 쓸 수 없다**(400 에러, Anthropic 문서 ✅) | 없음 (항상 청크 안의 실제 텍스트) | B1 부분만 위험, 검증으로 차단 |
| 한국어 문장 분리 | 청킹이 `[.!?。]\s+`뿐이라 `~다.` 뒤 공백이 없거나 줄바꿈으로만 끝나는 문장이 길어질 수 있다 | 분리 불필요 | 필요. 마침표 + 줄바꿈 + 목록 접두(`- `, `1. `) 분리. 형태소 분석기 없이 가능하나 `3.5`, `v1.2` 같은 숫자 소수점은 분리 금지 처리가 필요 | 같음 |
| 실패 시 폴백 | 없음 (그냥 큰 청크) | 검증 실패 → B2 | 점수가 임계값 미만 → 청크 전체(지금과 동일)이되 "맥락" 약한 음영 | 단계적 폴백 |
| 구현 규모 | 청킹 파라미터 1줄 + **전체 재색인 도구**(새 엔드포인트/스크립트 ≈ 60~100줄) + 평가 | 프롬프트·파서·검증기 ≈ 150~250줄, 모델별 준수율 테스트 | 서버 ≈ 80~140줄(분할 + bigram 점수 + 단위 테스트) + 클라이언트 변경 없음(quote만 짧아짐) | B2 + B1 ≈ 250~400줄 |
| 되돌리기 | 재색인을 다시 해야 함 (비가역에 가깝다) | 프롬프트 플래그로 즉시 | **서버 환경값 하나로 즉시** (`citationSpan=off` 시 지금과 동일) | 플래그 |

### 2.2 노트와 PDF에서 "하이라이트 범위"를 정하는 방식

| 대상 | 범위 결정 | 비고 |
|---|---|---|
| **노트(마크다운)** | 서버가 보낸 문장/줄(`quote` 또는 신규 `span`)을 `findQuote`로 본문에서 찾는다. 청크는 원문을 그대로 쪼갠 것이라 마크다운 기호가 보존되어 일치한다. 목록·제목은 **줄 전체**로 확장한다 | 줄 확장은 클라이언트에서 `\n` 경계까지 넓히면 된다. 같은 문장이 본문에 두 번 나오면 첫 번째가 선택된다(⚠️ 드문 경우) |
| **PDF(페이지 텍스트)** | 뷰어가 해당 페이지의 `PdfPageText`(= 서버 `DocPage.text`와 같은 `loadStructuredText().fullText`)에서 문장을 공백 허용 정규식으로 찾아 `PdfPageTextRange`를 얻고, `enumerateFragmentBoundingRects()`/`bounds`로 PDF 좌표 사각형을 얻는다 ✅ (`pdfrx_engine 0.6.1` `pdf_text.dart`). 그려서 보여 주는 훅은 `PdfViewerParams.pagePaintCallbacks`이고 스크롤은 `controller.ensureVisible(calcRectForRectInsidePage(...))` ✅ (`PdfTextSearcher.goToMatch`가 이 조합을 쓴다) | 스캔 PDF(텍스트 없음)는 인용 자체가 안 만들어진다. 한국어 PDF 추출의 공백 차이는 ⚠️ 실기 시험 필요(plan 005도 같은 ⚠️) |

### 2.3 사실 확인된 주변 정보

- Claude 네이티브 citations: 평문 문서는 **문장 단위로 자동 청킹**되고 `cited_text`는 출력 토큰으로 계산되지 않으며, citations와 structured outputs는 함께 쓸 수 없다(400) ✅ (Anthropic 문서 `build-with-claude/citations`, 2026-10-16 조회). 따라서 B1을 Claude 네이티브 경로에 붙이는 것은 불가이고, 이 경로는 이미 문장 단위이므로 **오히려 이 경로의 `cited_text`를 `span`으로 그대로 쓰면 된다.**
- 검색 단위를 작게 두고 부모 청크를 컨텍스트로 쓰는 "small-to-big / sentence-window retrieval" 패턴이 RAG 업계 관행이라는 점은 알려져 있다 ⚠️ (이번 조사에서 문서를 직접 조회하지 않음). 출처 문장 귀속(attribution)을 LLM 인용 + 사후 검증으로 하는 방식도 관행이다 ⚠️ 같은 이유.
- 업로드 PDF 텍스트와 뷰어 텍스트는 같은 엔진·같은 버전(`pdfrx 2.6.5`, `pdfrx_engine 0.6.1`, `app/pubspec.lock`)이라 오프셋·문자열 일관성은 대체로 기대할 수 있다 ⚠️ (구버전으로 올린 PDF의 텍스트와의 차이는 미확인).

---

## 3. 인용 표시 UI/UX 안

공통 원칙: 선택 색과 **색이 아니라 구조로** 구분한다(번개 라벨, 좌측 레일, 밑줄). 새 토큰은 `Pb`에 `citeFill`, `citeEdge`로 추가하고 `LiveStyles.highlight` 한 곳에서 쓴다.

| 안 | 설명 | 구현 위치 · 난이도 |
|---|---|---|
| **U1. 형광펜 + 밑줄 + 번호 라벨** | 근거 구간만 `accent` 22%(라이트) / 28%(다크) 채움 + `accent` 2px 밑줄. 배너는 `⚡1 · 답변의 근거`로 번호를 보여 주고, 다중 인용이면 `⚡1`, `⚡2` 칩(숫자·아이콘이 있어 색에만 의존하지 않음)을 위에 둔다. 열릴 때 구간으로 중앙 스크롤 | **TextSpan 스타일.** `runsToSpan`의 `_overlay`에 스타일 하나(`backgroundColor` + `decoration`)를 추가. **S (≈ 30~60줄)**. 약점: 여러 줄이면 줄 박스가 끊겨 "형광펜 긁음" 느낌이 일부 남는다 |
| **U2. 블록 + 좌측 레일 + 펄스 (권장)** | 근거 줄 묶음을 **둥근 사각 한 덩어리**(accent 10~14%)로 본문 뒤에 칠하고 왼쪽 gutter에 3px `accent` 레일. 나타날 때 600ms 동안 28%→12% 펄스 후 유지, `✕`/`←→`로 닫기·다음 인용 이동. 자동 중앙 스크롤. 선택 영역은 그대로 위에 겹쳐 보여 구분됨 | **오버레이.** 이미 있는 `LiveCodeBackLayer`가 `RenderEditable.getBoxesForSelection`으로 코드 블록 배경을 필드 뒤에 칠한다(research 024 ✅). 같은 패턴으로 `CiteBackLayer` 추가. **M (≈ 150~250줄 + 위젯 테스트)** |
| **U3. 나머지 흐리게 (집중 보기)** | 근거 구간은 본래 글자색, 나머지 본문은 `ink` 45%로 흐리게. "전체 보기" 토글로 해제. 채움 색이 필요 없어 선택 색과 충돌이 없다 | **TextSpan 스타일**(비범위 런에 색 오버레이). **S~M**. 약점: 편집 가능한 본문 전체가 흐려져 편집 의도와 충돌, 접근성상 흐린 글자 대비(≥4.5:1) 확인 필요 |

PDF 표시(U1/U2 공통): `pagePaintCallbacks`에서 근거 사각형을 둥근 모서리 accent 22%로 칠하고 아래에 1.5px accent 막대를 그린다. 페이지가 열릴 때 `ensureVisible`로 중앙으로 스크롤한다. 구현 규모 **M (≈ 80~140줄)**. 가장 값싼 대안은 `PdfTextSearcher`에 공백 허용 정규식을 주고 내장 `pageTextMatchPaintCallback`을 쓰는 것(**S, ≈ 40줄**)이며 색은 `PdfViewerParams.matchTextColor`로 바꾼다 ✅.

다른 필수 정리.

- **선택 색:** `ThemeData(textSelectionTheme: TextSelectionThemeData(selectionColor: …))`로 바이올렛 기본값 대신 **중립 청회색 계열**(예: ink 18~22%)을 지정해 spec의 "바이올렛은 ⚡ 인용 전용" 원칙을 지킨다. 구체 색은 ⚠️ 실기 눈 확인 필요.
- **모바일 인용 시트:** 하드코딩한 `0xFFF7F3EA`/`0xFF1F1B16`을 `Pb` 토큰으로 교체(다크 모드 깨짐 수정)하고, 청크 전체가 아니라 **근거 문장은 강조, 앞뒤 맥락은 흐리게** 보여 준다.
- **접근성:** 색 외에 레일/밑줄/번호가 있으므로 색각 이상에서도 구분된다. 펄스는 `MediaQuery.disableAnimations`이면 생략한다. 터치 환경에서는 시트의 `←→`(이미 `l.sourceNofM`) 단계 이동을 그대로 쓴다.
- **다크 모드:** 채움 알파를 라이트보다 높게(28%) 하고 레일은 `#B7A6FF`를 쓴다. 표의 대비 값은 ink 7.8~9.0이다.
- **다중 인용 색 구분:** 번호는 기호로 구분하고 색은 하나로 유지하는 것을 권한다. 인용 번호마다 색을 바꾸면 spec의 "포인트 색 하나" 원칙을 깨고 색각 이상에 약하다.

---

## 4. 추천안과 단계적 도입 순서

**추천: B2를 기본으로 하고, 표시는 U2를 단계적으로. A는 하지 않거나 맨 마지막.**

| 단계 | 내용 | 규모 | 되돌리기 |
|---|---|---|---|
| **0. 즉시 (UI 버그성)** | 인용 시트 하드코딩 색을 토큰으로 교체, 노트 편집기 열릴 때 하이라이트로 **자동 스크롤**, 선택 색을 중립으로 | S | 커밋 되돌리기 |
| **1. 서버 B2 (quote만 짧게)** | `ask_endpoint`가 마커 직전 문장을 질의로 청크를 줄·문장 단위로 쪼개고 문자 **bigram 중첩 점수**로 상위 1~2개(연속이면 합침)를 `quote`로 보낸다. 점수가 임계값 미만이면 청크 전체로 폴백. 서버 환경값 `citationSpan`(기본 on)으로 끈다. **클라이언트·스키마 변경 없음**: 기존 `findQuote`, 배너, 시트, PDF 배너가 모두 `quote` 하나만 쓴다 ✅ | M(서버 ≈ 80~140줄 + 테스트) | 환경값 off → 현재와 동일 |
| **2. 노트 U1 → 필요하면 U2** | 하이라이트 스타일을 `LiveStyles.highlight`와 `Pb` 토큰으로 정리, 줄 단위 블록(U2) | S → M | 토큰 값만 바꾸면 이전 색으로 |
| **3. PDF 본문 하이라이트** | plan 005 §3(P1, 미구현)의 구현. `PdfTextSearcher` 또는 `pagePaintCallbacks`로 `quote`를 칠하고 중앙 스크롤. 매칭 실패 시 지금처럼 배너만 | M | 실패 시 배너 폴백이 이미 있음 |
| **4. (선택) `Citation.span`·다중 구간** | 다른 문장을 인용한 같은 청크의 마커를 `spans`로 모음. 이때 `quote`=청크(맥락), `span`=근거(강한 음영)로 2층 표시. `serverpod generate`만 필요(테이블 아님 ✅). 구 클라이언트는 필드를 무시해야 하나 ⚠️ 미확인 | M | 필드는 nullable 추가라 호환 |
| **5. (선택) B1 / C** | OpenRouter 경로에서 "근거 문장 원문 그대로" 구조화 출력을 받아 검증. 종료 시점에 같은 `index`로 재발행해 B2 결과를 갱신(클라이언트가 `turn.citations[c.index] = c`로 덮어쓰므로 가능 ✅ `ask_screen.dart:124`). 모델별 준수율을 먼저 측정 | M~L | 프롬프트 플래그 |
| **6. (보류) A 청크 축소** | B2 후에도 검색 단계의 정밀도 문제가 **측정으로** 확인될 때만. 전체 재색인 도구, 한국어 평가셋(ADR 002가 요구한 `tools/eval`, 현재 저장소에서 못 찾음 ⚠️)이 선행 | L | 사실상 비가역(재색인) |

**근거:**

1. 증상의 원인(quote=청크 전체)을 가장 짧은 경로로 고치며 색인 데이터를 건드리지 않는다.
2. 노트가 대부분 한 청크라서 A는 이 증상을 고치지 못한다(§1.4).
3. B1은 구조화 출력이 필요한데 Claude 네이티브 citations와 공존할 수 없고, 무료 모델의 원문 준수가 불확실하다.
4. 같은 `index`를 덮어쓰는 클라이언트 구조 덕분에 B2 → B1을 점진적으로 쌓을 수 있다.

---

## 5. CTO가 결정해야 할 것

| # | 결정 | 선택지 | 추천 |
|---|---|---|---|
| D1 | 근거 구간 산출 방식 | (a) B2 서버 선택 (b) B1 LLM 원문 인용 (c) C 혼합 (d) A 청크 축소 | **(a)로 시작, 효과를 보고 (c)** |
| D2 | B2 점수 방식 | (a) 문자 bigram 어휘 점수 (지연 0, 모델 무관) (b) 문장 임베딩 (추가 호출 +지연, 의미 매칭 강함) | **(a)**. (b)는 오탐이 측정으로 확인될 때만 |
| D3 | 노트에서 목록·제목 등 구조 단위의 확장 | (a) 줄 단위 블록 (b) 문장 단위 | **(a)**. 노트는 마침표가 없는 줄이 많다 |
| D4 | 표시 안 | U1 / U2 / U3 | **U2**(그 전에 U1로 빠르게 출시 가능) |
| D5 | 선택 색을 바이올렛에서 중립으로 변경 (전역 영향) | 예 / 아니오 | **예.** spec이 바이올렛을 ⚡ 인용 전용으로 규정하므로 일관된다 |
| D6 | 인용 범위 | 청크당 인용 1개 유지 / 마커마다 여러 구간 | 1단계는 유지, 4단계에서 확장 |
| D7 | (A를 하게 될 때) 전체 재색인 | 도구 신설 / 사용자 재색인 안내 | 보류 |

---

## 6. ⚠️ 미확인

- 운영 배포가 OpenRouter 경로인지 Claude 직접 경로인지(비밀값 비가시). 코드·ADR로 OpenRouter를 추정했다.
- 운영 임베딩 공급자(DeepInfra vs Gemini). Gemini 무료 한도·요금, DeepInfra 실제 단가·잔액은 확인하지 못했다.
- 한국어 질의·문서에서 bigram 점수로 맞는 문장을 고르는 정확도. 실제 질문/답변 20~30개로 시험해야 한다.
- 무료 OpenRouter 모델(Gemma 4 26B, Nemotron)이 "근거 문장을 원문 그대로" 출력하는 준수율, 구조화 출력 지원 여부.
- 실제 한국어 PDF 한 페이지의 청크 수, 줄바꿈·공백이 뷰어 텍스트와 서버 텍스트에서 동일한지. 스캔본은 해당 없음.
- 구버전 클라이언트가 `Citation`에 새 필드가 오면 무시하는지(Serverpod 4.0.4 역직렬화 동작).
- `app/pageblink_flutter`에는 `pubspec.lock`이 없고 워크스페이스 루트 `app/pubspec.lock`이 정본이다(pdfrx 2.6.5 ✅). 다른 플랫폼(웹 WASM)에서 `PdfTextSearcher`의 동작은 코드 검토만 했고 실행 확인은 못 했다.
- U2·PDF 하이라이트의 색·알파는 계산상 대비만 확인했다. 실기 눈 확인은 하지 않았다.
- RAG 업계 관행(sentence-window retrieval, attribution)은 이번 세션에서 문서를 직접 조회하지 않았다.

---

## 출처

코드 (모두 읽기 전용으로 확인, 저장소 `/Volumes/Nova/00-src/70-github@biyott/pageblink`)

- `app/pageblink_server/lib/src/rag/chunker.dart`, `embedding_spec.dart`
- `app/pageblink_server/lib/src/rag_endpoints/ask_endpoint.dart`, `document_endpoint.dart`
- `app/pageblink_server/lib/src/providers/openrouter_llm_provider.dart`, `llm_provider.dart`, `embedding_provider.dart`, `gemini_embedding_provider.dart`
- `app/pageblink_server/lib/src/services/rag_services.dart`, `llm_catalog.dart`
- `app/pageblink_server/lib/src/demo/demo_samples.dart`
- `app/pageblink_server/lib/src/models/citation.spy.yaml`, `doc_chunk.spy.yaml`, `doc_page.spy.yaml`
- `app/pageblink_flutter/lib/features/notes/markdown_live.dart`, `note_editor_screen.dart`, `live_code_layer.dart`
- `app/pageblink_flutter/lib/features/open_item/open_item_view.dart`, `lib/app/open_item_controller.dart`
- `app/pageblink_flutter/lib/features/viewer/page_viewer_screen.dart`, `citation_sheet.dart`
- `app/pageblink_flutter/lib/features/ask/ask_screen.dart`
- `app/pageblink_flutter/lib/app/theme.dart`, `lib/features/documents/pdf_text.dart`
- `docs/design/ab-glass-paper/spec.md`, `docs/plan/003-tech-stack-and-prep.md`, `docs/plan/005-follow-up-spec.md` §3
- `docs/adr/002`, `003`, `013`, `014`, `docs/research/006`, `024`

실행 확인 (스크래치패드, 저장소 무수정)

- `/private/tmp/claude-501/-Volumes-Nova-00-src-70-github-biyott-pageblink/a5666af9-28c0-4328-8234-8d574a83e873/scratchpad/measure.dart` (청크 수·`body.contains(chunk)`)
- `/private/tmp/claude-501/-Volumes-Nova-00-src-70-github-biyott-pageblink/a5666af9-28c0-4328-8234-8d574a83e873/scratchpad/cover.dart` (`findQuote` 복제 → 본문 100% 범위)

외부·패키지

- Anthropic Citations 문서: https://platform.claude.com/docs/en/build-with-claude/citations (2026-10-16 조회)
- Flutter SDK 3.47.7 `packages/flutter/lib/src/material/text_field.dart` (선택 색 기본값)
- `pdfrx 2.6.5` `lib/src/widgets/pdf_text_searcher.dart`, `pdf_viewer_params.dart`; `pdfrx_engine 0.6.1` `lib/src/pdf_text.dart` (`~/.pub-cache/hosted/pub.dev/`)
