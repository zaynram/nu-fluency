---
name: audit-pipeline
description: Generate diagnostics from a Nushell code snippet by executing `nu-lint` if available, otherwise uses an experimental agent as fallback. Use when debugging any Nushell code, after authoring any Nushell code, before running the `nu_exec` or `nu_repl` MCP tools, or when the user mentions "Nushell diagnostics", "nu-lint", "Nushell linter", or "generate Nushell diagnostics".
arguments: [expression]
argument-hint: [<expression>, "[--read-only]"]
allowed-tools: ["Bash(*)", "Task(*)", "Read(*)"]
shell: bash
---

# Audit Pipeline

The `!`-executed probes and `$expression` substitution below run once at
invocation, like a slash command's preprocessing — this is not a recurring
hook.

## Environment

- Nushell version: !`nu --version`
- Nu-Lint native installation path: !`which nu-lint || true`
- Nu-Lint WSL installation path: !`wsl.exe --exec which nu-lint || true`

If the native Nu-Lint installation path is not empty, follow the standard [procedure](#procedure).

Else, if the WSL installation path is not empty, then
follow the standard [procedure](#procedure) with the entire command call wrapped
with `wsl.exe` to ensure the binary is on PATH.

Else, follow the [fallback](#fallback) instructions.

## Procedure

1. Run the linter with the pipeline.

   ```bash
   CONFIG="${CLAUDE_PLUGIN_ROOT}/configs/strict.nu-lint.toml"
   # quoted heredoc (<<'PIPELINE') stops bash from expanding the substituted pipeline as shell syntax
   echo "$(cat <<'PIPELINE'
   $expression
   PIPELINE
   )" | nu-lint --stdin --format compact --config "$CONFIG"
   ```

2. Render the diagnostics directly, one per line, with line/column references.

## Fallback

1. Invoke the [`generate-diagnostics`](../../agents/generate-diagnostics.md) Task agent.
2. Prepend a one-line caveat to your output indicating the diminished integrity.
3. Present the diagnostics in a table with each row containing a message and a
line/column reference

## Constraints

If diagnostics return with no warnings or errors, say so explicitly.

If `$ARGUMENTS` does not contain the flag `--read-only`, apply sensible fixes
automatically and await confirmation for further edits.

Else, present the diagnostics to the user without making any changes, and
for each diagnostic, surface `nu-lint --explain <rule>` output.
