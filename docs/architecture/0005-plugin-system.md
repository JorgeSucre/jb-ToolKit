# ADR-0005: Plugin System

## Context

Storage's original design (previous iteration) already had a form of
plugin: a profile was a single `.sh` file that called `register_storage_profile`
and defined three callback functions (`_source_root`, `_dest_subdir`,
`_scan`), auto-discovered by globbing `profiles/*.sh`. That design already
satisfied the core promise — engine.sh contained zero profile-specific
knowledge, verified by grep before this iteration even started. What changed
is the *shape* of a profile, not whether the engine stays domain-agnostic.

## Problem

Two small but real problems with the single-file-plus-callbacks shape:

1. **`DEST_SUBDIR` was a function that always returns a constant.**
   `storage_profile_home_dest_subdir() { printf "%s\n" "Home"; }` is a
   function wrapping a value that never changes at runtime — indistinguishable
   from data, dressed up as behavior. Every other place in this codebase that
   has static, declarative per-item facts (an application's `NAME`,
   `INSTALL_METHOD`, `PACKAGE` in `catalog/applications/<id>/app.conf`) uses
   a flat `KEY=value` file, not a function. Profiles were the outlier.
2. **Registration was imperative and repeatable-per-file.** Each profile
   file called `register_storage_profile` itself, at source time — one more
   place a profile author could make a mistake (wrong argument order, a
   forgotten call, a typo in the id) with no structural check.

## Decision

A profile becomes a **directory** with exactly two files:

```
profiles/<id>/
    profile.env   PROFILE_ID=<id> · PROFILE_LABEL="<display name>" · DEST_SUBDIR=<folder>
    scan.sh       storage_profile_<id>_source_root, storage_profile_<id>_scan
```

`profile.env` holds everything that's genuinely static — matching the
catalog's own proven `.env`/`.conf`-per-directory convention rather than
inventing a new one. `scan.sh` holds the one thing that's genuinely dynamic:
resolving *whose* data this is (the console user isn't necessarily the
technician) and enumerating it.

Registration moves out of the profile entirely. `load_storage_profiles` (in
`engine.sh`) discovers `profiles/*/`, sources `profile.env` into three known
local variables, calls `register_storage_profile` **on the profile's
behalf**, then sources `scan.sh`. A profile author now cannot get
registration wrong — there's nothing left to call.

The callback count drops from three to two: `_dest_subdir` is gone, replaced
by `storage_profile_dest_subdir(id)`, a lookup into the registry (extended
from `id|label` to `id|label|dest_subdir` — bash 3.2 has no associative
arrays, so the existing pipe-delimited-line pattern is extended rather than
inventing a lookup table type that doesn't exist in this shell).

One quoting gotcha worth naming explicitly: `profile.env` is *sourced* as
bash, not parsed as flat KV the way `state.env` is. `PROFILE_LABEL=Home del
usuario` (no quotes) doesn't set a three-word string — it sets
`PROFILE_LABEL=Home` and then bash tries to execute `del` as a command. This
was caught by testing (the actual failure: `del: command not found`) before
it shipped. Every profile's label with a space must be quoted
(`PROFILE_LABEL="Home del usuario"`); this requirement is stated explicitly
in [Storage-Architecture.md](../Storage-Architecture.md) and
[CONTRIBUTING.md](../CONTRIBUTING.md) precisely because it's easy to get
wrong once and never notice until a profile with a multi-word label is added.

**Rejected: per-profile `execute.sh`/`verify.sh`.** See
[ADR-0002](0002-storage-platform.md) for the full reasoning — copying and
verification have zero profile-specific variance today, and adding hooks for
variance that doesn't exist would risk a future profile quietly weakening
the safety guarantee every profile currently shares.

## Alternatives considered

- **Keep the single-file shape, just fix the `DEST_SUBDIR` function
  smell** (e.g., a fourth "declare metadata" callback that echoes
  `id|label|dest_subdir`). Rejected: this still requires every profile
  author to remember to call `register_storage_profile` correctly, and it
  doesn't gain the directory-per-profile structure that makes "which
  profiles exist" a filesystem question (`ls profiles/`) rather than a
  question about function-call side effects.
- **A manifest file listing all profiles** (e.g., `profiles/registry.env`
  enumerating `home,downloads,...`), avoiding a directory-scan loop.
  Rejected: it reintroduces exactly the "edit a shared list to add a
  profile" friction the plugin system exists to remove, and it's a second
  place a profile could be inconsistently registered (present in the
  manifest but missing its files, or vice versa).

## Consequences

- Adding a profile is "create a directory with two files," full stop — no
  engine file is touched, no shared list is edited, no registration call can
  be gotten wrong because there isn't one to write.
- `profiles/downloads/` (two files, ~40 lines total) is not a hypothetical
  proof of this — it was rebuilt under the new shape and re-verified
  end-to-end as part of this iteration, alongside `profiles/home/`.
- The profile contract is now exactly two functions per profile
  (`_source_root`, `_scan`), the smallest surface that can express "where is
  it" and "what's in it" — anything a future profile seems to need beyond
  that is a signal to either extend the contract for every profile (update
  this ADR and Storage-Architecture.md in the same change) or recognize the
  need doesn't belong in a profile at all.

## Future implications

Photos Library, Steam Library, Docker, VMs, Cloud Sync, Backups, and Media
Libraries are each expected to fit the two-callback contract unchanged (see
the worked Photos Library example in
[Storage-Architecture.md](../Storage-Architecture.md)). If a real future
profile genuinely cannot express itself in `_source_root` + `_scan` — for
example, something needing per-item exclusion logic more complex than a
boolean — extend the contract deliberately and update every existing profile
to match, rather than special-casing one profile.
