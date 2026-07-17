---
name: audit-pipeline
description: Audit a provided Nushell pipeline. Executes `nu-lint` for diagnostics if available, otherwise uses an experimental agent as fallback.
arguments: [pipeline]
argument-hint: [expression]
allowed-tools: ["Bash", "Task", "Read"]
---

# Audit Pipeline

## Environment

```!
echo 'resolving nu-lint installation'
which nu-lint ||
   wsl.exe --exec which nu-lint ||
   echo 'nu-lint is not installed'
```

## Procedure

The pipeline to review: `$pipeline`

1. Determine if `nu-lint` is installed using the [environment](#Environment) output.

2. If `nu-lint` is available:

Run the linter with the pipeline piped in as a raw string:

```nu
let config: path = `${CLAUDE_PLUGIN_ROOT}` | path join configs strict.nu-lint.toml
r#'$pipeline'# | nu-lint --stdin --format=compact --config=$config
```

Render the diagnostics directly, one per line, with line/column references.

- For each diagnostic, surface `nu-lint --explain <rule>` output as the "why"
- If nu-lint emitted no diagnostics, say so explicitly — clean pipeline

2. Else,

Use the `generate-diagnostics` Task agent as a fallback diagnostics generator.

Prepend a one-line caveat to your output indicating the diminished integrity.

Report your findings in a neat, organized fashion.

## Constraints

Never apply rewrites automatically; the user decides what to take.
