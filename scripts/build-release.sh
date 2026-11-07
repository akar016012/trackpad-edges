#!/bin/bash
#
# Builds a signed Release copy of the app, with the adapter library inside it.
#
# Usage: scripts/build-release.sh <output folder>
#
# The app is written to <output folder>/Trackpad Edges.app. The script signs with the project's
# Developer ID identity when it exists, and otherwise with an Apple Development identity. Set
# SIGN_KEYCHAIN to sign from a specific keychain. Both install.sh and the release workflow use it.

set -euo pipefail

root="$(cd "$(dirname "$0")/.." && pwd)"
output="${1:?Give an output folder.}"
app_name="Trackpad Edges"
team="3J6QGH6H9F"

# Signing by hash stays unambiguous when a renewed certificate shares its name with an old one.
identities="$(security find-identity -v -p codesigning ${SIGN_KEYCHAIN:+"$SIGN_KEYCHAIN"})"
identity="$(sed -n "s/.*) \([0-9A-F]\{40\}\) \"Developer ID Application: .*($team)\".*/\1/p" \
  <<<"$identities" | head -n 1)"
timestamp=(--timestamp)
if [[ -z "$identity" ]]; then
  identity="$(sed -n 's/.*) \([0-9A-F]\{40\}\) "Apple Development: .*/\1/p' \
    <<<"$identities" | head -n 1)"
  timestamp=(--timestamp=none)
  echo "No Developer ID identity was found, so this copy uses Apple Development." >&2
  echo "Macs treat that as a different app, so it needs its own Accessibility permission." >&2
fi
if [[ -z "$identity" ]]; then
  echo "No signing identity was found. Sign in to your developer account in Xcode first." >&2
  exit 1
fi
sign=(codesign --force --options runtime "${timestamp[@]}" --sign "$identity")
if [[ -n "${SIGN_KEYCHAIN:-}" ]]; then
  sign+=(--keychain "$SIGN_KEYCHAIN")
fi

mkdir -p "$output"
work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT

echo "Building the Release configuration..."
xcodebuild -project "$root/trackpad-edges.xcodeproj" -scheme trackpad-edges \
  -configuration Release -derivedDataPath "$work/build" CODE_SIGNING_ALLOWED=NO \
  build >"$work/build.log" 2>&1 || {
  tail -n 30 "$work/build.log" >&2
  exit 1
}
app="$work/build/Build/Products/Release/$app_name.app"

# Xcode leaves compiled binaries out of an app's resources, so the library ships as text and
# becomes a real framework here. The text copy is then no longer needed.
resources="$app/Contents/Resources"
framework="$app/Contents/Frameworks/MediaRemoteAdapter.framework"
mkdir -p "$framework/Versions/A/Resources"
base64 --decode -i "$resources/MediaRemoteAdapter.base64" \
  -o "$framework/Versions/A/MediaRemoteAdapter"
rm "$resources/MediaRemoteAdapter.base64"
cat >"$framework/Versions/A/Resources/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleExecutable</key>
  <string>MediaRemoteAdapter</string>
  <key>CFBundleIdentifier</key>
  <string>com.adityakar.trackpad-edges.adapter</string>
  <key>CFBundleName</key>
  <string>MediaRemoteAdapter</string>
  <key>CFBundlePackageType</key>
  <string>FMWK</string>
</dict>
</plist>
PLIST
ln -s A "$framework/Versions/Current"
ln -s Versions/Current/MediaRemoteAdapter "$framework/MediaRemoteAdapter"
ln -s Versions/Current/Resources "$framework/Resources"

# Inner code is signed first, because the app's signature records the signatures inside it.
"${sign[@]}" "$framework"
"${sign[@]}" "$app"
codesign --verify --strict --deep "$app"

rm -rf "${output:?}/$app_name.app"
ditto "$app" "$output/$app_name.app"
codesign --verify --strict --deep "$output/$app_name.app"
echo "Built: $output/$app_name.app"
