# Changelog — sdd-propose

- **v0.1** — first version. Adds the framing before the Spec Kit flow: receives a feature
  description, delegates directory creation and numbering to
  `.specify/scripts/bash/create-new-feature.sh`, and writes `proposal.md` with problema,
  alcance_incluye, alcance_excluye, archivos_afectados, riesgos, and rollback. Makes the value of
  `SPECIFY_FEATURE_DIRECTORY` explicit so `/speckit-specify` reuses the same folder, and requires
  reviewing the `agent-selection` risk list before indicating the next step. Keeps the proposal
  focused on the concrete case and limits clarifications to three, in line with the Spec Kit
  criteria and the repo constitution.
