---
name: incident-report
description: Use for Cloudflare incident reports from Jira incidents like INCIDENT-1234; updates Jira fields, drafts Confluence incident reports, follows the report template instructions, selects the best evidence format, and uses Jira macros correctly.
---

# Incident Report

Use this skill when the user asks to prepare, draft, update, or complete a Cloudflare incident report from an incident Jira key such as `INCIDENT-1234`.

## Required Skills

- Load and follow `mcp-access` first.
- Load and follow `agent-browser` when Google Chat screenshots or headed SSO are needed.

## Workflow

1. Run `opencode mcp list` before authenticated work.
2. Fetch the Jira incident and Confluence report page.
3. Fetch the Confluence page in `storage` format and inspect the actual section instructions in the template.
4. Audit the current draft in storage format before editing. Check for direct Chat image URLs, fixed image dimensions, screenshot-only links, plain Jira issue links where Jira macros are required, missing required section answers, and already-populated Jira-backed fields.
5. Identify the Confluence report's Jira-backed fields from the page storage or template.
6. Update Jira fields first so Confluence macros auto-fill correctly.
7. Draft/update Confluence content while preserving the original template.
8. Add evidence in the format that best represents the source data.
9. Do a human-readability pass: remove assistant/edit meta language, awkward labels, misleading evidence captions, or structure that would not belong in a final incident report.
10. Verify the final page in storage format and check attachments.
11. When Confluence was edited via storage or REST, open the rendered page in a browser and verify the page reads cleanly to a human.

## Follow The Confluence Template

- Treat the Confluence incident report page as the source of truth for what each section must answer.
- Read the incident report document itself before drafting. It contains the required guidance for each section.
- Read and follow the section-specific instructions that are already present in the page.
- Make changes additive and directly address the instructions in the template.
- Do not merely fill generic prose under a heading. Answer the questions in that section's prompt in the added content.
- Do not change the report structure by adding new headings under existing sections. Put the answer directly under the template guidance as paragraphs, lists, or table rows within the existing section.
- Do not add edit-marker labels such as `Added Impact Details`, `Added Detection Details`, `Draft`, `Assistant Notes`, or similar meta headings. The report should read like a final incident report, not an annotated diff.
- Preserve the instructional text/placeholders unless the user explicitly asks to remove them.
- Add content after the instructions, not instead of them.
- If preserved original rows or placeholders are incomplete, stale, or redundant after your additions, leave them in place unless the user asked for cleanup. Call them out in the final response and ask before deleting or rewriting them.
- If a section asks for data you do not have, write the known facts and explicitly call out what still needs confirmation.
- When editing storage format, identify the existing section heading and the next existing section heading, then insert or replace content only within that section boundary. Avoid brittle whitespace-specific matches copied from Markdown rendering.
- If the user provides remembered incident context, treat it as authoritative for drafting. Use Jira, Chat, and Confluence evidence to corroborate, refine, or find supporting artifacts rather than ignoring the correction.

For example, when filling `Impact`, answer the template's prompts explicitly:

- `WHO`: which customers or customer types were affected, and whether the impact was random or consistent.
- `HOW MANY`: number of customers, builds, requests, users, or other units impacted, with context of total volume when available.
- `HOW LONG`: first possible impact, first observed impact, and duration/frequency of impact.
- `HOW BAD`: the regrettable customer experience.

For `SLO Impact`, answer whether the impacted usage is covered by an SLO and quantify error-budget burn when available. If burn is unknown, state that it still needs to be calculated from the SLO dashboard.

For `Detection`, identify who or what noticed the impact first, when it happened, and whether expected alerts fired.

For `Trigger`, distinguish the immediate trigger from the root cause.

For `Root Causes`, connect each cause to a prevention action or Jira macro. Do not just list tickets.

For `Mitigation and Resolution`, explain why impact ended when it did and not later.

For `Timeline`, include the critical markers requested by the template, including incident declared, first alert, investigation begins, impact begins, impact ends, and incident resolved.

## Current Draft Audit

Before editing an existing report draft, inspect the storage body and produce a quick internal audit of:

