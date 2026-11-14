# Code that is unintuitive from a bash-conditioned reader's perspective

Secondary deliverable: feedback for the owner's Nushell tooling (nu-fluency skills, lint rules).
Each item: the construct, where it appears, what a bash-conditioned reader assumes, what it actually does,
and how badly it tripped me (★ = slowed me down, ★★ = I briefly misdiagnosed something, ★★★ = I would have written a bug).
Every semantic claim below was checked on 0.116.2-nightly.32.

## A. Implicit pipeline-input flow (the biggest category)

1. **Empty block as identity** — `| if $debug { debug echo x } else { }`, `| if $libs != null {…} else { default [] }`,
   `match … { record => () … }` (command/mod.nu:18, test/mod.nu:185,439).
   Bash reads `else { }` / `()` as "produce nothing". In nu, an empty block or `()` with pipeline input passes the
   input through (`5 | if false {x} else { }` → `5`). ★★★ — I'd have "simplified" these into bugs.
   *Tooling idea:* an idiom card "empty arm = pass-through", or a lint that suggests a named `identity`/comment.

2. **`$in` inside `match` arms** — `$root | try { path expand | match ($in | path type) { dir => (glob $"($in)/**") } }`
   (test/mod.nu:186-189). The subject is `($in | path type)`, but `$in` *inside an arm* is the pipeline input to
   `match` (the path), not the subject. Two different `$in`s in one line. ★★ — I initially suspected this as the TODO's
   path bug; it was actually correct (the real bug was positional dirs being `source`d).
   *Tooling idea:* skill note: "in a match arm, `$in` = match's pipeline input, never the subject"; prefer binding
   (`let p = …; match ($p | path type) { dir => (glob $"($p)/**") }`) when both appear.

3. **`let` as a pipeline tee / statement capturing `$in`** — `$r | lines | let ls | where …` (test/mod.nu:361) and
   `do {|| let key: cell-path; … }` with no `=` (hook/mod.nu:39). Both bind the *pipeline input*; the mid-pipeline
   form also passes it on. No bash analog; reads like a syntax error. ★★
   *Tooling idea:* flag bare `let x;` (no initializer) in lint as "captures $in" with an explanation; it's
   indistinguishable from a forgotten initializer.

4. **Closures produced by `match`, executed by piping** — `match $meta { … => {|| … } } | do --env --ignore-errors $in`
   (conf/machine.nu:76-107) and `match $merge { false => {|| ^$p … | complete } … } | if $check { post-complete } else { do $in }`
   (command/mod.nu:57-58). Deferred execution chosen by data. Powerful but very non-obvious;
   `--ignore-errors` on the whole closure also silently swallows a broken host branch. ★

5. **`default --empty {|| … }` with closures as lazy defaults that `error make`** (test/mod.nu:182, 196) —
   "default" that throws reads backwards. ★

## B. Cell-path sigils

6. **`$.field` literal cell paths** everywhere in `get/select/reject/insert/update` (`get $.stem`, `insert $.role`).
   Bash readers (and most nu readers) expect bare `stem`. Consistent in this codebase, so learnable, but it doubles the
   sigil load. ★
7. **`!` suffix = case-*insensitive*** (`$env.work!`, `$.path!`, `get $.foo!`) and `!?` combos (`$env.posh_config!?`).
   A bash reader parses `!` as negation/"force"; I had to verify (`{Foo: 1} | get $.foo!` → `1`). util/mod.nu:18 documents
   it — good — but it's undocumented at use sites. ★★
   *Tooling idea:* idiom card for `?`, `!`, `!?` cell-path suffixes.

## C. Shadowing and naming

8. **Match binding shadows a parameter** — `export def subprocess [c: string …] { … match $in.exit_code { … $c => { error make "…code ($c)" } } }`
   (test/mod.nu:433-445). `$c` is the command string outside the arm and the exit code inside. ★★
9. **Module command shadowing a builtin inside its own module** — `export def skip` in test/mod.nu forces `drop nth 0`
   instead of `skip 1` later in the same file (comment at :455 explains it). Also forces the "import the module before
   `skip`" ordering dance in every seam. ★ (well-commented, but a design smell worth a lint rule: "exported name shadows builtin")
