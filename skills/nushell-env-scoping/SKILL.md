---
name: nushell-env-scoping
description: >
  This skill should be used when writing Nushell code that touches `$env` —
  setting or reading environment variables, persisting env across calls,
  scoping env to a closure, or debugging why an env mutation isn't visible
  somewhere. Covers `do --env`, `with-env`, the `for` vs `each`
  env-propagation distinction, and Nushell's automatic env vars. Trigger
  phrases: "env mutation", "$env", "scope", "load-env", "with-env",
  "do --env", "env doesn't propagate", "auto env var".
version: 0.1.0
user-invocable: false
---

# Nushell Env Scoping

`$env` in nu is a record like any other, but it has **scope semantics that bite hard if you don't know the rules.** Closures isolate env by default. Some constructs propagate; most don't. Some vars can't be set manually at all. This skill names the rules.

Syntax reference: [cheat-sheet → Env and Scope](../nushell-idioms/references/cheat-sheet.md#env-and-scope).

## The four propagation rules

1. **Top-level code** mutates the script's env. Always propagates downward to children.
2. **`for n in $list { … }`** — env mutations inside the loop body **propagate to the outer scope**.
3. **`each`, `items`, `reduce`, `where`** — closure invocations. Env mutations inside **do not propagate** to the outer scope.
4. **`do --env { … }`** — propagates closure mutations to caller. **`do { … }`** without `--env` does not.

This is the entire spec. The biggest trap is writing `each { |x| $env.LAST = $x }` and being surprised that `$env.LAST` is unset after.

## The three scope-affecting constructs

### `do { … }` and `do --env { … }`

Plain `do` runs the closure in an isolated scope — env mutations inside vanish at the closing brace. `do --env` propagates mutations back to the caller; reach for it whenever a closure should write to the outer env (e.g. persistence-layer save steps that need to see the user pipeline's `$env.FOO = …` writes).

### `with-env { … } { … }`

Scoped env, downward-only. Sets the given record into env only for the duration of the closure; env reverts on exit. Mutations made inside the closure do not escape — that is the point. Use it for "run this command with a specific env without polluting the parent."

### `load-env { … }`

Bulk-merges a record into env at the current scope. Subject to the same propagation rules as direct `$env.X = …` assignment: works at top level, blocked inside `each`, propagates with `do --env`.

## Automatic env vars (cannot be set manually)

In nu 0.111, these three error with `automatic_env_var_set_manually` if you try to `load-env` them:

- `PWD` — set by `cd`
- `FILE_PWD` — directory of the running script
- `CURRENT_FILE` — path of the running script

These almost certainly will not be the entire set across future nu versions. The defensive pattern is to **wrap individual `load-env` calls in `try`**:

```nu
for entry in ($record | transpose key value) {
    try { load-env { ($entry.key): $entry.value } } catch {}
}
```

This lets a single auto-var fail in isolation instead of nuking the entire load. `for` is the right iteration construct here because it propagates the successful env mutations.

There's also a longer list of `LAST_EXIT_CODE`, `OLDPWD`, `NU_VERSION`, `PROCESS_PATH` — these vary by version. The defensive `for`-with-`try` pattern handles them all without needing a static list.

## Setting env at function boundaries

A `def` is a closure boundary by default — env mutations inside a `def`'d function don't leak out. The `--env` flag opts in to caller-env mutation (`def --env name [...] { ... }`). For modules that need to set env at import time, use `export-env { … }`: the block runs in the caller's scope when `use module.nu` is invoked. Both forms are necessary because the default for functions, like for closures, is isolation.

## Common debugging move

When something env-related isn't working, dump the entries you care about as a record:

```nu
$env | select --optional KEY1 KEY2 KEY3
```

`select --optional` returns null for missing keys instead of erroring — perfect for "did this get set or not." Avoid `print $env.KEY?` chains; assemble the diagnostic as a single record so you can see all the answers together.

## The persistence-layer pattern

When persisting env across nu invocations (file-backed bucket of `$env` entries), the load/save loop is:

```nu
# Load
let __persisted = try {
    open --raw $path | from json | reject --optional PWD FILE_PWD CURRENT_FILE
} catch { {} }
for entry in ($__persisted | transpose key value) {
    try { load-env { ($entry.key): $entry.value } } catch {}
}

# User code runs here (inside `do --env { … }` if a closure boundary intervenes)

# Save
$env
| reject --optional ENV_CONVERSIONS config FILE_PWD CURRENT_FILE
| items { |k, v| try { $v | to json --raw | ignore; {($k): $v} } catch { null } }
| where $it != null
| into record
| to json --raw
| save --force --raw $path
```

The `for`+`try` on load and the `items`+`where`+`into record` on save are the two patterns to memorize. Both lean on nu's structural-data primitives rather than imperative accumulation.

## Pitfalls

- **`each` for env is the most common bug**. If you find yourself writing `each { |x| $env.something = … }`, switch to `for` immediately.
- **`do { … }` without `--env`** silently swallows mutations. The default is "isolate"; the opt-in is "propagate."
- **A failed `load-env` is atomic** — if the record contains one bad key (e.g. `PWD`), nothing else loads. Per-key try-load is defensive.
- **`with-env` changes do NOT escape** — that's the design. If you want propagation, use `do --env`.
