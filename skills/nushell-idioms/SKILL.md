---
name: nushell-idioms
when-to-use: This skill should be used when writing, reading, or executing Nushell code. This includes any `.nu` script, the `nu_run` MCP tool, or pipelines that contain Nushell-specific operators like `$env`, `do --env`, `where`, `each`, or `|` chains with structured data. Potential trigger phrases include 'nushell', 'nu script', 'nu pipeline', 'writing nu', 'calling nu_run', 'convert this to nu'.
user-invocable: false
description: Recalibrates toward idiomatic Nushell instead of bash-translated patterns.
version: 0.1.0
---

# Nushell Idioms

Nushell is a **structural-data-first** shell.

Native types outside of base primitives (`string`, `int`, etc.) are expansive:

- `record` -> mapping of key-value pairs
- `list` -> sequence of elements
- `table` -> sequence of records with compatible columns (keys)
- `filesize` -> byte-measurement unit (uses suffix; i.e. `3GB`)
- `duration` -> timespan-measurement unit (uses suffix; i.e. `2sec`)
- `datetime` -> temporal-measurement unit (run `date --help` in nu for more info)

The biggest source of mistakes when writing nu is reaching for bash patterns.

- Bash uses text-streaming which can cloud intuition about Nushell.
- Bash dominates training data and is warmed for shell-related operations.

This skill names many common traps and their idiomatic replacements.

## Language Protocols: Nushell LSP and Nu-Lint

The bundled LSP uses the native `nu --lsp` server.

- This provides simple, realtime diagnostics when working on Nushell files.

When available, the `nu-lint` command provides much richer diagnostics.

- This is what the plugin's post-`nu_run` hook calls when checking a pipeline.

It's a deterministic community-maintained linter with ~150 rules.

Namely, the `posix` rule-group aims to "replace common bash/posix patterns".

- These rules cover a large subset of bash → nu translation traps.

Useful entry points:

- `nu-lint <path>` — lint files in a directory (default `.`)
- `nu-lint --stdin --format compact` — lint a snippet from stdin, one line per finding
- `nu-lint --explain <rule>` — full rationale for a specific rule
- `nu-lint --list` — every available rule, by group
- `nu-lint --fix <path>` — apply auto-fixes (most rules support this)

The rest of this skill is a recalibration toolkit.

Use it for cases where nu-lint isn't installed or additional information is sought.

## Self-Prompted Reflection

Internalize asking yourself the following question when composing a Nushell pipeline:

> For each `let` assignment, does it carry a state forward or express a transformation?

- state -> keep the `let`
- transformation -> collapse into pipeline

Majority of the time, it is a transformation and does not need assignment.

Two `let` forms exist and behave differently:

