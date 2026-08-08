# Tasks: Auditoría de consistencia de skills

**Input**: Design documents from `/specs/001-skill-audit/` (`plan.md`, `data-model.md`,
`quickstart.md`)

## Format: `[ID] [P?] [Story] Description`

- **[P]**: se puede ejecutar en paralelo (archivos distintos, sin dependencias pendientes)
- **[Story]**: a qué historia de usuario pertenece (US1, US2)

## Path Conventions

Proyecto de un solo script: `scripts/check-skills.sh` (repo root). No hay `src/`/`tests/`
separados — ver `plan.md`, sección Project Structure.

## Phase 1: Setup (Shared Infrastructure)

- [X] T001 Crear `scripts/check-skills.sh` con shebang `#!/usr/bin/env bash`, `set -euo pipefail`, y
  darle permiso de ejecución (`chmod +x`)

## Phase 2: Foundational (Blocking Prerequisites)

**Nota**: sin esto, ninguna de las dos historias es verificable de forma independiente — el
mecanismo de reporte y el parseo de frontmatter son compartidos.

- [X] T002 En `scripts/check-skills.sh`, implementar la iteración sobre `.claude/skills/*/SKILL.md`
  que arma la lista de skills a auditar; si una carpeta no tiene `SKILL.md`, agregar un `Check` con
  `check="skill-md-present"` y `result="fail"` para esa carpeta (Edge Case de `spec.md`) en vez de
  abortar la corrida
- [X] T003 En `scripts/check-skills.sh`, implementar una función para extraer un campo escalar del
  frontmatter YAML de un `SKILL.md` dado (usa `sed`/`awk`, sin parser YAML completo — ver
  Assumptions de `spec.md`); si el frontmatter no tiene delimitadores `---` válidos, agregar un
  `Check` con `check="frontmatter-valid"` y `result="fail"` para esa skill (Edge Case de `spec.md`)
- [X] T004 En `scripts/check-skills.sh`, implementar el acumulador de `Check` (skill | check |
  result | detail) y la función de impresión del resumen tabular final + cálculo de exit code
  (`FR-004`, `FR-005`: exit 1 si algún `Check` tiene `result="fail"`, exit 0 en cualquier otro caso)

**Checkpoint**: con Setup + Foundational, el script corre sin errores pero sin chequeos reales
todavía (tabla vacía, exit 0).

## Phase 3: User Story 1 - Detectar `name` desincronizado del directorio (Priority: P1) 🎯 MVP

**Goal**: detectar y reportar cuando el `name` del frontmatter de una skill no coincide con el
nombre de su carpeta.

**Independent Test**: ver `quickstart.md`, Escenario 2.

- [X] T005 [US1] En `scripts/check-skills.sh`, implementar el chequeo `name-matches-dir`: para cada
  skill de la iteración (T002), extraer `name` con la función de T003, compararlo contra el nombre
  de la carpeta, y agregar un `Check` (`pass` si coincide, `fail` con el valor encontrado/esperado
  en `detail` si no)
- [X] T006 [US1] En `scripts/check-skills.sh`, invocar el chequeo de T005 dentro del loop principal
  para cada skill de la iteración de T002, y confirmar manualmente (Escenario 1 de `quickstart.md`)
  que el resumen y el exit code reflejan el estado real del repo

**Checkpoint**: Historia 1 completa y verificable de forma independiente (MVP).

## Phase 4: User Story 2 - Detectar skills versionadas sin `CHANGELOG.md` (Priority: P2)

**Goal**: detectar y reportar cuando una skill con `metadata.version` no tiene `CHANGELOG.md` junto
a su `SKILL.md`.

**Independent Test**: ver `quickstart.md`, Escenario 3.

- [X] T007 [US2] En `scripts/check-skills.sh`, implementar el chequeo `has-changelog`: para cada
  skill, extraer `metadata.version` con la función de T003; si está ausente, no agregar ningún
  `Check` para esta skill (Acceptance Scenario 3 de Historia 2 — se omite, no se reporta pass/fail);
  si está presente, verificar `test -f` sobre `CHANGELOG.md` en la misma carpeta y agregar un
  `Check` (`pass`/`fail`)
- [X] T008 [US2] En `scripts/check-skills.sh`, invocar el chequeo de T007 dentro del mismo loop
  principal (junto al de T006) para cada skill, y confirmar manualmente (Escenario 1 de
  `quickstart.md`) que las skills `speckit-*` no aparecen en el resumen para este chequeo

**Checkpoint**: Historia 2 completa. Ambas historias verificables juntas o por separado.

## Phase N: Polish & Cross-Cutting Concerns

- [X] T009 Agregar un comentario de cabecera en `scripts/check-skills.sh` con uso (`Usage:
  ./scripts/check-skills.sh`) y qué hace en una línea
- [X] T010 Correr los 3 escenarios completos de `quickstart.md` contra el estado real del repo
  (incluyendo introducir y revertir las dos inconsistencias de prueba) y confirmar que SC-001,
  SC-002 y SC-003 de `spec.md` se cumplen

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (T001)**: sin dependencias, primero
- **Foundational (T002-T004)**: depende de T001, bloquea todo lo demás
- **User Story 1 (T005-T006)**: depende de Foundational
- **User Story 2 (T007-T008)**: depende de Foundational (no depende de User Story 1 — ambas
  historias son independientes entre sí, solo comparten los helpers de Foundational)
- **Polish (T009-T010)**: depende de que las historias que se vayan a incluir ya estén completas

### Within Each User Story

Secuencial: cada tarea de una historia edita el mismo archivo (`scripts/check-skills.sh`) que la
tarea anterior de esa misma historia.

### Parallel Opportunities

Ninguna real en esta feature: es un solo archivo (`scripts/check-skills.sh`), todas las tareas lo
editan — marcarlas `[P]` sería falso paralelismo de archivo. User Story 1 y User Story 2 sí son
independientes entre sí *conceptualmente* (no hay dependencia de datos entre una y otra), pero
igual compiten por el mismo archivo si se ejecutaran a la vez.

## Implementation Strategy

### MVP First (User Story 1 Only)

Completar Setup + Foundational + User Story 1 (T001-T006) da un script funcional que ya cumple el
chequeo más importante (`name-matches-dir`) con resumen y exit code correctos.

### Incremental Delivery

1. Setup + Foundational + US1 → validar con Escenario 1 y 2 de `quickstart.md` → MVP
2. Agregar US2 → validar con Escenario 3 de `quickstart.md`
3. Polish → validar los tres escenarios completos (T010)
