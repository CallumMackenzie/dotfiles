import { spawn } from "node:child_process";
import { readFile, rename, writeFile } from "node:fs/promises";
import { homedir } from "node:os";
import { join } from "node:path";
import { definePluginEntry } from "openclaw/plugin-sdk/plugin-entry";

const SAFE_SESSION_KEY = /^[A-Za-z0-9_.-]+$/;
const SAFE_PANE_ID = /^%\d+$/;

type PaneMapping = {
  pane?: unknown;
  socket?: unknown;
  tmuxSessionId?: unknown;
  status?: unknown;
  updatedAt?: unknown;
};

type OpenClawStatus = "progressing" | "finished" | "stopped";

function mappingPathForSession(sessionKey: string): string {
  return join(
    homedir(),
    ".local",
    "state",
    "openclaw-tmux",
    `${sessionKey}.json`,
  );
}

async function readMapping(mappingPath: string): Promise<PaneMapping | null> {
  try {
    return JSON.parse(await readFile(mappingPath, "utf8")) as PaneMapping;
  } catch {
    // Sessions not launched through `oc` intentionally have no mapping.
    return null;
  }
}

async function setStatus(
  mappingPath: string,
  mapping: PaneMapping,
  status: OpenClawStatus,
): Promise<void> {
  const temporaryPath = `${mappingPath}.${process.pid}.${Date.now()}.tmp`;
  await writeFile(
    temporaryPath,
    `${JSON.stringify({ ...mapping, status, updatedAt: Date.now() })}\n`,
    { mode: 0o600 },
  );
  await rename(temporaryPath, mappingPath);
}

function sessionKeyFromCanonical(canonicalSessionKey: string | undefined) {
  const sessionKey = canonicalSessionKey?.split(":").at(-1);
  return sessionKey && SAFE_SESSION_KEY.test(sessionKey) ? sessionKey : null;
}

export default definePluginEntry({
  id: "openclaw-tmux-notify",
  name: "OpenClaw tmux notifications",
  description: "Routes completed OpenClaw turns to their originating tmux pane.",
  register(api) {
    api.on("before_agent_run", async (_event, ctx) => {
      const sessionKey = sessionKeyFromCanonical(ctx.sessionKey);
      if (!sessionKey) return;

      const mappingPath = mappingPathForSession(sessionKey);
      const mapping = await readMapping(mappingPath);
      if (!mapping) return;

      await setStatus(mappingPath, mapping, "progressing");
    });

    api.on("agent_end", async (event, ctx) => {
      const sessionKey = sessionKeyFromCanonical(ctx.sessionKey);
      if (!sessionKey) return;

      const mappingPath = mappingPathForSession(sessionKey);
      const mapping = await readMapping(mappingPath);
      if (!mapping) return;

      await setStatus(mappingPath, mapping, event.success ? "finished" : "stopped");

      if (typeof mapping.pane !== "string" || !SAFE_PANE_ID.test(mapping.pane)) {
        return;
      }
      if (typeof mapping.socket !== "string" || !mapping.socket.startsWith("/")) {
        return;
      }

      const notifier = join(homedir(), ".local", "bin", "tmux-notify-jump");
      const success = event.success;
      const child = spawn(
        notifier,
        [
          "--tmux-socket",
          mapping.socket,
          "--target",
          mapping.pane,
          "--title",
          success ? "OpenClaw finished" : "OpenClaw failed",
          "--body",
          sessionKey,
          "--notify-kind",
          success ? "complete" : "attention",
          "--detach",
        ],
        {
          detached: true,
          stdio: "ignore",
        },
      );
      child.unref();
    });
  },
});
