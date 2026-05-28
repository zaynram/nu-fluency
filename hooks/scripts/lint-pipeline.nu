# nu-fluency: lint the `pipeline` argument of an MCP nu_run call.
#
# Reads tool-input JSON from stdin (Claude Code's hook protocol),
# pipes the pipeline string through nu-lint, and emits a non-empty
# response only when nu-lint actually flags something. Silent on
# clean code, silent when nu-lint isn't installed.
#
# Invoked by hooks.json as `nu <this-script>`; no shebang needed.
#
# Probe order:
#   1. `nu-lint` on PATH (any platform).
#   2. Windows native cargo install locations:
#        ~/.local/share/cargo/bin/nu-lint.exe   (XDG-style)
#        ~/.cargo/bin/nu-lint.exe               (default)
#   3. WSL fallback: ~/.cargo/bin/nu-lint inside WSL.
#   4. Nothing → silent pass-through.

# Resolve which nu-lint invocation to use on this host. Returns a record
# with `cmd` + `args`, or `null` if no usable runtime is available.
def resolve-lint-runner []: nothing -> any {
    # Use the resolved path (which includes `.exe` on Windows) rather than
    # the bare command name — nu's `^cmd` form on Windows wants the full
    # filename to spawn the process reliably.
    let direct = which nu-lint | first | get path? | default null
    if $direct != null {
        return {cmd: $direct, args: [--stdin --format compact]}
    }

    # Windows native cargo install locations — common when `cargo install
    # nu-lint` ran on the Windows side but the cargo bin dir isn't on PATH.
    let home = $env.USERPROFILE? | default ''
    let xdg_cargo = $home | path join .local share cargo bin nu-lint.exe
    if ($xdg_cargo | path exists) {
        return {cmd: $xdg_cargo, args: [--stdin --format compact]}
    }
    let std_cargo = $home | path join .cargo bin nu-lint.exe
    if ($std_cargo | path exists) {
        return {cmd: $std_cargo, args: [--stdin --format compact]}
    }

    # WSL fallback: nu-lint installed inside a Linux distro.
    if (r#'C:\Windows\System32\wsl.exe'# | path exists) {
        return {
            cmd: wsl.exe
            args: [--exec bash -c '~/.cargo/bin/nu-lint --stdin --format compact']
        }
    }

    null
}

# Extract the user pipeline from the JSON payload Claude Code piped in.
# Returns the empty string if no pipeline field is present.
def extract-pipeline []: record -> string {
    let payload = $in
    $payload.tool_input?.pipeline?
    | default $payload.arguments?.pipeline?
    | default ''
    | into string
}

# Build the block-reason text shown when nu-lint flags issues.
def format-reason []: string -> string {
    let diagnostics = $in
    let count = $diagnostics | lines | length
    let header = $"nu-lint flagged ($count) issue\(s\) in the just-executed nu pipeline."
    let footer = 'Run `nu-lint --fix <file>` to auto-fix where possible, or `/nu-audit` for guidance. To silence specific rules edit `configs/hook.nu-lint.toml`.'
    [$header '' $diagnostics '' $footer] | str join "\n"
}

# Run nu-lint against a piped-in pipeline string. Returns the trimmed
# diagnostics string when there are findings, or null on any condition
# that means "stay silent" (no runner available, linter errored, no
# findings).
def analyze []: string -> oneof<string, nothing> {
    let pipeline = $in
    let runner = resolve-lint-runner
    if $runner == null { return null }

    let plugin_root = $env.CLAUDE_PLUGIN_ROOT? | default .
    let config_path = $plugin_root | path join configs hook.nu-lint.toml
    let extra_args = if ($config_path | path exists) { [--config $config_path] } else { [] }

    let result = (
        $pipeline
        | run-external $runner.cmd ...$runner.args ...$extra_args
        | complete
    )
    # Linter errored, missing input, etc. → silent. We never want OUR hook
    # to block on OUR tooling's failure.
    if $result.exit_code != 0 { return null }

    # nu-lint emits "No violations found!" on a clean pass — non-empty stdout
    # that does NOT represent a finding. Real diagnostics match the pattern
    # `<path>:<line>:<col>: <level>(<rule>): …`. Keep only those.
    let diagnostics = (
        $result.stdout
        | lines
        | where $it =~ '^[^:]+:\d+:\d+:\s+(warning|error|hint)\('
        | str join "\n"
    )
    if ($diagnostics | is-empty) { return null }
    $diagnostics
}

# Hook entry point. `main` is required because we read `$in` here;
# nu-lint flags `$in` used outside `main` as a runtime-error risk.
def main []: string -> nothing {
    # Defensive parse: if input isn't JSON for any reason, exit silent.
    let payload = try { $in | from json } catch { {} }
    let pipeline = $payload | extract-pipeline

    # Nothing to lint → silent pass-through.
    if ($pipeline | str trim | is-empty) {
        print '{}'
        return
    }

    let diagnostics = $pipeline | analyze
    if $diagnostics == null {
        print '{}'
        return
    }

    # Real findings → surface as a block reason.
    {decision: block, reason: ($diagnostics | format-reason)} | to json --raw | print
}
