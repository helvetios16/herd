#!/usr/bin/env bash
# Regenera SKILL.md a partir del `herdr --skill` instalado, agregando metadata de versión
# capturada en vivo (no a mano). Correr después de cada `brew upgrade herdr` (o equivalente).
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OUT="$SCRIPT_DIR/SKILL.md"

if ! command -v herdr >/dev/null 2>&1; then
  echo "error: herdr no está instalado o no está en PATH" >&2
  exit 1
fi

VERSION="$(herdr --version | awk '{print $2}')"
RAW="$(herdr --skill)"

awk -v version="$VERSION" '
  NR == 1 && $0 == "---" { in_fm = 1; print; next }
  in_fm && $0 == "---" && !fm_end_seen {
    print "metadata:"
    print "  source: \"verbatim output of `herdr --skill`, captured from the installed binary — not hand-written\""
    print "  captured_from_herdr_version: \"" version "\""
    print "  refresh: \"regenerate with .claude/skills/herdr/regenerate.sh after any Herdr upgrade; this file carries no self-updating version check\""
    print "---"
    fm_end_seen = 1
    in_fm = 0
    next
  }
  { print }
' <<< "$RAW" > "$OUT"

echo "Regenerado $OUT (herdr $VERSION)"
