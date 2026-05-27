---
name: mcp-access
description: Use for MCP status checks, MCP setup, MCP authentication, Jira, Confluence, Google Chat, Gmail, Google Calendar, Google Drive, Google Docs, Google Workspace, Cloudflare Access, cf-portal, or atlassian access; requires MCP tools instead of WebFetch and includes auth refresh steps.
---

# MCP Access

Use MCP tools for all authenticated work and for requests to check, set up, or repair MCP access. Do not use WebFetch for Jira, Confluence, Google Chat, Gmail, Google Calendar, Drive, Docs, Sheets, Slides, Forms, Cloudflare internal pages, or any Cloudflare Access-protected URL. WebFetch cannot satisfy Cloudflare Access and usually returns an auth wall or unusable content.

## Preflight

Before authenticated Atlassian, Google Workspace, Cloudflare internal work, or any generic MCP status/setup request, run:

```sh
opencode mcp list
```

Expected healthy state:

- `cf-portal` is `connected (OAuth)`.
- `atlassian` is `connected`.
- Other enabled MCPs needed for the task are `connected`.

If `cf-portal` is disconnected, expired, unauthorized, or tools fail with auth errors and no valid credentials are present, run:

```sh
opencode mcp auth cf-portal
```

`opencode mcp auth cf-portal` is interactive when credentials already exist: it prompts whether to re-authenticate and blocks unattended agent work. If `opencode mcp list` shows cf-portal has credentials but the session is expired or invalid, do not run `opencode mcp auth cf-portal` directly. First ask the user to log out/disconnect cf-portal from `/mcp` or otherwise clear the existing OAuth credentials, then run auth again.

After auth completes, re-check with `opencode mcp list`. If tools are still unavailable in the current OpenCode session, tell the user to run `/mcp` and reconnect/reload MCP servers, or quit and restart OpenCode. This is expected because cf-portal credentials expire several times a day.

## Tool Selection

Prefer the direct Atlassian MCP tools for Jira and Confluence when available:

- Jira: `atlassian_jira_search`, `atlassian_jira_get_issue`, `atlassian_jira_create_issue`, `atlassian_jira_update_issue`, `atlassian_jira_add_comment`, `atlassian_jira_transition_issue`, and related `atlassian_jira_*` tools.
- Confluence: `atlassian_confluence_search`, `atlassian_confluence_get_page`, `atlassian_confluence_create_page`, `atlassian_confluence_update_page`, `atlassian_confluence_add_comment`, and related `atlassian_confluence_*` tools.

Use cf-portal codemode for Cloudflare-hosted MCP servers and Google Workspace:

- Discover tools with `cf-portal_portal_codemode_search`.
- Execute tools with `cf-portal_portal_codemode_execute`.
- Gmail tools are named like `google_workspace_mcp_gmail_search`, `google_workspace_mcp_gmail_get_message`, `google_workspace_mcp_gmail_send`, and `google_workspace_mcp_gmail_reply`.
- Calendar tools are named like `google_workspace_mcp_calendar_list`, `google_workspace_mcp_calendar_get_events`, and `google_workspace_mcp_calendar_freebusy`.
- Google Chat tools are named like `google_workspace_mcp_chat_list_spaces`, `google_workspace_mcp_chat_search_messages`, `google_workspace_mcp_chat_get_thread`, and `google_workspace_mcp_chat_find_dm`.
- Drive and document tools are named like `google_workspace_mcp_drive_search`, `google_workspace_mcp_drive_get_content`, `google_workspace_mcp_docs_get`, `google_workspace_mcp_sheets_get_values`, `google_workspace_mcp_slides_get`, and `google_workspace_mcp_forms_get`.
- cf-portal also exposes Cloudflare Docs, Backstage, GitLab, Jira, PagerDuty, Prometheus, Sentry, and Wiki/Confluence servers. Search before assuming an exact tool name.

## Failure Handling

If an MCP call fails:

1. Check whether it is an auth or connection failure.
2. For cf-portal auth failures with no existing credentials, run `opencode mcp auth cf-portal` and retry once.
3. For cf-portal auth failures with existing credentials, ask the user to log out/disconnect cf-portal first because `opencode mcp auth cf-portal` is interactive in that state.
4. If retry still fails, ask the user to reconnect from `/mcp` or restart OpenCode.
5. Do not fall back to WebFetch for Cloudflare Access-protected content.

## Current Evaluation

At the time this skill was created, `opencode mcp list` showed:

- `cf-portal`: connected over OAuth at `https://portal.mcp.cfdata.org/mcp?codemode=search_and_execute`.
- `atlassian`: connected via `/Users/eric/.local/bin/mcp-atlassian-cf`.
- `sentry` and `Solo`: connected.
- `excalidraw-cf`: disabled.

cf-portal tool discovery found Google Workspace tools for Gmail, Calendar, Drive, Docs, Sheets, Slides, Forms, Chat, People, and Tasks, plus Jira and Wiki/Confluence tools. Direct Atlassian tools are also available in this OpenCode session for Jira and Confluence.
