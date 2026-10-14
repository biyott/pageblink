# 009 · Device 계층 프라이버시 · 승격 · 동기화 원칙

| 상태 | 결정일 | 근거 |
|---|---|---|
| 채택 | 2026-10-14 | [plan 002 §5](../plan/002-rag-assistant-plan.md) · [research 003](../research/003-competitors-and-gaps.md) |

## 결정
- 계층: 🔒 Device / ☁️ Cloud / 👥 Project. 문서별 "업로드 금지" 잠금
- **Device 문서는 서버에 저장하지 않음.** 생성에 근거 청크가 필요하면 질문마다 동의 후 **일시 전송**, 원장에 기록
- 승격 시 **서버가 텍스트로 재임베딩** (기기 벡터는 로컬 전용) → 양자화·버전 불일치 차단
- 문서·청크 `contentHash`(SHA-256)로 중복 제거·증분 재임베딩
- 충돌: v1은 문서 단위 last-writer-wins + 이전 버전 보관
- 로컬 `syncState`: `localOnly / pending / synced / conflict`

## 결과
- 👍 "민감한 건 폰에" 약속을 기술적으로 보장
- 👎 승격 시 서버 임베딩 비용 발생(소액)
