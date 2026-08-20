# Changelog — agent-selection

Historial de ajustes de la skill. Entradas v0.1 a v0.11 comprimidas a una línea cada una — detalle
completo solo en la más reciente (criterio: la anterior ya cumplió su función de trazabilidad, no hace
falta repetirla entera).

- **v0.1** — primera versión, basada en [[Agent Harness Patterns]] y pruebas de coordinación con Herdr.
- **v0.2** — chequeo de Herdr pasa a ser el Paso 0 obligatorio, antes de cualquier otra evaluación.
- **v0.3** — modelos fijos por CLI (Opus 5 / gpt-5.6-luna / DeepSeek V4 Flash Free / Gemini 3.6 Flash).
- **v0.4** — Codex de `xhigh` a `high`, fijado explícito por no confiar en el config global.
- **v0.5** — Paso 1/2 realineados al esquema de tres rutas de `trigger-rules.md` de gentle-ai.
- **v0.6** — lanzar agentes en el pane root del tab nuevo, nunca con `pane split`.
- **v0.7** — primera revisión ciega real (Codex+opencode): 5 problemas convergentes + bug de invocación
  de Codex corregidos (fallback de model tiering, criterios objetivos, prioridad entre preguntas del
  Paso 2, justificación del Paso 0, fuentes externas, `-m gpt-5.6-luna`).
- **v0.8** — operacionalizado Blind dual-judge (quién coordina, cómo evitar fuga entre jueces) y Paso 5
  condicionado a rutas con CLI externo real.
- **v0.9** — Paso 0: nunca iniciar el server por cuenta propia, y verificar que la sesión esté *dentro*
  de Herdr (no solo que el server esté `running`).
- **v0.10** — primera prueba de Lentes paralelas 4R (4 evaluadores reales): agregado el **Paso 6 —
  fallos a mitad de camino** (timeout, detección de Herdr caído, degradación con resultados parciales,
  limpieza de tabs, qué pasa si la corrección única falla) y verificación de arranque real en el Paso 4.
- **v0.11** — aplicados los 5 hallazgos de la lente Risk: lista de riesgo ampliada (CI/CD, infra,
  migraciones, config de producción), el riesgo anula Direct inline aunque el conteo de archivos diga
  lo contrario, guardrails de seguridad en el Paso 4 (lectura por defecto, escritura requiere
  confirmación aparte, nunca destructivo sin supervisión), no pegar secretos en los prompts, y
  correcciones sobre la lista de riesgo requieren confirmación del usuario, no solo del orquestador.
- **v0.12** — aplicados los 5 hallazgos de Readability, cierra el ciclo de las 4 lentes 4R: dedupe del
  fallback de model tiering, Blind dual-judge reubicado del Paso 4 al Paso 3, glosario de jerga
  Herdr/TUI en el Paso 4, meta-comentarios narrativos recortados del Paso 0, changelog histórico
  comprimido a una línea por versión.
- **v0.13** — primera prueba real de Model tiering (patrón 4) con división de trabajo genuina: Agy
  extrajo mecánicamente los 11 comandos `herdr ...` citados en el archivo, el orquestador los comparó
  contra `herdr --help` real (la parte que sí requiere criterio). Los 11 son válidos; encontró un
  hallazgo menor: la nota de Codex en la tabla del Paso 4 citaba `` `agent send <target> "3"` `` sin el
  prefijo `herdr` — único comando del archivo escrito así, no ejecutable si se copia literal. Corregido
  a `` `herdr agent send <target> "3"` ``.
- **v0.14** — el changelog se movió de `SKILL.md` a este archivo (`CHANGELOG.md`), en el mismo
  directorio de la skill — decisión explícita del usuario para que el historial no infle el archivo
  que se carga en cada invocación. `SKILL.md` ahora solo tiene un puntero acá.