- Jira-backed fields rendered by the template and whether Jira already has values for them.
- Direct Google Chat image URLs such as `chat.google.com/api/get_attachment_url`.
- Image sizing attributes: `ac:width`, `ac:height`, `width`, `height`, or `ac:thumbnail`.
- Screenshot-only Chat links or pasted image URLs that should be replaced by uploaded attachments, tables, or quotes.
- Plain Jira issue links or bare issue keys in newly-added content where Jira macros should be used.
- Whether `Impact` explicitly answers `WHO`, `HOW MANY`, `HOW LONG`, and `HOW BAD`.
- Whether `SLO Impact`, `Detection`, `Trigger`, `Root Causes`, `Mitigation and Resolution`, and `Timeline` answer the template instructions.
- Existing stale template/example rows or placeholders that should be preserved but reported to the user if they conflict with the completed draft.

Use this audit to avoid duplicating work already done by the user and to focus edits on gaps or rule violations.

## Evidence Selection Rules

- Use the most idiomatic evidence format for the source data. Do not force everything into screenshots.
- Pictures = images. Use original graph/image attachments or dashboard screenshots when the evidence is visual.
- Tables = Confluence tables. Convert query output, counts, percentiles, before/after measurements, and tabular Chat snippets into tables.
- Confirmation = quotes. Use block quotes for textual confirmation, customer/staff statements, status decisions, and short incident-room messages.
- Prefer the best data for the report over the easiest artifact to embed. A clear table or quote is better than a screenshot of a Chat message containing the same data.
- Do not embed screenshots of Google Chat chrome unless the report specifically needs visual proof of a conversation. Chat UI screenshots are conversation evidence only, never metric evidence.
- Screenshots must show the evidence itself, not a Chat message that merely references the evidence. For example, embed the Grafana recovery graph, not a GChat screenshot saying latency returned to normal.
- Do not reuse the same screenshot across multiple sections unless it directly supports each section and no better evidence exists. If reuse is necessary, keep the surrounding text specific to that section.
- If a related incident report is provided or discovered, compare its evidence choices before finalizing this report. Reuse the evidence pattern only when the failure mode is similar; otherwise explain why a different graph/table/quote is better.

## Jira Field Rules

- Use direct Atlassian Jira MCP tools for Jira reads/updates.
- Do not guess option values. Fetch field schemas/options or ask the user.
- Use option IDs when required by Jira update APIs.
- Update report-driving fields before editing Confluence.
- Typical incident report fields include:
  - `customfield_17009`: Impact Start Timestamp.
  - `customfield_17010`: Impact End Timestamp.
  - `customfield_14908`: Time to Restore (min).
  - `customfield_14910`: Detected By.
  - `customfield_14900`: Customer Facing IR needed?
  - `customfield_15200`: Customer.
  - `customfield_15201`: Publicity.
  - `customfield_15700`: Impacted Environment.
  - `customfield_16155`: Proximal Cause.
  - `customfield_15962`: Status Page Link.
- If a needed value is ambiguous, ask the user one short question with concrete choices.

### Timestamp and Time-To-Restore Rules

- Treat Jira API timestamps as UTC unless the field value explicitly carries another offset. Confluence browser rendering may display local time; do not copy browser-rendered local times back into Jira as UTC.
- Compute `customfield_14908` Time to Restore from the impact start and impact end timestamps in UTC, in minutes.
- Before updating impact end/start fields, compare the proposed UTC value against the evidence timestamp and the Confluence-rendered local value to catch accidental timezone shifts.
- If impact start is only bounded by available data retention, use the earliest visible evidence timestamp only when Jira requires a concrete value, and state in the report that the exact start is unknown.

## Confluence Content Rules

- Fetch Confluence pages in `storage` format before editing.
- Preserve the original incident report template, placeholders, Jira macros, and example rows.
- Only add content or table rows unless the user explicitly asks to delete or replace existing text.
- Do not introduce new `h1`, `h2`, `h3`, or other heading elements inside report sections unless the existing template already has that exact heading and the user asks you to modify it.
- Insert report prose immediately before the next existing section heading, or append rows to the existing table for table-based sections.
- Prefer section-bound edits in storage format: locate the current section heading, locate the next existing section heading, and operate only inside that range.
- Prefer direct Atlassian Confluence MCP tools for content updates.
- After updating, read the page back in storage format and verify expected macros/content.

