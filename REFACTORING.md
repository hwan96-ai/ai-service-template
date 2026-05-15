# Refactoring Roadmap

10개 리뷰(qa-only, review, investigate, cso, health, office-hours, plan-ceo-review, plan-eng-review, plan-design-review, plan-devex-review)에서 합의된 findings를 우선순위·단계별로 정리.

**현재 상태:** Health 7.2/10 · DX 5.5/10 · TTHW ~10분(Red Flag) · Blocker 3건

**목표 상태:** Health 9/10 · DX 8.5/10 · TTHW <5분(Competitive)

---

## 우선순위 매트릭스

| Tier | 라벨 | 정의 | 항목 수 |
|---|---|---|---|
| **P0** | Blocker | 머지 전 반드시 해결 | 3 |
| **P1** | High | 같은 PR/다음 PR에 반드시 | 4 |
| **P2** | Medium | 이번 스프린트 내 | 5 |
| **P3** | Strategic | 별도 결정 게이트 필요 | 2 |

---

## Stage 1 — P0 Blocker (즉시, ~30분)

### 1.1 AI_AGENT_BOOTSTRAP Read Order 갱신
- **출처:** Review/Eng/CSO/Health 4개 리뷰 합의
- **What:** [AI_AGENT_BOOTSTRAP.md:12-21](AI_AGENT_BOOTSTRAP.md) "Required first" / "Agent rules" 섹션에 `.claude/rules/*.md` 4개를 명시
- **Why:** 에이전트가 `CLAUDE.md` 인덱스만 읽고 하위 룰을 무시할 위험. 분배 변경의 가장 큰 회귀 risk.
- **Acceptance:** BOOTSTRAP의 Read Order만 보고 4개 룰 파일을 모두 인지 가능
- **File:** `AI_AGENT_BOOTSTRAP.md`

