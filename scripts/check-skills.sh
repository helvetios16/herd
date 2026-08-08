#!/usr/bin/env bash
# Usage: ./scripts/check-skills.sh
# Audita .claude/skills/*: name del frontmatter vs. carpeta, y CHANGELOG.md para skills versionadas.
set -euo pipefail

SKILLS_DIR=".claude/skills"
CHECKS=()

add_check() {
  # $1 skill  $2 check  $3 result  $4 detail
  CHECKS+=("$1|$2|$3|$4")
}

# T003: extrae el bloque de frontmatter (entre el primer y el segundo "---") de un SKILL.md.
# Exit 1 si no hay frontmatter válido.
get_frontmatter() {
  local file="$1"
  awk '
    NR==1 && $0!="---" { exit 1 }
    NR==1 { next }
    /^---$/ { found=1; exit }
    { print }
    END { if (!found) exit 1 }
  ' "$file"
}

# T003: extrae un campo escalar top-level (ej. "name") de un bloque de frontmatter.
get_field() {
  printf '%s\n' "$1" | grep -m1 "^${2}:" | sed -E 's/^[a-zA-Z_]+: *//; s/^"//; s/"$//'
}

# T003: extrae metadata.version (campo anidado) de un bloque de frontmatter.
get_metadata_version() {
  printf '%s\n' "$1" | awk '
    /^metadata:/ { inmeta=1; next }
    inmeta && /^[a-zA-Z_]/ { inmeta=0 }
    inmeta && /version:/ {
      sub(/^ *version: */, "")
      gsub(/"/, "")
      print
      exit
    }
  '
}

# T002: itera las skills instaladas y aplica los chequeos de T005/T007.
for dir in "$SKILLS_DIR"/*/; do
  skill=$(basename "$dir")
  skill_md="${dir}SKILL.md"

  if [ ! -f "$skill_md" ]; then
    add_check "$skill" "skill-md-present" "fail" "SKILL.md ausente"
    continue
  fi

  if ! frontmatter=$(get_frontmatter "$skill_md"); then
    add_check "$skill" "frontmatter-valid" "fail" "sin delimitadores --- válidos"
    continue
  fi

  # T005 (US1): name-matches-dir
  name_val=$(get_field "$frontmatter" "name")
  if [ "$name_val" = "$skill" ]; then
    add_check "$skill" "name-matches-dir" "pass" ""
  else
    add_check "$skill" "name-matches-dir" "fail" "encontrado='${name_val:-<vacío>}' esperado='${skill}'"
  fi

  # T007 (US2): has-changelog, solo si declara metadata.version
  version_val=$(get_metadata_version "$frontmatter")
  if [ -n "$version_val" ]; then
    if [ -f "${dir}CHANGELOG.md" ]; then
      add_check "$skill" "has-changelog" "pass" ""
    else
      add_check "$skill" "has-changelog" "fail" "metadata.version='${version_val}' sin CHANGELOG.md"
    fi
  fi
done

# T004: resumen tabular + exit code
printf '%-20s %-18s %-7s %s\n' "skill" "check" "result" "detail"
failed=0
for entry in "${CHECKS[@]}"; do
  IFS='|' read -r skill check result detail <<< "$entry"
  printf '%-20s %-18s %-7s %s\n' "$skill" "$check" "$result" "$detail"
  [ "$result" = "fail" ] && failed=1
done

exit "$failed"
