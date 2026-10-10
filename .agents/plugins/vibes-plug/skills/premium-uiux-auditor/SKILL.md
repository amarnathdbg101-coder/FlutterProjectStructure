---
name: premium-uiux-auditor
description: Ensures premium minimalist UI/UX design, fluid typography, smooth animations, and cross-platform zero-overflow responsiveness.
---

# Vibes Plug: Premium UI/UX Auditor Skill

## 1. Visual Hierarchy & Color Theory
- Use curated slate neutrals (`colorBg`, `colorSurface`, `colorSurfaceSubtle`, `colorBorder`).
- Accents: Consistent emerald/primary tones without harsh clashing colors.

## 2. Multi-Screen Clamping & Responsiveness
- Enforce `ResponsiveContainer` on wide desktop/web screens to prevent stretched controls.
- Wrap all bottom sheets and dialog forms in `SingleChildScrollView` with `viewInsets.bottom` keyboard padding.
- Clamped KPI counters using `FittedBox` to prevent font scaling overflows.
