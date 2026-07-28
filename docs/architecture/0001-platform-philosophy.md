# ADR-0001: Platform Philosophy

## Context

JB Toolkit grew as five independent module scripts sharing a foundation
(`core/utils.sh`) and a UI layer (`core/bootstrap/ui.sh`), plus one additional
shared library (`core/deployment/*`, consumed by both the Deployment module
and Bootstrap's onboarding wizard). That shape served the toolkit well through
v2.0.1: each module owns a complete, independent workflow, and the only
cross-module channel is `logs/state.env`.

The Storage subsystem — built to migrate a client's Home folder to an
external drive before a repair — outgrew that shape. It needed its own
identity concept (an external volume that stays recognized across sessions),
its own execution record (a transaction, separate from what merely was
*planned*), and a growing family of things it could migrate (Home today;
Photos Library, Steam Library, Docker, VMs, Cloud Sync, Backups, and Media
Libraries named as likely next). The owner asked for this to be treated as
the **Architecture Freeze**: not a feature iteration, but the point where the
project deliberately establishes a Platform layer beneath its modules —
Storage becomes the first tenant, with State, Metrics, Logging, Report,
Events, and Config named as candidates that would join later.

## Problem

Two problems, not one:

1. **Immediate**: Storage's logic (volume adoption, the migration pipeline)
   was becoming a de facto shared capability without a shared-capability
   *contract* — nothing stopped a future module from reading
   `.jbtoolkit` directly, or duplicating "how do I find an external APFS
   volume" logic, the same way the project already avoided duplicating
   catalog access by consolidating it into `core/deployment/*`.
2. **Structural**: the project's existing extension points
   (`core/<module>/*` sub-modules, `core/deployment/*` as a library) don't
   name a place for infrastructure that isn't owned by any one module and
   isn't a workflow with its own menu entry. Without naming that place, each
   future cross-cutting need (state, metrics, config...) would either bolt
   onto an unrelated module or duplicate itself per-module.

## Decision

Introduce `core/platform/<service>/` as the home for reusable infrastructure
with its own public API, one level below modules:

```
Platform            core/platform/<service>/   — reusable services, own API
      ↓
Shared Services      core/<module>/* + core/deployment/*, core/bootstrap/ui.sh
      ↓
Modules              core/bootstrap.sh, diagnostics.sh, maintenance.sh, deployment.sh, report.sh
      ↓
User Features         the menus, prompts, and workflows those modules present
```

A Platform service is warranted when the same bar the project already applies
to shared code in `core/utils.sh` is met — "two or more consumers, and
consolidating makes the total code smaller, and introduces no new
abstraction" — **or** when the owner makes as explicit a request as the one
that created Storage. Storage qualifies on the second ground today; it does
not yet have a second real consumer. That's an accepted, named exception (see
[Design-Principles.md](../Design-Principles.md), principle 7's "Deliberate
exception"), not a new default.

**Only Storage is implemented.** State, Metrics, Logging, Report, Events, and
Config are named here as the shape future work would take *if* it's ever
warranted — no directories, no stub files, no placeholder functions. Git
doesn't track empty directories, and an empty scaffold signals "started" when
nothing has. The bar for actually building one of these is the same one
above: a demonstrated second consumer, or an equally explicit request.

`BASE_DIR` (computed once by whichever entry point runs first, exported,
reused by every child process and Platform service) already fulfills the role
a "platform root" would play. It is not renamed to `JB_ROOT` or anything
else — the existing name works, is already exported, and a rename would touch
dozens of files for no functional gain.

## Alternatives considered

- **Keep growing `core/utils.sh`.** Rejected: it already holds config,
  session logging, `run_cmd`, the health score, Homebrew access, and hardware
  primitives. Adding volume adoption and a migration pipeline would make it a
  grab-bag with no ownership boundary, the opposite of "explicit ownership."
- **A `core/platform.sh` dispatcher, mirroring `core/deployment.sh`.**
  Rejected: Storage has no independent workflow with its own menu entry to
  dispatch to — it's consumed *by* a module (`maintenance.sh`), not run on
  its own. A dispatcher would be ceremony with no caller.
- **A full dependency-injection / plugin-loader framework for platform
  services.** Rejected outright: bash 3.2, a project of this size, and a
  single real tenant do not justify one. The `core/platform/<service>/`
  convention plus a `service::` function-name prefix is the entire
  mechanism.

## Consequences

- Every future Platform service candidate gets evaluated against the same
  bar Storage was held to, not waved through because the directory now
  exists.
- `core/platform/storage/`'s internal shape (volume/plan/transaction/engine/
  api/profiles) is the template a second service would follow, not because
  it's mandated, but because it's the only proven example in this codebase.
- Modules keep talking to Storage exclusively through `storage::*` — the
  Platform/module boundary is enforced by convention (documented in
  [CONTRIBUTING.md](../CONTRIBUTING.md)), not by tooling. There is no bash
  mechanism to make `volume.sh` actually private; discipline is the
  enforcement, same as every other convention in this project.

## Future implications

If a second Platform service is ever built, this ADR is the place to update
with what changed about the bar (if anything) and why that service cleared
it — not a reason to relax the bar for the third, fourth, and fifth.
