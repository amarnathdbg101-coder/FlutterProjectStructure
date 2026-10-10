---
name: appsec-auditor
description: Performs dependency vulnerability assessments, token leakage checks, and static application security testing (SAST).
---

# Endor Labs AppSec Auditor Skill

## 1. Secret Scanning
- Scans modified files for hardcoded JWTs, private keys, passwords, and API credentials before staging commits.

## 2. Dependency Risk Assessment
- Inspects newly added dependencies in `pubspec.yaml` and `go.mod` for known CVEs, malicious maintainer takeovers, or abandoned packages.
