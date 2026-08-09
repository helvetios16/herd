---
name: agent-selection
description: >
  Evalúa una situación de trabajo y recomienda si conviene usar un solo agente o varios coordinados,
  qué patrón de orquestación aplica, y qué CLI/modelo asignar a cada rol. Trigger: antes de delegar
  una tarea a un agente, cuando se duda si vale la pena coordinar múltiples agentes (vía Herdr u otro
  mecanismo), o al elegir qué CLI/modelo usar para un subagente.
metadata:
  status: experimental
  version: "0.34"
---

## Qué hace esta skill

Skill experimental, en ajuste continuo. Antes de lanzar más de un agente (o de elegir cuál CLI usar
para uno), evalúa la situación con el marco de abajo y da una recomendación explícita: agente único,
o qué patrón multi-agente + qué CLI/modelo por rol.

**Fuentes externas que este archivo asume consistentes, pero no versiona ni puede verificar desde
acá**: `docs/trigger-rules.md` de [gentle-ai](https://github.com/Gentleman-Programming/gentle-ai)
(Paso 1), y las notas de Phyume "Herdr" (Paso 4) y "Agent Harness Patterns" (Paso 3). Si algo de este
archivo contradice lo que se observa en vivo (banner de un CLI, `herdr --help`, etc.), confiar en lo
observado y actualizar este archivo — no al revés.

## Paso 0 — chequear Herdr (obligatorio, antes de cualquier otra cosa)

Correr `herdr status` **primero, siempre**, antes de evaluar nada más. Define qué opciones existen
para el resto del análisis:

- **`server.status: running`** → coordinación cruzando CLIs disponible (Claude Code, Codex, opencode,
  Agy). Seguir con el marco completo, Paso 3 incluye las cuatro opciones.
- **Server caído, o `herdr` no existe como comando** → sin coordinación cruzando CLIs. Solo queda el
  mecanismo nativo de subagentes de Claude Code (Task/Agent tool), que corre subagentes del mismo
  modelo/proveedor. **Avisar esta limitación explícitamente** antes de recomendar nada — no asumir
  Herdr disponible ni proponer Codex/opencode/Agy como opción si el chequeo no confirmó que el server
  está corriendo. Model tiering con Agy/Gemini queda descartado en este caso.

**Regla dura: nunca iniciar el server de Herdr por cuenta propia.** Si `herdr status` muestra el
server caído, esa es la respuesta — no correr `herdr server ...` ni ningún comando que lo levante.
Arrancar un servidor en background es una decisión del usuario, no algo que esta skill dispare sola.
Reportar el estado caído y seguir con el fallback de subagentes nativos.

**Además del server, la sesión actual tiene que estar corriendo *dentro* de Herdr.** Que
`server.status: running` sea cierto no alcanza — hace falta que esta misma instancia de Claude Code
sea un agente reconocido por Herdr (lanzada como `herdr` o dentro de un pane que Herdr gestiona), si
no, no hay `workspace_id` propio desde el cual hacer `tab create`. Confirmar con
`herdr agent list` y verificar que aparezca esta sesión (mismo `terminal_id`/pane donde se está
corriendo). Si el server está activo pero esta sesión no aparece ahí, tratarlo igual que "Herdr no
disponible" para efectos del Paso 3/4 — no se puede crear tabs nuevos sin un workspace propio.

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
  **Aclaración sobre "auth" (v0.33)**: esto se refiere a tocar credenciales/infraestructura de auth
  *real* fuera de una feature ya planificada — no a escribir el código de una feature de auth que ya
  pasó por `speckit-plan`/`speckit-tasks` y tiene un `tasks.md` aprobado. Leído literal, la lista
  forzaría re-confirmar tarea por tarea una feature entera de auth (ej. `001-auth-minima`), lo cual
  contradice correr `sdd-implement` sobre un `tasks.md` ya aprobado — no es el uso que se busca.
- **Esta lista es puro criterio de prompt, sin respaldo técnico — probado en vivo con Codex
  (`-s workspace-write`).** El sandbox del CLI protege *integridad* (no puede escribir fuera del
  proyecto: `operation not permitted` confirmado contra un archivo señuelo en `~/.ssh/`) pero **no
  confidencialidad** (leer un archivo fuera del proyecto — el mismo señuelo — dio éxito, código 0). Y
  dentro del proyecto (ej. un `.env` del propio repo) el sandbox no restringe nada, ni lectura ni
  escritura. Esta lista solo funciona si el CLI lanzado respeta el prompt — no hay ningún mecanismo que
  se lo impida técnicamente si decide ignorarlo.

Si ninguna da sí → **Delegated direct alcanza** (ruta 2 del Paso 1), no hace falta patrón multi-agente.

## Paso 3 — mapeo pregunta → patrón

| Si la respuesta a... | ...es sí, usar | Roles |
|---|---|---|
| 1 | Orquestador + subagentes especializados | 1 líder (frontier) + N ejecutores |
| 2 | Blind dual-judge (jueces ciegos) | 2-3 evaluadores independientes, mismo criterio, sin verse entre sí |
| 3 | Lentes paralelas (framework 4R: Risk/Readability/Reliability/Resilience) | N evaluadores, cada uno con un criterio distinto |
| 4 | Model tiering | Orquestador en modelo potente, ejecución mecánica en modelo barato. Fallback si Herdr no está activo: ver Paso 4 |
| 5 | Aislamiento de contexto (subagente en fresh context) | Subagente nuevo, sin arrastrar el historial de la sesión actual |

**Cómo operacionalizar Blind dual-judge (patrón 2) para que sea realmente ciego** (CLI/modelo de cada
juez: ver tabla del Paso 4):

1. La instancia que corre esta skill (Claude Code) es el **orquestador/fix-agent** — nunca uno de los
   jueces. Si el objetivo a revisar lo escribió/editó esta misma sesión, un juez tiene que ser un CLI
   distinto para que la revisión sea independiente del autor.
2. Lanzar los `tab create` + `pane run` de **ambos** jueces antes de leer la respuesta de ninguno —
   no esperar a que termine el primero para lanzar el segundo (eso ya rompe el "sin verse entre sí" si
   el prompt del segundo se arma citando algo del primero).
3. Mandar el **mismo prompt, palabra por palabra**, a los dos.
4. Leer ambas respuestas recién cuando las dos terminaron (`agent wait --status idle` en cada pane,
   con timeout — ver Paso 6). Nunca pegarle a un juez la respuesta del otro, ni resumírsela.
5. El orquestador filtra qué hallazgos son válidos (convergentes = más confianza; únicos = evaluar caso
   por caso) y aplica la corrección — un intento, no un loop de generación (ver *Surgical single-attempt
   correction* en Agent Harness Patterns).
6. **Si un juez nunca responde (timeout o falla)**: "convergentes vs únicos" deja de tener sentido con
   una sola respuesta — no fingir que hubo consenso. Reportarlo explícitamente como "una sola opinión,
   no blind dual-judge completo" y decidir con el usuario si alcanza así o si vale relanzar ese juez
   (ver Paso 6, degradación con resultados parciales).

## Paso 4 — qué CLI/modelo usar por rol

Solo aplica si el Paso 0 confirmó Herdr activo. Coordinable por CLI (`herdr tab create` →
`herdr pane run` → `herdr agent wait`/`agent read` — ver detalles y gotchas en la nota de Phyume
"Herdr").

**Glosario rápido** (términos de Herdr/terminal usados abajo): *pane* = una terminal individual;
*pane root* = el pane a pantalla completa que ya trae un tab apenas se crea, sin necesidad de split;
*alt-screen TUI* = una interfaz que redibuja toda la pantalla en vez de hacer scroll normal (Agy,
algunos CLIs) — por eso a veces hace falta leer con `--source visible` (lo que se ve ahora en
pantalla) en vez de `--source recent` (historial de scroll, que en estas interfaces puede venir vacío
o desactualizado).

**Secuencia exacta de lanzamiento — un tab nuevo por agente, nunca un split:**

```bash
herdr tab create --workspace <ws_id> --label <nombre-agente> --no-focus
# devuelve el pane_id del pane root del tab nuevo (ej. w9:p3) — un tab SIEMPRE trae
# su propio pane a pantalla completa desde que se crea
herdr pane run <pane_id_devuelto> "<comando del CLI, ej. claude>"
# esperar unos segundos y VERIFICAR arranque real antes de mandar el prompt de la tarea —
# ver "Verificar arranque real" abajo, y qué hacer si falla en el Paso 6.
```

El agente se lanza **en el pane root que ya trae el tab nuevo** — nunca crear un pane adicional con
`herdr pane split` para esto. `pane split` es solo para cuando hacen falta 2+ panes visibles
*simultáneamente dentro del mismo tab*, que no es el caso al lanzar un agente nuevo.

**Verificar arranque real antes de esperar** (no asumir que "lanzado" = "listo"): tras `pane run`,
leer el pane (`agent read <pane_id> --source visible`) y confirmar que muestra el banner esperado del
CLI — no un prompt de confirmación bloqueante (hooks de Codex, boot todavía en curso de Agy). Un pane
bloqueado en una pantalla de confirmación es indistinguible de uno "pensando" para `agent wait`, y
puede no reportar `idle` nunca. Si no aparece el banner esperado en ~10-15s, resolver el bloqueo (ver
gotchas por CLI en la tabla) antes de mandar el prompt real y antes de entrar a esperar — nunca mandar
el prompt a ciegas justo después de `pane run`.

**Mandar el prompt real de la tarea una vez verificado el arranque — usar `pane run`, no `agent
send`.** Confirmado en vivo (`herdr agent --help`): `agent send <target> <text>` **solo tipea texto,
no presiona Enter** — el prompt queda pegado en el input box del CLI sin someterse, indistinguible de
"trabajando" hasta que se revisa el pane. `pane run <target> "<texto>"` sí tipea y presiona Enter. Si
el prompt ya se mandó por error con `agent send` y quedó sin enviar, `pane run <target> ""` (texto
vacío) alcanza para someter lo que ya está tipeado, sin re-tipear nada. Al lanzar varios agentes en
paralelo, mandar el `pane run` del prompt real a **todos** antes de leer la respuesta de cualquiera
(mismo criterio que Blind dual-judge, punto 2 más abajo).

**El campo `revision` no sirve para detectar cambios de pane — confirmado en vivo (v0.33).** Es
tentador usar `revision` de `herdr agent get`/`agent list`/`pane get` para hacer polling manual ("leer
de nuevo cuando suba"), pero se probó en vivo (`pane get` repetido cada pocos segundos sobre un pane
activo, con el spinner del terminal visiblemente cambiando entre lecturas) y **`revision` se mantuvo
exactamente igual** mientras el contenido del pane sí cambiaba — no trackea redibujados/actualizaciones
de contenido. Para polling real, usar en cambio:
`herdr wait agent-status <target> --status <idle|working|blocked|done|unknown> [--timeout MS]`
(bloqueante, para esperar una transición de estado) o
`herdr wait output <pane_id> --match <texto> [--timeout MS] [--regex]` (bloqueante, para esperar que
aparezca un texto específico en el pane — útil cuando `agent_status` no es confiable, como con
opencode, ver tabla más abajo). Si hace falta polling manual no bloqueante, comparar el `agent_status`
reportado entre lecturas, no `revision`.

**Gotcha de shell, no de Herdr (v0.33)**: si se escribe un script propio de polling en zsh, no usar
`status` como nombre de variable — es una variable especial de solo lectura en zsh (alias de `$?`),
asignarla falla con `read-only variable: status` (confirmado en vivo). Usar otro nombre (`agent_status`,
`estado`, etc.).

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

**Memoria compartida (Engram) — exclusiva del orquestador, no registrada en los CLIs lanzados:**

**Decisión (v0.29, revierte el diseño de v0.15-v0.28)**: Engram NO se registra como servidor MCP en
ningún CLI lanzado vía Herdr (Codex/opencode/Agy). El orquestador (esta sesión) es el único punto de
contacto con Engram — hace `mem_search` antes de lanzar cualquier rol y pasa el contexto relevante
directo en el prompt (modelo "push"), en vez de darle a cada CLI lanzado su propia conexión MCP para
buscar por su cuenta (modelo "pull").

**Por qué**: el beneficio de que un CLI lanzado pudiera buscar memoria por su cuenta (evitar
redescubrir contexto) era marginal — el orquestador ya hace esa búsqueda antes de delegar cualquier
rol — y ese único beneficio había generado una ronda entera de trabajo de seguridad (wrapper por
`PATH`, verificación de sandbox por CLI, agentes custom de Codex/opencode) para defender un acceso que
no hacía falta dar en primer lugar. Sacarlo de raíz es más simple que seguir defendiéndolo.

Historial completo del diseño anterior (wrapper, hallazgos de bypass por CLI, agentes custom
`safe-reviewer` de Codex/opencode) en `CHANGELOG.md` v0.15-v0.28 — no se borró nada de eso, solo se
dejó de usar. El wrapper (`~/.local/share/agent-selection/restricted-bin/engram`) y los agentes custom
(`.codex/agents/safe-reviewer.toml`, `.opencode/agents/safe-reviewer.md`) quedan en el filesystem,
dormidos, por si en algún momento se decide volver a registrar Engram en algún CLI.

**Roster de CLI restringido a nivel proyecto (v0.33)**: antes de asumir que las cuatro opciones de la
tabla de abajo están disponibles, chequear si el proyecto actual fija un roster más chico —
`.specify/memory/constitution.md` (si el proyecto usa Spec Kit) o `CLAUDE.md` en la raíz del repo son
los lugares naturales para esa restricción, igual que cualquier otra decisión de stack técnico del
proyecto. Si ninguno de los dos dice nada, usar la tabla completa por default. Si el usuario restringe
el roster verbalmente en una sesión puntual (ej. "solo opencode y codex para esto"), aplicarlo para esa
sesión y sugerir persistirlo en uno de esos archivos si es una restricción que se espera repetir —
hoy no hay otro mecanismo para fijarlo de forma duradera por proyecto.

**Modelos fijos por CLI** (decisión del usuario, usar siempre estos — no improvisar otro modelo):

| CLI | Modelo fijo | Invocación vía `pane run` | Rol por defecto |
|---|---|---|---|
| **Claude Code** | Sonnet 5 (default de la CLI, sin flag) | `claude` | Orquestador/líder — mejor detección de estado (`agent wait --status idle` confiable) |
| **Codex** | gpt-5.6-luna · high | `codex -m gpt-5.6-luna -c model_reasoning_effort="high" -s workspace-write` | Segunda opinión/ejecutor independiente. `-s workspace-write` limita su sandbox a escribir solo dentro del proyecto — guardrail de seguridad general, no específico de Engram (que ya no está registrado, ver más abajo). Al primer arranque puede pedir confirmación de hooks (bloquea el pane hasta resolverlo con `herdr agent send <target> "3"`) |
| **opencode** | DeepSeek V4 Flash Free | `opencode -m opencode/deepseek-v4-flash-free` | Ejecutor independiente. `agent wait --status idle` no es confiable — sondear con `agent read` en vez de esperar a ciegas |
| **Agy** (Antigravity) | Gemini 3.6 Flash · High | `agy --model gemini-3.6-flash-high` | Minion/ejecutor mecánico en model tiering. TUI de alt-screen — leer con `--source visible`, no `recent`. Esperar a que termine de bootear antes del prompt real. **No es fire-and-forget con capacidad de escritura** — ver nota abajo, pide confirmación por cada acción |

Nota Agy — **confirmación por acción es el comportamiento default, no algo que trae `--sandbox`**
(corregido tras probarlo en vivo, la nota anterior decía lo contrario). Con el comando default
(`agy --model gemini-3.6-flash-high`, **sin** `--sandbox`), cada archivo que crea/edita y cada
comando de shell que corre dispara un prompt bloqueante ("Allow creation of this file?" / "Requesting
permission for: `<comando>`") que hay que aprobar uno por uno con `herdr pane run <target> "1"` — con
5 escrituras seguidas (3 archivos + 1 comando, en una prueba real) salieron 4 prompts, ninguno
agrupado. Un rol de Agy con capacidad de escritura en un patrón multi-agente **no se puede lanzar y
dejar corriendo sin supervisión** — hay que sondear el pane (`agent read --source visible`) y aprobar
cada prompt a medida que aparece, igual que se hace con el hook de Codex. Además, la **primera vez**
que Agy corre en un directorio que no vio antes pide un trust prompt único ("Do you trust the contents
of this project?") — se aprueba igual, con `herdr pane run <target> ""` (la opción default ya es
"Yes, I trust this folder").

Separado de esto, Agy también tiene un **sandbox nativo opcional** (`--sandbox`): da un aislamiento
más fuerte que el `-s workspace-write` de Codex (en macOS usa `sandbox-exec` y bloquea *lectura y
escritura* fuera del proyecto, no solo escritura — probado en vivo). No es el comando default porque
suma fricción de confirmación *adicional* a la que ya existe por default (ver arriba) — usarlo cuando
el aislamiento del sandbox importe más que esa fricción extra, y **nunca combinarlo con
`--dangerously-skip-permissions`**: vulnerabilidad documentada (`google-antigravity/antigravity-cli#36`)
que deja que el modelo se auto-apruebe saltar el sandbox por completo.

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
`general-purpose` — tiene `disallowedTools` bloqueando `Bash`/`PowerShell`/`Edit`/`Write`/
`NotebookEdit` y los tools de escritura de Engram (`mem_save`, `mem_update`, `mem_pin`, etc.), a
diferencia del guardrail de "`mem_save` reservado al orquestador" de más abajo, que es solo texto. Este
sí es técnico: un subagente nativo de Claude Code (Task tool) no hereda `permissions.deny` del
`settings.json` del padre (limitación conocida y documentada de Claude Code —
`anthropics/claude-code#25000`, `#27661`), así que la única forma real de restringirlo es el campo
`disallowedTools`/`tools` de su propia definición de agente, no un ajuste de `settings.json`. Nota:
`safe-reviewer` excluye `Bash` a propósito, no solo los tools MCP — un subagente con Bash disponible
podría invocar el binario real de `engram` directo, igual que hacían los CLIs externos antes del
wrapper. Si un rol de revisión realmente necesita correr comandos (tests, linters), no usar
`safe-reviewer`, usar `general-purpose` y aplicar el guardrail de texto como mitigación parcial.
Verificado en vivo (ver `TODO.md`): `mem_save` y `Bash` no aparecen en la lista de tools de un
subagente `safe-reviewer`, ni siquiera entre las diferidas — `mem_search` sí, confirmando que el
bloqueo es selectivo. **Alcance**: esto solo cubre subagentes nativos de Claude Code (Task tool); los
CLIs externos vía Herdr no leen `.claude/agents/`, siguen protegidos por el wrapper/sandbox de más
abajo, son superficies distintas.

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

1. **Timeout explícito por rol.** Todo `agent wait --status idle` lleva `--timeout` (60-120s para un
   prompt normal, más para tareas de razonamiento largas) — nunca un wait sin límite. Si se cumple el
   timeout, no seguir esperando ese pane a ciegas: pasar directo al punto 3 (degradación).
   **Excepción confirmada en earpi (v0.33)**: si la tarea le pide al ejecutor correr comandos como
   parte de verificar su propio trabajo (`bun test`, build, lint), 180s no alcanzó con Codex casi
   terminado — ese tiempo se suma al de razonamiento, no lo reemplaza. Para este tipo de tarea usar
   300-600s, o preferir `herdr wait output <target> --match <texto-de-fin-esperado>` en vez de un solo
   wait largo por `agent_status` — permite chequear progreso real en vez de esperar a ciegas hasta el
   límite.
2. **Herdr puede caer a mitad de un patrón** (entre `tab create` y `pane run`, o con agentes ya
   corriendo). No hay una señal proactiva de esto — se detecta porque el siguiente comando de Herdr
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
hallazgos, sin pendientes activos (última ronda cerrada: feedback de uso real en earpi, v0.33-v0.34).
