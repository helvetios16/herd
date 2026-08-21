# Changelog — sdd-judge

- **v0.1** — first version. New skill that adapts gentle-ai's `judgment-day` to this repo's own
  multi-agent framework: adversarial review with two judges blind to each other, launched via
  Herdr (reuses the Blind dual-judge operationalization and the CLI/model table already defined in
  `agent-selection`, doesn't duplicate them). A finding only counts as confirmed if both judges
  report it independently; if only one sees it, it stays "suspect" without being auto-fixed; if
  they contradict each other, it's escalated to the user. Bounded correction with explicit human
  confirmation before applying it, and a scoped re-judgment limited to the frozen ledger plus the
  fix's delta — hard cap of 2 total rounds, same as the original. No third refuter: agreement
  between the two judges is the corroboration mechanism. Explicit user decision: hard dependency on
  Herdr, no fallback to native subagents — the pattern's whole point is model independence
  (different CLIs/weights), which a same-provider fallback can't give; if Herdr isn't active, the
  step is skipped that round and the flow goes straight to `sdd-verify`. Runs between
  `sdd-implement` and `sdd-verify`, optional (doesn't block either one), written directly (without
  going through the repo's own SDD cycle) by the user's decision, since the design was already well
  defined from the prior conversation.
