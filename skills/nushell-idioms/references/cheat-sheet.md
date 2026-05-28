# Nushell Cheat Sheet

Pull when you need syntax for a specific operation.

For anti-patterns and recalibration, see the [skill](`../SKILL.md`).

## Data Conversion

```nu
# string -> int
"12" | into int                  # 12

# int -> duration
120 | into duration              # 120ns
# duration -> int
500ms | into int                 # 500000000

# string -> datetime -> string
'2026-03-11 13:00'
| date from-human                # Wed, 11 Mar 2026 13:00:00 -0500
| format date %Y-%m-%d           # 2026-03-11

# record -> json (string)
{a: 1, b: 2} | to json --raw     # {"a":1,"b":2}

# json (string) -> list<record>
'[{"x": 1}]' | from json         # [{x: 1}]

# list<string> -> yaml (string)
[a b c] | to yaml                # - 'a'\n- 'b'\n- 'c'
```

## Records

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

```nu
[[a b]; [1 2] [3 4]]                      # table literal (header row)
ls | sort-by size --reverse | first 5
$table | select name size                 # column projection
$table | where size > 1kb
$table | group-by ext                     # → record of tables
$table | drop column                      # remove last column
$table | move name --after size
$table | rename old new
$a | append $b                            # concat (same columns)
$record | transpose key value             # record → table
$table | into record                      # table → record (with care; see notes)
```

## Strings

```nu
let name = "alice"
$"hello ($name)"                          # interpolation
"hello,world,3" | split row ","           # → list
"hello world" | str contains "world"      # → bool
"hello" | str upcase
"hello" | str length
'Hello World' | str substring 0..4        # → "Hello"
[a b c] | str join ","                    # → "a,b,c"
'Nushell 0.111' | parse '{shell} {version}'   # → table with named cols
"a,b\n1,2" | from csv                     # → table
$"(ansi red)error(ansi reset)"            # terminal colors
```

## Filesystem

```nu
ls
ls *.md
ls **/*.rs                                # recursive (with glob)
glob **/*.{js,ts} --depth 3
open file.txt                             # text, structured, or binary by ext
open --raw file.bin                       # force raw bytes
'data' | save out.txt
'more' | save --append out.txt
{a:1} | save out.json
watch . --glob=**/*.rs { || cargo test }
```

## Env and Scope

```nu
$env.HOME                                 # access
$env.NEW = "val"                          # set (current scope)
load-env { A: "1", B: "2" }               # bulk set
with-env { TMP: "/tmp" } { run-thing }    # scoped: only inside closure
do --env { $env.X = "y" }                 # closure mutations propagate out
do { $env.X = "y" }                       # mutations stay inside (default)
for k in (ls) { $env.X = $k.name }        # `for` propagates env; `each` doesn't
```

## Variables

```nu
let x = 42                                # immutable
mut y = 0; $y += 1                        # mutable
const PATH = "/etc/foo"                   # parse-time constant
do { let val = 101; $val }                # shadowing scope
let result = (ls | where size > 10kb)     # capture pipeline
```

## Control Flow

```nu
if $x > 0 { "pos" } else if $x < 0 { "neg" } else { "zero" }
match $color { "red" => 1, "green" => 2, _ => 0 }
try { risky-thing } catch { |e| $"failed: ($e.msg)" }
for n in 1..5 { print $n }
while $cond { do-thing }
```

## Custom Commands

```nu
def greet [name: string, --loud] {
    if $loud { $"HELLO ($name)" } else { $"hello ($name)" }
}
def sum [...nums: int] { $nums | math sum }
def --env enter [path: string] { cd $path }   # mutates caller's env
```

## Modules

```nu
# greetings.nu
export def hello [name] { $"hi ($name)" }
export-env { $env.GREETING_LOADED = true }
export def main [] { "greetings and salutations" }

# caller
use greetings.nu
greetings hello "world"      # → "hi world"
greetings                    # → "greetings and salutations"
```

## Useful Flags

- `reject --optional` — skip missing columns instead of erroring
- `get --optional` — equivalent to `?` postfix on cell paths
- `select --optional` — missing columns return null
- `to nuon --serialize` — emit NUON allowing unserializeable data
- `complete` — wrap a command, return `{stdout, stderr, exit_code}`
