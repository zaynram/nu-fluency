---
name: inspect-shape
description: Inspect the structure of a `nu` expression and return the data's described type, it's length (if applicable), and the value itself.
user-invocable: true
argument-hint: [<expression>]
arguments: [expr]
allowed-tools: ["mcp__nushell__nu_exec"]
---

# Inspect Shape

## Environment

```!
nu --version
```

## Procedure

Pass the provided expression as pipeline input to the `inspect.nu` script.

- **Expression:** `$expr`

Call `nu_exec` with the following parameters:

- `pipeline` set to `$expr | run inspect.nu [--max-rows=<int>]`
- `cwd` set to `${CLAUDE_SKILL_DIR}/scripts`

## Usage (`inspect.nu`)

### Input

The script accepts pipeline input and 0 positional arguments.

#### Options

| Flag(s) | Type | Description | Default |
|---|---|---|---|
| `-m`, `--max-rows` | `int` | Number of rows to include in the `value` field for `list` and `table` values | `3` |

### Output

This will return a record with the following properties:

- `type`: the native nushell type the expression's result
- `length`: the length of the expression's result (omitted for non-enumerables)
- `value`: the expression's result (or a limited item count of an enumerable)

## Constraints

Provide the resulting data to the user in a neat format.

Restrain from commenting on the data unless given explicit direction to do so.

Focus on understanding the structural intuition construed by the data.
