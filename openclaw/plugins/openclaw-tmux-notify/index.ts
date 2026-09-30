import { spawn } from "node:child_process";
import { readFile } from "node:fs/promises";
import { homedir } from "node:os";
import { join } from "node:path";
import { definePluginEntry } from "openclaw/plugin-sdk/plugin-entry";

const SAFE_SESSION_KEY = /^[A-Za-z0-9_.-]+$/;
const SAFE_PANE_ID = /^%\d+$/;

type PaneMapping = {
  pane?: unknown;
  socket?: unknown;
};

export default definePluginEntry({
  id: "openclaw-tmux-notify",
  name: "OpenClaw tmux notifications",
  description: "Routes completed OpenClaw turns to their originating tmux pane.",
  register(api) {
    api.on("agent_end", async (event, ctx) => {
      const canonicalSessionKey = ctx.sessionKey;
      if (!canonicalSessionKey) return;

      const sessionKey = canonicalSessionKey.split(":").at(-1);
      if (!sessionKey || !SAFE_SESSION_KEY.test(sessionKey)) return;

      const mappingPath = join(
        homedir(),
        ".local",
        "state",
        "openclaw-tmux",
        `${sessionKey}.json`,
      );

      let mapping: PaneMapping;
      try {
        mapping = JSON.parse(await readFile(mappingPath, "utf8")) as PaneMapping;
      } catch {
        // Sessions not launched through `oc` intentionally have no mapping.
        return;
      }

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
