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

A `.nu` file becomes a module when imported with `use`. The module's exported names become available under the module's name as a namespace. This is how reusable nu code gets organized — and unlike sourcing in bash, modules have explicit boundaries (only `export def`'d names are visible to the caller).

## The minimal module

```nu
# greetings.nu
export def hello [name: string] {
    $"hello ($name)"
}
```

```nu
# caller
use greetings.nu
greetings hello "world"          # → "hello world"
```

The import surfaces `greetings` as a namespace; `greetings hello` calls the exported function. To pull functions into the calling scope directly:

```nu
use greetings.nu hello           # only `hello` is imported
hello "world"                    # → "hello world" (no namespace)
use greetings.nu *               # everything exported
```

## The four export forms

### `export def` — a command

```nu
export def hello [name: string] { $"hello ($name)" }
```

### `export def --env` — a command that mutates caller env

```nu
export def --env activate [path: string] {
    cd $path
    $env.ACTIVE_PATH = $path
}
```

The `--env` flag is what lets the function's env mutations propagate back to the caller.

### `export-env { … }` — setup that runs at import time

```nu
# greetings.nu
export-env {
    $env.MYNAME = "default"
}
export def hello [] { $"hello ($env.MYNAME)" }
```

```nu
use greetings.nu
$env.MYNAME      # "default" — set when the module was imported
greetings hello  # "hello default"
```

`export-env` runs once at `use` time. It's where you initialize module-level env vars or any state that should be available immediately on import.

### `export const` — a parse-time constant

```nu
export const VERSION = "1.0.0"
```

Available as `greetings VERSION` after import. Useful for module metadata.

## The `main` command

A module can export a `main` function that runs when the module name is called by itself:

```nu
# greetings.nu
export def hello [name: string] { $"hello ($name)" }

export def main [] { "greetings and salutations!" }
```

```nu
use greetings.nu
greetings                # → "greetings and salutations!"
greetings hello "alice"  # → "hello alice"
```

This is the pattern for "a module that's primarily one command, with subcommands." Think `git`: `git` shows help, `git status` does the thing. The `main` function is `git`; the subcommands are other `export def`s.

## Inline modules

For tightly-scoped code, define a module inline:

```nu
module greetings {
    export def hello [name: string] {
        $"hello ($name)"
    }
}
use greetings hello
hello "world"
```

Inline modules don't need separate files. Good for grouping a few helpers without ceremony. The `use greetings hello` form pulls just `hello` into scope.

## Organizing a project

For a multi-file project:

```
my-project/
├── main.nu              # entry point
├── lib/
│   ├── parser.nu
│   ├── render.nu
│   └── utils.nu
```

```nu
# main.nu
use lib/parser.nu
use lib/render.nu

def run [path: string] {
    parser parse $path | render render
}
```

Modules are referenced by path relative to the importing file. Absolute paths work too. The directory structure mirrors the namespace: `lib/parser.nu` becomes `parser` namespace.

## Module-as-config

A useful pattern: a module that exists purely to set up env and helpers, imported once at session start:

```nu
# nu-fluency.nu
export-env {
    $env.NU_FLUENCY_LOADED = true
}
export def lint [path: string] { … }
export def shape [expr: any] { … }
```

```nu
# config.nu (sourced at session start)
use ~/.config/nushell/nu-fluency.nu *
```

After session start, `lint` and `shape` are available globally.

## Pitfalls

- **Forgetting `export`** — a `def` without `export` is private to the module and won't be visible after `use`.
- **`use` is parse-time**: you can't dynamically import based on a runtime variable; the path must be a literal or const.
- **`export-env` runs only once**, when the module is first imported. Subsequent `use` calls in the same session don't re-run it.
- **Module name conflicts**: if two modules export the same name and both are wildcarded into scope, the second wins. Be explicit (`use foo.nu hello as foo_hello`) if you need disambiguation.
- **`def --env` vs `export def --env`**: the `--env` flag controls env propagation; `export` controls visibility. Both are needed if you want a public env-mutating function.
