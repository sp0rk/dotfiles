#!/bin/bash

set -e

is_macos() {
  [[ "$(uname)" == "Darwin" ]]
}

apt_install() {
  sudo apt-get update || true
  sudo apt-get install -y "$@" </dev/tty
}

brew_install() {
  brew install "$@"
}

brew_install_cask() {
  brew install --cask "$@"
}

github_latest_lite_xl_tag() {
  curl -fsSL https://api.github.com/repos/lite-xl/lite-xl/releases/latest |
    sed -n 's/.*"tag_name": "\(v[^"]*\)".*/\1/p' |
    head -n 1
}

install_lite_xl_linux() {
  local tag tmp archive url

  tag="$(github_latest_lite_xl_tag)"
  if [ -z "$tag" ]; then
    echo "Unable to find latest Lite XL release tag" >&2
    return 1
  fi

  tmp="$(mktemp -d)"
  archive="$tmp/lite-xl.tar.gz"
  url="https://github.com/lite-xl/lite-xl/releases/download/${tag}/lite-xl-${tag}-linux-x86_64-portable.tar.gz"

  curl -fL "$url" -o "$archive"
  tar -xzf "$archive" -C "$tmp"

  rm -rf "$HOME/.local/share/lite-xl" "$HOME/.local/bin/lite-xl"
  mkdir -p "$HOME/.local/bin" "$HOME/.local/share/lite-xl"
  cp "$tmp/lite-xl/lite-xl" "$HOME/.local/bin/lite-xl"
  cp -r "$tmp/lite-xl/data/." "$HOME/.local/share/lite-xl"
  rm -rf "$tmp"
}

install_lite_xl_macos() {
  local tag arch asset tmp dmg mount app_path url

  tag="$(github_latest_lite_xl_tag)"
  if [ -z "$tag" ]; then
    echo "Unable to find latest Lite XL release tag" >&2
    return 1
  fi

  arch="$(uname -m)"
  case "$arch" in
    arm64) asset="macos-arm64.dmg" ;;
    x86_64) asset="macos-x86_64.dmg" ;;
    *) asset="macos-universal.dmg" ;;
  esac

  tmp="$(mktemp -d)"
  dmg="$tmp/lite-xl.dmg"
  mount="$tmp/mount"
  app_path="$HOME/Applications/Lite XL.app"
  url="https://github.com/lite-xl/lite-xl/releases/download/${tag}/lite-xl-${tag}-${asset}"

  mkdir -p "$mount" "$HOME/Applications" "$HOME/.local/bin"
  curl -fL "$url" -o "$dmg"
  hdiutil attach "$dmg" -mountpoint "$mount" -nobrowse -quiet
  rm -rf "$app_path"
  cp -R "$mount/Lite XL.app" "$app_path"
  hdiutil detach "$mount" -quiet
  cat > "$HOME/.local/bin/lite-xl" <<WRAPPER
#!/bin/sh
exec env LITE_XL_DATADIR="$app_path/Contents/Resources" "$app_path/Contents/MacOS/lite-xl" "\$@"
WRAPPER
  chmod +x "$HOME/.local/bin/lite-xl"
  rm -rf "$tmp"
}

# Install shell and setup prerequisites
if ! command -v zsh >/dev/null; then
  if is_macos; then
    brew_install zsh
  else
    apt_install zsh
  fi
  hash -r
fi

if ! command -v git >/dev/null; then
  if is_macos; then
    brew_install git
  else
    apt_install git
  fi
fi

if ! command -v curl >/dev/null; then
  if is_macos; then
    brew_install curl
  else
    apt_install curl
  fi
fi

if is_macos; then
  if ! command -v thefuck >/dev/null; then
    brew_install thefuck
  fi
else
  if ! command -v thefuck >/dev/null || ! python3 -c "import distutils.spawn" >/dev/null 2>&1; then
    apt_install thefuck python3-setuptools
  fi
fi

# Install oh-my-zsh
if [ ! -d "$HOME/.oh-my-zsh" ]; then
  sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended
fi

# Install oh-my-zsh custom plugins
ZSH_CUSTOM="${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}"
[ -d "$ZSH_CUSTOM/plugins/zsh-autosuggestions" ] || git clone https://github.com/zsh-users/zsh-autosuggestions "$ZSH_CUSTOM/plugins/zsh-autosuggestions"
[ -d "$ZSH_CUSTOM/plugins/zsh-syntax-highlighting" ] || git clone https://github.com/zsh-users/zsh-syntax-highlighting "$ZSH_CUSTOM/plugins/zsh-syntax-highlighting"
[ -d "$ZSH_CUSTOM/plugins/command-time" ] || git clone https://github.com/popstas/zsh-command-time "$ZSH_CUSTOM/plugins/command-time"
[ -d "$ZSH_CUSTOM/themes/powerlevel10k" ] || git clone --depth=1 https://github.com/romkatv/powerlevel10k "$ZSH_CUSTOM/themes/powerlevel10k"

# Install kitty
if ! command -v kitty >/dev/null; then
  if is_macos; then
    brew_install_cask kitty
  else
    apt_install kitty
  fi
fi

# Install Lite XL
if ! command -v lite-xl >/dev/null; then
  if is_macos; then
    install_lite_xl_macos
  else
    install_lite_xl_linux
  fi
fi

# Install git hooks
CHEZMOI_SRC="$HOME/.local/share/chezmoi"
ln -sf "$CHEZMOI_SRC/hooks/pre-push" "$CHEZMOI_SRC/.git/hooks/pre-push"

# Set default shell to zsh
if [ "$(basename "$SHELL")" != "zsh" ]; then
  if is_macos; then
    chsh -s "$(which zsh)"
  else
    sudo usermod -s "$(which zsh)" "$USER" </dev/tty
  fi
fi

# Set editors
git config --global core.editor "lite-xl"
mkdir -p "$HOME/.config/chezmoi"
cat > "$HOME/.config/chezmoi/chezmoi.toml" <<'EOF'
[edit]
    command = "lite-xl"
EOF
