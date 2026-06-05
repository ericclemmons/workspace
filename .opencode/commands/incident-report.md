---
description: Prepare or update a Cloudflare incident report from a Jira incident key
agent: build
---

Load and follow the `mcp-access` skill first.

Load and follow the `incident-report` skill.

If Google Chat screenshots or SSO-gated images are needed, load and follow the `agent-browser` skill.

Run `opencode mcp list` before doing any task work. Treat enabled MCPs that are disconnected, expired, unauthorized, or listed as needing authentication as setup blockers for authenticated Jira, Confluence, or Google Workspace work.

Use the Jira incident key or URL from `$ARGUMENTS` as the incident to process.

If `$ARGUMENTS` is empty, ask the user for the incident Jira key, for example `INCIDENT-1234`.

For the incident report:

1. Fetch the Jira incident, linked issues, comments, status history, and report page URL.
2. Fetch the Confluence report page in storage format.
3. Read the incident report document itself because it contains required guidance for each section.
4. Read the existing instructions under each Confluence section and follow them when adding content.
5. Identify which Jira fields the report page auto-fills.
6. Ask concise questions for ambiguous fields before updating Jira.
7. Update Jira report-driving fields first.
8. Draft/update the Confluence report while preserving the original template, instructions, macros, placeholders, and example rows.
9. Make Confluence changes additive and directly address the instructions in the template.
10. In `Impact`, explicitly answer `WHO`, `HOW MANY`, `HOW LONG`, and `HOW BAD` from the template.
11. Use Jira macros for every Jira issue reference added to Confluence.
12. Add 1 focused inline screenshot, or at most 2, to each relevant section: Impact, SLO Impact, Detection, and Mitigation and Resolution.
13. Upload screenshots as page attachments and embed them inline at original size with no width, height, or thumbnail attributes.
14. Verify the final page in storage format and with attachment metadata.

Do not delete original template text, placeholders, macros, instructions, or example table rows unless the user explicitly asks. Add answers below the template guidance.

Do not use plain Jira links where a Jira macro should be used.

Do not leave screenshot-only Chat links in the report unless the user asks to keep source links.

Report the final Confluence page URL, Jira fields changed, images embedded, and any remaining open questions.
