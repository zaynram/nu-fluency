---
name: nushell-records
description: >
  This skill should be used when writing or transforming Nushell records
  (key-value structures) or tables — including `$env` manipulation, record
  literals, column projection with `select`/`reject`, building records from
  iterables, or any time keys/values/columns are being added, removed,
  filtered, or restructured. Trigger phrases: "record", "table",
  "key/value", "select column", "build a record", "filter columns",
  "transform $env".
version: 0.1.0
user-invocable: false
---

# Nushell Records and Tables

Records are nu's primary data structure. A record is `{key: value, …}`. A table is a list of records that all share the same column shape — `[[a b]; [1 2] [3 4]]` is a table with two columns `a` and `b` and two rows. The distinction matters because some operations are record-shaped and some are table-shaped, and converting between the two is one of the most common operations.

Syntax reference: [cheat-sheet → Records / Tables](../nushell-idioms/references/cheat-sheet.md#records).

## The mental model

- **Record** = single key/value structure. Indexed by name. Order preserved.
- **Table** = list of records with shared columns. Indexed by position (row) AND name (column).
- **Cell paths** like `$x.a.b.2` work uniformly across records, tables, and lists.
- **`transpose`** moves between table and key/value-pair form.
- **`into record`** collapses a list of single-key records into one merged record.

## The four record-building patterns

### Literal

```nu
{name: "alice", age: 30}
```

### Project from another record

```nu
$person | select name age              # keep only listed keys
$person | reject password              # drop listed keys
$person | upsert age 31                # insert or update
```

### Build from a list with `into record`

```nu
[{a: 1} {b: 2} {c: 3}] | into record
# → {a: 1, b: 2, c: 3}
```

This works because `into record` merges a list of single-key records into one. The natural pair is `items` (which produces single-key records from a record) — see the next pattern.

### Filter-and-rebuild via `items | where | into record`

The single most useful record-shaped pipeline:

```nu
$env
| items { |k, v| 
    if ($v | describe | str starts-with "string") { {($k): $v} } 
  }
| where $it != null
| into record
```

Read as: "from each entry, emit a single-key record if the value is a string, drop nulls, merge." Replaces what would be `reduce -f {} { … upsert … }` in older or less-fluent code.

## Cell paths and safe navigation

The `?` postfix is **the** idiom for safe access — works inline on any cell path across records, lists, and tables (`$record.name?`, `$list.3?`, `$table.0.name?`). Reach for `try/catch` only when an operation might throw for reasons other than a missing key.

## Selecting columns with `--optional`

`select --optional KEY1 KEY2` is `?` for the column-projection case — missing keys return null instead of erroring. Useful when probing `$env` or unknown-shape data. The deprecated `-i` flag does the same thing; new code should use `--optional`.

## Record ↔ table ↔ list

```nu
# Record → key/value table
{a: 1, b: 2} | transpose key value
# → ╭───┬─────╮
#   │ a │  1  │
#   │ b │  2  │
#   ╰───┴─────╯ (as a 2-row, 2-column table)

# Table → record (single row only; multi-row collapses to last row)
[[k v]; [a 1]] | into record
# → {k: a, v: 1}

# Record → list of single-key records (via `items`)
{a: 1, b: 2} | items { |k, v| {($k): $v} }
# → [{a: 1} {b: 2}]

# List of single-key records → record (merge)
[{a: 1} {b: 2}] | into record
# → {a: 1, b: 2}
```

The chain `items { … } | where … | into record` is the canonical "filter-and-rebuild a record" pattern. Memorize it; it replaces what feels like it should be a reduce.

## Table operations

`update <col> { |row| ... }` is the row-level mutation idiom — the closure receives each row and returns the new column value. The dual `insert <col> { |row| ... }` adds a column whose values are computed per-row. Both are cleaner than `each { |row| ... }` chains when only one column changes.

## When records aren't enough

For ordered key/value pairs where the same key can appear multiple times (HTTP headers, etc.), nu doesn't have a native type — use `[{key: …, value: …}, …]` table shape, never collapse into a record.

## Pitfalls

- **`into record` on a multi-row table** keeps only the last row. Surprising; use `items`+`into record` pattern instead.
- **`get` returns null on missing key** with `--ignore-errors`, otherwise errors. `?` postfix on cell path is the inline equivalent.
- **Records preserve insertion order**, but operations like `transpose` may reorder; don't rely on iteration order semantically.
- **Empty record literal is `{}`**, which is identical to JSON syntax — but `{1 2 3}` is invalid record syntax (use `[1 2 3]` for a list).