10. **`alias` used as a function** — `alias validate-target = do --capture-errors {|| let key; … }`,
    `alias add = run-internal $strategy` (hook/mod.nu:38, test/mod.nu:133). Bash aliases are textual; here they're
    closures-with-input or dynamic dispatch via `run-internal`. `def` would read immediately. ★★

## D. Path idioms

11. **`path basename --replace` / `path dirname --replace` for sibling paths** —
    `$nu.data-dir | path basename --replace nupm/modules/test` (several seams, conf/machine.nu). Reads as string surgery;
    the intent is "sibling of data-dir". `path dirname | path join nupm modules test` says it directly. ★
12. **`path self` in const/`use` positions** with relative arguments (`path self ../..`, `export use (path self ..)`).
    Clear once known; the parse-time-only nature isn't obvious. ★

## E. Code generation

13. **`format pattern` over raw-string templates with `{{`/`}}` escapes** generating nu programs (test/mod.nu:48-94,
    336-377), plus `'' + r###'…'###` (test/mod.nu:48; the `'' +` prefix has no visible purpose). Doubled braces mixed
    with nu's own `{}` blocks are hard to read and impossible to lint. ★★ (this is where the hooks/ctx bugs hid)

## F. Smaller things

14. `par-each --keep-order` for trivial per-line string formatting (test/mod.nu:218, 321, 411) — reads as "this is
    expensive", it isn't; thread overhead dominates.
15. Inconsistent param-doc placement: next-line (`init`, `register`, `post-complete`) vs same-line (`main`). Both work
    (verified with `help`), but mixing them in one file makes signatures harder to scan.

## G. Found while building (post-exploration)

16. **Bare words in expression position are commands.** `match $x { null => written, _ => kept }` runs externals
    named `written`/`kept` ("External command failed"); inside a list or record the same words are strings. ★★★
    *Tooling idea:* lint "bare word as a match-arm/if-branch value" → suggest quoting.
17. **A module cannot export a command named like itself.** A directory `init-local/` holding `export def init-local`
    fails with "Can't export command named same as the module" — bit me only because a *worktree* was named after
    the command; the main checkout (`nu/`) is fine. ★
18. **`to nuon` is not a const command**, so `const X = $"…($ROOT | to nuon)"` fails at parse time; wrap in a `def`. ★
19. **`run` is a parser keyword** that needs a parse-time constant path, and a missing file is a parse error even in
    a never-taken branch; `source` likewise. Loading user-supplied scripts therefore needs a child process. ★★
20. **`overlay hide` takes the overlay *name*** (`nu`, or the `as` alias), not the path used in `overlay use`; and
    `let` bindings made while an overlay is active vanish with it. ★★
21. **One declaration, two names.** A command re-exported under a prefix (`local alarm set`) and its bare twin from an
    overlay are the same declaration: `hide` of either name hides both, and `hide <module>` hides an overlay built
    from that module. The only way to keep names out of completions is never to import them (`use x *` sweeps in
    exported submodules). ★★
22. **`source-env <file>` runs the file's top-level statements, not just its `export-env`.** A `use`/`export use`
    executed that way runs the imported module's `export-env` (direct-`use` semantics), so sourcing a barrel file
    silently bypasses every guard around the modules it imports. Loaders belong in an import-free file. ★★★
23. **`source-env` and `use` are parse-time keywords; guards only skip evaluation.** Every `source-env <file>` inside
    an `export-env` re-parses that file as a script when the enclosing file is parsed, even inside a never-taken
    `if` — six guarded loaders cost ~45 ms per barrel load. A `use <module>` of a module the barrel already
    imported is cached (no re-parse) and its `export-env` runs only when the `use` statement executes, so it is
    the cheap way to run env set-up under a guard. ★★★ (measured: 164 → 121 ms plain, 212 → 130 ms login)
24. **`job spawn` without `--auto-kill` makes interactive `exit` refuse once** ("Running background jobs that won't
    be killed automatically … Run exit again"); with the flag `exit` is silent. No job outlives the process in either
    case (0.116.2-nightly.33, measured), so "won't be killed automatically" is about the prompt, not survival. ★★
