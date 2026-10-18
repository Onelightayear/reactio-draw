#!/bin/sh
# Takes Reactio Draw out of the applications menu. Your documents and settings stay in ~/.local/share/ReactioDraw;
# delete that folder and this one to remove everything.
D="${XDG_DATA_HOME:-$HOME/.local/share}"
rm -f "$D/applications/reactio-draw.desktop" "$D/icons/hicolor/256x256/apps/reactiodraw.png" "$HOME/.local/bin/reactiodraw" "$HOME/.local/bin/reactio"
rm -f "$D/mime/packages/reactio-draw.xml"; command -v update-mime-database >/dev/null 2>&1 && update-mime-database "$D/mime" >/dev/null 2>&1 || true
command -v update-desktop-database >/dev/null 2>&1 && update-desktop-database "$D/applications" >/dev/null 2>&1 || true
echo "Reactio Draw is no longer in the applications menu."
