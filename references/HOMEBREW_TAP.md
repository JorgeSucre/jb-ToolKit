# JB Toolkit — Homebrew Tap Readiness Audit

Status: **audit only, no functional changes**. This document records what
would actually be required to ship JB Toolkit through a Homebrew Tap
(`brew tap jb-repair/jb-toolkit && brew install jb-toolkit`). Nothing here
is implemented — see Roadmap v1.1 in `references/KNOWN_ISSUES.md` for when
this might actually be built.

This was already identified as a recommended near-term direction in the
"Product Vision" section of `KNOWN_ISSUES.md` ("Homebrew Tap... fits the
project's existing Homebrew-centric design philosophy"). This document is
the concrete audit behind that recommendation.

---

## 1. Bootstrap entrypoint

Today: `./jb` at the repo root is the **only** supported entry point
(AGENTS.md §1). It resolves its own location with:

```bash
BASE_DIR="$(cd "$(dirname "$0")" && pwd)"
```

Every module (`core/utils.sh`, `core/bootstrap.sh`, etc.) repeats the same
pattern relative to its own file. This assumes the entire repository
structure (`core/`, `references/`, `brewfile`, `logs/`) is reachable as
siblings/descendants of wherever the entrypoint script physically lives.

**Finding — symlink resolution gap.** A Homebrew formula's normal install
shape is to put the real files under `libexec` and create a **symlink**
in `bin` (`bin.install_symlink libexec/"jb"`), so `jb` is on `PATH`. But
`dirname "$0"` on a symlinked invocation resolves to the symlink's own
directory (`$(brew --prefix)/bin`), **not** the real script's directory —
`core/`, `references/`, and `brewfile` would not be found there at all.

This needs one of:
- Resolve the entrypoint's *real* path before computing `BASE_DIR` (e.g.
  `cd -P "$(dirname "$0")"` or a small `readlink`-following loop), so it
  follows the symlink back to `libexec`, or
- Have the installed `bin/jb` be a small wrapper script (not a symlink)
  that `cd`s into a known `libexec` path directly, rather than relying on
  `$0` resolution at all.

Either fix is small and self-contained, but it is a **required** change
before a Tap install would work — not optional polish.

---

## 2. Non-interactive entrypoint (missing today)

`jb` is a pure interactive menu loop (`read -r -p "Option: " opt` inside a
`while true`). There is currently **no** non-interactive flag at all — no
`--version`, `--help`, no way to invoke a single module without sitting
through the menu.

**Finding — blocks a meaningful `test do` block.** Homebrew's own
guidelines require formula tests to be non-interactive and to actually
exercise the installed binary (not just check that a file exists). Without
at least a `--version` flag, the best a `test do` block could do is
`assert_predicate bin/"jb", :exist?` — which proves nothing about whether
the toolkit actually runs. Adding a minimal `--version`/`--help` flag to
`jb` (print `$JB_VERSION` and exit 0) is a small, low-risk, genuinely
useful change independent of Homebrew — and a prerequisite for a real Tap
test.

---

## 3. Writable data directory (the most significant finding)

Today, `core/utils.sh` does:

```bash
export STATE_FILE="$BASE_DIR/logs/state.env"
mkdir -p "$BASE_DIR/logs" 2>/dev/null || true
```

— and `ensure_pdf_python()` creates `JB_VENV_DIR="$BASE_DIR/.venv"`. Both
assume `$BASE_DIR` is a writable directory the current user owns, which is
true for a git checkout but **false** for a Homebrew install: `BASE_DIR`
would resolve into `$(brew --cellar)/jb-toolkit/<version>/libexec`, a
shared, version-pinned, not-necessarily-user-writable location. Writing
`logs/state.env` there would either fail (permissions) or, worse, succeed
and then get wiped out the next time the formula is upgraded (Homebrew
replaces the Cellar contents on `brew upgrade`).

**Finding — this is an actual redesign, not a packaging detail.** Before a
Tap install is usable, `state.env`, `logs/`, `maintenance_history.log`,
and `.venv` all need to move to a per-user, persistent, writable location
— the conventional choice is `~/Library/Application Support/JBToolkit/`
(or `$XDG_DATA_HOME`/`~/.jb-toolkit` if a simpler convention is preferred).
This touches every module that currently derives a path from `$BASE_DIR`
for logs/state (`core/utils.sh`, `core/maintenance/state.sh`,
`core/report.sh`, `core/report_pdf.py`), but the change itself is
mechanical (swap one base path constant) **if** it's done as a single,
deliberate pass — not an incremental patch per module.

