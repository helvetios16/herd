# Changelog — agent-selection

Historial de ajustes de la skill, agrupado en bloques de ~10 versiones (una entrada por bloque) —
detalle completo solo en el bloque más reciente, todavía en formación (criterio: un bloque cerrado ya
cumplió su función de trazabilidad, no hace falta repetirlo entero; recuperable línea por línea en el
historial de git de este archivo si algún día hiciera falta el detalle).

- **v0.1–v0.10 — fundacional.** Primera versión, basada en Agent Harness Patterns y pruebas de
  coordinación con Herdr. Chequeo de Herdr como Paso 0 obligatorio. Modelos fijos por CLI (Opus 5 en
  ese momento / gpt-5.6-luna / DeepSeek V4 Flash Free / Gemini 3.6 Flash). Paso 1/2 realineados al
  esquema de tres rutas de `trigger-rules.md` de gentle-ai. Convención de lanzar en el pane root de un
  tab nuevo, nunca con `pane split`. Primera revisión ciega real (Codex+opencode): 5 problemas
  convergentes corregidos más un bug de invocación de Codex. Operacionalizado Blind dual-judge. Paso 0
  extendido para verificar que la sesión esté *dentro* de Herdr, no solo que el server esté corriendo.
  Primera prueba de Lentes 4R con el **Paso 6 — fallos a mitad de camino** (timeout, Herdr caído,
  degradación con resultados parciales, limpieza de tabs).
- **v0.11–v0.20 — cierre de las lentes 4R y primera ronda de seguridad de Engram.** Aplicados los
  hallazgos de las lentes Risk y Readability (lista de riesgo ampliada, guardrails de escritura en el
  Paso 4, dedupe de model tiering, glosario de jerga Herdr/TUI). Primera prueba real de model tiering.
  Changelog movido de `SKILL.md` a este archivo. Diseño y hardening de la barrera de escritura a Engram
  para CLIs externos: wrapper por `PATH` (`restricted-bin/engram`), luego reemplazado por el sandbox
  real de Codex (`-s workspace-write`) al encontrar que el wrapper por `PATH` no lo detenía. Creado
  `TODO.md` con los pendientes de esa ronda. Claude Code pasa de Opus 5 a Sonnet 5, sin flag de modelo.
  Wrapper de Engram movido fuera del árbol del repo (gap crítico: un CLI con permiso de escritura podía
  editarlo/borrarlo antes de intentar el bypass).
- **v0.21–v0.30 — cierre de la ronda de seguridad de Engram, y luego su reversión.** Cerrado el `TODO.md`
  de seguridad por completo: bypass real probado y bloqueado (wrapper ya fuera del repo), guardrail de
  "no pegar secretos en los prompts" confirmado (`pane_history` off por defecto), lista de riesgo del
  Paso 2 confirmada **sin respaldo técnico real** (depende de que el CLI respete el prompt). Hallazgo
  importante: un subagente nativo de Task tool tenía escritura sin restricción a Engram — creado
  `.claude/agents/safe-reviewer.md` (`disallowedTools`) como mitigación real, verificado en vivo que
  bloquea `mem_save`/`Bash`. Comparado con gentle-ai (mismo problema de fondo con subagentes, sin
  solución propia). Agentes custom equivalentes probados y confirmados para Codex/opencode (sandbox real
  bloqueando el bypass), sin equivalente para Agy. **Decisión del usuario que revierte casi toda esta
  ronda (v0.29)**: Engram deja de registrarse como MCP en los CLIs externos — el beneficio de que
  buscaran memoria por su cuenta era marginal frente al costo de mantener esta barrera; el wrapper y los
  agentes custom quedan dormidos en el filesystem por si se reconsidera.
