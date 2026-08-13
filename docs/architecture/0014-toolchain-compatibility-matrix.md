# ADR-0014: macOS Toolchain Compatibility Matrix (v2.5.0)

## Context

Bootstrap's prior Command Line Tools handling was a single check:
`xcode-select -p`, install if absent, and log-only on failure — it never
inspected the macOS version and never blocked the run. In practice this
meant Bootstrap could reach Homebrew installation on a macOS/Xcode
combination Apple never documented as compatible, or on a machine missing
capabilities Homebrew itself would need, with the toolkit finding out only
when Homebrew (or a later `brew install`) failed on its own — no earlier,
more specific diagnostic existed. Bootstrap has never had a Module Contract
or an ADR of its own; this is the first.

Apple's Xcode/macOS compatibility windows are narrow and version-specific,
and shift with every macOS release; Homebrew's own supported-macOS floor
moves independently, on Homebrew's own schedule, not the toolkit's.
Hardcoding either as a fixed assumption goes stale on a schedule the
toolkit doesn't control.

This decision is independent of [ADR-0013](0013-module-contracts.md).
ADR-0013 governs the Module Contract model and its incremental adoption
across Deployment-layer modules; nothing here modifies that model, and
nothing there addresses Bootstrap's environment-preparation flow. Both
landed in v2.5.0 as two largely separate efforts.

## Decisions

### Toolchain compatibility is resolved from a declarative matrix, not branching logic

`core/bootstrap/toolchain-matrix.conf` is the single source of truth for
which macOS/Xcode/Command Line Tools situation a machine is in — one
`[section]` per macOS family/patch band, in the same awk-parseable flat
`KEY=value` convention `catalog/presets.conf` already uses (no YAML/JSON,
no new dependency). `core/bootstrap/toolchain.sh`'s
`resolve_toolchain_section` looks up the row with the greatest
`PATCH_FLOOR` at or below the machine's detected version; there is no
per-macOS-version `if`/`elif` ladder in `toolchain.sh` or `bootstrap.sh`.
Adding a new macOS release means adding a matrix row, not editing code.

### Capability profiles, not tool versions, express what the Toolkit requires

Each matrix row names a `CAPABILITY_PROFILE` (currently only
`standard_clt`, requiring `clang` and `git`) rather than a specific tool
version. This is a narrower claim than "the matrix encodes Homebrew's
requirements": the profile is what *this toolkit* needs to proceed,
decided independently of whatever Homebrew currently requires.

### Capability validation is behavioral

`validate_capability` requires each command in a profile to both exist on
`PATH` and successfully run `<cmd> --version` — command existence alone is
not treated as sufficient evidence the toolchain works.

### A per-row strategy can stop Bootstrap before Homebrew is touched

Each row's `TOOLKIT_STRATEGY` (`proceed` / `proceed_with_warning` /
`proceed_with_caution` / `stop`) governs what `prepare_toolchain` does
next. A macOS version below every row's floor for its family resolves to
`stop` directly (the synthetic `BELOW_FLOOR` marker). `core/bootstrap.sh`
treats a `prepare_toolchain` failure as fatal — Bootstrap exits before
`install_brew` is ever called.

### Apple's documented Xcode/CLT compatibility window is informational only

`APPLE_XCODE_MIN`/`APPLE_XCODE_MAX` record the Xcode/CLT version range
Apple documents as compatible with a given macOS patch band, checked
against whatever is actually detected on the machine (`detect_xcode_clt`)
and surfaced only as a warning when outside that range. It is never an
install target — `xcode-select --install` always installs whatever Apple
currently offers for the running OS — and the range never gates
`prepare_toolchain`'s pass/fail result; `validate_capability_profile`
alone decides that.

### Homebrew's own compatibility remains Homebrew's to decide, validated live

`BREW_TIER` records Homebrew's own published support-tier label for a row,
for logging/context only. The matrix does not encode Homebrew's current
version floor, and nothing in `toolchain.sh` gates on `BREW_TIER`.
Homebrew's actual compatibility with the machine continues to be
established the way it already was — `configure_brew` and `validate_brew`,
run live, every time — unchanged by this decision.

### CLT installation is relocated, not redesigned

