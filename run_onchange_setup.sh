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

deb_package_installed() {
  dpkg-query -W -f='${Status}' "$1" 2>/dev/null | grep -q "install ok installed"
}

ensure_fd_command_linux() {
  if command -v fd >/dev/null; then
    return 0
  fi

  if ! command -v fdfind >/dev/null; then
    echo "fd-find installed but neither fd nor fdfind is available" >&2
    return 1
  fi

  mkdir -p "$HOME/.local/bin"
  ln -sf /usr/bin/fdfind "$HOME/.local/bin/fd"
}

ensure_bat_command_linux() {
  if command -v bat >/dev/null; then
    return 0
  fi

  if ! command -v batcat >/dev/null; then
    echo "bat installed but neither bat nor batcat is available" >&2
    return 1
  fi

  mkdir -p "$HOME/.local/bin"
  ln -sf /usr/bin/batcat "$HOME/.local/bin/bat"
}

github_latest_lite_xl_tag() {
  curl -fsSL https://api.github.com/repos/lite-xl/lite-xl/releases/latest |
    sed -n 's/.*"tag_name": "\(v[^"]*\)".*/\1/p' |
    head -n 1
}

github_latest_bottom_tag() {
  curl -fsSL https://api.github.com/repos/ClementTsang/bottom/releases/latest |
    sed -n 's/.*"tag_name": "\([^"]*\)".*/\1/p' |
    head -n 1
}

github_latest_yazi_tag() {
  curl -fsSL https://api.github.com/repos/sxyazi/yazi/releases/latest |
    sed -n 's/.*"tag_name": "\([^"]*\)".*/\1/p' |
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
  url="https://github.com/lite-xl/lite-xl/releases/download/${tag}/lite-xl-${tag}-addons-linux-x86_64-portable.tar.gz"

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
  url="https://github.com/lite-xl/lite-xl/releases/download/${tag}/lite-xl-${tag}-addons-${asset}"

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

install_bottom_linux() {
  local tag tmp arch deb url

  tag="$(github_latest_bottom_tag)"
  if [ -z "$tag" ]; then
    echo "Unable to find latest bottom release tag" >&2
    return 1
  fi

  arch="$(dpkg --print-architecture)"
  case "$arch" in
    amd64|arm64|armhf) ;;
    *)
      echo "Unsupported architecture for bottom .deb install: $arch" >&2
      return 1
      ;;
  esac

  tmp="$(mktemp -d)"
  deb="$tmp/bottom_${tag#v}-1_${arch}.deb"
  url="https://github.com/ClementTsang/bottom/releases/download/${tag}/bottom_${tag#v}-1_${arch}.deb"

  curl -fL "$url" -o "$deb"
  sudo dpkg -i "$deb" </dev/tty
  rm -rf "$tmp"
}

install_yazi_linux() {
  local tag tmp arch asset deb url

  tag="$(github_latest_yazi_tag)"
  if [ -z "$tag" ]; then
    echo "Unable to find latest Yazi release tag" >&2
    return 1
  fi

  arch="$(dpkg --print-architecture)"
  case "$arch" in
    amd64) asset="x86_64-unknown-linux-gnu" ;;
    arm64) asset="aarch64-unknown-linux-gnu" ;;
    *)
      echo "Unsupported architecture for Yazi .deb install: $arch" >&2
      return 1
      ;;
  esac

  tmp="$(mktemp -d)"
  deb="$tmp/yazi-${asset}.deb"
  url="https://github.com/sxyazi/yazi/releases/download/${tag}/yazi-${asset}.deb"

  curl -fL "$url" -o "$deb"
  sudo dpkg -i "$deb" </dev/tty
  rm -rf "$tmp"
}

lite_xl_has_plugin_manager() {
  [ -f "$HOME/.config/lite-xl/plugins/plugin_manager/init.lua" ] ||
  [ -f "$HOME/.local/share/lite-xl/plugins/plugin_manager/init.lua" ] ||
    [ -f "$HOME/Applications/Lite XL.app/Contents/Resources/plugins/plugin_manager/init.lua" ]
}

lite_xl_user_has_plugin_manager() {
  [ -f "$HOME/.config/lite-xl/plugins/plugin_manager/init.lua" ]
}

lpm_arch() {
  local arch os

  arch="$(uname -m)"
  os="$(uname | tr '[:upper:]' '[:lower:]')"
  case "$arch" in
    arm64) arch="aarch64" ;;
  esac

  printf '%s-%s\n' "$arch" "$os"
}

install_lite_xl_plugin_manager() {
  local lpm tmp arch

  if lite_xl_user_has_plugin_manager; then
    return 0
  fi

  arch="$(lpm_arch)"
  tmp="$(mktemp -d)"
  lpm="$tmp/lpm"

  curl -fL "https://github.com/lite-xl/lite-xl-plugin-manager/releases/download/latest/lpm.${arch}" -o "$lpm"
  chmod +x "$lpm"
  "$lpm" install plugin_manager --assume-yes --userdir="$HOME/.config/lite-xl"
  rm -rf "$tmp"
}