- **v0.31–v0.40 — primeros patrones multi-agente reales, feedback de earpi, y actualización a Herdr
  0.8.0.** Primer patrón multi-agente completo corrido de verdad vía `sdd-implement` (3 CLIs en
  paralelo): hallazgo de que `agent send` no somete Enter, hay que usar `pane run`. Hallazgos reales
  sobre Agy (la confirmación por acción es su comportamiento default, no algo que trae `--sandbox`).
  Tres rondas de feedback real de earpi cerradas (`revision` no sirve para detectar cambios de pane,
  gotcha de `status` read-only en zsh, timeout insuficiente cuando el ejecutor verifica su propio
  trabajo, ambigüedad de "auth" en la lista de riesgo, roster de CLI por proyecto), con confirmación
  posterior de que los fixes funcionaron en un run real. Investigación de `herdr --help` (0.7.4):
  `agent start` no reemplazaba `tab create`+`pane run`, `agent_status` de Agy es puro fallback estático,
  `herdr worktree` confirmado como aislamiento real para escritura paralela, `notification show` no
  utilizable, `agent rename` vs `pane`/`tab rename` no son intercambiables — más confirmación oficial
  del fallback de Agy vía la doc de Herdr. Actualización real de Herdr 0.7.4 → 0.8.0, con reescritura
  del Paso 4 a la API nueva (`agent start --kind/--pane`, `agent prompt --wait`, `agent send-keys`,
  variables `$HERDR_*`) y corrección del hallazgo de opencode (sí tiene autoridad de ciclo de vida real,
  la nota vieja estaba desactualizada). Cierra con una limpieza de `SKILL.md` (495→393 líneas) pedida
  por el usuario y corrección de 2 referencias cruzadas rotas.
- **v0.41** — decisión explícita del usuario: Agy sale del roster activo, una segunda instancia de
  Claude Code entra en su lugar. Motivada directamente por los hallazgos de v0.35-v0.39 (detección de
  estado de Agy nunca funcionó, ni siquiera con Herdr 0.8.0 y manifiestos actualizados). Se preguntó
  antes de tocar nada qué rol cubriría el reemplazo, dado que Sonnet 5 no es un modelo barato — el
  usuario eligió: Claude Code entra como cuarta opción lanzable (ejecutor/segunda opinión de máxima
  confiabilidad), y opencode (ya confirmado confiable y gratis en v0.39) toma el rol de minion barato de
  model tiering que dejaba Agy. Aplicado en `SKILL.md`: tabla de CLIs actualizada, las dos notas
  tácticas de Agy removidas (reemplazadas por una nota corta de por qué se sacó, con puntero a
  `TODO.md`/`CHANGELOG.md` para el historial completo) y una nota nueva sobre el límite de Claude#2
  como juez (da independencia de contexto, no de modelo — preferir Codex/opencode cuando eso importa).
  Limpiadas también las menciones sueltas de Agy en Paso 0/glosario/notas de polling que ya no aplican
  al roster activo. `TODO.md`: nueva sección con la decisión y su razonamiento completo.
