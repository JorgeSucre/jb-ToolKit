# ADR-0004: Transactions

## Context

Before this iteration, a Storage migration's execution record
(`STORAGE_TXN_*`) was written to disk exactly once, at the very end of
`run_storage_management`, after everything — copying, verification,
disposal — had already happened. If the process died mid-migration (killed,
crashed, laptop closed, drive unplugged), no transaction record existed at
all: only the plan (what was *intended*) survived, never what actually
happened up to that point.

The Architecture Freeze asked for transactions to carry a UUID and progress
through an explicit lifecycle —
`planned → executing → copied → verified → committed → rolled_back → failed`
— specifically so that a future feature could detect an interrupted
migration without implementing resume itself yet.

## Problem

Two distinct problems surfaced while implementing this:

1. **The requested 7-state lifecycle doesn't match the engine's real control
   flow.** `storage_execute` copies and verifies each item synchronously, in
   the same loop iteration — there is no code-observable moment between
   "copied" and "verified" where a checkpoint could land; by the time either
   state would be written, the other has already happened too. `rolled_back`
   is a **per-item** automatic response to a copy failure (a counter,
   `STORAGE_TXN_ROLLED_BACK`), never a whole-transaction terminal outcome —
   a transaction with 3 verified items and 1 rolled-back item isn't "rolled
   back," it's partially successful.

2. Writing a `STATE` value the code structurally cannot produce is not a
   harmless simplification of the request — it's the state-machine
   equivalent of the false-success-message problem
   [Design-Principles.md](../Design-Principles.md)'s truthfulness principle
   exists to prevent. A future reader (or a future resume feature) trusting
   `STATE=copied` as a real signal would be trusting something the code
   never actually sets.

## Decision

Ship an **honestly reachable** 5-state lifecycle:
`planned → executing → committed | failed | cancelled`, checkpointed at
three real points:

- `txn_begin` sets `STATE=planned` and the caller exports immediately — a
  transaction record now exists on disk before any copying starts, which
  didn't happen before at all.
- Immediately before `storage_execute` runs, `STATE=executing` and export
  again — this is the actual crash window; a record stuck here with no later
  write is a genuine, discoverable "this migration was interrupted" signal.
- After `finalize_storage_result` determines the outcome, map it to a
  terminal `STATE` (`success`/`partial` → `committed`, `failed` → `failed`,
  `cancelled` → `cancelled`) and export once more, before the disposal
  decision — then `txn_finish` + a final export capture the complete record
  including disposal.

`txn_export` is idempotent (always overwrites the same file by
`STORAGE_TXN_ID`), so calling it three-plus times per migration costs
nothing. The per-item facts the 7-state request was trying to capture —
which items copied, which verified, which rolled back, which failed and why
— are preserved exactly as before: `STORAGE_TXN_VERIFIED` /
`STORAGE_TXN_FAILED` / `STORAGE_TXN_ROLLED_BACK` counts, plus named
`STORAGE_TXN_VERIFIED_ITEMS` / `STORAGE_TXN_FAILED_ITEMS` with reasons. They
were never lost — they just live as per-item facts, not top-level lifecycle
states, because that's what they actually are.

`STORAGE_TXN_UUID` (`uuidgen`) was added as requested, as a field inside the
record — the filename stays timestamp-based
(`<txn_id>.env`, e.g. `txn_2026-07-27_11-19-09.env`) so a technician can
still scan a directory listing and see what happened when at a glance. Dual
identifier, not a replacement.

## Alternatives considered

- **Restructure `storage_execute` into two explicit passes** (copy every
  item first, then verify every item) to make `copied`/`verified` real,
  distinct, checkpointable phases. This was seriously considered — it's the
  only way to make the full 7-state lifecycle honest. Rejected for now on
  cost/benefit: it's real surgery on an engine that had just been thoroughly
  tested (including the rollback path), for a benefit smaller than it looks.
  rsync is already idempotent — a future resume feature can simply re-run
  `storage_execute` against the persisted plan and get correct, efficient
  behavior (already-copied files are skipped by rsync's own quick check)
  without needing fine-grained phase tracking at all. Given the freeze's
  explicit "do not implement resume yet," paying the complexity cost now for
  a resume strategy that isn't the one that would actually get built later
  didn't clear the bar.
- **Silently truncate to 5 states without documenting why.** Rejected —
  this is exactly the kind of deviation the owner asked to have explained,
  not absorbed quietly.
- **Promote `rolled_back` to a possible terminal `STATE`** for
  all-items-failed transactions. Rejected: `finalize_storage_result`
  already has a correct, existing category for that case (`RESULT=failed`
  when `STORAGE_TXN_VERIFIED` is zero) — inventing a second name for the
  same outcome would be redundant, not additive.

## Consequences

- A future "detect an interrupted migration" feature has real signal to act
  on today: read `.jbtoolkit/transactions/*.env`, find any entry whose
  `STATE` is `planned` or `executing` with no later write — that's an
  interrupted transaction, full stop, no guessing about which items got how
  far.
- That same future feature's *response* to finding one is still open — most
  likely "safely re-run `storage::run_profile` against the recorded plan,"
  since nothing here prevents that. But this ADR does not promise
  finer-grained recovery (e.g., "resume from item 3 of 7") without the
  two-pass execute redesign above.
- `STORAGE_TXN_RESULT` (`success | partial | failed | cancelled`, unchanged
  from before this iteration) remains the fine-grained verdict; `STATE` is
  purely lifecycle phase. Code reading a transaction record should use
  `RESULT` to ask "how did it go" and `STATE` to ask "how far did it get."

## Future implications

If fine-grained resume becomes a real, prioritized need — not merely
possible — revisit the two-pass `storage_execute` redesign and extend
`STORAGE_TXN_STATE` to include real `copied`/`verified` checkpoints at that
point, updating this ADR rather than reinterpreting the current 5-state set
to mean something it doesn't.
