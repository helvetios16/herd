# Changelog — sdd-propose

- **v0.1** — primera versión. Agrega el encuadre previo al flujo de Spec Kit: recibe una
  descripción de feature, delega la creación y numeración del directorio a
  `.specify/scripts/bash/create-new-feature.sh`, y escribe `proposal.md` con problema, alcance
  incluido, alcance excluido, archivos afectados, riesgos y rollback. Deja explícito el valor de
  `SPECIFY_FEATURE_DIRECTORY` para que `/speckit-specify` reutilice la misma carpeta, y obliga a
  revisar la lista de riesgo de `agent-selection` antes de indicar el siguiente paso. Mantiene la
  propuesta enfocada en el caso concreto y limita las aclaraciones a tres, en línea con los
  criterios de Spec Kit y la constitución del repo.
