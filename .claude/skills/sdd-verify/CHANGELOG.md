# Changelog — sdd-verify

- **v0.1** — first version. Closes the SDD roadmap gap of "review/verify with evidence" that
  Spec Kit does not cover natively (`speckit-converge` only adds missing tasks; it does not verify).
  Invocable skill that runs **after** `/speckit-implement` or `/sdd-implement`: reads the feature's
  `spec.md`, compiles each Acceptance Scenario (reference "US-N / Acceptance Scenario M") and each
  Success Criterion (`SC-00N`), and for each one performs a **targeted verification** against the
  repo's actual state (specific command, `test -f`, file reading, or reuse of already existing
  implementation evidence) — the same adversarial attitude as Principle I of the constitution.
  No criterion may be marked `pass` without citing the actual evidence used in the same row of
  `verify-report.md` (FR-004); if there is no objective way to verify it, it is marked `no verificable`
  with the reason in `detalle`; it is never forced to `pass`/`fail` without a basis (FR-003,
  Acceptance Scenario 3 of User Story 2). If the feature does not have `tasks.md` with at least one
  `[X]` task, it reports "nothing to verify yet" and **does not** generate `verify-report.md` — it
  avoids fabricated verdicts (Edge Case of `spec.md`). It does not run its own test suite: it reuses
  existing evidence or runs targeted verifications itself (Assumptions of `spec.md`). The only
  output is a new file in the feature folder (`verify-report.md`, one row per criterion according to
  `data-model.md`); the format of `spec.md`/`plan.md`/`tasks.md` does not change, so
  `speckit-converge`/`speckit-analyze` continue working the same way afterward. Natural consumer:
  `sdd-archive`, which refuses to archive if any `fail`/`no verificable` remains.
