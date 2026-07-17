---
name: command-help
description: Get helpful information using the `nu_doc_help` and `nu_doc_search` MCP tools. Use when searching for a command, querying available commands, needing information about a command, inspecting a command signature (e.g. I/O contract, parameter types, return types), or when the user mentions "nu help", "query the nu docs", "what does <command> do", or "is there a nu command for this".
arguments: [query]
argument-hint: [<query>]
allowed-tools: ["mcp__nushell__nu_doc_help", "mcp__nushell__nu_doc_search"]
compatibility: { nu: '>=0.114.0' }
version: 0.1.2
---

# Command Help

## Procedure

The query to use for the tool calls: `$query`

If the query is empty, the user is pushing you to read Nushell
documentation relevant to your recent activity. If you have not
used the `mcp_nushell__*` tools or are unable to determine this
skill's relevance to your session, inform the user and return.

### Exact Commands

When the query is a complete command name, use the `nu_doc_help` tool
with `name: $query` to search for an exact match.

- If found, render the `help` field neatly and note the nu version.
- Else if `suggestions` is present, display them and offer to search for the best-match.
- Else, follow the [Search Strings](#search-strings) procedure below.

### Search Strings

When the query is not a complete command, or is not found by `nu_doc_help`,
then call `nu_doc_search` with `$query`.

- If there is an exact match to the query, run the `nu_doc_help` tool on
the matching item and present the information to the user.
- Else if there are matches but none exactly match the query, then present the
top five matches to the user and offer to run `nu_doc_help` to retrieve more
specific information.
- Else, inform the user that you were unable to locate any commands
based on the query.

## Constraints

Keep rendering compact; the help text is already structured.

Avoid commentary and interpretation about the resulting data.

Note the help information for yourself; the help is for both you and the user.
