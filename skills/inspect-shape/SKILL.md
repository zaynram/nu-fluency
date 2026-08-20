---
name: inspect-shape
description: Inspects the structure of a `nu` expression and return it's described type, length (if applicable), and the value itself. Use when you are uncertain about a pipeline result's data type, debugging Nushell code, testing that a Nushell expression produces an expected shape, or when the user mentions "typecheck", "unknown data types", "inspect the shape", or "what kind of data".
user-invocable: false
allowed-tools: ["mcp__nushell__nu_exec"]
compatibility: { nu: '>=0.114.0' }
version: 0.1.1
---

# Inspect Shape

## Environment

```!
nu --version
```

## Usage (`inspect`)

```!
nu --no-std-lib --no-config-file --commands "inspect --help"
```

## Procedure

Call `nu_exec` with `pipeline` set to `<expression> | inspect | ignore`
