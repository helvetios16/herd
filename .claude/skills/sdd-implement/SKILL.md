---
name: "sdd-implement"
description: "Ejecuta tasks.md de una feature de Spec Kit delegando cada fase al framework de decisión de agent-selection (agente único, delegado, o patrón multi-agente vía Herdr), en vez de ejecutar todo inline como /speckit-implement."
argument-hint: "Guía opcional de implementación o filtro de tareas (mismo formato que /speckit-implement)"
compatibility: "Requiere estructura de proyecto Spec Kit (.specify/) con tasks.md generado, y la skill agent-selection en este mismo repo"
metadata:
  status: experimental
  version: "0.4"
user-invocable: true
disable-model-invocation: false
---

## Qué hace esta skill

Reemplazo de `/speckit-implement` para este repo. Spec Kit deja las bases (`spec.md` → `plan.md` →
`tasks.md`) con `/speckit-constitution` → `/speckit-specify` → `/speckit-plan` → `/speckit-tasks`;
esta skill toma esas bases y las ejecuta, pero en vez de correr todo inline en la sesión actual
(como hace `speckit-implement` nativo), evalúa **cada fase de `tasks.md`** con el framework de
decisión de [[agent-selection]] (`.claude/skills/agent-selection/SKILL.md`) para decidir si esa fase
se resuelve en la sesión actual, delegada a un subagente, o con un patrón multi-agente vía Herdr.

`speckit-implement` sigue instalado sin tocar — es el fallback nativo si alguna vez se quiere
ejecutar una feature sin pasar por agent-selection.

## User Input

```text
$ARGUMENTS
```

Si no está vacío, tratarlo igual que lo trataría `speckit-implement`: guía de implementación o
filtro de qué tareas/fases correr.

## Paso 1 — prerrequisitos y contexto (igual que `speckit-implement`, no reinventar)

Reusar tal cual, sin reescribir, los pasos 1-4 de `.claude/skills/speckit-implement/SKILL.md`:

1. Correr `.specify/scripts/bash/check-prerequisites.sh --json --require-tasks --include-tasks` y
   resolver `FEATURE_DIR`/`AVAILABLE_DOCS`.
2. Chequeo de estado de checklists (`FEATURE_DIR/checklists/`) — si hay ítems incompletos, **parar y
   preguntar** antes de seguir, igual que el nativo.
3. Cargar contexto: `tasks.md` (requerido), `plan.md` (requerido), `spec.md`,
   `.specify/memory/constitution.md`, y `data-model.md`/`contracts/`/`research.md` si existen.
4. Verificación de setup del proyecto (ignore files según stack detectado en `plan.md`) — **con
   criterio, no ciego**: si el stack real de la feature (según `plan.md`) no genera ningún artefacto
   que necesite ignorarse, omitir este paso explícitamente y decirlo en el reporte de la fase de
   Setup, en vez de crear un `.gitignore` genérico con patrones de stacks que este repo no usa —
   Principio II de la constitución (no generalizar sin necesidad concreta). Confirmado en vivo: un
   script bash de mantenimiento (sin build ni dependencias) no ameritó `.gitignore` — ver
   `CHANGELOG.md` v0.2.

Se referencia esta sección en vez de copiarla para que un cambio futuro en `speckit-implement`
(por una actualización de `specify`) no deje a esta skill con una copia desactualizada — Principio
VI de la constitución (concepto por encima de marca/versión puntual de la herramienta). Esto
también aplica al resto del Paso 1: reusar por referencia no significa aplicar ciego — cualquier
paso de `speckit-implement` que no aplique al caso real de la feature se omite explícitamente, con
la razón, no se ejecuta solo porque el nativo lo hace incondicionalmente.

## Paso 2 — parsear `tasks.md` en fases (igual que `speckit-implement`)

Extraer, en el orden en que aparecen en `tasks.md`: **Setup → Foundational → una fase por User
Story (P1, P2, P3...) → Polish**. Por cada fase, listar sus tareas `[ID] [P?] [Story] Descripción`
y marcar cuáles están etiquetadas `[P]` (paralelizables entre sí, tocan archivos distintos).

## Paso 3 — el puente: cada fase es "la tarea" para agent-selection

Para cada fase, en el orden que le corresponde (nunca saltar una fase antes de que termine la
anterior, salvo que agent-selection decida ejecutar dos fases independientes en paralelo — ver
abajo):

1. **Leer y aplicar en vivo** `.claude/skills/agent-selection/SKILL.md`, Paso 0 a Paso 6 completos,
   tratando **el conjunto de tareas de esta fase** como "la tarea" que ese framework evalúa. No
   resumir ni reinterpretar el framework — seguirlo tal cual está escrito ahí, incluyendo el
   chequeo obligatorio de Herdr (Paso 0, una vez por corrida de `sdd-implement`, no por fase, salvo
   que el Paso 6 de agent-selection detecte que Herdr cayó a mitad de camino).
