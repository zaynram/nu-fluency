---
name: env-snapshot
description: Snapshot values from the nushell environment for the provided keys as a record. If no keys are provided, a default set is substituted.
user-invocable: true
argument-hint: [<...keys>]
allowed-tools: ["mcp__nushell__nu_run"]
---

# Env Snapshot

## Procedure

Call `nu_run` with the following template as pipeline input:

```json
{
  "pipeline": "$env | select --optional <keys>"
}
```

Substitute `<keys>` respective to the user-provided arguments as follows:

### Case 1: User-Provided Keys

`<keys>` => `$ARGUMENTS`

### Case 2: Default Keys

`<keys>` => `HOME PATH USER PWD SHELL NU_VERSION NU_LIB_DIRS NU_PLUGIN_DIRS`

The `nu_run` call will return a record containing the corresponding key-value pairs.

## Constraints

Provide the resulting data to the user in a neat format.

Restrain from commenting on the data unless given explicit direction to do so.

Emphasize any `null` values to surface the missing data to the user.
