# 002 · Flutter 온디바이스 RAG 스택

| 항목 | 값 |
|---|---|
| 조사일 | 2026-10-14 (KST) |
| 담당 | 서브에이전트 (general-purpose) |
| 질문 | Android(→iOS→Web)에서 PDF 추출·임베딩·벡터 검색·생성을 오프라인으로 할 수 있나? 기기와 서버가 같은 임베딩 공간을 쓰려면? |
| 결론 한 줄 | **오프라인 검색 + 온라인 생성**이 v1 정답. 오프라인 생성은 고사양 옵션. **EmbeddingGemma-300m을 기기·서버 공용**으로 |
| 반영 | [ADR 001](../adr/001-offline-retrieval-online-generation.md) · [ADR 002](../adr/002-embedding-embeddinggemma-768.md) · [plan 002 §3](../plan/002-rag-assistant-plan.md) |

## 핵심 결론

- **가장 큰 변화**: `flutter_gemma`는 개발 중단(마지막 1.11.4). 후속 **`flutter_edge_ai` 2.3.2**가 조사 하루 전 출시됐고 파이프라인 대부분을 담당 ✅
- 오프라인 검색: pdfrx → EmbeddingGemma(~180MB) → sqlite-vec + FTS5
- 오프라인 생성: 2.4~3GB 모델 다운로드가 필요한 **옵션** (RAM 6~8GB 기기 ⚠️)
- 공용 임베딩: EmbeddingGemma-300m. 서버는 Ollama `embeddinggemma:300m`(622MB ✅)이나 TEI로 서빙. **순수 Dart 서버 런타임은 검증된 방법 없음 ✅**

## 상세

### 1. PDF 텍스트 추출

| 패키지 | 버전 | 플랫폼 | 비고 |
|---|---|---|---|
| **pdfrx** | 2.6.5 ✅ | Android·iOS·데스크톱·Web(WASM) ✅ | PDFium. `PdfPage.loadText`로 **페이지별 추출 → 인용 페이지 확보** |
| pdfrx_engine | 0.6.1 ✅ | 순수 Dart ✅ | 서버에서도 같은 추출기 사용 가능 |
| syncfusion_flutter_pdf | 35.1.40 ✅ | 전 플랫폼 ✅ | 상용 또는 Community 라이선스 필요 ✅ |

- 한국어(CJK) 언급 없음 ✅ → PDF의 글리프 매핑에 따라 달라짐 ⚠️ → 실제 문서로 시험 필요
- 스캔 PDF는 OCR 필요 ✅ → Google ML Kit 텍스트 인식 ⚠️

### 2. 청킹
- 쓸 만한 Dart 라이브러리 없음 → 직접 구현 (페이지 → 문장/문단, 300~500토큰, overlap, 페이지 번호 저장)
- **`flutter_edge_ai`는 입력이 길면 `EmbeddingInputTooLongException`을 던지고 자르지 않음 ✅** → 청크 길이 제한 필수

### 3. 온디바이스 임베딩
- `flutter_edge_ai`: EmbeddingGemma 전 플랫폼 지원, Gecko 목록 존재 ✅
  - EmbeddingGemma(.tflite): 300M, 768차원, 512토큰판 ~179MB / 2048토큰판 ~196MB ✅
  - EmbeddingGemma 2(.litertlm): 텍스트 전용 165MB + 캐시 71MB ✅
  - Gecko: 110M, 768차원, ~114MB ✅
- EmbeddingGemma-300m 모델 카드 ✅: 100+ 언어(한국어 명시 없음), 2048토큰, 512/256/128차원 축소 가능, 다국어 MTEB 61.15 (Q4/Q8 60.6~60.9), Gemma 라이선스
  - 프리픽스 필수: 질의 `task: search result | query:` / 문서 `title: … | text:`
  - **공개된 한국어 검색 벤치마크 없음 ✅** → 자체 한국어 평가셋 필요
- ONNX 경로: `flutter_onnxruntime` 1.9.0(Web 포함 ✅) + multilingual-e5-small(⚠️ ~118M, 384차원) 또는 bge-m3(⚠️ 568M, 1024차원, 중급 기기엔 무거움, Ko-StrategyQA 79.4 ⚠️)
- 중급 Android 속도: 공개 수치 없음. 추정 청크당 50~300ms(CPU) ⚠️ → 백그라운드 인덱싱

### 4. 온디바이스 벡터 저장소

