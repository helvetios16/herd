# Tasks: Skills que cierran los gaps de SDD de Spec Kit

**Input**: Design documents from `/specs/002-sdd-gap-skills/` (`plan.md`, `data-model.md`,
`quickstart.md`)

## Format: `[ID] [P?] [Story] Description`

- **[P]**: se puede ejecutar en paralelo (archivos distintos, sin dependencias pendientes)
- **[Story]**: a qué historia de usuario pertenece (US1, US2, US3)

## Path Conventions

Tres skills nuevas bajo `.claude/skills/`, cada una en su propia carpeta con `SKILL.md` +
`CHANGELOG.md` — ver `plan.md`, sección Project Structure. Sin código de aplicación, sin
`src/`/`tests/`.

## Phase 1: Setup (Shared Infrastructure)

- [X] T001 Crear las carpetas `.claude/skills/sdd-propose/`, `.claude/skills/sdd-verify/`,
  `.claude/skills/sdd-archive/`

**Nota**: sin fase Foundational — a diferencia de la feature 001, acá no hay ningún helper
compartido entre las tres historias (Assumptions de `spec.md`: son independientes entre sí como
piezas de software, cada una es autocontenida en su propio `SKILL.md`).

## Phase 2: User Story 1 - Encuadrar una feature antes de especificarla (Priority: P1) 🎯 MVP

**Goal**: `sdd-propose` genera `proposal.md` (problema, alcance, archivos afectados, riesgos,
rollback) y deja el directorio de la feature listo para que `/speckit-specify` lo reutilice vía
`SPECIFY_FEATURE_DIRECTORY`.

**Independent Test**: ver `quickstart.md`, Escenario 1.

- [X] T002 [P] [US1] Crear `.claude/skills/sdd-propose/SKILL.md`: skill que recibe una descripción
  de feature en lenguaje natural, reusa el mecanismo de `create-new-feature.sh` para crear el
  directorio numerado bajo `specs/` (FR-002), escribe `proposal.md` con las 5 secciones de
  `data-model.md` (FR-001), y persiste `SPECIFY_FEATURE_DIRECTORY` de forma que una corrida
  posterior de `/speckit-specify` reutilice esa misma carpeta en vez de crear una nueva
- [X] T003 [US1] Crear `.claude/skills/sdd-propose/CHANGELOG.md` con la entrada v0.1 describiendo
  qué resuelve la skill (Principio IV de la constitución)

**Checkpoint**: Historia 1 completa y verificable de forma independiente (MVP) — funciona sin que
existan `sdd-verify` ni `sdd-archive`.

## Phase 3: User Story 2 - Verificar una implementación contra su spec con evidencia (Priority: P2)

**Goal**: `sdd-verify` genera `verify-report.md` con un veredicto pass/fail/no-verificable por cada
acceptance scenario y success criterion de `spec.md`, con evidencia obligatoria en cada `pass`.

**Independent Test**: ver `quickstart.md`, Escenario 2 y 3.

- [X] T004 [P] [US2] Crear `.claude/skills/sdd-verify/SKILL.md`: skill que lee `spec.md` de una
  feature, extrae cada acceptance scenario y success criterion, y para cada uno intenta verificarlo
  contra el estado real del código/repo (comando puntual, `test -f`, lectura de archivo) — nunca
  marca `pass` sin citar la evidencia usada (FR-003, FR-004); si no hay `tasks.md` con al menos una
  tarea `[X]`, reporta "nada que verificar todavía" en vez de generar veredictos fabricados (Edge
  Case de `spec.md`)
- [X] T005 [US2] Crear `.claude/skills/sdd-verify/CHANGELOG.md` con la entrada v0.1

**Checkpoint**: Historia 2 completa y verificable de forma independiente — funciona sin
`sdd-propose` ni `sdd-archive`, sobre cualquier feature que ya tenga `spec.md` + implementación.

## Phase 4: User Story 3 - Archivar una feature ya verificada (Priority: P3)

