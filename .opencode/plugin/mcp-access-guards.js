function toolName(input) {
  if (typeof input?.tool === "string") return input.tool
  if (typeof input?.tool?.name === "string") return input.tool.name
  if (typeof input?.name === "string") return input.name
  if (typeof input?.toolName === "string") return input.toolName
  return ""
}

function toolArgs(input) {
  return input?.args ?? input?.input ?? input?.tool_input ?? {}
}

function normalizedToolName(input) {
  return toolName(input).toLowerCase().replace(/[^a-z0-9]/g, "")
}

function candidateUrl(args) {
  if (typeof args?.url === "string") return args.url
  if (typeof args?.uri === "string") return args.uri
  if (typeof args === "string") return args
  return ""
}

function cleanSegments(pathname) {
  return pathname.split("/").filter(Boolean).map((segment) => decodeURIComponent(segment))
}

function repoNameFromPath(repoPath) {
  return repoPath.split("/").at(-1)?.replace(/\.git$/, "") ?? "repo"
}

function shellQuote(value) {
  if (/^[A-Za-z0-9_./:@+-]+$/.test(value)) return value
  return `'${value.replace(/'/g, `'"'"'`)}'`
}

function gitSourceGuidance(value) {
  if (!value) return null

  let url
  try {
    url = new URL(value)
  } catch {
    return null
  }

  const host = url.hostname.toLowerCase()
  const segments = cleanSegments(url.pathname)
  let repoPath = ""
  let filePath = ""

  if (host === "raw.githubusercontent.com") {
    if (segments.length < 3) return null
    repoPath = `${segments[0]}/${segments[1]}`
    filePath = segments.slice(3).join("/")
  } else if (host === "github.com" || host.endsWith(".github.com")) {
    if (segments.length < 2) return null
    repoPath = `${segments[0]}/${segments[1]}`
    const marker = segments.findIndex((segment) => segment === "blob" || segment === "raw")
    if (marker >= 0) {
      filePath = segments.slice(marker + 2).join("/")
    }
  } else if (host.includes("gitlab")) {
    const marker = segments.indexOf("-")
    if (marker < 1) return null
    repoPath = segments.slice(0, marker).join("/")
    const kind = segments[marker + 1]
    if (kind === "raw" || kind === "blob") {
      filePath = segments.slice(marker + 3).join("/")
    }
  } else {
    return null
  }

  if (!repoPath) return null

  const repoName = repoNameFromPath(repoPath)
  const remote = `git@${host}:${repoPath}.git`
  const addCommand = ["mise", "run", "add", repoName, remote].map(shellQuote).join(" ")
  const localPath = filePath ? `repos/${repoName}/${filePath}` : `repos/${repoName}`

  return (
    "Do not use WebFetch for GitHub/GitLab repository content. " +
    `Clone the repo into this workspace and inspect it locally instead: \`${addCommand}\`, ` +
    `then read \`${localPath}\` from the default branch. ` +
    "If you need an isolated task branch after adding the repo, run `mise run branch <task> <repo>` and work under `worktrees/<task>/<repo>/`."
  )
}

const mcpOnlyHosts = [
  /(^|\.)atlassian\.net$/,
  /(^|\.)jira\.com$/,
  /(^|\.)confluence\.com$/,
  /(^|\.)cfdata\.org$/,
  /(^|\.)cloudflareaccess\.com$/,
  /(^|\.)cloudflare\.com$/,
  /^mail\.google\.com$/,
  /^calendar\.google\.com$/,
  /^chat\.google\.com$/,
  /^drive\.google\.com$/,
  /^docs\.google\.com$/,
  /^sheets\.google\.com$/,
  /^slides\.google\.com$/,
  /^forms\.gle$/,
]

function isMcpOnlyUrl(value) {
  if (!value) return false

  try {
    const url = new URL(value)
    return mcpOnlyHosts.some((pattern) => pattern.test(url.hostname.toLowerCase()))
  } catch {
    const lower = value.toLowerCase()
    return [
      "atlassian",
      "jira",
      "confluence",
      "cfdata.org",
      "cloudflareaccess",
      "mail.google.com",
      "calendar.google.com",
      "chat.google.com",
      "drive.google.com",
      "docs.google.com",
      "sheets.google.com",
      "slides.google.com",
      "forms.gle",
    ].some((needle) => lower.includes(needle))
  }
}

export default async () => ({
  "tool.execute.before": async (input) => {
    const name = normalizedToolName(input)
    if (name !== "webfetch") return

    const url = candidateUrl(toolArgs(input))
    const gitGuidance = gitSourceGuidance(url)
    if (gitGuidance) throw new Error(gitGuidance)

    if (!isMcpOnlyUrl(url)) return

    throw new Error(
      "Use MCP tools for this authenticated resource instead of WebFetch. " +
        "Run `opencode mcp list`; if cf-portal auth is stale, run `opencode mcp auth cf-portal`, then reconnect via `/mcp` if needed."
    )
  },
})
