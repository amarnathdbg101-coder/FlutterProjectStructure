---
name: context-telemetry
description: Telemetry skill for monitoring context window consumption, token budgets, and agent subagent lifecycles.
---

# AGY-HUD Context Telemetry Skill

## 1. Context Tracking
- Monitors conversation history token depth and prompts when context window approaches compaction.
- Prefers localized code slices over massive file dumps to prevent premature context loss.

## 2. Resource & Quota Health
- Tracks background task completion states (`manage_task`).
- Audits active tool invocations to keep agent response latency low.
