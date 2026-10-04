# dotfiles

Declarative macOS configuration for Zsh, Neovim, tmux, Hammerspoon, WezTerm,
Git, Vimium C, and Pi. Nix Darwin and Home Manager are the primary restoration
path; the legacy bootstrap remains available as a pre-Nix fallback.

## What is tracked

- `zsh/`, `nvim/`, `tmux/`, `wezterm/`, `hammerspoon/`, `git/`, `vimium-c/`
- `pi/AGENTS.md`, `pi/extensions/{tmux-notify,ascii-splash}.ts`, `pi/model-defaults.json`
- `pi/mcp.json.example` and `pi/mcp/` — non-secret MCP configuration and server code
- `scripts/pi-tmux-status` — per-pane Pi status for WezTerm
- `python/`, `Brewfile`, `scripts/bootstrap.sh`, `flake.nix`, `hosts/`, `modules/`

## Nix restoration

Install the signed Determinate Nix package from
<https://install.determinate.systems/determinate-pkg/stable/Universal>, clone
this repository, then:

```sh
sudo nix run nix-darwin -- switch --flake .#MacBook-Pro
# later activations:
sudo darwin-rebuild switch --flake .#MacBook-Pro
```

Pi itself is installed separately. Home Manager links the Pi extensions,
user instructions, MCP wrapper scripts and status helper, merges model defaults
into Pi's existing settings (without replacing installed packages/device ID),
and installs the Titan MCP dependency tree. `gpt-5.6-sol` remains available for
manual model switching; Pi does not use OpenClaw's automatic fallback chain. `~/.pi/agent/mcp.json` is created
from the example only when absent and is never replaced; edit it locally.
The host name in this flake is `MacBook-Pro`. Add a new host configuration for
additional Macs.

## Legacy bootstrap

Install Homebrew, clone anywhere and run `./scripts/bootstrap.sh`.
It installs `Brewfile`, links configuration conservatively (refuses to replace
existing paths), installs pinned `tmux-notify-jump`, creates private zsh config,
sets up the Neovim Python environment, and configures Pi files and MCP servers.
Pi itself must be installed separately.

## Pi splash

`pi/extensions/ascii-splash.ts` replaces Pi's startup header with an animated
ASCII logo. Its moving Voronoi color regions follow the active light/dark theme;
the timer stops when the session closes. In terminals narrower than 72 columns,
it shows a compact `C1` instead.

## Pi and tmux notifications

Launch **plain `pi`** in a tmux pane. The Pi extension detects `TMUX_PANE`,
records the tmux socket/session/pane under `~/.local/state/pi-tmux/` and marks
runs progressing, finished or stopped. It sends the last response preview
(120 characters, suppressing `NO_REPLY`) via `tmux-notify-jump` only after Pi
has fully settled, not between retries or follow-ups. Failed runs receive an
attention notification. Exit, abort and session shutdown clear the running
status. Launches outside tmux and headless Pi runs are not tracked.

- Clicking a macOS notification jumps to the originating WezTerm/tmux pane.
- Background completions enter the tmux inbox; `Prefix + N` jumps to the next.
- WezTerm shows every tmux session. Orange `●` is progressing, pink `✓` is
  finished with unread notification, green `✓` is viewed, and gray `○` is
  stopped/unmapped. The current attached session is underlined.
- Allow Homebrew `terminal-notifier` under **System Settings → Notifications**.
  Pi explicitly prefers `/opt/homebrew/bin` when calling the notifier: the
  older Nix `terminal-notifier` 2.0 uses a legacy macOS notification API that
  macOS rejects when the newer Homebrew app has the same bundle ID.

Do **not** install the separate upstream `tmux-notify-jump` Pi extension as
well: it would deliver duplicate notifications. The upstream notifier binary
and tmux inbox configuration are reused here.

## Private configuration and MCP

`~/.zshrc.private`, `~/.pi/agent/mcp.json`, `~/.pi/agent/auth.json`,
`~/.pi/agent/memory/`, `~/.config/pi/credentials/`, Pi sessions, Keychain
passwords and runtime state must never be committed. Tracked MCP files contain
only non-secret code and an example config. The example config defines:

- `obsidian-notes`, `obsidian-jobsearch`, `obsidian-content` (`mcpvault`)
- `google-drive` (compatibility adapter; service-account JSON at
  `~/.config/pi/credentials/google-service-account.json`)
- `titan-imap` (local Node server; password in Keychain service `pi-titan-imap`
  with account `callum@camackenzie.com`)
- `mcp-neovim-server` (`/tmp/nvim.sock`, shell commands disallowed)
- `leetcode` (Keychain service `pi-leetcode-session`, account `pi`)
- `course-tracker` (Keychain service `pi-course-tracker-mcp`, account `callum`;
  only four read-only assessment/schedule tools exposed)

On a new machine install credentials separately (never place secrets in the
repo), then run `pi mcp list` or `/mcp` to inspect connections. MCP tools use
Pi's default `codemode` exposure except for the filtered course tracker.
There is no gateway, messaging channel, heartbeat or model-embedding memory
service. The previous assistant's personal memory can be kept privately under
`~/.pi/agent/memory/` and read only when relevant; it is not a Pi session.

## Other applications

Neovim plugins restore via `lazy.nvim` and `lazy-lock.json`; its Python/Jupyter
environment is provided by Nix or the bootstrap. LaTeX/PDF preview uses
Tectonic, Ghostscript and ImageMagick. Import `vimium-c/settings.json` through
Vimium C's **Backup and Restore** page.

## Validation

```sh
zsh -n ~/.zshrc ~/.zprofile
bash -n scripts/*.sh
pi mcp list
tmux source-file ~/.tmux.conf
~/.local/bin/pi-tmux-status
darwin-rebuild switch --flake .#MacBook-Pro
```

`Brewfile`, Python requirements, and bootstrap remain a rollback path until a
Nix activation has been verified across a reboot.
