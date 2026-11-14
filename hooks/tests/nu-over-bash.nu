# Cases for hooks/scripts/nu-over-bash.nu.
# Run from the repository root: nu --no-config-file hooks/tests/nu-over-bash.nu

use std/assert

const SCRIPT = path self ../scripts/nu-over-bash.nu

# Run the hook on a Bash command; return the context it adds, or null.
def nudge [command: string]: nothing -> any {
    {tool_name: Bash, tool_input: {command: $command}}
    | to json
    | ^$nu.current-exe --no-config-file --stdin $SCRIPT
    | from json
    | get hookSpecificOutput?.additionalContext?
}

def main [] {
    # silent: nothing nu does better, file search, already nu, bare cat/head
    for command in [
        'git status'
        'bun test'
        'grep -rn foo src/'
        'cat README.md'
        'git log | head -5'
        "nu -c 'ls | length'"
    ] {
        assert equal (nudge $command) null $'expected no nudge for: ($command)'
    }

    # nudges, naming the command each hint is for
    for case in [
        [command expect];
        ['cat a.json | jq .x' ['`cat`' '`jq`']]
        ["ps aux | awk '{print $2}'" ['`awk`']]
        ['ls | wc -l' ['`wc`']]
        ['FOO=1 sed -i s/a/b/ f && bun test' ['`sed`']]
        ['find . -name "*.ts"' ['`find`']]
        ['while read -r l; do echo $l; done < f' ['`each']]
        ['for f in $(ls); do echo $f; done' ['`each']]
        ['curl -s u | jq .items' ['`http get']]
    ] {
        let context = nudge $case.command
        assert ($context != null) $'expected a nudge for: ($case.command)'
        for word in $case.expect {
            assert str contains $context $word
        }
    }

    # never a permission decision, and silent on a malformed payload
    let output = 'cat a.json | jq .x' | do { {tool_input: {command: $in}} } | to json
    | ^$nu.current-exe --no-config-file --stdin $SCRIPT | from json
    assert ($output.hookSpecificOutput.permissionDecision? == null)
    assert equal ('not json' | ^$nu.current-exe --no-config-file --stdin $SCRIPT | from json) {}

    print 'nu-over-bash: all cases pass'
}
