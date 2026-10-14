# 015 · 실제 게임 스킬·아이템 이름 30선 (LoL·오버워치·스타·WoW·도타)

| 항목 | 값 |
|---|---|
| 조사일 | 2026-10-14 (KST) |
| 담당 | 서브에이전트 (general-purpose) |
| 질문 | 범용 단어 말고 실제 공식 스킬 이름(특히 LoL) 중 기능에 맞는 것은? Blink vs Warp vs Flash? |
| 결론 한 줄 | **Blink 유지(PageBlink)** — 한국어로는 LoL Flash·오버워치/스타2/WoW Blink 모두 "점멸". 기능 용어: Recall(복원)·Infrasight/Ward(공유)·Fog of War(비공개) |
| 반영 | [ADR 012](../adr/012-product-name-pageblink.md) · [plan 004](../plan/004-naming-and-feature-vocabulary.md) |

표기: ✔ 이번에 공식 한국어 페이지로 한글명 확인 · † 기억 기반, 재확인 필요. 평가 = 영어 직관 / 한국 게이머 친숙 / 위험

## 점프·텔레포트
| 게임 | 영문 | 한글 | 이름안 | 평가 |
|---|---|---|---|---|
| LoL 소환사 주문 | Flash | 점멸 ✔ | PageFlash | 중/상/상 (Adobe Flash) |
| LoL 소환사 주문 | Teleport | 순간이동 ✔ | TeleDoc | 상/상/중 |
| LoL 이즈리얼 E | Arcane Shift | 비전 이동 ✔ | ArcaneShift | 하/중/중 |
| LoL 카사딘 R | Riftwalk | 균열 이동 ✔ | Riftwalk | 중/상/중 |
| LoL 아리 R | Spirit Rush | 혼령 질주 ✔ | SpiritRush | 하/중/중 |
| LoL 바드 E | Magical Journey | 신비한 차원문 ✔ | PageJourney | 중/중/하 |
| 오버워치 트레이서 | Blink | 점멸 ✔ | **PageBlink** | 상/상/중 |
| 오버워치 리퍼 | Shadow Step | 그림자 밟기 ✔ | ShadowStep | 중/중/하 |
| 스타2 추적자 | Blink | 점멸 | Blink | 상/상/중 |
| WoW 마법사 | Blink | 점멸 ✔ | Blink | 상/상/중 |
| 도타2 | Blink Dagger | 블링크 단검 † | DaggerPage | 중/중/하 |
| 스타2 프로토스 | Warp Gate | 차원 관문 † | PageWarp | 중/상/중 (warp.dev) |

## 복귀·복원·동기화
| 게임 | 영문 | 한글 | 이름안 | 평가 |
|---|---|---|---|---|
| LoL | Recall | 귀환 † | PageRecall | 상/상/상 (Microsoft Recall) |
| 오버워치 트레이서 | Recall | 시간 역행 ✔ | Recall | 상/상/상 |
| LoL 질리언 W | Rewind | 되감기 ✔ | Rewind | 상/중/하 |
| WoW | Hearthstone | 귀환석 † | — | **사용 금지** (블리자드 상표) |
| 스타2 모선 | Strategic Recall (구 Mass Recall) | † | StrategicRecall | 중/중/중 |
| 오버워치 솜브라 | Translocator | 위치변환기 ✔ | Translocate | 하/중/하 |
| 오버워치 시메트라 | Teleporter | 순간이동기 ✔ | Teleporter | 상/중/하 |

## 공유·팀 시야
| 게임 | 영문 | 한글 | 이름안 | 평가 |
|---|---|---|---|---|
| LoL | Stealth Ward | 투명 와드 ✔ | Wardbook | 중/상/하 |
| LoL | Control Ward | 제어 와드 † | ControlWard | 중/상/하 |
| LoL | Oracle Lens | 예언자의 렌즈 † | OracleLens | 중/중/하 |
| 오버워치 위도우메이커 | Infra-Sight | 적외선 투시 ✔ | **Infrasight** | 중/중/하 |
| 스타2 테란 | Scanner Sweep | 스캔 † | PageScan | 상/상/중 |
| 스타2 프로토스 | Pylon | 파일런 | DocPylon | 중/상/중 |

## 비공개·프라이버시
| 게임 | 영문 | 한글 | 이름안 | 평가 |
|---|---|---|---|---|
| LoL 이블린 | Demon Shade (Camouflage) | 악의 장막 ✔ | Shade | 중/중/중 |
| LoL | Zhonya's Hourglass | 존야의 모래시계 ✔ | Hourglass | 하/상/상 (고유명) |
| 스타·워크 | Fog of War | 전장의 안개 † | Fogless | 상/상/하 |

## 지식·정답
| 게임 | 영문 | 한글 | 이름안 | 평가 |
|---|---|---|---|---|
| LoL 트위스티드 페이트 R | Destiny | 운명 ✔ | Destiny | 상/중/중 |
| LoL (구 소환사 주문) | Clairvoyance | † | Clairvoyant | 중/하/하 |

챔피언·영웅 고유명은 제외. Riot·Blizzard 어휘를 그대로 상표로 쓰면 이의 제기 위험 — 발표에서 "점멸에서 착안" 정도는 안전

## Blink vs Warp vs Flash
| | Blink | Warp | Flash |
|---|---|---|---|
| 게임 | 오버워치·스타2·WoW·도타2 | 스타2 Warp Gate | **LoL 소환사 주문** |
| 한국어 | 점멸 ✔ | 차원 관문 † | 점멸 ✔ |
| 한국 친숙도 | 상 | 중 (스타 한정) | 상 |
| 영어 의미 | 깜빡임, 순식간 | 휘다, 왜곡 | 번쩍임 |
| 충돌 | Amazon Blink, Chromium Blink, Blinkist, Blink Shell | warp.dev, Cloudflare WARP | Adobe Flash, 카메라 플래시, flashcard |

**추천: Blink 유지** — 복합어 PageBlink는 충돌이 약하고, 한국에서는 "페이지 점멸"로 읽혀 LoL 유저에게도 통함. 슬로건 예: "인용 페이지로 점멸"

pub.dev 404(미등록) 확인: pageblink, pageflash, pagewarp, wardbook, infrasight, pagerecall, riftwalk, farsight, pageshift, docblink, pagescan, arcaneshift, blinkdocs, flashpage

## 출처
- https://leagueoflegends.fandom.com/wiki/Flash
- https://overwatch.blizzard.com/ko-kr/heroes/tracer/
- https://starcraft.fandom.com/wiki/Stalker
- https://www.wowhead.com/classic/ko/spell=1953/점멸
- https://warcraft.wiki.gg/wiki/Hearthstone
- https://liquipedia.net/starcraft2/Spells · https://liquipedia.net/starcraft2/Scouting
- https://wiki.leagueoflegends.com/en-us/Control_Ward
