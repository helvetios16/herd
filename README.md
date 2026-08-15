# herd

Repo de skills de Claude Code. Principios generales del repo en
[`.specify/memory/constitution.md`](.specify/memory/constitution.md) (Spec-Driven Development vía
[Spec Kit](https://github.com/github/spec-kit)).

## Skills

- [`agent-selection`](.claude/skills/agent-selection/) — evalúa si una tarea requiere un solo agente
  o un patrón multi-agente coordinado vía Herdr, y qué CLI/modelo asignar a cada rol.
- [`sdd-implement`](.claude/skills/sdd-implement/) — ejecuta `tasks.md` de una feature de Spec Kit
  delegando cada fase al framework de decisión de `agent-selection`, en vez de correr todo inline
  como `/speckit-implement` nativo.
- [`sdd-propose`](.claude/skills/sdd-propose/) — encuadra una feature (problema, alcance, archivos
  afectados, riesgos, rollback) antes de `/speckit-specify`, dejando `proposal.md` en la misma
  carpeta que `spec.md`.
- [`sdd-verify`](.claude/skills/sdd-verify/) — verifica una feature ya implementada contra `spec.md`
  con evidencia real, criterio por criterio, en `verify-report.md`.
- [`sdd-archive`](.claude/skills/sdd-archive/) — archiva una feature con `verify-report.md` limpio a
  `specs/_archive/`, con confirmación humana explícita antes de mover nada.
- `speckit-*` — las 10 skills nativas de Spec Kit (`constitution`, `specify`, `plan`, `tasks`,
  `implement`, `converge`, `clarify`, `analyze`, `checklist`, `taskstoissues`), instaladas por
  `specify init` sin modificar.

Ciclo SDD completo de este repo: `sdd-propose` → `speckit-specify` → `speckit-plan` →
`speckit-tasks` → `sdd-implement` (no `speckit-implement`) → `sdd-verify` → `sdd-archive`.

## agent-selection

Skill experimental que evalúa si una tarea requiere un solo agente o un patrón multi-agente coordinado
vía [Herdr](https://herdr.dev), y qué CLI/modelo asignar a cada rol (Claude Code —incluida una segunda
instancia como ejecutor/juez—, Codex, opencode).

- Uso y criterios: [`SKILL.md`](.claude/skills/agent-selection/SKILL.md)
- Historial de versiones: [`CHANGELOG.md`](.claude/skills/agent-selection/CHANGELOG.md)
- Método y hallazgos de la ronda de seguridad (sin pendientes activos):
  [`TODO.md`](.claude/skills/agent-selection/TODO.md)
