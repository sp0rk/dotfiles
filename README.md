# Dotfiles

Managed with [chezmoi](https://chezmoi.io).

## Managed tools

- Shell
  - **zsh** — Default shell, set automatically on first run.
  - **oh-my-zsh** — Zsh plugin/theme framework.
  - **p10k** — Powerlevel10k prompt theme for zsh.
- CLI
  - **zoxide** — Smarter cd command that learns your most-used directories (replaces `cd`).
  - **eza** — Modern ls replacement with icons, git status, and color (replaces `ls`).
  - **thefuck** — Corrects previous console commands.
  - **tree** — Directory listing in tree format.
  - **tldr** — Simplified man pages with practical examples.
- Apps
  - **kitty** — Terminal emulator.
  - **Lite XL** — Text editor.
  - **espanso** — OS-wide text expander.

## Setup

```sh
sh -c "$(curl -fsLS https://get.chezmoi.io)" -- init --apply --ssh sp0rk
```

`run_onchange_setup.sh` runs automatically when it changes. It installs all managed tools for macOS and Linux, symlinks the repo git hook, sets the default shell to zsh, and sets git/chezmoi editors to `lite-xl`.

On macOS, packages are installed with Homebrew where available. Lite XL is installed from the latest official GitHub DMG into `~/Applications`. On Linux, apt is used for packaged tools, and Lite XL is installed from the latest official GitHub tarball into `~/.local`.

## Device-specific configuration

Following files are created empty by chezmoi and never overwritten. Edit them directly on each device:

| File | Purpose |
|------|---------|
| `~/.config/zsh/pre.local.zsh` | Sourced at the start of `.zshrc` |
| `~/.config/zsh/secrets.local` | Sourced near the start of `.zshrc` with auto-export enabled for local secrets |
| `~/.config/zsh/post.local.zsh` | Sourced at the end of `.zshrc` |
| `~/.config/zsh/aliases.local.zsh` | Sourced at the end of `.zsh_aliases` |
| `~/.config/kitty/local.conf` | Included at the end of `kitty.conf` |
| `~/.config/lite-xl/local.lua` | Loaded at the end of Lite XL `init.lua` |

Put shell-style assignments in `~/.config/zsh/secrets.local`, for example `FOO_API_KEY=bar`.
They are exported automatically so commands launched from zsh can read them from the environment.

Runtime state is intentionally not tracked. For Lite XL, this means files such as `session.lua` and workspace state under `~/.config/lite-xl/ws/` stay local to each device.

## Git hooks

A `pre-push` hook checks `chezmoi diff` before pushing. If there are unapplied changes, it prompts to apply, force push, or abort. The hook is symlinked from `hooks/pre-push` by `run_onchange_setup.sh`.
