---
name: nushell-strings
description: >
  This skill should be used when manipulating strings in Nushell — parsing
  structured text with `parse '{a} {b}'`, interpolating with `$"..."`,
  splitting/joining/replacing, converting between strings and structured
  formats (json/csv/yaml/toml), or any string operation that bash would
  handle with sed/awk/grep. Trigger phrases: "parse string", "split", "join",
  "str replace", "string interpolation", "regex", "from csv", "from json
  string".
version: 0.1.0
user-invocable: false
---

# Nushell Strings

In bash, string manipulation is a parade of `sed`, `awk`, `grep`, `cut`, `tr`, `printf`. In nu, there are three primary tools — `parse`, the `str` namespace, and the `from <format>` family — plus interpolation. The shift to internalize: **nu wants you to parse strings into structured data and then operate on the data**, not chain text transformations.

## The four primary tools

### 1. `parse '{name} {pattern}'` — typed extraction

The strongest single tool. Takes a template with named captures, returns a table:

```nu
'Nushell 0.111' | parse '{shell} {version}'
# → ╭───┬─────────┬─────────╮
#   │ # │  shell  │ version │
#   ├───┼─────────┼─────────┤
#   │ 0 │ Nushell │ 0.111   │
#   ╰───┴─────────┴─────────╯

ls | get name | parse '{stem}.{ext}'   # split filenames into stem/ext
```

Whenever you'd reach for `awk '{print $2}'` or a regex with named groups, `parse` is the right tool. The output is a table — chain `get` or `select` to extract.

For full regex, `parse --regex '<pattern>'` accepts standard regex syntax with named captures `(?<name>…)`.

### 2. The `str` namespace

```nu
"hello" | str upcase            # "HELLO"
"hello" | str downcase
"hello" | str length            # 5
"  pad  " | str trim
"hello world" | str contains "world"        # true
"hello world" | str replace "world" "nu"    # "hello nu"
"hello world" | str replace --regex 'w.+' "x"
"hello world" | str starts-with "hello"
"hello world" | str ends-with "world"
"hello" | str substring 1..3                 # "el"
"a-b-c" | str index-of "-"                   # 1
```

The `str` namespace covers ~95% of single-string manipulation. Tab-complete `str ` to discover the full set.

### 3. The `from <format>` family

```nu
'[{"x": 1, "y": 2}]' | from json
"a,b\n1,2\n3,4" | from csv
"key: val\nlist:\n  - 1\n  - 2" | from yaml
$toml_text | from toml
$nuon_text | from nuon
```

These read a string and return structured data. `from nuon` is JSON-superset, so it parses both nu's native and JSON forms. The pair `from json` and `to json` round-trip; `to nuon --serialize` round-trips closures too.

### 4. Interpolation: `$"…"`

```nu
let name = "alice"
$"hello ($name)"                       # "hello alice"
$"size: ($file | get size)"            # arbitrary expressions in parens
$"(ansi red)error(ansi reset)"         # terminal colors
```

`$"…"` is interpolation; `"…"` is a plain string. The inner expressions inside `(…)` are full nu expressions, not just variable names — `$"sum: ([1 2 3] | math sum)"` works.

## Splitting and joining

```nu
"a,b,c" | split row ","                 # ["a", "b", "c"]
"line1\nline2" | split row "\n"         # ["line1", "line2"]
"line1\nline2" | lines                  # same, but handles \r\n on Windows
"a b c d" | split column " "            # → {column1: a, column2: b, …}
[a b c] | str join "-"                  # "a-b-c"
```

`lines` is the preferred line-splitter — handles `\r\n` correctly.

## Encoding conversion

```nu
"hello" | encode utf-8        # → binary
$bytes | decode utf-8         # → string
"yes" | encode base64
"eWVz" | decode base64
```

## Regex

When `parse` doesn't fit, full regex via `str replace --regex` or `find --regex`:

```nu
"foo123bar" | str replace --regex '\d+' "X"     # "fooXbar"
[abc abd abe] | find --regex "^ab[cd]"          # filter by regex match
```

For extraction with captures, `parse --regex '(?<name>pattern)'` is cleaner than `find --regex` + post-processing.

## NUON string subtleties

When asserting on NUON output, **strings get quoted differently depending on context**:

- Top-level string `"hello"` → NUON `"hello"` (quoted)
- Inside a list `[hello, world]` → NUON `[hello, world]` (some bare-identifier-like strings unquoted)
- Inside a record `{key: "hello"}` → NUON `{key: hello}` (same)

This means `r.nuon === '"hello"'` is the right comparison for a top-level string, but `r.nuon.includes('"hello"')` may fail for a hello-inside-a-list NUON. **The robust pattern for tests is to do the equality check inside nu** and assert the resulting boolean:

```nu
$expected == $actual    # → true/false (always NUON-safe to compare)
```

## When bash's text-stream model leaks in

Coming from bash, the instinct is "transform text → transform text → final text." In nu, the better instinct is "parse text into structured data once, transform structurally, render to text at the very end." If a pipeline has three `str replace` calls in a row, it's almost always a sign you should be parsing into a record first and using `update` instead.

## Pitfalls

- **`echo`** in nu prints a list of values, not a string. Use `print` for stdout-side-effect, `$"…"` for interpolation.
- **Single-quoted strings** are literal — no interpolation, no escapes (except `\\`). Use double quotes for interpolation.
- **`split row` vs `split column`**: row → list of strings; column → record with auto-named columns. Pick by what you want next.
- **`parse` returns a table**, not a record. Use `parse … | first | …` if you expect one match.
