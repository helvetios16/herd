# herd

Repo de skills de Claude Code. Por ahora contiene una sola: [`agent-selection`](.claude/skills/agent-selection/).

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
