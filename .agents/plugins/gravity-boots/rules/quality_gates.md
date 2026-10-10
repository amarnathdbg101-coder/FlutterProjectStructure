# Quality Gates & Coding Standards

1. **Gate 1: Zero Compiler Errors**:
   - Every file change must produce zero compile errors and zero warnings.
2. **Gate 2: Safe Async Operations**:
   - All asynchronous state changes must check `mounted` before executing UI updates or Navigator/Context calls.
3. **Gate 3: Compressed Communication**:
   - Eliminate filler prose and deliver clear, high-density engineering responses.
