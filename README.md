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
vía [Herdr](https://herdr.dev), y qué CLI/modelo asignar a cada rol (Claude Code, Codex, opencode, Agy).

- Uso y criterios: [`SKILL.md`](.claude/skills/agent-selection/SKILL.md)
- Historial de versiones: [`CHANGELOG.md`](.claude/skills/agent-selection/CHANGELOG.md)
- Pendientes de seguridad: [`TODO.md`](.claude/skills/agent-selection/TODO.md)

### Setup requerido fuera del repo

La skill lanza CLIs externos con acceso a la memoria compartida de Engram restringido a solo-lectura
(`mem_search`), a través de un wrapper que se antepone al `PATH` del CLI lanzado. Ese wrapper **no vive
en este repo a propósito** — si viviera dentro, un CLI lanzado con permiso de escritura sobre el
proyecto (ej. Codex con `-s workspace-write`) podría editarlo o borrarlo antes de intentar saltárselo.

Antes de usar la skill en una máquina nueva, crear el wrapper en:

```
~/.local/share/agent-selection/restricted-bin/engram
```

Contenido y permisos (`chmod +x`) documentados en `SKILL.md`, sección "Memoria compartida (Engram)".
Sin este archivo, el `PATH` inline del Paso 4 no tiene nada que anteponer y el CLI lanzado termina
resolviendo el binario real de Engram sin restricción.
