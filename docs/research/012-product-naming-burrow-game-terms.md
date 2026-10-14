# 012 · 제품 이름 3차: Burrow 변형 · 게임 용어

| 항목 | 값 |
|---|---|
| 조사일 | 2026-10-14 (KST) |
| 담당 | 서브에이전트 (general-purpose) |
| 질문 | 보류 후보(Pinpage, Burrow) 외에 Burrow 변형 10개, 국내외 게이머가 아는 게임 용어 기반 이름 20개는? |
| 결론 한 줄 | 종합 Top 5: **Pinpage · Burrowpin · Savepoint · Questpage · Pagewarp** — 사용자 결정 대기 |
| 반영 | 결정 후 ADR |

## 새로 확인한 사실
- ⚠️ 단독 **Burrow**: 웹 텍스트를 캡처해 노트·컬렉션으로 정리하는 Chrome 확장 "Burrow"(app.burrow.world, v2.0.4, 2026-07-20)가 있어 노트 카테고리에서 겹침. iOS "Burrow CRM", "Bunny Burrow"도 존재
- ⚠️ 한국어 뉘앙스: "버로우 타다" = 잠수·잠적 은어(존버 어원설). 약한 부정, 유머로 읽힘
- pub.dev: 아래 이름 전부 404. `stash`, `lore`, `codex`는 사용 중(200)

## A. Burrow 변형
| # | 이름 | 장단점 | Cloud ID | 웹 충돌 |
|---|---|---|---|---|
| 1 | Burrow Note | 직관적 / 노트 앱 인상, Burrow 캡처 확장과 정면 충돌 | burrow-note | 높음 |
| 2 | Burrow Docs | 문서 포지션 명확 / 밋밋, Google Docs 연상 | burrow-docs | 중 |
| 3 | BurrowBook | 한 단어로 기억 쉬움 / Facebook 말장난 느낌 | burrowbook | 낮음 |
| 4 | Burrowly | SaaS 어감 / "-ly" 흔함, "버로울리" 어색 | burrowly | 낮음 |
| 5 | Burrow Pages | 페이지 인용과 연결 / Apple Pages 혼동 | burrow-pages | 낮음~중 |
| 6 | My Burrow | 감성적 / 일반어, 검색에 약함 | my-burrow | 중 |
| 7 | Burrowpin | 굴(기기)+핀(인용) / 발음 무거움, Pinterest 연상 | burrowpin | 낮음 |
| 8 | Burrow Ask | "Ask your documents" 직결 / 브랜드 느낌 약함 | burrow-ask | 낮음 |
| 9 | Burrow Den | 따뜻함 / 동의어 중복 | burrow-den | 낮음 |
| 10 | Burrowse | burrow+browse 말장난 / 철자 오인, 발음 불명확 | burrowse | 낮음 |

## B. 게임 용어 (한 = 한국 게이머 친숙도, 영 = 영어 직관성)
| 분류 | 이름 | 출처 | 한/영 | 제품 매핑 | Cloud ID | 충돌 |
|---|---|---|---|---|---|---|
| 인벤토리·저장 | Stashpage | Diablo·PoE·Tarkov 창고 | 중/상 | 문서 창고 | stashpage | 중 (Stash* 계열 다수) |
| | Savepoint | RPG 세이브 포인트 | 상/상 | 기기 오프라인 저장 → 클라우드 세이브 → 파티 공유 | savepoint | 중 (일반어, SQL SAVEPOINT) |
| | Quickslot | MMO·소울류 퀵슬롯 | 상/하 | 자주 쓰는 문서 | quickslot | 낮음 |
| | Checkpage | 체크포인트 | 상/중 | 인용 페이지 확인 | checkpage | 낮음 (평범) |
| | Lootbook | 루트(전리품) | 상/중 | 답변 수집 | lootbook | 낮음 (한국에서 확률형 아이템 논란 연상) |
| 탐험·이동 | Waypage | 웨이포인트 | 중/중 | 인용 → 페이지 이동 | waypage | 낮음 (오타처럼 보임) |
| | Pagewarp | 워프(스타크래프트·오버워치) | 상/상 | 인용 탭 → 페이지로 순간이동 | pagewarp | 낮음 ("warp" 왜곡 뉘앙스) |
| | Portapage | 포탈 | 상/중 | portable+portal | portapage | 낮음 |
| | Questpage | 퀘스트 | 상/상 | 질문 = 퀘스트, 답 = 보상 | questpage | 낮음 |
| | Fogpage | 전장의 안개 | 상/중 | 비공개 문서는 안개에 가려짐 | fogpage | 낮음 ("흐릿한 답" 연상) |
| 파티·길드 | Guildoc | 길드 | 상/중 | 프로젝트 공유 | guildoc | 낮음 (읽기 모호) |
| | Docparty | 파티 | 상/상 | 팀과 문서를 함께 | docparty | 낮음 (가벼운 인상) |
| | Squadoc | 스쿼드 | 상/중 | 소규모 팀 | squadoc | 낮음 (발음 어색) |
| | Guildpage | 길드 | 상/상 | 팀 공유 페이지 | guild-page | 낮음~중 |
| 지식·도감 | Pagedex | 도감(Pokédex 계열) | 상/중 | 내 문서 도감 | pagedex | 중 (Pokédex 연상) |
| | Docdex | 도감 | 중/중 | 문서 색인 | docdex | 중 (개발자 도구 이름 ⚠️) |
| | Lorebook | 로어(WoW·엘든링) | 중/중 | 설정집 | lorebook | 중 (AI 롤플레이 기능명과 겹침) |
| | Lorepage | 로어 | 중/중 | 페이지 단위 설정집 | lorepage | 낮음 |
| | Lorekeeper | 로어 | 중/중 | 지식 지킴이 | lore-keeper | 낮음 (길고 무거움) |
| | Grimoire | 마법서(Destiny·Diablo·D&D) | 중/중 | 비밀 주문서 같은 개인 문서 | grimoire | 중 (일반 단어) |

제외: Codex(pub 사용 중, OpenAI Codex), Waypoint(Halo Waypoint), Respawn(Respawn Entertainment), Warpage(뒤틀림)

## 조사자 종합 Top 5
1. **Pinpage**(보류) — 인용 핀 → 페이지 이동과 직결, "핀페이지" 자연스러움 / 3계층 연결 약함
2. **Burrowpin** — 굴(기기) + 핀(인용)으로 계층 스토리와 인용 기능을 한 이름에 / 발음 무거움
3. **Savepoint** — 기기 세이브 → 클라우드 세이브 → 파티 공유 서사가 가장 자연스러움, 한영 쉬움 / 일반어라 구별력 약함
4. **Questpage** — 질문 = 퀘스트 말장난, 데모 "퀘스트 시작, 보상은 인용" / 충돌 낮음
5. **Pagewarp** — 인용 탭 순간이동 장면을 그대로 설명 / 프라이버시 메시지 없음

## 출처
- https://chromewebstore.google.com/detail/hddbogdpamphlapinbeehfeajkjbpoai (Burrow 확장)
- https://apps.apple.com/us/app/-/id1598528869 (Burrow CRM)
- https://apps.apple.com/us/app/-/id6698879381 (Bunny Burrow)
- https://apps.apple.com/us/app/id6738359748 (Stashly AI)
- https://www.producthunt.com/products/docstash-2
- https://pypi.org/project/loredocs/0.1.19/
- https://www.gamemeca.com/view.php?gid=124918 (버로우 은어)
- https://namu.moe/w/%EC%A1%B4%EB%B2%84
