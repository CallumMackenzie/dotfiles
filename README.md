# dotfiles

Declarative macOS configuration for Zsh, Neovim, tmux, Hammerspoon, WezTerm,
Git, Vimium C, and the local OpenClaw tmux-completion integration. Nix Darwin
and Home Manager are the primary restoration path; the legacy bootstrap remains
temporarily available as a pre-Nix fallback.

## What is tracked

- `zsh/` — interactive and login-shell configuration
- `nvim/` — Neovim configuration, plugin lockfile, and cheatsheet
- `tmux/` — tmux configuration and completion-inbox binding
- `wezterm/` — terminal configuration and background asset
- `hammerspoon/` — application launcher shortcuts
- `git/` — Git defaults
- `vimium-c/` — browser extension export
- `openclaw/plugins/` — local OpenClaw completion hook
- `python/` — direct Python dependencies for Neovim notebooks
- `Brewfile` — command-line and application dependencies
- `scripts/bootstrap.sh` — conservative fresh-machine bootstrap
- `flake.nix` / `flake.lock` — pinned Nix entry point and dependencies
- `hosts/` — per-Mac configuration
- `modules/` — nix-darwin, Home Manager, and Homebrew modules

## Nix restoration

Install the signed Determinate Nix package from:

<https://install.determinate.systems/determinate-pkg/stable/Universal>

Then clone this repository and perform the first activation:

```sh
sudo nix run nix-darwin -- switch --flake .#MacBook-Pro
```

Subsequent activations use the installed command:

```sh
sudo darwin-rebuild switch --flake .#MacBook-Pro
```

The configuration declaratively manages:

- CLI packages and language runtimes through Nix
- WezTerm and Hammerspoon through declarative Homebrew casks
- Zsh, Git, tmux, Neovim, WezTerm, Hammerspoon, and OpenClaw plugin links
- Neovim's Python/Jupyter environment
- the pinned `tmux-notify-jump` source
- selected keyboard, Dock, and Finder preferences

OpenClaw itself remains externally installed because its current release can
move ahead of Nixpkgs. Home Manager registers and enables the tracked plugin
when an `openclaw` executable is present. Restart the OpenClaw Gateway after an
activation that changes the plugin.

The host name in this flake is `MacBook-Pro`. Add another directory under
`hosts/` and another `darwinConfigurations` entry for additional Macs.

## Legacy bootstrap

Install Homebrew, clone this repository anywhere, then run:

```sh
./scripts/bootstrap.sh
```

The bootstrap script:

1. Installs packages from `Brewfile`.
2. Creates symlinks for the tracked configuration files.
3. Creates an empty mode-`600` `~/.zshrc.private` when one is absent.
4. Installs the pinned `tmux-notify-jump` revision.
5. Creates `~/.venvs/neovim` and installs its direct Python dependencies.
6. Links and enables the OpenClaw tmux notification plugin when OpenClaw is
   already installed.

It refuses to replace existing configuration paths. Move or back up old files
before running it on a machine that already has dotfiles.

OpenClaw itself is intentionally not installed by this bootstrap script. If it
is installed later, rerun the script to register the tracked local plugin, then
restart the Gateway.

## Private configuration

Machine-private shell settings belong in `~/.zshrc.private`. The tracked
`.zshrc` loads it automatically, but its contents must never be committed.
Use macOS Keychain or another protected secret store for credentials whenever
possible; a mode-`600` shell file is still plaintext.

The following state is intentionally excluded:

- `~/.zshrc.private`
- OpenClaw's main configuration, credentials, sessions, and pane mappings
- GitHub and cloud-provider authentication files
- downloaded plugins, caches, logs, and application runtime state

## OpenClaw tmux notifications

Launch a TUI with `oc` from inside tmux. The launcher derives a stable session
name from the tmux session, window, and pane and records the originating pane.
When a turn finishes, the tracked OpenClaw hook calls `tmux-notify-jump`.

Expected behavior:

- macOS shows an `openclaw <tmux-session>` notification whose body previews
  the first 120 characters of the final assistant response. Responses whose
  normalized body is exactly `NO_REPLY` do not create a notification.
- Clicking the notification returns to the originating WezTerm/tmux pane.
- Background completions appear in tmux's inbox.
- `Prefix + N` jumps to the next pane needing attention.
- WezTerm shows every local tmux session in its status strip, including while
  the active terminal is inside tmux. Each mapped OpenClaw pane gets an icon:
  pink `✓` means a finished turn has an unread notification, green `✓` means
  the finished pane has been viewed, orange `●` means a turn is running, and
  gray `○` means no OpenClaw mapping exists, the TUI stopped, or its last turn
  failed. For example, `● ✓ env` means one pane is running and another has
  finished. A session name is pink while any finished pane has an unread
  notification. `Prefix + N` jumps to the next unread notification, changing
  its pink check and session name to green when the destination pane is selected.

The session name uses the aggregate color. A progressing OpenClaw pane takes
priority over an unread pane, which takes priority over viewed finished and
stopped panes. The session attached to the current WezTerm pane is underlined;
windows without an attached tmux client have no underlined session. Existing
TUIs must be relaunched with `oc` once after installing this configuration so
their mappings include the tmux session identifier.

Allow `terminal-notifier` under **System Settings → Notifications**. Automatic
inside-tmux detection and pane routing are local-machine features.

## Neovim

Plugins restore automatically through `lazy.nvim` and `lazy-lock.json`.
Notebook support uses the `neovim` Python environment created by the bootstrap
script. LaTeX and terminal PDF previewing depend on Tectonic, Ghostscript, and
ImageMagick from the `Brewfile`.

## Vimium C

Import `vimium-c/settings.json` through Vimium C's **Backup and Restore** page.

## Validation

Useful checks after restoration:

```sh
zsh -n ~/.zshrc ~/.zprofile
tmux source-file ~/.tmux.conf
openclaw config validate
openclaw plugins list
```

Evaluate the complete Darwin configuration without activating it:

```sh
nix eval .#darwinConfigurations.MacBook-Pro.config.system.build.toplevel.drvPath
```

The `Brewfile`, Python requirements, and bootstrap script remain only as a
rollback path until the first successful Nix activation. They can be removed
after that activation has been verified across a reboot.
