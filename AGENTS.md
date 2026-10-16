# Agent brief — Mobile Explorer

- Read `docs/PRD.md`, `docs/TRD.md`, `specs/FEATURES.md` and `SHARED_TASK_NOTES.md` before editing.
- Use STAR and worktrees; never touch other sessions' locks, branches or worktrees.
- P0 is metadata enumeration + user-authored notes, NOT automatic reverse engineering.
- Never add bypasses for FairPlay/DRM, iOS sandbox, device lock, access control or app secrets.
- Never upload device identifiers, notes, screenshots or app content by default.
- `swift build && swift test` on macOS with Xcode, with real device authorized for integration tests.
- Document untested Apple SDK APIs honestly, then fix through actual Mac validation.
