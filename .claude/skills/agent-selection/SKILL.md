---
name: agent-selection
description: >
  Evalúa una situación de trabajo y recomienda si conviene usar un solo agente o varios coordinados,
  qué patrón de orquestación aplica, y qué CLI/modelo asignar a cada rol. Trigger: antes de delegar
  una tarea a un agente, cuando se duda si vale la pena coordinar múltiples agentes (vía Herdr u otro
  mecanismo), o al elegir qué CLI/modelo usar para un subagente.
metadata:
  status: experimental
  version: "0.25"
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

**Memoria compartida (Engram) — search abierto, save centralizado en el orquestador:**

Engram (memoria persistente de Claude Code) puede registrarse como servidor MCP en el config propio de
cada CLI (Codex: `~/.codex/config.toml`; opencode: `~/.config/opencode/opencode.jsonc`, clave `mcp`;
Agy: `~/.gemini/config/mcp_config.json`) — no es automático, es setup previo, no algo que la skill haga
al lanzar un pane. El binario `engram mcp --tools=<perfil>` soporta perfiles y también nombres de
herramientas individuales (`--tools=mem_search`, `--tools=mem_save,mem_search`, etc.).

- **Ejecutores/jueces lanzados vía Herdr**: registrar Engram con `--tools=mem_search` únicamente — les
  sirve para no redescubrir contexto ya guardado, sin que cada uno escriba memoria por su cuenta.
- **`mem_save` queda reservado al orquestador** (esta sesión) — mismo principio que el resto de esta
  sección: un solo punto de control para lo que se persiste, después de filtrar/sintetizar. **Esto
  también aplica a subagentes nativos lanzados con el Task tool, no solo a CLIs externos vía Herdr** —
  probado en vivo: un subagente nativo tiene acceso completo y sin restricción a `mem_save` (vía MCP) y
  al binario `engram` crudo (vía Bash), porque corre con el mismo nivel de confianza que la sesión
  orquestadora — no hay wrapper por `PATH` ni sandbox que lo limite, a diferencia de Codex/opencode/Agy.
  Un subagente de Task tool debe reportar sus hallazgos de vuelta al orquestador, no guardar memoria por
  su cuenta.
- **La restricción `--tools=` sola es una barrera blanda** — solo limita lo que el CLI ve a través de
  *esa conexión MCP registrada*; un CLI con acceso a bash puede saltearla invocando el binario `engram`
  directamente con otro perfil. Probado en vivo, encontró exactamente eso: opencode lo hizo y escribió
  una memoria real.
- **Barrera más dura: wrapper restringido delante del binario real**
  (`~/.local/share/agent-selection/restricted-bin/engram`) — vive **fuera del árbol de cualquier
  proyecto** a propósito: si viviera dentro de un repo que el CLI lanzado puede escribir (ej. Codex con
  `-s workspace-write`), ese mismo CLI podría editar o borrar el wrapper antes de intentar el bypass.
  Solo deja pasar `engram mcp --tools=mem_search [--project NAME]`, bloquea cualquier otra cosa
  (`--tools=all`, `save`, `delete`, agregar `mem_save` a la lista, etc.) con exit 1, sin importar qué le
  pida el modelo. Activarlo anteponiendo su directorio al `PATH` **dentro del mismo comando de
  `pane run`** que lanza el CLI — no con `herdr tab create --env PATH=...`, que el shell interactivo
  termina pisando con sus propios dotfiles (`.zshrc`/`brew shellenv` vuelven a poner
  `/opt/homebrew/bin` primero):
  ```bash
  herdr pane run <pane_id> 'export PATH="$HOME/.local/share/agent-selection/restricted-bin:$PATH"; <comando del CLI>'
  ```
  Fuente completa del wrapper (crear en `~/.local/share/agent-selection/restricted-bin/engram`,
  `chmod +x` — no se distribuye con el repo a propósito, ver arriba):
  ```bash
  #!/usr/bin/env bash
  # Restricted wrapper for the real `engram` binary.
  # Only allows: engram mcp --tools=mem_search [--project NAME]
  # Blocks everything else (save, delete, --tools=all, --tools=mem_save, raw stdio tricks, etc.)
  # so a spawned CLI (Codex/opencode/Agy) can search shared memory but cannot write to it,
  # even if it tries to shell out and construct the call by hand.
  set -euo pipefail

  REAL_ENGRAM="/opt/homebrew/bin/engram"

  deny() {
    echo "engram (restricted): blocked — only 'engram mcp --tools=mem_search [--project NAME]' is permitted here. Attempted: engram $*" >&2
    exit 1
  }

  if [ "${1:-}" != "mcp" ]; then
    deny "$@"
  fi
  shift

  tools_ok=0
  i=0
  args=("$@")
  n=${#args[@]}
  while [ "$i" -lt "$n" ]; do
    arg="${args[$i]}"
    case "$arg" in
      --tools=mem_search)
        tools_ok=1
        ;;
      --project)
        i=$((i + 1))
        if [ "$i" -ge "$n" ]; then
          deny mcp "$@"
        fi
        ;;
      *)
        deny mcp "$@"
        ;;
    esac
    i=$((i + 1))
  done

  if [ "$tools_ok" -ne 1 ]; then
    deny mcp "$@"
  fi

  exec "$REAL_ENGRAM" mcp "$@"
  ```
