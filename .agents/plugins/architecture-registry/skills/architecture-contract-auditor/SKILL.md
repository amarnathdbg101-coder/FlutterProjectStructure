---
name: architecture-contract-auditor
description: Audits architectural boundaries, routes, models, and API contracts against project specifications.
---

# Architecture Contract Auditor

## 1. Schema & Model Synchronization
- Validates frontend Dart models with backend Go models (`ShopModel`, `ProductModel`, `UserModel`).
- Ensures JSON serialization/deserialization fields match exactly.

## 2. Route & Dependency Integrity
- Audits `AppRouter` configuration to ensure no orphan paths exist.
- Verifies state management provider bindings in `MultiProvider`.