`brewfile` (the catalog of optional software JB Toolkit installs *for the
technician*) and `references/tools/*.md` (the Documentation Library) are
read-only assets and can safely stay under the Homebrew-managed
`libexec`/`#{prefix}` path — only the *write* targets need to move.

---

## 4. Version source

`core/utils.sh`:

```bash
export JB_VERSION="${JB_VERSION:-1.0.0}"
```

This is already the toolkit's single internal source of truth (AGENTS.md
§3) — every other consumer (banner, `state.env`, snapshot, PDF footer)
reads `$JB_VERSION`, never a hardcoded literal. For a Tap formula, this
value and the formula's own `version "x.y.z"` field become **two places
that must agree**, since the formula's `url`/`sha256` pin a specific
tagged release. A release checklist item (not a code change): bumping the
version means updating `core/utils.sh` **and** the formula in the same
release, in that order — `CHANGELOG.md`'s existing "Release Workflow"
section is the natural place to add this step in the future, alongside
"Create the git tag."

---

## 5. Dependencies

| Dependency | Type | Notes |
|---|---|---|
| `fastfetch` | Formula `depends_on` (hard) | Already treated as a near-core dependency by the toolkit itself (AGENTS.md §4/§8) — installing it via the formula's own dependency graph is more reliable than the current Brewfile-driven install, though the toolkit must still degrade gracefully if it's ever missing (existing rule, unchanged). |
| `python3` | Implicit (system or Homebrew) | `ensure_pdf_python()` only requires `command_exists python3` to bootstrap its own `.venv` — no formula-level Python dependency is strictly required, consistent with the current design. |
| Homebrew itself | N/A | Not a formula dependency — installing *via* `brew install` already implies Homebrew is present. (This is the toolkit's own *runtime* dependency on Homebrew for the Brewfile-driven install flow, which is unrelated and unaffected.) |
| `bats-core` | **Test-only**, never a runtime `depends_on` | Needed only to run `tests/` locally/in CI — see `references/KNOWN_ISSUES.md` and the new `tests/` directory. Must never be required by an end user just to run `jb`. |

---

## 6. Proposed formula layout (illustrative — not implemented)

```ruby
class JbToolkit < Formula
  desc "macOS maintenance, diagnostics, provisioning, and reporting toolkit"
  homepage "https://github.com/JorgeSucre/jb-ToolKit"
  url "https://github.com/JorgeSucre/jb-ToolKit/archive/refs/tags/v1.0.0.tar.gz"
  sha256 "..." # computed at release time
  license "MIT"

  depends_on "fastfetch"

  def install
    libexec.install Dir["*"]
    # Wrapper, not a bare symlink — sidesteps the $0 symlink-resolution
    # gap documented in §1 by cd'ing into the real install directory
    # before invoking the real jb script.
    (bin/"jb").write <<~EOS
      #!/bin/bash
      cd "#{libexec}" && exec ./jb "$@"
    EOS
    (bin/"jb").chmod 0755
  end

  test do
    # Requires the --version flag from §2 to be a meaningful test.
    assert_match version.to_s, shell_output("#{bin}/jb --version")
  end
end
```

---

## 7. Summary — what must change before this ships

1. Fix `$0`/symlink path resolution (§1) — small, mechanical.
2. Add a `--version`/`--help` non-interactive flag to `jb` (§2) — small,
   independently useful even without Homebrew.
3. Move `logs/`, `state.env`, `maintenance_history.log`, and `.venv` to a
   per-user writable data directory (§3) — the real work; touches several
   files but is mechanical if done as one deliberate pass.
4. Keep version bumps synchronized between `core/utils.sh` and the formula
   (§4) — process discipline, not code.
5. `fastfetch` becomes a formula dependency instead of (or in addition to)
   a Brewfile entry (§5) — straightforward.

None of this is implemented by this audit. It belongs in Roadmap v1.1 per
`references/KNOWN_ISSUES.md`'s Product Vision section, after the writable
-data-directory redesign (item 3) is scoped as its own deliberate change.
