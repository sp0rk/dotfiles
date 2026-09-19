#!/bin/bash

set -e

assume_yes=false
case "${1:-}" in
  --yes) assume_yes=true ;;
  "") ;;
  *)
    echo "Usage: $0 [--yes]" >&2
    exit 2
    ;;
esac

if [ "$(uname)" != "Linux" ]; then
  echo "Desktop-state sync is Linux-only; nothing was captured."
  exit 0
fi

enabled="$(chezmoi execute-template '{{ get . "desktopSync" | default false }}')"
if [ "$enabled" != "true" ]; then
  echo "Desktop-state sync is disabled in chezmoi's data settings." >&2
  echo "Run 'chezmoi init', answer yes to the desktop-sync prompt, then retry." >&2
  exit 1
fi

if ! $assume_yes; then
  printf 'Capture current Cinnamon, Plank, and Ulauncher state into chezmoi? [y/N] '
  read -r answer </dev/tty
  case "$answer" in
    y|Y|yes|YES|Yes) ;;
    *)
      echo "Desktop-state capture cancelled."
      exit 0
      ;;
  esac
fi

source_dir="$(chezmoi source-path)"
state_dir="$source_dir/.chezmoitemplates/desktop-state"

mkdir -p "$state_dir/dconf" "$state_dir/config" "$state_dir/desklets"
rm -rf \
  "$state_dir/config/ulauncher" \
  "$state_dir/config/plank-launchers" \
  "$state_dir/config/cinnamon-spices"

if command -v dconf >/dev/null; then
  dconf dump /org/cinnamon/ > "$state_dir/dconf/cinnamon.ini"
  dconf dump /net/launchpad/plank/ > "$state_dir/dconf/plank.ini"
else
  echo "Warning: dconf is unavailable; GSettings were not captured." >&2
fi

if [ -d "$HOME/.config/ulauncher" ]; then
  mkdir -p "$state_dir/config/ulauncher"
  for name in settings.json shortcuts.json extensions.json user-themes; do
    if [ -e "$HOME/.config/ulauncher/$name" ]; then
      cp -a "$HOME/.config/ulauncher/$name" "$state_dir/config/ulauncher/"
    fi
  done
fi

if [ -d "$HOME/.config/plank/dock1/launchers" ]; then
  mkdir -p "$state_dir/config/plank-launchers"
  cp -a "$HOME/.config/plank/dock1/launchers/." "$state_dir/config/plank-launchers/"
fi

if [ -d "$HOME/.config/cinnamon/spices" ]; then
  mkdir -p "$state_dir/config/cinnamon-spices"
  cp -a "$HOME/.config/cinnamon/spices/." "$state_dir/config/cinnamon-spices/"
fi

if [ -d "$HOME/.local/share/cinnamon/desklets" ]; then
  find "$HOME/.local/share/cinnamon/desklets" -mindepth 1 -maxdepth 1 -type d \
    -printf '%f\n' | LC_ALL=C sort > "$state_dir/desklets/installed.txt"
else
  : > "$state_dir/desklets/installed.txt"
fi

(
  cd "$state_dir"
  find config dconf desklets -type f ! -name manifest.sha256 -print0 \
    | LC_ALL=C sort -z \
    | xargs -0 sha256sum
) > "$state_dir/manifest.sha256"

echo "Desktop state captured in $state_dir"
echo "Review it for private data, then commit it explicitly."
