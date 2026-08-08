# Feature Specification: Skills que cierran los gaps de SDD de Spec Kit

**Feature Branch**: `002-sdd-gap-skills`

**Created**: 2026-08-07

**Status**: Draft

**Input**: User description: "Completar el roadmap de SDD del repo agregando tres skills nuevas e
independientes bajo .claude/skills/, que cubren los dos gaps que Spec Kit no resuelve nativamente
(confirmado con una prueba en vivo de speckit-specify/speckit-converge/speckit-analyze): sdd-propose
(antes de /speckit-specify, problema/scope/riesgos/rollback), sdd-verify (después de
/speckit-implement o /sdd-implement, veredicto pass/fail con evidencia contra spec.md), sdd-archive
(solo si sdd-verify da veredicto limpio, genera state.yaml y mueve la feature a un histórico)."

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Encuadrar una feature antes de especificarla (Priority: P1)

Como mantenedor del repo, antes de correr `/speckit-specify` quiero dejar por escrito el problema
que resuelve una feature, qué entra y qué queda explícitamente afuera, qué archivos toca, sus
riesgos y cómo revertirla si hace falta — para no llegar a `spec.md` sin haber pensado el encuadre y
el riesgo primero.

**Why this priority**: es el primer gap identificado (Spec Kit va directo de una frase a `spec.md`,
sin ese encuadre previo) y el que más valor aporta solo — funciona incluso si las otras dos skills
de esta feature nunca se agregan.

**Independent Test**: correr la skill sobre una descripción de feature de prueba, confirmar que
genera `proposal.md` en un directorio numerado nuevo bajo `specs/`, y que una corrida posterior de
`/speckit-specify` reutiliza ese mismo directorio (no crea uno nuevo) y dentro queda `spec.md` junto
a `proposal.md`.

**Acceptance Scenarios**:

1. **Given** una descripción de feature en texto libre, **When** se corre la skill, **Then** se crea
   `specs/<NNN-nombre>/proposal.md` con secciones de problema, alcance (qué entra/qué se descarta),
   archivos afectados, riesgos y estrategia de rollback — sin placeholders sin resolver.
2. **Given** un `proposal.md` ya creado en `specs/<NNN-nombre>/`, **When** se corre
   `/speckit-specify` a continuación, **Then** `spec.md` se crea dentro de esa misma carpeta
   (`specs/<NNN-nombre>/spec.md`), no en un directorio numerado distinto.
3. **Given** una feature cuyo alcance incluye tocar algo de la lista de riesgo de `agent-selection`
   (ej. CI/CD, infraestructura, secretos), **When** se corre la skill, **Then** la sección de riesgos
   de `proposal.md` lo señala explícitamente, sin que la skill decida por su cuenta seguir adelante.

---

### User Story 2 - Verificar una implementación contra su spec con evidencia (Priority: P2)

Como mantenedor del repo, después de correr `/speckit-implement` o `/sdd-implement` quiero un
veredicto explícito, criterio por criterio, de si la implementación cumple lo que pedía `spec.md` —
respaldado con evidencia real (comandos corridos, archivos tocados), no con la palabra de que "ya
funciona".

**Why this priority**: depende de que exista una implementación real que verificar (viene después
de la Historia 1 en el ciclo, aunque las tres skills son independientes entre sí como piezas de
software). Es el gap más importante de cerrar porque hoy no existe ningún paso nativo de Spec Kit
que dé este veredicto (`speckit-converge` solo agrega tareas faltantes, no verifica).

**Independent Test**: correr la skill sobre una feature ya implementada con `tasks.md` completo,
confirmar que genera `verify-report.md` con una fila por acceptance scenario/criterio de éxito de
`spec.md`, cada una con veredicto pass/fail y la evidencia concreta que lo respalda.

**Acceptance Scenarios**:

1. **Given** una feature con `spec.md` y una implementación real en el código, **When** se corre la
   skill, **Then** genera `verify-report.md` con una fila por cada acceptance scenario y success
   criterion de `spec.md`, marcado `pass` o `fail`.
2. **Given** un criterio marcado `pass`, **When** se revisa `verify-report.md`, **Then** esa fila
   incluye la evidencia concreta usada (comando corrido y su resultado, o archivo/línea
   verificado) — nunca un pass sin evidencia citada.
3. **Given** un criterio que no se puede verificar objetivamente con la evidencia disponible,
   **When** se corre la skill, **Then** se marca explícitamente como no verificable (no se fuerza a
   pass ni a fail sin base).

---

### User Story 3 - Archivar una feature ya verificada (Priority: P3)

Como mantenedor del repo, quiero que una feature ya verificada limpia quede archivada — con un
resumen de estado final y fuera de la carpeta activa de `specs/` — para que `specs/` no crezca
indefinidamente mezclando trabajo activo con trabajo ya cerrado.

**Why this priority**: depende de que exista un `verify-report.md` limpio (viene después de la
Historia 2 en el ciclo), y es la de menor urgencia de las tres — sin ella, las features verificadas
simplemente se quedan en `specs/`, lo cual funciona pero no escala.

**Independent Test**: sobre una feature con `verify-report.md` con todos los criterios en `pass`,
correr la skill y confirmar que `specs/<NNN-nombre>/` deja de estar en `specs/` y aparece completa
bajo `specs/_archive/`, con un `state.yaml` nuevo resumiendo el cierre.

**Acceptance Scenarios**:

