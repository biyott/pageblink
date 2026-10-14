# 003 · 경쟁 제품과 빈틈

| 항목 | 값 |
|---|---|
| 조사일 | 2026-10-14 (KST) |
| 담당 | 서브에이전트 (general-purpose) |
| 질문 | 개인/팀 문서 RAG 제품들의 오프라인·공유·모바일 지원은? 아무도 잘 못하는 빈틈은? 해커톤 심사위원은 무엇을 높이 샀나? |
| 결론 한 줄 | **문서 하나 단위로 "기기 전용 ↔ 서버" 계층을 오가는 제품은 찾지 못함.** 오프라인 우선 + 실사용 + 카메라/음성이 수상 경향 |
| 반영 | [plan 002 §1, §6](../plan/002-rag-assistant-plan.md) |

## 제품 조사 (14개)

| 제품 | 오프라인 / 온디바이스 | 공유 | 모바일 | 특징 |
|---|---|---|---|---|
| **NotebookLM** | 오프라인 Q&A 없음. Audio Overview만 오프라인 청취 | 웹에서만 공유, 모바일은 "곧" | iOS/Android(2025-05~), 2026-04-30 Gemini 앱 연동 | Audio/Video Overview, 출처 인용 |
| **AnythingLLM** | 모바일 앱이 소형 모델로 완전 오프라인 RAG | 워크스페이스, 데스크톱·자체 호스팅과 동기화 | 문서상 Android만 ⚠️ | 하이브리드에 가장 가깝지만 **인스턴스 단위 동기화**, 문서 단위 계층 이동은 아님 |
| **Obsidian Smart Connections / Copilot** | 로컬 임베딩, Ollama/LM Studio로 오프라인 채팅 | Obsidian Sync/Git 수준 | 모바일 임베딩 여부 출처 충돌 ⚠️ | 라이선스·가격 불명확 ⚠️ |
| **Mem / Reflect** | Mem 없음 / Reflect는 노트 오프라인(캐시 수준 ⚠️), AI는 클라우드 | Mem 초기 팀 공유 | ✅ | Reflect 종단간 암호화, Mem 음성 캡처 |
| **Notion AI / Enterprise Search** | AI 오프라인 없음 | 강력한 권한·커넥터 | ✅ | 인용 답변, Business $20/인 |
| **Apple Intelligence (WWDC26)** | 온디바이스 시맨틱 인덱스 → Private Cloud Compute로 승급 | 없음 | Apple 기기만 | **계층 개념이 가장 비슷**하나 개발자용 노트 RAG API 없음 |
| **PrivateGPT / GPT4All LocalDocs / Msty** | 완전 로컬, 데스크톱 | 거의 없음 | ❌ | LocalDocs는 사용한 로컬 스니펫 표시. GPT4All 릴리스 정체 ⚠️ |
| **Khoj** | 자체 호스팅, 로컬 인덱싱 | 제한적 | Web·폰·WhatsApp | Obsidian/Emacs 클라이언트, 에이전트, 자동화 |
| **Enchanted** | 자체 호스팅 Ollama의 iOS 클라이언트, 온디바이스 모델 없음 ⚠️(미검증) | 없음 | iOS/macOS | – |
| **Google AI Edge Gallery** | 온디바이스 Gemma(채팅·이미지·Audio Scribe), 문서 RAG 없음 | 없음 | Android | AI Edge RAG SDK는 고사양 폰에서 Gemma-3 1B |
| **모바일 오프라인 RAG 앱** | LatentChat 완전 로컬 / LocalRAG!는 기기 검색 + Claude로 발췌 전송 | 없음 | iOS | 소규모 틈새 앱 |
| **국내 (Liner, Lilys AI)** | 클라우드만 | 최소 | ✅ | Liner 문장별 출처·사진 질문, Lilys 영상/음성/PDF 요약. **한국어 특화 검색을 내세운 곳은 없음** |

## 빈틈 (Gaps)

| 영역 | 관찰 |
|---|---|
| 하이브리드 오프라인/온라인 | 로컬 전용 아니면 클라우드 전용. 문서 하나를 "기기 전용"으로 두었다가 감사 기록과 함께 서버로 승격하는 제품 없음 |
| 프라이버시 계층 | 공식 계층은 Apple뿐(OS 내부). LocalRAG!는 혼합 구조를 사용자에게 숨김. **어느 계층이 답했는지 보여 주는 제품 없음** |
| 팀/프로젝트 공유 | Notion은 클라우드 전용, NotebookLM은 웹만. **공유 프로젝트 문서 + 내 비공개 문서 오버레이** 없음 |
| 모바일 캡처 | Liner 사진 질문, Mem 음성 → 오프라인 인덱스로 가지는 않음. 온디바이스 한국어 OCR + STT → 로컬 인덱스는 비어 있음 |
| 페이지 인용 | NotebookLM·Liner는 잘하지만 로컬 전용 환경의 페이지 인용 사례 없음 |
| 동기화 충돌 | 기기 사본과 서버 사본이 갈라졌을 때 처리·재임베딩을 문서화한 제품 없음 |
| 지식 신선도 | 오래된/대체된 문서 경고, 인덱스 갱신 시각 표시 없음 |
| 한국어 | 로컬 도구는 영어 임베딩 기본, 한국어 형태소 BM25 하이브리드 없음 |

