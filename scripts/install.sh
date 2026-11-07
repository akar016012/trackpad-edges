#!/bin/bash
#
# Builds a Release copy of the app, signs it, and installs it.
#
# Usage: scripts/install.sh [destination folder]
#
# The destination defaults to the Applications folder. The script signs with the project's
# Developer ID identity when it exists, and otherwise with an Apple Development identity. The
# adapter library goes inside the app before signing, so that the app's signature covers it.

set -euo pipefail

root="$(cd "$(dirname "$0")/.." && pwd)"
app_name="Trackpad Edges"
team="3J6QGH6H9F"

mkdir -p "${1:-/Applications}"
destination="$(cd "${1:-/Applications}" && pwd -P)"
target="$destination/$app_name.app"
staged="$destination/.$app_name.new.app"
previous="$destination/.$app_name.old.app"
if [[ ! -w "$destination" ]]; then
  echo "This account cannot write to $destination." >&2
  exit 1
fi

# Signing by hash stays unambiguous when a renewed certificate shares its name with an old one.
identities="$(security find-identity -v -p codesigning)"
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

work="$(mktemp -d)"
trap 'rm -rf "$work" "$staged"' EXIT

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
codesign --force --options runtime "${timestamp[@]}" --sign "$identity" "$framework"
codesign --force --options runtime "${timestamp[@]}" --sign "$identity" "$app"
codesign --verify --strict --deep "$app"

# The new copy is complete and checked before anything that already exists changes.
rm -rf "$staged" "$previous"
ditto "$app" "$staged"
codesign --verify --strict --deep "$staged"

# Only a copy running from the exact target stops, so an Xcode copy keeps running.
executable="$target/Contents/MacOS/$app_name"
running=()
others=0
for pid in $(pgrep -x "$app_name" || true); do
  if lsof -a -p "$pid" -d txt -Fn 2>/dev/null | grep -Fxq "n$executable"; then
    running+=("$pid")
  else
    others=$((others + 1))
  fi
done

# Renames are the only steps here that can fail halfway, and each one can be undone.
if [[ -e "$target" ]]; then
  mv "$target" "$previous"
fi
if ! mv "$staged" "$target"; then
  if [[ -e "$previous" ]]; then
    mv "$previous" "$target"
  fi
  echo "The new copy could not be moved into place, so the old copy stays." >&2
  exit 1
fi
rm -rf "$previous"

if [[ ${#running[@]} -gt 0 ]]; then
  kill "${running[@]}"
  for _ in 1 2 3 4 5 6 7 8 9 10; do
    kill -0 "${running[@]}" 2>/dev/null || break
    sleep 0.2
  done
fi
echo "Installed: $target"

if [[ "$destination" == "/Applications" || ${#running[@]} -gt 0 ]]; then
  open "$target"
  echo "A copy with a new signing identity needs its own Accessibility permission."
fi
if [[ "$others" -gt 0 ]]; then
  echo "Another copy of the app is still running, and both copies act on every gesture." >&2
fi
