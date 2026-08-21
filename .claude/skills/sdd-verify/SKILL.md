---
name: "sdd-verify"
description: "Verifies an already-implemented feature against its spec.md: it checks every acceptance scenario and success criterion and gives a pass/fail/not-verifiable verdict for each against the real state of the repo, citing the real evidence used for each pass. Generates verify-report.md inside specs/<feature>/."
argument-hint: "Directory or folder name of the feature to verify (e.g. specs/002-sdd-gap-skills or 002-sdd-gap-skills). If omitted, it is resolved the same way as speckit-implement (prerequisites script)."
compatibility: "Requires Spec Kit project structure (.specify/) with the feature's spec.md and a real implementation (tasks.md with at least one task marked [X])"
metadata:
  status: experimental
  version: "0.1"
user-invocable: true
disable-model-invocation: false
---

## What this skill does

Covers the "review/verify with evidence" gap that Spec Kit doesn't natively solve:
`speckit-converge` only adds missing tasks, it doesn't verify. This skill runs **after**
`/speckit-implement` or `/sdd-implement`, on a feature that already has a real implementation in the
repo, and answers, criterion by criterion, whether that implementation fulfills what `spec.md`
asked for — backed by real evidence (a command run and its result, or a file/line read), not by
someone's word that "it already works".

Verifying means, for each Acceptance Scenario and Success Criterion in `spec.md`, running a
**targeted check** against the real state of the repo — a specific command, a `test -f`, a
file read — and classifying the result as `pass`, `fail`, or `not verifiable`. Same adversarial
standard as Principle I of the constitution, applied to the codebase: a `pass` is never marked
without the evidence that led to that verdict being cited in the same row of the report,
and a verdict is never forced when there's no basis for it (Principle II: don't invent verdicts or
mechanisms without a concrete need).

It does not run its own automated test suite — it reuses evidence that already exists from the
implementation (tests run during `/sdd-implement`, commands already executed) or runs the
targeted checks itself when the criterion allows for it, consistent with the fact that this repo has no
unified test framework (Assumptions in `spec.md`). It does not touch code: it only writes one
new file in the feature's folder.

## User Input

```text
$ARGUMENTS
```

Resolve which feature to verify: if the argument carries the feature's directory or folder name
(`specs/NNN-name/` or `NNN-name`), it's used as-is. If it's empty, it is resolved the same way
as `speckit-implement` (prerequisites script, Step 1), allowing for `tasks.md` not to exist.

## Step 1 — resolve the feature and unblock "nothing to verify yet"

1. If the argument carries the feature's directory, take it directly. If not, run
   `.specify/scripts/bash/check-prerequisites.sh --json` **without** `--require-tasks` (unlike
   `speckit-implement`: here it's a valid case, not an error, for `tasks.md` not to exist or to have no
   tasks marked) and resolve `FEATURE_DIR` and `AVAILABLE_DOCS`.
2. **Gate 1: nothing to verify yet.** If `FEATURE_DIR/tasks.md` doesn't exist, or exists but has
   **zero** tasks marked `[X]`, stop here and explicitly report **"nothing to verify
   yet"**: without a task marked as done there's no implementation to check against
   `spec.md`. **Do not generate `verify-report.md`** in that case — fabricating verdicts without a basis violates the
   Edge Case in `spec.md` and Principle I. It's not a failure of the skill: it's the correct state of a
   feature that hasn't been implemented yet, and it's communicated as such.
3. If `spec.md` doesn't exist in `FEATURE_DIR`, stop and report that there's no specification to
   verify anything against — also without generating a report.
4. Load context: `spec.md` (the criteria to verify), `tasks.md`/`plan.md` (to know what
   artifacts to expect from the feature's real state).

## Step 2 — extract the criteria from `spec.md`

Read `spec.md` in full and compile the list of verifiable criteria, **without omitting or merging
any of them**:

- Each **Acceptance Scenario** (`Acceptance Scenarios` sections of each User Story), with a reference
  matching the `data-model.md` format: "US-N / Acceptance Scenario M".
- Each **Success Criterion** (`SC-00N` in the Measurable Outcomes section), with reference `"SC-00N"`.

For each criterion, note: the reference, the criterion's text (to cite it in the report without
reinterpreting it), and what artifact or repo state could verify it. If a criterion doesn't map to
any observable state today, it isn't discarded: it moves on to Step 3, where it ends up as `not verifiable`
with the reason.

