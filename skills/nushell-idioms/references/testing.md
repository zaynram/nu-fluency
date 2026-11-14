# Testing Nushell code

Framework-free lessons from building a Nushell test runner. They hold whichever
runner (or none) a project uses.

## Assertions

`use std/assert` gives `assert`, `assert equal`, `assert error`,
`assert length`, `assert str contains` and the comparison forms. A failed
assertion raises, so a test is any command that returns normally when it passes.

```nu
use std/assert
assert equal ([1 2] | length) 2
assert error { error make {msg: boom} }
```

## Run each test in a child interpreter

A test that runs in the caller's shell can see and change its state: imported
modules, `$env`, `export-env` side effects. Run it in a fresh process instead:

```nu
^nu --no-config-file -I $repo_root -c 'use mymod; assert-things' | complete
```

`complete` gives `exit_code`, `stdout` and `stderr`; a raise in the child is a
non-zero exit with the error on stderr.

- **Pass the include path with `-I`.** Modules that import each other by bare
  name resolve through `NU_LIB_DIRS`; without `-I <checkout>` a worktree's
  modules can silently resolve from another checkout on the caller's path.
- **Build the child's environment, don't scrub it.** `hide-env` is a silent
  no-op after any `do --env` or `def --env` call in scope (a bug still present
  in 0.117.0), so start the child from scratch where an `env` program exists
  (`^env -i PATH=$env.PATH HOME=$tmp nu …`).
- **Sandbox state.** Point `HOME` and `XDG_*` at a temp tree so code that
  persists state (`std-rfc/kv --universal`, caches) never touches real data.
  `std-rfc/kv` does not create `$XDG_DATA_HOME/nushell`; create it first.
- **Give the child no terminal.** `input` reads the terminal, not stdin, so an
  empty stdin does not stop a prompt from hanging the run; detach with `setsid`
  where it exists, and bound children with a timeout.

## Calling a test by name

Nushell has no string-eval, and a variable in command position evaluates to its
value: with `let n = "test x"`, a bare `$n` is the string `"test x"`, not a call.
A runner that dispatches "by name" this way makes every test pass vacuously.
Write the literal command name into the child's program text instead, which
means test names must parse as bare words (no quotes, brackets, `|`, `;`, `#`).

## Report unavailable dependencies as skipped

A test whose program, OS or credential is missing should report `skip`, never
`ok` or `fail`, so a green run means what it says.