sync_lite_xl_plugins() {
  local lpm plugins

  lpm="$(find "$HOME/.config/lite-xl/plugins/plugin_manager" -maxdepth 1 -type f -name 'lpm.*' -perm -u+x | head -n 1)"
  if [ ! -x "$lpm" ] || [ ! -f "$HOME/.config/lpm/settings.json" ]; then
    return 0
  fi

  plugins="$(
    python3 -c 'import json, sys; print(" ".join(json.load(open(sys.argv[1])).get("installed", [])))' "$HOME/.config/lpm/settings.json"
  )"
  if [ -n "$plugins" ]; then
    # shellcheck disable=SC2086
    "$lpm" install $plugins --assume-yes --userdir="$HOME/.config/lite-xl"
  fi
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

if ! command -v tree >/dev/null; then
  if is_macos; then
    brew_install tree
  else
    apt_install tree
  fi
fi

if ! command -v tldr >/dev/null; then
  if is_macos; then
    brew_install tldr
  else
    apt_install tldr
  fi
fi

if ! command -v bat >/dev/null; then
  if is_macos; then
    brew_install bat
  else
    apt_install bat
    ensure_bat_command_linux
  fi
fi

if ! command -v fd >/dev/null; then
  if is_macos; then
    brew_install fd
  else
    apt_install fd-find
    ensure_fd_command_linux
  fi
fi

if is_macos; then
  command -v ffmpeg >/dev/null || brew_install ffmpeg-full
  command -v jq >/dev/null || brew_install jq
  command -v 7z >/dev/null || brew_install sevenzip
  command -v pdftotext >/dev/null || brew_install poppler
  command -v rg >/dev/null || brew_install ripgrep
  command -v fzf >/dev/null || brew_install fzf
  command -v zoxide >/dev/null || brew_install zoxide
  command -v resvg >/dev/null || brew_install resvg
  command -v magick >/dev/null || brew_install imagemagick-full
else
  command -v ffmpeg >/dev/null || apt_install ffmpeg
  command -v jq >/dev/null || apt_install jq
  command -v 7z >/dev/null || apt_install 7zip
  command -v pdftotext >/dev/null || apt_install poppler-utils
  command -v rg >/dev/null || apt_install ripgrep
  command -v fzf >/dev/null || apt_install fzf
  deb_package_installed zoxide || apt_install zoxide
  command -v magick >/dev/null || apt_install imagemagick
fi

if is_macos; then
  command -v yazi >/dev/null || brew_install yazi
else
  if ! deb_package_installed yazi; then
    install_yazi_linux
  fi
fi

if ! command -v btm >/dev/null; then
  if is_macos; then
    brew_install bottom
  else
    install_bottom_linux
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

if ! command -v eza >/dev/null; then
  if is_macos; then
    brew_install eza
  else
    sudo mkdir -p /etc/apt/keyrings
    wget -qO- https://raw.githubusercontent.com/eza-community/eza/main/deb.asc | sudo gpg --dearmor -o /etc/apt/keyrings/gierens.gpg
    echo "deb [signed-by=/etc/apt/keyrings/gierens.gpg] http://deb.gierens.de stable main" | sudo tee /etc/apt/sources.list.d/gierens.list
    sudo chmod 644 /etc/apt/keyrings/gierens.gpg /etc/apt/sources.list.d/gierens.list
    apt_install eza
  fi
fi

if command -v espanso >/dev/null; then
  espanso_uninstall=""
  read -r -p "Espanso is installed. Uninstall it? [y/N] " espanso_uninstall </dev/tty || true
  case "$espanso_uninstall" in
    y|Y|yes|YES|Yes)
      if is_macos; then
        brew uninstall espanso
        if [ -L "$HOME/Library/Application Support/espanso" ]; then
          rm "$HOME/Library/Application Support/espanso"
        fi
      else
        sudo apt remove -y espanso </dev/tty
      fi
      ;;
    *)
      echo "Keeping Espanso installed."
      ;;
  esac
fi

# Install oh-my-zsh
if [ ! -d "$HOME/.oh-my-zsh" ]; then
  sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended
fi

# Install oh-my-zsh custom plugins
ZSH_CUSTOM="${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}"
[ -d "$ZSH_CUSTOM/plugins/fzf-tab" ] || git clone https://github.com/Aloxaf/fzf-tab "$ZSH_CUSTOM/plugins/fzf-tab"
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
if ! command -v lite-xl >/dev/null || ! lite_xl_has_plugin_manager; then
  if is_macos; then
    install_lite_xl_macos
  else
    install_lite_xl_linux
  fi
fi

install_lite_xl_plugin_manager
sync_lite_xl_plugins

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
