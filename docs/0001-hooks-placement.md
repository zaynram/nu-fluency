---
status: draft
date: 2026-08-20
decision-makers: [{ name: Zayn Ramdass, email: ramdasszayn@gmail.com }]
consulted: [claude-sonnet-5]
---

# Hooks Placement

## Context and Problem Statement

We need to decide on where the expanded hook layer should exist at the
plugin root, or scoped to individual skills.

## Decision Drivers

* Interoperability
* Separation of concerns
* Maintenance burden

## Considered Options

* **standalone-file**: `hooks.json` implemented at the plugin root
* **config-property**: `"hooks"` property in `.claude-plugin/plugin.json`
* **per-frontmatter**: Frontmatter of individual `SKILL.md` files

## Decision Outcome

Chosen option: **standalone-file**, because it's a centralized option which reduces
the total maintenance burden and it maintains it's own distinct separation of concerns
from the remaining configuration options.

### Consequences

* Good, because centralization places all hook configurations in one place which
makes maintenance easier as a solo-developer.
* Good, because a standalone file differentiates the heightened role and responsibilities
from other configuration properties.
* Bad, because specialized hooks with SKILL-specific behavioral targets
become hoisted and will run regardless of their respective SKILL's invocation status.
