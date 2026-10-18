#!/bin/sh
# Reactio Draw for Linux: adds it to the applications menu (for you only, no root needed) and checks for WebKitGTK.
# Run it from the "Reactio Draw" folder, where you want the program to stay:  ./install.sh
set -e
DIR="$(cd "$(dirname "$0")" && pwd)"
BIN="$DIR/ReactioDraw"
[ -x "$BIN" ] || chmod +x "$BIN"
APPS="${XDG_DATA_HOME:-$HOME/.local/share}/applications"
ICONS="${XDG_DATA_HOME:-$HOME/.local/share}/icons/hicolor/256x256/apps"
mkdir -p "$APPS" "$ICONS" "$HOME/.local/bin"
cp "$DIR/reactiodraw.png" "$ICONS/reactiodraw.png"
cat > "$APPS/reactio-draw.desktop" <<EOF
[Desktop Entry]
Type=Application
Name=Reactio Draw
GenericName=Chemical structure editor
Comment=Draw chemical structures and reactions
Exec="$BIN" %F
Icon=reactiodraw
Terminal=false
Categories=Science;Chemistry;Education;Graphics;
StartupWMClass=reactiodraw
MimeType=application/x-reactio+json;
EOF
# .reactio, Reactio Draw's own document: a file type of its own that opens in Reactio Draw
MIME="${XDG_DATA_HOME:-$HOME/.local/share}/mime"
mkdir -p "$MIME/packages"
cat > "$MIME/packages/reactio-draw.xml" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<mime-info xmlns="http://www.freedesktop.org/standards/shared-mime-info">
  <mime-type type="application/x-reactio+json">
    <comment>Reactio Draw document</comment>
    <sub-class-of type="application/json"/>
    <glob pattern="*.reactio"/>
    <icon name="reactiodraw"/>
  </mime-type>
</mime-info>
EOF
command -v update-mime-database >/dev/null 2>&1 && update-mime-database "$MIME" >/dev/null 2>&1 || true
command -v xdg-mime >/dev/null 2>&1 && xdg-mime default reactio-draw.desktop application/x-reactio+json >/dev/null 2>&1 || true
ln -sf "$BIN" "$HOME/.local/bin/reactiodraw"
[ -f "$DIR/reactio" ] && { chmod +x "$DIR/reactio"; ln -sf "$DIR/reactio" "$HOME/.local/bin/reactio"; }
command -v update-desktop-database >/dev/null 2>&1 && update-desktop-database "$APPS" >/dev/null 2>&1 || true
command -v gtk-update-icon-cache >/dev/null 2>&1 && gtk-update-icon-cache -q "${XDG_DATA_HOME:-$HOME/.local/share}/icons/hicolor" >/dev/null 2>&1 || true
echo "Reactio Draw is in your applications menu (and runs as: reactiodraw; command line: reactio --help)."
if ! ldconfig -p 2>/dev/null | grep -q -e 'libwebkit2gtk-4.1.so.0' -e 'libwebkit2gtk-4.0.so.37'; then
  echo
  echo "It needs WebKitGTK for its window; install it once:"
  echo "  Debian, Ubuntu, Mint:  sudo apt install libwebkit2gtk-4.1-0"
  echo "  Fedora:                sudo dnf install webkit2gtk4.1"
  echo "  Arch:                  sudo pacman -S webkit2gtk-4.1"
  echo "  openSUSE:              sudo zypper install libwebkit2gtk-4_1-0"
  echo "(Without it, Reactio Draw opens in your web browser instead.)"
fi
