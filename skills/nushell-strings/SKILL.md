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

Syntax reference: [cheat-sheet → Strings](../nushell-idioms/references/cheat-sheet.md#strings).

## The four primary tools

### 1. `parse '{name} {pattern}'` — typed extraction

The strongest single tool. Takes a template with named captures and returns a **table**. Whenever the bash instinct is `awk '{print $2}'` or a regex with named groups, `parse` is the right tool — chain `get` or `select` to extract from the returned table. For full regex, `parse --regex '<pattern>'` accepts standard syntax with named captures `(?<name>…)`. A common idiom: `ls | get name | parse '{stem}.{ext}'` to split filenames.

### 2. The `str` namespace

Covers ~95% of single-string manipulation — case conversion (`upcase`, `downcase`, `capitalize`, `camel-case`, `snake-case`, etc.), inspection (`length`, `contains`, `starts-with`, `ends-with`, `index-of`, `distance`), slicing (`substring`), replacement (`replace`, `replace --all`, `replace --regex`), trimming (`trim`, `trim --char`), and reshaping (`reverse`, `expand`). Tab-complete `str ` to discover the full set; 23 subcommands as of nu 0.113.

### 3. The `from <format>` family

`from json`, `from csv`, `from yaml`, `from toml`, `from nuon` each read a string and return structured data. `from nuon` is a JSON-superset parser — it accepts both nu's native form and plain JSON. The pair `from json` and `to json` round-trip; `to nuon --serialize` round-trips closures too.

### 4. Interpolation: `$"…"` and `$'…'`

The `$` prefix turns either quote form into an interpolation. Inside `(…)`, full nu expressions are evaluated — `$"sum: ([1 2 3] | math sum)"` works. Double-quoted interpolation `$"…"` interprets backslash escapes; single-quoted interpolation `$'…'` preserves backslashes verbatim. Plain `"…"` and `'…'` (no `$`) are non-interpolating strings with the same escape distinction.

## Splitting and joining

`lines` is the preferred line-splitter — it handles `\r\n` correctly across platforms. `split row` returns a list of strings; `split column` returns a single-row table with auto-named columns (`column0`, `column1`, …). Pick by what the next stage expects.

## Encoding conversion

`encode utf-8` and `decode utf-8` convert between strings and binary; `encode base64` / `decode base64` handle base64 (both produce/consume strings — chain `decode utf-8` after `decode base64` to recover text from base64-encoded bytes).

## Regex

When `parse` doesn't fit, full regex is available via `str replace --regex` (substitute) and `find --regex` (filter list elements). For extraction with captures, `parse --regex '(?<name>pattern)'` reads more cleanly than `find --regex` followed by post-processing.

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
- **`'…'` (plain single-quoted) is literal** — no escapes interpreted. For interpolation that still preserves backslashes, use the `$` prefix: `$'…'`. Plain double-quoted `"…"` interprets escapes; `$"…"` adds interpolation on top.
- **`split row` vs `split column`**: row → list of strings; column → record with auto-named columns. Pick by what you want next.
- **`parse` returns a table**, not a record. Use `parse … | first | …` if you expect one match.
