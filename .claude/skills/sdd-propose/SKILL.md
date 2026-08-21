---
name: "sdd-propose"
description: "Frames a Spec Kit feature before specifying it, capturing problem, scope, affected files, risks, and rollback in a traceable proposal."
argument-hint: "Describe the feature you want to frame"
compatibility: "Requires a Spec Kit project structure with .specify/ and the script .specify/scripts/bash/create-new-feature.sh"
metadata:
  status: experimental
  version: "0.1"
user-invocable: true
disable-model-invocation: false
---

## What this skill does

First step of the SDD cycle for this repo. It takes a natural-language feature description,
reuses the Spec Kit mechanism to create a numbered directory under `specs/`, and writes there a
`proposal.md` with the minimal framing before moving on to `/speckit-specify`: problem, scope
included, scope excluded, affected files, risks, and rollback.

Numbering and initial directory creation are not reimplemented here: they are always resolved by
`.specify/scripts/bash/create-new-feature.sh`, which also persists `.specify/feature.json`. The
resulting folder is explicitly handed off as `SPECIFY_FEATURE_DIRECTORY` so that the next
run of `/speckit-specify` writes `spec.md` alongside `proposal.md`.

## User Input

```text
$ARGUMENTS
```

The description the user wrote after `/sdd-propose` is the feature input. If it is
empty, report `No feature description provided` and do not create any directory or file.

## Step 1 — validate the input and load the criteria

1. Consider the full description in `$ARGUMENTS` before proposing anything. Extract actors,
   problem, desired action, data, and constraints that are present.
2. Read `.specify/memory/constitution.md` and apply its six principles, especially not
   generalizing without a concrete need, maintaining version traceability, and separating the
   transferable concept from the specific brand or tool.
3. If a decision that materially changes the scope is missing and there is no reasonable
   assumption, mark it with `[NEEDS CLARIFICATION: concrete question]`. Use at most 3 markers total,
   prioritized by scope, security/privacy, and user experience. Do not invent data to
   avoid a clarification. Present the questions and wait for an answer before closing the proposal.
4. Do not use generic placeholders like `[FEATURE NAME]`, `[DATE]`, `TBD`, or `N/A`. A
   `NEEDS CLARIFICATION` marker is the only exception allowed when the ambiguity is material; once
   the answer is received, replace it with a concrete decision.

## Step 2 — create the feature directory with the existing mechanism

1. With the description available, derive a short name of 2 to 4 words, in action or
   concept form, to pass to `create-new-feature.sh` only if it's necessary to set the name. Do not
   invent a numeric prefix or scan `specs/` to number it.
2. Run `.specify/scripts/bash/create-new-feature.sh` with the feature description and
   `--json`. Reuse the script as-is; do not copy or reimplement its numbering algorithm,
   template resolution, `spec.md` creation, or `.specify/feature.json` persistence.
3. Take the `SPEC_FILE` and `FEATURE_NUM` returned by the script as evidence. The feature
   directory is the directory containing that `SPEC_FILE`; keep the exact path, including
   `specs/` and the numeric prefix. If the script fails, report the error and do not write a
   proposal in another folder.
4. Use the directory resolved by the script as `SPECIFY_FEATURE_DIRECTORY` for everything that
   follows. Do not create a second folder, even if the branch name and the directory name
   differ.

## Step 3 — draft `proposal.md`

Write `SPECIFY_FEATURE_DIRECTORY/proposal.md` with these six exact sections, in this order.
The headings must keep these data-model field names:

1. `## problema` — what concrete situation motivates the feature, who suffers from it, and what value is sought.
2. `## alcance_incluye` — a concrete list of what's in for this feature.
3. `## alcance_excluye` — a concrete list of what's out, including boundaries that prevent
   generalizing beyond the real case.
4. `## archivos_afectados` — paths or file patterns that will likely be created, read, or
   modified. If an exact path can't yet be determined, describe the pattern and the reason,
   without turning it into a generic list of possible files.
5. `## riesgos` — feature-specific risks, known mitigations, and the review status of the
   `agent-selection` risk list.
6. `## rollback` — concrete steps to revert the feature and restore the prior state; if the
   reversal requires a decision or an irreversible action, flag it.

Write content derived from `$ARGUMENTS`, repo context, and reasonable assumptions. Document
assumptions within the relevant section or at the end of `## problema` as `Supuestos`; do not
add a seventh section to the model or leave unresolved template text. The proposal should
be readable for whoever will decide the scope and must not become a detailed
implementation plan.

## Step 4 — explicitly review risk before closing

In `## riesgos`, review the identified files and boundaries against the risk list from Step 2
of `.claude/skills/agent-selection/SKILL.md`: `.env*` and other environment files, SSH or
credentials, CI/CD configuration, infrastructure, database migrations, production/deploy
configuration, and auth, payments, or bulk data deletion.

Leave an explicit conclusion, even when there are no matches:

- `Lista de riesgo de agent-selection: no detectada`, briefly explaining what was reviewed; or
- `Lista de riesgo de agent-selection: detectada`, indicating the specific pattern or file and why
  it applies.

If a risk is detected, do not decide on your own that the feature can move forward. Mark
`CONFIRMACIÓN HUMANA REQUERIDA` in the risks section and in the Completion Report, and stop
any further specification or implementation step until the user explicitly confirms
how to proceed. Detection does not authorize migrations, deploys, exposure of secrets,
auth/payments changes, or deletions.

## Step 5 — Completion Report

Finish with a report to the user that includes:

- `SPECIFY_FEATURE_DIRECTORY`: the exact resolved path value, for example
  `specs/003-user-auth`.
- `SPEC_FILE`: the exact path returned by `create-new-feature.sh`.
- `proposal.md`: confirmation that it was written inside `SPECIFY_FEATURE_DIRECTORY` and that it
  contains the six required sections.
- `Riesgo`: explicit result of the `agent-selection` review; if applicable, the pending human
  confirmation gate.
- `Siguiente paso`: the `/speckit-specify` invocation using exactly that value, for example
  `SPECIFY_FEATURE_DIRECTORY=specs/003-user-auth /speckit-specify <feature description>`.

Do not claim that `spec.md` was created by this skill: it is created by `/speckit-specify`. Remember that the
script already persisted the path in `.specify/feature.json`, but still hand off the
explicit `SPECIFY_FEATURE_DIRECTORY` value for the next command.

## Done When

- [ ] Empty input was rejected without creating any files.
- [ ] `create-new-feature.sh` was run to resolve the numbered directory and its numbering was
      not reimplemented.
- [ ] `proposal.md` exists in the folder returned by the script.
- [ ] `proposal.md` has `problema`, `alcance_incluye`, `alcance_excluye`, `archivos_afectados`,
      `riesgos`, and `rollback`, with no unresolved generic placeholders.
- [ ] The `agent-selection` risk review was made explicit and any match was
      blocked pending human confirmation.
- [ ] The Completion Report leaves the exact `SPECIFY_FEATURE_DIRECTORY` value for
      `/speckit-specify`.
