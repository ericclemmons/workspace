---
description: Check MCP auth, then do the requested work
agent: build
---

Load and follow the `mcp-access` skill first.

Run `opencode mcp list` before doing any task work. Treat enabled MCPs that are disconnected, expired, unauthorized, or listed as needing authentication as setup blockers for authenticated work.

If `cf-portal` is not `connected (OAuth)`, run `opencode mcp auth cf-portal`, wait for the authentication flow, then run `opencode mcp list` again. If any required MCP tools still are not available in this OpenCode session after auth succeeds, tell the user to run `/mcp` and reconnect/reload MCP servers, or quit and restart OpenCode.

Use MCP tools for authenticated Jira, Confluence, Google Workspace, Cloudflare internal, and Cloudflare Access-protected work. Do not use WebFetch for those resources.

After MCP preflight is healthy, do this work:

$ARGUMENTS

If no task was provided in `$ARGUMENTS`, report the MCP status and ask what work to do next.
