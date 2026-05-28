# Nushell Cheat Sheet

Pull when you need syntax for a specific operation.

For anti-patterns and recalibration, see the [skill](`../SKILL.md`).

## Data Conversion

### Primitives

```nu
# string -> int / float / bool
"12"   | into int                # 12
"3.14" | into float              # 3.14
"true" | into bool               # true

# int -> string
42 | into string                 # "42"
```

### Unit Types

```nu
# int -> duration / filesize
120  | into duration             # 120ns        (default unit is nanoseconds)
1024 | into filesize             # 1.0 kB       (default presentation is decimal SI)

# duration / filesize -> int
500ms | into int                 # 500000000    (nanoseconds)
1.5GB | into int                 # 1500000000   (bytes)

# force a presentation unit
1hr   | format duration sec      # "3600 sec"
1024b | format filesize KiB      # "1 KiB"      (binary presentation)
```

### Datetime

```nu
# parse ISO 8601 string
'2024-01-15T10:30:00'
| into datetime
| format date "%Y-%m-%d"         # "2024-01-15"

# parse natural-language string
'2026-03-11 13:00'
| date from-human                # Wed, 11 Mar 2026 13:00:00 -0500
| format date %Y-%m-%d           # 2026-03-11
```

### Serialized Text

```nu
# json
{a: 1, b: 2} | to json --raw     # {"a":1,"b":2}
'{"x": 1}' | from json           # {x: 1}

# yaml
[a b c] | to yaml                # "- 'a'\n- 'b'\n- 'c'\n"
"- a\n- b\n- c" | from yaml      # [a b c]

# csv (from csv is type-inferring on numeric columns)
[[a b]; [1 2]] | to csv          # "a,b\n1,2\n"
"a,b\n1,2" | from csv            # [[a b]; [1 2]]

# toml
{name: alice, age: 30} | to toml # "name = \"alice\"\nage = 30\n"

# nuon (preserves nu-native types; durations expand to ns)
{x: 1, y: 2sec} | to nuon        # "{x: 1, y: 2000000000ns}"
'{x: 1, y: 2sec}' | from nuon    # {x: 1, y: 2sec}
```

### Binary

```nu
# text <-> binary
"hello" | encode utf-8           # 0x[68656C6C6F]   (binary)
$bytes  | decode utf-8           # "hello"

# base64 (string in / out; chain decode utf-8 to recover text)
"yes"  | encode base64           # "eWVz"
"eWVz" | decode base64           # 0x[796573]      (binary)
```

## Records

Conceptual reference: [`nushell-records`](../../nushell-records/SKILL.md)

### Type Syntax

```nu
# base type can contain any key-value pairing
let point: record = {}                                 # valid
let point: record = {a: foo x: 0}                      # valid
# specifying types enables parser typechecking
let point: record<x: int, y: int> = {x: 1 y: 2}        # valid
let point: record<x: int, y: int> = {x: foo y: bar}    # invalid
# typecheck does not run on data outside of type definition
let point: record<x: int, y: int> = {a: foo x: 3 y: 9} # valid
# typecheck runs on all defined keys for non-empty records
let point: record<x: int, y: int> = {}                 # valid
let point: record<x: int, y: int> = {x: 1}             # invalid
let point: record<x: int, y: int> = {a: foo b: bar}    # invalid
```

### Operations and Accessing

```nu
let example: record<name: string, age: int> = {name: alice age: 30}
```

```nu
# extract column value(s)
$example | get name           # alice
# list the columns/keys
$example | columns            # [name age]
# list the values
$example | values             # [alice 30]
# keep selected columns
$example | select name        # {name: alice}
# drop rejected columns
$example | reject name        # {age: 30}
# insert a key-value pair
$example | insert sex F       # {name: alice age: 30 sex: F}
# update an existing key
$example | update age 50      # {name: alice age: 50}
# insert or update data
$example | upsert alias ally  # {name: alice age: 30 alias: ally}
# operate on key-value pairs
$example | items {|k v|
  {($v | describe): [$k $v]}
}                             # {string: [name alice] int: [age 30]}
```

```nu
# access column values
$example.name                 # alice
$example.missing              # <error>
# safely access column values
$example.name?                # alice
$example.missing?             # null
# access nested values
$example.nested.value?        # <error>
# safely access nested values
$example.nested?.value?       # null
```