- **v0.42** — actualización real de Herdr 0.8.0 → 0.8.2 (`brew upgrade herdr`, mismo procedimiento que
  v0.38: self-update deshabilitado en instalaciones Homebrew, reinicio del server hecho por el usuario
  fuera de esta sesión, confirmado después con `herdr status` → `compatible: yes`, `restart_needed: no`,
  la sesión de esta skill siguió viva sin cortes). A pedido del usuario, investigado el
  `CHANGELOG.md` oficial del repo (`herdrdev/herdr`, leído directo vía `raw.githubusercontent.com` para
  evitar el resumen alucinado que dio el fetch inicial contra la página de releases de GitHub — fecha y
  contenido no coincidían con el texto crudo) y aplicados a `SKILL.md` los dos hallazgos con impacto
  directo en esta skill, **sin prueba en vivo propia** (a diferencia de v0.38/v0.39, acá se confía en el
  changelog oficial con número de issue, no en repetir la prueba adversarial):
  1. Los prompts de confirmación nativos de Claude Code (`Enter to confirm · Esc to cancel`) ahora
     reportan `agent_status: blocked` en vez de `idle` (bug corregido, issue #2268 del changelog
     oficial) — relevante porque Claude#2 (agregada como juez en v0.41) puede toparse con este mismo
     tipo de prompt. Agregado como ejemplo de `blocked` en la nota de `agent start` del Paso 4, junto al
     ya existente de Codex.
  2. `agent send-keys`/`pane send-keys` ahora preservan Shift al enviar `shift+tab` (antes se perdía,
     issue #1561) — permite ciclar el modo de permisos de un agente por comando. Agregado como nota
     corta después del párrafo de `send-keys` en el Paso 4.
  Otros hallazgos del changelog (fix de carrera en `agent start` esperando el pane/shell listo,
  `#2410`/`#2537`/`#2773`/`#2774`; restore nativo de OpenCode por conversación raíz, `#2450`) se
  evaluaron y se descartaron para `SKILL.md`: no corrigen ninguna guía activa del archivo (la
  recomendación de revisar `agent_status` después de `agent start` sigue siendo válida
  independientemente de si la carrera existía o no) ni cambian ninguna nota de confiabilidad existente
  (la nota de opencode ya documentaba su detección como confiable desde v0.38, el restore es un tema
  distinto). `TODO.md`: nueva sección con el detalle completo y los ítems descartados, explícito que
  falta verificación en vivo si en algún momento se quiere confirmar el fix de Claude Code con una
  prueba real (relanzar Claude#2, forzar un prompt de confirmación, leer `agent_status`).
- **v0.43** — pedido explícito del usuario: agregar la skill oficial de Herdr (`herdr --skill`) como
  skill propia dentro de este repo, y que `agent-selection` la referencie en vez de instruir correrla
  en vivo cada vez. Creado `.claude/skills/herdr/SKILL.md` con el output verbatim de `herdr --skill`
  (ya trae frontmatter válido — `name: herdr`, `description` propia — listo para cargar como skill sin
  edición), más un bloque `metadata` agregado a mano (no viene del binario) con la versión de Herdr al
  momento de la captura (0.8.2) y una nota explícita de que el archivo no se auto-actualiza: hay que
  regenerarlo corriendo `herdr --skill > .claude/skills/herdr/SKILL.md` de nuevo tras cada upgrade,
  porque el output de `herdr --skill` no trae ningún número de versión adentro que permita detectar el
  desfasaje solo. Aplicado en `SKILL.md`: la lista de "fuentes externas" (preámbulo) ahora incluye la
  skill `herdr`, y el Paso 4 reemplaza la instrucción de correr `herdr --skill` suelto por apuntar al
  archivo local, con la misma advertencia de posible desactualización.
- **v0.44** — pedido explícito del usuario tras v0.43 (opción elegida de 2 propuestas: "opción 1,
  creás un script que regenere la skill acá, y luego se copia a mano a otros lados donde haga falta,
  sin mucho problema"): reemplazado el `metadata` a mano de `.claude/skills/herdr/SKILL.md` por
  `.claude/skills/herdr/regenerate.sh`, un script que corre `herdr --skill` y `herdr --version` en
  vivo y arma el frontmatter con la versión real (evita que quede mal tipeada o vieja por olvido).
  Probado: `git diff` contra el archivo escrito a mano en v0.43 dio vacío — el script reproduce
  exactamente el mismo resultado, además de quedar repetible para el próximo upgrade de Herdr.
  Aplicado en `SKILL.md` (Paso 4): la instrucción de regenerar el archivo ahora apunta al script en
  vez de al comando `herdr --skill > ...` suelto, y agrega una señal concreta de cuándo correrlo — si
  `metadata.captured_from_herdr_version` del archivo local no coincide con la versión que reporta
  `herdr status` en el Paso 0. Fuera de alcance a propósito (decisión explícita del usuario): no se
  automatizó la copia de este script/skill a otros repos — queda manual, "sin mucho problema".
- **v0.45** — pedido explícito del usuario: cerrar en vivo el pendiente de v0.42 (fix de Claude Code
  #2268) y de paso probar el otro hallazgo de 0.8.2 (Shift en `shift+tab`), en ese orden. Lanzada una
  segunda instancia real de Claude Code vía Herdr (`tab create` + `agent start --kind claude`).
  **Hallazgo no anticipado**: quedó en "auto mode" por default, que aprueba solo por clasificador — el
  primer intento de escritura no disparó ningún diálogo, invalidando la primera prueba. Resuelto
  sacándola de auto mode con `agent send-keys ... shift+tab` antes de reintentar (esto ya probó de
  paso el segundo hallazgo). Con eso, un segundo pedido de escritura sí disparó el diálogo real y
  `agent_status` dio `blocked` (confirmado con `agent explain --json`) — **fix de #2268 confirmado en
  vivo**, con un matiz: el bloqueo lo detectó el fallback genérico `legacy_no_prompt_blocker`, no una
  regla dedicada (las reglas específicas buscan "do you want to proceed?", frase de Bash; el diálogo
  real del tool Write dice "Do you want to create `<archivo>`?", texto distinto sin regla propia
  todavía) — el resultado final es correcto igual, no cambia ninguna recomendación de `SKILL.md`.
  Shift en `shift+tab` confirmado con dos transiciones de modo reales y distintas (auto→manual,
  manual→accept edits), leídas del pane, no inferidas. Limpieza: tab de prueba cerrado, 2 archivos
  temporales de `/tmp` borrados. `TODO.md`: el ítem pendiente de v0.42 pasa de `[ ]` a `[x]` con el
  detalle completo; agregado un `[x]` nuevo para el hallazgo de `shift+tab`. Sin cambios de contenido
  en `SKILL.md` — ninguna de las dos pruebas encontró algo que corrija la guía ya escrita en v0.42.
- **v0.46** — pedido explícito del usuario: sacar `status: experimental` del `metadata` del frontmatter,
  dejar solo `version`. Motivo implícito: tras 46 versiones, historial versionado completo en este
  archivo y una ronda de verificación en vivo recién cerrada (v0.45), la etiqueta "experimental" ya no
  describe el estado real de la skill. Quitada la línea del frontmatter y también la mención equivalente
  en prosa ("Skill experimental, en ajuste continuo" → "Skill en ajuste continuo, versionada en
  `CHANGELOG.md`", primer párrafo de "Qué hace esta skill") — quedó "en ajuste continuo" porque eso sí
  sigue siendo cierto, solo se sacó la calificación de "experimental". No se tocó la mención no
  relacionada de la línea de guardrails de Herdr ("`[experimental] pane_history`" — un flag de config de
  Herdr, no el estado de esta skill).
- **v0.47** — pedido explícito del usuario: reducir el tamaño de este archivo, que había llegado a 438
  líneas / 46 versiones con detalle completo desde v0.12 en adelante (solo v0.1-v0.11 estaban
  comprimidas, una por línea, desde el recorte de v0.12). Esquema elegido por el usuario (de 3
  propuestas): agrupar en bloques de ~10 versiones, una sola entrada de resumen por bloque — no una
  línea por versión como el esquema anterior. Comprimidos v0.1-v0.10, v0.11-v0.20, v0.21-v0.30 y
  v0.31-v0.40 en cuatro bloques (reemplazando 40 entradas individuales, incluidas las 11 que ya estaban
  en formato de una línea). v0.41 en adelante queda con el detalle completo sin tocar — es la década más
  reciente, todavía en formación, con el trabajo de esta misma sesión (Herdr 0.8.2, skill `herdr`,
  verificación en vivo). Resultado: 438 → 140 líneas (~68% menos). El detalle completo de las versiones
  comprimidas sigue recuperable línea por línea en el historial de git de este archivo — no se perdió
  información, solo se resumió la prosa. Actualizado también el criterio del preámbulo para describir el
  esquema nuevo de bloques.
