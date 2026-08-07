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
