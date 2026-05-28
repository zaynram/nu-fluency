# nu-fluency

A plugin that helps Claude (and humans) write Nushell idiomatically — not "bash with weird syntax." 
The training distribution heavily over-represents bash and POSIX shell, so the default reach when writing nu is to translate bash patterns instead of using nu's own structural-data-first primitives. 
This plugin counteracts that bias by combining authoritative tooling (`nu-lint`) with educational scaffolding (skills, slash commands, an experimental fallback agent).

## Peer Dependency: `nu-lint`

The commands packaged in this plugin prefer to delegate diagnostics to [`nu-lint`](https://codeberg.org/wvhulle/nu-lint) — a deterministic community linter for Nushell with ~150 rules across `idioms`, `posix`-replacement, `parsing`, `dead-code`, `runtime-errors`, and more. 
Most rules have auto-fixes, and the rules themselves respect the nuance of diverging from the status quo in the age of LLM.

Install it:

```sh
cargo install nu-lint
```

On Windows with WSL, installing `nu-lint` inside your WSL distribution is supported. 
The plugin's hook auto-detects `wsl.exe` and routes through it.

The hook is silent when `nu-lint` is unavailable, so the plugin won't error if you skip this step; you'll just lose out on that deterministic diagnostic surface.

## Native LSP Integration

`.lsp.json` at the plugin root registers `nu --lsp` as Claude Code's language server for `.nu` files.
Once the plugin is installed and the language server connects, Claude sees inline diagnostics, hover info, and auto-fixes any time it edits a Nushell file. 
No editor configuration needed — Claude Code handles the LSP protocol end-to-end.

For users editing `.nu` files outside Claude Code, the same `nu --lsp` can be configured to work with most of the common LSP-aware editors.

It may be of interest to know that, `nu-lint` also has a language server; see the upstream [`nu-lint` README](https://codeberg.org/wvhulle/nu-lint) for editor-specific wiring.

## Components

| Type | Count | Purpose |
|---|---|---|
| Skill | 6 | Entry-point `nushell-idioms` + 5 model-only siblings (`user-invocable: false`). Pull-on-demand reference. |
| Commands | 4 | `/nu-shape`, `/nu-env-snapshot`, `/nu-audit`, `/nu-doc`. |
| Agents | 1 | **Experimental fallback** reviewer for `/nu-audit` when `nu-lint` isn't installed. |
| Hooks | 1 | Post-`nu_run` hook that runs nu-lint on the just-executed pipeline. Silent on clean code. |
| LSP | 1 | `nu --lsp` via native `.lsp.json` integration. |
| Configs | 2 | `configs/hook.nu-lint.toml` (narrow rule set for the hook) and `configs/strict.nu-lint.toml` (broad rule set for `/nu-audit`). |

## Skills

Only `nushell-idioms` shows up as a slash command (`/nu-fluency:nushell-idioms`). The five focused siblings are model-only — they auto-load when their topic comes up, without cluttering your slash menu.

- **`nushell-idioms`** (user-invocable) — entry point. Cheat sheet + bash→nu equivalents + pointers to nu-lint. Carries the cheat-sheet reference for deep syntax lookup.
- **`nushell-records`** (model-only) — records, tables, cell paths, `items | where | into record`.
- **`nushell-env-scoping`** (model-only) — `$env`, `do --env`, `with-env`, `for` vs `each` propagation, automatic env vars.
- **`nushell-strings`** (model-only) — `parse` templates, `str` namespace, interpolation, `from <format>`.
- **`nushell-control-flow`** (model-only) — `for`/`each`/`reduce`/`any`/`all`/`take while`, conditionals, `try/catch` vs `?`.
- **`nushell-modules`** (model-only) — `module`/`use`/`export def`/`export-env`/`main`.

## Commands (user-invocable)

> Note: The original `commands` are deprecated in favor of `skills` with `user-invocable: true`; the distinction is preserved in this document for clarity of usage.

- **`/nu-shape <expr>`** — runs `<expr> | describe` + a sample row through `nu_run`. Structural intuition.
- **`/nu-env-snapshot [keys...]`** — `$env | select --optional <keys>` with sensible defaults.
- **`/nu-audit <pipeline>`** — runs nu-lint (or falls back to the experimental agent if nu-lint isn't installed).
- **`/nu-doc <name>`** — inline help lookup via `nu_doc_command`.

## Hook

Post-tool-use hook on MCP `nu_run` calls. Reads the tool's `pipeline` argument from stdin (JSON), pipes it through `nu-lint --stdin --format compact` using the narrow `configs/hook.nu-lint.toml`, and surfaces findings as a block reason if (and only if) there are any. Silent on clean code, silent when nu-lint isn't installed.

The hook config is intentionally conservative — `posix`, `idioms`, `parsing` groups only — so it fires on bash-translation patterns and skips stylistic noise. For broader analysis, use `/nu-audit` (which uses the `strict.nu-lint.toml` config).

## Conventions enforced

The hook + nu-lint catches most of these mechanically. Worth knowing anyway:

1. When a `let` chain forms, ask whether each step is *carrying state* or *expressing a transform*. Transforms collapse into pipeline stages.
2. Records are nu's primary data structure. Building one via `reduce` is usually `items | where | into record`.
3. Env mutations propagate through `for` and `do --env`, not `each`/`items`/`reduce` and not bare `do`.
4. `?` postfix on cell paths returns null instead of erroring. Prefer it over `try/catch` for safe navigation.
5. NUON string quoting is context-dependent. Assert via in-nu equality returning bool, not raw NUON comparison.
6. The last expression in a closure or pipeline is its return value. Don't `print` what you're returning.

## License

MIT.
