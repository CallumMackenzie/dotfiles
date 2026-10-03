#!/usr/bin/env node
import { execFile } from "node:child_process";
import { createInterface } from "node:readline";
import { promisify } from "node:util";
import { ImapFlow } from "imapflow";
import { simpleParser } from "mailparser";

const execFileAsync = promisify(execFile);

const SERVER_NAME = "titan-imap-mcp";
const SERVER_VERSION = "0.1.0";

function env(name, fallback = undefined) {
  const value = process.env[name];
  return value === undefined || value === "" ? fallback : value;
}

async function readKeychainPassword(account) {
  const service = env("TITAN_IMAP_KEYCHAIN_SERVICE", "pi-titan-imap");
  if (!account) return undefined;
  try {
    const { stdout } = await execFileAsync("security", [
      "find-generic-password",
      "-s",
      service,
      "-a",
      account,
      "-w",
    ]);
    return stdout.trim() || undefined;
  } catch {
    return undefined;
  }
}

async function readFileCredentials() {
  const path = env("TITAN_IMAP_CREDENTIALS_JSON");
  if (!path) return {};
  try {
    const fs = await import("node:fs/promises");
    return JSON.parse(await fs.readFile(path, "utf8"));
  } catch {
    return {};
  }
}

async function getConfig() {
  const fileCreds = await readFileCredentials();
  const user =
    env("TITAN_IMAP_USER") ||
    env("TITAN_EMAIL_ADDRESS") ||
    fileCreds.user ||
    fileCreds.email ||
    fileCreds.username;
  const password =
    env("TITAN_IMAP_PASSWORD") ||
    env("IMAP_PASSWORD") ||
    fileCreds.password ||
    (await readKeychainPassword(user));

  return {
    host: env("TITAN_IMAP_HOST", "imap.titan.email"),
    port: Number(env("TITAN_IMAP_PORT", "993")),
    secure: env("TITAN_IMAP_SECURE", "true") !== "false",
    user,
    password,
    keychainService: env("TITAN_IMAP_KEYCHAIN_SERVICE", "pi-titan-imap"),
  };
}

function missingConfig(config) {
  const missing = [];
  if (!config.user) missing.push("TITAN_IMAP_USER or TITAN_EMAIL_ADDRESS");
  if (!config.password) {
    missing.push(
      "Keychain password, TITAN_IMAP_PASSWORD, IMAP_PASSWORD, or TITAN_IMAP_CREDENTIALS_JSON password",
    );
  }
  return missing;
}

async function withClient(fn, { mailbox = "INBOX", readOnly = true } = {}) {
  const config = await getConfig();
  const missing = missingConfig(config);
  if (missing.length) {
    throw new Error(`IMAP credentials are not configured. Missing: ${missing.join(", ")}`);
  }

  const client = new ImapFlow({
    host: config.host,
    port: config.port,
    secure: config.secure,
    auth: {
      user: config.user,
      pass: config.password,
    },
    logger: false,
  });

  await client.connect();
  try {
    if (mailbox) {
      await client.mailboxOpen(mailbox, { readOnly });
    }
    return await fn(client, config);
  } finally {
    await client.logout().catch(() => {});
  }
}

function textResult(value) {
  return {
    content: [
      {
        type: "text",
        text: typeof value === "string" ? value : JSON.stringify(value, null, 2),
      },
    ],
  };
}

function asDate(value) {
  if (!value) return undefined;
  const date = new Date(value);
  if (Number.isNaN(date.getTime())) {
    throw new Error(`Invalid date: ${value}`);
  }
  return date;
}

function buildSearchQuery(args = {}) {
  const mode = args.mode || "all";
  const query = {};
  if (mode === "unread") query.seen = false;
  if (mode === "seen") query.seen = true;
  if (args.from) query.from = args.from;
  if (args.to) query.to = args.to;
  if (args.subject) query.subject = args.subject;
  if (args.since) query.since = asDate(args.since);
  if (args.before) query.before = asDate(args.before);
  return query;
}

function addressList(addresses) {
  return (addresses || [])
    .map((entry) => entry.address || entry.name)
    .filter(Boolean);
}

function envelopeSummary(message) {
  const envelope = message.envelope || {};
  return {
    uid: message.uid,
    flags: [...(message.flags || [])],
    date: envelope.date ? envelope.date.toISOString() : undefined,
    subject: envelope.subject || "",
    from: addressList(envelope.from),
    to: addressList(envelope.to),
    messageId: envelope.messageId,
  };
}

const tools = [
  {
    name: "setup_info",
    description: "Show Titan IMAP server settings and local credential setup status without revealing passwords.",
    inputSchema: {
      type: "object",
      additionalProperties: false,
      properties: {},
    },
  },
  {
    name: "test_connection",
    description: "Test the configured Titan IMAP connection.",
    inputSchema: {
      type: "object",
      additionalProperties: false,
      properties: {},
    },
  },
  {
    name: "list_mailboxes",
    description: "List available IMAP mailboxes/folders.",
    inputSchema: {
      type: "object",
      additionalProperties: false,
      properties: {},
    },
  },
  {
    name: "search_messages",
    description: "Search message envelopes in a mailbox. Returns metadata only, not full bodies.",
    inputSchema: {
      type: "object",
      additionalProperties: false,
      properties: {
        mailbox: { type: "string", default: "INBOX" },
        mode: { type: "string", enum: ["all", "unread", "seen"], default: "all" },
        from: { type: "string" },
        to: { type: "string" },
        subject: { type: "string" },
        since: { type: "string", description: "Date parseable by JavaScript Date, e.g. 2026-06-03." },
        before: { type: "string", description: "Date parseable by JavaScript Date, e.g. 2026-06-04." },
        limit: { type: "integer", minimum: 1, maximum: 100, default: 20 },
      },
    },
  },
  {
    name: "fetch_message",
    description: "Fetch and parse one message by UID from a mailbox opened read-only.",
    inputSchema: {
      type: "object",
      required: ["uid"],
      additionalProperties: false,
      properties: {
        mailbox: { type: "string", default: "INBOX" },
        uid: { type: "integer", minimum: 1 },
        maxBodyChars: { type: "integer", minimum: 200, maximum: 50000, default: 8000 },
      },
    },
  },
];

