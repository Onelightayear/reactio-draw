#!/bin/sh
# Adds the Reactio Draw tab to Word for Mac (Word 2016 or later), as reference managers do: the template goes into
# Word's Startup folder, and a small helper script into Word's scripts folder (Word's macros may start other programs
# only through a script there). Run it again after moving Reactio Draw.app; with --remove it takes the tab away.
cd "$(dirname "$0")" || exit 1
if [ "$1" = "--remove" ]; then
  for c in "User Content.localized" "User Content"; do for s in "Startup.localized" "Startup"; do
    rm -f "$HOME/Library/Group Containers/UBF8T346G9.Office/$c/$s/Word/Reactio Draw.dotm"; done; done
  rm -f "$HOME/Library/Application Scripts/com.microsoft.Word/ReactioDraw.applescript"
  echo "The Reactio Draw tab is removed from Word (restart Word)."; exit 0
fi
app=""
for d in "/Applications/Reactio Draw.app" "$HOME/Applications/Reactio Draw.app"; do [ -d "$d" ] && { app="$d"; break; }; done
[ -n "$app" ] || { echo "Reactio Draw.app is not in Applications: run Install Reactio Draw.command first."; exit 1; }
g="$HOME/Library/Group Containers/UBF8T346G9.Office"
[ -d "$g" ] || { echo "Microsoft Word for Mac was not found (open Word once, then run this again)."; exit 1; }
c="User Content.localized"; [ -d "$g/$c" ] || { [ -d "$g/User Content" ] && c="User Content"; }
s="Startup.localized"; [ -d "$g/$c/$s" ] || { [ -d "$g/$c/Startup" ] && s="Startup"; }
mkdir -p "$g/$c/$s/Word" && cp "Reactio Draw.dotm" "$g/$c/$s/Word/" || exit 1
mkdir -p "$HOME/Library/Application Scripts/com.microsoft.Word"
sed "s|__APP__|$app|" ReactioDraw.applescript > "$HOME/Library/Application Scripts/com.microsoft.Word/ReactioDraw.applescript" || exit 1
echo "The Reactio Draw tab is in Word now (restart Word if it is open)."
echo "To take it away: sh \"Install Word tab.command\" --remove"
