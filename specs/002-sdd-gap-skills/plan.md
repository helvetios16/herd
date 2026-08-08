# Implementation Plan: Skills que cierran los gaps de SDD de Spec Kit

**Branch**: `002-sdd-gap-skills` | **Date**: 2026-08-07 | **Spec**: [spec.md](./spec.md)

**Input**: Feature specification from `/specs/002-sdd-gap-skills/spec.md`

## Summary

Tres skills nuevas e independientes (`sdd-propose`, `sdd-verify`, `sdd-archive`) que cierran los dos
gaps de Spec Kit confirmados en la memoria/trial de la feature 001: falta de fase "proposal" antes
de especificar, y falta de "review/verify con evidencia" + "archive" después de implementar.

## Technical Context

**Language/Version**: Markdown (frontmatter YAML) — mismo formato que el resto de skills del repo

**Primary Dependencies**: Ninguna externa. `sdd-propose` reusa `create-new-feature.sh` de Spec Kit
(mismo mecanismo de numeración de `specs/`). `sdd-verify`/`sdd-archive` leen/escriben archivos del
propio repo, sin dependencias nuevas.

**Storage**: N/A (archivos del repo: `proposal.md`, `verify-report.md`, `state.yaml`)

**Testing**: Validación manual vía `quickstart.md` — mismo criterio que la feature 001, corriendo
las skills de verdad sobre un caso de prueba real.

**Target Platform**: Claude Code (skills invocables), mismo target que el resto del repo

**Project Type**: tres skills de Claude Code (documentos de instrucciones + su propio CHANGELOG),
no una app ni una librería

**Performance Goals**: N/A

**Constraints**: Cada skill debe poder implementarse, probarse y usarse de forma independiente de
las otras dos (Assumptions de `spec.md`) — el plan de tareas debe reflejar esa independencia, no
crear una dependencia artificial de orden entre ellas a nivel de implementación.

**Scale/Scope**: 3 skills nuevas, 2 archivos cada una (`SKILL.md` + `CHANGELOG.md`) = 6 archivos
nuevos, sin tocar código existente del repo.

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

Contra `.specify/memory/constitution.md` v1.0.0:

- **I. Prueba adversarial real**: `quickstart.md` (Fase 1) define un caso de prueba real —
  corriendo las tres skills en secuencia sobre una feature de prueba chica, exactamente como se
  hizo con la feature 001.
- **II. No generalizar sin necesidad concreta**: cada skill cubre exactamente el gap que motivó su
  creación (ver memoria de la prueba en vivo de Spec Kit) — no se agrega configuración genérica ni
  soporte para casos no pedidos (ej. `sdd-archive` no soporta políticas de retención configurables,
  solo mover a `specs/_archive/`).
- **III. Confirmación humana ante irreversibles**: `sdd-archive` mueve archivos (`git mv` o
  equivalente) — no es destructivo (no borra nada, todo queda versionado en `specs/_archive/`), pero
  igual se trata como acción que amerita confirmación explícita antes de ejecutar el movimiento,
  reportando primero qué se va a mover.
- **IV. Trazabilidad de versiones**: FR-007 lo exige explícitamente — las tres skills nacen con
  `metadata.version` + `CHANGELOG.md` propio desde la v0.1.
- **V. Iteración dirigida por el usuario**: retoma trabajo que el usuario había archivado
  explícitamente (no descartado) en una sesión anterior, y lo prioriza ahora como caso real para
  probar la rama delegada/multi-agente de `sdd-implement`.
- **VI. Concepto por encima de marca**: las tres skills son agnósticas de qué motor de SDD se use
  por debajo — dependen del formato de `spec.md`/`tasks.md` de Spec Kit, no de su implementación
  interna.

Sin violaciones. No hace falta `Complexity Tracking`.

## Project Structure

### Documentation (this feature)

```text
specs/002-sdd-gap-skills/
├── plan.md              # This file
├── data-model.md         # Fase 1 — entidades Proposal/VerifyReport/State
├── quickstart.md         # Fase 1 — guía de validación manual
└── tasks.md              # Fase 2 (/speckit-tasks) — no creado por este comando
```

Sin `research.md` (no hay `NEEDS CLARIFICATION` pendiente) ni `contracts/` (son skills de
instrucciones para un agente, no una interfaz externa contractuable).

### Source Code (repository root)

```text
.claude/skills/
├── sdd-propose/
│   ├── SKILL.md
│   └── CHANGELOG.md
├── sdd-verify/
│   ├── SKILL.md
│   └── CHANGELOG.md
└── sdd-archive/
    ├── SKILL.md
    └── CHANGELOG.md
```

**Structure Decision**: tres carpetas independientes bajo `.claude/skills/`, mismo patrón que
`agent-selection` y `sdd-implement` — cada una con su propio `SKILL.md` + `CHANGELOG.md`. Sin
carpeta compartida entre las tres (Assumptions de `spec.md`: independientes como piezas de
software).

## Complexity Tracking

*Sin violaciones que justificar — sección omitida.*
