# Installed build

Status: this feature is planned for phase 5.

## Goal

The app should run from the Applications folder as a signed Release build, rather than from Xcode. That makes launch at login reliable, and it closes the main security gap in media seek.

## Behavior

- A script builds a Release copy and installs it in the Applications folder.
- Launch at login points at the installed copy.
- The Accessibility permission survives updates, because the signing identity stays the same.

## Implementation plan

1. Add a build and install script, and document it in the README.
2. Sign with the Developer ID identity, and turn on hardened runtime only after confirming that loading the private frameworks still works.
3. Move the adapter library inside the signed app, so that the app's signature covers it. This needs a build step that decodes the base64 before signing, and it removes the writable copy in Application Support.
4. Confirm that the window stays closed at login, which has not been tested with a real login.

## Risks

- A build step in the new project format is untested. If it fails, the current unpacking and byte check stay in place.
- A Developer ID build needs its own Accessibility grant, so the first launch asks again.
- Hardened runtime may block the private frameworks.

## Verification

- The installed copy passes `codesign --verify --strict`.
- After a restart, the app runs with no window, and every gesture works.

## Related docs

- [media-seek.md](../media-seek.md) describes the adapter and its current protection.
- [menu-bar-and-onboarding.md](../menu-bar-and-onboarding.md) describes login behavior.
