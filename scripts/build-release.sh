#!/bin/bash
#
# Builds a signed Release copy of the app, with the adapter library inside it.
#
# Usage: scripts/build-release.sh <output folder>
#
# The app is written to <output folder>/Trackpad Edges.app, and the update tools that match its
# updater are written to <output folder>/sparkle-bin. The script signs with the project's
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
  -configuration Release -derivedDataPath "$work/build" \
  -clonedSourcePackagesDirPath "$work/build/SourcePackages" \
  -packageCachePath "$work/package-cache" -onlyUsePackageVersionsFromResolvedFile \
  CODE_SIGNING_ALLOWED=NO \
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

# A library built for a newer system than the app's minimum refuses to load there, and media seek
# then fails without a word. A default build targets the build machine's system, so this stops it.
app_minimum="$(/usr/libexec/PlistBuddy -c 'Print :LSMinimumSystemVersion' "$app/Contents/Info.plist")"
adapter_minimum="$(xcrun vtool -show-build "$framework/Versions/A/MediaRemoteAdapter" |
  awk '/minos/ {print $2}' | sort -V | tail -n 1)"
if [[ -z "$adapter_minimum" ]]; then
  echo "Could not read the minimum macOS of the adapter." >&2
  exit 1
fi
if [[ "$(printf '%s\n%s\n' "$adapter_minimum" "$app_minimum" | sort -V | tail -n 1)" != "$app_minimum" ]]; then
  echo "The adapter needs macOS $adapter_minimum, but the app supports macOS $app_minimum." >&2
  echo "Rebuild it as docs/dependencies.md describes." >&2
  exit 1
fi

# Inner code is signed first, because the app's signature records the signatures inside it. The
# updater's helpers are signed one at a time, because each must carry the hardened runtime.
sparkle="$app/Contents/Frameworks/Sparkle.framework"
"${sign[@]}" "$sparkle/Versions/B/XPCServices/Installer.xpc"
"${sign[@]}" --preserve-metadata=entitlements "$sparkle/Versions/B/XPCServices/Downloader.xpc"
"${sign[@]}" "$sparkle/Versions/B/Autoupdate"
"${sign[@]}" "$sparkle/Versions/B/Updater.app"
"${sign[@]}" "$sparkle"
"${sign[@]}" "$framework"
# Signing with --force and no entitlements file would strip the app's entitlements, and corners
# then cannot ask for permission to send Apple events.
"${sign[@]}" --entitlements "$root/Config/TrackpadEdges.entitlements" "$app"
codesign --verify --strict --deep "$app"
if ! codesign -d --entitlements - --xml "$app" 2>/dev/null |
  grep -q "com.apple.security.automation.apple-events"; then
  echo "The signed app is missing the Apple events entitlement." >&2
  exit 1
fi

rm -rf "${output:?}/$app_name.app"
ditto "$app" "$output/$app_name.app"
codesign --verify --strict --deep "$output/$app_name.app"
rm -rf "${output:?}/sparkle-bin"
ditto "$work/build/SourcePackages/artifacts/sparkle/Sparkle/bin" "$output/sparkle-bin"
echo "Built: $output/$app_name.app"
