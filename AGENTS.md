# Repository Guidelines

## Project Structure & Module Organization

This is a chezmoi-managed dotfiles repository. Top-level `dot_*` files map to home-directory dotfiles such as `~/.zshrc` and `~/.p10k.zsh`. Configuration under `private_dot_config/` maps to `~/.config/`, including `zsh/`, `kitty/`, `lite-xl/`, and `lpm/`. Setup and automation live in `run_onchange_*.sh` scripts, with template-aware automation in `*.tmpl`. Git hooks are tracked in `hooks/`; `run_onchange_setup.sh` symlinks `hooks/pre-push` into `.git/hooks/`.

Device-specific files use `create_empty_*` source files and should remain empty placeholders in the repo. Put local machine changes in the generated files under `~/.config/...`, not in tracked shared config.

## Build, Test, and Development Commands

- `chezmoi diff`: preview differences between the source state and the applied home-directory state.
- `chezmoi apply`: apply tracked dotfile changes to the current machine.
- `chezmoi execute-template < file.tmpl`: inspect rendered output from a chezmoi template before applying.
- `bash -n run_onchange_setup.sh hooks/pre-push`: syntax-check shell scripts.
- `shellcheck run_onchange_setup.sh hooks/pre-push`: lint shell scripts when `shellcheck` is available.

There is no application build step or formal test suite.

## Coding Style & Naming Conventions

Shell scripts use Bash with `#!/bin/bash`; prefer `set -e` for setup-style automation and keep functions small. Use two-space indentation in shell control blocks, matching existing scripts. Follow chezmoi naming conventions: `dot_` for home dotfiles, `private_dot_config/` for private config paths, `run_onchange_` for scripts that should rerun when content changes, and `.tmpl` for templates.

For JSON config such as `private_dot_config/lpm/settings.json`, keep output normalized and compact. Avoid committing runtime state, sessions, caches, or machine-local overrides.

## Testing Guidelines

Before pushing, run `chezmoi diff` and review the exact target-file changes. For shell edits, run `bash -n` at minimum; use `shellcheck` for nontrivial changes. For Lite XL plugin changes, ensure `private_dot_config/lpm/settings.json` remains valid JSON and can be parsed with `python3 -m json.tool`.

## Commit & Pull Request Guidelines

Git history uses short, imperative commit subjects such as `Update Lite XL plugins` and `Make Lite XL launcher quiet`. Keep commits focused on one config area or behavior change.

Pull requests should describe the affected tool or config area, list any setup side effects, and mention manual checks performed, especially `chezmoi diff`, shell linting, or app-specific validation. Include screenshots only for visible UI changes such as kitty theme or Lite XL appearance updates.

## Security & Configuration Tips

Do not commit secrets, host-specific credentials, or private runtime files. Keep personal overrides in generated local files like `~/.config/zsh/post.local.zsh`, `~/.config/kitty/local.conf`, and `~/.config/lite-xl/local.lua`.