### Browser REST Fallback for Confluence

Use this fallback when direct Confluence MCP updates fail, when Cloudflare Access blocks direct API access, or when browser SSO is the only working authenticated path:

1. Load `agent-browser` and open the Confluence page in a named headed session.
2. Ask the user to complete SSO if the browser lands on Cloudflare Access or an identity provider.
3. Verify the browser is on the target Confluence page by checking the title or URL.
4. From `agent-browser eval --stdin`, fetch storage with `fetch('/rest/api/content/{pageId}?expand=body.storage,version,space', { credentials: 'include' })`.
5. Update with `PUT /rest/api/content/{pageId}` using the next page version and `body.storage.value`.
6. Re-fetch storage and verify the intended content, macros, and image embeds.

Do not use the browser fallback to bypass the template rules. It is only an authenticated transport for the same storage-preserving edits.

## Jira Macro Rules

- Every Jira issue reference added to Confluence must use a Confluence Jira macro, not a plain URL.
- Do not restate the issue key/title next to a Jira macro unless the surrounding prose needs extra context; the macro renders the issue key, summary, type, priority, status, and other configured columns.
- Write prose around Jira macros as rendered widgets. For example, use `Prevention is tracked in <jira macro>.` rather than `Prevention is tracked in ISSUE-123 - title <jira macro>`.
- In browser view, a Jira macro commonly renders as `KEY - summary STATUS`. That is expected and should be considered the issue title/status display.
- Use `/jira`-style storage macros for issue references:

```xml
<ac:structured-macro ac:name="jira" ac:schema-version="1">
  <ac:parameter ac:name="server">Cloudflare Jira</ac:parameter>
  <ac:parameter ac:name="columnIds">issuekey,summary,issuetype,created,updated,duedate,assignee,reporter,priority,status,resolution</ac:parameter>
  <ac:parameter ac:name="columns">key,summary,type,created,updated,due,assignee,reporter,priority,status,resolution</ac:parameter>
  <ac:parameter ac:name="serverId">cc100dec-3d79-305b-8fae-4caba5e44cd2</ac:parameter>
  <ac:parameter ac:name="key">ISSUE-123</ac:parameter>
</ac:structured-macro>
```

- In storage XML, include unique `ac:macro-id` values when practical.
- Markdown read-back may render Jira macros as very verbose text. This noise is expected. Verify macro correctness in storage format and verify report readability in the rendered browser page.

## Image Rules

- Add 1 focused image, or at most 2, in each relevant report section when a picture is the best evidence format.
- Put images where they explain the section. Do not dump a gallery at the end.
- Recommended placements:
  - `Impact`: customer-visible queue/backlog evidence. Prefer tables when impact evidence is query output.
  - `SLO Impact`: SLO or availability chart, or a table of SLO thresholds/percentiles if that is the evidence available.
  - `Detection`: first alert, Sentry, or error evidence. Use quotes when detection evidence is a Chat/customer statement.
  - `Mitigation and Resolution`: recovery, rollout, or errors-going-away evidence. Use before/after tables when recovery evidence is tabular.
- Upload images as Confluence page attachments and embed them inline.
- Do not set image sizing attributes. Do not set `ac:width`, `width`, `height`, or `ac:thumbnail`.
- Confluence may normalize storage image markup after save. Both `<ac:image><ri:attachment ... /></ac:image>` and rendered/read-back `<img src="/download/attachments/...">` forms are acceptable when the image points to a page attachment and has no width, height, or thumbnail attributes.
- Because Confluence can normalize attachment embeds during save, verify image correctness by properties, not by exact XML shape: image source is a current page attachment, no direct SSO-gated Chat URL remains, and no size/thumbnail attributes remain.
- Prefer natural/original-size inline images:

```xml
<ac:image>
  <ri:attachment ri:filename="incident-1234-impact.png" />
</ac:image>
```

- Do not leave screenshot-only Chat links in the report unless the user asks for provenance links.
- Do not upload or embed screenshots of Google Chat when the underlying evidence is a graph image, table, or quote that can be represented directly.

## Google Chat Screenshot Workflow

