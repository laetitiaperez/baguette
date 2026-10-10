#!/bin/bash
# Assemble build/Baguette.app à partir de la compilation release du package.
set -euo pipefail

cd "$(dirname "$0")/.."

swift build -c release --product Baguette
BIN_DIR="$(swift build -c release --show-bin-path)"

APP="build/Baguette.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources/fr.lproj"
cp "$BIN_DIR/Baguette" "$APP/Contents/MacOS/Baguette"

ICON_ENTRY=""
if [ -f Sources/Baguette/Resources/AppIcon.icns ]; then
    cp Sources/Baguette/Resources/AppIcon.icns "$APP/Contents/Resources/AppIcon.icns"
    ICON_ENTRY="<key>CFBundleIconFile</key><string>AppIcon</string>"
fi

cat > "$APP/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleIdentifier</key><string>fr.laetitiaperez.baguette</string>
    <key>CFBundleName</key><string>Baguette</string>
    <key>CFBundleDisplayName</key><string>Baguette</string>
    <key>CFBundleExecutable</key><string>Baguette</string>
    <key>CFBundlePackageType</key><string>APPL</string>
    <key>CFBundleShortVersionString</key><string>1.0</string>
    <key>CFBundleVersion</key><string>1</string>
    <key>CFBundleDevelopmentRegion</key><string>fr</string>
    <key>CFBundleLocalizations</key><array><string>fr</string></array>
    <key>LSMinimumSystemVersion</key><string>14.0</string>
    <key>LSApplicationCategoryType</key><string>public.app-category.graphics-design</string>
    <key>NSHighResolutionCapable</key><true/>
    <key>NSPrincipalClass</key><string>NSApplication</string>
    ${ICON_ENTRY}
    <key>CFBundleDocumentTypes</key>
    <array>
        <dict>
            <key>CFBundleTypeName</key><string>Image</string>
            <key>CFBundleTypeRole</key><string>Viewer</string>
            <key>LSHandlerRank</key><string>Alternate</string>
            <key>LSItemContentTypes</key><array><string>public.image</string></array>
        </dict>
    </array>
</dict>
</plist>
PLIST

# Signature ad hoc pour que macOS lance l'app sans avertissement de binaire modifié.
codesign --force --sign - "$APP" >/dev/null 2>&1 || true

echo "→ $APP"