- **Statement form** `let name: TYPE = <expr>` is parse-time. Type annotation is enforced (record/string mismatches reject; lists widen if there's overlap with the annotation).
- **Pipeline form** `<pipeline> | let name` is runtime. Any `: TYPE` annotation is cosmetic — the binding takes the pipeline's actual type; no typecheck runs. Reach for it when binding a name mid-stream is genuinely useful; do not reach for it to "check the shape of a value at runtime".

## Bash to Nushell Equivalents

| Bash | Nushell |
|---|---|
| `$( cmd \| jq … )` capture and parse | `cmd \| from json` (nu reads JSON, YAML, CSV, TOML natively) |
| `for x in $(ls); do …; done` | `ls \| each { \|f\| … }` or `for f in (ls) { … }` |
| `grep pattern file` | `open file \| where $it =~ "pattern"` (or `find "pattern"`) |
| `awk '{print $2}'` | `split column " " \| get column2` |
| `sed 's/a/b/'` | `str replace 'a' 'b'` |
| `cat f \| head -n 5` | `open f \| first 5` |
| `wc -l < file` | `open file \| lines \| length` |
| `arr=(a b c); echo "${arr[1]}"` | `let arr = [a b c]; $arr.1` |
| `[[ -n "$x" ]]` | `($x \| is-not-empty)` |
| `if [[ "$x" == "y" ]]; then …; fi` | `if $x == "y" { … }` |
| `read -r line` | (rare; nu is non-interactive by default in scripts) |
| `printf "%s\n" "${arr[@]}"` | `$arr \| each { print $in }` (but usually you just want `$arr`) |
| `cmd 2>/dev/null` | `cmd e>\| ignore` (drop stderr); `cmd \| complete` to capture both for inspection |
| `set -e` | (built-in; pipelines stop on first error unless `try` wraps) |

## Anti-Patterns: Common Mistakes

These show up in nu code written by people fluent in bash. Each has a one-line correction.

### 1. Two sequential `let`s where one pipeline would do

```nu
# anti-pattern
let parsed = ($env.RAW_INPUT | from json)
let result = ($parsed | where active == true | length)

# idiomatic
let result = ($env.RAW_INPUT | from json | where active == true | length)
```

The intermediate name `parsed` doesn't earn its keep — nothing else uses it.

### 2. `each` with `$env` mutation (won't propagate)

```nu
# anti-pattern — env mutations inside `each` are invisible after
[1 2 3] | each { |n| $env.LAST = $n }
$env.LAST  # error: not set

# idiomatic — `for` propagates env mutations to the outer scope
for n in [1 2 3] { $env.LAST = $n }
$env.LAST  # "3"
```

Same applies to `items`, `reduce`.

Only `for` (and top-level code) propagates `$env` by default.

### 3. `try/catch` swallowing a single cell-path access

```nu
# anti-pattern
let name = (try { $person.name } catch { "unknown" })

# idiomatic — `?` postfix returns null instead of erroring
let name = ($person.name? | default "unknown")
```

### 4. `print` chains before a return

```nu
# anti-pattern
print $env.A
print $env.B
print "done"
$env.RESULT

# idiomatic — last expression IS the return
{a: $env.A, b: $env.B, result: $env.RESULT}
```

If you want all three visible AND the result, return a record.

If you really need to print mid-pipeline, that's a side effect; do it sparingly.

### 5. Explicit `get N` for list indexing

```nu
# anti-pattern
let third = ($planets | get 2)

# idiomatic
let third = $planets.2
```

Cell paths work on lists too.

## Anti-Patterns: False Positives

Nu's idioms can look unfamiliar coming from bash.

These are all correct and intentional:

1. **Implicit Return**

The last expression of a closure or pipeline **always** returns a value.

There is little reason to use the `return` keyword outside of early exits.

There is almost no reason to use the `echo` keyword, ever.

- Nushell's built in `echo` does not print to `stdout`, it _returns_ the value.
- `'some string'` is equivalent to `echo some string`

2. **Contextual Strings**

Strings in the starting position of an expression are always _invoked_.

- `whoami` => `<username>`
- `/usr/bin/whoami` => `<username>`

Nushell parses tokens, so most strings can be provided as arguments without quotes.

Strings with whitespace that are to be treated as one argument still requires quotes.

- `cd example/path` is valid
- `cd 'example/path with whitespace'` is valid

Function signatures can specify an argument's type as `path`.

- This streamlines path resolution and operations using the argument in the function.
- The value itself, when piped to `describe`, will still show `string`.

Function signatures can also specify an argument's type as `glob`.

- Unlike `path`, `glob` values piped to `describe` will return `glob`.
- Conversion to `glob` is supported by `into glob`.
- Conversion from `glob` is supported by `into string`.
- The built in `ls` command uses a `glob` argument signature.

Path and glob arguments do not require quotations, unless they contain whitespace.

- `ls foo/bar` is valid and equivalent to `ls "foo/bar"`
- The same follows for `ls foo/**/*`

Records, tables, and lists treat unparenthesized tokens as strings.

- `{me: whoami} | get me` => `whoami`
- `{me: (whoami)} | get me` => `<username>`

The quotation character used influences the parsing behavior.

- Double-quotes allows backslash-escaping:
  - `"\n"` => `<newline>`
- Single-quotes are treated as literal strings:
  - `'\n'` => `\n`
- This behavior also applies to string interpolation.

Interpolation uses parentheses and a distinct convention that differs from bash.

- Interpolated strings are prefixed with `$` and may use double or single quotes.
- Subexpressions are used for evaluated values; bracketed expansion is unsupported.
  - `$"hello ($env.USER)"` is the Nushell equivalent of `echo "hello ${USER}"`

3. **Environment Mutation**

Environment mutations are made through direct assignments on `$env` or with `load-env`.

```nu
$env.x = 'assigned'
$env.x # assigned
```

```nu
load-env {x: loaded}
$env.x # loaded
```

Temporary environments may be used through the `with-env` command.

```nu
with-env {x: temporary} { $env.x } # temporary
```

By default, closures and functions do not persist enviornment changes.

- Use the `--env` flag to propagate environment changes.

  ```nu
  def --env call [] { $env.called = true }
  $env.called? # null
  call
  $env.called? # true
  ```

  ```nu
  let env_sum: closure = {|a: int, b: int| load-env {sum: ($a + $b)} }
  $env.sum? # null
  do --env $env_sum 3 7
  $env.sum? # 10

  ```

## Sibling Skills

This skill may not cover the full extent of any inquiry or composition.

The following mapping can be used to compound relevant sibling skills:

[`nushell-records`](../nushell-records/SKILL.md)

- Load when working with records or tables.

[`nushell-env-scoping`](../nushell-env-scoping/SKILL.md)

- Load when working with `$env`, persistence, or scope propogation.

[`nushell-strings`](../nushell-strings/SKILL.md)

- Load when working with string parsing, formatting, or interpolation.

[`nushell-control-flow`](../nushell-control-flow/SKILL.md)

- Load when working with iteration, conditionals, and/or error handling.

[`nushell-modules`](../nushell-modules/SKILL.md)

- Load for writing/organizing nu code into reusable units.

## References

[cheat sheet](./references/cheat-sheet.md)

- Syntax-dense quick reference with annotated examples and inline-comment results for every primitive, plus sections on conversions, records, lists, tables, strings, filesystem, env and scope, variables, control flow, custom commands, modules, and cross-cutting flags.
- Each section that has a matching sibling skill links back to it as the conceptual reference.

## Constraints

Refrain from using `print` whenever pipeline result would suffice.

Debug using Nushell's introspection commands (i.e. `inspect`, `debug`, `describe`).

Pay attention to both "what" differs from bash and "why" it differs.

- This will help build an _intuition_ for "thinking-in-nu"
