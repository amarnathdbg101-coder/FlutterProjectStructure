# AGY-HUD Telemetry Rules

1. **Context Window Optimization**:
   - Always limit file reads to targeted sections (`view_file` slices <= 100 lines).
   - Keep tool output compact and clean.
2. **Proactive Health Notifications**:
   - Notify the user immediately when long-running background tasks start or finish.