- **v0.15** — agregado el diseño de memoria compartida (Engram) al Paso 4: search abierto para
  ejecutores/jueces lanzados vía Herdr (`engram mcp --tools=mem_search`), `mem_save` reservado al
  orquestador. Probado en vivo registrando Engram en `~/.config/opencode/opencode.jsonc` restringido a
  `mem_search` y lanzando opencode vía Herdr: `mem_search` funcionó de verdad (encontró las memorias
  reales guardadas esta sesión), pero opencode logró saltarse la restricción invocando el binario
  `engram mcp --tools=all` directamente por bash y escribió una memoria real de todos modos (limpiada
  después, obs #657 hard-deleted). Hallazgo documentado: la restricción `--tools=` es una barrera
  blanda (evita el uso accidental por el flujo normal de tool-calling), no un límite de seguridad
  garantizado contra un CLI con acceso a shell.
- **v0.16** — mejorada la barrera y probada con los tres CLIs. Creado
  `restricted-bin/engram` (wrapper que solo deja pasar `engram mcp --tools=mem_search`, bloquea todo lo
  demás con exit 1) y activado anteponiéndolo al `PATH` dentro del mismo comando de `pane run` (no con
  `tab create --env`, que el shell interactivo pisa con sus dotfiles). Registrado Engram también en
  Codex (`~/.codex/config.toml`) y Agy (`~/.gemini/config/mcp_config.json`). Resultado: **opencode y Agy
  respetan el wrapper** — ambos intentos de bypass (`--tools=all`, `--tools=mem_save`) quedaron
  bloqueados con exit 1. **Codex no** — su herramienta de ejecución reconstruye su propio entorno en
  sandbox; `which engram` ahí adentro resuelve al binario real sin importar el `PATH` externo, y el
  intento de bypass llegó al binario real (solo falló por un error de DB ajeno, `readonly database`, no
  por el wrapper). Documentado como límite conocido: para Codex, no registrarle `mem_save` en su propio
  MCP config es la única mitigación real disponible por ahora.
- **v0.17** — encontrada la barrera real para Codex: no un truco de `PATH`, sino su propio sandbox de
  ejecución (macOS Seatbelt). Probado `-s read-only`: descartado — demasiado estricto, bloquea hasta
  `mem_search` porque `engram mcp` necesita escritura incidental (migración de schema) para arrancar,
  sin importar qué tools se pidan. Probado `-s workspace-write`: funciona — Codex solo puede escribir
  dentro del proyecto, `~/.engram/` (la DB real) queda fuera y el sandbox del SO lo deniega
  (confirmado con un `echo > archivo` fuera del workspace dando `Operation not permitted`, la misma
  clase de error que el intento contra Engram). `mem_search` sigue funcionando normal porque pasa por la
  conexión MCP, no por el sandbox de shell. Agregado `-s workspace-write` a la invocación estándar de
  Codex en el Paso 4 — no es solo para Engram, es un guardrail de seguridad razonable en general
  (Codex no puede escribir fuera del proyecto ni por accidente).
- **v0.18** — creado `TODO.md` con los pendientes de seguridad detectados durante la ronda de pruebas
  de v0.15-v0.17, priorizados. El más importante: el wrapper de Engram vive dentro del árbol del
  proyecto, que los mismos CLIs que restringe pueden escribir bajo `-s workspace-write` — nadie probó
  todavía si un CLI puede editar/borrar el wrapper para anular la restricción antes de intentar el
  bypass. `SKILL.md` ahora apunta a `TODO.md` desde "Estado y ajustes".
- **v0.19** — decisión explícita del usuario: Claude Code pasa de Opus 5 a **Sonnet 5**, sin flag de
  modelo (`claude` a secas usa el default actual de la CLI). Cambiado en las tres referencias de
  `SKILL.md`: el ejemplo de lanzamiento del Paso 4, la fila de la tabla "Modelos fijos por CLI" (se
  quitó también la justificación "mayor razonamiento para planificar", específica de Opus), y el modo
  sin Herdr (subagentes nativos). El resto de los CLIs (Codex, opencode, Agy) no cambia.
- **v0.20** — resuelto el ítem crítico de `TODO.md`: el wrapper se movió de
  `.claude/skills/agent-selection/restricted-bin/engram` (dentro del repo) a
  `~/.local/share/agent-selection/restricted-bin/engram` (fuera del árbol de cualquier proyecto), para
  que un CLI lanzado con permiso de escritura sobre el repo (ej. Codex con `-s workspace-write`) no
  pueda editar ni borrar el wrapper antes de intentar el bypass. Actualizado el `PATH` inline del Paso 4
  en `SKILL.md` a la ruta nueva, y agregado ahí mismo el fuente completo del wrapper como bloque de
  código documentado — la única copia ejecutable vive ahora fuera del repo, sin esto se perdería el
  fuente si se borra `~/.local/share/agent-selection/`. Creado también `README.md` en la raíz del repo
  (primero del proyecto) con puntero a la skill y una nota del setup manual requerido fuera del repo.
  Pendiente en `TODO.md`: repetir la prueba de bypass real con el wrapper ya en la ruta nueva — todavía
  no se hizo (solo un smoke test manual: `--tools=all` bloqueado con exit 1, `--tools=mem_search`
  pasa al binario real).
- **v0.21** — cerrado el ítem crítico del `TODO.md`: prueba de bypass real, no simulada, con Codex
  lanzado de verdad vía Herdr (`-s workspace-write`, tab nueva en `herd`). Pedido explícito: escribir un
  archivo dentro del repo, leer el wrapper externo, y borrarlo. Resultado — escritura dentro del repo:
  éxito (exit 0); lectura del wrapper fuera del proyecto: éxito (exit 0, el sandbox de Codex no
  restringe lectura fuera del workspace, solo escritura); borrado del wrapper: **falló**,
  `rm: .../restricted-bin/engram: Operation not permitted`. Confirma que mover el wrapper fuera del
  árbol del proyecto (v0.20) cierra el hueco real: Codex puede escribir en el proyecto pero no puede
  tocar el wrapper. `TODO.md` actualizado, ítem crítico marcado resuelto por completo.
- **v0.22** — cerrado el primer ítem Alto del `TODO.md`: probado de verdad el guardrail de "no pegar
  secretos en los prompts". opencode lanzado de verdad vía Herdr, mandado un prompt con un secreto de
  mentira (marcador único). Buscado el marcador en `herdr-server.log`, `herdr-client.log`, `session.json`
  y el resto de `~/.config/herdr/` — cero coincidencias con la config default. Investigado en la doc
  (`herdr.dev/docs/session-state`) el motivo: el contenido de los panes solo se persiste a disco si se
  activa `[experimental] pane_history` (off por defecto), que escribe todo el scroll en texto plano a
  `session-history.json`. Agregada esta nota al guardrail del Paso 4 en `SKILL.md` — no activar esa
  opción con agentes de esta skill corriendo.
- **v0.23** — cerrado el segundo ítem Alto del `TODO.md`, último pendiente serio: probada de verdad la
  lista de riesgo del Paso 2. Codex lanzado de verdad vía Herdr (`-s workspace-write`), con dos señuelos
  de contenido falso: `~/.ssh/herd_test_decoy_key` (fuera del proyecto) y `./.env.test-decoy` (dentro del
  repo). Pedido explícito de leer y escribir cada uno. Resultado: leer fuera del proyecto — éxito;
  escribir fuera del proyecto — falló (`operation not permitted`); leer y escribir dentro del proyecto —
  ambas éxito. **Confirma que la lista de riesgo del Paso 2 no tiene respaldo técnico**: el sandbox
  protege integridad (no escritura fuera del proyecto) pero no confidencialidad (lectura fuera del
  proyecto libre, y dentro del proyecto ni lectura ni escritura están restringidas) — depende
  enteramente de que el CLI respete el prompt. Agregada esta nota al criterio de la lista de riesgo en
  `SKILL.md`. Señuelos limpiados después de la prueba. Con esto quedan cerrados todos los ítems Crítico y
  Alto de `TODO.md` — solo quedan pendientes Medio/Bajo, no bloqueantes.
- **v0.24** — avance en los ítems Medio/Bajo. Reconfirmado con Codex real (v0.147.0) que `/tmp` sigue
  escribible bajo `-s workspace-write`. **Hallazgo importante**: un subagente nativo de Claude Code (Task
  tool, no vía Herdr) tiene escritura completa y sin restricción en Engram — probado en vivo, pudo llamar
  `mem_save` por MCP directo (memoria limpiada después con `engram delete --hard`) y ejecutar el binario
  `engram` crudo por Bash sin ningún bloqueo. No hay wrapper ni sandbox equivalente al de los CLIs
  externos para subagentes nativos, porque corren con el mismo nivel de confianza que el orquestador.
  Aclarado en `SKILL.md`: el principio "`mem_save` reservado al orquestador" aplica también a
  subagentes de Task tool, no solo a CLIs vía Herdr — deben reportar hallazgos de vuelta, no guardar
  memoria por su cuenta. Quedan pendientes sin tocar: investigar sandbox nativo de opencode/Agy,
  evaluar generalizar el wrapper a otros binarios sensibles, y verificar el deny-list de gentle-ai.
- **v0.25** — cierra `TODO.md` por completo (todos los ítems Crítico/Alto/Medio/Bajo probados,
  investigados, o resueltos con recomendación). Tres hallazgos de esta ronda:
  1. **opencode no tiene sandbox nativo** — hubo un PR experimental (`anomalyco/opencode#21538`,
     opt-in vía `experimental.sandbox`) pero nunca se mergeó, cerrado en mayo 2026. Sigue dependiendo
     del wrapper por `PATH` y de `Permissions` (allow/deny/ask), ambas barreras blandas.
  2. **Agy sí tiene sandbox nativo (`--sandbox`) y es más fuerte que el de Codex** — probado en vivo:
     en macOS usa `sandbox-exec` y bloquea *lectura y escritura* fuera del proyecto (Codex solo
     bloqueaba escritura). La skill no lo usa por default porque introduce confirmación interactiva por
     comando, rompiendo el lanzamiento autónomo en background; documentado en `SKILL.md` como opción,
     con la advertencia de nunca combinarlo con `--dangerously-skip-permissions`
     (vulnerabilidad documentada, `google-antigravity/antigravity-cli#36`).
  3. **gentle-ai**: sin evidencia pública de que haya probado su deny-list contra un bypass real (docs
     y `e2e/` revisados, sin cobertura al respecto) — investigación con límite conocido (no se pudo
     buscar código de GitHub sin login).
  Además, evaluado (no probado, es criterio de diseño) que **no conviene generalizar el patrón del
  wrapper** a otros binarios sensibles (`git push`, deploys) — la superficie de flags es demasiado
  grande y variable por proyecto para un wrapper confiable; mejor invertir en que se cumpla el
  guardrail de confirmación humana ya existente. `TODO.md` reescrito como registro de método/hallazgos,
  ya no como lista de pendientes activos.
- **v0.26** — investigada la comparación con gentle-ai a fondo (a pedido del usuario) y encontrado el
  mecanismo real que faltaba para cerrar el hueco de v0.24 (subagente nativo con `mem_save` sin
  restricción). Confirmado que gentle-ai inyecta su deny-list en el `permissions.deny` nativo de
  `settings.json` de Claude Code — pero eso **no cubre subagentes del Task tool**, limitación real y
  documentada del propio Claude Code (`anthropics/claude-code#25000` "Sub-agents bypass permission deny
  rules — security risk", `#27661`, `#14714`, `#22665`): no heredan `permissions.deny` ni
  `PreToolUse` hooks del padre. gentle-ai tiene exactamente nuestro mismo problema, no lo resuelve.
  La única restricción técnica real por subagente es su propio `tools`/`disallowedTools`
  (confirmado en `code.claude.com/docs/en/sub-agents`). Creado `.claude/agents/safe-reviewer.md` —
  agente custom con `disallowedTools` bloqueando Bash/PowerShell/Edit/Write/NotebookEdit y los tools de
  escritura de Engram, para usar en jueces/lentes/reviewers de subagente nativo en vez de
  `general-purpose`. Excluye `Bash` a propósito (no solo los tools MCP) porque un subagente con Bash
  podría invocar el binario `engram` real directo, el mismo vector que usaban los CLIs externos.
  **No se pudo verificar en vivo** — Claude Code no detecta un `.claude/agents/` nuevo sin reiniciar la
  sesión; queda como único pendiente activo en `TODO.md` para la próxima sesión. Memoria #655
  actualizada con la comparación corregida.
- **v0.27** — verificado en vivo, mismo día: `safe-reviewer` sí se detectó sin reiniciar la sesión
  (el aviso de la doc sobre reinicio no aplicó acá). Lanzado un subagente real con
  `subagent_type: safe-reviewer`, pedido explícito de llamar `mem_save` y usar Bash para invocar
  `engram` — **ninguna de las dos herramientas aparece en su lista de tools**, ni de nivel superior ni
  entre las diferidas (`mem_search` sí, confirmando bloqueo selectivo). Cierra por completo el hallazgo
  de v0.24. `TODO.md` sin pendientes activos.
- **v0.28** — investigados y probados en vivo los equivalentes de "agente custom" para Codex y opencode
  (a pedido del usuario, siguiendo el patrón de `safe-reviewer` de Claude Code). Codex:
  `.codex/agents/safe-reviewer.toml` con `sandbox_mode = "read-only"`, invocado con `spawn_agent` desde
  una sesión Codex real — el intento de bash contra `engram mcp --tools=all` fue denegado por el
  sandbox del subagente (`attempt to write a readonly database`). Funcionó pese a issues públicos de
  `openai/codex` (#14579, #15250) que sugerían lo contrario — no reproducido en v0.147.0. opencode:
  `.opencode/agents/safe-reviewer.md` con `permission: {bash: deny}`, delegado desde una sesión real —
  Bash no aparece en su lista de tools ("restricción estructural"), cerrando el vector de bypass de
  v0.15/v0.16. Agy: sin mecanismo equivalente — un subagente/worker paralelo hereda exactamente la
  misma restricción de sandbox que el padre, confirmado con un intento de lectura fuera del proyecto
  (`Operation not permitted`, igual que el padre). Documentado en `SKILL.md` como mecanismo disponible
  para cuando estos CLIs necesiten auto-delegar de forma más segura — no cambia el patrón de
  lanzamiento estándar del Paso 4, que sigue siendo un proceso top-level por rol.
- **v0.29** — decisión del usuario, revierte el diseño de v0.15-v0.28: Engram deja de registrarse como
  servidor MCP en los CLIs lanzados vía Herdr. Motivo: el beneficio (que un CLI lanzado pudiera buscar
  memoria por su cuenta) era marginal — el orquestador ya hace `mem_search` antes de lanzar cualquier
  rol y puede pasar el contexto relevante directo en el prompt — y ese beneficio marginal había
  generado toda una ronda de trabajo de seguridad (wrapper, verificación de sandbox por CLI, agentes
  custom) para defender un acceso que no hacía falta dar. Aplicado: sacada la entrada `engram` de
  `~/.codex/config.toml`, `~/.config/opencode/opencode.jsonc`, `~/.gemini/config/mcp_config.json` —
  verificado con `codex mcp list` / `opencode mcp list` que ninguno lo ve más. `SKILL.md`: toda la
  sección de Engram (search abierto, wrapper, agentes custom) reemplazada por una nota corta explicando
  la decisión, con puntero al historial completo acá (v0.15-v0.28) para no perder el trabajo hecho. El
  wrapper y los agentes custom `safe-reviewer` de Codex/opencode quedan en el filesystem sin usar, por
  si se revierte esta decisión más adelante.
- **v0.30** — corregido puntero desactualizado en "Estado y ajustes": todavía decía que `TODO.md` tenía
  "un gap crítico sin corregir (el wrapper de Engram vive dentro del árbol del proyecto)", pero eso se
  cerró en v0.20 y `TODO.md` quedó sin pendientes activos desde v0.25. Reemplazado por una nota correcta
  apuntando a `TODO.md` como registro de método/hallazgos de la ronda v0.20-v0.29.
- **v0.31** — hallazgo real del primer patrón multi-agente completo corrido de verdad vía
  `sdd-implement` (3 CLIs externos en paralelo — Codex, opencode, Agy — escribiendo `sdd-propose`,
  `sdd-verify`, `sdd-archive`): `herdr agent send <target> <text>` solo tipea texto, **no presiona
  Enter** — confirmado en `herdr agent --help` ("agent send writes literal text; use pane run when
  you want command text plus Enter"). Los 3 CLIs quedaron con el prompt pegado en el input box sin
  arrancar hasta mandar `pane run <target> ""` (texto vacío, solo somete lo ya tipeado). Documentado
  en el Paso 4: usar `pane run`, no `agent send`, para mandar el prompt real de la tarea una vez
  verificado el arranque.
- **v0.32** — verificado a fondo el pendiente de `TODO.md` sobre Agy (lanzado de nuevo vía Herdr, en
  un directorio nuevo, pidiéndole crear 3 archivos y correr un comando de shell). Confirmado: la
  confirmación por acción **es el comportamiento default de Agy, no algo que trae `--sandbox`** — la
  nota anterior decía lo contrario. Sin `--sandbox`, cada archivo creado y cada comando de shell
  disparó su propio prompt bloqueante (4 prompts para 3 archivos + 1 comando, ninguno agrupado);
  además, la primera corrida en un directorio nuevo agregó un trust prompt único adicional. Corregida
  la nota de Agy en el Paso 4: un rol de Agy con capacidad de escritura no es fire-and-forget, hay que
  sondear y aprobar cada prompt — el sandbox nativo (`--sandbox`) suma fricción *adicional* a esta,
  no es la causa. `TODO.md` actualizado: el ítem queda cerrado.
- **v0.33** — cerrados los 5 hallazgos de `FEEDBACK.md` de earpi (sesión real corriendo
  `sdd-implement` sobre `001-auth-minima`, T001-T010). Dos verificados en vivo, tres aplicados como
  aclaración/mejora de diseño:
  1. **`revision` no sirve para detectar cambios de pane — confirmado en vivo**: `pane get`/`agent get`
     repetidos cada pocos segundos sobre un pane activo (spinner del terminal cambiando visiblemente
     entre lecturas) mostraron `revision` exactamente igual en todas las lecturas. Documentada la
     alternativa real en el Paso 4: `herdr wait agent-status --status ... --timeout MS` (bloqueante por
     transición de estado) o `herdr wait output <pane_id> --match <texto> --timeout MS` (bloqueante por
     contenido) en vez de polling manual por `revision`.
  2. **`status` es variable read-only en zsh — confirmado en vivo** (`zsh -c 'status=5'` da
     `read-only variable: status`, es alias de `$?`). Agregado como gotcha de shell junto a la nota de
     polling, para futuros snippets de ejemplo.
  3. **Timeout de 180s insuficiente cuando el ejecutor corre su propia verificación** (`bun test` en
     T009 con Codex). Agregada excepción explícita en el Paso 6: 300-600s (o `wait output --match`) para
     tareas donde el CLI lanzado corre comandos como parte de verificar su propio trabajo, distinto de
     "tarea de razonamiento largo".
  4. **Ambigüedad de "auth" en la lista de riesgo del Paso 2** — aclarado que se refiere a tocar
     credenciales/infra de auth *real* fuera de plan, no a escribir código de una feature de auth ya
     aprobada con `tasks.md` (la lectura literal forzaría re-confirmar tarea por tarea, contradiciendo el
     propósito de `sdd-implement`).
  5. **Sin mecanismo para fijar un roster de CLI restringido por proyecto** — agregada nota al Paso 4:
     chequear `.specify/memory/constitution.md` o `CLAUDE.md` del proyecto antes de asumir las 4 CLIs
     disponibles; si el usuario restringe verbalmente, sugerir persistirlo ahí para no repetirlo cada
     sesión.
  `TODO.md` actualizado: los 5 ítems de la sección "Feedback de uso real — earpi" quedan cerrados.
- **v0.34** — sin cambios de contenido en `SKILL.md`. Registrada en `TODO.md` la confirmación de una
  tercera ronda de `FEEDBACK.md` en earpi (US2, T015-T019): los fixes de v0.33 (esta skill) y v0.3
  (`sdd-implement`) funcionaron limpio en un run posterior — `herdr wait agent-status`/`herdr wait
  output` detectaron codex y opencode sin falsos timeouts, y la delegación con contrato fijo dio
  resultado correcto por tercera vez consecutiva (T008/T009, T015/T016). Sin fricción nueva.
- **v0.35** — ronda de exploración de `herdr --help` pedida por el usuario, dos hallazgos probados en
  vivo (creando y limpiando tabs/panes de prueba reales):
  1. **`herdr agent start` no reemplaza la secuencia `tab create` → `pane run`.** Probado con Codex
     real: sin `--tab` hace split 50/50 del tab actual; con `--tab` apuntando a un tab nuevo y vacío,
     igual dividió su pane root en vez de usarlo directo (confirmado con `pane layout`). Está pensado
     para varios agentes visibles a la vez en un mismo tab, no para "un tab nuevo por agente". Nota
     agregada en el Paso 4, junto a la secuencia de lanzamiento.
  2. **`agent_status`/`agent wait --status` no dan ninguna señal real para Agy — es un fallback
     estático.** `herdr agent explain <pane_id>` dio `rule: none` /
     `fallback_reason: default_known_agent_idle_fallback` de forma idéntica en tres momentos distintos
     (bloqueado en el trust prompt, recién booteado e idle de verdad, y a mitad de una tarea real en
     curso) — `agent list` reportó `agent_status: done` en los tres casos por igual, sin distinguir
     ninguno. Distinto de opencode (que sí tiene detección real, solo "poco confiable"): acá no hay
     ninguna regla del manifest de Agy que dispare nunca. Agregada nota en la fila de Agy de la tabla de
     CLIs y nota extendida en el Paso 4 — para Agy, nunca esperar por `agent wait --status`, solo `wait
     output --match` o lectura directa del pane. Documentado de paso `herdr agent explain` como
     herramienta de diagnóstico (qué regla disparó un status, o por qué cayó a fallback).
  `TODO.md`: nueva sección "Investigación de `herdr --help`" con estos dos hallazgos cerrados y tres
  candidatos identificados pero sin probar todavía (`herdr worktree` para aislar agentes de escritura
  en paralelo, `herdr notification show` para avisos de bloqueo, diferencias entre `agent rename` /
  `pane rename` / `tab rename`).
- **v0.36** — cerrados los 3 candidatos que quedaron pendientes de la ronda anterior, probados en vivo
  sobre el repo `herd` (todo limpiado sin dejar rastro):
  1. **`herdr worktree create/open/remove` confirmado como respuesta real al gap de escritura
     paralela.** `worktree create --branch ... --label ...` crea un worktree de git de verdad (visible
     con `git worktree list` desde el repo principal), en una workspace nueva de Herdr con su propio
     tab/pane. Aislación confirmada en ambos sentidos: un archivo escrito en el worktree no aparece en
     el `git status` del repo principal, y los cambios sin commitear del repo principal no se filtran al
     worktree. `worktree remove` se niega por defecto si queda algo sucio (requiere `--force`) — buen
     guardrail. Agregado como recomendación nueva en la sección de guardrails de escritura del Paso 4:
     aislar en un worktree por agente cuando 2+ corren en paralelo con capacidad de escritura sobre el
     mismo repo.
  2. **`herdr notification show` no es utilizable en este entorno.** Corre sin error pero devuelve
     `{"shown": false, "reason": "disabled"}` — no hay toggle en `config.toml` que lo explique, más
     probable que sea permiso de notificaciones del SO sin otorgar a Herdr. Documentado como advertencia,
     no como mecanismo disponible.
  3. **`agent rename` vs `pane rename`/`tab rename` — no son intercambiables.** Solo `agent rename` crea
     un alias direccionable de verdad (`agent get <name>` resuelve igual que por `pane_id`); `pane
     rename`/`tab rename` solo cambian una etiqueta visual, no sirven para direccionar (probado: `agent
     get`/`pane get`/`tab get` por esos labels fallan con `not_found`).
  `TODO.md`: sección "Investigación de `herdr --help`" queda cerrada del todo (v0.35-v0.36).
- **v0.37** — sin cambios de contenido en `SKILL.md`. Lectura de `https://herdr.dev/docs/agents/`
  (pedida por el usuario, "anotalo, luego lo pruebas" — registro, no prueba en vivo todavía) confirma
  con fuente oficial el hallazgo de Agy de v0.35-v0.36: "if no rule matches for a known agent, Herdr
  falls back to idle" — Agy es agente "screen manifest" puro, sin lifecycle hooks, según la tabla
  "Supported agents" de esa página. No cambia la conclusión práctica ya documentada, pero la explica.
  Registrado en `TODO.md` un pendiente nuevo, abierto: probar `herdr server update-agent-manifests` (o
  un override local en `~/.config/herdr/agent-detection/agy.toml`) para ver si mejora la detección del
  trust-prompt/confirmación de Agy, en vez de asumir que es un límite permanente.
- **v0.38** — actualización real de Herdr 0.7.4 → 0.8.0 (pedida por el usuario tras leer
  `https://herdr.dev/docs/agent-automation/`, que documentaba comandos que la versión instalada no
  reconocía) y reescritura de buena parte del Paso 4 con la superficie de comandos nueva, todo probado
  en vivo tras confirmar `herdr status` con `client`/`server` en 0.8.0 y `compatible: yes`:
  1. **Cerrado el pendiente de v0.37**: `herdr server update-agent-manifests` no arregla la detección
     de Agy — el manifiesto ya estaba `current`, no era un problema de caché. Repetido con Agy relanzado
     desde cero vía el `agent start --kind agy --pane` nuevo: mismo resultado que antes
     (`rule: none`), y encima `agent start` devolvió `idle`/`interactive_ready: true` mientras Agy
     seguía bloqueado en el trust-prompt sin resolver. `agent wait --until blocked` dio timeout siempre.
  2. **`herdr --skill` es la referencia oficial embebida en el binario** — más confiable que reconstruir
     sintaxis con `--help` + prueba y error para rondas futuras.
  3. **`$HERDR_ENV`/`$HERDR_WORKSPACE_ID`/`$HERDR_TAB_ID`/`$HERDR_PANE_ID`** reemplazan el `agent list`
     + matchear `terminal_id` a mano del Paso 0 — confirmados seteados en vivo en esta misma sesión.
  4. **`agent start --kind <cli> --pane <pane_id> -- <args>` sí reemplaza la secuencia vieja en 0.8.0**
     (a diferencia de la conclusión de v0.35 contra 0.7.4) — probado en vivo con Codex real: no hizo
     split (confirmado con `pane layout`), bloqueó hasta detectar el estado real (`blocked` por el
     trust-prompt), resuelto con `agent send-keys reviewer-test enter`, y `agent prompt ... --wait`
     sometió la tarea real y esperó su cierre en un solo comando, confirmado leyendo la respuesta.
  5. **Decisión explícita del usuario, registrada para que no se pierda**: el skill oficial de Herdr
     recomienda por default split en el tab actual en vez de tab nuevo por agente — se preguntó
     directamente y el usuario eligió mantener la convención existente de esta skill ("un tab nuevo por
     agente, nunca split").
  6. Comandos de espera renombrados (`wait agent-status`/`wait output` → `agent wait --until`/`pane
     wait-output`), `agent send` reemplazado por `agent prompt`/`agent send-keys`. Todo aplicado en
     `SKILL.md` con nota explícita de fallback a la sintaxis vieja si el server vuelve a estar <0.8.0.
  7. `herdr update --handoff` no sirve para instalaciones vía Homebrew (pide `brew upgrade` en su
     lugar) — el reinicio real del server lo hizo el usuario manualmente, fuera de esta sesión.
  `TODO.md`: nueva sección "Actualización de Herdr 0.7.4 → 0.8.0" cerrada del todo, y el pendiente de
  v0.37 sobre Agy también queda cerrado.
- **v0.39** — leída `https://herdr.dev/docs/integrations/` (pedido del usuario) y corregido un hallazgo
  desactualizado a partir de eso: la página clasifica a opencode en el grupo "lifecycle authority"
  (hooks reales), distinto de Claude Code/Codex/Agy ("session identity", sin autoridad real) — contradice
  la nota vieja de esta skill ("`agent wait` no es confiable" para opencode). Probado en vivo antes de
  tocar nada (pedido explícito del usuario, "antes de probar, ¿cómo se ejecuta el lanzamiento de un
  agente?"): lanzado opencode real, mandada una tarea real sin `--wait` para poder sondear a mitad de
  camino — `agent_status` pasó correctamente de `idle` a `working` (confirmado con `agent read` que
  generaba texto de verdad) y `agent explain` mostró `screen_detection_skip_reason:
  full_lifecycle_hook_authority`, y volvió a `idle` recién al terminar de verdad (14.0s, verificado
  leyendo la respuesta completa). Corregida la fila de opencode en la tabla de CLIs de `SKILL.md` y la
  mención en la nota de polling que lo daba como ejemplo de detección poco confiable. `TODO.md`: nueva
  sección con este hallazgo, con un candidato de baja prioridad sin probar (`herdr integration install
  antigravity-cli` para Agy — solo restauración de sesión, no arregla la detección de estado).
- **v0.40** — limpieza pedida por el usuario (`SKILL.md` había llegado a 495 líneas). Recortado el
  Paso 4 (donde estaba casi todo el peso, acumulado por rondas sucesivas de pruebas en vivo v0.33-v0.39
  con narración redundante de "cómo se probó") a 393 líneas totales — sin sacar contenido accionable ni
  el "por qué" de ninguna decisión, solo la narración del método de prueba (que ya vive completa acá en
  `CHANGELOG.md`) y los bloques de fallback a Herdr <0.8.0 (dead weight ahora que 0.8.0 es la versión
  confirmada; recuperable de v0.30-v0.38 si algún día hiciera falta). Las dos notas de Agy se
  consolidaron en una; corregida también la afirmación estática de "Estado y ajustes" ("sin pendientes
  activos, última ronda earpi v0.33-v0.34") que había quedado desactualizada — ahora apunta a `TODO.md`
  en vez de congelar un snapshot que se desactualiza en cada ronda nueva. Pasada de coherencia adicional
  (pedida por el usuario): encontradas y corregidas 2 referencias cruzadas rotas, preexistentes al
  recorte de hoy — "Blind dual-judge, punto 2 más abajo" (Paso 4) apuntaba mal de dirección, esa
  sección está en el Paso 3, más arriba; "Engram... ver más abajo" (tabla de CLIs) también apuntaba mal,
  la nota de Engram está más arriba. Trim adicional leve en el Paso 2 (aclaración de "auth" y nota de
  sandbox integridad/confidencialidad), sin sacar contenido, solo prosa más compacta.
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
