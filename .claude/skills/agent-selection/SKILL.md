---
name: agent-selection
description: >
  Evalúa una situación de trabajo y recomienda si conviene usar un solo agente o varios coordinados,
  qué patrón de orquestación aplica, y qué CLI/modelo asignar a cada rol. Trigger: antes de delegar
  una tarea a un agente, cuando se duda si vale la pena coordinar múltiples agentes (vía Herdr u otro
  mecanismo), o al elegir qué CLI/modelo usar para un subagente.
metadata:
  status: experimental
  version: "0.44"
---

## Qué hace esta skill

Skill experimental, en ajuste continuo. Antes de lanzar más de un agente (o de elegir cuál CLI usar
para uno), evalúa la situación con el marco de abajo y da una recomendación explícita: agente único,
o qué patrón multi-agente + qué CLI/modelo por rol.

**Fuentes externas que este archivo asume consistentes, pero no versiona ni puede verificar desde
acá**: `docs/trigger-rules.md` de [gentle-ai](https://github.com/Gentleman-Programming/gentle-ai)
(Paso 1), la skill `herdr` (`.claude/skills/herdr/SKILL.md`, Paso 4 — ver nota abajo) y las notas de
Phyume "Herdr" (Paso 4) y "Agent Harness Patterns" (Paso 3). Si algo de este archivo contradice lo que
se observa en vivo (banner de un CLI, `herdr --help`, etc.), confiar en lo observado y actualizar este
archivo — no al revés.

## Paso 0 — chequear Herdr (obligatorio, antes de cualquier otra cosa)

Correr `herdr status` **primero, siempre**, antes de evaluar nada más. Define qué opciones existen
para el resto del análisis:

- **`server.status: running`** → coordinación cruzando CLIs disponible (Codex, opencode, y una segunda
  instancia de Claude Code). Seguir con el marco completo, Paso 3 incluye las opciones.
- **Server caído, o `herdr` no existe como comando** → sin coordinación cruzando CLIs. Solo queda el
  mecanismo nativo de subagentes de Claude Code (Task/Agent tool), que corre subagentes del mismo
  modelo/proveedor. **Avisar esta limitación explícitamente** antes de recomendar nada — no asumir
  Herdr disponible ni proponer Codex/opencode como opción si el chequeo no confirmó que el server está
  corriendo. Model tiering (minion barato vía opencode) queda descartado en este caso.

**Regla dura: nunca iniciar el server de Herdr por cuenta propia.** Si `herdr status` muestra el
server caído, esa es la respuesta — no correr `herdr server ...` ni ningún comando que lo levante.
Arrancar un servidor en background es una decisión del usuario, no algo que esta skill dispare sola.
Reportar el estado caído y seguir con el fallback de subagentes nativos.

**Además del server, la sesión actual tiene que estar corriendo *dentro* de Herdr.** Que
`server.status: running` sea cierto no alcanza — hace falta que esta misma instancia de Claude Code
sea un agente reconocido por Herdr (lanzada como `herdr` o dentro de un pane que Herdr gestiona), si
no, no hay `workspace_id` propio desde el cual hacer `tab create`. **Desde v0.8.0 de Herdr, la forma
oficial y más simple de confirmar esto es un chequeo de variables de entorno** (documentado en `herdr
--skill`, probado en vivo — v0.37): `$HERDR_ENV` vale `1` dentro de un pane gestionado por Herdr, y
`$HERDR_WORKSPACE_ID`/`$HERDR_TAB_ID`/`$HERDR_PANE_ID` ya traen los IDs propios de esta sesión sin
necesidad de correr `agent list` y matchear `terminal_id` a mano.

```bash
test "${HERDR_ENV:-}" = 1   # si falla, no estamos dentro de un pane de Herdr
echo "$HERDR_WORKSPACE_ID" "$HERDR_TAB_ID" "$HERDR_PANE_ID"   # IDs propios, listos para usar en el Paso 4
```

Si `$HERDR_ENV` no está seteado (o vale distinto de `1`) aunque el server esté corriendo, tratarlo
igual que "Herdr no disponible" para efectos del Paso 3/4 — no se puede crear tabs nuevos sin un
workspace propio. `herdr agent list` sigue siendo útil para inspeccionar qué más hay corriendo, pero ya
no hace falta para confirmar la propia identidad de la sesión.

Este chequeo no es opcional. Corre siempre, incluso si el Paso 1 termina resolviendo Direct inline y
el resultado no se llega a usar: es un solo comando (`herdr status`), más barato que descubrir recién
en el Paso 4 que Herdr no estaba disponible.

## Paso 1 — elegir ruta (alineado a `trigger-rules.md` de gentle-ai)

Clasificar la tarea en una de tres rutas, de menor a mayor delegación — **usar siempre la más liviana
que la situación realmente requiera**, no saltar a una más pesada porque "está disponible":

**Antes de clasificar por conteo de archivos: chequear la *lista de riesgo* del Paso 2.** Si el
archivo/cambio toca algo de esa lista, el conteo de archivos no manda — nunca es Direct inline
automático, sin importar que sea 1 solo archivo. Como mínimo, tratarlo como Delegated direct con
confirmación explícita del usuario antes de aplicar nada; si además es una decisión irreversible,
evaluar directamente la pregunta 2 del Paso 2. Esto cierra el hueco de que un cambio chico pero
peligroso (un script de deploy, un archivo de permisos, algo de auth) se cuele como Direct inline solo
por tocar 1-3 archivos.

1. **Direct inline** — entender o verificar el cambio requiere **1-3 archivos**, o es un cambio
   mecánico ya entendido, sin investigación ni decisión de diseño pendiente, **y no toca nada de la
   lista de riesgo**. → seguir en la sesión actual, no lanzar nada.
2. **Delegated direct** — entender requiere **4+ archivos**, la lectura prepara una escritura, hace
   falta investigación amplia, o un writer va a tocar **2+ archivos no triviales**. → delegar esa
   exploración o escritura puntual a **un** subagente (nativo de Claude Code, o vía Herdr si el rol lo
   justifica) — todavía sin armar un patrón multi-agente.
3. **Multi-agente con patrón** — alguna pregunta del Paso 2 da sí. → una sola delegación no alcanza;
   hace falta el patrón específico del Paso 3.

El conteo de archivos describe el contexto que necesita la acción *actual*, no un score de riesgo — el
riesgo puede justificar escalar a la ruta 3, pero nunca fuerza una ruta más pesada si el contexto real
sigue siendo chico.

## Paso 2 — cuándo escalar de Delegated direct a un patrón multi-agente (ruta 3)

Estas preguntas **no son mutuamente excluyentes** — más de una puede dar sí a la vez para la misma
tarea. Si eso pasa, combinar los patrones correspondientes del Paso 3 (ej. orquestador que además usa
model tiering para sus ejecutores). Si hay tensión real entre qué patrón aplicar primero, priorizar
**2 y 3 (verificación/riesgo) por sobre 1 y 4 (organización/costo)** — un hallazgo de seguridad importa
más que ahorrar en modelo.

1. ¿La tarea tiene varias fases/dominios **genuinamente independientes** que requieren más de una
   delegación coordinada por un líder — no un solo tramo de trabajo repetitivo (eso es la pregunta 4,
   no esta)?
2. ¿Toca algo de la lista de riesgo (ver abajo), o es una decisión irreversible (borrado, migración,
   secreto/credencial, lanzar algo a producción) — al punto de necesitar una segunda opinión que no vea
   el output del primero?
3. ¿Hay más de una dimensión de falla relevante *a la vez* (seguridad, legibilidad, cobertura de tests,
   resiliencia) que un solo pase de revisión no cubre bien — a diferencia de la pregunta 2, acá no se
   busca una segunda opinión sobre lo mismo, sino cobertura de ángulos distintos?
4. ¿Una parte del trabajo es mecánica/repetitiva **y separable** (se puede mandar a ejecutar sola, sin
   que dependa de razonamiento de frontier model) — no solo "hay algo repetitivo en el medio de una
   tarea que de todos modos hay que pensar entera"?
5. ¿La sesión actual ya viene larga y arriesga compactación (pérdida silenciosa de reglas dadas al
   inicio) si se sigue acumulando contexto ahí mismo?

**Criterios objetivos** (para no dejar 2/3/4 a interpretación libre):
- *"Archivo no trivial"* (preguntas de delegación en Paso 1 y aquí): cambia lógica o agrega/quita un
  flujo, no solo texto/formato/rename.
- *Lista de riesgo* para la pregunta 2 (y para el chequeo previo del Paso 1): rutas tipo `~/.ssh/*`,
  `*.pem`, `*.key`, `.env*`, `~/.aws/credentials`, `~/.config/gh/hosts.yml`; configuración de CI/CD
  (`.github/workflows/*`, `.gitlab-ci.yml`, `Jenkinsfile`); infraestructura como código (Terraform,
  manifiestos de Kubernetes, `Dockerfile`/`docker-compose` de producción); migraciones de base de
  datos; cualquier archivo de configuración de producción/deploy; o auth/pagos/borrado masivo de
  datos. Fuera de esa lista, tratar la pregunta 2 como "no" salvo justificación explícita.
  **Aclaración sobre "auth"**: se refiere a tocar credenciales/infraestructura de auth *real* fuera de
  una feature ya planificada — no a escribir el código de una feature de auth que ya tiene `tasks.md`
  aprobado (leído literal, forzaría re-confirmar tarea por tarea una feature entera, contradiciendo
  correr `sdd-implement` sobre un plan ya aprobado).
- **Esta lista es puro criterio de prompt, sin respaldo técnico** — probado en vivo con Codex
  (`-s workspace-write`): el sandbox protege *integridad* (no puede escribir fuera del proyecto) pero
  no *confidencialidad* (leer un archivo fuera del proyecto sí funciona), y dentro del proyecto no
  restringe nada. Solo funciona si el CLI lanzado respeta el prompt — nada lo obliga técnicamente.

Si ninguna da sí → **Delegated direct alcanza** (ruta 2 del Paso 1), no hace falta patrón multi-agente.

## Paso 3 — mapeo pregunta → patrón

| Si la respuesta a... | ...es sí, usar | Roles |
|---|---|---|
| 1 | Orquestador + subagentes especializados | 1 líder (frontier) + N ejecutores |
| 2 | Blind dual-judge (jueces ciegos) | 2-3 evaluadores independientes, mismo criterio, sin verse entre sí |
| 3 | Lentes paralelas (framework 4R: Risk/Readability/Reliability/Resilience) | N evaluadores, cada uno con un criterio distinto |
| 4 | Model tiering | Orquestador en modelo potente, ejecución mecánica en modelo barato (opencode/DeepSeek V4 Flash Free — ver tabla del Paso 4). Fallback si Herdr no está activo: ver Paso 4 |
| 5 | Aislamiento de contexto (subagente en fresh context) | Subagente nuevo, sin arrastrar el historial de la sesión actual |

**Cómo operacionalizar Blind dual-judge (patrón 2) para que sea realmente ciego** (CLI/modelo de cada
juez: ver tabla del Paso 4):

1. La instancia que corre esta skill (Claude Code) es el **orquestador/fix-agent** — nunca uno de los
   jueces. Si el objetivo a revisar lo escribió/editó esta misma sesión, un juez tiene que ser un CLI
   distinto para que la revisión sea independiente del autor.
2. Lanzar los `tab create` + `agent start --kind --pane` de **ambos** jueces antes de leer la respuesta
   de ninguno — no esperar a que termine el primero para lanzar el segundo (eso ya rompe el "sin verse
   entre sí" si el prompt del segundo se arma citando algo del primero).
3. Mandar el **mismo prompt, palabra por palabra**, a los dos (`agent prompt <target> "..." --wait`).
4. Leer ambas respuestas recién cuando las dos terminaron (`agent prompt --wait` ya espera el estado
   asentado de cada pane, con timeout — ver Paso 6). Nunca pegarle a un juez la respuesta del otro, ni
   resumírsela.
5. El orquestador filtra qué hallazgos son válidos (convergentes = más confianza; únicos = evaluar caso
   por caso) y aplica la corrección — un intento, no un loop de generación (ver *Surgical single-attempt
   correction* en Agent Harness Patterns).
6. **Si un juez nunca responde (timeout o falla)**: "convergentes vs únicos" deja de tener sentido con
   una sola respuesta — no fingir que hubo consenso. Reportarlo explícitamente como "una sola opinión,
   no blind dual-judge completo" y decidir con el usuario si alcanza así o si vale relanzar ese juez
   (ver Paso 6, degradación con resultados parciales).

## Paso 4 — qué CLI/modelo usar por rol

Solo aplica si el Paso 0 confirmó Herdr activo. La skill `herdr` (`.claude/skills/herdr/SKILL.md`, en
este mismo repo) es una copia verbatim de `herdr --skill` y la referencia autoritativa de sintaxis —
`metadata.captured_from_herdr_version` en su frontmatter dice contra qué versión se generó, pero el
archivo no se auto-actualiza. Si algo de acá no calza con lo que hace Herdr en vivo, o el
`herdr status` del Paso 0 muestra una versión distinta a la de ese metadata, correr
`.claude/skills/herdr/regenerate.sh` (regenera el archivo capturando `herdr --skill` y `herdr
--version` en vivo, no a mano) antes de asumir que el archivo local está mal, y actualizar este
archivo si contradice lo observado en vivo.

**Glosario rápido**: *pane* = una terminal individual; *pane root* = el pane a pantalla completa que ya
trae un tab apenas se crea; *alt-screen TUI* = interfaz que redibuja toda la pantalla en vez de hacer
scroll normal — leer con `--source visible`, no `recent` (puede venir vacío/desactualizado en estas
interfaces).

**Secuencia de lanzamiento — un tab nuevo por agente, nunca un split** (decisión de diseño: el skill
oficial de Herdr recomienda por default split en el tab actual, se evaluó explícitamente y se mantiene
esta convención — ver `TODO.md`/`CHANGELOG.md` v0.38 antes de "corregir" esto sin saber que fue a
propósito):

```bash
herdr tab create --workspace <ws_id> --label <nombre-agente> --no-focus
# .result.root_pane.pane_id → pane a pantalla completa, en su indicador de shell interactivo
herdr agent start <nombre-agente> --kind <claude|codex|opencode|agy|...> --pane <pane_id> -- <args nativos del CLI>
```

`agent start` bloquea hasta detectar el agente en ese pane (default 30s, `--timeout` 3000-300000ms) y
el nombre pasado como primer argumento queda como alias direccionable de inmediato. `herdr agent` (sin
subcomando) lista los `--kind` instalados. El pane objetivo tiene que estar en su indicador de shell
interactivo — Herdr nunca crea, divide ni mueve layout por sí solo, por eso `tab create` va primero.

**Que `agent start` devuelva no significa "listo para la tarea real"** — solo que Herdr reconoció algún
estado (`idle`, `working`, o `blocked`). Revisar siempre `.result.agent.agent_status`: si da `blocked`
(hook de confirmación de Codex, trust-prompt, o el prompt nativo de confirmación de Claude Code —
`Enter to confirm · Esc to cancel`, que hasta Herdr 0.8.1 se reportaba por error como `idle`, corregido
en 0.8.2 — relevante para Claude#2 como juez, ver tabla más abajo), resolverlo con `agent send-keys`
antes de seguir.

`agent rename <target> <name>` crea un alias direccionable de verdad (usable después como `<target>`
en cualquier `herdr agent ...`); `pane rename`/`tab rename` solo cambian una etiqueta visual — probado
que **no** sirven para direccionar (`get` por ese label da `not_found`). Usar `agent rename` para
scripting, los otros dos solo para legibilidad humana al revisar la sesión.

`herdr notification show` no es utilizable en este entorno — probado en vivo, devuelve
`{"shown": false, "reason": "disabled"}` sin ningún toggle en `config.toml` que lo explique (más
probable: permiso de notificaciones del SO sin otorgar a Herdr). No depender de esto para avisar al
usuario de un agente bloqueado.

**Mandar el prompt real — un solo comando, tipea + somete + espera:**

```bash
herdr agent prompt <nombre-agente> "<texto de la tarea>" --wait --timeout <ms>
```

Default de espera: primer estado asentado (`idle`/`done`/`blocked`, no hace falta `--until`). Si no hay
cambio de ciclo de vida en 5s desde un estado no-`working`, devuelve `agent_prompt_stalled` en vez de
colgarse — señal de que el prompt no se sometió de verdad. Al lanzar varios agentes en paralelo,
disparar `agent prompt --wait` a **todos** antes de esperar la respuesta de cualquiera (mismo criterio
que Blind dual-judge, punto 2 del Paso 3 más arriba).

Para interactuar con la UI de un agente ya corriendo (aprobar confirmaciones, cancelar) usar `herdr
agent send-keys <target> <tecla>` (`esc`, `enter`, `ctrl+c`) — Herdr valida la tecla y rechaza si el
agente ya no controla el pane, más seguro que `pane run`/`pane send-keys` a ciegas. Esos comandos de
`pane` siguen siendo la superficie correcta para procesos ordinarios no-agente (tests, builds). Desde
Herdr 0.8.2, `send-keys ... shift+tab` preserva el Shift al enviarse (antes se perdía) — sirve para
ciclar el modo de permisos de un agente (ej. Claude Code) por comando, sin intervención manual.

**Polling y espera de estado.** El campo `revision` de `agent get`/`pane get` **no sirve** para
detectar cambios de pane (confirmado en vivo: se mantiene igual mientras el contenido del pane cambia)
— no usarlo para polling manual. En su lugar: `herdr agent wait <target> [--until <estado>] [--timeout
MS]` (bloqueante por transición de estado; sin `--until` usa el mismo default que `agent prompt
--wait`) o `herdr pane wait-output <pane_id> --match <texto> [--regex] [--timeout MS]` (bloqueante por
contenido del pane — necesario si algún CLI del roster no tiene detección de estado confiable; sin
`--timeout` espera indefinidamente). `herdr agent explain <target> [--json]` muestra qué regla disparó un
`agent_status` (o si cayó a un fallback) — más rápido que especular.

**Gotcha de shell (no de Herdr)**: en zsh, `status` es variable read-only (alias de `$?`) — usar otro
nombre (`agent_status`, `estado`) en scripts de polling propios.

**Guardrails de seguridad al lanzar agentes con capacidad de escritura:**

- **Por defecto, tareas de lectura/revisión** (jueces, lentes, exploración) — no de escritura. Si el
  rol específico requiere que el CLI lanzado *modifique* archivos o ejecute comandos (no solo lea y
  reporte), eso es una decisión aparte que requiere **confirmación explícita del usuario antes de
  lanzarlo**, igual que cualquier otra acción de escritura fuera de esta skill — no asumir permiso
  implícito solo porque el patrón multi-agente ya fue aprobado.
- **Nunca dejar que un agente lanzado corra comandos destructivos o de producción sin supervisión**
  (deploys, migraciones, borrados masivos, cambios de infraestructura) — eso siempre pasa por el mismo
  chequeo de confirmación humana que tendría si lo hiciera esta sesión directamente, sin atajos por
  estar "delegado" a otro CLI.
- **No pegar secretos ni credenciales en los prompts** que se mandan a los CLIs — si la tarea necesita
  referenciar un archivo sensible (de la lista de riesgo del Paso 2), describirlo por ruta/nombre, no
  copiar su contenido. Mandar el mismo contexto a 2-4 CLIs distintos (blind dual-judge, lentes 4R)
  multiplica la superficie de exposición si el prompt incluye datos sensibles. Probado en vivo con un
  secreto de mentira: con la config default de Herdr no queda expuesto en ningún archivo persistente
  (`herdr-server.log`, `herdr-client.log`, `session.json`) — pero si alguna vez se activa
  `[experimental] pane_history` (off por defecto), el contenido de los panes, secretos incluidos, queda
  en texto plano en `session-history.json`. No activar esa opción con agentes de esta skill corriendo.
- **Una corrección que toca algo de la lista de riesgo no se aplica solo con el visto bueno del
  orquestador** (aunque venga de blind dual-judge o de cualquier patrón de verificación) — confirmar
  con el usuario antes de aplicarla. Verificación adversarial reduce el riesgo de un error lógico, pero
  no es una autorización de seguridad.
- **Dos o más agentes con capacidad de escritura en paralelo sobre el mismo repo → aislar cada uno en
  su propio `herdr worktree`, no lanzarlos directo sobre el mismo checkout.** Confirmado en vivo (v0.35,
  `herdr worktree create --workspace ID --branch NAME --label TEXT`): crea un worktree de git real (no
  simulado — visible con `git worktree list` desde el repo principal) en una workspace nueva de Herdr con
  su propio tab/pane, en una rama propia. Probada la aislación en ambos sentidos: un archivo escrito
  dentro del worktree no aparece en el `git status` del repo principal, y cambios sin commitear del repo
  principal no se filtran al worktree. `herdr worktree remove --workspace ID` se niega por defecto si
  queda algo sin commitear (`dirty_worktree_requires_force`, hay que pasar `--force`) — buen guardrail
  para no perder trabajo del agente al limpiar. Sin esto, 2+ agentes escribiendo sobre el mismo checkout
  compiten por los mismos archivos sin ningún guardrail técnico — solo confirmación humana, que no
  resuelve el conflicto de merge.

**Memoria compartida (Engram) — exclusiva del orquestador, no registrada en los CLIs lanzados
(decisión v0.29, revierte el diseño de v0.15-v0.28).** Ningún CLI externo (Codex/opencode/Agy) tiene a
Engram como MCP — el orquestador hace `mem_search` antes de delegar y pasa el contexto directo en el
prompt (modelo "push"), no "pull". Por qué: el beneficio de que cada CLI buscara memoria por su cuenta
era marginal (el orquestador ya busca antes de delegar) frente al costo de mantener seguro ese acceso.
Historial del diseño anterior (wrapper por `PATH`, agentes custom `safe-reviewer` de Codex/opencode) en
`CHANGELOG.md` v0.15-v0.28 — sigue en el filesystem, dormido, por si se revierte la decisión.

**Roster de CLI restringido por proyecto**: antes de asumir las 4 opciones de la tabla, chequear si el
proyecto fija un roster más chico en `.specify/memory/constitution.md` o `CLAUDE.md`. Sin eso, usar la
tabla completa. Restricción verbal puntual del usuario aplica solo a esa sesión, salvo que se persista
en uno de esos archivos — hoy no hay otro mecanismo para fijarla de forma duradera por proyecto.

**Modelos fijos por CLI** (decisión del usuario, usar siempre estos — no improvisar otro modelo):

| CLI | Modelo fijo | `--kind` + args nativos (después de `--`) | Rol por defecto |
|---|---|---|---|
| **Claude Code** | Sonnet 5 (default de la CLI, sin flag) | `--kind claude` (sin args nativos) | Por defecto, orquestador/líder (esta misma sesión) — no se lanza a sí mismo. También se puede **lanzar una segunda instancia** vía `agent start --kind claude` como ejecutor/segunda opinión de máxima confiabilidad (mismo mecanismo nativo que el orquestador, sin gotchas externos) — ver nota abajo sobre su límite de independencia como juez |
| **Codex** | gpt-5.6-luna · high | `--kind codex -- -m gpt-5.6-luna -c model_reasoning_effort="high" -s workspace-write` | Segunda opinión/ejecutor independiente. `-s workspace-write` limita su sandbox a escribir solo dentro del proyecto — guardrail de seguridad general, no específico de Engram (que ya no está registrado, ver más arriba). Al primer arranque puede pedir confirmación de hooks/trust (bloquea el pane hasta resolverlo — ver nota Codex más abajo) |
| **opencode** | DeepSeek V4 Flash Free | `--kind opencode -- -m opencode/deepseek-v4-flash-free` | Ejecutor independiente **y minion barato de model tiering** (patrón 4, Paso 3). **`agent wait`/`agent_status` sí son confiables** (corregido en v0.38, nota anterior desactualizada — ver nota debajo) |

Nota Claude#2 — **como juez, da independencia de proceso/contexto, no de modelo.** Una segunda
instancia de Claude Code corre en un contexto fresco (no ve el razonamiento de la sesión orquestadora),
pero comparte el mismo proveedor/modelo (Sonnet 5) que el autor si el autor también es esta sesión — no
tiene el mismo valor que Codex/opencode para blind dual-judge, donde la independencia buscada es
justamente de sesgos de modelo. Preferir Codex/opencode cuando la independencia de modelo importa;
reservar Claude#2 para roles donde alcanza con contexto fresco (ejecutor del patrón 1, aislamiento de
contexto del patrón 5) o cuando se necesita la confiabilidad de detección de estado por sobre todo.

**Agy (Antigravity) se sacó del roster activo (v0.40)** — decisión del usuario tras esta sesión de
pruebas en vivo: su `agent_status` nunca reflejó el estado real (fallback estático confirmado en 4
momentos distintos, incluso tras actualizar Herdr y sus manifiestos de detección), contaminando también
`agent_start`/`agent wait`. El hallazgo completo y el historial de investigación quedan en `TODO.md`/
`CHANGELOG.md` (v0.30-v0.39) por si se reconsidera en el futuro — no se borró nada de ahí, solo dejó de
ser parte del roster por defecto de esta tabla.

Nota opencode — **`agent_status` es confiable de verdad, autoridad de ciclo de vida real por hook**
(corregido en v0.38, la nota anterior estaba desactualizada). Confirmado en
`https://herdr.dev/docs/integrations/`: opencode está en el grupo "lifecycle authority" (con
Pi/OMP/Kimi/Kilo/MastraCode), a diferencia de Claude Code/Codex ("session identity", sin autoridad
real — aunque en la práctica su screen-manifest funciona bien igual). Probado en vivo: `agent explain` mostró `screen_detection_skip_reason:
full_lifecycle_hook_authority` y `agent_status` siguió correctamente `idle → working → idle` en
sincronía con el contenido real del pane. Único matiz: lag breve (<1s) entre someter el prompt y que el
hook reporte `working` por primera vez — no afecta a llamadas bloqueantes (`agent prompt --wait`/`agent
wait`), solo a un `agent get` suelto sin esperar justo después de someter.

Nota Codex — `~/.codex/config.toml` trae `model_reasoning_effort = "xhigh"` como default global — distinto
del `high` fijado acá. La invocación pasa **ambos** flags explícitos, `-m gpt-5.6-luna` y
`-c model_reasoning_effort="high"` — antes solo se fijaba el reasoning effort y el modelo base quedaba
a merced del config global (bug encontrado por revisión ciega con Codex mismo, ver changelog v0.7).
Chequear el banner al lanzarlo (`gpt-5.6-luna high`) para confirmar que ambos se aplicaron.

Si Herdr no está activo (ver Paso 0): usar subagentes nativos de Claude Code (Sonnet 5) para los
patrones del Paso 3 que no dependan de cruzar proveedores (1, 2, 3, 5 sirven igual con subagentes
nativos). El patrón 4 (model tiering) **no tiene minion barato sin Herdr** — no queda "sin resolver":
degrada explícitamente a Delegated direct (Paso 1, ruta 2) con subagente nativo, sin el ahorro de
costo pero sin bloquear la tarea.

**Para cualquier rol de solo lectura/revisión con subagente nativo (jueces, lentes 4R, minion de model
tiering), usar el agente custom `safe-reviewer`** (`.claude/agents/safe-reviewer.md`) en vez de
`general-purpose` — bloquea `Bash`/`Edit`/`Write`/`NotebookEdit` y los tools de escritura de Engram vía
`disallowedTools`, la única forma real de restringir un subagente nativo (no hereda
`permissions.deny` de `settings.json` — limitación conocida de Claude Code,
`anthropics/claude-code#25000`). Excluye `Bash` a propósito, no solo tools MCP: con Bash disponible se
podría invocar el binario real de `engram` directo. Si el rol necesita correr comandos (tests,
linters), no usar `safe-reviewer` — usar `general-purpose` con el guardrail de texto como mitigación
parcial. Verificado en vivo: `mem_save`/`Bash` no aparecen en la lista de tools de `safe-reviewer`, ni
siquiera diferidas (`mem_search` sí, bloqueo selectivo). Alcance: solo cubre subagentes nativos (Task
tool); los CLIs externos vía Herdr no leen `.claude/agents/`, son superficies distintas.

## Paso 5 — output esperado

Al aplicar esta skill, decir explícitamente:
1. Resultado del chequeo de Herdr (Paso 0) y qué opciones quedan habilitadas.
2. Ruta elegida en el Paso 1 (Direct inline / Delegated direct / Multi-agente con patrón) y por qué.
3. Si es ruta 3: qué pregunta del Paso 2 la activó, qué patrón y cuántos roles.
4. **Solo si la ruta es 2 o 3 y hay un CLI externo involucrado**: qué CLI/modelo para cada rol, con la
   razón. Si es ruta 1 (Direct inline, nada que lanzar) o ruta 2 con subagente nativo (sin CLI externo,
   sin modelo fijo que reportar), omitir este punto en vez de forzarlo — no hay "para cada rol" que
   completar cuando no hay roles múltiples.
5. **Si hubo degradación** (ver Paso 6): decirlo explícitamente — qué rol faltó y qué garantía del
   patrón se perdió. Nunca reportar un patrón multi-agente como completo si no lo está.

## Paso 6 — fallos a mitad de camino

Regla general: **nunca esperar indefinidamente, nunca dejar tabs huérfanos, nunca fingir que un
patrón se completó si no se completó.**

1. **Timeout explícito por rol.** Todo `agent prompt --wait`/`agent wait` lleva `--timeout` (60-120s
   para un prompt normal, más para tareas de razonamiento largas) — nunca un wait sin límite. Si se cumple el
   timeout, no seguir esperando ese pane a ciegas: pasar directo al punto 3 (degradación).
   **Excepción confirmada en earpi (v0.33)**: si la tarea le pide al ejecutor correr comandos como
   parte de verificar su propio trabajo (`bun test`, build, lint), 180s no alcanzó con Codex casi
   terminado — ese tiempo se suma al de razonamiento, no lo reemplaza. Para este tipo de tarea usar
   300-600s, o preferir `herdr pane wait-output <target> --match <texto-de-fin-esperado>` en vez de un
   solo wait largo por `agent_status` — permite chequear progreso real en vez de esperar a ciegas hasta
   el límite.
2. **Herdr puede caer a mitad de un patrón** (entre `tab create` y `agent start`/`agent prompt`, o con
   agentes ya corriendo). No hay una señal proactiva de esto — se detecta porque el siguiente comando de Herdr
   falla o no responde. Ante cualquier comando de Herdr que falle a mitad de un patrón, volver a correr
   `herdr status` para confirmar si el server sigue vivo antes de asumir cualquier otra cosa.
3. **Degradación con resultados parciales**: si algunos roles respondieron y otros no (timeout, Herdr
   caído, pane que nunca arrancó), seguir con lo que sí se obtuvo — pero decirlo explícitamente en el
   Paso 5: qué rol falta y qué garantía del patrón se perdió (blind dual-judge con 1 juez es una sola
   opinión, no consenso; lentes 4R con 3 de 4 lentes cubre 3 dimensiones, no las 4). Nunca reportar el
   patrón como completo si no lo está.
4. **Limpieza de tabs**: si un patrón se aborta o degrada a mitad de camino, cerrar con
   `herdr tab close <tab_id>` los tabs que se llegaron a crear, incluidos los que nunca arrancaron bien
   — no dejar tabs huérfanos corriendo en el workspace del usuario.
5. **El intento único de corrección (Surgical single-attempt correction) también puede fallar**: si la
   corrección aplicada no resuelve el problema, no reintentar en loop — reportarlo al usuario como
   hallazgo sin resolver, no como error a forzar hasta que funcione.

## Estado y ajustes

Historial completo de versiones en `CHANGELOG.md`, en este mismo directorio de la skill — no se carga
acá para no inflar el archivo que se lee en cada invocación. `TODO.md` queda como registro de método y
hallazgos por ronda — revisar ahí el estado de pendientes activos en vez de asumirlo desde acá.
