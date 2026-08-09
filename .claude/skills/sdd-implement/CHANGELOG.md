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
- **v0.3** — cerrados 2 hallazgos de una segunda ronda de feedback en earpi (US1, T011-T014, ver
  `TODO.md` de `agent-selection`, sección "Feedback de uso real — earpi, actualización US1"). Uno
  verificado en vivo, más a fondo que el reporte original: earpi sospechaba que el cwd del Bash tool
  se reseteaba a veces por interleaving con otra tool; probado acá de forma aislada y determinista
  (`cd .../backend && pwd` en una llamada, `pwd` solo en la siguiente sin ninguna otra tool en el
  medio, repetido 3 veces) — **el cwd vuelve al working directory primario en cada llamada, siempre**,
  no solo a veces. Agregada precaución explícita en el Paso 3, punto 5: prefijar comandos de fase que
  dependan de un cwd específico con `cd /ruta/absoluta &&` en la misma invocación. El segundo hallazgo
  (infra externa —OrbStack/Docker— cayéndose a mitad de fase sin aviso) se aplicó por extensión directa
  del principio que el Paso 6 de `agent-selection` ya usa para Herdr, agregado al punto 7 del Paso 3:
  verificar que la infra externa siga viva antes de asumir que un fallo a mitad de fase es del código.
- **v0.4** — sin cambios de contenido en `SKILL.md`. Registrada en `TODO.md` de `agent-selection` la
  confirmación de una tercera ronda de `FEEDBACK.md` en earpi (US2, T015-T019): el patrón de
  delegación con contrato fijo (Paso 3, señales de `tasks.md` para agent-selection) dio resultado
  correcto por tercera vez consecutiva (T008/T009, T015/T016) — sin fricción nueva de ejecución de
  fase en esta ronda. El fix de polling (`herdr wait agent-status`/`herdr wait output`) que también se
  confirmó limpio en esta ronda es de `agent-selection` v0.33, no de esta skill — ver su `CHANGELOG.md`
  v0.34.
