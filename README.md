# AI Service Template

이 템플릿은 **기존 서비스 레포지토리**에 복사해서 쓰는 로컬 PowerShell 기반 AI 자동화 하네스입니다.
ChatGPT로 계획을 세우고 → Codex CLI로 코드를 구현하고 → Claude Code CLI로 리뷰하고 →
로컬 테스트를 실행하고 → 사람이 최종 승인하는 흐름을 **안전하게** 지원합니다.
커밋, 푸시, 배포, 패키지 설치는 기본적으로 **절대 자동으로 하지 않습니다**.

> **Template version:** `0.6.0` — 변경 이력은 `TEMPLATE_CHANGELOG.md` 참조.

---

## 목차

1. [이 템플릿이 하는 일](#이-템플릿이-하는-일)
2. [이 템플릿이 하지 않는 일](#이-템플릿이-하지-않는-일)
3. [파일 구조](#파일-구조)
4. [사전 요구사항](#사전-요구사항)
5. [기존 서비스 레포에 적용하기](#기존-서비스-레포에-적용하기)
6. [복사 후 먼저 수정할 파일들](#복사-후-먼저-수정할-파일들)
7. [안전한 첫 실행 명령들](#안전한-첫-실행-명령들)
8. [준비됐을 때: 실제 Codex/Claude 실행](#준비됐을-때-실제-codexclaude-실행)
9. [안전 모델](#안전-모델)
10. [일반적인 워크플로우](#일반적인-워크플로우)
11. [자주 발생하는 문제와 해결법](#자주-발생하는-문제와-해결법)
12. [커밋 정책](#커밋-정책)
13. [현재 템플릿 버전](#현재-템플릿-버전)
14. [대상 독자](#대상-독자)
15. [라이선스 / 재사용](#라이선스--재사용)

---

## 이 템플릿이 하는 일

이 템플릿을 서비스 레포에 복사하면 다음이 가능해집니다:

- **재사용 가능한 AI 제어 문서와 도구 스크립트를 서비스 레포에 복사**합니다
  (`copy-template-to-service.ps1` 사용, 기본값은 미리보기 전용)
- **설치 검증**을 실행해 필수 파일이 모두 있는지 확인합니다
  (`validate-template-install.ps1`)
- **git status / diff 컨텍스트를 안전하게 수집**합니다 — 비밀 파일은 읽지 않습니다
  (`collect-context.ps1`)
- **테스트 러너를 자동 감지**합니다 — 아무것도 설치하거나 실행하지 않습니다
  (`detect-tests.ps1`)
- **안전한 로컬 테스트를 옵션으로 실행**합니다 (`-TestLevel unit`)
- **Codex 구현 프롬프트를 생성**합니다 (`-Implementer codex`)
- **Codex 원샷 실행을 옵션으로 수행**합니다 (`-RunImplementer`)
- **Claude 리뷰 프롬프트를 생성**합니다 (`-Reviewer claude`)
- **Claude 리뷰-온리 실행을 옵션으로 수행**합니다 (`-RunReviewer`)
- **제한된 Codex ↔ Claude 수정 루프**를 지원합니다 (`-EnableFixLoop`, 최대 3회)
- 모든 실행 결과를 **`AI_FINAL_HANDOFF.md`에 기록**하고 사람의 최종 판단을 요청합니다
- 기본값으로는 **커밋, 푸시, 배포, 패키지 설치를 절대 하지 않습니다**

---

## 이 템플릿이 하지 않는 일

다음은 이 템플릿이 **의도적으로 하지 않는** 일입니다:

- `AI_PRODUCT_SPEC.md` / `AI_TASK_QUEUE.md`를 직접 채우지 않으면 **서비스를 자동으로 이해하지 못합니다** — 컨텍스트는 사람이 작성해야 합니다
- **자동으로 커밋하지 않습니다** (`-AutoCommit`은 오류로 거부됩니다)
- **푸시하지 않습니다**
- **배포하지 않습니다**
- **패키지를 설치하지 않습니다** (`npm`, `pip`, `yarn` 등 모두 금지)
- **샌드박스/권한을 우회하지 않습니다** (`danger-full-access`, `bypass`, `yolo`, `full-auto` 플래그 사용 금지)
- **사람의 리뷰를 대체하지 않습니다** — 하네스는 초안과 요약을 제공하지만 최종 판단은 사람이 합니다
- **프로덕션에 안전하지 않은 변경을 하지 않습니다**
- **명시적 스위치 없이 Codex나 Claude를 실행하지 않습니다** — `-RunImplementer` / `-RunReviewer`가 없으면 프롬프트 파일만 생성합니다

---

## 파일 구조

```
D:\ai-service-template
├─ AI_PRODUCT_SPEC.md            # 서비스 설명 (직접 작성)
├─ AI_ACCEPTANCE_CRITERIA.md     # 단계별 완료 기준
├─ AI_TASK_QUEUE.md              # 작업 큐 (직접 작성)
├─ AI_WORKFLOW.md                # 하네스 동작 흐름 (단계별 상세)
├─ AGENTS.md                     # Codex CLI 가드레일
├─ CLAUDE.md                     # Claude Code CLI 가드레일
├─ README.md                     # 이 파일
├─ TEMPLATE_USAGE.md             # 상세 사용자 가이드
├─ SERVICE_ONBOARDING_CHECKLIST.md  # 비개발자용 체크리스트
├─ TEMPLATE_CHANGELOG.md         # 단계별 변경 이력
├─ TEMPLATE_MANIFEST.json        # 머신-리더블 파일 목록 + 버전
├─ ai-runs/                      # 로컬 전용 실행 아티팩트 (gitignore됨)
│  └─ .gitkeep
└─ tools/
   ├─ ai-autopilot.ps1                  # 하네스 오케스트레이터 (핵심)
   ├─ collect-context.ps1               # git 컨텍스트 안전 스냅샷
   ├─ detect-tests.ps1                  # 테스트 러너 감지 (설치/실행 없음)
   ├─ write-final-handoff.ps1           # AI_FINAL_HANDOFF.md 생성기
   ├─ write-claude-review-prompt.ps1    # Phase 3 리뷰 프롬프트
   ├─ write-codex-implementation-prompt.ps1  # Phase 4 원샷 프롬프트
   ├─ write-codex-fix-prompt.ps1        # Phase 5 수정 루프 프롬프트
   ├─ copy-template-to-service.ps1      # Phase 6 — 기본값: 미리보기 전용
   └─ validate-template-install.ps1    # Phase 6 — 설치 검증 + 스모크 테스트
```

### 주요 파일 설명

| 파일 | 역할 |
|------|------|
| `ai-autopilot.ps1` | 모든 단계를 조율하는 메인 스크립트. 여기서 모든 것이 시작됩니다 |
| `AI_PRODUCT_SPEC.md` | 서비스가 무엇을 하는지, 어떤 기술 스택인지 직접 기술합니다 |
| `AI_TASK_QUEUE.md` | 이번 실행에서 Codex가 처리할 작업 목록입니다 |
| `AI_ACCEPTANCE_CRITERIA.md` | 어떻게 하면 완료로 볼 수 있는지 기준을 정의합니다 |
| `AGENTS.md` | Codex에게 허용/금지 행동을 알려주는 가드레일 문서 |
| `CLAUDE.md` | Claude에게 허용/금지 행동을 알려주는 가드레일 문서 |
| `TEMPLATE_USAGE.md` | 단계별 상세 사용 가이드 (이 README보다 더 깊은 내용) |
| `SERVICE_ONBOARDING_CHECKLIST.md` | 코드를 잘 모르는 사용자를 위한 체크리스트 |
| `copy-template-to-service.ps1` | 이 템플릿을 다른 서비스 레포에 복사합니다 (기본값: 미리보기만) |
| `validate-template-install.ps1` | 복사 후 설치가 올바른지 확인합니다 |
| `ai-runs/` | 실행마다 생성되는 타임스탬프 폴더 (로컬 전용, 커밋 안 됨) |

---

## 사전 요구사항

### 필수

- **Windows PowerShell** (Windows 10/11 기본 내장)
- **Git** — 서비스 레포가 git 레포여야 합니다

### 선택 (해당 기능 사용 시 필요)

- **Claude Code CLI** — Claude 리뷰 기능 사용 시
- **Codex CLI** — Codex 구현 기능 사용 시
- **Node.js / Python** — 서비스 레포에 해당 테스트가 있을 때만

### 버전 확인 명령

```powershell
git --version
claude --version
codex --version
```

> **중요:** `-DryRun`(미리보기)과 프롬프트-온리 흐름은 실제 Codex/Claude가 설치되어 있지 않아도 동작합니다.
> 처음에는 DryRun으로 시작하고, 나중에 실제 실행을 활성화하면 됩니다.

---

## 기존 서비스 레포에 적용하기

아래 예시는 `D:\auto_resume` 레포를 대상으로 합니다.
**실제 사용 시 `D:\auto_resume`을 본인의 서비스 레포 경로로 바꾸세요.**

### 1단계 — 대상 레포가 git 레포인지 확인

```powershell
cd D:\auto_resume
git status --short
```

오류 없이 결과가 나오면 계속 진행합니다.

### 2단계 — 이 템플릿 레포로 이동

```powershell
cd D:\ai-service-template
```

### 3단계 — 미리보기 실행 (파일을 쓰지 않습니다)

```powershell
powershell -ExecutionPolicy Bypass -File .\tools\copy-template-to-service.ps1 -TargetRepo D:\auto_resume
```

어떤 파일이 복사될지 목록만 출력합니다. 아무것도 쓰지 않습니다.
출력 내용을 확인하고 문제가 없으면 4단계로 넘어갑니다.

### 4단계 — 실제 복사 적용

```powershell
powershell -ExecutionPolicy Bypass -File .\tools\copy-template-to-service.ps1 -TargetRepo D:\auto_resume -Apply -IncludeLocalGitignoreRules
```

- `-Apply` 없이는 아무것도 복사되지 않습니다
- `-IncludeLocalGitignoreRules`는 `ai-runs/`, `.claude/` 등의 로컬 전용 경로를 대상 레포의 `.gitignore`에 추가합니다
- 기존 제어 문서(`AI_PRODUCT_SPEC.md` 등)는 덮어쓰지 않습니다 (명시적으로 `-OverwriteControlDocs`를 전달해야 덮어씁니다)

### 5단계 — 설치 검증

```powershell
powershell -ExecutionPolicy Bypass -File .\tools\validate-template-install.ps1 -TargetRepo D:\auto_resume -RunSmoke
```

- 필수 파일이 모두 존재하는지 확인합니다
- `-RunSmoke`는 DryRun 모드로 `ai-autopilot.ps1`을 한 번 실행해 하네스가 정상 동작하는지 확인합니다
- 실제 Codex / Claude / 테스트는 실행하지 않습니다

---

## 복사 후 먼저 수정할 파일들

템플릿 파일이 복사된 후 **반드시 직접 내용을 채워야** 하는 파일들이 있습니다.
이 파일들을 채우지 않으면 Codex / Claude는 서비스 컨텍스트를 알 수 없습니다.

### 1. `AI_PRODUCT_SPEC.md` — 서비스 설명

**무엇을 쓰나요?**
이 서비스가 무엇을 하는지, 기술 스택, 주요 진입점, 외부 의존성 등을 기술합니다.

**예시:**
```markdown
## 서비스 개요
auto_resume은 Python FastAPI 백엔드 + React 프론트엔드로 구성된 이력서 자동 생성 서비스입니다.

## 기술 스택
- Backend: Python 3.11, FastAPI, SQLAlchemy, PostgreSQL
- Frontend: React 18, TypeScript, Tailwind CSS
- 테스트: pytest (백엔드), Vitest (프론트엔드)

## 주요 진입점
- `apps/api/main.py` — FastAPI 앱 진입점
- `apps/web/src/main.tsx` — React 앱 진입점
```

### 2. `AI_TASK_QUEUE.md` — 작업 큐

**무엇을 쓰나요?**
Codex가 이번 실행에서 처리해야 할 구체적인 작업을 나열합니다.
너무 광범위하지 않게, 작고 명확한 단위로 작성하세요.

**예시:**
```markdown
## 현재 스프린트 작업

- [ ] TASK-001: `/api/resume/export` 엔드포인트에 PDF 포맷 지원 추가
- [ ] TASK-002: 이력서 섹션 순서를 드래그 앤 드롭으로 변경하는 프론트엔드 컴포넌트 구현
```

### 3. `AI_ACCEPTANCE_CRITERIA.md` — 완료 기준

**무엇을 쓰나요?**
어떤 조건이 충족됐을 때 작업이 완료됐다고 볼 수 있는지 기술합니다.
테스트 통과, 특정 API 동작, UI 화면 등을 포함하세요.

**예시:**
```markdown
## TASK-001 완료 기준
- `GET /api/resume/{id}/export?format=pdf` 호출 시 200 OK와 PDF 바이너리 반환
- pytest `tests/api/test_export.py` 전체 통과
- 기존 `/export?format=json` 동작이 변경되지 않음
```

### 4. `AGENTS.md` — Codex 가드레일

Codex가 허용/금지할 파일 경로와 명령어를 서비스에 맞게 수정합니다.
기본값은 보수적으로 설정되어 있으므로, 서비스 소스 파일 경로를 허용 목록에 추가하세요.

### 5. `CLAUDE.md` — Claude 가드레일

Claude가 리뷰어로 동작할 때의 허용 범위를 정의합니다.
기본 템플릿은 `Phase 1` 리뷰-온리 모드로 설정되어 있습니다.
서비스별 파일 경로에 맞게 "allowed file scope" 섹션을 업데이트하세요.

> **주의:** 이 파일들을 채우지 않으면 Codex/Claude가 서비스 컨텍스트를 모르는 상태로 실행됩니다.
> 최소한 `AI_PRODUCT_SPEC.md`와 `AI_TASK_QUEUE.md`는 반드시 작성하세요.

---

## 안전한 첫 실행 명령들

아래 명령들은 모두 **Codex도 Claude도 실행하지 않습니다**. 안심하고 시도해 보세요.

서비스 레포 디렉토리로 먼저 이동합니다:

```powershell
cd D:\auto_resume
```

### 완전 DryRun — 아무것도 실행하지 않음

```powershell
powershell -ExecutionPolicy Bypass -File .\tools\ai-autopilot.ps1 -DryRun -Goal "service smoke test"
```

`ai-runs/<타임스탬프>/` 폴더가 생성되고, git 컨텍스트 수집 + 테스트 감지 + `AI_FINAL_HANDOFF.md` 생성만 합니다.
Codex, Claude, 테스트 실행 없음.

### 유닛 테스트만 실행

```powershell
powershell -ExecutionPolicy Bypass -File .\tools\ai-autopilot.ps1 -TestLevel unit -Goal "unit validation"
```

로컬 유닛 테스트만 실행합니다. Codex, Claude 없음.
`-TestLevel`은 `unit` / `integration` / `e2e` / `all` 중 선택 가능합니다.

### Codex 프롬프트만 생성 (DryRun)

```powershell
powershell -ExecutionPolicy Bypass -File .\tools\ai-autopilot.ps1 -Implementer codex -DryRun -Goal "Codex prompt only"
```

`codex-implementation-prompt.md` 파일을 생성합니다. Codex CLI를 실행하지 않습니다.
프롬프트 내용을 직접 확인하고 ChatGPT / Codex Web에 붙여넣어 사용할 수 있습니다.

### Claude 리뷰 프롬프트만 생성 (DryRun)

```powershell
powershell -ExecutionPolicy Bypass -File .\tools\ai-autopilot.ps1 -Reviewer claude -DryRun -Goal "Claude review prompt only"
```

`claude-review-prompt.md` 파일을 생성합니다. Claude CLI를 실행하지 않습니다.
프롬프트를 Claude 웹 인터페이스에 붙여넣어 수동으로 리뷰받을 수 있습니다.

---

## 준비됐을 때: 실제 Codex/Claude 실행

> **⚠ 고급 기능입니다.** 프롬프트-온리 모드로 출력 내용을 먼저 검증한 후에 사용하세요.
> 실행 전 `AI_PRODUCT_SPEC.md`와 `AI_TASK_QUEUE.md`가 채워져 있어야 합니다.

### Codex 원샷 실행

```powershell
powershell -ExecutionPolicy Bypass -File .\tools\ai-autopilot.ps1 `
    -Implementer codex -RunImplementer `
    -TestLevel unit `
    -Goal "implement one small task"
```

- `-RunImplementer`가 있어야만 Codex CLI가 실제로 실행됩니다
- Codex는 `codex exec --sandbox workspace-write` 패턴으로 실행됩니다 (위험 플래그 없음)
- 실행 후 `AI_FINAL_HANDOFF.md`를 확인하고 사람이 직접 결과를 검토합니다

### Claude 리뷰-온리 실행

```powershell
powershell -ExecutionPolicy Bypass -File .\tools\ai-autopilot.ps1 `
    -Reviewer claude -RunReviewer `
    -TestLevel unit `
    -Goal "review current changes"
```

- `-RunReviewer`가 있어야만 Claude CLI가 실제로 실행됩니다
- Claude는 `claude -p ... --tools ""` (파일 편집 없음, 리뷰-온리) 패턴으로 실행됩니다

### 제한된 Codex ↔ Claude 수정 루프

```powershell
powershell -ExecutionPolicy Bypass -File .\tools\ai-autopilot.ps1 `
    -Implementer codex -RunImplementer `
    -Reviewer claude -RunReviewer `
    -EnableFixLoop -MaxIterations 2 `
    -TestLevel unit `
    -Goal "implement one small task with bounded review loop"
```

- `-EnableFixLoop`는 기본값이 비활성화입니다 — 명시적으로 전달해야 합니다
- `-MaxIterations`는 최대 `3`으로 하드캡되어 있습니다. `4` 이상을 전달하면 실행 전에 오류로 중단됩니다
- 루프가 끝나도 **사람의 최종 승인이 필요합니다** — 하네스는 자동으로 커밋하지 않습니다

---

## 안전 모델

### 기본값 (스위치 없이 실행 시)

| 항목 | 기본값 |
|------|--------|
| Codex 실행 | ❌ 비활성 (프롬프트 파일만 생성) |
| Claude 실행 | ❌ 비활성 (프롬프트 파일만 생성) |
| 테스트 실행 | ❌ 비활성 (`-TestLevel none`) |
| 자동 커밋 | ❌ 거부됨 (오류 발생) |
| 수정 루프 | ❌ 비활성 |
| 최대 반복 횟수 | 3 (하드캡) |

### 명시적 승인이 필요한 항목

- `-RunImplementer` — Codex 실제 실행
- `-RunReviewer` — Claude 실제 실행
- `-EnableFixLoop` — 수정 루프 활성화
- `-TestLevel unit/integration/e2e/all` — 테스트 실행
- `-Apply` — 파일 복사 실행

### 절대 금지 항목 (어떤 플래그로도 우회 불가)

- `git commit`, `git push`, `git tag`, 배포 명령
- 패키지 설치 (`npm`, `pnpm`, `yarn`, `pip`, `poetry`, `uv` 등)
- `-AutoCommit` (오류로 거부)
- 위험 Codex 플래그 (`danger-full-access`, `--dangerously-bypass-approvals-and-sandbox`, `--full-auto`, yolo, bypass)
- 위험 Claude 플래그 (`--dangerously-skip-permissions`, `acceptEdits`, `bypassPermissions`, allowed-edit, allowed-bash)
- 비밀 파일 읽기 (`.env`, `*.pem`, `*.key`, `*secret*`)
- 레포 루트 밖의 파일 수정

### 로컬 전용 아티팩트

- `ai-runs/<타임스탬프>/` — `.gitignore`로 추적 제외. 절대 커밋하지 마세요
- `.claude/` — 로컬 Claude Code CLI 설정. 커밋 제외

### diff 보수 기준 (수정 루프)

- `-MaxChangedFiles` 기본값: `12` (변경 파일 수 초과 시 루프 중단)
- `-MaxDiffStatLines` 기본값: `120` (diff 라인 수 초과 시 루프 중단)

---

## 일반적인 워크플로우

1. **ChatGPT로 계획 수립** — 어떤 기능을 구현할지, 어떤 파일을 수정할지 논의합니다
2. **`AI_PRODUCT_SPEC.md` / `AI_TASK_QUEUE.md` 업데이트** — 계획 내용을 문서에 반영합니다
3. **DryRun 실행** — 하네스가 정상 동작하는지, git 상태가 깨끗한지 확인합니다
4. **테스트 실행** — `-TestLevel unit`으로 기존 테스트가 통과하는지 확인합니다
5. **Codex 프롬프트 생성** — `-Implementer codex -DryRun`으로 프롬프트를 확인합니다
6. **Claude 리뷰 프롬프트 생성** — `-Reviewer claude -DryRun`으로 리뷰 프롬프트를 확인합니다
7. **선택: Codex 원샷 실행** — 프롬프트가 올바르다면 `-RunImplementer`로 실제 실행합니다
8. **선택: Claude 리뷰 실행** — `-RunReviewer`로 Claude가 변경사항을 리뷰하게 합니다
9. **선택: 제한된 루프 활성화** — `-EnableFixLoop -MaxIterations 2`로 최대 2회 반복합니다
10. **`AI_FINAL_HANDOFF.md` 확인** — 실행 요약, 변경된 파일 목록, Claude 리뷰 결과를 읽습니다
11. **사람이 커밋 여부 결정** — 만족스러우면 `git add` + `git commit`을 직접 실행합니다

---

## 자주 발생하는 문제와 해결법

### TargetRepo 경로가 존재하지 않음

**증상:** `copy-template-to-service.ps1` 실행 시 "TargetRepo does not exist" 오류

**원인:** 경로가 잘못되었거나 드라이브 문자가 틀렸습니다

**해결:** `Get-Item D:\auto_resume` 로 경로를 확인하세요. 경로에 한글이 있으면 따옴표로 감싸세요:
```powershell
-TargetRepo "D:\내 프로젝트\auto_resume"
```

---

### TargetRepo가 git 레포가 아님

**증상:** "TargetRepo is not a git repository" 오류

**원인:** 대상 폴더에 `.git/`이 없습니다

**해결:** 해당 폴더에서 `git init` 또는 `git clone`을 먼저 실행하세요

---

### 테스트를 찾지 못함

**증상:** "No test runners detected" 경고

**원인:** `package.json`, `pytest.ini`, `setup.cfg`, `pyproject.toml` 등이 없거나
 test 스크립트가 정의되지 않았습니다

**해결:** 경고는 무시해도 됩니다. 테스트 감지는 정보 제공 목적입니다.
실제 테스트가 있다면 서비스 레포에서 직접 확인하세요

---

### MaxDiffStatLines 초과

**증상:** "Diff stat lines (N) exceeds MaxDiffStatLines (120)" 루프 중단

**원인:** 변경된 코드가 너무 많아 안전 한계를 초과했습니다

**해결:** 작업 범위를 줄이거나, 필요하다면 명시적으로 한계를 높이세요:
```powershell
-MaxDiffStatLines 200
```

---

### MaxChangedFiles 초과

**증상:** "Changed file count (N) exceeds MaxChangedFiles (12)" 루프 중단

**원인:** 너무 많은 파일이 변경되었습니다

**해결:** 작업을 더 작은 단위로 나누거나, 필요 시:
```powershell
-MaxChangedFiles 20
```

---

### MaxIterations 거부됨

**증상:** "MaxIterations must be between 1 and 3" 오류로 실행 중단

**원인:** `-MaxIterations 4` 이상을 전달했습니다

**해결:** 최대 `3`으로 제한되어 있습니다. `3` 이하로 설정하세요

---

### Claude CLI 플래그 미지원 오류

**증상:** Claude 실행 시 "Unknown flag" 또는 플래그 오류

**원인:** Claude CLI 버전이 너무 오래되었거나 플래그가 변경되었습니다

**해결:** `claude --version`으로 버전 확인 후 업데이트:
```powershell
npm install -g @anthropic-ai/claude-code
```

---

### Codex CLI 플래그 미지원 오류

**증상:** Codex 실행 시 "Unknown flag" 또는 `--sandbox workspace-write` 오류

**원인:** Codex CLI 버전이 너무 오래되었거나 API가 변경되었습니다

**해결:** `codex --version`으로 버전 확인 후 업데이트

---

### ExecutionPolicy 오류

**증상:** "running scripts is disabled on this system" 오류

**원인:** PowerShell 실행 정책이 스크립트를 막고 있습니다

**해결:** 각 명령에 `-ExecutionPolicy Bypass`를 포함해서 실행하세요 (이미 가이드에 포함됨):
```powershell
powershell -ExecutionPolicy Bypass -File .\tools\ai-autopilot.ps1 ...
```

---

### ai-runs 폴더가 git status에 보이지 않음

**증상:** `ai-runs/<타임스탬프>/` 폴더가 `git status`에 나타나지 않음

**원인:** `.gitignore`에 `ai-runs/*`가 등록되어 있기 때문입니다 — **정상입니다**

**해결:** 이 폴더는 의도적으로 추적 제외됩니다. 실행 아티팩트는 커밋하지 마세요

---

### LF will be replaced by CRLF 경고

**증상:** `git add` 시 "LF will be replaced by CRLF" 경고

**원인:** 윈도우의 git 설정이 줄바꿈 변환을 하도록 되어 있습니다

**해결:** 경고이므로 무시해도 됩니다. 불편하면:
```powershell
git config --global core.autocrlf input
```

---

## 커밋 정책

**이 하네스는 절대로 커밋하지 않습니다.**

모든 커밋은 사람이 직접 합니다. 커밋 전 반드시 변경사항을 검토하세요:

```powershell
# 변경된 파일 목록 확인
git status --short

# 변경 통계 확인
git diff --stat

# 공백 오류 확인
git diff --check

# 전체 diff 확인
git diff
```

문제가 없다면 직접 커밋합니다:

```powershell
git add <변경된 파일들>
git commit -m "feat: <작업 내용 요약>"
```

---

## 현재 템플릿 버전

| 항목 | 값 |
|------|-----|
| TemplateVersion | `0.6.0` |
| Latest known commit | `d8d77f6` |
| 구현된 Phase | 1, 2, 3, 4, 5, 6 |
| Phase 6 bugfix | collect-context 및 validation 스모크 아티팩트 하드닝 |

### 구현된 단계 요약

| Phase | 내용 |
|-------|------|
| 1 | 제어 문서 + PowerShell 하네스 기반 + 최종 핸드오프 문서 |
| 2 | 테스트 감지 + 선택적 안전 테스트 실행 |
| 3 | Claude 리뷰 프롬프트 생성 + 선택적 리뷰-온리 Claude 실행 |
| 4 | Codex 원샷 구현 프롬프트 + 선택적 `codex exec --sandbox workspace-write` |
| 5 | 제한된 Codex ↔ Claude 수정 루프 스캐폴딩 (opt-in, 최대 3회) |
| 6 | 패키징, 온보딩, 서비스 복사 도구, 설치 검증, 매니페스트, 변경 이력 |

---

## 대상 독자

- Codex CLI와 Claude Code CLI를 실제 서비스 레포에 사용하고 싶지만 **푸시/배포 권한을 주고 싶지 않은** 솔로 개발자 또는 소규모 팀
- **코드를 깊이 읽기 어렵고** 체크리스트, 미리보기 모드, 명시적 사람 승인 게이트가 필요한 사용자
- **동일한 하네스, 동일한 가드레일, 동일한 `AI_FINAL_HANDOFF.md` 흐름**을 여러 서비스 레포에 걸쳐 유지하고 싶은 사용자

---

## 라이선스 / 재사용

이 저장소는 MIT License로 공개됩니다. 자세한 내용은 `LICENSE`를 참고하세요.

본인의 서비스 레포에 자유롭게 복사하세요.
템플릿의 안전 보장은 다음 조건을 지킬 때만 유효합니다:

- 하네스 스크립트를 수정하지 않을 것
- 위험 플래그(`danger-full-access`, bypass 등)를 추가하지 않을 것
- `-DryRun` / `-RunImplementer` / `-RunReviewer` 게이팅을 우회하지 않을 것

확신이 없다면 `SERVICE_ONBOARDING_CHECKLIST.md`를 먼저 읽으세요.
