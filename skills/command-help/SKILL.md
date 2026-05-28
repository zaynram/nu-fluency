---
name: command-help
description: Look up help for a nu command using the `nu_doc_command` MCP tool. This allows the user and Claude to retreive information about a command within the conversation. It also ensures Claude and the user are operating on the same information about the command itself.
arguments: [query]
argument-hint: [command]
allowed-tools: ["mcp__nushell__nu_doc_command", "mcp__nushell__nu_doc_search"]
---

# Command Help

## Procedure

The query to use for the tool calls: `$query`

If the query is empty, surface the requirement to the user and exit.

1. Call `nu_doc_command` with `name: $query`.
2. If `found: true`, render the `help` field neatly and note the nu version.
3. If `found: false`:
   - If `suggestions` is present, display them and offer to search for the best-match.
   - Else, call `nu_doc_search` with `$query`, and surface the top 5 matches.

## Constraints

Keep rendering compact; the help text is already structured.

Minimize commentary and interpretation about the resulting data.

Note the help information for yourself; the help is for both you and the user.