1. **Given** una feature con `verify-report.md` donde todos los criterios están en `pass`, **When**
   se corre la skill, **Then** genera `state.yaml` (estado final, fecha, resumen del veredicto de
   verify) dentro de la carpeta de la feature, y mueve toda la carpeta a `specs/_archive/`.
2. **Given** una feature con `verify-report.md` que tiene al menos un criterio en `fail` o no
   verificable, **When** se corre la skill, **Then** se rehúsa a archivar y explica cuáles criterios
   bloquean el archivado, sin mover ningún archivo.
3. **Given** una feature ya archivada, **When** se corre `/speckit-converge` o `/speckit-analyze`
   sobre esa feature, **Then** esos comandos siguen funcionando igual porque el formato de
   `spec.md`/`plan.md`/`tasks.md` no cambia con el archivado, solo la ubicación de la carpeta.

---

### Edge Cases

- ¿Qué pasa si `sdd-propose` se corre sobre una descripción de feature vacía o demasiado ambigua?
  Igual que `speckit-specify`, usa como máximo 3 marcadores `[NEEDS CLARIFICATION]` y pregunta antes
  de seguir, en vez de inventar un encuadre.
- ¿Qué pasa si `sdd-verify` se corre sobre una feature sin `tasks.md` o sin ninguna tarea marcada
  `[X]`? Se reporta como "nada que verificar todavía", sin generar un `verify-report.md` con
  veredictos fabricados.
- ¿Qué pasa si `sdd-archive` se corre sobre una feature que ya fue archivada antes? Detecta que la
  carpeta ya no está en `specs/` (o que `state.yaml` ya existe) y lo reporta sin repetir el archivado.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: `sdd-propose` MUST generar `proposal.md` con, como mínimo: problema, alcance (qué
  entra / qué se descarta explícitamente), archivos afectados, riesgos, y estrategia de rollback.
- **FR-002**: `sdd-propose` MUST crear el directorio numerado de la feature bajo `specs/` con el
  mismo mecanismo que usa `speckit-specify` (`create-new-feature.sh`), y MUST dejar ese directorio
  resuelto de forma que una corrida posterior de `/speckit-specify` con `SPECIFY_FEATURE_DIRECTORY`
  explícito reutilice esa misma carpeta.
- **FR-003**: `sdd-verify` MUST generar `verify-report.md` con un veredicto `pass`/`fail`/`no
  verificable` por cada acceptance scenario y success criterion de `spec.md`.
- **FR-004**: Todo veredicto `pass` en `verify-report.md` MUST estar acompañado de la evidencia
  concreta usada para llegar a ese veredicto.
- **FR-005**: `sdd-archive` MUST rehusarse a archivar una feature cuyo `verify-report.md` tenga
  algún criterio en `fail` o `no verificable`, explicando cuáles bloquean el archivado.
- **FR-006**: `sdd-archive` MUST generar `state.yaml` (estado final, fecha, resumen del veredicto)
  y mover la carpeta completa de la feature a `specs/_archive/` cuando el archivado procede.
- **FR-007**: Las tres skills MUST declarar `metadata.version` en su frontmatter y tener un
  `CHANGELOG.md` propio junto a su `SKILL.md` (Principio IV de la constitución del repo).

### Key Entities

- **Proposal**: problema, alcance, archivos afectados, riesgos, estrategia de rollback — vive en
  `proposal.md`, en la misma carpeta que `spec.md` de la misma feature.
- **Verify Report**: una fila por criterio de `spec.md` (acceptance scenario o success criterion),
  con veredicto y evidencia — vive en `verify-report.md`.
- **State**: estado final de una feature archivada (fecha, resumen de verify) — vive en
  `state.yaml`, dentro de la carpeta movida a `specs/_archive/`.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: Correr `sdd-propose` → `/speckit-specify` en secuencia sobre una feature de prueba
  deja `proposal.md` y `spec.md` en la misma carpeta, sin intervención manual para alinear
  directorios.
- **SC-002**: Sobre una feature con implementación real, `sdd-verify` produce un veredicto por cada
  criterio de `spec.md` sin dejar ninguno sin cubrir, y cada `pass` es trazable a evidencia concreta
  citada en el reporte.
- **SC-003**: Introducir un criterio deliberadamente incumplido antes de correr `sdd-verify` hace
  que ese criterio aparezca en `fail` y que `sdd-archive` se rehúse a archivar la feature.
- **SC-004**: Corregir ese incumplimiento y volver a correr `sdd-verify` seguido de `sdd-archive`
  archiva la feature correctamente, con `state.yaml` reflejando el veredicto limpio.

## Assumptions

- Las tres skills son independientes entre sí como piezas de software (cada una se puede
  implementar, probar y usar sin las otras dos) aunque su uso típico en el ciclo completo sea
  secuencial: `sdd-propose` → `/speckit-specify` → ... → `/sdd-implement` → `sdd-verify` →
  `sdd-archive`.
- `sdd-verify` no ejecuta una suite de tests automatizada propia — reusa la evidencia que ya exista
  (tests corridos, comandos ejecutados durante `/sdd-implement`) o corre verificaciones puntuales
  ella misma cuando el criterio lo permite (ej. un `test -f` sobre un archivo esperado), consistente
  con que este repo no tiene un framework de test unificado para todas sus skills.
- `specs/_archive/` no existe todavía en el repo — `sdd-archive` lo crea la primera vez que archiva
  algo.
- Ninguna de las tres toca la lista de riesgo de `agent-selection` directamente (no son
  CI/CD/infra/secretos) — son archivos Markdown/YAML de skills y specs.