| 선택지 | 상태 | Web |
|---|---|---|
| **flutter_edge_ai_sqlite** 2.1.0 | sqlite-vec. Web은 WASM + OPFS/IndexedDB ✅ | ✅ 단, COOP/COEP 헤더 필요, 한 탭만 사용 ✅ |
| ObjectBox 5.3.2 | HNSW, cosine/dot ✅ | ❌ |
| sqlite_vector 1.1.2 | 별도 확장 ✅ | ❌ 라이선스 불명 |
| Isar 3.1.0+1 | 3년간 안정판 없음, 벡터 검색 없음 ✅ | 피할 것 |

- flutter_edge_ai_sqlite 주의: 첫 빌드 때 GitHub에서 확장 다운로드, 1.x 인덱스는 업그레이드 후 읽기 불가 ✅
- 키워드 검색은 SQLite FTS5 병행

### 5. 온디바이스 생성

| 모델 (flutter_edge_ai) ✅ | 크기 |
|---|---|
| Gemma 3 1B | 0.5GB |
| Qwen3 0.6B | 586MB |
| Gemma 4 E2B | 2.4GB |
| Gemma 3n E2B | 3.1GB |
| Gemma 4 / 3n E4B | 4.3 / 6.5GB |

- LiteRT 엔진: Android minSdk 30, 64비트 ARM만 ✅. RAM 요구량 미공개 → 추정 1B 1~1.5GB, E2B 3GB+, E4B 4GB+ ⚠️
- 한국어: 1B/0.6B는 근거 기반 답변에 약할 것, E2B가 최소 ⚠️
- Gemini Nano: `flutter_native_ai` 0.5.4 (ML Kit Prompt API) ✅. 지원 기기만, 앱별 할당량, 포그라운드에서만 ✅, 1.0 이전. 대안 `google_mlkit_genai_prompt`(비공식)
- Apple Foundation Models(iOS 26+): `flutter_native_ai`, `cupertino_fundations_models` 0.1.1 ✅
- llama.cpp: `llama_cpp_dart` 0.2.2(9개월 전, 직접 빌드) ✅ · `fllama` 0.0.1(23개월, Android GPU 없음) → 제외

### 6. 올인원 RAG 패키지
- **flutter_edge_ai + flutter_edge_ai_rag 1.1.0** ✅: 임베딩·인덱싱·필터 검색, 서로 다른 임베딩 모델 혼용 방지. **청킹·PDF·키워드 검색·인용은 없음**
- mobile_rag_engine 0.20.1 ✅: SQLite + HNSW + BM25, PDF/DOCX. 기본 모델이 영어 전용 MiniLM, Rust 툴체인 필요, Web 없음, PDF는 샘플 2개로만 테스트
- 추천: flutter_edge_ai

### 7. Web
- 검색은 가능 (onnxruntime-web, sqlite WASM ✅). EmbeddingGemma Web은 텍스트 전용 ✅
- transformers.js 직접 연동은 Flutter 예제 없음 ✅ → 피할 것
- 생성: WebGPU로 가능 ✅이나 모바일 브라우저 지원 들쭉날쭉, 수백 MB~수 GB 다운로드 ⚠️ → **Web 생성은 온라인 전용**

## 미확인 · 리스크
- ⚠️ EmbeddingGemma 한국어 검색 품질
- ⚠️ 양자화(기기) vs 원본(서버) 벡터의 미세 차이 → 섞기 전 코사인 일치도 확인, 또는 서버 재임베딩
- ⚠️ `flutter_edge_ai`가 막 개명·출시됨 → 버전 고정
- 대안 모델: multilingual-e5-small ONNX 양쪽 (384차원, `query:`/`passage:`) ⚠️
- Gemini API 임베딩은 EmbeddingGemma와 다른 벡터 공간 ⚠️

## 출처
- https://pub.dev/packages/pdfrx · https://pub.dev/packages/pdfrx_engine · https://pub.dev/packages/syncfusion_flutter_pdf
- https://pub.dev/packages/flutter_edge_ai · https://flutteredge.ai/docs/models
- https://pub.dev/packages/flutter_edge_ai_sqlite · https://pub.dev/packages/flutter_edge_ai_rag
- https://huggingface.co/google/embeddinggemma-300m · https://ollama.com/library/embeddinggemma
- https://pub.dev/packages/flutter_onnxruntime · https://pub.dev/packages/onnxruntime
- https://pub.dev/packages/objectbox · https://docs.objectbox.io/on-device-vector-search
- https://pub.dev/packages/sqlite_vector · https://pub.dev/packages/isar
- https://pub.dev/packages/flutter_native_ai · https://pub.dev/documentation/google_mlkit_genai_prompt/latest/
- https://pub.dev/packages/cupertino_fundations_models
- https://pub.dev/packages/llama_cpp_dart · https://pub.dev/packages/fllama
- https://pub.dev/packages/mobile_rag_engine
