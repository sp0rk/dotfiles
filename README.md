# Dotfiles

Managed with [chezmoi](https://chezmoi.io).

## What's shared

- zsh
- oh-my-zsh
- kitty
- Lite XL

## Setup

```sh
sh -c "$(curl -fsLS https://get.chezmoi.io)" -- init --apply --ssh sp0rk
```

`run_onchange_setup.sh` runs automatically when it changes. It installs prerequisites and tools for macOS and Linux:

- zsh
- git
- curl
- thefuck and its Python compatibility dependency on Linux
- oh-my-zsh and custom plugins
- kitty
- Lite XL

It also symlinks the repo git hook, sets the default shell to zsh, and sets git/chezmoi editors to `lite-xl`.

On macOS, packages are installed with Homebrew where available. Lite XL is installed from the latest official GitHub DMG into `~/Applications`. On Linux, apt is used for packaged tools, and Lite XL is installed from the latest official GitHub tarball into `~/.local`.

## Device-specific configuration

Following files are created empty by chezmoi and never overwritten. Edit them directly on each device:

| File | Purpose |
|------|---------|
| `~/.config/zsh/pre.local.zsh` | Sourced at the start of `.zshrc` |
| `~/.config/zsh/post.local.zsh` | Sourced at the end of `.zshrc` |
| `~/.config/zsh/aliases.local.zsh` | Sourced at the end of `.zsh_aliases` |
| `~/.config/kitty/local.conf` | Included at the end of `kitty.conf` |
| `~/.config/lite-xl/local.lua` | Loaded at the end of Lite XL `init.lua` |

Runtime state is intentionally not tracked. For Lite XL, this means files such as `session.lua` and workspace state under `~/.config/lite-xl/ws/` stay local to each device.

## Git hooks

A `pre-push` hook checks `chezmoi diff` before pushing. If there are unapplied changes, it prompts to apply, force push, or abort. The hook is symlinked from `hooks/pre-push` by `run_onchange_setup.sh`.
