import { spawn } from "node:child_process";
import { readdir, readFile, rename, writeFile } from "node:fs/promises";
import { homedir } from "node:os";
import { join } from "node:path";
import { definePluginEntry } from "openclaw/plugin-sdk/plugin-entry";

const SAFE_SESSION_KEY = /^[A-Za-z0-9_.-]+$/;
const SAFE_PANE_ID = /^%\d+$/;
const NOTIFICATION_PREVIEW_LENGTH = 120;

type PaneMapping = {
  pane?: unknown;
  socket?: unknown;
  tmuxSessionId?: unknown;
  tmuxSessionName?: unknown;
  status?: unknown;
  updatedAt?: unknown;
};

type OpenClawStatus = "progressing" | "finished" | "stopped";

function textFromAssistantMessage(message: unknown): string | null {
  if (!message || typeof message !== "object") return null;

  const candidate = message as { role?: unknown; content?: unknown };
  if (candidate.role !== "assistant") return null;
  if (typeof candidate.content === "string") return candidate.content;
  if (!Array.isArray(candidate.content)) return null;

  const text = candidate.content
    .filter(
      (block): block is { type: "text"; text: string } =>
        Boolean(block) &&
        typeof block === "object" &&
        (block as { type?: unknown }).type === "text" &&
        typeof (block as { text?: unknown }).text === "string",
    )
    .map((block) => block.text)
    .join("\n");
  return text || null;
}

function notificationPreview(messages: unknown[], fallback: string): string {
  let response: string | null = null;
  for (let index = messages.length - 1; index >= 0; index -= 1) {
    response = textFromAssistantMessage(messages[index]);
    if (response) break;
  }

  const normalized = (response ?? fallback).replace(/\s+/g, " ").trim();
  const characters = Array.from(normalized);
  if (characters.length <= NOTIFICATION_PREVIEW_LENGTH) return normalized;
  return `${characters.slice(0, NOTIFICATION_PREVIEW_LENGTH - 1).join("")}…`;
}

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

function belongsToSameTui(left: PaneMapping, right: PaneMapping): boolean {
  return (
    typeof left.pane === "string" &&
    left.pane === right.pane &&
    typeof left.socket === "string" &&
    left.socket === right.socket &&
    typeof left.tmuxSessionId === "string" &&
    left.tmuxSessionId === right.tmuxSessionId
  );
}

async function setStatusForAliases(
  mappingPath: string,
  mapping: PaneMapping,
  status: OpenClawStatus,
): Promise<void> {
  const stateDirectory = join(homedir(), ".local", "state", "openclaw-tmux");
  let names: string[];
  try {
    names = await readdir(stateDirectory);
  } catch {
    names = [];
  }

  let updatedCanonicalMapping = false;
  for (const name of names) {
    if (!name.endsWith(".json")) continue;
    const candidatePath = join(stateDirectory, name);
    const candidate = await readMapping(candidatePath);
    if (!candidate || !belongsToSameTui(candidate, mapping)) continue;
    await setStatus(candidatePath, candidate, status);
    updatedCanonicalMapping ||= candidatePath === mappingPath;
  }

  if (!updatedCanonicalMapping) {
    await setStatus(mappingPath, mapping, status);
  }
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
    api.on("session_end", async (event) => {
      const sessionKey = sessionKeyFromCanonical(event.sessionKey);
      const nextSessionKey = sessionKeyFromCanonical(event.nextSessionKey);
      if (!sessionKey || !nextSessionKey || sessionKey === nextSessionKey) return;

      const mappingPath = mappingPathForSession(sessionKey);
      const mapping = await readMapping(mappingPath);
      if (!mapping) return;

      // The TUI can replace its session in-place with /new or /reset while the
      // shell process and tmux pane stay the same. Carry the pane association
      // forward so lifecycle hooks continue to resolve the new canonical key.
      await setStatus(mappingPath, mapping, "stopped");
      await setStatus(
        mappingPathForSession(nextSessionKey),
        mapping,
        "stopped",
      );
    });

    // llm_input is available to locally loaded plugins and fires as soon as a
    // model turn actually starts. Keep every alias for an in-place /new or
    // /reset in sync so an old finished alias cannot pin the bar green.
    api.on("llm_input", async (_event, ctx) => {
      const sessionKey = sessionKeyFromCanonical(ctx.sessionKey);
      if (!sessionKey) return;

      const mappingPath = mappingPathForSession(sessionKey);
      const mapping = await readMapping(mappingPath);
      if (!mapping) return;

      await setStatusForAliases(mappingPath, mapping, "progressing");
    });

    api.on("agent_end", async (event, ctx) => {
      const sessionKey = sessionKeyFromCanonical(ctx.sessionKey);
      if (!sessionKey) return;

      const mappingPath = mappingPathForSession(sessionKey);
      const mapping = await readMapping(mappingPath);
      if (!mapping) return;

      await setStatusForAliases(
        mappingPath,
        mapping,
        event.success ? "finished" : "stopped",
      );

      if (typeof mapping.pane !== "string" || !SAFE_PANE_ID.test(mapping.pane)) {
        return;
      }
      if (typeof mapping.socket !== "string" || !mapping.socket.startsWith("/")) {
        return;
      }
      if (
        typeof mapping.tmuxSessionName !== "string" ||
        mapping.tmuxSessionName.length === 0
      ) {
        return;
      }

      const notifier = join(homedir(), ".local", "bin", "tmux-notify-jump");
      const success = event.success;
      const body = notificationPreview(
        event.messages,
        event.error ?? (success ? "Turn finished." : "Turn failed."),
      );
      const child = spawn(
        notifier,
        [
          "--tmux-socket",
          mapping.socket,
          "--target",
          mapping.pane,
          "--title",
          `openclaw ${mapping.tmuxSessionName}`,
          "--body",
          body,
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