## 해커톤 수상 경향 (2024~2026)

- **Gemma 3n Impact Challenge** (Kaggle, 600+ 출품): 1위 Gemma Vision(시각장애인용 카메라 비서), 2위 Vite Vere Offline(완전 오프라인 동반자), 3위 3VA. **오프라인 우선 + 실사용자 + 카메라/음성**이 이김. Gemma Vision은 Google AI Edge 특별상도 수상
- **LlamaIndex Agentic RAG-a-thon 2**: "Timeline of You" 우승 — 검색 기법보다 **완성도 높은 UI와 시장성**
- **Vectara Advanced RAG Hackathon (2024)**: RAG 챗봇이 있는 노트 앱 MindPal 우승
- **Serverpod "Flutter Butler" 챌린지 (Serverpod 3)**: 개인 비서/자동화 주제, Serverpod 팀 심사. Serverpod 공식 AI & RAG 튜토리얼로 보아 pgvector 활용을 반길 것
- Serverpod 해커톤 수상작은 Devpost 페이지 접근 실패(403/410)로 확인 못 함 ⚠️

## 빈틈 기반 기능 아이디어 (조사 원안)

1. 문서별 프라이버시 계층(Device/Team/Server) + 원탭 승격 + 답변 계층·모델 배지
2. Split-brain 질의: 서버 프로젝트 문서 + 기기 비공개 문서를 기기에서 병합
3. 승격 전 개인정보(주민번호·전화번호) 로컬 마스킹 + diff 승인
4. 페이지 인용: 탭하면 PDF/이미지의 하이라이트 위치로 (오프라인 포함)
5. 카메라 → 인덱스: 기기 한국어 OCR, 수 초 안에 검색 가능
6. 음성 메모: 기기 STT, 타임스탬프 청크, 인용 탭 시 해당 시점 재생
7. 동기화 충돌 UI: 나란히 diff → 바뀐 청크만 재임베딩 (Serverpod 스트리밍)
8. 신선도 신호: 오래된 출처 경고 + 프로젝트 재검증 큐
9. 한국어 우선 검색: 형태소 BM25 + 벡터, 한영 혼합 질의, 질문 언어로 답변
10. 역할 기반 프로젝트 룸: 실시간 "누가 무엇을 추가" + 검색 단계 접근 규칙
11. 오프라인 질문 큐: 재연결 시 답변 + 알림
12. 공유 답변 카드: 받는 사람이 볼 수 있는 인용만
13. 심사용 신뢰 데모: 비행기 모드 시연 + "기기를 떠난 것" 프라이버시 로그

> 최종 15선은 [plan 002 §6](../plan/002-rag-assistant-plan.md)에서 리드가 정리했습니다.

## 미확인 · 리스크
- ⚠️ AnythingLLM Android 전용 여부, Smart Connections 모바일, Msty RAG, Apple 개발자 API는 2차 출처끼리 충돌 → 피치 인용 전 재확인

## 출처
- https://blog.google/technology/ai/notebooklm-app/
- https://pasqualepillitteri.it/en/news/1697/notebooklm-april-2026-mobile-cinematic-video-gemini-sync
- https://docs.anythingllm.com/mobile/overview · https://anythingllm.com/mobile
- https://anthemcreation.com/en/artificial-intelligence/ai-plugins-obsidian-2026-comparison/ · https://www.promptquorum.com/power-local-llm/smart-connections-review
- https://tana.inc/blog/best-mem-alternatives-2026 · https://apps.apple.com/ms/app/reflect-notes/id1575595407
- https://penchan.co/en/ai/notion/notion-ai-features-guide/
- https://www.vktr.com/ai-news/apple-pushes-ai-deeper-into-the-os-at-wwdc-2026/
- https://toolhalla.ai/compare/gpt4all-vs-privategpt · https://www.local-llm.net/compare/msty-vs-jan-vs-gpt4all/
- https://github.com/ai-khoj/khoj
- https://developers.googleblog.com/google-ai-edge-gallery-now-with-audio-and-on-google-play/ · https://ai.google.dev/edge/mediapipe/solutions/genai/rag/android?hl=en
- https://apps.apple.com/app/localrag/id6759317956 · https://alternativeto.net/software/latentchat--assistant-llm/about
- https://apps.apple.com/kr/app/liner-%EB%9D%BC%EC%9D%B4%EB%84%88-%EB%AF%BF%EC%9D%84-%EC%88%98-%EC%9E%88%EB%8A%94-ai-%EA%B2%80%EC%83%89/id955395198
- https://blog.google/innovation-and-ai/technology/developers-tools/developers-changing-lives-with-gemma-3n/
- https://blog.google/innovation-and-ai/technology/developers-tools/winning-entries-gemma-4-good-challenge/
- https://llamaindex.ai/blog/agentic-rag-a-thon-2-winners-and-recap
- https://www.vectara.com/blog/advanced-rag-hackathon
- https://docs.serverpod.dev/next/tutorials/ai-and-rag