- Use cf-portal Google Chat tools to discover relevant messages and candidate images.
- Google Chat attachment URLs returned by APIs may resolve to HTML auth pages when downloaded from shell.
- For actual image bytes, use `agent-browser --headed` when needed and ask the user to complete SSO in the headed browser.
- Use named browser sessions for Chat/Wiki work so SSO state can be reused during the same task. Chat and Wiki may require separate SSO interactions even when MCP authentication is healthy.
- After opening a headed browser for SSO, stop and wait until the user confirms they are fully inside the target app. Then verify the current URL/title before capturing or downloading anything.
- Prefer original Google Chat image attachments over page screenshots. Open the image preview, click `Download`, then copy the newest completed PNG from `~/Downloads` to a stable filename.
- If legacy `https://chat.google.com/room/...` links redirect to sign-in or lose auth, try the internal route form after the browser is signed in: `https://chat.google.com/app/chat/<space-id>/topic/<thread-id>/message/<message-id>`.
- If a Chat attachment is a screenshot of a graph or dashboard, open/download the actual attachment image. Do not replace it with a browser screenshot of the surrounding Chat UI unless the Chat conversation itself is the evidence being documented.
- If the image is visible in the authenticated browser but the download flow is unreliable, extract the rendered attachment image URL from the DOM and fetch the image bytes from the authenticated browser context when feasible.
- Verify every downloaded file with `file`. Do not upload HTML auth pages.

## Attachment Upload Fallback

- Try Atlassian Confluence MCP upload tools first.
- Treat MCP upload responses as successful only when attachment metadata confirms the file exists on the page. Some upload tools can return a top-level success message while the nested attachment result has `success: false` or the file is absent from `get_attachments`.
- If uploads fail with filenames containing spaces, retry once with simple ASCII filenames from a stable temp directory before falling back.
- If Confluence MCP attachment upload fails but content updates work, use direct Confluence REST as a fallback.
- Operational sequence: upload with MCP, verify with `atlassian_confluence_get_attachments`, retry once with simple ASCII filenames if absent, use REST fallback if still absent, then verify with `get_attachments` before editing the page body to embed those files.
- If Confluence rejects a duplicate attachment filename, update the existing attachment data instead of posting a duplicate. For Confluence Server/DC this is commonly `POST /rest/api/content/{pageId}/child/attachment/{attachmentId}/data` with `X-Atlassian-Token: no-check`.
- Use the existing authenticated Confluence access path configured for MCP; do not print secrets in responses. For Cloudflare Access-protected Confluence, obtain a Cloudflare Access token with `cloudflared access token <confluence-url>` for REST requests. Keep this wrapper-agnostic; do not assume a specific local wrapper script exists.
- After upload, verify attachments with `atlassian_confluence_get_attachments`.

## Report Drafting Guidance

- Lead with a concise incident summary understandable to any Cloudflare engineer.
- Make impact customer-oriented and explicitly answer the template's `WHO`, `HOW MANY`, `HOW LONG`, and `HOW BAD` prompts.
- Keep uncertainties explicit and mark what still needs metrics confirmation.
- Root causes should connect cause to prevention. Do not just list Jira tickets.
- Timeline should include the key markers requested by the template.
- Impact must contain explicit answers to `WHO`, `HOW MANY`, `HOW LONG`, and `HOW BAD`. If those labels are not appropriate for the final report prose, the answers must still be clearly identifiable in paragraph form.
- SLO Impact must state whether the affected usage is covered by an SLO, whether error-budget burn is known, and what gap remains if burn is unknown.
- Detection must state the first detection path, the time of first known detection, and whether expected automated alerts/SLOs fired.
- Trigger must say what initiated the incident at that time. If no discrete trigger is known, say so and distinguish customer escalation/incident declaration from technical root cause.
- Root Causes must include direct causes, contributing factors, and a prevention action or Jira macro for each actionable cause.
- Mitigation and Resolution must state what changed, when impact ended, and why it ended then rather than later.
- Timeline must include or explicitly mark `ISSUE INTRODUCED`, `TRIGGER EVENT`, `IMPACT BEGINS`, `FIRST ALERT`, `INVESTIGATION BEGINS`, `INCIDENT DECLARED`, `IMPACT ENDS`, and `INCIDENT RESOLVED` when the template asks for them.
- Preserve all RespectTables status updates and template instructions.
- SLO Impact should explain both error-budget impact and detection coverage. If alerting/SLOs should have caught the incident but did not, state that gap and link the follow-up Jira macro.
- Detection should identify why expected automation did or did not catch the issue, not just who posted first in the incident room.
- Before finalizing, read the updated report as a human-facing incident report and remove assistant-authored meta phrasing, edit labels, redundant headings, and evidence captions that describe the wrong artifact.

