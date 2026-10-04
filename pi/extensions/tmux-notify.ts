import { spawn, execFile } from "node:child_process";
import { promisify } from "node:util";
import { createHash } from "node:crypto";
import { mkdir, readFile, rename, unlink, writeFile } from "node:fs/promises";
import { homedir } from "node:os";
import { join } from "node:path";
import type { ExtensionAPI, ExtensionContext } from "@earendil-works/pi-coding-agent";

const exec = promisify(execFile);
const stateDir = join(homedir(), ".local", "state", "pi-tmux");
type Status = "progressing" | "finished" | "stopped";
type Mapping = {
  pane: string;
  socket: string;
  tmuxSessionId: string;
  tmuxSessionName: string;
  owner: number;
  status: Status;
  updatedAt: number;
};

function preview(ctx: ExtensionContext): string {
  const messages = ctx.sessionManager.buildSessionProjection().messages;
  const last = [...messages].reverse().find((m) => m.role === "assistant");
  if (!last || last.role !== "assistant") return "Turn finished.";
  const text = last.content
    .filter((block) => block.type === "text")
    .map((block) => block.text)
    .join("\n")
    .replace(/\s+/g, " ")
    .trim();
  const chars = Array.from(text || "Turn finished.");
  return chars.length <= 120 ? chars.join("") : `${chars.slice(0, 119).join("")}…`;
}

export default function (pi: ExtensionAPI) {
  // This belongs to a TUI process, never a headless sub-agent or print invocation.
  let mapping: Mapping | undefined;
  let mappingPath: string | undefined;
  let outcome: "completed" | "aborted" | "error" = "completed";

  async function update(status: Status): Promise<void> {
    if (!mapping || !mappingPath) return;
    try {
      const current = JSON.parse(await readFile(mappingPath, "utf8")) as Mapping;
      // Never overwrite the mapping of a newer Pi process in the same pane.
      if (current.owner !== process.pid || current.pane !== mapping.pane || current.socket !== mapping.socket) return;
      const next = { ...current, status, updatedAt: Date.now() };
      const temporary = `${mappingPath}.${process.pid}.${Date.now()}.tmp`;
      await writeFile(temporary, `${JSON.stringify(next)}\n`, { mode: 0o600 });
      await rename(temporary, mappingPath);
    } catch (error) {
      console.error("pi-tmux: unable to update status", error);
    }
  }

  pi.on("session_start", async (_event, ctx) => {
    if (ctx.mode !== "tui") return;
    const pane = process.env.TMUX_PANE;
    const socket = process.env.TMUX?.split(",")[0];
    if (!pane || !/^%\d+$/.test(pane) || !socket?.startsWith("/")) return;
    try {
      const { stdout } = await exec("tmux", ["-S", socket, "display-message", "-p", "-t", pane,
        "#{session_id}\t#{session_name}"]);
      const [tmuxSessionId, tmuxSessionName] = stdout.trimEnd().split("\t");
      if (!/^\$\d+$/.test(tmuxSessionId) || !tmuxSessionName) return;
      const socketId = createHash("sha256").update(socket).digest("hex").slice(0, 12);
      mappingPath = join(stateDir, `${socketId}-s${tmuxSessionId.slice(1)}-p${pane.slice(1)}.json`);
      mapping = { pane, socket, tmuxSessionId, tmuxSessionName, owner: process.pid,
        status: "stopped", updatedAt: Date.now() };
      await mkdir(stateDir, { recursive: true, mode: 0o700 });
      await writeFile(mappingPath, `${JSON.stringify(mapping)}\n`, { mode: 0o600 });
    } catch (error) {
      console.error("pi-tmux: unable to register pane", error);
    }
  });

  pi.on("agent_start", async () => { outcome = "completed"; await update("progressing"); });
  pi.on("agent_before_settle", (event) => { outcome = event.outcome; });
  pi.on("agent_settled", async (_event, ctx) => {
    if (!mapping || !mappingPath) return;
    // A superseded process must not send a completion for the new owner.
    let current: Mapping;
    try { current = JSON.parse(await readFile(mappingPath, "utf8")) as Mapping; } catch { return; }
    if (current.owner !== process.pid) return;
    await update(outcome === "completed" ? "finished" : "stopped");
    if (outcome === "aborted") return;
    const body = outcome === "completed" ? preview(ctx) : "Turn failed.";
    if (body === "NO_REPLY") return;
    const child = spawn(join(homedir(), ".local", "bin", "tmux-notify-jump"), [
      "--tmux-socket", mapping.socket, "--target", mapping.pane,
      "--title", mapping.tmuxSessionName, "--body", body,
      "--notify-kind", outcome === "completed" ? "complete" : "attention",
      "--notify-source", "Pi", "--detach",
    ], {
      detached: true,
      stdio: "ignore",
      // Homebrew's modern terminal-notifier is registered with macOS. Nix's
      // older binary uses the same bundle ID but the legacy notification API;
      // macOS usernoted rejects it when both have been used on this machine.
      env: { ...process.env, PATH: `/opt/homebrew/bin:${process.env.PATH ?? "/usr/bin:/bin"}` },
    });
    child.on("error", (error) => console.error("pi-tmux: notifier failed", error));
    child.unref();
  });
  pi.on("session_shutdown", async () => {
    if (!mapping || !mappingPath) return;
    try {
      const current = JSON.parse(await readFile(mappingPath, "utf8")) as Mapping;
      // A newer Pi in this pane may have replaced our entry already.
      if (current.owner === process.pid && current.pane === mapping.pane && current.socket === mapping.socket) {
        await unlink(mappingPath);
      }
    } catch (error) {
      if ((error as NodeJS.ErrnoException).code !== "ENOENT") {
        console.error("pi-tmux: unable to remove pane", error);
      }
    }
    mapping = undefined;
    mappingPath = undefined;
  });
}
