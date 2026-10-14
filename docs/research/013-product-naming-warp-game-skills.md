# 013 · 제품 이름 4차: Warp 변형 · 블리자드/LoL 용어 · 기능 용어집

| 항목 | 값 |
|---|---|
| 조사일 | 2026-10-14 (KST) |
| 담당 | 서브에이전트 (general-purpose) |
| 질문 | Savepoint는 저장만 연상됨(동기화·공유 부족). Warp 변형(Docwarp, Warpnote…)·Docparty 변형, 스타크래프트·LoL·오버워치·워크래프트·WoW 용어 중 쓸 만한 것은? |
| 결론 한 줄 | Top 5: **Pagewarp · Docparty · Savepoint · Pinpage · Blinkpage**. 게임 용어는 앱 이름보다 **기능 이름**으로 적합 |
| 반영 | 결정 후 ADR |

## Warp 충돌 (핵심)
- warp.dev: 개발자에게 매우 유명한 agentic development environment(2026-04 오픈소스). **Warp Drive Notebooks = 팀 동기화 Markdown 문서** → `Warp`+doc/note는 개념까지 겹침
- iOS "Warp Notes"(음성 노트) 존재, PDFwarp(PDF AI 채팅), Docuwarp(PyPI), Warpgate(SSH 배스천, 별 ~7천)
- pub.dev: 아래 모든 이름 404

## A. Warp 변형
| 이름 | 한글 | Cloud ID | 평가 |
|---|---|---|---|
| **Pagewarp** | 페이지워프 | pagewarp | 최선. "탭 → 페이지로 순간이동"이 바로 보이고 page가 앞이라 warp.dev 연상 완화. 동기화·공유는 암시 못 함. PDFwarp와 유사 |
| Docwarp | 독워프 | docwarp | "독(毒)/dog" 발음, 점프 의미 약함, Docuwarp 유사 |
| Warpnote | 워프노트 | warpnote | **Warp Notes(iOS)와 사실상 동일** — 비추천 |
| Warpdoc(s) | 워프독(스) | warpdoc | Warp Drive 문서 기능과 혼동 — 비추천 |
| Warpin | 워핀 | warpin | 의미 불명확 |
| Warp Pages | 워프 페이지스 | warp-pages | Pagewarp의 하위 호환 |
| Warpzone | 워프존 | warpzone | 문서 의미 없음, 일반 명사 |
| Warpgate | 워프게이트 | warpgate | **SSH 도구 Warpgate와 직접 충돌** — 비추천 |
| Warpparty | 워프파티 | warp-party | 길고 의미 흐림 |

## A2. Docparty 변형
| 이름 | 평가 |
|---|---|
| **Docparty** (독파티) | 팀 공유 직관적, 동명 앱 미발견. 오프라인·점프 미반영, 가벼운 인상 |
| Doc Party | 띄어쓰기로 식별력 약함 |
| Partydoc | "파티 dog" 발음 불리 |

## B. 게임 용어 (KR 친숙도 / EN 직관성)
| 용어 | KR/EN | 제품 매핑 | 위험 |
|---|---|---|---|
| Recall (LoL 귀환, SC 아비터 리콜) | 상/상 | 클라우드 → 기기 동기화 | Microsoft Recall(프라이버시 논란), Recall.ai |
| Mass Recall (SC) | 중/중 | 프로젝트 전체 동기화 | 기능명 적합 |
| Hearthstone (WoW 귀환석) | 중/중 | 귀환 | **Blizzard 등록상표 — 사용 금지** |
| Warp Gate (SC2) | 상/중 | 업로드 관문 | Warpgate SSH 충돌 |
| Nexus (SC·LoL) | 상/상 | 중심 허브 | 소프트웨어 상표 매우 많음 |
| Pylon (SC) | 상/하 | 주변에 공유 | 영어 직관성 낮음 |
| Shared Vision (SC 공유 시야) | 상/상 | 팀이 같은 문서를 봄 | 기능명 최적 |
| Ward (LoL 와드) | 상/하 | 시야·북마크 | 영어 "병동" 의미 |
| Blink (LoL 점멸, Blink Dagger) | 상/상 | 인용 탭 → 페이지 점프 | 단독은 Chromium Blink·Blink 카메라와 혼잡, 복합어는 양호 |
| Teleport | 상/상 | 이동 | 구분력 약함 |
| Portal (WoW 차원문) | 중/상 | 기기↔클라우드 | Valve Portal, 포털 사이트 |
| Rally Point (SC) | 중/중 | 팀 집결지 | 낮음 |
| Scout | 상/상 | 탐색·검색 | 일반어 |
| Cloak (SC 클로킹) | 상/중 | 기기 전용·비공개 | Cloak VPN 존재, 기능명 적합 |
| Detector | 중/중 | 미인덱싱 문서 발견 | 의미 약함 |
| Guild Bank (WoW) | 중/중 | 팀 공용 저장소 | 금융 앱 오해 |
| Mailbox (WoW) | 중/상 | 공유 받은 문서함 | 기존 Mailbox 앱 |
| Ping (LoL·OW 핑) | 상/상 | "이 페이지 봐" 알림 | 기능명 적합 |
| Minimap | 상/상 | 페이지 썸네일 내비 | 기능명 |
| Fog of War | 상/중 | 미동기화 문서 상태 | 기능명 |

조합명(pub 404): Blinkpage, Recall Docs, Wardbook, Rallydoc

## 기능 이름 어휘집 (앱 내부용 제안)
| 기능 | 게임 용어 |
|---|---|
| 클라우드 → 기기 동기화 | **Recall (귀환)** |
| 프로젝트 전체 동기화 | Mass Recall |
| 인용 탭 → PDF 페이지 점프 | **Blink (점멸)** |
| 프로젝트 팀 공유 | **Shared Vision (공유 시야)** |
| 기기 전용(비공개·오프라인) | **Cloak (클로킹)** |
| 클라우드 업로드 | Warp Gate |
| 팀원에게 특정 인용 공유 | **Ping (핑)** |
| 미동기화 문서 표시 | Fog of War |
| 페이지 썸네일 탐색 | Minimap |

## 조사자 Top 5
1. **Pagewarp** — 데모 핵심(페이지 순간이동), 한영 발음 쉬움. 태그라인 "Ask. Warp to the page." + 기능 어휘로 동기화·공유 보완. warp.dev 연상 주의
2. **Docparty** — 팀 공유 직관적, 충돌 미발견. 문서 질의·점프 안 보임
3. **Savepoint** — 친숙·신뢰감. 태그라인 "Save. Sync. Share. Jump."로 보완. 일반어 상표 확인 필요
4. **Pinpage** — 중립적, 충돌 적음. 공유·동기화 미반영
5. **Blinkpage** — Pagewarp의 점프 메타포 + Warp 충돌 없음. Blink(Chromium·카메라) 혼잡

## 출처
- https://www.deployhq.com/guides/warp
- https://docs.warp.dev/knowledge-and-collaboration/warp-drive/notebooks
- https://apps.apple.com/pg/app/warp-notes/id6752957562
- https://webcatalog.io/en/apps/pdfwarp/alternatives
- https://pypi.org/project/docuwarp
- https://computingforgeeks.com/setup-ssh-https-and-mysql-bastion-server-using-warpgate/
- https://liquipedia.net/starcraft2/Warpgate