`install_clt` (unconditional install attempt, then poll `xcode-select -p`
for up to five minutes) moves from `bootstrap.sh` into `toolchain.sh`
as-is, with unchanged behavior. What changes is who decides whether and
when to call it, and what happens afterward: `prepare_toolchain` calls it
only when the capability profile isn't already satisfied, and never trusts
its exit code as proof of success — it re-runs `validate_capability_profile`
afterward and fails the whole run if the profile still isn't met.

### Toolchain preparation is a fatal prerequisite, ahead of Homebrew

`prepare_toolchain` is the first substantive step in Bootstrap's first
stage, called before `install_brew`. Its failure is fatal to the run, not
logged-and-continued the way the prior CLT check's failure was.

## Alternatives considered

- **The superseded prior design: presence-only CLT detection with
  non-blocking failure.** Not a hypothetical alternative — it is what
  Bootstrap actually did before this decision (`xcode-select -p`, install
  if absent, log-only on failure, no macOS-version awareness at all).
  Superseded because it let a run reach Homebrew on an environment the
  toolkit had no basis to believe would work, discoverable only by a
  later, less specific failure.
- **Hardcoded per-macOS-version `if`/`elif` branching in Bootstrap code,
  instead of a declarative matrix file.** Explicitly rejected by the
  implementation's own design, per `toolchain.sh`'s header comment: adding
  a macOS release should mean adding a matrix row, not editing bootstrap
  logic. A branching ladder would recreate exactly the maintenance pattern
  the matrix format was chosen to avoid.
- **Static/pinned version mapping instead of behavioral capability
  validation.** Rejected for the same reason twice over in the
  implementation: `validate_capability`'s own comment states "command
  existence alone is not treated as sufficient," and the matrix's
  `BREW_TIER` field is explicitly commented as never gating anything —
  "Homebrew's actual compatibility is always validated live, never gated
  on this label or on a pinned version." A version string or a tier label
  can be correct on paper and still not reflect what's actually installed
  and working; running each required command is the only check that can't
  be stale.
- **Allowing Bootstrap to continue when toolchain preparation fails.**
  Rejected — this is the behavior the prior design actually had (failure
  was logged only), and it is exactly what this decision replaces.
  `prepare_toolchain`'s own header comment states it directly: "Never
  continues silently past `TOOLKIT_STRATEGY=stop`."

No design document or prior ADR records these as having been weighed in a
formal review; the alternatives above are reconstructed from the
implementation's own committed rationale (code comments) and, for the
first item, from the actual prior behavior itself — not from a design
record that does not exist.

## Consequences

**Benefits.**
- Bootstrap now detects an unsupported or unsafe macOS/toolchain
  combination before it ever touches Homebrew, rather than discovering it
  later through a less specific failure.
- Environment compatibility is represented as data
  (`toolchain-matrix.conf`), inspectable and editable without reading
  Bash.
- Adding support for a new macOS patch band is ordinarily a new matrix
  row, not new branching logic in `toolchain.sh` or `bootstrap.sh`.
- Capability validation checks that required tools actually run, not
  merely that a version string or tier label claims they should.
- Homebrew's own compatibility stays exactly where it already was —
  Homebrew's live validation — so this decision never has to be kept in
  sync with Homebrew's own changing requirements.

**Costs.**
- `toolchain-matrix.conf` is a new, ongoing maintenance surface: a macOS
  release with no matching row falls through to the `DEFAULT_NEWER`
  section (`proceed_with_caution`) rather than a specifically-verified
  path, until a real row is added.
- A machine whose macOS family has no row at or below its detected version
  (`BELOW_FLOOR`) now stops Bootstrap outright — a real behavior change
  from "always continues" to "can refuse to continue."
- Bootstrap's first stage has a strictly stronger prerequisite gate than
  it did before; a machine that previously limped through with a log-only
  warning can no longer do so.

## Future implications

If a capability profile beyond `standard_clt` (for example, a
`full_xcode_required` profile for a future workflow) becomes a real,
demonstrated need, `_capability_profile_commands` is the one place to
extend — no other part of `toolchain.sh` or `bootstrap.sh` changes. If
Apple ever ships a macOS version whose Xcode/CLT compatibility splits
mid-version the way Sonoma's did (two rows, `14.0` and `14.5`, in the
current matrix), the same patch-band pattern already supports it without a
new mechanism. `DEFAULT_NEWER`'s `proceed_with_caution` strategy is a
deliberate safety valve for exactly this gap — it should be narrowed to a
specific row as soon as a new macOS release is actually verified, not left
as the permanent answer for it.
