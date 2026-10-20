#!/bin/bash
# Installs Reactio Draw.app: compiles it on this Mac (swiftc from Apple's Command Line Tools), puts it into Applications and opens it.
set -e
d="$(cd "$(dirname "$0")" && pwd)"
if ! xcrun -f swiftc >/dev/null 2>&1; then
  echo "Reactio Draw needs Apple's Command Line Tools (free). A window will ask to install them;"
  echo "when that is done, run this installer again."
  xcode-select --install || true
  exit 1
fi
dest="/Applications"; [ -w "$dest" ] || { dest="$HOME/Applications"; mkdir -p "$dest"; }
app="$dest/Reactio Draw.app"
osascript -e 'tell application id "org.reactiodraw.editor" to quit' >/dev/null 2>&1 || true
w="$(mktemp -d)"; b="$w/Reactio Draw.app/Contents"
mkdir -p "$b/MacOS" "$b/Resources"
echo "Building Reactio Draw..."
xcrun swiftc -O "$d/main.swift" -o "$b/MacOS/ReactioDraw" -framework Cocoa -framework WebKit
cp "$d/index.html" "$b/Resources/index.html"
# the command line (reactio --help): a small script in the app that runs it without a window
cat > "$b/MacOS/reactio" <<'SH'
#!/bin/sh
# Reactio Draw command line (reactio --help). Runs the program beside this script without a window.
s="$0"; while [ -L "$s" ]; do t="$(readlink "$s")"; case "$t" in /*) s="$t";; *) s="$(dirname "$s")/$t";; esac; done
exec "$(cd "$(dirname "$s")" && pwd)/ReactioDraw" --cli "$@"
SH
chmod 755 "$b/MacOS/reactio"
cp "$d/opsin.jar" "$b/Resources/opsin.jar" 2>/dev/null || true
cp "$d/reactio_name.py" "$b/Resources/reactio_name.py" 2>/dev/null || true
cp "$d/ReactioDraw.icns" "$b/Resources/ReactioDraw.icns"
# licenses travel inside the app
for f in LICENSE LICENSE.txt THIRD-PARTY-NOTICES.md; do [ -f "$d/$f" ] && cp "$d/$f" "$b/Resources/"; done; [ -d "$d/LICENSES" ] && cp -R "$d/LICENSES" "$b/Resources/" || true
cat > "$b/Info.plist" <<PL
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>CFBundleName</key><string>Reactio Draw</string>
<key>CFBundleDisplayName</key><string>Reactio Draw</string>
<key>CFBundleIdentifier</key><string>org.reactiodraw.editor</string><key>NSAppleEventsUsageDescription</key><string>Reactio Draw puts a drawing you edited back into Word (Reactio Draw tab in Word).</string><key>NSHumanReadableCopyright</key><string>© 2026 Pavel Sakharov. GNU AGPL v3 or later.</string>
<key>CFBundleExecutable</key><string>ReactioDraw</string>
<key>CFBundleIconFile</key><string>ReactioDraw</string>
<key>CFBundlePackageType</key><string>APPL</string>
<key>CFBundleShortVersionString</key><string>1.1.1</string>
<key>LSMinimumSystemVersion</key><string>11.0</string>
<key>NSHighResolutionCapable</key><true/>
<key>NSPrincipalClass</key><string>NSApplication</string>
<key>CFBundleDocumentTypes</key><array>
<dict><key>CFBundleTypeName</key><string>Reactio Draw document</string><key>CFBundleTypeRole</key><string>Editor</string><key>LSHandlerRank</key><string>Owner</string>
<key>CFBundleTypeIconFile</key><string>ReactioDraw</string><key>LSItemContentTypes</key><array><string>org.reactiodraw.reactio</string></array><key>CFBundleTypeExtensions</key><array><string>reactio</string></array></dict>
<dict><key>CFBundleTypeName</key><string>Chemical drawing</string><key>CFBundleTypeRole</key><string>Editor</string><key>LSHandlerRank</key><string>Alternate</string>
<key>CFBundleTypeIconFile</key><string>ReactioDraw</string>
<key>LSItemContentTypes</key><array><string>org.reactiodraw.cdxml</string><string>org.reactiodraw.cdx</string><string>org.reactiodraw.mol</string><string>org.reactiodraw.rxn</string><string>org.reactiodraw.sdf</string><string>org.reactiodraw.smi</string><string>public.json</string></array>
<key>CFBundleTypeExtensions</key><array><string>cdxml</string><string>cdx</string><string>json</string><string>mol</string><string>rxn</string><string>sdf</string><string>smi</string></array></dict>
</array>
<key>UTExportedTypeDeclarations</key><array>
<dict><key>UTTypeIdentifier</key><string>org.reactiodraw.reactio</string><key>UTTypeDescription</key><string>Reactio Draw document</string><key>UTTypeConformsTo</key><array><string>public.json</string></array><key>UTTypeTagSpecification</key><dict><key>public.filename-extension</key><array><string>reactio</string></array><key>public.mime-type</key><array><string>application/x-reactio+json</string></array></dict></dict>
</array>
<key>UTImportedTypeDeclarations</key><array>
<dict><key>UTTypeIdentifier</key><string>org.reactiodraw.cdxml</string><key>UTTypeDescription</key><string>CDXML drawing</string><key>UTTypeConformsTo</key><array><string>public.xml</string></array><key>UTTypeTagSpecification</key><dict><key>public.filename-extension</key><array><string>cdxml</string></array></dict></dict>
<dict><key>UTTypeIdentifier</key><string>org.reactiodraw.cdx</string><key>UTTypeDescription</key><string>CDX drawing</string><key>UTTypeConformsTo</key><array><string>public.data</string></array><key>UTTypeTagSpecification</key><dict><key>public.filename-extension</key><array><string>cdx</string></array></dict></dict>
<dict><key>UTTypeIdentifier</key><string>org.reactiodraw.mol</string><key>UTTypeDescription</key><string>Molfile</string><key>UTTypeConformsTo</key><array><string>public.plain-text</string></array><key>UTTypeTagSpecification</key><dict><key>public.filename-extension</key><array><string>mol</string></array></dict></dict>
<dict><key>UTTypeIdentifier</key><string>org.reactiodraw.rxn</string><key>UTTypeDescription</key><string>Reaction file</string><key>UTTypeConformsTo</key><array><string>public.plain-text</string></array><key>UTTypeTagSpecification</key><dict><key>public.filename-extension</key><array><string>rxn</string></array></dict></dict>
<dict><key>UTTypeIdentifier</key><string>org.reactiodraw.sdf</string><key>UTTypeDescription</key><string>Structure-data file</string><key>UTTypeConformsTo</key><array><string>public.plain-text</string></array><key>UTTypeTagSpecification</key><dict><key>public.filename-extension</key><array><string>sdf</string><string>sd</string></array></dict></dict>
<dict><key>UTTypeIdentifier</key><string>org.reactiodraw.smi</string><key>UTTypeDescription</key><string>SMILES file</string><key>UTTypeConformsTo</key><array><string>public.plain-text</string></array><key>UTTypeTagSpecification</key><dict><key>public.filename-extension</key><array><string>smi</string></array></dict></dict>
</array>
</dict></plist>
PL
codesign --force --deep -s - "$w/Reactio Draw.app" >/dev/null 2>&1 || true
rm -rf "$app"; mv "$w/Reactio Draw.app" "$app"
touch "$app"
/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister -f "$app" >/dev/null 2>&1 || true
open "$app"
# reactio in the Terminal: linked where the shell looks for programs, if that folder can be written without a password
if [ -d /usr/local/bin ] && [ -w /usr/local/bin ]; then ln -sf "$app/Contents/MacOS/reactio" /usr/local/bin/reactio; cl="reactio --help"
else cl="\"$app/Contents/MacOS/reactio\" --help   (or: sudo ln -sf \"$app/Contents/MacOS/reactio\" /usr/local/bin/reactio)"; fi
echo "Reactio Draw is installed in $dest. Command line: $cl"
# the Reactio Draw tab in Word, when Word is on this Mac
[ -d "$HOME/Library/Group Containers/UBF8T346G9.Office" ] && [ -f "$d/Install Word tab.command" ] && sh "$d/Install Word tab.command"
echo "You can close this window."
