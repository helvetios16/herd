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

**Un (1) pendiente activo, de otra ronda distinta** (mecánica de lanzamiento multi-agente, no
seguridad de Engram): ver sección "Mecánica de lanzamiento multi-agente" más abajo — confirmación
interactiva de Agy por archivo escrito, sin `--sandbox`, todavía sin verificar a fondo.

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
- [ ] **Agy pidió confirmación interactiva por archivo escrito, sin `--sandbox`.** Al escribir
      `sdd-archive/SKILL.md` y `sdd-archive/CHANGELOG.md`, Agy mostró dos veces "Allow creation of
      this file? 1. Yes 2. No" — bloqueando el pane hasta aprobar con `herdr pane run <target> "1"`.
      Esto pasó con el comando default (`agy --model gemini-3.6-flash-high`, **sin** `--sandbox`).
      Contradice/afina la nota actual del Paso 4, que solo documenta esta fricción como consecuencia
      de agregar `--sandbox` — sugiere que la confirmación por escritura de archivo es un
      comportamiento default de Agy, independiente del sandbox. **No verificado a fondo todavía**:
      solo 2 confirmaciones observadas en una sola corrida, no se probó si es consistente en todo
      write, si depende de alguna config (`--dangerously-skip-permissions` u otra), ni si aplica
      igual a comandos de shell (no solo creación de archivos). Antes de dar por cerrado: repetir con
      Agy en un rol de escritura de nuevo y confirmar el patrón, luego actualizar la nota del Paso 4
      (tabla de CLI/modelo) para que quien lance Agy con capacidad de escritura sepa de antemano que
      hay que estar atento a estos prompts — mismo tipo de gotcha ya documentado para el hook de
      confirmación de Codex al primer arranque.

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
