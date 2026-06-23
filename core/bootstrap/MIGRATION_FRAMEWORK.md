# Homebrew Migration Framework — Architecture Notes (Not Implemented)

Status: **design only**. No functional code exists yet. This file exists so
the eventual implementation has a single source of truth to follow, and so
no functionality is added accidentally before the design is reviewed.

## Why this exists

`detect_app_state()` (`core/utils.sh`) and `package_app_bundle_name()`
(`core/bootstrap/packages.sh`) already distinguish three install methods for
a given package: Homebrew formula, Homebrew cask, and **manual** (a `.app`
bundle found in `/Applications` or `~/Applications` that Homebrew doesn't
know about). Today that distinction is purely informational — it's surfaced
in reports (`method == "manual"` → "Instalación manual", never "actualizado")
and used to avoid recommending an install that's already present.

A natural next step — **not being built now** — is offering to bring a
manually-installed app under Homebrew's management, so it benefits from
`brew upgrade`/`brew bundle` going forward instead of staying a silent,
unversioned `.app` bundle.

## Proposed flow

```text
Manual App Detected
   (detect_app_state() returns "installed:manual")
        ↓
Homebrew Equivalent Exists
   (package_app_bundle_name() already maps id -> bundle name;
    a migration table would need the reverse: bundle -> known package id,
    plus a per-app cask/formula confidence check)
        ↓
Offer Migration
   (read-only, presented like offer_hardware_recommendations() — a
    selectable menu item, never automatic)
        ↓
User Confirmation
   (explicit ask_yes_no() per app — no "select all" shortcut for this
    one, given it touches an existing install)
        ↓
Backup
   (snapshot the existing .app bundle path — e.g. move-then-verify, not
    delete-then-install — so a failed migration can be rolled back)
        ↓
Migration
   (brew install --cask <pkg>, verify via detect_app_state() again,
    only then remove/retire the backup)
```

## Hard constraints for the eventual implementation

- **Detection only, never automatic.** Mirrors the rule already enforced
  for `maintenance/apps.sh` (never uninstall automatically) — see
  AGENTS.md §5. A migration is a more invasive action than an uninstall
  recommendation and must never run without an explicit per-app
  confirmation.
- **Never destructive without a verified backup.** The existing manual
  install must remain recoverable until the Homebrew-managed replacement
  is confirmed working (matches the "Backup" stage above). This is a much
  stronger requirement than `maintenance/cleanup.sh`'s age-gated deletion,
  since here we'd be replacing something the user relies on, not clearing
  stale cache files.
- **Module ownership stays put.** This belongs in `core/bootstrap/`
  (provisioning concern), not `core/maintenance/` — migrating an install
  method is closer to "how is this software managed" than to a corrective
  maintenance action. It must not call into `maintenance/*` or write
  maintenance's `state.env` keys.
- **No new state.env keys without updating AGENTS.md §3.** If migration
  history needs to persist (e.g. "this app was migrated on this date"),
  it needs its own key, owned by whichever file implements this, added to
  the ownership table — not piggybacked onto an existing key.
- **Reuse `detect_app_state()`.** The verification step after migration
  must call the existing shared detection function, not re-implement
  bundle/version checking.

## What's explicitly out of scope for "foundation only"

- No actual migration logic, no `brew install` calls tied to this flow,
  no backup/rollback code, no new menu entries reachable from `bootstrap.sh`
  or `jb`. The TODO markers in `core/bootstrap/packages.sh` point back to
  this file — implement against this design, don't start from scratch.