- **Resultado real, probado con los tres CLIs**: **opencode** y **Agy** heredan el `PATH` del proceso
  padre para su herramienta de shell — el wrapper bloqueó ambos intentos de bypass (`--tools=all` y
  `--tools=mem_save`) con el mensaje del wrapper, exit 1. **Codex NO** — su herramienta de ejecución
  reconstruye su propio entorno en sandbox y `which engram` ahí adentro sigue resolviendo al binario
  real, ignorando el `PATH` exportado afuera. El wrapper por `PATH` no sirve como barrera para Codex.
- **Barrera real para Codex: su propio sandbox de ejecución, no un truco de `PATH`.** Lanzarlo con
  `-s workspace-write` (Codex solo puede escribir *dentro* del directorio de trabajo; todo lo de afuera
  queda denegado por el sandbox del SO, macOS Seatbelt). `~/.engram/` (la base de datos real de Engram)
  vive fuera de cualquier proyecto — probado en vivo: con `-s workspace-write`, `mem_search` funciona
  normal (vía la conexión MCP propia, no pasa por el sandbox de shell) y el intento de bypass por bash
  contra `engram mcp --tools=mem_save` fue denegado por el sandbox, no por una coincidencia de lock de
  base de datos (se confirmó por separado: un `echo > archivo` fuera del workspace da
  `Operation not permitted`, la misma clase de error). **`-s read-only` NO sirve** — es demasiado
  estricto: bloquea hasta `mem_search`, porque el propio binario `engram` necesita escritura incidental
  (migración de schema) para arrancar, sin importar qué tools se pidan.

**Modelos fijos por CLI** (decisión del usuario, usar siempre estos — no improvisar otro modelo):

| CLI | Modelo fijo | Invocación vía `pane run` | Rol por defecto |
|---|---|---|---|
| **Claude Code** | Sonnet 5 (default de la CLI, sin flag) | `claude` | Orquestador/líder — mejor detección de estado (`agent wait --status idle` confiable) |
| **Codex** | gpt-5.6-luna · high | `codex -m gpt-5.6-luna -c model_reasoning_effort="high" -s workspace-write` | Segunda opinión/ejecutor independiente. `-s workspace-write` limita su sandbox a escribir solo dentro del proyecto — es también la barrera real contra que escriba en Engram (ver más abajo). Al primer arranque puede pedir confirmación de hooks (bloquea el pane hasta resolverlo con `herdr agent send <target> "3"`) |
| **opencode** | DeepSeek V4 Flash Free | `opencode -m opencode/deepseek-v4-flash-free` | Ejecutor independiente. `agent wait --status idle` no es confiable — sondear con `agent read` en vez de esperar a ciegas |
| **Agy** (Antigravity) | Gemini 3.6 Flash · High | `agy --model gemini-3.6-flash-high` | Minion/ejecutor mecánico en model tiering. TUI de alt-screen — leer con `--source visible`, no `recent`. Esperar a que termine de bootear antes del prompt real |

Nota Agy — sandbox nativo disponible pero no usado por default: agregar `--sandbox` da un aislamiento
más fuerte que el `-s workspace-write` de Codex (en macOS usa `sandbox-exec` y bloquea *lectura y
escritura* fuera del proyecto, no solo escritura — probado en vivo). No es el comando default porque
introduce un prompt de confirmación interactivo antes de cada comando de shell, que rompe el patrón de
lanzamiento autónomo en background de este Paso 4. Usarlo cuando el aislamiento importe más que la
fricción de aprobar cada comando — y **nunca combinarlo con `--dangerously-skip-permissions`**:
vulnerabilidad documentada (`google-antigravity/antigravity-cli#36`) que deja que el modelo se
auto-apruebe saltar el sandbox por completo.

Nota Codex: `~/.codex/config.toml` trae `model_reasoning_effort = "xhigh"` como default global — distinto
del `high` fijado acá. La invocación pasa **ambos** flags explícitos, `-m gpt-5.6-luna` y
`-c model_reasoning_effort="high"` — antes solo se fijaba el reasoning effort y el modelo base quedaba
a merced del config global (bug encontrado por revisión ciega con Codex mismo, ver changelog v0.7).
Chequear el banner al lanzarlo (`gpt-5.6-luna high`) para confirmar que ambos se aplicaron.

Si Herdr no está activo (ver Paso 0): usar subagentes nativos de Claude Code (Sonnet 5) para los
patrones del Paso 3 que no dependan de cruzar proveedores (1, 2, 3, 5 sirven igual con subagentes
nativos). El patrón 4 (model tiering) **no tiene minion barato sin Herdr** — no queda "sin resolver":
degrada explícitamente a Delegated direct (Paso 1, ruta 2) con subagente nativo, sin el ahorro de
costo pero sin bloquear la tarea.

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
acá para no inflar el archivo que se lee en cada invocación. Pendientes de seguridad sin resolver en
`TODO.md` — incluye un gap crítico todavía sin corregir (el wrapper de Engram vive dentro del árbol del
proyecto, que los mismos CLIs que restringe pueden escribir).
