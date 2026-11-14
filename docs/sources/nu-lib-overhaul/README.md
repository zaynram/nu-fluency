# nu-lib overhaul: source material

Inputs for [#20](https://github.com/zaynram/nu-fluency/issues/20), kept so the
findings outlive the laptop they were written on.

## Runbook (verbatim)

Session notes from the nu-lib overhaul
([nu-lib#9](https://github.com/zaynram/nu-lib/issues/9)), never committed to
nu-lib. Measured on 0.116.2-nightly.32/.33; the claims the skills now carry
were re-checked on 0.117.0 (see the table below).

| File | What it holds |
|---|---|
| `runbook/nushell-ergonomics.md` | Constructs that mislead a bash-conditioned reader; the session's feedback for this plugin |
| `runbook/05-nightly-bugs.md` | Bug candidates with repros and issue drafts for nushell/nushell |
| `runbook/undocumented-features.md` | In-binary features missing from nushell.sh, 0.116.0 to nightly.33 |
| `runbook/11-startup-assessment.md` | Import-cost measurements for the library |

## nu-lib `_docs` (by permalink)

These are committed in nu-lib, so they are linked rather than copied:

- [`startup-time.md`](https://github.com/zaynram/nu-lib/blob/8ef711d/_docs/startup-time.md)
- [`data-shaping.md`](https://github.com/zaynram/nu-lib/blob/8ef711d/_docs/data-shaping.md)
- [`nightly-features.md`](https://github.com/zaynram/nu-lib/blob/8ef711d/_docs/nightly-features.md)
- [`testing.md`](https://github.com/zaynram/nu-lib/blob/8ef711d/_docs/testing.md)
- [`CLAUDE.md`](https://github.com/zaynram/nu-lib/blob/8ef711d/CLAUDE.md)

## Re-checked on 0.117.0

| Claim | 0.117.0 |
|---|---|
| `record each` / `record where` exist, same contract as `items` | holds |
| Empty block or `()` arm passes pipeline input through | holds |
| `$in` in a `match` arm is the match's input, not the subject | holds |
| Bare `let x;` binds the block's input; `… \| let x \| …` tees | holds |
| `!` cell-path suffix is case-insensitive | holds |
| Bare word as a `match` arm value runs a command | holds |
| `if ($in \| …)` on a later statement sees an empty input | holds |
| `into record` on a table merges rows, later rows win | holds |
| `export use` does not run the module's `export-env` | holds |
| `source-env` runs the file's top-level statements | holds |
| Guarded `source-env`/`use` of a missing file is a parse error | holds |
| A module cannot export a command named like itself | holds |
| `to nuon` is not a const command | holds |
| `hide-env` is a no-op after `do --env` / a `def --env` call (bug) | still reproduces |
| `try`/`catch` in a command whose output is piped to `ignore` (bug) | still reproduces |
| `def "a (x)"` gives "no space between name and parameters" (bug) | still reproduces |
| `def "a #b"` gives an explicit name error | holds; message now lists every disallowed form |
| Experimental options: `pipefail`, `enforce-runtime-annotations`, `reorder-cell-paths` on by default | holds |
