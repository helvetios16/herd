# Changelog — sdd-verify

- **v0.1** — primera versión. Cierra el gap de "review/verify con evidencia" del roadmap SDD que
  Spec Kit no cubre nativamente (`speckit-converge` solo agrega tareas faltantes, no verifica).
  Skill invocable que corre **después** de `/speckit-implement` o `/sdd-implement`: lee `spec.md`
  de la feature, compila cada Acceptance Scenario (referencia "US-N / Acceptance Scenario M") y cada
  Success Criterion (`SC-00N`), y por cada uno ejecuta una **verificación puntual** contra el estado
  real del repo (comando puntual, `test -f`, lectura de archivo, o reutilización de evidencia ya
  existente de la implementación) — misma actitud adversarial del Principio I de la constitución.
  Ningún criterio puede marcar `pass` sin citar en la misma fila del `verify-report.md` la evidencia
  real usada (FR-004); si no hay forma objetiva de verificar, se marca `no verificable` con el
  motivo en `detalle`, nunca se fuerza a `pass`/`fail` sin base (FR-003, Acceptance Scenario 3 de la
  User Story 2). Si la feature no tiene `tasks.md` con al menos una tarea `[X]`, reporta "nada que
  verificar todavía" y **no** genera `verify-report.md` — evita veredictos fabricados (Edge Case de
  `spec.md`). No corre suite de tests propia: reutiliza la evidencia existente o corre
  verificaciones puntuales ella misma (Assumptions de `spec.md`). El único output es un archivo
  nuevo en la carpeta de la feature (`verify-report.md`, una fila por criterio según el
  `data-model.md`); el formato de `spec.md`/`plan.md`/`tasks.md` no cambia, así que
  `speckit-converge`/`speckit-analyze` siguen funcionando igual después. Consumidor natural:
  `sdd-archive`, que se rehúsa a archivar si queda algún `fail`/`no verificable`.
