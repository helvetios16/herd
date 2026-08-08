# Changelog — sdd-implement

- **v0.1** — primera versión. Puente entre las bases que deja Spec Kit (`spec.md` → `plan.md` →
  `tasks.md`, vía `/speckit-constitution` → `/speckit-specify` → `/speckit-plan` → `/speckit-tasks`)
  y la ejecución real: en vez de correr `/speckit-implement` nativo (todo inline en la sesión
  actual), esta skill evalúa **cada fase de `tasks.md`** con el framework de decisión completo de
  `agent-selection` (Paso 0-6) para decidir agente único / delegado / patrón multi-agente vía Herdr.
  Reusa por referencia (no copia) los pasos de prerrequisitos, checklist status y setup de
  `speckit-implement` — evita que una actualización futura de `specify` deje una copia
  desactualizada acá. Señal nueva: las tareas `[P]` de `tasks.md` alimentan directamente la
  pregunta 4 del Paso 2 de agent-selection (trabajo mecánico/separable → candidato a model
  tiering). `speckit-implement` sigue instalado sin tocar, como fallback nativo. No cubre las fases
  de proposal ni review/verify+archive del roadmap SDD — quedan archivadas, fuera de alcance de
  esta versión.
- **v0.2** — primer trial en vivo (Principio I de la constitución), caso real: `scripts/check-skills.sh`
  corrido de punta a punta con `/speckit-specify` → `/speckit-plan` → `/speckit-tasks` →
  `/sdd-implement` (`specs/001-skill-audit/`). Las 5 fases resolvieron Direct inline (un solo
  archivo, mecánico, sin lista de riesgo) — confirma que el puente no sobre-escala un caso trivial,
  pero deja sin ejercitar la rama delegada/multi-agente (pendiente de un segundo trial con un caso
  que la active). Hallazgo aplicado: el paso 4 del Paso 1 ("reusar tal cual" la verificación de
  ignore-files de `speckit-implement`) aplicado ciego hubiera generado un `.gitignore` genérico con
  patrones de stacks que este repo no usa, violando el Principio II. Aclarado que "reusar por
  referencia" no es "aplicar ciego": cualquier paso reusado que no aplique al caso real se omite
  explícitamente, con la razón.
