#!/bin/bash

set -e

applications_dir="$HOME/.local/share/applications"
desktop_file="$applications_dir/lite-xl.desktop"

mkdir -p "$applications_dir"
cat > "$desktop_file" <<'EOF'
[Desktop Entry]
Type=Application
Name=Lite XL
GenericName=Text Editor
Comment=A lightweight text editor written in Lua
Exec=lite-xl %F
Terminal=false
Categories=Utility;TextEditor;
MimeType=text/plain;text/x-lua;text/x-python;text/x-shellscript;text/markdown;application/json;application/xml;
StartupNotify=true
Icon=accessories-text-editor
EOF

chmod 644 "$desktop_file"
if command -v update-desktop-database >/dev/null; then
  update-desktop-database "$applications_dir"
fi
