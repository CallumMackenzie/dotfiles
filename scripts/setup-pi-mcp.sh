#!/usr/bin/env bash
set -euo pipefail
pi_dir="${1:?pass the pi/ source directory}"
agent_dir="$HOME/.pi/agent"
titan_dir="$HOME/.local/share/pi-mcp/titan"
mkdir -p "$agent_dir" "$titan_dir"
chmod 700 "$agent_dir" "$titan_dir"
if [[ ! -e "$agent_dir/mcp.json" ]]; then
  install -m 600 "$pi_dir/mcp.json.example" "$agent_dir/mcp.json"
fi
# Titan resolves npm dependencies relative to the physical server.mjs file.
install -m 700 "$pi_dir/mcp/titan/server.mjs" "$titan_dir/server.mjs"
install -m 600 "$pi_dir/mcp/titan/package.json" "$titan_dir/package.json"
if ! cmp -s "$pi_dir/mcp/titan/package-lock.json" "$titan_dir/package-lock.json" || [[ ! -d "$titan_dir/node_modules" ]]; then
  install -m 600 "$pi_dir/mcp/titan/package-lock.json" "$titan_dir/package-lock.json"
  npm ci --prefix "$titan_dir" --ignore-scripts --no-audit --no-fund
fi
printf 'Pi MCP files installed. Supply Keychain items pi-titan-imap, pi-leetcode-session and pi-course-tracker-mcp and the Google service-account file separately.\n'
