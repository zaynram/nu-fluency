---
name: inspect-shape
description: This skill is used to inspect the structure of a nu expression. It surfaces the data's described type, it's length (if applicable), and a sample of the value. The sample will contain the raw value itself for non-enumerable types, otherwise it will contain the first three values of the enumerable.
user-invocable: true
argument-hint: [<expression>]
arguments: [expr]
allowed-tools: ["mcp__nushell__nu_run"]
---

# Inspect Shape

## Environment

```!
nu --version
```

## Procedure

Invoke the `inspect.nu` script with the expression as pipeline input.

The expression to evaluate and inspect: `$expr`

Call `nu_run` with:

```json
{
  "pipeline": "$expr | nu ([${CLAUDE_SKILL_DIR} scripts] | path join inspect.nu)"
  // ...
}
```

This will return a record with the following properties:

- `type`: the nushell type of the expression's result
- `len`: the length of the expression's result (omitted for non-enumerables)
- `sample`: a sample of the expression's result (or the result itself for non-enumerables)

## Constraints

Provide the resulting data to the user in a neat format.

Restrain from commenting on the data unless given explicit direction to do so.

Focus on understanding the structural intuition construed by the data.
