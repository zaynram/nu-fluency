# Nightly bug candidates (file after all other primary goals)

Re-verified 2026-11-06 on 0.116.2-nightly.33 (host bumped mid-session): items 1, 1b, 2, 3 and 4 all reproduce
unchanged. Full stack suite on .33: 826 ok / 0 fail / 4 skip in both isolation modes; selftest 25/25.

Dropped per owner: `export use` skipping export-env (by design); imported `skip` clobbering builtins in later
parses (documented, unavoidable).

1. hide-env ignored after do --env in an enclosing scope (0.116.2-nightly.32)
   `$env.FOO = 1; do { do --env { }; hide-env FOO; $env has FOO }` → true (expected false). Also inside a def called
   from such a block: `$env.X = 1; def f [] { hide-env X; print $env.X? }; do { do --env { null }; f }` prints 1.
2. try/catch inside a block does not catch when the block's output is piped to `ignore` (0.116.2-nightly.32)
   `def f [] { try { error make {msg: inner} } catch { "caught" } }; f | ignore` → error "inner" escapes.
   Same with `do { try {…} catch {…} } | ignore`, with or without `--show-errors`; `f`, `f | to nuon`, and an inline
   `try {…} catch {…} | ignore` behave. Contradicts both try semantics and ignore's docs (errors only pass with -x).
   Owner asked whether it's just stderr: no. As a plain script the pipeline aborts (exit 1, following statements
   don't run), an outer try receives a full nu::shell::error record, and f's own `catch` block never executes (a
   `print --stderr` in it never appears). Hypothesis for the report: the try body is evaluated lazily when the
   block's output is drained by `ignore`, after `try` has returned.
3. `hide-env` is a no-op even in its OWN scope after a `def --env` command ran earlier in that scope (.33 verified):
   `def --env g [] { $env.G = 1 }; $env.H = 1; def f [] { g; hide-env H; print ($env.H? | default unset) }; f` → 1.
   Same family as item 1 (any env-propagating call poisons later hide-env in the block).
   `default <closure>` literal vs variable asymmetry: by design (lazy literal) — not a bug; dropped.
4. (verify) `def "a (x)" [] { }` and `def "test a [b]" [] { }` fail with "no space between name and parameters"
   although the name is a quoted string (and `def "a #b"` → "Command name not supported", which at least is explicit).
   Misleading diagnostic at minimum; possibly names with `(`/`[` should be rejected with the explicit message.

---
# Issue drafts (for nushell/nushell; I cannot file them from this session — GitHub access is scoped to nu-lib)

## Draft 1 — `hide-env` silently does nothing after an env-propagating call in the same block

**Describe the bug.** Once a `do --env { … }` block or a `def --env` command has run earlier in the same scope,
a later `hide-env` in that scope is a no-op: the variable stays set, no error is raised. It also fails within the
scope that calls it, not only toward the caller.

**How to reproduce** (0.116.2-nightly.33, Linux x86_64, `nu --no-config-file`):
```nushell
$env.FOO = 1; do { do --env { }; hide-env FOO; $env has FOO }        # true   (expected false)
$env.FOO = 1; do { hide-env FOO; $env has FOO }                       # false  (control)
def --env g [] { $env.G = 1 }
$env.H = 1; def f [] { g; hide-env H; $env.H? | default unset }; f  # 1      (expected unset)
```
**Expected behavior.** `hide-env FOO` removes `FOO` from the current scope regardless of what ran before it.
**Context.** Found while building a test runner that scrubs the environment of child processes; the workaround is
`env -i` for externals and binding values before any `--env` call. Nushell 0.116.2-nightly.33; also on nightly.32.

## Draft 2 — `try`/`catch` inside a command does not catch when the command's output is piped to `ignore`

**Describe the bug.** A `try { … } catch { … }` that is the last expression of a custom command stops catching when
the command's output is piped into `ignore`: the error escapes to the caller, the pipeline aborts (exit 1 in a
script), and the `catch` block never runs. Piping into other commands (`to nuon`) behaves correctly, and an inline
`try {…} catch {…} | ignore` outside a command behaves correctly.

**How to reproduce** (0.116.2-nightly.33):
```nushell
def f [] { try { error make {msg: inner} } catch { print --stderr "catch ran"; "caught" } }
f               # caught
f | to nuon     # "caught"
f | ignore      # Error: inner  — "catch ran" is never printed; the script exits 1
do { try { error make {msg: inner} } catch { "caught" } } | ignore   # same
try { f | ignore } catch {|e| $e.msg }                                # inner
```
`ignore --show-errors` makes no difference. `help ignore` says errors pass through only with `-x`.
**Expected behavior.** The error is caught inside `f`; `ignore` receives `"caught"` and discards it.
**Suspected cause.** The `try` body's value is evaluated lazily when `ignore` drains the block's output, after
`try` has returned, so the raise happens outside the protected region.

## Draft 3 — misleading diagnostic for a quoted command name containing `(` or `[`

**Describe the bug.** `def "a (x)" [] { }` and `def "a [b]" [] { }` fail with "no space between name and
parameters", which points at a non-problem (there is a space). `def "a #b" [] { }` fails with the explicit
"Command name not supported", which is the message the other two should get if such names are rejected on purpose.

**How to reproduce** (0.116.2-nightly.33):
```nushell
def "a (x)" [] { }   # Error: no space between name and parameters
def "a #b" [] { }    # Error: Command name not supported
```
**Expected behavior.** Either the quoted name is accepted (it is a quoted string), or the error says the name is
not supported, as for `#`.
