# SDLC & DevOps Rules

1. **Clean Branch Discipline**:
   - Always push directly to `origin/main`. Avoid detached heads or unmerged feature branches without automated verification.
2. **Zero Failing Commits**:
   - Never commit code that fails `flutter analyze` or contains syntax/lint warnings.
3. **Traceability**:
   - Every major user-facing feature change must be noted in `PROJECT_RULEBOOK.md`.
