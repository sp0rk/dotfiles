# Dotfiles

Managed with [chezmoi](https://chezmoi.io).

## What's shared

- zsh
- oh-my-zsh

## Setup

```sh
sh -c "$(curl -fsLS https://get.chezmoi.io)" -- init --apply sp0rk
```

`run_once_setup.sh` runs automatically on first apply and installs prerequisites (zsh, git, oh-my-zsh) and sets git/chezmoi editors to `subl`.

## Device-specific configuration

Following files are created empty by chezmoi and never overwritten. Edit them directly on each device:

| File | Purpose |
|------|---------|
| `~/.config/zsh/pre.local.zsh` | Sourced at the start of `.zshrc` |
| `~/.config/zsh/post.local.zsh` | Sourced at the end of `.zshrc` |
| `~/.config/zsh/aliases.local.zsh` | Sourced at the end of `.zsh_aliases` |

## Git hooks

A `pre-push` hook checks `chezmoi diff` before pushing. If there are unapplied changes, it prompts to apply, force push, or abort. The hook is symlinked from `hooks/pre-push` by `run_once_setup.sh`.
