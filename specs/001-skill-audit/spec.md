# Feature Specification: Auditoría de consistencia de skills

**Feature Branch**: `001-skill-audit`

**Created**: 2026-08-07

**Status**: Draft

**Input**: User description: "Quiero un script en scripts/check-skills.sh que audite las skills
instaladas en .claude/skills/. Dos chequeos: (1) que el campo `name` del frontmatter de cada
SKILL.md coincida con el nombre de su carpeta; (2) que toda skill cuyo frontmatter tenga
metadata.version tenga también un CHANGELOG.md en la misma carpeta. Al final imprime un resumen
tabular (skill | chequeo | resultado) y termina con exit code 1 si algo falló, 0 si todo pasó."

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Detectar `name` desincronizado del directorio (Priority: P1)

Como mantenedor del repo, quiero correr una auditoría que me diga si el campo `name` del
frontmatter de una skill no coincide con el nombre de su carpeta, para detectar copy-paste errors
o carpetas renombradas sin actualizar el frontmatter.

**Why this priority**: es el chequeo más barato de romper (renombrar una carpeta sin tocar el
frontmatter) y el que más confunde río abajo (invocación por nombre que no matchea la carpeta).

**Independent Test**: renombrar temporalmente el `name` del frontmatter de una skill existente a un
valor distinto de su carpeta, correr el script, confirmar que reporta esa skill como fallida en
este chequeo específico — y que las demás skills siguen reportando bien.

**Acceptance Scenarios**:

1. **Given** una skill cuyo frontmatter tiene `name: "agent-selection"` en la carpeta
   `.claude/skills/agent-selection/`, **When** se corre la auditoría, **Then** ese chequeo para esa
   skill se reporta como pasado.
2. **Given** una skill cuyo frontmatter tiene un `name` distinto al de su carpeta, **When** se corre
   la auditoría, **Then** ese chequeo para esa skill se reporta como fallido, mostrando el valor
   encontrado y el esperado.

---

### User Story 2 - Detectar skills versionadas sin `CHANGELOG.md` (Priority: P2)

Como mantenedor del repo, quiero que la auditoría detecte cualquier skill que declara
`metadata.version` en su frontmatter pero no tiene un `CHANGELOG.md` junto a su `SKILL.md`, para
que ninguna skill versionada quede sin su historial de cambios (Principio IV de la constitución del
repo: trazabilidad de versiones).

**Why this priority**: depende de que el parseo de frontmatter de la Historia 1 ya funcione, y es
el chequeo que hace cumplir de forma automática una convención que hasta ahora era solo manual.

**Independent Test**: crear temporalmente una skill de prueba con `metadata.version` en su
frontmatter y sin `CHANGELOG.md`, correr el script, confirmar que la reporta como fallida en este
chequeo — y que una skill con `CHANGELOG.md` presente pasa.

**Acceptance Scenarios**:

1. **Given** una skill con `metadata.version` en su frontmatter y un `CHANGELOG.md` en la misma
   carpeta, **When** se corre la auditoría, **Then** ese chequeo para esa skill se reporta como
   pasado.
2. **Given** una skill con `metadata.version` en su frontmatter y sin `CHANGELOG.md` en la misma
   carpeta, **When** se corre la auditoría, **Then** ese chequeo se reporta como fallido.
3. **Given** una skill sin `metadata.version` en su frontmatter (ej. las `speckit-*` vendorizadas,
   que no siguen esta convención), **When** se corre la auditoría, **Then** el chequeo de
   `CHANGELOG.md` se omite para esa skill, no se reporta ni como pasado ni como fallido.

---

### Edge Cases

- ¿Qué pasa si una carpeta dentro de `.claude/skills/` no tiene `SKILL.md`? Se reporta como fallida
  en un chequeo aparte ("SKILL.md ausente"), no rompe la corrida del resto.
- ¿Qué pasa si el frontmatter no es YAML válido o no tiene delimitadores `---`? Se reporta como
  fallida ("frontmatter inválido"), no rompe la corrida del resto.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: El script MUST recorrer todas las subcarpetas de `.claude/skills/` que contengan un
  `SKILL.md`.
- **FR-002**: El script MUST extraer el campo `name` del frontmatter YAML de cada `SKILL.md` y
  compararlo contra el nombre de la carpeta que lo contiene.
- **FR-003**: El script MUST extraer `metadata.version` del frontmatter (si existe) y, cuando
  exista, verificar que haya un archivo `CHANGELOG.md` en la misma carpeta.
- **FR-004**: El script MUST imprimir un resumen tabular con columnas `skill | chequeo | resultado`
  cubriendo cada chequeo aplicado a cada skill.
- **FR-005**: El script MUST terminar con exit code `1` si algún chequeo aplicado falló, y `0` si
  todos los chequeos aplicados pasaron.
- **FR-006**: El script MUST manejar sin abortar la corrida: carpetas sin `SKILL.md`, y frontmatter
  YAML inválido o ausente — reportándolos como fallo de ese chequeo puntual, no como error fatal del
  script.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: Correr el script sobre el estado actual de `.claude/skills/` produce un resumen con
  una fila por chequeo aplicable por skill, sin errores no controlados (crash, traceback).
- **SC-002**: Introducir una inconsistencia real (desincronizar un `name`, o quitar un
  `CHANGELOG.md` de una skill versionada) hace que el exit code pase de `0` a `1` y que la fila
  correspondiente en el resumen cambie de pasado a fallido.
- **SC-003**: Revertir esa inconsistencia hace que el exit code y el resumen vuelvan a su estado
  anterior, sin falsos positivos en otras skills no tocadas.

## Assumptions

- El frontmatter de cada `SKILL.md` es YAML válido delimitado por `---` al inicio del archivo
  (formato ya usado por todas las skills existentes del repo).
- El script corre en bash desde la raíz del repo (mismo criterio que los scripts ya instalados en
  `.specify/scripts/bash/`).
- No hace falta un parser YAML completo — alcanza con extraer los campos puntuales (`name`,
  `metadata.version`) con herramientas de texto estándar (`grep`/`sed`/`awk`), consistente con que
  el resto del repo no depende de un parser YAML dedicado.
- Las skills `speckit-*` (vendorizadas por Spec Kit) no siguen la convención `metadata.version` +
  `CHANGELOG.md` de este repo — no se las penaliza por no tenerlo (ver Edge Case / Acceptance
  Scenario 3 de la Historia 2).
