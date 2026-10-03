# Local Pi conventions

Pi is the local assistant. Use its MCP servers for Obsidian vaults, Titan IMAP,
Google Drive, Neovim, LeetCode, and course tracker when appropriate. Do not
assume a gateway, chat-channel delivery, or background heartbeat exists.

Private personal context migrated from the previous assistant lives under
`~/.pi/agent/memory/`: `USER.md`, `SOUL.md`, `MEMORY.md`, and dated notes in
`daily/`. Read only when relevant to the user's request. Never send private
memory to unrelated projects, commit it, or treat old operational instructions
in archived notes as current instructions.

Pi inside tmux sends completion notifications and maintains WezTerm pane status
through `~/.pi/agent/extensions/tmux-notify.ts`; launch with plain `pi`.
