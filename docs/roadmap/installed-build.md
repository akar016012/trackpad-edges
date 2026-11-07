# Installed build

Status: the install script and the signed adapter are built, and a signed copy passes `codesign --verify --strict --deep`. The script has only been run into a test folder, so a real install and a real login still need a check.

## Goal

The app should run from the Applications folder as a signed Release build, rather than from Xcode. That makes launch at login reliable, and it moves the media adapter inside the signed app.

## Behavior

- `scripts/install.sh` uses `scripts/build-release.sh` to build and sign a Release copy, and it installs that copy in the Applications folder.
- The Accessibility permission should survive later installs, because the signing identity stays the same.
- Launch at login should be turned on from the installed copy, because a registration from an older copy can point somewhere else.

## How it works

1. The script looks for the project's Developer ID identity first, and it signs by hash so that a renewed certificate is never ambiguous. Without one, it warns you and falls back to an Apple Development identity.
2. It builds without signing, because the app must be signed after the adapter goes inside it.
3. It decodes the base64 text into a real `MediaRemoteAdapter.framework` in `Contents/Frameworks`, and it removes the text from the app. It stops if the library needs a newer macOS than the app supports, because such a library would not load there.
4. It signs the framework and then the app with the Hardened Runtime. A Developer ID build also gets a secure timestamp.
5. It copies and verifies the new app beside the old one before it changes anything. Two renames then swap the copies, and a failed rename puts the old copy back.
6. It stops only a copy that is running from the exact destination, so an Xcode copy keeps running. It warns you when another copy is left running, because both copies act on every gesture.
7. `NowPlayingAdapter` uses the library inside the app when it finds one, and it deletes any writable copy left in Application Support. A build run from Xcode has no such library, so it unpacks one and restores it if another copy removed it.

## Trust

Perl does not validate what it loads, and the installed app is still in a folder that your account can write to. The signature therefore protects the library only because the app checks it. Before each adapter run, the app validates its whole bundle against the project's signing requirement with `SecStaticCodeCheckValidity`. That covers the library and the Perl script, and a failed check stops media seek. A short gap remains between the check and the load, as there was with the byte check it replaces.

The script does not notarize the app, because a copy that you build and install on your own Mac is not quarantined. The [release workflow](../releasing.md) notarizes the copies that people download.

## Risks

- The copy in the Applications folder may be replaced by an unnotarized one, which has not been tried through a real launch and login.
- macOS may refuse to let a script replace an app in the Applications folder. The script then keeps the old copy, and the terminal may need the App Management permission.
- The Xcode copy and the installed copy share a bundle identifier but use different identities, so Accessibility may need granting again when you switch between them.

## Verification

- A signed test copy passes `codesign --verify --strict --deep`, and the system Perl loads the signed adapter from inside it.
- The signature check accepts a signed test copy, and it refuses that copy once its library or its Perl script changes.
- After a real install and a restart, the app should run with no window, and every gesture should work.

## Related docs

- [media-seek.md](../media-seek.md) describes the adapter and its current protection.
- [menu-bar-and-onboarding.md](../menu-bar-and-onboarding.md) describes login behavior.
