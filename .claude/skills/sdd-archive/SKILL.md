---
name: "sdd-archive"
description: "Archiva una feature de Spec Kit moviendo su carpeta a specs/_archive/ y generando state.yaml, sólo si verify-report.md da veredicto limpio en todos sus criterios y tras confirmación humana explícita."
argument-hint: "Nombre o ruta de la feature a archivar (ej. 002-sdd-gap-skills o specs/002-sdd-gap-skills)"
compatibility: "Requiere estructura de proyecto Spec Kit (.specify/) con verify-report.md generado por sdd-verify"
metadata:
  status: experimental
  version: "0.1"
user-invocable: true
disable-model-invocation: false
---

## Qué hace esta skill

Cierra el ciclo de desarrollo SDD (Spec-Driven Development) archivando una feature cuya implementación y verificación han finalizado. Lee `verify-report.md` (generado por `sdd-verify`), evalúa la totalidad de sus veredictos, y si todos los criterios están en `pass`, solicita confirmación humana explícita (Principio III de la constitución del repo), genera `state.yaml` con los 4 campos obligatorios de metadata de cierre (`feature`, `estado`, `fecha_archivado`, `resumen_verify`) y traslada la carpeta completa de la feature desde `specs/<feature>/` a `specs/_archive/<feature>/` (creando `specs/_archive/` si aún no existe).

## User Input

```text
$ARGUMENTS
```

Si el argumento no está vacío, identifica la feature a archivar (aceptando formatos como `002-sdd-gap-skills` o `specs/002-sdd-gap-skills`). Si está vacío, intenta resolver la feature activa actual en `specs/` (o solicita aclaración al usuario si existe ambigüedad entre múltiples carpetas activas).

## Paso 1 — Verificación de idempotencia y edge cases (archivado previo)

Antes de realizar lecturas o procesamientos adicionales:
1. Verificar si la carpeta de la feature especificada ya fue movida previamente a `specs/_archive/<feature>/` o si ya no se encuentra en `specs/`.
2. Verificar si dentro del directorio de la feature (`specs/<feature>/` o `specs/_archive/<feature>/`) ya existe el archivo `state.yaml` con `estado: archivada`.
3. **Comportamiento ante re-ejecución**: Si se cumple cualquiera de las condiciones anteriores, detener la ejecución inmediatamente e informar al usuario que la feature ya fue archivada previamente, reportando su estado sin repetir el movimiento de archivos ni re-generar `state.yaml`.

## Paso 2 — Inspección de `verify-report.md` y evaluación de bloqueo (FR-005)

1. Ubicar y leer el archivo `verify-report.md` dentro de la carpeta de la feature (`specs/<feature>/verify-report.md`).
   - Si `verify-report.md` **no existe**, rehusarse a archivar explicando que la feature debe ser verificada primero ejecutando `sdd-verify`.
2. Analizar las filas y veredictos reportados en `verify-report.md` (`pass`, `fail`, `no verificable`).
3. **Evaluación de bloqueo**:
   - Si detecta **al menos un criterio** marcado como `fail` o `no verificable`:
     - **REHUSAR EL ARCHIVADO**.
     - Listar detalladamente en el reporte cada uno de los criterios que bloquean el archivado, indicando su estado (`fail` o `no verificable`) y el motivo/detalle reportado en `verify-report.md`.
     - Detener el proceso sin mover ningún archivo ni modificar la estructura del repositorio.

## Paso 3 — Gate de confirmación humana explícita (Principio III de la constitución)

1. Si **todos los criterios** registrados en `verify-report.md` tienen veredicto limpio en `pass`:
2. **PARAR Y PEDIR CONFIRMACIÓN EXPLICITA AL USUARIO** antes de realizar cualquier cambio en el sistema de archivos (Principio III de la constitución del repo — no negociable, nunca omitir este paso).
   - Informar al usuario que la feature ha superado todas las verificaciones en `pass`.
   - Detallar la acción a realizar: generación de `state.yaml` y movimiento de la carpeta `specs/<feature>/` a `specs/_archive/<feature>/`.
   - Esperar la respuesta y autorización explícita del usuario para continuar.

## Paso 4 — Generación de `state.yaml` y traslado a `specs/_archive/` (FR-006)

Una vez confirmada explícitamente la acción por parte del usuario:
1. Crear el archivo `state.yaml` en la raíz de la carpeta de la feature (`specs/<feature>/state.yaml`) conteniendo exactamente los 4 campos definidos en `data-model.md`:
   ```yaml
   feature: "<NNN-nombre>"
   estado: "archivada"
   fecha_archivado: "<YYYY-MM-DD>"
   resumen_verify: "Todos los criterios verificados en pass (<N>/<N> pass)"
   ```
2. Asegurar la existencia del directorio de destino `specs/_archive/` (crearlo si no existe).
3. Mover la carpeta completa de la feature de `specs/<feature>/` a `specs/_archive/<feature>/`.

## Paso 5 — Reporte de cierre

Presentar el resumen final al usuario:
- Confirmar que la carpeta de la feature fue trasladada con éxito a `specs/_archive/<feature>/`.
- Mostrar el contenido del archivo `state.yaml` generado.
- Notificar que las herramientas de Spec Kit (`/speckit-converge`, `/speckit-analyze`, etc.) continúan funcionando normalmente sobre la carpeta en su nueva ubicación archivada.

## Notas

- **Trazabilidad y versiones**: Todo cambio en la estructura o comportamiento de esta skill requiere actualizar `metadata.version` en este `SKILL.md` y agregar la entrada correspondiente en `CHANGELOG.md` (Principio IV de la constitución).
- **Acciones irreversibles**: El movimiento de carpetas a `specs/_archive/` cambia la ubicación activa de las specs. El guardrail de confirmación humana del Paso 3 es la salvaguarda obligatoria requerida por el Principio III de la constitución.
