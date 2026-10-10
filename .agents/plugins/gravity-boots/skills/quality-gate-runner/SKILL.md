---
name: quality-gate-runner
description: Runs strict quality gates, verifies code health, and compresses communication into actionable engineering checkpoints.
---

# Gravity Boots: Quality Gate Runner

## 1. Token-Compressed Operations
- Inspect files with line slicing (`view_file` StartLine/EndLine) rather than full reads.
- Target regex searches with `grep_search` to conserve context memory.
- Provide concise, actionable feedback to the user without repetitive text.

## 2. Shell Safety Protocols
- Never run infinite background loops or blocking wait commands without asynchronous handlers.
- Use native package manager and build tooling with targeted flags.
