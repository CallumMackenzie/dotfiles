#!/usr/bin/env node
import { spawn } from "node:child_process";
import { createInterface } from "node:readline";

const child = spawn("npx", ["-y", "mcp-google-drive@1.6.2"], {
  env: process.env,
  stdio: ["pipe", "pipe", "pipe"],
});

const toolCallIds = new Set();

const clientLines = createInterface({
  input: process.stdin,
  crlfDelay: Infinity,
});

clientLines.on("line", (line) => {
  if (!line.trim()) {
    child.stdin.write(`${line}\n`);
    return;
  }

  try {
    const message = JSON.parse(line);
    if (message.method === "tools/call" && message.id !== undefined) {
      toolCallIds.add(String(message.id));
    }
  } catch {
    // Forward non-JSON exactly as received.
  }

  child.stdin.write(`${line}\n`);
});

clientLines.on("close", () => {
  child.stdin.end();
});

const serverLines = createInterface({
  input: child.stdout,
  crlfDelay: Infinity,
});

serverLines.on("line", (line) => {
  if (!line.trim()) {
    process.stdout.write(`${line}\n`);
    return;
  }

  try {
    const message = JSON.parse(line);
    const id = message.id === undefined ? undefined : String(message.id);

    if (id !== undefined && toolCallIds.has(id)) {
      toolCallIds.delete(id);
      if (message.result && !Array.isArray(message.result.content)) {
        message.result = {
          content: [
            {
              type: "text",
              text: JSON.stringify(message.result, null, 2),
            },
          ],
          isError: false,
        };
      }
    }

    process.stdout.write(`${JSON.stringify(message)}\n`);
  } catch {
    process.stdout.write(`${line}\n`);
  }
});

child.stderr.pipe(process.stderr);

child.on("exit", (code, signal) => {
  if (signal) {
    process.kill(process.pid, signal);
    return;
  }
  process.exit(code ?? 0);
});

process.on("SIGINT", () => child.kill("SIGINT"));
process.on("SIGTERM", () => {
  child.kill("SIGTERM");
  setTimeout(() => process.exit(143), 1000).unref();
});
