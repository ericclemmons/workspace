import { spawnSync } from "node:child_process"
import { dirname, resolve } from "node:path"
import { fileURLToPath } from "node:url"

const repoRoot = resolve(dirname(fileURLToPath(import.meta.url)), "../..")

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

function runGuard(script, payload, cwd = process.cwd()) {
  const result = spawnSync(resolve(repoRoot, ".githooks", script), [], {
    cwd,
    input: JSON.stringify(payload),
    encoding: "utf8",
  })

  if (result.status === 0) return result.stdout

  let reason = result.stderr.trim() || result.stdout.trim() || `${script} failed`
  try {
    reason = JSON.parse(reason).reason ?? reason
  } catch {}
  throw new Error(reason)
}

function commandCwd(args) {
  if (typeof args?.workdir !== "string" || args.workdir.length === 0) return process.cwd()
  return args.workdir.startsWith("/") ? args.workdir : resolve(process.cwd(), args.workdir)
}

export default async () => ({
  "tool.execute.before": async (input) => {
    const name = toolName(input).toLowerCase()
    const args = toolArgs(input)

    if (name === "edit" || name === "write") {
      runGuard("agent-guard-edit.sh", { tool_input: args })
      return
    }

    if (name === "bash") {
      runGuard("agent-guard-bash.sh", { tool_input: args }, commandCwd(args))
    }
  },
})