async function callTool(name, args = {}) {
  if (name === "setup_info") {
    const config = await getConfig();
    const missing = missingConfig(config);
    return textResult({
      host: config.host,
      port: config.port,
      secure: config.secure,
      userConfigured: Boolean(config.user),
      passwordConfigured: Boolean(config.password),
      keychainService: config.keychainService,
      missing,
      keychainCommand: config.user
        ? `security add-generic-password -U -s ${config.keychainService} -a ${config.user} -w '<password>'`
        : `security add-generic-password -U -s ${config.keychainService} -a '<email>' -w '<password>'`,
    });
  }

  if (name === "test_connection") {
    const result = await withClient(async (client, config) => ({
      ok: true,
      host: config.host,
      port: config.port,
      secure: config.secure,
      user: config.user,
      mailbox: client.mailbox
        ? {
            path: client.mailbox.path,
            exists: client.mailbox.exists,
            unseen: client.mailbox.unseen,
          }
        : undefined,
    }));
    return textResult(result);
  }

  if (name === "list_mailboxes") {
    const result = await withClient(async (client) => {
      const boxes = await client.list();
      return boxes.map((box) => ({
        path: box.path,
        delimiter: box.delimiter,
        flags: box.flags,
        listed: box.listed,
        subscribed: box.subscribed,
        specialUse: box.specialUse,
      }));
    }, { mailbox: null });
    return textResult(result);
  }

  if (name === "search_messages") {
    const mailbox = args.mailbox || "INBOX";
    const limit = Math.min(Math.max(Number(args.limit || 20), 1), 100);
    const query = buildSearchQuery(args);
    const result = await withClient(async (client) => {
      const uids = (await client.search(query, { uid: true })).sort((a, b) => b - a).slice(0, limit);
      if (!uids.length) return [];
      const messages = [];
      for await (const message of client.fetch(uids, { uid: true, envelope: true, flags: true }, { uid: true })) {
        messages.push(envelopeSummary(message));
      }
      return messages.sort((a, b) => b.uid - a.uid);
    }, { mailbox, readOnly: true });
    return textResult(result);
  }

  if (name === "fetch_message") {
    const mailbox = args.mailbox || "INBOX";
    const uid = Number(args.uid);
    const maxBodyChars = Math.min(Math.max(Number(args.maxBodyChars || 8000), 200), 50000);
    const result = await withClient(async (client) => {
      const sourceMessage = await client.fetchOne(uid, { uid: true, envelope: true, flags: true, source: true }, { uid: true });
      if (!sourceMessage) throw new Error(`No message found for UID ${uid} in ${mailbox}`);
      const parsed = await simpleParser(sourceMessage.source);
      const body = (parsed.text || parsed.html || "").slice(0, maxBodyChars);
      return {
        ...envelopeSummary(sourceMessage),
        cc: addressList(parsed.cc?.value),
        replyTo: addressList(parsed.replyTo?.value),
        body,
        bodyTruncated: (parsed.text || parsed.html || "").length > maxBodyChars,
        attachments: (parsed.attachments || []).map((attachment) => ({
          filename: attachment.filename,
          contentType: attachment.contentType,
          size: attachment.size,
        })),
      };
    }, { mailbox, readOnly: true });
    return textResult(result);
  }

  throw new Error(`Unknown tool: ${name}`);
}

function send(message) {
  process.stdout.write(`${JSON.stringify(message)}\n`);
}

async function handle(message) {
  if (!message || typeof message !== "object") return;
  if (message.id === undefined) return;

  try {
    if (message.method === "initialize") {
      send({
        jsonrpc: "2.0",
        id: message.id,
        result: {
          protocolVersion: message.params?.protocolVersion || "2024-11-05",
          capabilities: { tools: {} },
          serverInfo: { name: SERVER_NAME, version: SERVER_VERSION },
        },
      });
      return;
    }

    if (message.method === "tools/list") {
      send({ jsonrpc: "2.0", id: message.id, result: { tools } });
      return;
    }

    if (message.method === "tools/call") {
      const result = await callTool(message.params?.name, message.params?.arguments || {});
      send({ jsonrpc: "2.0", id: message.id, result });
      return;
    }

    send({ jsonrpc: "2.0", id: message.id, result: {} });
  } catch (error) {
    send({
      jsonrpc: "2.0",
      id: message.id,
      error: {
        code: -32000,
        message: error instanceof Error ? error.message : String(error),
      },
    });
  }
}

const lines = createInterface({ input: process.stdin, crlfDelay: Infinity });
lines.on("line", (line) => {
  if (!line.trim()) return;
  try {
    void handle(JSON.parse(line));
  } catch (error) {
    send({
      jsonrpc: "2.0",
      id: null,
      error: {
        code: -32700,
        message: error instanceof Error ? error.message : String(error),
      },
    });
  }
});
