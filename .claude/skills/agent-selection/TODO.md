# TODO — seguridad (agent-selection)

Pendientes identificados durante la ronda de pruebas reales de la barrera de escritura a Engram (ver
`CHANGELOG.md` v0.15-v0.17 y la nota de Phyume "Herdr", sección "Restringir qué puede escribir un CLI
lanzado"). **Estado: todos probados/investigados/aplicados** (v0.20-v0.25, ver `CHANGELOG.md`) — este
archivo queda como registro de método y hallazgos, no como lista de pendientes activos. Si aparece un
hallazgo nuevo, agregarlo acá con la misma metodología de prueba adversarial real, no especulación.

**Nota (v0.29)**: todo el trabajo de este archivo defendía un acceso que después se decidió sacar de
raíz — Engram ya no se registra como MCP en ningún CLI lanzado (ver `CHANGELOG.md` v0.29). Nada de lo
de acá quedó invalidado (el wrapper y los hallazgos siguen siendo correctos), simplemente dejó de
aplicar porque ya no hay una conexión de Engram que defender en Codex/opencode/Agy.

## Estado

Sin pendientes activos de la ronda de seguridad de Engram (Crítico/Alto/Medio/Bajo abajo). El último
ítem de esa ronda (`safe-reviewer`, v0.26) se verificó en vivo el mismo día: no hizo falta reiniciar
la sesión después de todo — el nuevo `.claude/agents/` se detectó solo.

La otra ronda distinta (mecánica de lanzamiento multi-agente, no seguridad de Engram — ver sección
"Mecánica de lanzamiento multi-agente" más abajo) también quedó sin pendientes activos: el ítem de
Agy se verificó a fondo y se cerró en v0.32.

La ronda de feedback de earpi (ver sección "Feedback de uso real — earpi" más abajo) también quedó
cerrada en v0.33: 2 de los 5 hallazgos se verificaron en vivo (`revision` de Herdr, gotcha de `status`
en zsh), los otros 3 se aplicaron como aclaración/mejora de diseño directa a `SKILL.md`.

Una segunda actualización de earpi (US1, T011-T014, ver sección "Feedback de uso real — earpi,
actualización US1" más abajo) también quedó cerrada: los 2 hallazgos son sobre la ejecución de fases
de `sdd-implement`, no de `agent-selection` — las correcciones se aplicaron en
`.claude/skills/sdd-implement/SKILL.md` (v0.2→v0.3), no acá. Uno de los dos se verificó en vivo, más a
fondo que el reporte original de earpi.

- [x] **Verificado en vivo: `.claude/agents/safe-reviewer.md` (`disallowedTools`) bloquea de verdad
      `mem_save` y `Bash`.** Lanzado un subagente real con `subagent_type: safe-reviewer`, pedido
      explícito de (a) buscar y llamar cualquier tool `mem_save*` y (b) usar Bash para invocar el
      binario `engram` real. Resultado: **ninguna de las dos herramientas aparece en su lista de tools
      disponibles** — ni de nivel superior ni entre las diferidas (`mem_search` sí sigue disponible,
      confirmando que el bloqueo es selectivo, no total). Cierra el hallazgo de v0.24: un subagente
      nativo lanzado como `safe-reviewer` ya no tiene el problema que sí tiene `general-purpose`.
      **Alcance importante**: esto solo protege la vía de subagentes nativos de Claude Code (Task tool)
      — no aplica a los CLIs externos (Codex/opencode/Agy) lanzados vía Herdr, que no tienen ningún
      concepto de "agente custom de Claude Code" ni leen `.claude/agents/`; esa vía sigue asegurada por
      el wrapper/sandbox de v0.20-v0.25, son dos superficies distintas.

## Crítico

- [x] **El wrapper vivía *dentro* del proyecto que los mismos CLIs pueden escribir** — movido a
      `~/.local/share/agent-selection/restricted-bin/engram` (fuera del árbol de cualquier repo) y
      actualizado el `PATH` inline del Paso 4 en `SKILL.md` en consecuencia.
- [x] **Prueba de bypass repetida con el wrapper en la nueva ruta** — Codex lanzado de verdad vía Herdr
      con `-s workspace-write` en `herd`, pedido explícitamente: escribir un archivo dentro del repo,
      leer el wrapper externo, y borrarlo. Resultado: escritura dentro del repo — éxito (exit 0);
      lectura del wrapper externo — éxito (exit 0, el sandbox no restringe lectura fuera del proyecto,
      solo escritura); **borrado del wrapper — falló**: `rm: .../restricted-bin/engram: Operation not
      permitted`. Confirma que la reubicación cierra el hueco: Codex puede escribir en el proyecto pero
      no puede tocar el wrapper.

## Alto

- [x] **El guardrail de "no pegar secretos en los prompts" (Paso 4), probado de verdad.** Lanzado
      opencode de verdad vía Herdr, mandado un prompt con un secreto de mentira (marcador único
      `sk-FAKESECRET-9f8e7d6c5b4a3210-TESTMARKER-ZZ`). Buscado el marcador en `herdr-server.log`,
      `herdr-client.log`, `session.json` y el resto de `~/.config/herdr/` (recursivo) — **cero
      coincidencias**, no queda expuesto en ningún archivo persistente de Herdr con la config default.
      Motivo confirmado en la doc (`herdr.dev/docs/session-state`): el contenido de los panes (lo que
      incluiría cualquier secreto pegado en un prompt) solo se persiste a disco si se activa
      `[experimental] pane_history` (**off por defecto**, no está seteado en `config.toml`), que escribe
      todo el scroll de los panes en texto plano a `session-history.json`. **Riesgo latente para el
      futuro**: si algún día se activa `pane_history` (para debug, por ejemplo) sin recordar esta nota,
      cualquier secreto pegado en un prompt a un CLI lanzado queda en texto plano en disco — no hay
      guardrail técnico contra eso, es responsabilidad de quien active la opción.
- [x] **La lista de riesgo del Paso 2, probada de verdad con Codex** (`-s workspace-write`). Creados dos
      señuelos con contenido falso: `~/.ssh/herd_test_decoy_key` (fuera del proyecto) y
      `./.env.test-decoy` (dentro del repo). Pedido explícito: leer y escribir cada uno. Resultado —
      **confirma exactamente la hipótesis de v0.21**:
      1. `cat ~/.ssh/herd_test_decoy_key` (leer, fuera del proyecto) — **éxito**, código 0.
      2. `echo >> ~/.ssh/herd_test_decoy_key` (escribir, fuera del proyecto) — **falló**:
         `operation not permitted`.
      3. `cat ./.env.test-decoy` (leer, dentro del proyecto) — éxito.
      4. `echo >> ./.env.test-decoy` (escribir, dentro del proyecto) — **éxito** (revertido por el
         propio Codex después, cooperativo, no por ningún mecanismo técnico).
      **Conclusión dura**: la lista de riesgo del Paso 2 (`.ssh`, `.env`, CI/CD, infra, migraciones) no
      tiene ningún respaldo técnico — es pura confianza en que el CLI respete el prompt. El sandbox de
      Codex (`-s workspace-write`) protege *integridad* (no puede escribir/tocar archivos sensibles
      fuera del proyecto) pero **no protege confidencialidad** (puede leer cualquier archivo fuera del
      proyecto al que el usuario del SO tenga acceso, y dentro del proyecto no hay ninguna restricción,
      ni de lectura ni de escritura). Señuelos limpiados después de la prueba, sin dejar rastro.

## Medio

- [x] **`/tmp` queda escribible bajo `-s workspace-write`** — reconfirmado con Codex real vía Herdr
      (v0.147.0): `echo ... > /tmp/herd-sandbox-tmp-test.txt` escribió, leyó y borró sin error, código 0.
      No afecta a Engram (su DB no vive ahí) pero sigue siendo una vía abierta si en algún momento se
      necesita bloquear *cualquier* escritura fuera del proyecto, no solo la de un binario puntual.
- [x] **Investigado y probado: opencode NO tiene sandbox nativo; Agy SÍ, y es más fuerte que el de
      Codex.**
  - **opencode**: confirmado que no existe. Hubo un PR experimental
    (`anomalyco/opencode#21538`, "macOS bash command sandboxing", opt-in vía `experimental.sandbox`)
    pero **nunca se mergeó** — cerrado en mayo 2026 por inactividad. Sigue dependiendo enteramente del
    wrapper por `PATH` y de las reglas de `Permissions` (allow/deny/ask), ambas barreras blandas.
  - **Agy**: sí tiene (`--sandbox`), y **la skill no lo está usando** (`agy --model
    gemini-3.6-flash-high`, sin `--sandbox`). Probado en vivo, resultado más fuerte que Codex:
    en macOS usa `sandbox-exec` (mismo mecanismo de base que Codex) pero bloquea **lectura Y escritura**
    fuera del proyecto — `cat` de un señuelo fuera del proyecto dio `Operation not permitted` (Codex sí
    dejaba leer). Lectura/escritura dentro del proyecto: ambas éxito, igual que Codex.
  - **Gotcha real al activar `--sandbox` en Agy**: introduce un prompt de confirmación interactivo antes
    de cada comando de shell (aunque esté sandboxeado) — rompe el patrón de lanzamiento autónomo en
    background que usa el Paso 4 (`pane run` + esperar), salvo que se responda cada prompt o se
    seleccione "always allow" para el patrón de comando exacto. **Nunca combinar con
    `--dangerously-skip-permissions`** — vulnerabilidad documentada
    (`google-antigravity/antigravity-cli#36`): esa combinación deja que el modelo se auto-apruebe saltar
    el sandbox por completo, anulando la protección. No se cambió el comando de lanzamiento default de
    Agy en `SKILL.md` por este trade-off — documentado como opción para cuando se necesite aislamiento
    más fuerte y se pueda tolerar la fricción de las confirmaciones.
- [x] **Evaluado: no generalizar el patrón del wrapper a otros binarios (recomendación, no una
      prueba).** El wrapper de Engram funciona porque el caso es angosto y estable: un solo binario, una
      sola operación legítima a permitir (`mem_search`), superficie de flags chica y predecible — se
      pudo enumerar y bloquear todo lo demás con confianza. `git push`, scripts de deploy, etc. no
      comparten esas propiedades: superficie de flags mucho más grande, variación por proyecto, y un
      wrapper mal armado da falsa sensación de seguridad (peor que no tener nada, porque hace parecer
      resuelto algo que no lo está — confirmado en esta misma ronda que hasta el wrapper de Engram, bien
      angosto, dependía de *dónde* vivía el archivo, no solo de su lógica interna). Mejor invertir en que
      el guardrail de "nunca comandos destructivos sin supervisión" (Paso 4) se cumpla en la práctica —
      confirmación humana explícita antes de lanzar cualquier agente con esa capacidad — que en wrappers
      puntuales por binario. Si en el futuro aparece un caso concreto y angosto (no especulativo) que
      lo amerite, evaluarlo con la misma metodología de prueba adversarial usada en este TODO.

## Mecánica de lanzamiento multi-agente (hallazgos v0.30-v0.31)

Hallazgos de la primera corrida real de un patrón multi-agente completo vía `sdd-implement`
(Orquestador + 3 CLIs externos en paralelo — Codex, opencode, Agy — ver `CHANGELOG.md` v0.31).
Distinto en naturaleza del resto de este archivo (que es sobre la barrera de escritura a Engram) —
son hallazgos sobre la mecánica de lanzamiento del Paso 4, no de seguridad.

- [x] **`herdr agent send` no somete el prompt — resuelto en v0.31.** Los 3 CLIs quedaron con el
      prompt largo pegado en su input box sin arrancar (0 archivos escritos por varios minutos)
      hasta mandar `herdr pane run <target> ""` para completar el submit. Documentado en el Paso 4:
      usar `pane run`, no `agent send`, para el prompt real de la tarea.
- [x] **Verificado a fondo: Agy pide confirmación interactiva por acción (archivo o comando), sin
      `--sandbox` — es su comportamiento default, no algo que trae el sandbox.** Repetido el
      experimento en vivo (v0.32): Agy lanzado de nuevo vía Herdr en un directorio nuevo, pedido
      crear 3 archivos y correr un comando de shell (`date`), sin `--sandbox`. Resultado: **4 de 4
      acciones pidieron confirmación individual** (3 archivos + 1 comando), ninguna agrupada — más
      un **trust prompt único** ("Do you trust the contents of this project?") por ser la primera vez
      en ese directorio, que no había aparecido en el trial de `herd` porque Agy ya lo tenía confiado
      de sesiones anteriores. Contradecía la nota anterior del Paso 4, que atribuía la fricción de
      confirmación solo a `--sandbox` — corregido: la nota de Agy en el Paso 4 ahora dice
      explícitamente que un rol de Agy con capacidad de escritura no es fire-and-forget, hay que
      sondear (`agent read --source visible`) y aprobar cada prompt a medida que aparece, y que el
      sandbox nativo suma fricción *adicional* a la que ya existe por default.

## Feedback de uso real — earpi (v0.33, cerrado)

Hallazgos de una sesión real corriendo `sdd-implement` sobre `specs/001-auth-minima` en el proyecto
earpi (Setup + Foundational, T001-T010, 2026-08-09) — ver `FEEDBACK.md` en la raíz de ese repo. Distinto
en naturaleza del resto de este archivo: son gaps funcionales de `sdd-implement`/`agent-selection`
encontrados en uso real, no hallazgos de seguridad. Detalle completo de qué se aplicó en `CHANGELOG.md`
v0.33.

- [x] **Ambigüedad de "auth" en la lista de riesgo del Paso 2.** Aclarado en `SKILL.md`: se refiere a
      tocar credenciales/infra de auth *real* fuera de plan, no a escribir código de una feature de auth
      ya aprobada con `tasks.md` (la lectura literal forzaría re-confirmar tarea por tarea, contradiciendo
      el propósito de `sdd-implement`).
- [x] **`revision` no sirve para detectar cambios de pane — confirmado en vivo, no solo reportado.**
      Repetido `herdr pane get`/`agent get` cada pocos segundos sobre un pane activo (el spinner del
      terminal cambiaba visiblemente entre lecturas) — `revision` se mantuvo exactamente igual en todas
      las lecturas. La sesión de earpi había reportado que siempre devolvía `0`; acá dio `2` de forma
      constante, pero el patrón (no sube con cambios de contenido) es el mismo hallazgo. Documentada la
      alternativa real en el Paso 4: `herdr wait agent-status --status ... --timeout MS` o
      `herdr wait output <pane_id> --match <texto> --timeout MS`.
- [x] **Timeout de 180s insuficiente cuando el CLI externo corre su propia verificación.** Agregada
      excepción explícita en el Paso 6: 300-600s (o `wait output --match`) para tareas donde el ejecutor
      corre comandos (tests, build) como parte de verificar su propio trabajo — distinto de "tarea de
      razonamiento largo", que ya tenía cobertura ("más para tareas de razonamiento largas").
- [x] **Gotcha de shell: `status` es variable read-only en zsh — confirmado en vivo.**
      `zsh -c 'status=5; echo ok'` da `zsh:1: read-only variable: status`, exit 1 — es alias de `$?`.
      Agregado como nota en el Paso 4, junto a la guía de polling.
- [x] **No hay forma de fijar un roster de CLI restringido a nivel proyecto.** Agregada nota al Paso 4:
      chequear `.specify/memory/constitution.md` (proyectos con Spec Kit) o `CLAUDE.md` antes de asumir
      las 4 CLIs disponibles; restricción verbal puntual se sugiere persistir ahí si se espera repetir.
      No es una prueba en vivo — es una convención de diseño nueva, sin mecanismo previo que reemplazar.

## Feedback de uso real — earpi, actualización US1 (T011-T014) (v0.3 de sdd-implement, cerrado)

Segunda ronda de `FEEDBACK.md` en earpi, sesión nativa 2026-08-09, corriendo `sdd-implement` sobre
T011-T014 de `001-auth-minima`. Distinta de la ronda anterior en dónde aplica: son gaps de la
*ejecución de fases* (Paso 3 de `sdd-implement`), no de la elección de ruta/CLI de `agent-selection` —
las correcciones van en `.claude/skills/sdd-implement/SKILL.md`, ver `sdd-implement/CHANGELOG.md` v0.3.

- [x] **El cwd del Bash tool no persiste entre llamadas — confirmado en vivo, más a fondo que el
      reporte de earpi.** earpi reportó sospecha de reset ocasional (interleaving con otra tool). Acá
      se probó de forma aislada y determinista: `cd .../earpi/backend && pwd` en una llamada, seguido
      de `pwd` solo en la siguiente (sin ninguna otra tool en el medio) — **el cwd ya había vuelto** al
      working directory primario de la sesión. Repetido 3 veces seguidas, mismo resultado cada vez. No
      es "a veces por interleaving", es **cada llamada de Bash arranca en el working directory
      primario**, sin importar qué `cd` haya corrido antes. `cd` solo sobrevive dentro de la misma
      invocación compuesta (`cd /ruta && comando`), confirmado también en vivo. Documentado como
      precaución operativa en `sdd-implement` Paso 3.
- [x] **Infra externa (DB, contenedores) puede caer a mitad de una fase sin aviso — aplicado por
      extensión de un principio ya probado, no una prueba nueva.** earpi reportó que OrbStack/Docker
      cayó a mitad de T011 sin señal previa, detectado recién al fallar el test. `agent-selection` Paso
      6 punto 2 ya cubre esto para Herdr ("no hay señal proactiva, se detecta porque el siguiente
      comando falla o no responde — volver a chequear el estado antes de asumir otra cosa"). Extendido
      el mismo principio a `sdd-implement` Paso 3 punto 7 (fallos a mitad de fase): si una fase depende
      de infra externa corriendo, verificar que siga viva antes de asumir que el fallo es del código.

## Confirmación en producción — earpi, actualización US2 (T015-T019)

Tercera ronda de `FEEDBACK.md` en earpi, sesión nativa 2026-08-09, corriendo `sdd-implement` sobre
T015-T019 de `001-auth-minima`. A diferencia de las dos rondas anteriores, no trae fricciones nuevas —
confirma en un run posterior que los fixes de las dos rondas previas funcionan en la práctica. Sin
cambios de contenido en `SKILL.md`, solo este registro.

- [x] **Los fixes de v0.33 (`agent-selection`) y v0.3 (`sdd-implement`) funcionaron limpio.**
      `herdr wait agent-status <target> --status idle --timeout 480000` (codex) y
      `herdr wait output <target> --match <marcador> --regex --timeout 480000` (opencode) — el
      reemplazo documentado para el polling por `revision`/`agent wait` a secas — detectaron a ambos
      ejecutores sin falsos timeouts ni lecturas manuales de más. Sin fricción nueva para el patrón
      multi-agente en esta ronda.
- [x] **Delegación con contrato fijo, 3ª confirmación consecutiva.** T015 (opencode) y T016 (codex)
      dieron resultado correcto al primer intento con prompts autocontenidos que incluían el contrato
      exacto a testear — mismo patrón que ya había dado resultado limpio en T008/T009. Sin cambios: el
      patrón ya estaba documentado, esto es evidencia adicional de que sostiene.
- Un tercer punto de esa ronda (bug real de scoping `derive`/`onBeforeHandle` de Elysia en Direct
  inline, detectado por un test de contrato) queda **fuera de alcance a propósito** — earpi mismo lo
  marcó explícitamente como no hallazgo de `agent-selection`/`sdd-implement`, solo dato de proceso
  (correr tests reales después de implementar sigue pagando). No requiere cambio acá.

## Investigación de `herdr --help` — comandos no documentados (v0.35-v0.36, cerrado)

Ronda de exploración de `herdr --help` (y subcomandos) pedida por el usuario para ver qué mecanismos
de Herdr no estaban aprovechados todavía en esta skill. Dos hallazgos probados en vivo (creando y
limpiando tabs/panes de prueba reales, no especulación); otros candidatos (`herdr worktree`, `herdr
notification show`, `herdr integration status`) quedaron identificados pero sin probar a fondo — ver
más abajo.

- [x] **`herdr agent start` investigado y descartado como atajo de lanzamiento.** Probado en vivo con
      Codex real: sin `--tab`, hace split 50/50 del tab actual en vez de crear un tab nuevo. Con
      `--tab <id>` apuntando a un tab recién creado y vacío, **igual hizo split** del pane root de ese
      tab (confirmado con `pane layout`) en vez de usarlo directo. Conclusión: `agent start` está
      pensado para el caso "varios agentes visibles simultáneamente en un mismo tab", no para el patrón
      "un tab nuevo por agente" que usa esta skill — no reemplaza `tab create` → `pane run`. Aplicado en
      `SKILL.md` Paso 4, nota junto a la secuencia de lanzamiento.
- [x] **Confirmado con prueba real: `agent_status`/`agent wait --status` no funcionan en absoluto para
      Agy — es un fallback estático, no detección real.** `herdr agent explain <pane_id>` sobre un pane
      de Agy dio siempre `rule: none` / `fallback_reason: default_known_agent_idle_fallback` en los tres
      momentos probados: (1) bloqueado en el trust prompt inicial sin resolver, (2) recién booteado y
      genuinamente idle, (3) a mitad de una tarea real en curso (pedido de contar del 1 al 5, verificado
      que efectivamente estaba procesando). Los tres dieron **exactamente el mismo output**, y `herdr
      agent list` reportó `agent_status: done` en los tres casos por igual — ni siquiera distingue
      "bloqueado esperando input" de "trabajando" de "listo". Distinto de opencode (que sí tiene
      detección real, solo que "poco confiable" en algunos casos) — acá no hay ninguna señal detrás del
      status, el manifest (`agy.toml`) existe pero no tiene ninguna regla que dispare nunca. Aplicado en
      `SKILL.md`: nota nueva en la fila de Agy de la tabla de CLIs y nota extendida junto a la nota
      existente de confirmación-por-acción — la única señal confiable para Agy sigue siendo leer el pane
      o `wait output --match`, nunca `agent wait --status`.
      **De paso, hallazgo secundario**: `herdr agent explain <target> [--json]` es una herramienta de
      diagnóstico real y útil (muestra la regla exacta que disparó un status, o el motivo del fallback si
      no disparó ninguna) — documentado como referencia rápida en el Paso 4, junto a la nota de
      `revision`.
- [x] **`herdr worktree create/open/remove` confirmado como respuesta real al gap de escritura
      paralela.** Probado en vivo sobre el repo `herd`: `herdr worktree create --workspace wH --branch
      test/herdr-worktree-check --label wt-test --no-focus` creó un worktree de git real (visible con
      `git worktree list` desde el repo principal) en una workspace nueva de Herdr con su propio
      tab/pane, sobre una rama propia. Aislación confirmada en ambos sentidos: un archivo escrito dentro
      del worktree (`wt-isolation-test.txt`) no apareció en el `git status` del repo principal, y los 3
      archivos con cambios sin commitear del repo principal (los mismos de esta ronda) no se filtraron al
      `git status` del worktree. `herdr worktree remove --workspace ID` se negó por defecto por quedar
      sucio (`dirty_worktree_requires_force`), hubo que pasar `--force` — buen guardrail. Limpiado del
      todo: worktree removido, rama de prueba borrada (`git branch -D`), `git worktree list` vuelve a
      mostrar solo el repo principal. Aplicado en `SKILL.md`: guardrail nuevo en la sección de escritura
      del Paso 4, recomendando `herdr worktree` cuando 2+ agentes con capacidad de escritura corren en
      paralelo sobre el mismo repo.
- [x] **`herdr notification show` probado en vivo — no utilizable en este entorno.** Corrido con
      `--sound none`, devolvió `{"shown": false, "reason": "disabled"}` sin ningún error. Revisado
      `config.toml` completo — no hay ningún toggle de notificaciones ahí, la causa más probable es
      permiso de notificaciones del SO (macOS) no otorgado a Herdr, no una config de la skill. Aplicado
      en `SKILL.md`: nota junto a la de `agent rename` avisando que no depender de este mecanismo sin
      confirmar antes que las notificaciones del sistema estén habilitadas.
- [x] **`agent rename` vs `pane rename` vs `tab rename` — diferencia real confirmada en vivo, probada
      sobre el pane de esta misma sesión y revertida sin dejar rastro.** Solo `agent rename <target>
      <name>` crea un alias direccionable — después de renombrar, `herdr agent get <name>` resolvió
      igual que por `pane_id`. `pane rename <pane_id> <label>` y `tab rename <tab_id> <label>` solo
      cambian una etiqueta visual: probado que `agent get`/`pane get`/`tab get` por ese label fallan con
      `not_found` en los dos casos, siguen necesitando el id real. Revertido con `agent rename --clear`,
      `pane rename --clear` y `tab rename <id> 1` (label numérico default) — estado final idéntico al
      baseline (verificado con `agent get`/`pane get`/`tab get` antes/después). Aplicado en `SKILL.md`
      junto a la nota de `agent start`.

## Pendiente: reintentar detección de Agy vía `herdr server update-agent-manifests` (v0.37-v0.38, cerrado)

Hallazgo de lectura de doc, no de prueba en vivo — pedido por el usuario como "anotalo, luego lo
pruebas". `https://herdr.dev/docs/agents/` (sección "Detection manifests" / "Blocked state") confirma
con fuente oficial lo que ya se había probado empíricamente con Agy (`TODO.md`, ronda v0.35-v0.36):

> "Blocked detection is deliberately strict for screen-manifest agents. Herdr only marks `blocked` when
> the live bottom-buffer snapshot matches known visible approval, question, or permission UI. If no rule
> matches for a known agent, Herdr falls back to `idle`."

La tabla "Supported agents" de esa misma página confirma que **Agy es agente "screen manifest" puro**
(sin lifecycle hooks) — a diferencia de OpenCode/Pi/OMP/Kimi/Kilo/MastraCode, que sí tienen "state and
session" completo. Esto encaja con lo ya confirmado: `rule: none` /
`fallback_reason: default_known_agent_idle_fallback` en los tres estados probados (bloqueado en trust
prompt, idle real, trabajando). No cambia la conclusión práctica (para Agy, nunca confiar en
`agent_status`/`agent wait --status`), pero explica que es un límite conocido del mecanismo de
manifiestos, no un bug sin explicación.

**Lo nuevo, sin probar todavía**: la misma página documenta dos comandos que podrían mejorar esto, no
solo explicarlo:
- `herdr server update-agent-manifests` — trae actualizaciones remotas de manifiestos de detección; el
  manifiesto de Agy visto en vivo (`agy.toml 2026.06.24.1`) podría estar desactualizado respecto al que
  ofrece `herdr.dev` ahora.
- Override local en `~/.config/herdr/agent-detection/agy.toml` — "Local overrides always win"; si el
  manifiesto remoto sigue sin cubrir la pantalla de confirmación/trust-prompt de Agy, se podría escribir
  una regla propia.

- [x] **Cerrado en v0.38 — probado en vivo, `update-agent-manifests` NO arregla la detección de Agy.**
      De paso se actualizó Herdr entero de 0.7.4 a 0.8.0 (ver sección siguiente), lo que reinició el
      server y permitió correr `herdr server update-agent-manifests` de verdad. Resultado: `agy` ya
      figuraba `current` (`2026.06.24.1`, mismo que antes) — no era un problema de caché desactualizada,
      el manifiesto remoto simplemente no tiene ninguna regla para el trust-prompt/confirmación de Agy.
      Repetida la prueba con Agy relanzado desde cero en un directorio nuevo (vía el `agent start
      --kind agy --pane` nuevo de 0.8.0): mismo resultado que en v0.35-v0.36 (`rule: none`,
      `fallback_reason: default_known_agent_idle_fallback`), y **encima el propio `agent start` devolvió
      `agent_status: idle`/`interactive_ready: true` mientras Agy seguía en el trust prompt sin
      resolver** (confirmado leyendo el pane). `agent wait --until blocked` dio timeout siempre, nunca
      lo detectó. Sigue sin probar el override local (`~/.config/herdr/agent-detection/agy.toml`) — se
      deja como candidato de una ronda futura si se necesita cerrar esto del todo, pero ya no es
      prioritario: la skill documenta bien el workaround (leer el pane, nunca confiar en
      `agent_status`/`agent wait`/el retorno de `agent start` para Agy).

## Actualización de Herdr 0.7.4 → 0.8.0 y superficie de comandos nueva (v0.38, cerrado)

Pedido explícito del usuario tras leer `https://herdr.dev/docs/agent-automation/` (que documentaba
`--kind`, `agent prompt`, `agent send-keys`, `pane wait-output` — comandos que la versión instalada
0.7.4 no reconocía, confirmado probándolos en vivo antes de actualizar). Actualización hecha con
`brew upgrade herdr` (0.7.4 → 0.8.0, bottled) + reinicio del server (confirmado por el usuario, no por
esta sesión — `herdr update --handoff` está deshabilitado para instalaciones vía Homebrew, pide
`brew upgrade` en su lugar). Verificado post-reinicio: `herdr status` da `client.version: 0.8.0`,
`server.version: 0.8.0`, `compatible: yes` — la sesión de esta skill siguió viva sin cortes.

- [x] **`herdr --skill` es la referencia oficial y autoritativa, embebida en el binario mismo.**
      Descubierto vía `--help` (nuevo flag `--skill`, "Print the agent skill file and exit"). Trae
      instrucciones completas versionadas junto con el CLI instalado — más confiable que la doc web para
      la sintaxis exacta. Recomendación para rondas futuras: correr `herdr --skill` primero en vez de
      reconstruir la sintaxis a mano con `--help` + prueba y error.
- [x] **`$HERDR_ENV`/`$HERDR_WORKSPACE_ID`/`$HERDR_TAB_ID`/`$HERDR_PANE_ID` — mecanismo oficial y más
      simple para el chequeo del Paso 0.** Confirmado en vivo: `$HERDR_ENV=1` dentro del pane de esta
      sesión, con los 3 IDs ya seteados. Reemplaza el `agent list` + matchear `terminal_id` a mano que
      usaba el Paso 0 hasta ahora. Aplicado en `SKILL.md`.
- [x] **`agent start --kind <cli> --pane <pane_id> -- <args>` (nuevo en 0.8.0) sí reemplaza la
      secuencia vieja — a diferencia de lo concluido en v0.35 contra 0.7.0.** Probado en vivo con Codex
      real: `tab create` (pane root vacío) → `agent start reviewer-test --kind codex --pane <root_pane>
      -- -m gpt-5.6-luna -c model_reasoning_effort="high" -s workspace-write` — confirmado con
      `pane layout` que **no hizo split** (un solo pane en el tab), y bloqueó hasta detectar el estado
      real (`blocked`, por el trust-prompt de Codex). Con `agent send-keys reviewer-test enter` se
      resolvió el prompt, y `agent prompt reviewer-test "Cuenta del 1 al 5..." --wait --timeout 60000`
      sometió la tarea real y esperó su cierre en un solo comando (2.5s), confirmado leyendo la
      respuesta real con `agent read`. **Importante**: el retorno de `agent start` solo confirma que
      Herdr reconoció *algún* estado (incluyendo `blocked`), no que esté listo para la tarea real — hay
      que revisar `agent_status` de la respuesta antes de mandar el prompt.
- [x] **Para Agy específicamente, `agent start` no es confiable ni con 0.8.0** — ver hallazgo cerrado
      arriba (`update-agent-manifests`). Documentado explícitamente en `SKILL.md`.
- [x] **`agent prompt <target> "<texto>" --wait --timeout MS` reemplaza `pane run` + espera manual.**
      Probado en vivo (ver punto anterior) — atómico, con detección de stall (`agent_prompt_stalled` si
      no hay cambio de ciclo de vida en 5s desde un estado no-`working`).
- [x] **`agent send-keys <target> <tecla>` reemplaza `pane run <target> "1"` para aprobar prompts de
      confirmación de CLIs (Agy, hooks de Codex).** Probado en vivo con Codex (`enter` resolvió el
      trust-prompt). Más seguro que `pane run`/`pane send-keys` a ciegas: Herdr valida la tecla y
      rechaza si el agente ya no controla el pane.
- [x] **Decisión de diseño explícita del usuario**: mantener la convención "un tab nuevo por agente,
      nunca split" — el skill oficial de Herdr recomienda por default lo contrario (split en el tab
      actual, sin crear tabs nuevos salvo pedido explícito). Se preguntó directamente y el usuario eligió
      mantener la convención existente de esta skill. `SKILL.md` sigue usando `tab create` (pane root
      vacío) antes de `agent start --pane`, nunca `pane split`.
      **Registrado explícitamente para que una ronda futura no "corrija" esto sin saber que fue una
      decisión consciente, no un descuido.**
- [x] **Comandos de espera renombrados en 0.8.0**: `herdr wait agent-status`/`herdr wait output`
      (nivel top, `--status`) pasan a `herdr agent wait` (`--until`, repetible, default
      `idle`/`done`/`blocked` sin necesidad de pasarlo) y `herdr pane wait-output` (mismo rol que el
      viejo `wait output`, ahora bajo `pane`). `agent send` (solo tipeaba, no sometía) ya no existe como
      tal, reemplazado por `agent prompt`/`agent send-keys`. Todo aplicado en `SKILL.md`, con nota
      explícita de fallback a la sintaxis vieja si algún día el server vuelve a estar en <0.8.0.
- [x] **`herdr update --handoff` no sirve para instalaciones vía Homebrew** — probado en vivo, devuelve
      `self-update is disabled for Homebrew installs; run 'brew update && brew upgrade herdr'`. No hay
      un comando de "reiniciar el server con handoff" separado para este caso — solo `herdr server
      stop` (corte duro) o que el usuario lo reinicie manualmente. El usuario optó por reiniciarlo él
      mismo fuera de esta sesión.

## Lectura de `https://herdr.dev/docs/integrations/` y corrección de opencode (v0.39)

Pedido del usuario: analizar esa página antes de decidir si valía la pena reprobar la confiabilidad de
`agent_status` en opencode (nuestra nota decía "no es confiable", pero la página oficial clasifica a
opencode en el grupo "lifecycle authority" — hooks reales — junto a Pi/OMP/Kimi/Kilo/MastraCode, a
diferencia de Claude Code/Codex/Agy que solo tienen "session identity"). Se pidió probarlo en vivo antes
de tocar nada.

- [x] **Confirmado en vivo: la nota de opencode estaba desactualizada — sí tiene detección de estado
      real y confiable.** Lanzado opencode real (`agent start --kind opencode --pane <root_pane> --
      -m opencode/deepseek-v4-flash-free`), confirmado `interactive_ready` genuino con `agent read`.
      Mandada una tarea real con `agent prompt` (sin `--wait`, a propósito, para poder sondear el estado
      a mitad de camino): `agent_status` pasó correctamente de `idle` a `working` mientras el pane
      mostraba el spinner "Thinking" generando texto de verdad, y `herdr agent explain` mostró
      `screen_detection_skip_reason: full_lifecycle_hook_authority` — confirma que Herdr ni siquiera usa
      el screen-manifest acá, tiene autoridad de hook real. Al terminar la tarea (14.0s reportados por el
      propio opencode), `agent_status` volvió a `idle` — verificado leyendo la respuesta completa en el
      pane, coincide con "tarea realmente terminada", a diferencia del fallback estático de Agy. Único
      matiz real: hay un lag breve (bajo 1s) entre someter el prompt y que el hook reporte `working` por
      primera vez — no afecta a llamadas bloqueantes (`agent prompt --wait`/`agent wait`), solo a un
      `agent get` suelto sin esperar justo después de someter.
      Aplicado en `SKILL.md`: corregida la fila de opencode en la tabla de CLIs y la nota de la sección
      de polling que lo mencionaba como ejemplo de detección poco confiable (ahora solo queda Agy ahí).
- [x] **De paso, la página confirmó y explicó por qué Claude Code/Codex funcionan bien pese a estar en
      "session identity" (sin hooks reales) — no hace falta acción, es contexto que ya encajaba con lo
      observado.** Confirma que la fiabilidad real depende de si el manifiesto de screen-detection de
      cada CLI matchea su pantalla, no de la categoría oficial por sí sola — Agy también es "session
      identity" y ahí sí falla (ver hallazgo cerrado en la sección anterior).
- [ ] Sin probar: `herdr integration install antigravity-cli` (nombre correcto de la integración de Agy,
      no `agy`) — según la doc solo da restauración de sesión (`agy --conversation <id>`), no
      arreglaría la detección de estado (Agy sigue en "session identity", no "lifecycle authority"). Baja
      prioridad, no cierra el problema ya documentado.

## Roster de CLI: Agy sale, segunda instancia de Claude Code entra (v0.41)

Decisión explícita del usuario, motivada directamente por los hallazgos de esta misma sesión (rondas
v0.35-v0.39): la detección de estado de Agy nunca funcionó de verdad (fallback estático confirmado 4
veces, incluso tras actualizar Herdr a 0.8.0 y sus manifiestos), al punto de contaminar `agent_start` y
`agent wait`. Se preguntó explícitamente qué rol cubriría el reemplazo antes de tocar nada, dado que
Sonnet 5 no es un modelo barato (mismo que ya usa el orquestador) — el usuario eligió la opción
recomendada.

- [x] **Agy sacada del roster activo de `SKILL.md`** (tabla de "Modelos fijos por CLI" y las notas
      operativas asociadas). El hallazgo completo de por qué (detección rota) sigue documentado arriba
      en este archivo y en `CHANGELOG.md` v0.30-v0.39 — no se borró nada, solo dejó de ser parte del
      roster por defecto.
- [x] **Claude Code agregado como cuarta opción lanzable** (`agent start --kind claude`), distinta de
      su rol implícito de orquestador (esta misma sesión). Documentado un matiz nuevo: como juez da
      independencia de *proceso/contexto* (contexto fresco), no de *modelo* (mismo proveedor que el
      autor si el autor también es Claude Code) — preferir Codex/opencode para blind dual-judge donde
      la independencia de modelo es el punto; reservar Claude#2 para ejecutor del patrón 1 o
      aislamiento de contexto del patrón 5.
- [x] **opencode pasa a ser el minion barato de model tiering** (patrón 4, Paso 3) en el lugar que
      dejaba Agy — decisión consistente con el hallazgo ya cerrado de que opencode tiene detección de
      estado confiable de verdad (autoridad de hook real) y corre gratis (DeepSeek V4 Flash Free).

## Actualización de Herdr 0.8.0 → 0.8.2 y hallazgos del CHANGELOG.md oficial (v0.42)

Pedido explícito del usuario: primero actualizar Herdr, después investigar el 0.8.2 en la web y aplicar
lo relevante a `SKILL.md`.

- [x] **Actualización real, mismo procedimiento que v0.38.** `brew upgrade herdr` (0.8.0 → 0.8.2,
      bottled). `herdr status` antes de reiniciar mostró `client.version: 0.8.2`, `server.version: 0.8.0`,
      `compatible: no`, `restart_needed: yes` — el binario del server en memoria no se actualiza solo con
      el `brew upgrade`. Probado `herdr update --handoff`: mismo resultado que en v0.38, deshabilitado
      para instalaciones Homebrew (`self-update is disabled for Homebrew installs`). Preguntado
      explícitamente al usuario si reiniciaba esta sesión el server (`herdr --handoff`) o lo hacía él
      mismo, dado que el server es compartido con otros tabs/panes — el usuario lo hizo manualmente.
      Confirmado después: `herdr status` → `client.version`/`server.version: 0.8.2`, `compatible: yes`,
      `restart_needed: no`.
- [x] **Fetch de la página de releases de GitHub dio contenido no confiable — corregido leyendo el
      `CHANGELOG.md` crudo.** `WebFetch` contra `github.com/herdrdev/herdr/releases/tag/v0.8.2` devolvió
      una fecha imposible (2024, cuando la versión y el resto del historial ubican el release en
      2026-08-19) y features que no aparecen en ningún otro lado (mención de integración nativa Windows
      para "Hermes Agent"/"MastraCode" sin más contexto) — indicio de resumen alucinado por el modelo
      chico que procesa el fetch, no de la página en sí. Recuperado leyendo
      `raw.githubusercontent.com/herdrdev/herdr/master/CHANGELOG.md` directo con `curl` (texto crudo, sin
      pasar por resumen de modelo) — ahí sí el release `[0.8.2] - 2026-08-19` tiene números de issue reales
      y créditos de contribuidores consistentes con el resto del changelog (formato `(#NNNN, thanks
      @usuario)`), mucho más confiable. **Lección para rondas futuras**: para un changelog o release
      notes de una herramienta que este archivo cita como fuente, preferir el archivo crudo (`raw.
      githubusercontent.com`, `git show`) antes que dejar que `WebFetch` lo resuma — más barato de
      verificar y evita este tipo de alucinación silenciosa.
- [x] **Dos hallazgos con impacto directo en `SKILL.md`, aplicados sin prueba en vivo propia** (a
      diferencia de v0.38/v0.39 — acá se confía en el número de issue del changelog oficial, no se
      repitió la prueba adversarial real):
      1. Prompts de confirmación nativos de Claude Code (`Enter to confirm · Esc to cancel`) ahora
         reportan `blocked` en vez de `idle` (issue #2268) — agregado como ejemplo en la nota de
         `agent start` del Paso 4, junto al de Codex. Relevante porque Claude#2 (agregada como juez en
         v0.41) puede toparse con este mismo tipo de prompt.
      2. `send-keys ... shift+tab` preserva el Shift al enviarse (antes se perdía, issue #1561) — permite
         ciclar el modo de permisos de un agente por comando. Agregado como nota corta en el Paso 4.
- [ ] **Pendiente de verificación en vivo, baja prioridad**: confirmar el fix de Claude Code (#2268) con
      una prueba real — lanzar Claude#2 vía `agent start --kind claude`, forzar un prompt de
      confirmación real, y leer `.result.agent.agent_status` para comprobar que da `blocked` y no
      `idle`. No bloqueante: el hallazgo viene de un changelog oficial con número de issue, no de
      especulación, pero esta skill privilegia prueba real sobre fuente externa cuando hay tensión
      (ver preámbulo de `SKILL.md`).
- [x] **Otros dos hallazgos del changelog evaluados y descartados para `SKILL.md`** (no invalidan ni
      corrigen ninguna guía activa del archivo):
      - Fix de carrera en `agent start` esperando que el pane/shell y el primer prompt del agente estén
        listos antes de reportar éxito (issues #2410, #2537, #2773, #2774) — la guía actual de
        `SKILL.md` ("que devuelva no significa listo para la tarea real, revisar `agent_status`") ya
        cubre este caso independientemente de si la carrera existía o no; no había ningún workaround
        documentado acá que este fix vuelva obsoleto.
      - OpenCode ahora trackea su propia conversación raíz para restore nativo sin heredar actividad de
        clientes adjuntos (issue #2450) — es sobre *restore de sesión*, un tema distinto de la nota ya
        existente sobre confiabilidad de *detección de estado* (`agent_status`) de opencode, que sigue
        vigente desde v0.38 sin cambios.

## Bajo / investigar

- [x] **Investigado (sin poder confirmar del todo): no se encontró evidencia de que gentle-ai haya
      probado su "Permissions" (deny-list) contra un bypass real.** Revisada la documentación pública
      (`docs/agents.md`, `docs/components.md`) y el directorio `e2e/` del repo — ningún archivo ni
      mención relacionada con "bypass", "adversarial", "security test" o similar; el `e2e/` solo tiene
      Dockerfiles de smoke-test por distro (`Dockerfile.arch`, `.fedora`, `.ubuntu`,
      `Dockerfile.claude-network-none`) y un script `docker-test.sh`/`e2e_test.sh`, no pruebas de
      bypass de permisos. **Limitación de esta investigación**: no se pudo hacer búsqueda de código de
      GitHub (`*_test.go` con "permission") por requerir login — no se descartó al 100% que exista un
      test unitario de Go cubriendo esto en `internal/`, solo que no aparece en la documentación ni en
      `e2e/`. Su deny-list default sí es más específica que la lista de riesgo de esta skill (incluye
      `~/Library/Keychains/*`, `.p12`, `.pfx`) — vale la pena tomarla como referencia para ampliar la
      lista de riesgo del Paso 2 en algún momento, aunque no es parte de este TODO de seguridad.
- [x] **Confirmado: un subagente nativo de Claude Code (Task tool) tiene escritura sin ninguna
      restricción en Engram.** Probado en vivo: un subagente `general-purpose` lanzado con el Task tool
      (no vía Herdr) pudo (a) llamar `mcp__plugin_engram_engram__mem_save` directo y guardar una memoria
      real sin ningún gate — limpiada después con `engram delete <id> --hard`; y (b) ejecutar el binario
      real `engram mcp --tools=all` por Bash sin ningún bloqueo de sandbox/permisos. A diferencia de los
      CLIs externos (Codex/opencode/Agy), acá **no hay wrapper por `PATH` ni sandbox nativo que aplique**
      — un subagente nativo corre con el mismo nivel de confianza que la sesión orquestadora.
      **No es necesariamente un bug**: el diseño original de Engram (Paso 4, "search abierto, save
      centralizado en el orquestador") ya asumía que la restricción técnica solo hacía falta contra CLIs
      *externos* potencialmente adversariales — un subagente nativo es "nosotros mismos". Pero el texto
      del guardrail nunca decía esto explícitamente para subagentes de Task tool, solo hablaba de CLIs
      vía Herdr. **Aplicado**: aclarado en `SKILL.md` que `mem_save` queda reservado a la sesión
      orquestadora *incluyendo* cuando delega a subagentes nativos — un subagente lanzado con el Task
      tool no debería llamar `mem_save` directo, debe reportar hallazgos de vuelta al orquestador.
