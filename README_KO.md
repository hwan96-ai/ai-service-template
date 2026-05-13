# AI Service Template (한국어 안내)

[![Pester Safety Tests](https://github.com/hwan96-ai/ai-service-template/actions/workflows/pester.yml/badge.svg)](https://github.com/hwan96-ai/ai-service-template/actions/workflows/pester.yml)
[![Latest Release](https://img.shields.io/github/v/release/hwan96-ai/ai-service-template?display_name=tag&sort=semver)](https://github.com/hwan96-ai/ai-service-template/releases)
[![License: MIT](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)

<p align="center">
  <img src="assets/hero-banner.svg" alt="AI Service Template — 로컬 · 미리보기 우선 · 사람 중심 AI 코딩 안전 하네스" width="100%">
</p>

> Codex CLI 와 Claude Code CLI 를 실제 저장소에서 안전하게 쓰기 위한 **로컬 · 미리보기 우선 · 사람 중심(human-in-the-loop)** 안전 장치.

원문 README 는 [README.md](README.md) 에 있습니다. 이 문서는 한국어 사용자를 위한 실용적인 요약입니다.

<p align="center">
  <img src="assets/workflow-overview.svg" alt="워크플로: 설치 → 부트스트랩 읽기 → dry-run 미리보기 → 사람 검토 게이트 → 명시적 opt-in 실행 → 사람이 직접 커밋" width="100%">
</p>

---

## 1. 이 프로젝트가 무엇인가요?

- Windows + PowerShell 기반의 **로컬 안전 레이어** 입니다.
- Codex CLI 와 Claude Code CLI 를 실제 서비스 저장소에서 쓸 때, AI 가 마음대로 커밋/푸시/배포/의존성 설치 같은 행동을 하지 않도록 막아주는 가드레일과 워크플로 스크립트 모음입니다.
- 모든 실행은 기본적으로 **dry-run / prompt-only** 입니다. 즉, 실제 AI 호출 없이 "어떤 일이 일어날지" 만 먼저 사람에게 보여줍니다.
- 마지막에는 사람이 직접 검토할 수 있는 `AI_FINAL_HANDOFF.md` 가 만들어집니다.

## 2. 이 프로젝트가 아닌 것

- 호스팅형 AI 코딩 서비스가 아닙니다.
- Codex CLI 나 Claude Code CLI 자체를 대체하지 않습니다. 두 CLI 는 별도로 설치하고 인증해야 합니다.
- 완전 자동화 도구가 아닙니다. 자동 커밋, 자동 푸시, 자동 배포, 자동 의존성 설치를 하지 않습니다.
- MCP 런타임이나 플러그인 시스템이 아닙니다.
- 모든 위험을 막아주는 보안 제품이 아닙니다. 사람의 검토가 마지막 안전망입니다.

## 3. 언제 쓰면 좋을까요?

- 실제 서비스 저장소에서 Codex CLI 또는 Claude Code CLI 의 도움을 받고 싶지만, **AI 가 직접 커밋/푸시/배포하는 것은 막고 싶을 때**.
- AI 가 실제로 실행되기 전에 **프롬프트와 의도된 변경을 먼저 사람이 검토** 하고 싶을 때.
- AI 작업이 끝난 뒤에도 `git status`, 감지된 테스트, AI 출력, 검토 메모, 남은 위험을 정리한 **반복 가능한 핸드오프 문서**가 필요할 때.
- Windows + PowerShell 환경에서 작업할 때.

다음 경우에는 적합하지 않습니다.

- 자동 배포까지 한 번에 하고 싶을 때.
- 모든 게이트를 무시하고 AI 가 곧장 커밋/푸시하길 원할 때.
- 리눅스/맥OS 셸을 1차 지원하는 도구가 필요할 때.

## 4. 워크플로 한눈에 보기

1. 템플릿을 대상 저장소에 설치합니다 (미리보기 먼저, `-Apply` 로 적용).
2. AI 에이전트가 먼저 `AI_AGENT_BOOTSTRAP.md` 를 읽습니다.
3. dry-run / prompt-only 로 실행하면 `ai-runs/<timestamp>/` 에 로컬 산출물이 생성됩니다.
4. 사람이 `AI_FINAL_HANDOFF.md` 와 프롬프트 산출물을 검토합니다.
5. 안전하다고 판단되면 그때만 명시적으로 Codex/Claude 실행을 opt-in 합니다.
6. 사람이 직접 `git add`, `git commit`, `git push` 를 수행합니다.

## 5. 설치 방법 (preview-first)

대상 저장소(`D:\some-project` 등)에서 실행합니다. **먼저 `-Apply` 없이 미리보기**를 돌리고, 산출물이 안전해 보일 때만 `-Apply` 로 적용하세요.

```powershell
cd D:\some-project

$u = "https://raw.githubusercontent.com/hwan96-ai/ai-service-template/v0.6.11/tools/install-ai-service-template.ps1"
$p = "$env:TEMP\install-ai-service-template.ps1"
Invoke-WebRequest $u -OutFile $p

# 1) 미리보기 (파일은 아직 쓰이지 않음)
powershell -ExecutionPolicy Bypass -File $p `
  -TargetRepo . `
  -Version v0.6.11 `
  -IncludeLocalGitignoreRules

# 2) 미리보기가 안전해 보이면 적용
powershell -ExecutionPolicy Bypass -File $p `
  -TargetRepo . `
  -Version v0.6.11 `
  -Apply `
  -IncludeLocalGitignoreRules
```

설치 스크립트는 GitHub 에서 태그된 아카이브를 다운로드한 뒤 `TEMP` 에 풀어, 그 안의 복사 스크립트를 실행합니다. `curl | sh` 식의 파이프 실행은 사용하지 않습니다.

## 6. 기존 문서는 덮어쓰지 않습니다

설치 시 다음 파일들은 **기본적으로 보존**됩니다.

- `README.md`
- `AGENTS.md`
- `CLAUDE.md`
- `AI_AGENT_BOOTSTRAP.md`
- 그 외 `AI_PRODUCT_SPEC.md`, `AI_TASK_QUEUE.md`, `AI_ACCEPTANCE_CRITERIA.md`, `AI_WORKFLOW.md` 등 AI 제어 문서

미리보기 출력에는 `[skip-existing-readme]`, `[skip-existing-control-doc] <파일>` 같은 줄이 표시됩니다. **의도적으로 교체하고 싶을 때만** `-OverwriteReadme`, `-OverwriteControlDocs` 같은 옵션을 켜세요.

## 7. 핵심 문서의 역할

| 문서 | 역할 |
| --- | --- |
| `AI_AGENT_BOOTSTRAP.md` | 설치 후 AI 에이전트가 **가장 먼저 읽어야 하는 안내문**. 안전 규칙과 작업 흐름을 요약합니다. |
| `AGENTS.md` | Codex CLI 용 가드레일 및 작업 규칙. |
| `CLAUDE.md` | Claude Code CLI 용 가드레일 및 작업 규칙. |
| `AI_PRODUCT_SPEC.md` | 대상 서비스의 사람이 쓴 컨텍스트(무엇을 만드는 서비스인지). |
| `AI_TASK_QUEUE.md` | 사람이 관리하는 작업 큐. |
| `AI_ACCEPTANCE_CRITERIA.md` | 완료 조건과 안전 기준. |
| `AI_WORKFLOW.md` | 권장 워크플로 설명. |
| `ai-runs/<timestamp>/AI_FINAL_HANDOFF.md` | 매 실행마다 만들어지는 **사람 검토용 최종 핸드오프**. |

## 8. 사람이 직접 해야 하는 일

- `git add`, `git commit`, `git push`
- 태그 생성, 릴리스 노트 작성
- 의존성 설치 (`npm install`, `pip install` 등)
- 배포 트리거
- 실제 Codex / Claude 실행을 허용할지 여부 결정

이 하네스는 위 작업을 자동으로 수행하지 않으며, 그렇게 보이는 플래그(`--full-auto`, `danger-full-access`, `--dangerously-bypass-approvals-and-sandbox`, `--dangerously-skip-permissions` 등)도 기본값으로 사용하지 않습니다.

## 9. v0.6.11 기준 빠른 사용 예시

대상 서비스 저장소에 하네스가 이미 설치되어 있다고 가정합니다.

```powershell
cd D:\your-service-repo

# 감지 전용 스모크 런 (테스트 실행 없음, Codex/Claude 호출 없음)
powershell -ExecutionPolicy Bypass -File .\tools\ai-autopilot.ps1 `
  -DryRun -Goal "service smoke test"

# Codex 구현 프롬프트만 생성 (Codex 실행 안 함)
powershell -ExecutionPolicy Bypass -File .\tools\ai-autopilot.ps1 `
  -Implementer codex -DryRun -Goal "Generate a Codex implementation prompt only"

# Claude 리뷰 프롬프트만 생성 (Claude 실행 안 함)
powershell -ExecutionPolicy Bypass -File .\tools\ai-autopilot.ps1 `
  -Reviewer claude -DryRun -Goal "Generate a Claude review prompt only"
```

각 명령은 `ai-runs/<timestamp>/` 아래에 산출물과 `AI_FINAL_HANDOFF.md` 를 만듭니다. 실제 AI 실행은 핸드오프를 사람이 검토한 뒤, 별도의 실행 플래그(`-RunImplementer`, `-RunReviewer` 등) 를 명시적으로 추가했을 때만 수행됩니다.

## 10. 더 읽어보기

- [README.md](README.md) — 영어 원문
- [SECURITY.md](SECURITY.md) — 안전 경계, 신뢰 가정, 비목표
- [CONTRIBUTING.md](CONTRIBUTING.md) — 기여 가이드
- [TEMPLATE_USAGE.md](TEMPLATE_USAGE.md) — 자세한 사용 가이드
- [SERVICE_ONBOARDING_CHECKLIST.md](SERVICE_ONBOARDING_CHECKLIST.md) — 서비스 도입 체크리스트
- [TEMPLATE_CHANGELOG.md](TEMPLATE_CHANGELOG.md) — 릴리스 히스토리
