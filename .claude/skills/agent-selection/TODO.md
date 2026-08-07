# TODO — seguridad (agent-selection)

Pendientes identificados durante la ronda de pruebas reales de la barrera de escritura a Engram (ver
`CHANGELOG.md` v0.15-v0.17 y la nota de Phyume "Herdr", sección "Restringir qué puede escribir un CLI
lanzado"). Ninguno de estos está aplicado todavía — quedan acá para no perderlos.

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

- [ ] **El guardrail de "no pegar secretos en los prompts" (Paso 4) nunca se probó de verdad.** Es
      texto, no algo verificado — a diferencia de la barrera de Engram, que sí se sometió a un intento
      de bypass real. Diseñar una prueba: mandar un prompt con un secreto de mentira a un CLI y
      confirmar que no queda expuesto en ningún log/output persistente de Herdr (`session-history.json`
      si `pane_history` está activo, por ejemplo).
- [ ] **La lista de riesgo del Paso 2** (`.ssh`, `.env`, CI/CD, infra, migraciones, etc.) tampoco se
      probó con un intento de bypass — solo se amplió la lista, nunca se verificó que un CLI lanzado
      realmente no pueda tocar esas rutas. Aplicar la misma metodología de prueba adversarial que se
      usó con Engram: lanzar un CLI, pedirle explícitamente que lea/escriba un archivo de esa lista, y
      confirmar qué pasa en la práctica. **Actualizar la expectativa**: la prueba de bypass del wrapper
      (v0.21) encontró que `-s workspace-write` de Codex solo bloquea *escritura* fuera del proyecto —
      la *lectura* fuera del workspace no está restringida (confirmado: Codex leyó
      `~/.local/share/agent-selection/restricted-bin/engram` sin problema, exit 0). Para archivos como
      `.ssh`/`.env` fuera del proyecto, esto probablemente significa que un CLI lanzado SÍ puede leerlos
      igual, aunque no pueda modificarlos — hay que probarlo para confirmar, no asumir que "está fuera
      del proyecto" alcanza como barrera de confidencialidad. Si está *dentro* del proyecto, como un
      `.env` del propio repo, el sandbox no ayuda en nada (ni lectura ni escritura).

## Medio

- [ ] **`/tmp` queda escribible bajo `-s workspace-write`** (confirmado en la prueba). No afecta a
      Engram (su DB no vive ahí) pero es una vía abierta si en algún momento se necesita bloquear
      *cualquier* escritura fuera del proyecto, no solo la de un binario puntual.
- [ ] **opencode y Agy no tienen un sandbox nativo equivalente al de Codex** (`-s workspace-write`) —
      dependen enteramente del wrapper por `PATH`, que a su vez depende de que su herramienta de shell
      siga heredando el entorno del proceso padre. Si en una versión futura de cualquiera de los dos
      cambia ese comportamiento (como ya pasó con Codex, que empezó a reconstruir su propio entorno),
      la barrera se rompe en silencio sin que nada lo avise. Investigar si opencode/Agy tienen su
      propio mecanismo de sandbox/permisos nativo (no genérico de shell) que sea más robusto que el
      wrapper por `PATH`.
- [ ] **El wrapper solo cubre el binario `engram`.** Los guardrails de seguridad del Paso 4 hablan en
      general de "nunca comandos destructivos/de producción sin supervisión" — pero esa cobertura
      amplia sigue siendo texto/instrucción, no un mecanismo técnico como el que se armó para Engram.
      Evaluar si vale la pena generalizar el patrón del wrapper a otros binarios sensibles (`git push`,
      scripts de deploy del proyecto, etc.) o si conviene un enfoque distinto para esos casos.

## Bajo / investigar

- [ ] **Verificar si gentle-ai probó su propio "Permissions" (deny-list) contra un bypass real** — se
      especuló en Phyume que es la misma clase de barrera blanda que la de acá, pero nunca se confirmó
      revisando su código/tests, solo su documentación pública.
- [ ] **Confirmar si Claude Code, cuando lanza subagentes nativos (Task tool) en vez de CLIs vía Herdr,
      tiene el mismo problema de fondo** — un subagente nativo con acceso a bash podría en teoría llegar
      al binario real de Engram igual que Codex, si no se lo restringe de alguna forma. No se probó
      todavía porque toda la ronda de pruebas fue vía Herdr con CLIs externos.
