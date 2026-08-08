---
name: "sdd-propose"
description: "Encuadra una feature de Spec Kit antes de especificarla, dejando problema, alcance, archivos afectados, riesgos y rollback en una propuesta trazable."
argument-hint: "Describe la feature que quieres encuadrar"
compatibility: "Requiere estructura de proyecto Spec Kit con .specify/ y el script .specify/scripts/bash/create-new-feature.sh"
metadata:
  status: experimental
  version: "0.1"
user-invocable: true
disable-model-invocation: false
---

## Qué hace esta skill

Primer paso del ciclo SDD para este repo. Recibe una descripción de feature en lenguaje natural,
reusa el mecanismo de Spec Kit para crear un directorio numerado bajo `specs/`, y escribe ahí un
`proposal.md` con el encuadre mínimo antes de pasar a `/speckit-specify`: problema, alcance incluido,
alcance excluido, archivos afectados, riesgos y rollback.

La numeración y la creación inicial del directorio no se reimplementan acá: siempre las resuelve
`.specify/scripts/bash/create-new-feature.sh`, que también persiste `.specify/feature.json`. La
carpeta resultante se entrega explícitamente como `SPECIFY_FEATURE_DIRECTORY` para que la siguiente
corrida de `/speckit-specify` escriba `spec.md` junto a `proposal.md`.

## User Input

```text
$ARGUMENTS
```

La descripción que el usuario escribió después de `/sdd-propose` es el input de la feature. Si está
vacía, informar `No feature description provided` y no crear ningún directorio ni archivo.

## Paso 1 — validar el input y cargar el criterio

1. Considerar la descripción completa de `$ARGUMENTS` antes de proponer nada. Extraer actores,
   problema, acción deseada, datos y restricciones que estén presentes.
2. Leer `.specify/memory/constitution.md` y aplicar sus seis principios, especialmente no
   generalizar sin una necesidad concreta, mantener la trazabilidad de versión y separar el
   concepto transferible de la marca o herramienta puntual.
3. Si falta una decisión que cambia materialmente el alcance y no hay un supuesto razonable,
   marcarla con `[NEEDS CLARIFICATION: pregunta concreta]`. Usar como máximo 3 marcadores en total,
   priorizados por alcance, seguridad/privacidad y experiencia de usuario. No inventar datos para
   evitar una aclaración. Presentar las preguntas y esperar respuesta antes de cerrar la propuesta.
4. No usar placeholders genéricos como `[FEATURE NAME]`, `[DATE]`, `TBD` o `N/A`. Un marcador
   `NEEDS CLARIFICATION` es la única excepción permitida cuando la ambigüedad es material; al
   recibir la respuesta, reemplazarlo por una decisión concreta.

## Paso 2 — crear el directorio de la feature con el mecanismo existente

1. Con la descripción disponible, derivar un nombre corto de 2 a 4 palabras, en formato de acción
   o concepto, para pasárselo a `create-new-feature.sh` solo si hace falta fijar el nombre. No
   inventar un prefijo numérico ni escanear `specs/` para numerar.
2. Ejecutar `.specify/scripts/bash/create-new-feature.sh` con la descripción de la feature y
   `--json`. Reusar el script tal cual; no copiar ni reimplementar su algoritmo de numeración,
   resolución de templates, creación de `spec.md` o persistencia de `.specify/feature.json`.
3. Tomar el `SPEC_FILE` y `FEATURE_NUM` devueltos por el script como evidencia. El directorio de
   la feature es el directorio que contiene ese `SPEC_FILE`; conservar la ruta exacta, incluyendo
   `specs/` y el prefijo numérico. Si el script falla, reportar el error y no escribir una
   propuesta en otra carpeta.
4. Usar el directorio resuelto por el script como `SPECIFY_FEATURE_DIRECTORY` para todo lo que
   sigue. No crear una segunda carpeta, aunque el nombre de la rama y el nombre del directorio
   difieran.

## Paso 3 — redactar `proposal.md`

Escribir `SPECIFY_FEATURE_DIRECTORY/proposal.md` con estas seis secciones exactas y en este orden.
Los encabezados deben conservar estos nombres de campo del modelo de datos:

