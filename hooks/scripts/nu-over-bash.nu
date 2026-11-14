# nu-fluency: nudge a Bash tool call toward Nushell without blocking it.
#
# Reads the PreToolUse payload from stdin (Claude Code's hook protocol). When
# the command does text processing that Nushell does structurally (jq, sed,
# awk, grep in a pipeline, read loops, ...), it returns `additionalContext`
# naming the nu equivalents. It never sets a permission decision, so the
# command runs through the normal permission flow either way. Silent on
# anything else, and on any failure.
#
# Invoked by hooks.json as `nu --stdin <this-script>`; no shebang needed.

# Command name → the nu equivalent, phrased as a fact.
const HINTS = {
    jq: '`from json` parses JSON into tables and records; filter with `where`, project with `select`/`get`'
    sed: '`str replace` (with `--regex`/`--all`) edits strings; `lines | each { … }` works per line'
    awk: '`split column`, `parse` or `detect columns` turn text into a table with named columns'
    cut: '`split column` or `parse "{a} {b}"` extract fields by name'
    grep: '`lines | where $it =~ <pattern>` or `find <term>` filter output'
    egrep: '`lines | where $it =~ <pattern>` or `find <term>` filter output'
    wc: '`length` counts list items (`lines | length`); `str length` counts characters'
    sort: '`sort` / `sort-by <column>` order values and tables'
    uniq: '`uniq` / `uniq --count` deduplicate and count'
    cat: '`open <file>` reads a file and parses JSON, YAML, TOML or CSV by its extension'
    xargs: '`each { … }` runs a command per item'
    tr: '`str replace`, `str lowercase`/`str uppercase` and `split chars` cover tr'
    find: '`glob **/<pattern>` or `ls **/*` list files as a table with type, size and modified'
}

# Commands that only count when they consume a pipeline (on their own they
# are fine in bash, and the Grep/Glob tools cover file search). `head` and
# `tail` are left out: a trailing `| head` is too common to be worth a nudge.
const PIPED_ONLY = [grep egrep sort uniq wc tr]

# Commands that only count when their output feeds a pipe.
const PIPING_ONLY = [cat]

# Blank out quoted strings so separators inside them (`echo 'a | jq'`, a
# `nu -c '…'` program) are not read as shell syntax. Escaped quotes inside
# double quotes are kept inside the string.
def strip-quotes []: string -> string {
    str replace --all --regex `'[^']*'` "''"
    | str replace --all --regex `"(\\.|[^"\\])*"` '""'
}

# Split a shell command into segments on pipes and command separators, and
# return the command word of each with whether it reads from or feeds a pipe.
def segments []: string -> table<cmd: string, piped: bool, pipes: bool> {
    let pieces = $in | strip-quotes | split row --regex '(\|\||&&|;|\n)'
    $pieces | each {|piece|
        let parts = $piece | split row '|'
        let last = ($parts | length) - 1
        $parts | enumerate | each {|seg|
            let words = $seg.item | str trim | split row --regex '\s+' | where $it !~ '^\w+=' | where $it != ''
            {
                cmd: ($words | first | default '' | path basename)
                piped: ($seg.index > 0)
                pipes: ($seg.index < $last)
            }
        }
    } | flatten
}

# Hints for a command, or an empty list when nothing applies.
def hints-for []: string -> list<string> {
    let command = $in
    let segs = $command | segments
    # Already running nu somewhere in the command: nothing to nudge.
    if ($segs | any cmd in [nu nu.exe]) { return [] }
    let matched = $segs
    | where cmd in ($HINTS | columns)
    | where piped or cmd not-in $PIPED_ONLY
    | where pipes or cmd not-in $PIPING_ONLY
    | get cmd
    | uniq
    let loops = if $command =~ 'while\s+(IFS=\S*\s+)?read\b|for\s+\w+\s+in\s+\$\(' {
        ['`each { … }` maps over a list (`lines`, `ls`, `glob`) and returns the results; `for` is for side effects']
    } else { [] }
    let curl = if ($segs | any cmd == curl) and ('jq' in $matched) {
        ['`http get <url>` returns parsed JSON directly']
    } else { [] }
    $matched | each {|c| $'`($c)`: ($HINTS | get $c)' } | append $loops | append $curl
}

def main []: string -> nothing {
    let payload = try { $in | from json } catch { {} }
    let command = try { $payload.tool_input.command | into string } catch { '' }
    let hints = try { $command | hints-for } catch { [] }
    if ($hints | is-empty) {
        print '{}'
        return
    }
    let context = [
        "Nushell handles this command's text processing as structured data:"
        ...($hints | each { $'- ($in)' })
        'The nushell MCP runs nu: nu_exec for a one-shot pipeline, nu_repl_* for a session that keeps state across calls.'
    ] | str join "\n"
    {hookSpecificOutput: {hookEventName: PreToolUse, additionalContext: $context}} | to json --raw | print
}
