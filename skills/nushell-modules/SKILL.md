---
name: nushell-modules
description: Use when organizing Nushell code into reusable units (e.g. writing a `mod.nu` file, using the `module` keyword), exporting commands (`export def`/`export alias`), creating environment loaders (`export-env`/`source-env`), defining a `main` command for a module or script, importing another module with `use`, or when the user mentions "nu module", "reusable nu code", "export def/alias", "use module", "nu script organization", "main command", or "main subcommands".
user-invocable: false
version: 0.1.3
compatibility: { nu: '>=0.114.0' }
---

# Nushell Modules

A `.nu` file becomes a module when imported with `use`.

Only `export`ed names cross the boundary, and the import name itself becomes a namespace.

The model is closer to Python's import than to bash's `source`
— explicit boundaries, no leak of private definitions.

Syntax reference: [cheat-sheet → Modules](../nushell-idioms/references/cheat-sheet.md#modules).

## Export Eligibility

- **`export def`**
— export a function definition.
Visible after import; private without the keyword.
- **`export def --env`**
— export a function definition capable of mutating the caller's `$env` when invoked.
`--env` controls env propagation; `export` controls visibility.
- **`export-env { … }`**
— a setup block that runs once per `use` call
in the caller's scope to seed module-level env state.
Use `source-env` to load variables defined by an `export-env` block
without importing the module itself.
- **`export const NAME = …`**
— a parse-time constant.
Accessible as `$namespace.NAME` via record-style cell-path access on the
namespace name, or as bare `$NAME` after a wildcard import.

## Import Mechanisms

| Form | Scope Additions | Use Cases |
|---|---|---|
| `use foo` | Namespace `foo` only | You want the prefix discipline; few callers |
| `use foo bar` / `use foo [bar1 bar2]` | The named exports, unprefixed | A small, named subset of the module; frequently used |
| `use foo *` | All exports, unprefixed; constants as `$NAME` | Module-as-config or short scripts where prefix is noise |

`use` is **parse-time**. The path must be a string literal or a const
— you cannot import based on a runtime value.

- Certain commands resolve during parse time, (e.g. `path join`, `path expand`)
which provides limited flexibility to scripts/modules to import other modules
by assigning the `NU_LIB_DIRS` constant to an array of directories to include
at parse time when resolving imports.

### Example

```nu
#!/usr/bin/env -S nu --stdin

# Suppose we have a module `foo` at ~/modules/foo/mod.nu.
# Since `~/modules/` is not searched by default, the script
# will fail during parse time due to the unresolved module.

use foo # Error: nu::parser::module_not_found

# Since `$nu.home-dir` is a built-in constant, we can use
# `path join` and resolve our module directory at parse time.
# Technically we could assign this as a literal path, but
# for portability this is the preferred method.

const MODULES: path = $nu.home-dir | path join modules

# The parser still needs to be told where our module is
# located before it can be imported, so add the path
# to the NU_LIB_DIRS constant.

const NU_LIB_DIRS = [$MODULES]

# Then, we can import our module as normal within the script
# without the unresolved module errors.
use foo
```

## Dispatch (`main`, subcommands, and constants)

When importing an exported `main` command selectively (i.e. `use foo [bar main]`),
it's accessible through the module name itself (calling `foo` will run its `main`)

If `main` is not exported, it's only accessible by running the module file
directly as a script (`nu foo/mod.nu`/`run foo/mod.nu`).

Invoke a `nu` script directly through its path (must be executable)
or using either the `nu` binary or the `run` built-in command.

- `[nu|run] <script> ...<args>` - runs the script normally with arguments
- `... | nu --stdin <script> ...<args>` - converts pipeline input to a string
- `... | run <script> ...<args>` - retains pipeline input's native Nushell type

> Executable scripts that read from stdin require the shebang
`#!/usr/bin/env -S nu --stdin` (-S required for flags with `env`)

Subcommands definitions depend on the execution surface (script vs. module).

- For scripts, prefix subcommands with `main` (e.g. `def "main bar"`).
- For modules, export subcommands without a prefix (e.g. `export def bar`).

Importing a subcommand (e.g. `use foo "main bar"`) will _not_ be accessible
as `foo bar`; it becomes `main bar`.
To share subcommands between the two surfaces, export an unprefixed `alias`
for signature consistency.

### Example

```nu
#!/usr/bin/env -S nu --stdin
# bar.nu
const MSG: string = 'hello world'
export const ABC: int = 123
def "main greet" [name: string]: nothing -> string { $"hello ($name)" }
export def "main thank" [name: string]: nothing -> string { $"thanks, ($name)" }
export def main []: nothing -> string { $MSG }
export alias greet = main greet
```

```nu
use bar.nu
## exported main
bar # hello world
./bar.nu # hello world
## unexported "main greet" / exported alias greet
bar greet claude # hello claude
./bar.nu greet claude # hello claude
bar main greet claude # Error: nu::parser::extra_positional
## exported "main thank" / no alias
bar thank claude # Error: nu::parser::extra_positional
./bar.nu thank claude # thanks, claude
bar main thank claude # thanks, claude
## exported const ABC
$bar.ABC # 123
## unexported const MSG
$bar.MSG # Error: nu::shell::column_not_found
```

## Inline Modules

Define modules without a separate file using the `module` keyword.
This is particularly useful for arranging submodule hierarchies or grouping
helpers/utilities.

- `export module x { ... }` — export a submodule namespace `x` as member
- `module y { ... }` — define a submodule without external accessibility
(only available in the parent module's scope)
- `module y { ... }; export use y` — export submodule namespace `y` as a member
- `module z { export def one [] { 1 } }; export use z one` —
export submodule member `one` as member of the parent module

## File Structure

Define module files as either `<name>/mod.nu` or `<name>.nu`.

When the module directory or file is in one of the `NU_LIB_DIRS`, import it by name.

- `<name>/mod.nu` - `use <name>` (with or without trailing slash)
- `<name>.nu` - `use <name>.nu`

When the module is in a location the parser is not made aware of,
import it via an absolute path or a path relative to the current file.

When defined as `<name>/mod.nu`, it's possible to define submodules
as subdirectories of the same layout (e.g. `<name>/<submodule>/mod.nu`).
Import submodules of this form as `use <name>/<submodule>` for the full
submodule namespace, or `use <name> <submodule>` for the member exposed
by the parent module. Note that the interfaces exposed by each form are
not guaranteed to be the same, as the parent controls the exposed submodule
members.

## Configuration Modules

Environment seeding and scoping helpers are a valid use for modules.

- Use `export-env` with `source-env <file>` instead of `use <file>`
to seed environment variables if there are no exported commands.
- Otherwise, use a wildcard import to seed everything at the same time
(e.g. `use <file> *`)

## Modules with `nu_exec`

When using the `mcp__nushell__nu_exec` tool, internally it wraps the pipeline
by a `do {  }` call, writes it to a temporary script file, and invokes it as
`nu <script> ...<options>`. This inadvertantly inhibits scope introspection and
any relative paths to the `cwd` in `use` calls will error.

This is a documented limitation in the server, and is an actively tracked issue.
For now, there are a few methods for using modules with the `nushell-mcp`:

1. Set `const NU_LIB_DIRS = [...]` at the start of the pipeline to include the
parent directories of any modules or scripts before calling `use`.
2. Use `nu_repl` instead of `nu_exec`. REPL sessions are not subject to this limitation.
3. Use absolute paths in any `use` calls, so resolution doesn't depend on the
script's location.

## Anti-Patterns

- **Forgetting `export`** — a `def` without `export` is private to the module.
If the function name is not "main" or "main <name>", this definition is inaccessible
across all execution surfaces.
- **Expecting `namespace CONST` to fetch a constant** — use `$namespace.CONST`
(record-style) or wildcard-import to get `$CONST`.
- **Wildcard name collisions** — `use foo.nu *; use bar.nu *` with overlapping exports:
the second wins silently; prefer `overlay use foo`/`overlay use bar` with
`overlay hide` to add and remove commands from the current scope while controlling
the clobber behavior.
- **Dynamic paths** — `use $some_var` only works for variables resolvable
at parse time; include the parent in `NU_LIB_DIRS` or pass it as a literal or `const`.
- **Subcommand shadowing** — exported command names eat `main`'s positionals;
a module `bar` exporting both a `main` and `foo` command will cause bare `bar foo`
to invoke the subcommand. Quote the string literal to pass it as an argument
(e.g. `bar 'foo'`).