1. `## problema` — qué situación concreta motiva la feature, quién la sufre y qué valor se busca.
2. `## alcance_incluye` — lista concreta de lo que entra en esta feature.
3. `## alcance_excluye` — lista concreta de lo que queda fuera, incluyendo límites que eviten
   generalizar más allá del caso real.
4. `## archivos_afectados` — rutas o patrones de archivos que probablemente se crearán, leerán o
   modificarán. Si todavía no se puede conocer una ruta exacta, describir el patrón y el motivo,
   sin convertirlo en una lista genérica de archivos posibles.
5. `## riesgos` — riesgos específicos de la feature, mitigaciones conocidas y estado de la
   revisión de la lista de riesgo de `agent-selection`.
6. `## rollback` — pasos concretos para revertir la feature y devolver el estado anterior; si la
   reversión requiere una decisión o una acción irreversible, dejarlo señalado.

Escribir contenido derivado de `$ARGUMENTS`, contexto del repo y supuestos razonables. Documentar
los supuestos dentro de la sección relevante o al final de `## problema` como `Supuestos`; no
agregar una séptima sección de modelo ni dejar texto de plantilla sin resolver. La propuesta debe
ser legible para quien va a decidir el alcance y no debe convertirse en un plan de implementación
detallado.

## Paso 4 — revisar explícitamente el riesgo antes del cierre

En `## riesgos`, revisar los archivos y límites identificados contra la lista de riesgo del Paso 2
de `.claude/skills/agent-selection/SKILL.md`: `.env*` y otros archivos de entorno, SSH o
credenciales, configuración de CI/CD, infraestructura, migraciones de base de datos, configuración
de producción/deploy, y auth, pagos o borrado masivo de datos.

Dejar una conclusión explícita, incluso cuando no haya coincidencias:

- `Lista de riesgo de agent-selection: no detectada` y explicar brevemente qué se revisó; o
- `Lista de riesgo de agent-selection: detectada` indicando el patrón o archivo concreto y por qué
  aplica.

Si se detecta un riesgo, no decidir por cuenta propia que la feature puede seguir adelante. Marcar
`CONFIRMACIÓN HUMANA REQUERIDA` en la sección de riesgos y en el Completion Report, y detener
cualquier paso posterior de especificación o implementación hasta que el usuario confirme
explícitamente cómo continuar. La detección no autoriza migraciones, deploys, exposición de secretos,
cambios de auth/pagos ni borrados.

## Paso 5 — Completion Report

Terminar con un reporte al usuario que incluya:

- `SPECIFY_FEATURE_DIRECTORY`: el valor exacto de la ruta resuelta, por ejemplo
  `specs/003-user-auth`.
- `SPEC_FILE`: la ruta exacta devuelta por `create-new-feature.sh`.
- `proposal.md`: confirmación de que fue escrito dentro de `SPECIFY_FEATURE_DIRECTORY` y que
  contiene las seis secciones requeridas.
- `Riesgo`: resultado explícito de la revisión de `agent-selection`; si aplica, el gate de
  confirmación humana pendiente.
- `Siguiente paso`: la invocación de `/speckit-specify` usando exactamente ese valor, por ejemplo
  `SPECIFY_FEATURE_DIRECTORY=specs/003-user-auth /speckit-specify <descripción de la feature>`.

No afirmar que `spec.md` fue creado por esta skill: lo crea `/speckit-specify`. Recordar que el
script ya dejó la ruta persistida en `.specify/feature.json`, pero aun así entregar el valor
explícito de `SPECIFY_FEATURE_DIRECTORY` para el siguiente comando.

## Done When

- [ ] Se rechazó el input vacío sin crear archivos.
- [ ] Se ejecutó `create-new-feature.sh` para resolver el directorio numerado y no se reimplementó
      su numeración.
- [ ] Existe `proposal.md` en la carpeta devuelta por el script.
- [ ] `proposal.md` tiene `problema`, `alcance_incluye`, `alcance_excluye`, `archivos_afectados`,
      `riesgos` y `rollback`, sin placeholders genéricos sin resolver.
- [ ] La revisión de riesgo de `agent-selection` quedó explícita y cualquier coincidencia quedó
      bloqueada para confirmación humana.
- [ ] El Completion Report deja el valor exacto de `SPECIFY_FEATURE_DIRECTORY` para
      `/speckit-specify`.
