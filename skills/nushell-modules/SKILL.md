---
name: nushell-modules
description: >
  This skill should be used when organizing Nushell code into reusable
  units — writing a `.nu` file as a module, exporting commands with
  `export def`, setting up shared env via `export-env`, defining a
  module's `main` command, or importing/using another module with `use`.
  Trigger phrases: "nu module", "reusable nu code", "export def",
  "use foo.nu", "nu script organization", "module main command".
version: 0.1.0
user-invocable: false
---

# Nushell Modules

A `.nu` file becomes a module when imported with `use`. Only `export`'d names cross the boundary, and the import name itself becomes a namespace. The model is closer to Python's import than to bash's `source` — explicit boundaries, no leak of private definitions.

Syntax reference: [cheat-sheet → Modules](../nushell-idioms/references/cheat-sheet.md#modules).

## What can be exported

- **`export def`** — a command. Visible after import; private without the keyword.
- **`export def --env`** — a command that mutates the caller's `$env` when invoked. `--env` controls env propagation; `export` controls visibility. Both are needed for a public env-mutating function.
- **`export-env { … }`** — a setup block that runs once at `use` time, in the caller's scope. Use it to seed module-level env state.
- **`export const NAME = …`** — a parse-time constant. Accessible as `$namespace.NAME` via record-style cell-path access on the namespace name, or as bare `$NAME` after a wildcard import.

## Three ways to import

| Form | Brings into scope | Use when |
|---|---|---|
| `use foo.nu` | Namespace `foo` only | You want the prefix discipline; few callers |
| `use foo.nu name1 name2 …` | The named exports, unprefixed | A small, named subset of the module is used often |
| `use foo.nu *` | All exports, unprefixed; constants as `$NAME` | Module-as-config or short scripts where prefix is noise |

`use` is **parse-time**. The path must be a string literal or a const — you cannot import based on a runtime value.

## Dispatch: how `main` and subcommands interact

This is the most subtle part of nu modules in 0.113 and the part most often gotten wrong.

**Without an `export def main`** the namespace name is not callable on its own; it only routes to subcommands:

| Call | Result |
|---|---|
| `use foo.nu; foo` | Error — `foo` is not a command |
| `use foo.nu; foo bar arg` | Calls the exported `bar` with `arg` |
| `use foo.nu; foo CONST` | Error — constants are not subcommands |
| `use foo.nu; $foo.CONST` | ✓ Returns the constant |

**With an `export def main`** the namespace name becomes the command, and positional args go to `main` — subcommand-style dispatch via the namespace stops working:

| Call | Result |
|---|---|
| `use foo.nu; foo` | Calls `main []` |
| `use foo.nu; foo arg` | Calls `main [arg]` — `arg` is a positional argument to `main`, never a subcommand name |
| `use foo.nu; foo bar arg` | Error — `bar`, `arg` are extra positionals on `main` |
| `use foo.nu; $foo.CONST` | ✓ Returns the constant |

So **`main` and namespace-subcommand dispatch are mutually exclusive**. If you want both "bare invocation does the default thing" and "named subcommands", pick one of:

- **Selective import** — `use foo.nu hello`; then `hello` is a top-level command. The default behavior (your old `main`) stays reachable via `foo`. Each piece needs its own `use`.
- **Wildcard import** — `use foo.nu *`; all exports become top-level. `main` is still reachable as `foo`. Constants become `$NAME`.
- **No `main`** — keep dispatch via the namespace (`foo bar`, `foo baz`) and document that bare `foo` isn't a command.

This is the inverse of git's CLI ergonomics. A nu module with `main` is "a command that happens to have helpers exported alongside it"; a nu module without `main` is "a flat namespace of commands." There is no clean "main plus subcommands" in 0.113 without selective/wildcard import on the caller side.

## Inline modules

`module name { … }` defines a module without a separate file. Same export and dispatch rules as file modules. Useful for grouping a few helpers in a script that doesn't need to be split out.

## Project layout

Path is relative to the importing file (or absolute). Directory structure mirrors the namespace: `lib/parser.nu` imported as `use lib/parser.nu` exposes `parser` as the namespace. There is no `__init__`-style aggregator file — each module is its own `.nu`.

## Module-as-config

A module imported once at session start, intended purely to install env and helpers into the calling scope:

- Wildcard the import in `config.nu` (`use ~/.config/nushell/nu-fluency.nu *`).
- Put the env seed in `export-env { … }`.
- Don't define a `main`; the module isn't meant to be "invoked."

## Pitfalls

- **Forgetting `export`** — a `def` without `export` is private to the module. The error at the call site is "Command not found", which is confusing if you expected it to be visible.
- **Expecting `namespace subcommand args` to work when `main` is defined** — it doesn't. The subcommand name is treated as a positional argument to `main`. This is the single most common module bug.
- **Expecting `namespace CONST` to fetch a constant** — same trap as above. Use `$namespace.CONST` (record-style) or wildcard-import to get `$CONST`.
- **`export-env` only runs at first `use`** — subsequent `use` in the same session is a no-op for env setup.
- **Wildcard name collisions** — `use foo.nu *; use bar.nu *` with overlapping exports: the second wins silently. Disambiguate with `use foo.nu name as foo_name`.
- **Dynamic paths** — `use $some_var` does not work. `use` resolves at parse time; the path must be a literal or `const`.
