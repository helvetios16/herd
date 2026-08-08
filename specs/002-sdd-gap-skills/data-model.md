# Data Model: Skills que cierran los gaps de SDD de Spec Kit

Sin base de datos — estas son las entidades conceptuales que cada skill lee/escribe como archivos
Markdown/YAML dentro de `specs/<feature>/`.

## Proposal (`sdd-propose` → `proposal.md`)

| Campo | Notas |
|---|---|
| `problema` | qué motiva la feature, en texto libre |
| `alcance_incluye` | lista de qué entra |
| `alcance_excluye` | lista de qué se descarta explícitamente |
| `archivos_afectados` | rutas o patrones de archivos que la feature va a tocar |
| `riesgos` | riesgos identificados, incluyendo si toca la lista de riesgo de `agent-selection` |
| `rollback` | cómo revertir la feature si hace falta |

## Verify Report (`sdd-verify` → `verify-report.md`)

Una fila por criterio de `spec.md` (acceptance scenario o success criterion).

| Campo | Valores |
|---|---|
| `criterio` | referencia al criterio de `spec.md` (ej. "US1 / Acceptance Scenario 2", "SC-003") |
| `veredicto` | `pass` \| `fail` \| `no verificable` |
| `evidencia` | obligatoria si `veredicto = pass` (comando corrido + resultado, o archivo/línea) |
| `detalle` | obligatorio si `veredicto = fail` o `no verificable` (qué falta o por qué no se pudo verificar) |

## State (`sdd-archive` → `state.yaml`)

| Campo | Notas |
|---|---|
| `feature` | nombre de la carpeta (`NNN-nombre`) |
| `estado` | `archivada` (único valor por ahora — FR-006 no pide otros estados) |
| `fecha_archivado` | fecha de la corrida de `sdd-archive` |
| `resumen_verify` | resumen corto del veredicto de `verify-report.md` (todos los criterios en pass) |
