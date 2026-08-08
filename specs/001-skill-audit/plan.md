# Implementation Plan: Auditoría de consistencia de skills

**Branch**: `001-skill-audit` | **Date**: 2026-08-07 | **Spec**: [spec.md](./spec.md)

**Input**: Feature specification from `/specs/001-skill-audit/spec.md`

## Summary

Script `scripts/check-skills.sh` que recorre `.claude/skills/*/SKILL.md`, verifica que `name` del
frontmatter coincida con la carpeta y que toda skill con `metadata.version` tenga `CHANGELOG.md`
junto a su `SKILL.md`, e imprime un resumen tabular con exit code 0/1.

## Technical Context

**Language/Version**: Bash (mismo runtime que `.specify/scripts/bash/*.sh`, ya usados en este repo)

**Primary Dependencies**: Ninguna externa — `grep`/`sed`/`awk` estándar de macOS/Linux, ya asumido
por el resto de los scripts del repo. Sin parser YAML dedicado (ver Assumptions de `spec.md`).

**Storage**: N/A (lee archivos del propio repo, no persiste estado)

**Testing**: Validación manual vía `quickstart.md` (correr el script contra el estado real del repo
y contra una inconsistencia introducida a propósito) — no hay framework de test instalado en este
repo para bash.

**Target Platform**: macOS/Linux, línea de comandos (mismo target que el resto de `scripts/` y
`.specify/scripts/bash/`)

**Project Type**: CLI script de mantenimiento del propio repo (no una app/librería)

**Performance Goals**: N/A — corre sobre ~12 skills instaladas hoy, no hay requisito de escala

**Constraints**: Ninguna más allá de lo ya declarado en Assumptions de `spec.md`

**Scale/Scope**: Un solo script, ~12 skills a auditar hoy (crece con las que se agreguen)

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

Contra `.specify/memory/constitution.md` v1.0.0:

- **I. Prueba adversarial real**: cubierto por `quickstart.md` (Fase 1) — valida corriendo el
  script de verdad contra una inconsistencia introducida a propósito, no en teoría.
- **II. No generalizar sin necesidad concreta**: el script cubre exactamente los dos chequeos
  pedidos, sin parser YAML genérico ni framework de reglas configurable — texto plano con
  `grep`/`sed`/`awk`, alineado con el resto de `scripts/bash/` del repo.
- **III. Confirmación humana ante irreversibles**: N/A — el script es de solo lectura (audita, no
  modifica archivos), no aplica.
- **IV. Trazabilidad de versiones**: N/A para este script en sí (es una utilidad de repo, no una
  skill versionada con `metadata.version`) — pero es precisamente la herramienta que hace cumplir
  este principio para las demás skills.
- **V. Iteración dirigida por el usuario**: este plan es el resultado de un caso real elegido
  explícitamente por el usuario para probar `sdd-implement` en vivo.
- **VI. Concepto por encima de marca**: N/A, no depende de ninguna herramienta de terceros.

Sin violaciones. No hace falta `Complexity Tracking`.

## Project Structure

### Documentation (this feature)

```text
specs/001-skill-audit/
├── plan.md              # This file
├── data-model.md         # Fase 1 — entidades Skill/Check (livianas)
├── quickstart.md         # Fase 1 — guía de validación manual
└── tasks.md              # Fase 2 (/speckit-tasks) — no creado por este comando
```

No se genera `research.md` (no hay `NEEDS CLARIFICATION` pendiente — Technical Context quedó
resuelto con los defaults ya vigentes en el repo) ni `contracts/` (script interno de mantenimiento,
sin interfaz externa que contractuar — el propio template de plan indica omitirlo en este caso).

### Source Code (repository root)

```text
scripts/
└── check-skills.sh      # único archivo nuevo
```

**Structure Decision**: un solo script en `scripts/` (directorio ya usado para utilidades de este
tipo, distinto de `.specify/scripts/bash/` que es infraestructura propia de Spec Kit). Sin
estructura de `src/`/`tests/` — no aplica a un script de mantenimiento de una sola pieza.

## Complexity Tracking

*Sin violaciones que justificar — sección omitida.*
