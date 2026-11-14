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
version: 0.2.0
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
- **`record each` / `record where`** map and filter a record into a new record (nu >= 0.117).
- **`into record`** turns a list of `[key value]` pairs or single-key records into one record; given a table it merges the rows.

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

This works because `into record` merges a list of single-key records (or `[key value]` pairs) into one.

### Map and filter a record with `record each` / `record where`

The record-to-record transforms. Both take the same closure contract as `items`:

```nu
# filter: row condition over {key, value} rows, or a closure
{a: 1, b: "x", c: "y"} | record where {|k v| ($v | describe) == string }   # → {b: x, c: y}
$env | record where key starts-with NU_
{a: 1, b: ''} | record where --values { is-not-empty }                      # → {a: 1}

# map: return {$k: …}, a [k v] pair, or null to drop the field
{a: 1, b: 2} | record each {|k v| {$k: ($v * 2)} }                         # → {a: 2, b: 4}
```

They are the fastest options by a wide margin (measured on 5,000 fields: `record each` 7.7 ms against 54 ms for `items … | into record`; `record where` 5.4 ms against 16.2 ms for `items … | compact | into record`). Never build a record with `reduce --fold {} { … upsert … }`: every step copies the accumulator, so it is quadratic (625 ms against 24 ms for the `items` form at 5,000 fields).

`items {|k v| … }` remains the tool when the result is not a record (printing, collecting a list), and `items {…} | compact | into record` is the fallback on older nu.

## Cell paths and safe navigation

The `?` postfix is **the** idiom for safe access — works inline on any cell path across records, lists, and tables (`$record.name?`, `$list.3?`, `$table.0.name?`). Reach for `try/catch` only when an operation might throw for reasons other than a missing key.

## Selecting columns with `--optional`

`select --optional KEY1 KEY2` is `?` for the column-projection case — missing keys return null instead of erroring. Useful when probing `$env` or unknown-shape data. `get` and `reject` take the same flag. Its old spelling, `--ignore-errors` (`-i`), is deprecated since nu 0.106 on all three commands; new code uses `--optional` (`-o`).

## Record ↔ table ↔ list

```nu
# Record → key/value table
{a: 1, b: 2} | transpose key value
# → ╭───┬─────╮
#   │ a │  1  │
#   │ b │  2  │
#   ╰───┴─────╯ (as a 2-row, 2-column table)

# Key/value table → record
[[k v]; [a 1] [b 2]] | transpose --ignore-titles --header-row --as-record
# → {a: 1, b: 2}

# Single-row table → record (into record merges rows; with several rows, later rows win)
"k=v" | parse "{key}={value}" | into record
# → {key: k, value: v}

# Record → list of single-key records (via `items`)
{a: 1, b: 2} | items { |k, v| {($k): $v} }
# → [{a: 1} {b: 2}]

# List of single-key records → record (merge)
[{a: 1} {b: 2}] | into record
# → {a: 1, b: 2}
```

`record where` and `record each` are the canonical "filter-and-rebuild a record" verbs; reach for `transpose k v` only when the entries need table verbs (`sort-by`, `group-by`, multi-step `update`), then `transpose --header-row --as-record` back.

## Table operations

`update <col> { |row| ... }` is the row-level mutation idiom — the closure receives each row and returns the new column value. The dual `insert <col> { |row| ... }` adds a column whose values are computed per-row. Both are cleaner than `each { |row| ... }` chains when only one column changes.

## When records aren't enough

For ordered key/value pairs where the same key can appear multiple times (HTTP headers, etc.), nu doesn't have a native type — use `[{key: …, value: …}, …]` table shape, never collapse into a record.

## Pitfalls

- **`into record` on a table merges the rows** (union of columns, later rows win): `[[k v]; [a 1] [b 2]] | into record` is `{k: b, v: 2}`, not `{a: 1, b: 2}`. It is not a key/value conversion; use `transpose --ignore-titles --header-row --as-record`.
- **`rotate` is not `transpose`** for records: `{a: 1} | rotate` puts the value before the key, so `rotate key value` labels the columns backwards. Use `transpose key value`.
- **`get` errors on a missing key** unless given `--optional` (`-o`), which returns null instead. Don't write the deprecated `--ignore-errors` (`-i`) spelling. `?` postfix on cell path is the inline equivalent.
- **Records preserve insertion order**, but operations like `transpose` may reorder; don't rely on iteration order semantically.
- **Empty record literal is `{}`**, which is identical to JSON syntax — but `{1 2 3}` is invalid record syntax (use `[1 2 3]` for a list).
