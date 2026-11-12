#!/bin/bash
#
# Builds a Release copy of the app, signs it, and installs it.
#
# Usage: scripts/install.sh [destination folder]
#
# The destination defaults to the Applications folder. scripts/build-release.sh does the build
# and signing, and this script swaps the new copy in.

set -euo pipefail

root="$(cd "$(dirname "$0")/.." && pwd)"
app_name="Trackpad Edges"

mkdir -p "${1:-/Applications}"
destination="$(cd "${1:-/Applications}" && pwd -P)"
target="$destination/$app_name.app"
staged="$destination/.$app_name.new.app"
previous="$destination/.$app_name.old.app"
if [[ ! -w "$destination" ]]; then
  echo "This account cannot write to $destination." >&2
  exit 1
fi

work="$(mktemp -d)"
trap 'rm -rf "$work" "$staged"' EXIT
"$root/scripts/build-release.sh" "$work/app"
app="$work/app/$app_name.app"

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
  # This waits up to two seconds, so that open launches the new copy, not the old one.
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
