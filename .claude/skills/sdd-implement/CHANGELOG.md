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
