# JB Toolkit — Engineering Documentation

This directory is the official engineering reference for JB Toolkit. It describes the
architecture **as implemented today** (v2.4.1). It is written for future
contributors and AI assistants who need to understand, maintain, or extend the project
without reverse-engineering it from source.

## Reading order

| Document | What it covers |
|---|---|
| [Architecture.md](Architecture.md) | Overall structure, subsystems, module dependency graph |
| [Design-Principles.md](Design-Principles.md) | The engineering philosophy, inferred from and evidenced by the code |
| [Execution-Flow.md](Execution-Flow.md) | Launcher lifecycle and the five module workflows, step by step |
| [Module-Overview.md](Module-Overview.md) | Per-file responsibilities and public functions |
| [State-System.md](State-System.md) | The `state.env` persistence layer and cross-module data flow |
| [Logging.md](Logging.md) | Session logs, command capture, error traps, artifact retention |
| [Health-Score.md](Health-Score.md) | The 0–100 health score: inputs, weights, caveats |
| [Hardware-Detection.md](Hardware-Detection.md) | Device profiling, Rosetta detection, hardware-driven recommendations |
| [Reporting.md](Reporting.md) | Terminal report, system snapshot, and executive PDF pipeline |
| [Future-Roadmap.md](Future-Roadmap.md) | What exists vs. what is planned; known future improvements |
| [CONTRIBUTING.md](CONTRIBUTING.md) | Engineering handbook: philosophy, style, extension points, prohibitions |
| [Deployment-Architecture.md](Deployment-Architecture.md) | The deployment pipeline: layers, the Plan and Transaction contracts, invariants, where future work belongs |
| [Deployment-Design.md](Deployment-Design.md) | Design history of the Deployment module: decisions, phases, rationale |
| [Catalog-Format.md](Catalog-Format.md) | **Normative data contracts** for `catalog/`: file formats, fields, validation rules, doctor advisories |
| [CATALOG_CONSTITUTION.md](CATALOG_CONSTITUTION.md) | The catalog's long-term philosophy — 10 principles behind why it's curated the way it is |
| [CATALOG_STANDARD.md](CATALOG_STANDARD.md) | The metadata quality standard: required/optional fields, category enum, license vocabulary |
| [Storage-Architecture.md](Storage-Architecture.md) | The Storage Platform service: Adopted Data Volumes, the generic scan/plan/execute/verify/rollback/commit pipeline, the public `storage::*` API, and the profile contract future migration profiles implement |
| [architecture/](architecture/) | Architecture Decision Records — the *why* behind architectural decisions across the toolkit (Platform, Catalog, Deployment, Terminal UI), one topic per file, written for readers who won't read the implementation |
| [release-policy.md](release-policy.md) | Versioning strategy, the Release Candidate process, Architecture Freeze, and the release checklist |
| [engineering/](engineering/) | The Engineering Governance Layer — how the project engineers itself: principles, verification standard, roles, the verification program, and templates. Start at [engineering/README.md](engineering/README.md) |

See also, at the repository root: [CHANGELOG.md](../CHANGELOG.md) (what
changed, release by release) and [RELEASE_v2.2.2.md](../RELEASE_v2.2.2.md)
(this release's own summary, written for someone discovering the project for
the first time).

## Ground rules for contributors

1. **Read [Design-Principles.md](Design-Principles.md) before changing anything.** The
   project deliberately values small diffs, deletion over addition, and measured
   results over estimates. Changes that fight this philosophy will not be accepted.
2. The architecture is considered **stable**. It has been through multiple improvement
   passes and an independent release-readiness audit. Do not introduce new abstractions
   without a demonstrated, measurable benefit.
3. All user-facing text is **Spanish**; code, comments, and documentation are English.
4. Every user-visible success message must correspond to a verified operation. This is
   an audited invariant — see the "truthful reporting" principle.