2. **Señales específicas de `tasks.md` para el Paso 1/2 de agent-selection**:
   - El conteo de archivos de la fase = archivos distintos que tocan sus tareas (sumar, no contar
     por tarea individual).
   - La *lista de riesgo* del Paso 2 de agent-selection aplica igual acá: si alguna tarea de la fase
     toca esos patrones (`.env*`, CI/CD, infra, migraciones, auth/pagos), esa fase nunca es Direct
     inline sin importar cuántos archivos tenga.
   - Las tareas marcadas `[P]` dentro de la fase son la señal natural para la **pregunta 4 del Paso
     2 de agent-selection** ("¿parte del trabajo es mecánica/repetitiva y separable?") — si hay 2+
     tareas `[P]` no triviales, es una razón concreta para escalar a un patrón multi-agente (model
     tiering: orquestador reparte, minions ejecutan cada tarea `[P]` en paralelo) en vez de
     ejecutarlas una por una inline.
   - Si la fase es la de **Tests** de una user story (bajo TDD, ver `tasks.md`), esas tareas van
     antes que las de implementación de la misma fase — el orden interno de la fase no lo decide
     agent-selection, lo sigue dictando `tasks.md`.
3. **Reportar con el formato del Paso 5 de agent-selection**, una vez por fase, antes de ejecutarla:
   ruta elegida y por qué, patrón si aplica, CLI/modelo por rol si hay CLI externo involucrado.
4. **Gate de confirmación humana** (Principio III de la constitución): si el Paso 1/2 de
   agent-selection determina que la fase toca la lista de riesgo o es una decisión irreversible,
   parar y pedir confirmación explícita del usuario antes de ejecutar esa fase — no asumir que
   haber arrancado `sdd-implement` ya es luz verde para todo lo que venga.
5. Ejecutar la fase según la ruta decidida (inline / subagente único / patrón multi-agente), con las
   mismas reglas de coordinación por archivo que ya trae `speckit-implement` nativo: tareas que
   tocan el mismo archivo nunca corren concurrentes, aunque estén en roles distintos de un patrón
   multi-agente. **El cwd del Bash tool no persiste entre llamadas — confirmado en vivo (v0.3)**:
   cada invocación de Bash arranca en el working directory primario de la sesión, sin importar qué
   `cd` haya corrido en una llamada anterior; solo sobrevive dentro de la misma invocación compuesta
   (`cd /ruta/absoluta && comando`). Para comandos de fase que dependen de un cwd específico (tests,
   builds, scripts que leen `.env` relativo), prefijar siempre `cd /ruta/absoluta/de/la/fase &&` en el
   mismo comando — nunca asumir que un `cd` de un paso anterior se mantiene. Un fallo que parece de
   código (variable de entorno faltante, módulo no encontrado) puede ser en realidad esto.
6. **Marcar `[X]` en `tasks.md`** cada tarea de la fase a medida que se confirma terminada — sin
   importar si la ejecutó esta sesión, un subagente delegado, o un rol de un patrón multi-agente.
   Esta sesión (el orquestador) es la única que edita `tasks.md` — un CLI delegado nunca escribe
   directamente sobre `tasks.md`, reporta de vuelta y el orquestador marca.
7. **Fallos a mitad de fase**: aplicar el Paso 6 de agent-selection tal cual (timeouts explícitos,
   nunca esperar indefinido, limpiar tabs huérfanos, degradación con resultados parciales reportada
   explícitamente) — mismo criterio que ya usa `speckit-implement` de "halt si falla una tarea no
   paralela, seguir y reportar si falla una `[P]`", combinado con las reglas de Herdr. **Extensión a
   infra externa (v0.3)**: el mismo principio del Paso 6 punto 2 de agent-selection ("Herdr puede caer
   a mitad de camino, sin señal proactiva — se detecta porque el siguiente comando falla") aplica a
   cualquier dependencia externa que la fase necesite (DB, contenedores Docker/OrbStack, servicios
   locales) — si una fase que depende de infra externa falla de forma rara, verificar primero que esa
   infra siga viva antes de asumir que el fallo es del código.

## Paso 4 — cierre

Igual que el "Done When" de `speckit-implement`, más el detalle por fase:

- [ ] Todas las tareas de `tasks.md` marcadas `[X]` (o explícitamente reportadas como no
      completadas, con la razón).
- [ ] Por cada fase: qué ruta de agent-selection se usó y por qué (resumen, no hace falta repetir
      el detalle completo del Paso 5 de agent-selection ya reportado antes de ejecutarla).
- [ ] Cualquier degradación (Paso 6 de agent-selection) reportada explícitamente, nunca ocultada.
- [ ] Implementación validada contra `spec.md`/`plan.md`, igual que exige `speckit-implement`.

## Notas

- Esta skill no reemplaza `speckit-converge` ni `speckit-analyze` — siguen corriendo igual después,
  porque el formato de `tasks.md` (checkboxes `[X]`) no cambia.
- No cubre las fases de "proposal" ni "review/verify + archive" que le faltan a Spec Kit (ver
  memoria de decisión sobre el roadmap SDD) — quedan fuera de alcance por ahora, archivadas.