## Lists

Iteration semantics: [`nushell-control-flow`](../../nushell-control-flow/SKILL.md)

### Type Syntax

```nu
# base type can contain elements of any type
let lines: list = []                                   # valid
let lines: list = [foo 1sec {x: 1} 30 null]            # valid
# specifying types enables parser typechecking
let lines: list<string> = [foo bar]                    # valid
let lines: list<string> = [1 2 3 4]                    # invalid
# type declaration may be expanded by coercion
let lines: list<string> = [foo 1 bar 2]                # valid
$lines | describe # -> list<oneof<string, int>>
```

### Operations and Accessing

```nu
let example: list<int> = 1..5 | take 5 # -> [1 2 3 4 5]
```

```nu
# append a value
$example | append 3            # [1 2 3 4 5 3]
# prepend a value
$example | prepend 7           # [7 1 2 3 4 5]
# measure the list length
$example | length              # 5
# extract item at index
$example | get 0               # 1
# slice from the start
$example | first 2             # [1 2]
# slice from the end
$example | last 3              # [3 4 5]
# exclude from the start
$example | skip 1              # [2 3 4 5]
# keep selected indices
$example | select 2 4          # [3 5]
# drop rejected indices
$example | reject 2 4          # [1 2 4]
# insert a value at an index
$example | insert 3 10         # [1 2 3 10 4 5]
# update an existing index
$example | update 1 9          # [1 9 3 4 5]
# filter list elements
$example | where $it > 3       # [4 5]
# evaluate a predicate
$example | any { $in > 2 }     # true
$example | all { $in > 2 }     # false
# create new list by iteration
$example | each {|n|
  $n + 1
}                              # [2 3 4 5 6]
$example | par-each {|n|
  $n - 1
}                              # [0 1 2 3 4] (order may not be preserved w/o `--keep-order`)
# enumerate a list
$example | enumerate           # [[index item]; [0 1] [1 2] [2 3] [3 4] [4 5]]
# reduce a list cumulatively
$example | reduce {|n acc|
  $acc + $n
}                              # 15
# predicate-bound slicing
$example | take while {|n|
  $n < 3
}                              # [1 2]
```

```nu
# access at index
$example.1                    # 2
$example.8                    # <error>
# safely access at index
$example.1?                   # 2
$example.8?                   # null
```

## Tables

A table is a `list<record<...>>` where every row shares column names. The two literal forms are equivalent — `[[a b]; [1 2] [3 4]]` and `[{a: 1 b: 2} {a: 3 b: 4}]` produce `==`-equal values that both describe as `table<a: int, b: int>`. The annotations `table<a: int>` and `list<record<a: int>>` are interchangeable.

Conceptual reference: [`nushell-records`](../../nushell-records/SKILL.md)

