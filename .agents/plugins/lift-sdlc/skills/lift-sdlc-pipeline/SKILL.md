---
name: lift-sdlc-pipeline
description: Automates full SDLC pipeline from task planning, pre-flight linting, git commit generation, pull request drafting, and semantic release tagging.
---

# Lift-SDLC Pipeline Skill

Use this workflow to safely transition code changes from ideation to production release.

## 1. Stage 1: Quality Pre-Flight
- Run static analyzer: `flutter analyze`
- Verify unit & widget tests: `flutter test`
- Inspect untracked and modified files: `git status --porcelain`

## 2. Stage 2: Conventional Commit Construction
- Format commit message: `<type>(<scope>): <short description>`
- Types: `feat`, `fix`, `refactor`, `perf`, `chore`, `docs`
- Always verify that no secrets or unintended debug logs are committed.

## 3. Stage 3: Pull Request & Release Generation
- Auto-generate structured summary:
  - **Summary**: Concise bullet points of what changed.
  - **Testing**: Proof of test passes and zero lint issues.
  - **Impact**: Breaking changes (if any) and affected routes.
- Push strictly to designated branch (`main` / `origin/main`).