## Verification Checklist

Before reporting completion, verify all of these:

- Jira report-driving fields are populated or explicitly deferred.
- Confluence page version increased.
- Original template placeholders/example rows still exist.
- Added content answers the instructions embedded in each section of the Confluence report.
- Existing draft was audited for direct Chat image URLs, fixed image dimensions, screenshot-only links, plain Jira links, missing required section answers, and already-populated Jira fields before editing.
- Impact explicitly answers `WHO`, `HOW MANY`, `HOW LONG`, and `HOW BAD`.
- SLO Impact explicitly states SLO coverage and known/unknown error-budget burn.
- Detection explicitly states first detection path, first known detection time, and whether expected automated detection fired.
- Timeline includes the critical markers requested by the template or explicitly states which marker is unknown.
- No new structural headings or edit-marker labels were introduced unless explicitly requested.
- Added Jira references are `ac:name="jira"` macros.
- Screenshot attachments are only present when a screenshot is the best evidence format.
- Images are attached to the page when images are used.
- Images are embedded inline near the relevant section when images are used.
- Embedded screenshots show the underlying evidence, not merely Chat messages or links to evidence, unless Chat itself is the evidence.
- Screenshots are not reused across sections unless each reuse is specifically justified by the section text.
- Inline image storage has no hard-coded size or thumbnail attributes.
- Inline image storage uses attachment references such as `ri:attachment` when possible, not stale hard-coded download URLs.
- If Confluence normalized `ri:attachment` to an attachment download URL in storage read-back, verify it still points to a current page attachment and has no sizing attributes.
- There are no screenshot-only Chat links unless the user asked to keep them.
- Google Chat screenshots are not used where a graph image, table, or quote would represent the evidence better.
- Any uploaded-but-no-longer-embedded cleanup artifacts are reported explicitly, and the user is asked before deleting attachments.
- SLO Impact covers both error-budget status and any SLO/alerting detection gap.
- Detection explains the actual detection path and why expected automated detection did or did not fire.
- The report has passed a human-readability pass: no assistant meta language, no edit-state labels, no awkward structure, and no misleading evidence captions.
- Browser-rendered Confluence page was checked after storage/REST edits: Jira macros render cleanly, images are visible inline, and issue titles are not duplicated around macros.
- Any preserved stale rows/placeholders or uploaded-but-unused attachments are explicitly reported to the user instead of silently deleted.
- Markdown read-back and storage read-back both look reasonable.

### Storage Verification Pattern

After every Confluence storage update, run a targeted verification against the storage body. At minimum check:

- Page version increased.
- `body.includes('https://chat.google.com/api/get_attachment_url')` is false unless the user explicitly asked to keep a Chat source link.
- Counts for `ac:width`, `ac:height`, `width=`, `height=`, and `ac:thumbnail` are zero for inline images.
- Jira issue references added by the agent appear as `ac:name="jira"` macros.
- Required section phrases or section-specific answer markers are present.
- Attachment metadata confirms every embedded attachment exists on the page.

Example browser REST verification snippet:

```js
async () => {
  const pageId = '123456789';
  const res = await fetch(`/rest/api/content/${pageId}?expand=body.storage,version`, { credentials: 'include' });
  const page = await res.json();
  const body = page.body.storage.value;
  return {
    version: page.version.number,
    hasChatImageUrl: body.includes('https://chat.google.com/api/get_attachment_url'),
    widthAttrCount: (body.match(/\s(?:ac:)?width="/g) || []).length,
    heightAttrCount: (body.match(/\s(?:ac:)?height="/g) || []).length,
    thumbnailAttrCount: (body.match(/thumbnail=/g) || []).length,
    jiraMacroCount: (body.match(/ac:name="jira"/g) || []).length,
    imageCount: (body.match(/<ac:image\b|<img\b/g) || []).length,
  };
}
```