Type syntax follows the [Records](#records) (per-column) and [Lists](#lists) (row container) rules.

### Operations and Accessing

Operations that don't need the table shape live in [Records](#records) (per-row column ops: `select`, `reject`, `upsert`) and [Lists](#lists) (cross-row ops: `first`, `last`, `where`, `each`, `length`). The operations below require row-shared column structure.

```nu
let example: table<a: int, b: int> = [[a b]; [1 2] [3 4]]
```

```nu
# rename / reorder / drop columns (across all rows)
$example | rename a aa             # [[aa b]; [1 2] [3 4]]
$example | move b --before a       # [[b a]; [2 1] [4 3]]
$example | drop column             # [[a]; [1] [3]]   (drops rightmost)

# per-row update / insert with closure
$example | update a {|row| $row.a * 10}     # [[a b]; [10 2] [30 4]]
$example | insert c {|row| $row.a + $row.b} # [[a b c]; [1 2 3] [3 4 7]]

# row predicates use column names as identifiers
$example | where a > 1             # [[a b]; [3 4]]
$example | sort-by b --reverse     # [[a b]; [3 4] [1 2]]

# cross-shape transforms
$example | group-by a              # {1: [[a b]; [1 2]] 3: [[a b]; [3 4]]}
$example | transpose col r0 r1     # [[col r0 r1]; [a 1 3] [b 2 4]]
$example | first | into record     # {a: 1 b: 2}    (single row -> record)
$example | into record             # {a: 3 b: 4}    (multi-row: keeps last)
```

```nu
# cell-path access
$example.0                         # {a: 1 b: 2}    (row by index)
$example.0.a                       # 1              (cell value)
$example.a                         # [1 3]          (column as list)
```

## Strings

Conceptual reference: [`nushell-strings`](../../nushell-strings/SKILL.md)

### Type Syntax

```nu
# all four forms describe as string
"hello"                 # double-quoted: escapes interpreted (\n, \t, \", \\)
'hello'                 # single-quoted: literal (backslashes preserved)
$"hello (1 + 1)"        # interpolated: any expression inside (...)
$'hello (1 + 1)'        # interpolated literal: backslashes preserved; (...) still evaluated
r#'has "quotes" and \'# # raw: everything between r#'...'# preserved verbatim

# strict typecheck: value type must match the annotation
let s: string = "alice" # valid
let s: string = 42      # invalid (parser error)
```

### Operations

```nu
# transform case
"hello world" | str upcase           # "HELLO WORLD"
"hello world" | str capitalize       # "Hello world"
"camel_case"  | str camel-case       # "camelCase"

# inspect
"hello"       | str length           # 5
"hello world" | str contains "world" # true
"hello world" | str starts-with "h"  # true
"a-b-c"       | str index-of "-"     # 1

# substring
'Hello World' | str substring 0..4   # "Hello"

# replace
"hello"     | str replace "l" "L"            # "heLlo"   (first match)
"hello"     | str replace --all "l" "L"      # "heLLo"   (all matches)
"foo123bar" | str replace --regex '\d+' "X"  # "fooXbar"

# trim
"  pad  " | str trim                         # "pad"
"x.x.x"   | str trim --left --char "x"       # ".x.x"
```

### Parsing and Splitting

```nu
# parse template -> table of named captures
'Nushell 0.113' | parse '{shell} {version}'
# [[shell version]; [Nushell 0.113]]

# parse with regex (named groups)
'log: ERROR 42' | parse --regex 'log: (?<lvl>\w+) (?<n>\d+)'
# [[lvl n]; [ERROR 42]]

# split into list / table
"a,b,c"        | split row ","       # [a b c]
"a b c d"      | split column " "    # [[column0 column1 column2 column3]; [a b c d]]
"line1\nline2" | lines               # [line1 line2]   (handles \r\n on Windows)

# join
[a b c] | str join "-"               # "a-b-c"
```

For format conversion (`from json`, `to yaml`, etc.), see [Data Conversion](#data-conversion).

## Filesystem

```nu
# navigation
pwd                            # current directory as string
cd path/to/dir                 # change directory
cd ..                          # parent
cd ~                           # home

# listing (returns table<name, type, size, modified, ...>)
ls                             # current directory
ls *.md                        # glob filter
ls **/*.rs                     # recursive glob
ls -la                         # include hidden + long-form columns
glob **/*.{js,ts} --depth 3    # paths only, no metadata (returns list<string>)

# reading
open file.txt                  # auto-detect by extension (text, json, csv, yaml, toml, ...)
open --raw file.bin            # bytes, no auto-detection
open --raw file.txt | lines    # raw text -> list<string>

# writing
'content' | save out.txt           # error if file exists
'content' | save --force out.txt   # overwrite existing
'content' | save --append out.txt  # append
{a: 1} | save out.json             # serialize structured data by extension
{a: 1} | save --raw out.txt        # save without serialization

# file management
mkdir foo/bar                  # creates nested dirs automatically
cp src.txt dst.txt
mv old.txt new.txt
rm file.txt
rm -rf dir/

# path manipulation (string-only; does not touch the filesystem)
"a/b/c.txt" | path basename    # "c.txt"
"a/b/c.txt" | path dirname     # "a/b"
"a/b/c.txt" | path parse       # {parent: "a/b" stem: "c" extension: "txt"}
"a/b/c.txt" | path split       # [a b c.txt]
["a" "b" "c.txt"] | path join  # "a/b/c.txt"

# path inspection (touches the filesystem)
"/tmp" | path exists           # true
"/tmp" | path type             # "dir"  ("file" / "symlink" / etc.)

# watch
watch . --glob "**/*.rs" { || cargo test }
```

## Env and Scope

Conceptual reference: [`nushell-env-scoping`](../../nushell-env-scoping/SKILL.md)

```nu
# read
$env.HOME                          # value (errors if unset)
$env.HOME?                         # safe access (null if unset)
$env | columns | first 5           # list env var names

# write at current scope
$env.NEW = "val"
load-env {A: "1", B: "2"}          # bulk merge

# scoped: env active only inside the closure; mutations inside do not escape
with-env {TMP: "/tmp"} { run-thing }

# propagating mutations out of a closure
do --env { $env.X = "yes" }        # $env.X exists outside the do
do        { $env.X = "yes" }       # $env.X discarded on exit

# iteration: for propagates env mutations, each does not
for k in [a b c] { $env.LAST = $k }   # $env.LAST -> "c"
[a b c] | each {|k| $env.LAST = $k }  # $env.LAST unchanged (closure isolation)

# function boundaries: --env enables caller-env mutation
def --env activate [path] { $env.ACTIVE = $path }   # mutates caller env
def        peek     [path] { $env.PEEK   = $path }  # mutation invisible to caller
```

## Variables

```nu
# immutable binding (let)
let x = 42
$x                                # 42
$x = 100                          # invalid (parse error: cannot reassign let)

# mutable binding (mut)
mut y = 0
$y = 5
$y += 1
$y                                # 6

# parse-time constant (const) — value frozen at parse time
const PATH = "/etc/foo"
$PATH                             # "/etc/foo"

# type annotations (optional; checked at parse time)
let n: int = 42                   # valid
let s: string = "alice"           # valid
let bad: int = "foo"              # invalid (parser error)

# shadowing within a scope
let val = 1
do { let val = 99; $val }         # 99
$val                              # 1  (outer scope unchanged)

# capture a pipeline result
let big_files = (ls | where size > 10kb)
let count     = ($big_files | length)
```

## Control Flow

Conceptual reference: [`nushell-control-flow`](../../nushell-control-flow/SKILL.md)

### Conditionals

```nu
# if-else is an expression — returns the chosen branch's value
if $x > 0 { "pos" } else if $x < 0 { "neg" } else { "zero" }

# match: literals, ranges, records, lists, wildcard
match $color {
  "red"   => 1
  "green" => 2
  "blue"  => 3
  _       => 0
}

# match destructures and binds with $-prefixed names
match $event {
  {type: "click", x: $x, y: $y} => $"click at ($x), ($y)",
  {type: "key",   key: $k}      => $"key ($k)",
  _                              => "unknown",
}
```

### Error Handling

```nu
# ? postfix on cell paths — first reach for missing-key cases
$record.name?                                # null if missing
$record.name? | default "anonymous"          # null becomes "anonymous"

# try / catch (expression form: returns the catch value on failure)
try { open --raw $path | from json } catch { {} }
try { risky } catch { |e| $"failed: ($e.msg)" }

# bind a try result
let cfg = (try { open --raw "cfg.json" | from json } catch { {} })
```

### Iteration

```nu
for n in 1..5 { print $n }                   # range
for k in [a b c] { print $k }                # list
while $cond { do-thing }                     # while
loop { do-thing; if $stop { break } }        # loop with break / continue
```

For map / filter / fold iteration (each, where, reduce, any, all, take while), see [Lists → Operations and Accessing](#lists).

## Custom Commands

```nu
# basic: typed positional parameter
def greet [name: string] { $"hello ($name)" }
greet "alice"                       # "hello alice"

# default value on positional
def greet [name: string = "world"] { $"hello ($name)" }
greet                               # "hello world"

# optional positional (? suffix); value is null if omitted
def maybe [name?: string] { if $name == null { "anon" } else { $name } }
maybe                               # "anon"
maybe "alice"                       # "alice"

# flags: presence-only (--loud) and value-bearing (--prefix)
def greet [name: string, --loud, --prefix: string = "hi"] {
  if $loud { $"($prefix | str upcase) ($name | str upcase)" } else { $"($prefix) ($name)" }
}
greet "alice"                       # "hi alice"
greet "alice" --loud                # "HI ALICE"
greet "alice" --prefix "hello"      # "hello alice"

# short flag alias: --loud (-l)
def shout [name: string, --loud (-l)] { if $loud { $name | str upcase } else { $name } }
shout "alice" -l                    # "ALICE"

# rest parameters (...name: type)
def sum [...nums: int] { $nums | math sum }
sum 1 2 3 4 5                       # 15

# pipeline input/output type signature
def double []: int -> int { $in * 2 }
5 | double                          # 10

# --env enables caller-env mutation
def --env activate [path: string] { $env.ACTIVE = $path }
```

For module-exported commands (`export def`, `export def --env`, `export-env`), see [Modules](#modules).

## Modules

Conceptual reference: [`nushell-modules`](../../nushell-modules/SKILL.md)

```nu
# --- greetings.nu (module file) ---
export def hello [name: string] { $"hi ($name)" }
export def main [] { "greetings and salutations" }
export-env { $env.GREETING_LOADED = true }
export const VERSION = "1.0"
```

```nu
# --- caller: namespaced import ---
use greetings.nu
greetings              # "greetings and salutations"   (calls main)
greetings "alice"      # forwards "alice" to main as a positional arg

# subcommands and exported constants require selective or wildcard import
use greetings.nu hello                 # selective
hello "world"                          # "hi world"

use greetings.nu *                     # all exports into scope
hello "world"                          # "hi world"
$VERSION                               # "1.0"  (wildcard-imported constants surface as $NAME)
$env.GREETING_LOADED                   # true (export-env runs at `use` time)

# constants also reachable via record-style access on the namespace
use greetings.nu
$greetings.VERSION                     # "1.0"  (works with or without `main` defined)
```

```nu
# inline module (no separate file)
module mymod {
  export def double [n: int] { $n * 2 }
}
use mymod double
double 21                              # 42
```

**Dispatch rule**: when a module exports `main`, the bare namespace name invokes `main` and any positional args go to it. Subcommands are not reachable via `namespace subcommand` syntax in that case — use selective (`use foo.nu hello`) or wildcard (`use foo.nu *`) imports. A module **without** `main` does support `namespace subcommand args` dispatch directly.

## Useful Flags and Forms

### Missing Data Tolerance

```nu
# `--optional` on cell-path commands skips/nullifies missing keys
$record | select --optional a b c          # missing → null
$record | reject --optional a b            # missing → no error
$record | get --optional name              # missing → null (postfix `?` is equivalent)
$list | where { |x| not ($x.flag? | default false) }   # negate predicate; `where` has no --not flag
```

### Error and Exit Handling

```nu
^cmd args | complete                       # → { stdout, stderr, exit_code }
do --ignore-errors { ^cmd args }           # swallow non-zero exit
try { ... } catch { |e| ... }              # catch nu errors (see Control Flow)
^cmd args; $env.LAST_EXIT_CODE             # raw exit code from previous external
```

### File and Stream Encoding

```nu
open --raw $path                           # bytes/string, skip auto-decode by extension
save --raw --force $path                   # write bytes/string as-is, clobber if exists
to nuon --serialize                        # emit NUON even for partially-unserializable values
to json --raw                              # compact single-line JSON
into binary                                # convert to bytes; pair with `save --raw`
```

### Iteration Modifiers

```nu
ls | each --keep-empty { |f| ... }         # preserve nulls in the output list
"a,,b" | split row --regex ',+'            # regex splitter
$list | sort --natural --reverse           # natural (alphanumeric) order, descending; tables use `sort-by col`
$str | str replace --regex --all 'a.' 'X'  # all matches with regex; default replaces first literal
$value | describe --no-collect             # don't drain streams just to describe them
```

### Inspection and Debugging

```nu
$value | describe                          # runtime type
$value | describe --detailed               # full structural type
$value | inspect                           # print and pass through (debug-tap)
metadata $value                            # source span / origin info
view source <command>                      # show command's source
view files                                 # parsed source files (for module debugging)
```

### Quality of Life

```nu
$record | merge { extra: 1 }               # spread-merge two records
$list | append $more                       # list concat
$list | prepend $more
$"...($expr)..."                           # interpolation; use `r#'...'#` for regex-with-backslashes
^cmd                                       # force-external, even if a nu command of the same name exists
print -e "to stderr"                       # explicit stderr write
ignore                                     # discard a value (suppress final-expression print)
```
