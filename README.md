# nu-fluency

A plugin that helps Claude write [Nushell](https://github.com/nushell/nushell) (`nu`) code idiomatically.

## Background

When first introducing Claude to `nu`, we both agreed that it seemed like an
LLM's optimal shell with it's natural language semantics and first-class support
for structured data.

This insight led to the construction of my
[`nushell-mcp`](https://github.com/zaynram/nushell-mcp).

After testing out the MCP with Claude, he would often treat it as "`bash` with
weird syntax", which we hypothesize is the result of POSIX convention being
over-represented in his training distribution.

This highlighted a need to teach Claude about Nushell and its
built-in primitives, as the default behavior of reaching for `bash` patterns
bottlnecked the advantages of `nu` semantics and structured-data support.

This plugin counteracts that bias by combining authoritative tooling (`nu-lint`)
with educational scaffolding.

## MCP Server

This plugin uses the `nushell-mcp` server, automatically installed
from it's [NPM package listing](<https://www.npmjs.com/package/nushell-mcp>).

It provides a curated set of `nu` utilities to Claude including but not limited
to: `nu_exec` (one-shot `nu` pipeline execution) and `nu_repl` (persistent `nu`
REPL sessions piggybacking off of Nushell's built-in `nu --mcp`).

## Peer Dependency: Nu-Lint

The commands packaged in this plugin prefer to delegate diagnostics to [`nu-lint`](https://codeberg.org/wvhulle/nu-lint).

`nu-lint` is a deterministic community linter for Nushell with ~150 rules across
`idioms`, `posix`-replacement, `parsing`, `dead-code`, `runtime-errors`, and more.

Most rules have auto-fixes, and the rules themselves respect the nuance of diverging
from the status quo in the age of LLM.

### Installation

```sh
# `--git <url>` - Build from latest source code
# `--locked` - Ensures compatibility with the Nushell version declared via compatiblity.
cargo install --git https://codeberg.org/wvhulle/nu-lint --locked
```

The hook system is inert by default, and will not warn or error when `nu-lint` is
unavailable. The only downside is losing out on deterministic diagnostics.

## Native LSP Integration

The plugin declares an LSP configuration with Nushell's built-in language server.

```jsonc
// .claude-plugin/plugin.json
{
    // ...
    "lspServers": {
        "nushell": {
            "command": "nu",
            "args": [
                "--lsp"
            ],
            "extensionToLanguage": {
                ".nu": "nu",
                ".nuon": "nu"
            },
            "restartOnCrash": true,
            "maxRestarts": 3
        }
    }
}
```

After plugin installation and the language server connects, Claude sees inline diagnostics,
hover info, and auto-fixes any time it edits a Nushell file.

## Components

| Type | Count | Purpose |
|---|---|---|
| Skills | 10 | `/nushell-{idioms,records,env-scoping,strings,control-flow,modules}`, `/inspect-shape`, `/env-snapshot`, `/audit-pipeline`, `/command-help` |
| Agents | 1 | Fallback review agent for `/nu-audit` when `nu-lint` isn't installed (**experimental**) |
| Hooks | 1 | Post-`nu_exec` hook that runs `nu-lint` on the executed pipeline |
| LSP | 1 | `nu --lsp` via `.lsp.json` |
| Configs | 2 | `configs/hook.nu-lint.toml`, `configs/strict.nu-lint.toml` |

### Skills

#### User-Invocable

- **`/nushell-idioms`**
— (entry point) deep syntax lookup reference
([`cheat-sheet.md`](skills/nushell-idioms/references/cheat-sheet.md)),
`bash` → `nu` equivalents, pointers to nu-lint.
- **`/inspect-shape <expr>`**
— runs `<expr> | describe` + a sample row through `nu_exec`. Structural intuition.
- **`/env-snapshot [keys...]`**
— `$env | select --optional <keys>` with sensible defaults.
- **`/audit-pipeline <pipeline>`**
— runs nu-lint (or falls back to the experimental agent if nu-lint isn't installed).
- **`/command-help <name>`**
— inline help lookup via `nu_doc_command`.

#### Model-Only

- **`nushell-records`**
— records, tables, cell paths, `items | where | into record`.
- **`nushell-env-scoping`**
— `$env`, `do --env`, `with-env`, `for` vs `each` propagation, automatic env vars.
- **`nushell-strings`**
— `parse` templates, `str` namespace, interpolation, `from <format>`.
- **`nushell-control-flow`**
— `for`/`each`/`reduce`/`any`/`all`/`take while`, conditionals, `try/catch` vs `?`.
- **`nushell-modules`**
— `module`/`use`/`export def`/`export-env`/`main`.

### Hooks

Post-tool-use hook on MCP `nu_exec` calls.
Reads the tool's `pipeline` argument from stdin (JSON),
pipes it through `nu-lint --stdin --format compact` using the narrow
`configs/hook.nu-lint.toml`, and surfaces findings as a block reason iff
there are diagnostics surfaced.

The hook config is intentionally conservative
— `posix`, `idioms`, `parsing` groups only
— so it fires on bash-translation patterns and skips stylistic noise.

For broader analysis, use `/nu-audit` (which uses the `strict.nu-lint.toml` config).

## Conventions

The hook + nu-lint catches most of these mechanically,
but for completeness they are also enumerated here.

1. When a `let` chain forms, ask whether each step is
*carrying state* or *expressing a transform*.
Transforms collapse into pipeline stages.
2. Records are nu's primary data structure.
3. Env mutations propagate through `for` loops, `collect --keep-env`, and `do --env`.
The closures used in `each`/`items`/`reduce` and bare `do`/`collect` do not support
environment mutations.
4. Optional access (`<cell-path>?`) postfix on cell paths returns `null`.
Prefer it over `try/catch` for safe property/nested property access without errors.
5. NUON string quoting is context-dependent.
Assert via in-`nu` equality checks, not raw NUON comparison.
6. The last expression in a closure or pipeline is its return value, akin to `rust`.
Don't `print` what you're returning.

## License

MIT.
