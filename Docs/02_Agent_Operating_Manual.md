# Agent Operating Manual

Agents must work from the ledgers before making product claims. Required reading:

- `00_Master_Charter.md`
- `01_Project_Ledger.md`
- `08_AI_Memory_Ledger.md`
- `09_Verification_Ledger.md`
- `11_Agent_Handoff.md`
- `18_Reality_Ledger.md`
- `19_Privacy_Ledger.md`
- `20_Commercial_Ledger.md`

Rules:

- Do not add cloud, telemetry, or paid API dependencies to core V1.
- Do not implement repository mutation in V1.
- Keep all business logic in `LocalForgeCore`.
- Label stubs honestly.
- Verify builds/tests before claiming completion.
