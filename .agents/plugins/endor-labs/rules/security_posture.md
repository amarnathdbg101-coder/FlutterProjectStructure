# Security Posture Rules

1. **Zero Secret Hardcoding**:
   - Environment variables or `secure_storage` must be used for sensitive tokens. Never check secrets into version control.
2. **Safe Input Validation**:
   - Validate and sanitize all user and merchant input before passing to network requests or queries.