## Step 3 — verify each criterion against the real state

For each criterion in the list, in the order it appears in `spec.md`:

1. **Targeted check.** Choose the simplest check that can settle the
   criterion against the real state, in order of preference:
   - (a) a specific command — e.g. `test -f <path>` for criteria requiring that a file
     exist, or any short command whose result can be cited;
   - (b) file read — to verify content or structure, citing file and line(s);
   - (c) reuse evidence that already exists from the implementation (tests run in `/sdd-implement`,
     commands already executed) instead of re-running it — always citing what actually happened, never
     an assumed output.
2. **Classify** using the real evidence obtained in (1) — never the other way around:
   - the check confirms the criterion → `pass`, with the **concrete evidence** cited in the same
     row of the report (command + result, or file/line). **There is no `pass` without evidence
     cited** (FR-004): if no evidence could be obtained, that row is not `pass`.
   - the check contradicts the criterion → `fail`, with `detail` explaining what's missing (what was
     expected vs. what's there) so the implementation can be fixed and the skill re-run.
   - the criterion can't be objectively verified with what's available today (it points to something outside
     the repo or to behavior not observable with the citable means at hand) → `not verifiable`,
     with `detail` explaining why it couldn't be verified and what would be needed — a `pass` or
     `fail` is never forced without a basis (Edge Case in `spec.md`, FR-003).
3. **No fixing in this skill.** If a criterion fails, the `fail` is reported with its detail — the
   verification doesn't edit code or change the repo's state to "achieve" a `pass`. Fixing the
   implementation and re-running `sdd-verify` is on the implementation's side.

## Step 4 — write `verify-report.md` and close

Write `FEATURE_DIR/verify-report.md`, one row per criterion in `spec.md`, with the structure
from `data-model.md`:

```markdown
| criterio | veredicto | evidencia | detalle |
|---|---|---|---|
| US-2 / Acceptance Scenario 1 | pass | `test -f specs/002-sdd-gap-skills/spec.md` → exit 0 | — |
| SC-002 | no verificable | — | el criterio apunta a una métrica no medible en este repo; hace falta X |
```

Table rules: `evidencia` is **mandatory** in every `pass` row (never left blank);
`detalle` is **mandatory** in every `fail` or `no verificable` row; in `pass` rows, `detalle`
carries the `—` marker. Close with a short summary like "X pass / N fail / Z not verifiable",
so that `sdd-archive` can decide by reading the report.

Closing checklist, before considering the run finished:

- [ ] One row per each Acceptance Scenario and each Success Criterion in `spec.md` — no criterion
      left uncovered or merged with another.
- [ ] Each `pass` row cites its evidence in the same row (FR-004); if there's no evidence, that row is not
      `pass`.
- [ ] Each `fail`/`not verifiable` row states its `detail` with the reason (FR-003).
- [ ] The only file created is `FEATURE_DIR/verify-report.md` — no code was touched, nor
      `spec.md`/`tasks.md`/`plan.md`.
- [ ] If Step 1 reported "nothing to verify yet", there is no new `verify-report.md`: the
      state was communicated without fabricating verdicts.

## Notes

- It doesn't replace `speckit-converge` (adds missing tasks, doesn't verify) or `speckit-analyze`
  (consistency between artifacts): it's the "review/verify" step that Spec Kit doesn't cover.
- Its natural consumer is `sdd-archive`, which refuses to archive a feature with any criterion
  in `fail` or `not verifiable`, in the `propose → specify → implement → verify → archive` cycle.
- `verify-report.md` is a new file in the feature's folder; the format of `spec.md`/
  `plan.md`/`tasks.md` doesn't change, so `speckit-converge`/`speckit-analyze` keep working
  the same way after verification.
