# The JB Toolkit Catalog Constitution

This document defines the long-term philosophy of the Application Catalog —
not its file format (see [CATALOG_STANDARD.md](CATALOG_STANDARD.md) for
that), but the principles that should outlive any individual schema change,
category reshuffle, or metadata field added in the future.

Where a future decision seems to conflict with one of these principles,
the principle wins, or the principle gets amended deliberately — in an ADR,
in the open — never quietly worked around.

## 1. One application, one category

Every application belongs to exactly one primary category. An application
never appears twice in the catalog under two different classifications.
This is not a storage convenience — it is a promise to the technician
browsing the catalog: what you see once, you see exactly once, always in
the same numbered slot. See
[architecture/0007-catalog-consistency.md](architecture/0007-catalog-consistency.md)
for why this was made structurally impossible to violate, not just
discouraged.

## 2. Categories describe purpose, not audience

A category answers "what does this application do," never "who is this
for." `development` describes a class of tool, not a class of user —
`security` describes what 1Password does, not that IT technicians happen to
use it. This keeps categories stable as the catalog grows: a new user
persona never requires a new category, because personas were never what
categories were tracking. Presets (`catalog/presets.conf`), not categories,
are where "who is this for" lives — a Developer preset can freely draw from
`development`, `system`, and `productivity` in the same list.

## 3. Curated over exhaustive

The catalog is not a mirror of Homebrew. It is intentionally curated: only
software that provides real, demonstrated value to a JB Repair technician or
their client belongs here. "It exists and it's popular" is not, by itself,
a reason to add an application. A smaller catalog a technician trusts
completely beats a larger one they have to second-guess.

## 4. Prefer actively maintained software

An abandoned project is a liability the moment it's recommended — no
security patches, no compatibility fixes for the next macOS release, no one
to ask when something breaks. When two tools solve the same problem,
prefer the one with a maintainer still showing up. This is a preference,
not an absolute bar: a well-established, feature-complete tool with a slow
but real release cadence is not "abandoned."

## 5. Prefer Homebrew

Whenever a Homebrew formula or cask exists for an application, it is the
preferred `INSTALL_METHOD`. Homebrew gives JB Toolkit a uniform install/
verify/upgrade story, a maintained update channel independent of this
project, and — critically — it's the same mechanism every other catalog
entry already uses, so there is exactly one installation code path to trust
(see [Design-Principles.md](Design-Principles.md), principle 3). Manual
installs (`pkg`/`dmg`/`manual`/`mas`) are accepted, never treated as
failures, but are the fallback, not the default.

## 6. Official names only

`NAME` is always the application's own official project or product name —
never a nickname, a shortened form, or JB Repair's own label for it. A
technician who searches for "Visual Studio Code" should see exactly that
string, not "VS Code" or "vscode." This also protects the catalog from a
subtle drift: an unofficial name can quietly go stale when a project
rebrands; the official name is whatever the project itself currently calls
itself.

## 7. One source of truth

All application information — what it is, where it comes from, how it
installs, what category it belongs to — originates from the catalog and
nowhere else. Nothing in Deployment, Presets, or any future feature is
permitted to hardcode a fact about an application that the catalog could
have supplied. If a future feature needs to know something about an
application that today's schema doesn't capture, the answer is a new
catalog field — never a lookup table living somewhere else.

## 8. Metadata first

Every application carries enough metadata to support features that don't
exist yet, not just the fields the installer currently reads. `HOMEPAGE`,
`LICENSE`, and `ARCHITECTURE` have no consumer in Deployment today — they
exist because a technician-facing catalog browser, a license-compliance
report, or an architecture-filtering view are all reasonable future
features, and none of them should require a second migration to become
possible. This is a deliberate, bounded exception to "don't build for
hypothetical consumers" (Design-Principles.md principle 7): the cost here is
a few extra lines of already-curated text per application, not a new
abstraction, and the fields are populated *now*, while the information is
being gathered anyway, rather than backfilled later under worse conditions.

## 9. Presets reference applications; they never duplicate metadata

A preset (`catalog/presets.conf`) is a list of application IDs and nothing
more — see
[architecture/0006-deployment-flattening.md](architecture/0006-deployment-flattening.md).
It never repeats an application's name, description, category, or install
information. If a preset needed to know an application's category to
render correctly, that would be a bug: the catalog already knows, and the
preset should ask it, not carry its own copy.

## 10. The catalog is a product

The catalog is not merely a package list bolted onto Deployment — it is one
of JB Toolkit's core assets, with its own quality bar, its own
documentation, and its own review discipline (see
[CATALOG_STANDARD.md](CATALOG_STANDARD.md) and
[Catalog-Format.md](Catalog-Format.md)). Deployment consumes the catalog;
it does not own it, define it, or get to make catalog decisions by
implication. A change that's good for Deployment but bad for the catalog's
own coherence is not a change worth making.
