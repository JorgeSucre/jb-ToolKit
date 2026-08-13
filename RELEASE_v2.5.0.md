# JB Toolkit v2.5.0 — Release Notes

## Overview

JB Toolkit is a macOS maintenance, diagnostic, optimization, and deployment
suite built for repair technicians and IT consultants, running entirely as
native Bash. v2.5.0 is not a user-facing feature release in the sense
v2.2.2 or v2.4.0 were — it's an engineering-process release. Two mostly
independent efforts landed in the same window: a Module Contract model for
describing architecture as checkable claims instead of prose, applied to
five more Deployment-layer modules after `Deployment.Menu`'s own adoption;
and a data-driven macOS/Xcode/Command Line Tools compatibility matrix that
makes Bootstrap decide, deliberately, whether an environment can proceed
before it ever touches Homebrew. A real defect found in v2.4.1's terminal
grid — a `tput cols` call that could silently return the wrong width — is
also fixed here, since the fix landed after v2.4.1 was already closed.

## Release Goals

Two goals, pursued separately rather than as one theme:

- **Make architecture verifiable, not just documented.** Three completed
  Verifications (0001–0003) found real, undetected drift between prose
  architecture documents and the code they described — a stated exclusion
  contradicted by production code, a claim that corresponded to no
  documented text anywhere, a dependency missing from a diagram. The
  Module Contract model (`docs/architecture/MODULE_STANDARD.md`) exists to
  replace paragraphs a human has to re-interpret with atomic claims a
  Verification Engineer can check against real evidence, one sentence at a
  time. This release tests whether the model generalizes past its first
  worked example by running five more real modules through the same
  draft → verify → correct → re-verify cycle `Deployment.Menu` went
  through under ADR-0013.
- **Stop assuming the environment before touching Homebrew.** Bootstrap's
  previous Command Line Tools check (`xcode-select -p`, install if absent)
  never checked macOS version compatibility at all, and its own failure
  was only logged — never blocking the run. Apple's real Xcode/macOS
  compatibility windows are narrow and version-specific, and Homebrew's
  own supported-macOS floor moves independently, on its own schedule. The
  toolchain compatibility matrix makes this an explicit, data-driven
  decision instead of an implicit assumption, without hardcoding a
  Homebrew version anywhere.

## Major Architectural Milestones

| Milestone | What changed | Where |
|---|---|---|
| Module Contract model introduced | Seven-field contract (Purpose, Responsibilities, Consumes, Produces, Collaborates With, Constraints, Defined By) for describing a module as atomic, checkable claims | `docs/architecture/MODULE_STANDARD.md` |
| Module Contracts adopted via a governance process | ADR-0013 establishes the model and adopts `Deployment.Menu`'s own Contract as the first migrated module | [ADR-0013](docs/architecture/0013-module-contracts.md) |
| Five more modules adopted | `Deployment.Selection`, `Deployment.Planner`, `Deployment.Confirm`, `Deployment.Renderer`, `Deployment.Installer` each drafted, independently Boundary-Verified, corrected where findings existed, and re-verified — then adopted per ADR-0013's incremental, module-by-module sequence (19/19, 24/24, 13/13, 23/23, 18/18 respectively) | `docs/architecture/MODULE_STANDARD.md` §§10–14, `docs/engineering/verification/` |
| Engineering Governance Layer established | Principles, Roles, the Verification Standard, and the Verification Program — the process this release's own work follows | `docs/engineering/` |
| macOS Toolchain Compatibility Matrix | Patch-banded, data-driven macOS/Xcode/CLT/Homebrew compatibility — resolved before Homebrew is touched, extensible without touching bootstrap code | `core/bootstrap/toolchain-matrix.conf`, `core/bootstrap/toolchain.sh` |
| Terminal grid width-detection fixed | `stty size </dev/tty` now primary, `tput cols` a fallback — the earlier mechanism could silently return the wrong width | `core/deployment/menu.sh` |

## Known Limitations

Carried from `docs/engineering/MODULE_CONTRACT_MIGRATION_LESSONS.md`'s
"What Remains Open," current as of this release:

- **One Contract Consistency Observation is unresolved.**
  `Deployment.Menu`'s adopted Contract does not record
  `Deployment.Renderer`'s read of `CATALOG_MENU_HW_IDS`. Correcting it
  means amending an adopted Contract, which stayed out of scope for every
  task in this effort.
- **Two model-level gaps remain unaddressed:** no field states which
  implementation files constitute a module's boundary, and no rule states
  whether shared infrastructure like `core/utils.sh` belongs in
  `Collaborates With`.
- **Most of the Deployment pipeline, and every module outside it, has no
  Module Contract yet** — `Deployment.Transaction`, `Bootstrap`,
  `Maintenance`, `Diagnostics`, `Reporting`, `Platform`.
  `Deployment.Catalog` and `Platform` have Contracts that were
  shape-validated but never boundary-verified.
- **This is the second `RELEASE_vX.Y.Z.md` this project has ever
  produced.** No release note exists for v2.3.0, v2.3.1, v2.3.2, or
  v2.4.0, despite each shipping real architectural change under this
  policy's own MINOR-release definition. No git tag exists for any
  release since `v2.2.2` either.

## Future Direction

No specific architecture work is committed for the next release. One
concrete, evidenced next step exists if the project wants it: continue the
Module Contract migration into `Deployment.Transaction`, `Bootstrap`, and
the remaining modules — `docs/engineering/MODULE_CONTRACT_MIGRATION_LESSONS.md`
records what that process actually costs and finds. This is not prescribed
here; it is what the repository's own evidence points at.
