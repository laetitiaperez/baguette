#!/bin/bash
# Assemble build/Baguette.app à partir de la compilation release du package.
set -euo pipefail

cd "$(dirname "$0")/.."

# Variables facultatives (utilisées par la CI de release) :
#   BAGUETTE_VERSION  version affichée (défaut 1.0)
#   BAGUETTE_BUILD    numéro de build (défaut 1)
#   UNIVERSAL=1       binaire universel arm64 + x86_64 (nécessite Xcode)
VERSION="${BAGUETTE_VERSION:-1.0}"
BUILD="${BAGUETTE_BUILD:-1}"
BUILD_ARGS=(-c release)
if [[ "${UNIVERSAL:-0}" == "1" ]]; then
    BUILD_ARGS+=(--arch arm64 --arch x86_64)
fi

swift build "${BUILD_ARGS[@]}" --product Baguette
BIN_DIR="$(swift build "${BUILD_ARGS[@]}" --show-bin-path)"

APP="build/Baguette.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources/fr.lproj"
cp "$BIN_DIR/Baguette" "$APP/Contents/MacOS/Baguette"

# Icône générée par scripts/make-icon.swift.
cp Sources/Baguette/Resources/AppIcon.icns "$APP/Contents/Resources/AppIcon.icns"

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
    <key>CFBundleShortVersionString</key><string>${VERSION}</string>
    <key>CFBundleVersion</key><string>${BUILD}</string>
    <key>CFBundleDevelopmentRegion</key><string>fr</string>
    <key>CFBundleLocalizations</key><array><string>fr</string></array>
    <key>LSMinimumSystemVersion</key><string>14.0</string>
    <key>LSApplicationCategoryType</key><string>public.app-category.graphics-design</string>
    <key>NSHighResolutionCapable</key><true/>
    <key>NSPrincipalClass</key><string>NSApplication</string>
    <key>CFBundleIconFile</key><string>AppIcon</string>
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
if ! CODESIGN_LOG="$(codesign --force --sign - "$APP" 2>&1)"; then
    echo "⚠︎ Signature ad hoc impossible ; l'app reste utilisable mais macOS peut avertir au lancement :" >&2
    echo "$CODESIGN_LOG" >&2
fi

echo "→ $APP"
