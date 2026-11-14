# Undocumented feature hunt (secondary objective)

Method: the binary describes itself better than the website. Inventory script `scratchpad/hunt/inventory.nu` dumps
`config nu --doc` option keys, `scope commands` (names, signatures) and `$nu` keys for whichever `nu` runs it;
`diff.nu` compares two dumps. Baseline: stable 0.116.0 (tarball fetched read-only); current: 0.116.2-nightly.33.
Upstream commit titles between the two: `scratchpad/hunt/commits-since-0.116.0.txt` (218 commits via the GitHub
compare API). Everything below is documented *in the binary* (`help`, `config nu --doc`, `debug
experimental-options`) but not on nushell.sh. Checked 2026-11-06: the site's configuration page mentions none of
`status_line`, `$ans`, `max_last_result_size`, `hinter.closure` (nor even `use_ansi_coloring`); the `record`
command category and `from dotenv` pages do not exist (404). The site is generated per stable release and lags
the stable binary too, so "in the binary, not on the site" is the operative test.

## Config options added (0.116.0 → nightly.33)
| Key | What it does |
|---|---|
| `status_line.enable`, `.type`, `.preview`, `.signature`, `.errors` | The REPL status line under the prompt: output type, a **live preview of the typed line's value** when it is built only from const commands (25 ms budget; this is the owner's screenshot), the command signature, and errors. |
| `color_config.status_line`, `.status_line_error` | Its colours. |
| `tui.backdrop`, `tui.border_type`, `tui.surface` | Built-in TUI widget styling (`tui …` commands are built-ins now, not a plugin). |
Already in 0.116.0 but easy to miss: `max_last_result_size` + `$ans` (last-result cache: `$ans.last/.exit_code/.duration/.command`), `hinter.closure` (custom inline hints), `show_hints`.

## Commands added
| Command | One line |
|---|---|
| `record each` | Build a new record from the entries a closure returns per field (`{|k v| …}` → record, `[k v]` pair, or null). **7× faster than `items … \| into record`** (7.7 vs 54 ms, 5,000 fields). |
| `record where` | Keep fields by row condition (`record where value > 1`, `key starts-with NU_`; rows are `{key, value}`) or closure; `--keys`/`--values`. **3× faster than `items`+`compact`** (5.4 vs 16.2 ms). |
| `record apply` | Run a record of closures on the matching fields. |
| `record walk` | Run a closure on every nested value, rebuilding the record. |
| `from dotenv`, `to dotenv` | .env parsing/serialising; handles `export X=…`. `load-env`/`with-env` now convert via `ENV_CONVERSIONS` (`--no-convert` opts out). |
| `generate completions` | Generate `extern` definitions with completions from carapace specs, fish/zsh completions, man pages or `--help`. |
| `type`, `export type` | Type aliases (`type Name = record<…>`); the owner already uses them. |
| `attr structured` | `@structured` attribute: an extern returns data. |
| `config default` | Show the default configuration. |
| `ansi opt` | Shorten ANSI sequences without changing what the terminal shows. |

## Commands removed
`date format` (use `format date`), `filter` (use `where`), `let-env` (use `$env.X = …`). Flags removed: `get --ignore-errors`/`--sensitive`, `select --ignore-errors`, `reject --ignore-errors` (use `--optional`). The library uses none of the removed forms.

## Flags added
| Flag | One line |
|---|---|
| `join --anti` | Rows of the left with no match on the right. |
| `uniq --keep-last` | Keep the last occurrence, in the first occurrence's position. |
| `path relative-to --walk-up` | Allow `..` segments when the argument is not an ancestor. |
| `find --only-matching` | Print only the matched parts, one per line. |
| `into datetime --formats` | List the string formats it reads. |
| `job spawn --auto-kill` | Let interactive `exit` kill this job silently. Without it, `exit` with a running job refuses once (`nu::shell::background_jobs_running … Run exit again to kill all jobs`). No job survives the process either way (verified). |
| `extern --strict` | Reject undeclared flags at parse time. |
| `load-env --no-convert`, `with-env --no-convert` | Skip `ENV_CONVERSIONS`/PATH conversion. |
| `tui * --border/--title/--titlebar` | Widget borders and titles (`tui label --title` → `--titlebar`). |

## Consequences for the library
- **Data-shaping rules (CLAUDE.md):** prefer `record each` / `record where` over `items … | into record` and
  `transpose … | where … | transpose --as-record` for record mapping/filtering; same closure shape as `items`.
  Sweep the library's existing sites (see counts in the runbook).
- **`env dotenv`** duplicates the builtin and mishandles `export X=` → catalog #3 item.
- **`from-bash --load`** already relies on converting `load-env` (pinned by a test); `--no-convert` is the escape hatch.
- **`completion/local`** vs `generate completions`: the builtin generates static externs; ours bridges at runtime.
  Document as alternatives.
- **`uniq --keep-last`** may simplify `conf vars`' "keep existing positions" logic.

## Experimental options (`debug experimental-options`; `nu --experimental-options [name=true]`, `all`)
| Option | Default | What it does |
|---|---|---|
| `dc-glob` | opt-in | dc-glob as the glob backend for every command (`ls`, `rm`, `cp`, `mv`, `du`, `open`, externals, `glob`): nu-glob rules everywhere, adds `{a,b}` alternatives; `glob dir/**` lists the directories below `dir`; wax's `<x:n,m>` repeats and `\\` escapes are gone. Issue #18101. |
| `reorder-cell-paths` | **on** | Row before column when accessing a table cell (less memory). #16766 |
| `pipefail` | **on** | A failing external inside a pipeline sets `LAST_EXIT_CODE` to the rightmost failure. #16760 |
| `enforce-runtime-annotations` | **on** | `let x: type = …` is checked at runtime like predefined values. #16832 |
| `native-clip` | opt-in | Clipboard commands via native APIs instead of OSC 52. #17665 |
| `cell-path-types` | opt-in | Type inference of cell paths at parse time (may be slower). #17683 |
The `debug experimental-options` command itself is the discoverable surface; three of these are already on by
default and shape behaviour the library relies on (pipefail for `complete`-based wrappers, runtime annotations).

## Not yet checked
`record walk`/`apply` semantics in depth; `status_line.signature`/`errors` rendering; whether `extern --strict`
suits the library's `extern` uses (`pman`'s `bump-nu`? none); `$ans` interaction with the test runner (REPL-only).
