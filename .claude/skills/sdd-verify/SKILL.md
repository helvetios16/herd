---
name: "sdd-verify"
description: "Verifica una feature ya implementada contra su spec.md: compila cada acceptance scenario y success criterion y da un veredicto pass/fail/no verificable por cada uno contra el estado real del repo, citando la evidencia real usada en cada pass. Genera verify-report.md dentro de specs/<feature>/."
argument-hint: "Directorio o nombre de carpeta de la feature a verificar (ej. specs/002-sdd-gap-skills o 002-sdd-gap-skills). Si se omite, se resuelve igual que speckit-implement (script de prerrequisitos)."
compatibility: "Requiere estructura de proyecto Spec Kit (.specify/) con spec.md de la feature y una implementación real (tasks.md con al menos una tarea marcada [X])"
metadata:
  status: experimental
  version: "0.1"
user-invocable: true
disable-model-invocation: false
---

## Qué hace esta skill

Cubre el gap de "review/verify con evidencia" que Spec Kit no resuelve nativamente:
`speckit-converge` solo agrega tareas faltantes, no verifica. Esta skill se corre **después** de
`/speckit-implement` o `/sdd-implement`, sobre una feature que ya tiene implementación real en el
repo, y responde, criterio por criterio, si esa implementación cumple lo que pedía `spec.md` —
respaldado con evidencia real (comando corrido y su resultado, o archivo/línea leído), no con la
palabra de que "ya funciona".

Verificar significa, para cada Acceptance Scenario y Success Criterion de `spec.md`, ejecutar una
**verificación puntual** contra el estado real del repo — un comando puntual, un `test -f`, una
lectura de archivo — y clasificar el resultado en `pass`, `fail` o `no verificable`. Mismo criterio
adversarial del Principio I de la constitución, aplicado a la base de código: nunca se marca `pass`
sin que la evidencia con la que se llegó a ese veredicto esté citada en la misma fila del reporte,
y nunca se fuerza un veredicto para el que no hay base (Principio II: no inventar veredictos ni
mecanismos sin necesidad concreta).

No corre una suite de tests automatizada propia — reutiliza la evidencia que ya exista de la
implementación (tests corridos durante `/sdd-implement`, comandos ya ejecutados) o corre ella misma
las verificaciones puntuales cuando el criterio lo permite, consistente con que este repo no tiene
un framework de test unificado (Assumptions de `spec.md`). No toca código: solo escribe un archivo
nuevo en la carpeta de la feature.

## User Input

```text
$ARGUMENTS
```

Resolver qué feature verificar: si el argumento trae el directorio o el nombre de la carpeta de la
feature (`specs/NNN-nombre/` o `NNN-nombre`), se usa tal cual. Si viene vacío, se resuelve igual
que `speckit-implement` (script de prerrequisitos, Paso 1), permitiendo que no exista `tasks.md`.

## Paso 1 — resolver la feature y destrabar "nada que verificar todavía"

1. Si el argumento trae el directorio de la feature, tomarlo directo. Si no, correr
   `.specify/scripts/bash/check-prerequisites.sh --json` **sin** `--require-tasks` (a diferencia de
   `speckit-implement`: acá es un caso válido, no un error, que no exista `tasks.md` o que no tenga
   tareas marcadas) y resolver `FEATURE_DIR` y `AVAILABLE_DOCS`.
2. **Gate 1: nada que verificar todavía.** Si `FEATURE_DIR/tasks.md` no existe, o existe pero tiene
   **cero** tareas marcadas `[X]`, parar acá y reportar explícitamente **"nada que verificar
   todavía"**: sin una tarea marcada como hecha no hay implementación que confrontar contra
   `spec.md`. **No generar `verify-report.md`** en ese caso — fabricar veredictos sin base viola el
   Edge Case de `spec.md` y el Principio I. No es un fallo de la skill: es el estado correcto de una
   feature que todavía no se implementó, y se comunica como tal.
3. Si `spec.md` no existe en `FEATURE_DIR`, parar y reportar que no hay especificación contra la
   cual verificar nada — también sin generar reporte.
4. Cargar contexto: `spec.md` (los criterios a verificar), `tasks.md`/`plan.md` (para saber qué
   artefactos esperar del estado real de la feature).

## Paso 2 — extraer los criterios de `spec.md`

Leer `spec.md` completo y compilar la lista de criterios verificables, **sin omitir ni fusionar
ninguno**:

- Cada **Acceptance Scenario** (secciones `Acceptance Scenarios` de cada User Story), con referencia
  al formato de `data-model.md`: "US-N / Acceptance Scenario M".
- Cada **Success Criterion** (`SC-00N` en la sección Measurable Outcomes), con referencia `"SC-00N"`.

