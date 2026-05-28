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
version: 0.1.0
user-invocable: false
---

# Nushell Control Flow

The single biggest decision in nu iteration is **`for` vs `each`** — they look similar, but they have completely different scope semantics. The single biggest decision in nu error handling is **`?` postfix vs `try/catch`** — they look unrelated, but they solve overlapping problems and `?` is almost always the right reach.

## Iteration: pick the right tool

| Construct | Returns | Env propagates? | Use when |
|---|---|---|---|
| `each { \|x\| … }` | List of closure results | **No** | Pure map; you want the transformed list |
| `for x in $list { … }` | Nothing (side-effecting) | **Yes** | You're mutating state per iteration |
| `where { \|x\| … }` | Filtered list/table | **No** | Predicate filter |
| `reduce -f INIT { \|x, acc\| … }` | Single accumulated value | **No** | Folding into one value |
| `any { \|x\| … }` | Bool | **No** | "Is there any element matching?" |
| `all { \|x\| … }` | Bool | **No** | "Do all elements match?" |
| `take while { \|x\| … }` | Prefix of list | **No** | Slice up to first failing |
| `skip while { \|x\| … }` | Suffix of list | **No** | Slice past last passing |
| `enumerate` | List of `{index, item}` | **No** | When you need the index |
| `items { \|k, v\| … }` (on records) | List of closure results | **No** | Iterating record entries |

**Rule**: if the loop body mutates `$env`, use `for`. Otherwise use the highest-level transform that fits: `each`/`where`/`reduce`/`any`/`all`/`take while`/`skip while`.

## `reduce` parameter order

Nu's `reduce` closure is `{ |elt, acc| … }` — **element first, accumulator second**. Opposite of JavaScript's `reduce((acc, elt) => …)`. Easy bug source:

```nu
[1 2 3 4] | reduce -f 0 { |elt, acc| $acc + $elt }   # ✓ → 10
[1 2 3 4] | reduce -f 0 { |acc, elt| $acc + $elt }   # name confusion but same result
```

The names you write don't matter — positional binding does. First param is the element. Second is the accumulator.

The `--fold INIT` form is the long version; `-f INIT` is the short flag.

## Conditionals

### `if/else`

```nu
if $x > 0 { "positive" } else if $x < 0 { "negative" } else { "zero" }
```

`if` is an expression — returns the chosen branch's value. No need for assignment inside; just use the whole expression as the value.

### `match`

```nu
match $color {
    "red" => 1,
    "green" => 2,
    "blue" => 3,
    _ => 0,
}
```

Patterns can match literals, ranges, records, lists. The fallback wildcard is `_`. For pattern matching on structured values:

```nu
match $event {
    {type: "click", x: $x, y: $y} => $"clicked at ($x), ($y)",
    {type: "key", key: $k} => $"keypress ($k)",
    _ => "unknown event",
}
```

## Error handling

### The `?` postfix — first reach

For "this might be missing, default if so":

```nu
$record.name?                            # null instead of error
$record.deeply.nested.field?             # null at any link
$record.name? | default "anonymous"
$list.10? | default "out of bounds"
```

Use `?` **inline on the cell path itself**, not as a wrapper around it. It returns null instead of erroring, then `default` substitutes a value.

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

`try` is an expression — you can use it on the right-hand side of a `let`:

```nu
let parsed = (try { open --raw $path | from json } catch { {} })
```

This is the right idiom for "load if possible, default if not." The catch returns the default value, `let` binds the result. Avoids splitting load into multiple statements.

## Common iteration patterns

### Map a list

```nu
[1 2 3] | each { |n| $n * 2 }
```

### Filter a list

```nu
[1 2 3 4] | where $it > 2
# $it is the implicit current-element name when the closure is one-arg
```

### Map with index

```nu
[a b c] | enumerate | each { |row| $"($row.index): ($row.item)" }
```

### Aggregate predicate

```nu
$items | any { |x| $x.status == "error" }    # any errors?
$items | all { |x| $x.valid }                 # all valid?
```

### Reduce to a single value

```nu
[1 2 3 4] | reduce -f 0 { |n, acc| $acc + $n }    # sum
[1 2 3 4] | math sum                                # built-in
```

For sum/product/min/max/avg, prefer `math sum`/`math product`/`math min`/etc — they're more direct and read better.

### Conditional skip

```nu
let result = (if $env.MODE == "prod" { run-prod } else { run-dev })
```

`if` is an expression — assign its value directly.

## Pitfalls

- **`each` for env mutation** is the most common iteration bug. If the loop body touches `$env`, use `for`.
- **`reduce` param order** trips up JS-fluent developers. Element first, accumulator second.
- **Catching everything silently** is bad style — at least log to stderr.
- **`try/catch` around a single cell-path access** is verbose; `?` is the inline form.
- **`break` and `continue`** are not commonly used in nu pipelines (they exist in `for`/`while` loops but break the "transform a stream" mental model). Reach for `take while`/`skip while`/`first N` instead.
