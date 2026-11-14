---
name: nushell-control-flow
description: >
  This skill should be used when writing Nushell iteration, conditionals,
  or error handling — `for`/`each`/`reduce`/`any`/`all`/`take while`,
  `if`/`match`, `try/catch`, the `?` postfix operator. Especially relevant
  when choosing between `for` (env-propagating) and `each` (isolated), or
  when an error path needs to skip vs surface vs default. Trigger phrases:
  "iterate", "loop", "filter", "map", "reduce", "for loop", "try catch",
  "error handling", "match", "conditional".
version: 0.2.0
user-invocable: false
---

# Nushell Control Flow

The single biggest decision in nu iteration is **`for` vs `each`** — they look similar, but they have completely different scope semantics. The single biggest decision in nu error handling is **`?` postfix vs `try/catch`** — they look unrelated, but they solve overlapping problems and `?` is almost always the right reach.

Syntax reference: [cheat-sheet → Control Flow](../nushell-idioms/references/cheat-sheet.md#control-flow) and [Lists → Operations and Accessing](../nushell-idioms/references/cheat-sheet.md#lists).

## Iteration: pick the right tool

| Construct | Returns | Env propagates? | Use when |
|---|---|---|---|
| `each { \|x\| … }` | List of closure results | **No** | Pure map; you want the transformed list |
| `for x in $list { … }` | Nothing (side-effecting) | **Yes** | You're mutating state per iteration |
| `where <row condition>` | Filtered list/table | **No** | Predicate filter (`where size > 1kb`, `where $it > 2`) |
| `reduce -f INIT { \|x, acc\| … }` | Single accumulated value | **No** | Folding into one value |
| `any { \|x\| … }` | Bool | **No** | "Is there any element matching?" |
| `all { \|x\| … }` | Bool | **No** | "Do all elements match?" |
| `take while { \|x\| … }` | Prefix of list | **No** | Slice up to first failing |
| `skip while { \|x\| … }` | Suffix of list | **No** | Slice from first failing |
| `enumerate` | List of `{index, item}` | **No** | When you need the index |
| `items { \|k, v\| … }` (on records) | List of closure results | **No** | Iterating record entries |

**Rule**: if the loop body mutates `$env`, use `for`. Otherwise use the highest-level transform that fits: `each`/`where`/`reduce`/`any`/`all`/`take while`/`skip while`.

Predicates are row conditions, not closures: `where name =~ $re`, `take until name == $x`, `any name == $n`, `all $it in $expected`. A column is named bare on the left of an operator; use `$it` for a scalar element or inside parentheses. A closure (`where {|r| … }`) is only for a predicate that needs more than one expression.

### Cost

- **`reduce --fold` that builds a list or record is quadratic**: every step copies the accumulator. At 5,000 items, `reduce --fold [] { … append … }` took about a second against 2.5 ms for `each --flatten`. Fold only to a scalar, and prefer a builtin (`math sum`, `str join`) when one exists.
- **`par-each` costs about 1 ms per call before any work.** It only pays off when each item does slow work (I/O, an external program) and there are many items; trivial per-item work is faster with `each` up to thousands of items. Never `par-each` writes to shared state (files, SQLite, `$env`).
- **`each --flatten`** when each iteration yields a list (same cost as `each | flatten`, reads better).

## `reduce` parameter order

Nu's `reduce` closure is `{ |elt, acc| … }` — **element first, accumulator second**. Opposite of JavaScript's `reduce((acc, elt) => …)`. Easy bug source:

```nu
[1 2 3 4] | reduce -f 0 { |elt, acc| $acc + $elt }   # ✓ → 10
[1 2 3 4] | reduce -f 0 { |acc, elt| $acc + $elt }   # name confusion but same result
```

The names you write don't matter — positional binding does. First param is the element. Second is the accumulator.

The `--fold INIT` form is the long version; `-f INIT` is the short flag.

## Conditionals

`if` is an expression — it returns the chosen branch's value. No need for assignment inside; just use the whole expression as the value (`let result = (if ... { ... } else { ... })`).

`match` patterns can match literals, ranges, records, and lists. The fallback wildcard is `_`. Arms can destructure with `$`-prefixed bindings — `{type: "click", x: $x}` matches a record-shaped value and binds `$x` from the inner field. Use match for branching on shape, not just value.

## What `$in` is

Pipeline input flows implicitly, and a bash reader's instincts about "nothing" are wrong here:

- **An empty block or `()` passes the input through.** `5 | if false { 1 } else { }` is `5`, and a `match` arm `=> ()` returns the match's input. An empty `else` is an identity, not "produce nothing"; to discard, write `null` or pipe to `ignore`.
- **Inside a `match` arm, `$in` is the match's pipeline input, not the subject.** In `$p | match ($in | path type) { dir => (glob $"($in)/**") }` the arm's `$in` is the path. When both appear, bind the value first (`let p = …; match ($p | path type) { … }`).
- **Only a block's first statement receives its input implicitly.** A later `if ($in | is-empty) { … } else { $in | length }` can see the input in the condition and an empty `$in` in the body (`[1 2] | do { let y = 3; if ($in | is-empty) { … } else { $in | length } }` gives `0`). Bind the input in the first statement (`let xs;` with no initializer binds it) or write `$in | if …`.
- **`each` doubles as "apply if present"**: piped a scalar or record it runs the closure once and returns the bare result; piped `null` it skips the closure. Use it that way only where the value can never be a list.

## Bare words in arms

In expression position a bare word is a command call. `match $x { null => written, _ => kept }` tries to run commands named `written` and `kept`; inside a list or record the same words are strings. Quote arm values: `null => 'written'`.

## Error handling

### The `?` postfix — first reach

For "this might be missing, default if so". Use `?` **inline on the cell path itself**, not as a wrapper around the access — `$record.deeply.nested.field?` returns null at the first missing link rather than erroring, and `$list.10?` is the list-index equivalent. Compose with `default` to substitute a value: `$record.name? | default "anonymous"`.

### `try/catch` — when something else might throw

```nu
try { 
    risky-operation 
} catch { |e| 
    print -e $"failed: ($e.msg)"
    "default value"
}
```

The catch closure receives an error record with `msg`, `debug`, `raw`, etc. The closure's return value becomes the expression's value if it threw.

**Use `try/catch` when**:
- Something other than a missing field could go wrong (file I/O, parse errors, external commands).
- You need to inspect the error (e.g., log `$e.msg`).
- The retry logic isn't expressible as a default.

**Don't use `try/catch` to**:
- Guard against null/missing fields → use `?` instead.
- Suppress all errors silently → at minimum log to stderr; better, fix the root cause.

### Expression-form `try`

`try` is an expression — you can use it on the right-hand side of a `let`: `let parsed = (try { open --raw $path | from json } catch { {} })`. This is the right idiom for "load if possible, default if not." The catch returns the default value, `let` binds the result. Avoids splitting load into multiple statements.

## A note on iteration shortcuts

For sum/product/min/max/avg, prefer `math sum` / `math product` / `math min` over a hand-rolled `reduce` — they read better and need no init value. The `$it` implicit-element name works inside one-arg closures (`where $it > 2`), useful for short predicates that don't earn a named parameter. Use `enumerate` to pair each element with its index before mapping.

## Pitfalls

- **`each` for env mutation** is the most common iteration bug. If the loop body touches `$env`, use `for`.
- **`reduce` param order** is element-first, accumulator-second — the opposite of most reduce APIs in other languages. Easy slip from muscle memory.
- **Catching everything silently** is bad style — at least log to stderr.
- **`try/catch` around a single cell-path access** is verbose; `?` is the inline form.
- **`try`/`catch` stops catching when the enclosing command's output is piped to `ignore`** (a Nushell bug, still present in 0.117.0): with `def f [] { try { error make {msg: x} } catch { "caught" } }`, `f` and `f | to nuon` catch, but `f | ignore` lets the error escape and the `catch` block never runs. An inline `try {…} catch {…} | ignore` behaves. Discard such a command's output with `| to nuon | ignore` or bind it (`let _ = (f)`).
- **`break` and `continue`** are not commonly used in nu pipelines (they exist in `for`/`while` loops but break the "transform a stream" mental model). Reach for `take while`/`skip while`/`first N` instead.
