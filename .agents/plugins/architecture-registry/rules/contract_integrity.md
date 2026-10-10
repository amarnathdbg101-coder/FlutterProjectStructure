# Architecture Contract Integrity Rules

1. **No Untyped Dictionaries in Business Logic**:
   - All backend API payloads must map to typed model classes (`fromJson` / `toJson`).
2. **Endpoint Uniformity**:
   - Never use `/api/v1` prefix. Backend endpoints strictly map to `/auth/...`, `/shops/...`, `/products/...`.
3. **Role Enforcement**:
   - Merchant portal strictly enforces `role: 'merchant'`.
