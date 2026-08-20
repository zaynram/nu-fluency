---
name: audit-pipeline
description: Generate diagnostics from a Nushell code snippet by executing `nu-lint` if available, otherwise uses an experimental agent as fallback. Use when debugging any Nushell code, after authoring any Nushell code, before running the `nu_exec` or `nu_repl` MCP tools, or when the user mentions "Nushell diagnostics", "nu-lint", "Nushell linter", or "generate Nushell diagnostics".
arguments: [expression]
argument-hint: [<expression>, "[--read-only]"]
allowed-tools: ["Bash(*)", "Task(*)", "Read(*)"]
shell: bash
---

# Audit Pipeline

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

Run the linter with the pipeline.

```bash
CONFIG="${CLAUDE_PLUGIN_ROOT}/configs/strict.nu-lint.toml"
echo "$(cat <<'EOF'
$expression
EOF
)" | nu-lint --stdin --format compact --config "$CONFIG"
```

## Fallback

Invoke the [`generate-diagnostics`](../../agents/generate-diagnostics.md) Task agent.

Prepend a one-line caveat to your output indicating the diminished integrity.

Report your findings in a neat, organized fashion.

## Constraints

Render the diagnostics directly, one per line, with line/column references.

If nu-lint emitted no diagnostics, say so explicitly.

If `$ARGUMENTS` does not contain the flag `--read-only`, apply sensible fixes
automatically and await confirmation for further edits.

Else, present the diagnostics to the user without making any changes, and
for each diagnostic, surface `nu-lint --explain <rule>` output.
