# JB Toolkit — Engineering Documentation

This directory is the official engineering reference for JB Toolkit. It describes the
architecture **as implemented today** (v0.9, pre-1.0). It is written for future
contributors and AI assistants who need to understand, maintain, or extend the project
without reverse-engineering it from source.

## Reading order

| Document | What it covers |
|---|---|
| [Architecture.md](Architecture.md) | Overall structure, subsystems, module dependency graph |
| [Design-Principles.md](Design-Principles.md) | The engineering philosophy, inferred from and evidenced by the code |
| [Execution-Flow.md](Execution-Flow.md) | Launcher lifecycle and the four module workflows, step by step |
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
