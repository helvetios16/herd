# Data Model: Auditoría de consistencia de skills

Sin persistencia — estas son las entidades conceptuales que el script maneja en memoria mientras
recorre `.claude/skills/`.

## Skill

Una carpeta bajo `.claude/skills/` que contiene un `SKILL.md`.

| Campo | De dónde sale | Notas |
|---|---|---|
| `dir_name` | nombre de la carpeta | clave de comparación para el chequeo de `name` |
| `frontmatter_name` | campo `name` del frontmatter YAML | ausente/inválido → chequeo 1 falla |
| `version` | campo `metadata.version` del frontmatter | ausente → chequeo 2 se omite (no aplica) para esa skill |
| `has_changelog` | `test -f CHANGELOG.md` en la misma carpeta | solo se evalúa si `version` está presente |

## Check

Resultado de aplicar un chequeo a una `Skill`.

| Campo | Valores |
|---|---|
| `skill` | `dir_name` de la skill |
| `check` | `"name-matches-dir"` \| `"has-changelog"` |
| `result` | `"pass"` \| `"fail"` \| `"skipped"` (solo para `has-changelog` cuando no hay `version`) |
| `detail` | mensaje corto, solo relevante cuando `result = "fail"` (ej. valores esperado vs. encontrado) |

El resumen final (`FR-004`) es una tabla de `Check`, uno por fila. El exit code (`FR-005`) es
`1` si existe algún `Check` con `result = "fail"`, `0` en cualquier otro caso.
