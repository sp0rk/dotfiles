#!/bin/bash

# Install zsh
if ! command -v zsh >/dev/null; then
  if [[ "$(uname)" == "Darwin" ]]; then
    brew install zsh
  else
    sudo apt-get update || true
    sudo apt-get install -y zsh </dev/tty
  fi
  hash -r
fi

# Install git
if ! command -v git >/dev/null; then
  if [[ "$(uname)" == "Darwin" ]]; then
    brew install git
  else
    sudo apt-get update || true
    sudo apt-get install -y git </dev/tty
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

# Install git hooks
CHEZMOI_SRC="$HOME/.local/share/chezmoi"
ln -sf "$CHEZMOI_SRC/hooks/pre-push" "$CHEZMOI_SRC/.git/hooks/pre-push"

# Set default shell to zsh
if [ "$(basename "$SHELL")" != "zsh" ]; then
  sudo usermod -s "$(which zsh)" "$USER" </dev/tty
fi

# Set editors
git config --global core.editor "subl -n -w"
cat > "$HOME/.config/chezmoi/chezmoi.toml" <<'EOF'
[edit]
    command = "subl"
    args = ["-n", "-w"]
EOF
