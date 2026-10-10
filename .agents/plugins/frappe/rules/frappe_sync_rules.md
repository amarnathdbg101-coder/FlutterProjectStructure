# Frappe Database & Sync Rules

1. **Transactional Integrity**:
   - Always commit database entries with ACID compliance. Rollback on failure.
2. **Schema Mirroring**:
   - Ensure external DocType definitions stay aligned with local model properties.
