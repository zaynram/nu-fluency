# Startup-time assessment (draft; final numbers after the review loop)

## What the owner measures
A hook in `autoload/hooks.nu` prints `$nu.startup-time`: the whole boot (env.nu, config.nu, every autoload file),
350–500 ms today; earlier variants were 1–10 s before `proj` was optimised. The library's share is what this
initiative can change.

## Method here
`$nu.startup-time` does not include config evaluation in the `--config … -e` mode available in this session (a
100 ms `sleep` in config.nu does not register), so the library's share is measured as process wall time:
min of 5–7 runs of `nu [--login --interactive] -I <root> -c 'use <root> *; null'`, sandboxed HOME/XDG, minus a bare
`nu -c null` (10–11 ms). Login+interactive is the owner's case (every guarded loader runs).

| tree | plain | login+interactive | note |
|---|---|---|---|
| bare nu | 10 | 10 | |
| main (owner's current library) | 61–80 | 68–92 | range across runs today |
| stack before the loaders fix | 164 | 212 | `source-env` loaders re-parsed six modules per load |
| stack after the loaders fix (perf/barrel-loaders) | 123 | 134 | guarded `use <module>/mod.nu` |
| fix/integration (all phases) | 141 | 165 | + error derivation, from-bash, machine override validation, bump-nu |

Per-module parse cost (plain `use <m>`, min of 3, ms; main → integration): conf 21→52 (machine.nu now imports
`validate` for override validation and `error`), pman 15→38 (`nightly.nu`: std/log, error, reload), env 13→20
(from-bash), mods/local 55 (imports conf), others ±3. Pieces alone over bare nu: validate +11, from-bash +5,
std/log +2, error +1, reload +0, machine.nu +13. Inside the barrel each module is parsed once, so the barrel total
(141) is well below the sum of the parts.

## Reading
- The library's share of the owner's boot grows from roughly 70–90 ms to roughly 140–165 ms: about +75 ms, i.e.
  +15–20 % of a 350–500 ms boot. Half of the growth was the `source-env` loaders (fixed); the rest is new code that
  must be parsed at import (Nushell has no lazy module loading): machine-config validation via `validate`,
  `env from-bash`, `pman bump-nu`, derived error codes.
- Options if the owner wants the old number back: (1) validate the machine override in a child process only when
  a file exists (saves ~11 ms for everyone, costs ~15 ms when a file exists — the owner's common case, so not
  recommended); (2) drop `std/log` from `bump-nu` in favour of `print --stderr` (~2 ms); (3) stop exporting
  `pman` from the barrel (it is a management command; `use pman` on demand) — saves the whole conf/nightly chain
  for shells that never upgrade; (4) same for `mods/local` (55 ms; `edit` needs conf) if `mods edit` is rare.
  (3)+(4) would bring the barrel back near main's figure; they change the interactive surface, so owner's call.
- Suggested owner-side check (two commands, run in a real login shell): note `$nu.startup-time` with the current
  main, then with the finished stack checked out at /work/dev/nu; the delta is the honest before/after.

## Open
Final run on the reviewed HEAD; whether to apply (2); owner's decision on (3)/(4).

Interim reading on feat/use-colors @dcda11d (same method, min of 7): main 51 plain / 55 login; stack 123 / 141.
The stack improved ~20 ms since fix/integration (141/165): conf no longer validates an empty `--with` on every
call (~3 ms × 2 per `machine-config`), plus noise. Final reading after the review loop.

## Parse vs runtime (owner asked why mods/proj/pman loads can't be backgrounded)
Measured on feat/use-colors, min of 3, ms over a 9 ms bare nu: proj parse only 29; proj import with a warm
registry (scan within a day) 29; proj import with a cold registry scanning 30 git repos 88 (so the scan ≈ 60 ms per
30 repos and is the only backgroundable part); mods 26 and pman 38 are pure parse. Nushell parses `use` targets
synchronously at parse time; a `job spawn` cannot import into the parent scope and dies with the shell, so parse
cost cannot be deferred — only export-env runtime work (proj's scan) can be moved to a job with one atomic kv write.

## Interim reading after hydration (feat/hydration @8947bb7, 2026-11-06, min of 7, ms, bare nu 8–9)
| tree | plain | login+interactive | owner shape: first / warm |
|---|---|---|---|
| main | 55 | 55 | 71 / 55 |
| feat/use-colors (round-2 stack) | 127 | 132 | 252 / 169 |
| feat/hydration (+ session, proj snapshot/job, conf cache) | 132 | 145 | 234 / 157 |
"Owner shape" = login+interactive with a `.nu` machine override and WORK holding 30 repositories; "first" = a fresh
HOME (cold registry, cold override cache), "warm" = the next start. The conf cache saves ~12 ms per login (override
hit instead of a child `nu` + validation); proj's scan left the import path (isolated: cold 106 → 38 ms) but the
owner-shape "first" still pays other first-start costs (override load + check + cache write, mods, completers), so
the delta there is smaller. `session` and proj's `use log` add ~5–10 ms of parse to the plain import. Final numbers
after round 4.