### 1.2 CLAUDE.md 인덱스에 강제 로드 지시
- **출처:** Investigate(루트원인 #1), Design(7→10)
- **What:** [CLAUDE.md](CLAUDE.md) 인덱스 위에 한 문장: "Before any action, read ALL four rule files below in order."
- **Why:** 인덱스는 표제만 노출. 에이전트가 본문 미로드 가능성이 가장 높은 실패 모드.
- **Acceptance:** Claude/Codex 양쪽이 dry-run에서 4개 룰을 모두 인용

### 1.3 TEMPLATE_CHANGELOG에 BREAKING 마킹
- **출처:** Eng(#7), DX(upgrade path)
- **What:** [TEMPLATE_CHANGELOG.md](TEMPLATE_CHANGELOG.md)에 항목 추가:
  - `BREAKING: CLAUDE.md slimmed to index. Rules moved to .claude/rules/*.md`
  - 다운스트림 마이그레이션 1단계 명령 (예: `git pull && ls .claude/rules/`)
- **Why:** 이 템플릿을 이미 받아 쓰는 서비스가 silent break. 다운스트림 사용자가 분배 사실을 모름.
- **Acceptance:** CHANGELOG만 읽고 마이그레이션 절차 파악 가능

---

## Stage 2 — P1 High (같은 PR, ~1시간)

### 2.1 AGENTS.md 비대칭 해소
- **출처:** CEO, Eng(#5), Investigate(루트원인 #3)
- **What:** [AGENTS.md](AGENTS.md)도 동일 인덱스 패턴 적용. `.claude/rules/`를 양 진입점이 참조(SSOT).
- **Why:** Claude 에이전트와 Codex 에이전트가 다른 룰 셋을 보는 비대칭 제거.
- **Acceptance:** 두 진입점 모두 동일한 4개 룰을 가리킴

### 2.2 룰 파일 frontmatter 보강
- **출처:** QA, Health, Eng(#2)
- **What:** `.claude/rules/*.md` 4개에 `type: rule`, `owner: harness-maintainers` 추가
- **Why:** karpathy 스킬 스키마와 호환. 다중 에이전트 자동 식별.
- **Acceptance:** YAML 파서로 4개 파일 frontmatter 검증 통과

### 2.3 README 한/영 동기화 검증
- **출처:** QA, Health(-1), Design(5→10)
- **What:** [README_KO.md](README_KO.md) 본문에 새 인덱스/룰 구조 반영. [README.md](README.md)와 1:1 미러링.
- **Why:** 한국어 사용자가 옛 단일 CLAUDE.md를 기대.
- **Acceptance:** 두 README의 헤딩 구조가 동일

### 2.4 Escape Hatch 본문 균형화
- **출처:** Design(룰 카드 통일성), Review(nit)
- **What:** [.claude/rules/escape-hatch.md](.claude/rules/escape-hatch.md) 본문을 1문장 → 3-bullet으로 확장 (충돌 유형 / 보고 형식 / 안전 대안 예시)
- **Why:** 4개 룰 카드 길이가 5-10줄로 통일되면 시각 위계 일관
- **Acceptance:** 4개 룰 파일 모두 본문 5줄 이상

---

## Stage 3 — P2 Medium (다음 PR, ~3시간)

### 3.1 Magic Moment #1 — dry-run 데모 스크립트
- **출처:** DX(magic moment 후보 #1)
- **What:** `bin/agent-dry-run.sh` (+ Windows용 `.ps1`) 추가. 에이전트 호출해 "I would do X but blocked by rule Y" 출력.
- **Why:** TTHW 10분 → 2분 단축. 첫 5분에 "안전 가드가 실제 작동함"을 visceral하게 입증.
- **Acceptance:** clone 후 30초 안에 dry-run 결과 확인

### 3.2 Magic Moment #2 — 진입점 매퍼
- **출처:** DX(magic moment 후보 #2)
- **What:** `bin/agent-bootstrap <agent-name>` → 해당 에이전트용 진입점 파일 경로/내용 출력
- **Why:** 사용자가 자신의 에이전트에 맞는 파일을 즉시 찾음
- **Acceptance:** `claude`/`codex`/미지원(`gemini`) 3가지 케이스 모두 명확한 출력

### 3.3 룰 무결성 CI 게이트
- **출처:** DX(magic #3), Eng(#6), CSO(critical)
- **What:** `.github/workflows/rules-integrity.yml`:
  - `markdown-link-check` (깨진 링크)
  - frontmatter validator
  - `.claude/rules/*.md` 변경 시 SECURITY 리뷰 라벨 자동 부착
- **Why:** 룰 파일 임의 약화 방지 (CSO STRIDE Tampering)
- **Acceptance:** PR에서 깨진 링크/누락 frontmatter 자동 감지

### 3.4 First-5-min cheat-sheet
- **출처:** DX(friction #3)
- **What:** `QUICKSTART.md` (또는 README 최상단 박스) — "30초 dry-run → 30초 분기 → 1분 첫 작업" 3단계
- **Why:** Read Order 6개 + rules 4개 인지 부하 완화
- **Acceptance:** 5분 안에 첫 dry-run 성공 사용자 비율 측정 가능

### 3.5 template-payload PII 경고
- **출처:** CSO(HIGH)
- **What:** [template-payload/](template-payload) 디렉토리에 `WARNING.md`: "실제 시크릿/PII 절대 commit 금지. 이는 placeholder 전용."
- **Why:** 다운스트림 복사 시 실수 방지
- **Acceptance:** template-payload 진입 시 경고 즉시 노출

---

## Stage 4 — P3 Strategic (별도 결정 게이트)

### 4.1 분배 vs 단일 전략 결정
- **출처:** CEO(REDUCTION 권고), Office-hours(wedge tradeoff)
- **결정 필요:**
  - **Option A — 현재 분배 유지 + Stage 1-3 적용** (권장 by Eng/DX)
  - **Option B — REDUCTION: 단일 CLAUDE.md로 회귀** (권장 by CEO — curl UX, karpathy 정합)
- **결정 기준:** 다운스트림 사용자가 "curl 1회 단일 파일"을 가장 가치 있게 여기면 B. "모듈성/재사용"이면 A.
- **결정 시한:** Stage 2 머지 전. B로 갈 거면 Stage 1.2/2.4는 무의미.

### 4.2 멀티에이전트 룰 레지스트리 (장기)
- **출처:** Office-hours(6개월 비전), CEO(SCOPE EXPANSION 후보)
- **What:** `.claude/`, `.codex/`, `.cursor/`, `GEMINI.md`를 자동 매핑하는 레지스트리 + 단일 마스터 룰
- **Effort:** human ~3-6주 / CC ~3-5일
- **Decision gate:** Stage 1-3 완료 후 다운스트림 사용자 ≥3명 확보 시점에 재평가

---

## 실행 체크리스트

```
Stage 1 (P0)
  [ ] 1.1 AI_AGENT_BOOTSTRAP Read Order
  [ ] 1.2 CLAUDE.md 강제 로드 문장
  [ ] 1.3 TEMPLATE_CHANGELOG BREAKING 마킹

Stage 2 (P1)
  [ ] 2.1 AGENTS.md 인덱스화
  [ ] 2.2 룰 frontmatter type/owner
  [ ] 2.3 README_KO 동기화
  [ ] 2.4 Escape Hatch 본문 균형

Stage 3 (P2)
  [ ] 3.1 dry-run 스크립트
  [ ] 3.2 진입점 매퍼
  [ ] 3.3 CI rules-integrity
  [ ] 3.4 QUICKSTART cheat-sheet
  [ ] 3.5 template-payload WARNING

Stage 4 (P3) — 결정 게이트
  [ ] 4.1 분배 vs 단일 결정 (Stage 2 머지 전)
  [ ] 4.2 멀티에이전트 레지스트리 (장기)
```

---

## 측정 지표

| 지표 | 현재 | Stage 1 후 | Stage 3 후 | 목표 |
|---|---|---|---|---|
| Health composite | 7.2 | 8.0 | 9.0 | 9+ |
| DX overall | 5.5 | 6.5 | 8.5 | 8.5+ |
| TTHW (분) | ~10 | ~7 | <3 | <5 |
| Blocker 수 | 3 | 0 | 0 | 0 |

---

## NOT in scope

- 코드 베이스 자체 (이 repo는 문서 하니스. 런타임 코드 없음)
- 자동 마이그레이션 도구 (다운스트림이 직접 pull)
- 다국어 확장 (한/영만 우선)
- Cursor/Gemini 진입점 (Stage 4.2로 보류)
