# 003 · PDF 텍스트는 앱(pdfrx)에서 추출

| 상태 | 결정일 | 근거 |
|---|---|---|
| 채택 | 2026-10-14 | [research 001](../research/001-serverpod-cloud-pgvector.md) · [research 002](../research/002-flutter-ondevice-rag-stack.md) |

## 맥락
Cloud podlet S는 256MB. 서버에서 PDFium을 돌리면 메모리·네이티브 의존성 위험이 있다. 인용에는 페이지 번호가 필요하다.

## 결정
- 앱이 `pdfrx`의 `PdfPage.loadText`로 **페이지별 텍스트를 추출**해 `List<PageText>`로 업로드
- 원본 PDF는 Serverpod 파일 업로드로 private 스토리지에 별도 저장 (뷰어·공유용)
- 서버는 청킹·임베딩·저장만

## 대안과 기각 이유
- 서버 `pdfrx_engine`: 순수 Dart지만 Cloud에서 PDFium 동작·메모리 미검증

## 결과
- 👍 서버 경량화, Phase 1 기기 인덱싱과 추출 코드 공유
- 👎 클라이언트가 보낸 텍스트를 신뢰해야 함(개인 문서라 수용). 스캔 PDF는 OCR 필요(Phase 2)