**Goal**: `sdd-archive` mueve una feature con `verify-report.md` limpio a `specs/_archive/` con un
`state.yaml` de resumen, y se rehúsa a archivar si hay algún criterio en `fail`/`no verificable`.

**Independent Test**: ver `quickstart.md`, Escenario 3 y 4.

- [X] T006 [P] [US3] Crear `.claude/skills/sdd-archive/SKILL.md`: skill que lee `verify-report.md`
  de una feature; si algún criterio está en `fail` o `no verificable`, se rehúsa y lista cuáles
  bloquean (FR-005); si todos están en `pass`, pide confirmación explícita antes de mover (Principio
  III de la constitución), genera `state.yaml` (FR-006, campos de `data-model.md`) y mueve la
  carpeta completa a `specs/_archive/`; si la carpeta ya no está en `specs/` o ya existe
  `state.yaml`, lo reporta sin repetir el archivado (Edge Case de `spec.md`)
- [X] T007 [US3] Crear `.claude/skills/sdd-archive/CHANGELOG.md` con la entrada v0.1

**Checkpoint**: Historia 3 completa y verificable de forma independiente — funciona sin
`sdd-propose` ni `sdd-verify`, sobre cualquier feature que ya tenga un `verify-report.md`.

## Phase N: Polish & Cross-Cutting Concerns

- [X] T008 Actualizar `README.md` con las tres skills nuevas en la lista de skills del repo
- [X] T009 Correr los 4 escenarios de `quickstart.md` sobre una feature de prueba real y
  descartable (`sdd-propose` → `/speckit-specify` → implementación trivial → `sdd-verify` →
  incumplimiento a propósito → `sdd-archive` rehusado → corregido → `sdd-archive` archiva limpio) y
  confirmar SC-001 a SC-004 de `spec.md`

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (T001)**: sin dependencias, primero
- **User Story 1 (T002-T003)**: depende solo de T001
- **User Story 2 (T004-T005)**: depende solo de T001 — **no depende de User Story 1**
- **User Story 3 (T006-T007)**: depende solo de T001 — **no depende de User Story 1 ni 2**
- **Polish (T008-T009)**: depende de que las tres historias estén completas (T009 ejercita el ciclo
  completo, necesita las tres)

### User Story Dependencies

**Ninguna.** A diferencia de un ciclo SDD típico donde `propose` → `verify` → `archive` son pasos
secuenciales de *uso*, acá son tres piezas de software independientes — cada `SKILL.md` es
autocontenido y no importa nada de las otras dos carpetas. El orden secuencial solo aplica cuando
alguien *usa* las tres skills juntas en un ciclo real (eso es T009, Polish), no a su implementación.

### Within Each User Story

Secuencial: el `CHANGELOG.md` de cada historia depende de que su `SKILL.md` ya esté escrito (para
resumir qué hace en la entrada v0.1).

### Parallel Opportunities

**Real, no forzado**: T002 (`sdd-propose/SKILL.md`), T004 (`sdd-verify/SKILL.md`) y T006
(`sdd-archive/SKILL.md`) tocan tres archivos completamente distintos, en tres carpetas distintas,
sin que ninguno dependa de que otro termine — a diferencia de la feature 001 (un solo script), acá
las tres historias son genuinamente independientes entre sí (ver User Story Dependencies arriba).
Candidato directo a la Pregunta 1 del Paso 2 de `agent-selection` ("¿fases genuinamente
independientes que requieren más de una delegación coordinada por un líder?").

## Implementation Strategy

### MVP First (User Story 1 Only)

Completar Setup + User Story 1 (T001-T003) da `sdd-propose` funcional y usable de inmediato, aunque
`sdd-verify`/`sdd-archive` no existan todavía.

### Incremental Delivery

1. Setup + US1 → validar con Escenario 1 de `quickstart.md` → MVP
2. Agregar US2 → validar con Escenario 2 y 3
3. Agregar US3 → validar con Escenario 3 y 4
4. Polish → ciclo completo (T009)
