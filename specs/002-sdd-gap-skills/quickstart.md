# Quickstart: Skills que cierran los gaps de SDD de Spec Kit

## Prerrequisitos

- `sdd-propose`, `sdd-verify`, `sdd-archive` implementadas (ver `tasks.md`).

## Escenario 1 — `sdd-propose` → `speckit-specify` quedan en la misma carpeta (US1, SC-001)

```bash
# correr sdd-propose con una descripción de feature de prueba chica y descartable
# (ej. "un archivo VERSION en la raíz del repo con el string actual del repo")
# confirmar: crea specs/<NNN-nombre>/proposal.md, sin placeholders sin resolver
# correr /speckit-specify a continuación, SIN describir de nuevo la feature
# confirmar: spec.md aparece en la MISMA carpeta que proposal.md
ls specs/<NNN-nombre>/   # esperado: proposal.md y spec.md, mismo directorio
```

**Esperado**: `proposal.md` con las 5 secciones de `data-model.md` completas. `spec.md` en la misma
carpeta — no un directorio numerado nuevo.

## Escenario 2 — `sdd-verify` da veredicto con evidencia (US2, SC-002)

```bash
# sobre la feature de prueba del Escenario 1, ya implementada (aunque sea trivialmente)
# correr sdd-verify
cat specs/<NNN-nombre>/verify-report.md
```

**Esperado**: una fila por acceptance scenario/success criterion de `spec.md` de esa feature,
cada una `pass`/`fail`/`no verificable`. Ningún `pass` sin evidencia citada en la misma fila.

## Escenario 3 — un criterio incumplido bloquea el archivado (US2 + US3, SC-003)

```bash
# introducir a propósito un incumplimiento (ej. borrar el archivo que la feature de prueba
# debía crear) antes de correr sdd-verify
rm <archivo-que-la-feature-de-prueba-debia-crear>
# correr sdd-verify de nuevo
grep fail specs/<NNN-nombre>/verify-report.md   # esperado: al menos una fila
# correr sdd-archive
```

**Esperado**: `sdd-archive` se rehúsa a archivar, listando el criterio en `fail` que lo bloquea. La
carpeta de la feature sigue en `specs/`, no se mueve nada.

## Escenario 4 — corregido, `sdd-archive` archiva limpio (SC-004)

```bash
# revertir el incumplimiento del Escenario 3 (recrear el archivo borrado)
# correr sdd-verify de nuevo — esperado: todos los criterios en pass
# correr sdd-archive de nuevo
ls specs/<NNN-nombre> 2>&1          # esperado: No such file or directory
ls specs/_archive/<NNN-nombre>/      # esperado: la carpeta completa, + state.yaml nuevo
cat specs/_archive/<NNN-nombre>/state.yaml
```

**Esperado**: la carpeta ya no está en `specs/`, aparece completa bajo `specs/_archive/` con
`state.yaml` reflejando el veredicto limpio. `/speckit-converge`/`/speckit-analyze` corridos sobre
esa ruta archivada siguen funcionando igual (US3, Acceptance Scenario 3) — no se valida acá para no
alargar el quickstart, queda como chequeo manual opcional si hace falta más confianza.