Por cada criterio, anotar: la referencia, el texto del criterio (para citarlo en el reporte sin
reinterpretarlo), y qué artefacto o estado del repo podría verificarlo. Si un criterio no mapea a
ningún estado observable hoy, no se descarta: pasa al Paso 3, donde termina como `no verificable`
con el motivo.

## Paso 3 — verificar cada criterio contra el estado real

Por cada criterio de la lista, en el orden en que aparece en `spec.md`:

1. **Verificación puntual.** Elegir la verificación más simple con la que se pueda dirimir el
   criterio contra el estado real, en orden de preferencia:
   - (a) un comando puntual — ej. `test -f <ruta>` para criterios que piden que exista un archivo,
     o cualquier comando corto cuyo resultado se pueda citar;
   - (b) lectura de archivo — para verificar contenido o estructura, citando archivo y línea(s);
   - (c) reutilizar evidencia que ya exista de la implementación (tests corridos en `/sdd-implement`,
     comandos ya ejecutados) en vez de re-ejecutarla — citando siempre lo que realmente pasó, nunca
     una salida asumida.
2. **Clasificar** con la evidencia real obtenida en (1) — nunca al revés:
   - la verificación confirma el criterio → `pass`, con la **evidencia concreta** citada en la misma
     fila del reporte (comando + resultado, o archivo/línea). **No hay `pass` sin evidencia
     citada** (FR-004): si no se pudo obtener evidencia, esa fila no es `pass`.
   - la verificación contradice el criterio → `fail`, con `detalle` que explique qué falta (qué se
     esperaba vs qué hay) para que la implementación lo corrija y se re-corra la skill.
   - el criterio no se puede verificar objetivamente con lo disponible hoy (apunta a algo fuera del
     repo o a un comportamiento no observable con los medios citables a la mano) → `no verificable`,
     con `detalle` que explique por qué no se pudo y qué haría falta — nunca se obliga `pass` ni
     `fail` sin base (Edge Case de `spec.md`, FR-003).
3. **No reparar en esta skill.** Si un criterio falla, se reporta el `fail` con su detalle — la
   verificación no edita código ni cambia el estado del repo para "lograr" un `pass`. Corregir la
   implementación y correr de nuevo `sdd-verify` queda del lado de la implementación.

## Paso 4 — escribir `verify-report.md` y cerrar

Escribir `FEATURE_DIR/verify-report.md`, una fila por cada criterio de `spec.md`, con la estructura
de `data-model.md`:

```markdown
| criterio | veredicto | evidencia | detalle |
|---|---|---|---|
| US-2 / Acceptance Scenario 1 | pass | `test -f specs/002-sdd-gap-skills/spec.md` → exit 0 | — |
| SC-002 | no verificable | — | el criterio apunta a una métrica no medible en este repo; hace falta X |
```

Reglas de la tabla: `evidencia` es **obligatoria** en toda fila `pass` (nunca se deja en blanco);
`detalle` es **obligatorio** en toda fila `fail` o `no verificable`; en las filas `pass`, `detalle`
lleva el marcador `—`. Cerrar con un resumen corto del tipo "X pass / N fail / Z no verificable",
para que `sdd-archive` pueda decidir leyendo el reporte.

Cierre, antes de dar la corrida por terminada:

- [ ] Una fila por cada Acceptance Scenario y cada Success Criterion de `spec.md` — ningún criterio
      sin cubrir ni fusionado con otro.
- [ ] Cada fila `pass` cita su evidencia en la misma fila (FR-004); si no hay evidencia, esa fila no
      es `pass`.
- [ ] Cada fila `fail`/`no verificable` declara su `detalle` con el motivo (FR-003).
- [ ] El único archivo creado es `FEATURE_DIR/verify-report.md` — no se tocó código ni
      `spec.md`/`tasks.md`/`plan.md`.
- [ ] Si el Paso 1 reportó "nada que verificar todavía", no hay ningún `verify-report.md` nuevo: se
      comunicó el estado sin fabricar veredictos.

## Notas

- No reemplaza a `speckit-converge` (agrega tareas faltantes, no verifica) ni a `speckit-analyze`
  (coherencia entre artefactos): es el paso de "review/verify" que Spec Kit no cubre.
- Su consumidor natural es `sdd-archive`, que se rehúsa a archivar una feature con algún criterio
  en `fail` o `no verificable`, en el ciclo `propose → specify → implement → verify → archive`.
- `verify-report.md` es un archivo nuevo en la carpeta de la feature; el formato de `spec.md`/
  `plan.md`/`tasks.md` no cambia, así que `speckit-converge`/`speckit-analyze` siguen funcionando
  igual después de verificado.