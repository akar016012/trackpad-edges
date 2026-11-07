# Releasing

Status: version 1.0 is published, and it was released by hand. Version 1.1 is the first version set to release itself when its version change lands on `main`. No installed copy has updated itself yet.

Releases are automatic. Merging a change that bumps the version to `main` tags the commit, builds and signs the app, notarizes it, publishes a DMG on this repository's Releases page, and points the landing page at the download.

## One-time setup

Create these secrets in the `release` environment, under **Settings > Environments > release**.

| Secret                       | What it holds                                                                                                        |
| ---------------------------- | -------------------------------------------------------------------------------------------------------------------- |
| `MACOS_CERTIFICATE`          | This is the Developer ID Application certificate with its private key, exported as a `.p12` file and base64-encoded. |
| `MACOS_CERTIFICATE_PASSWORD` | This is the password chosen when the `.p12` file was exported.                                                       |
| `NOTARY_API_KEY`             | This is the text of an App Store Connect API key's `.p8` file.                                                       |
| `NOTARY_API_KEY_ID`          | This is that key's ID.                                                                                               |
| `NOTARY_API_ISSUER_ID`       | This is that key's issuer ID.                                                                                        |
| `SPARKLE_PRIVATE_KEY`        | This is the private update key, which signs every update.                                                            |

To make the certificate value, right-click **Developer ID Application** under **My Certificates** in Keychain Access, choose **Export**, save it as a `.p12` file with a password, and then run this command. Delete the file afterward.

```bash
base64 -i certificate.p12 | pbcopy
```

The update key lives in the login keychain, under the account `com.adityakar.trackpad-edges`. Its public half is `SUPublicEDKey` in `Config/Info.plist`. Keep a backup in a password manager, because replacing a lost key needs a recovery release signed with the same Developer ID.

The API key comes from App Store Connect, under **Users and Access > Integrations > App Store Connect API > Team Keys**, and it needs the Developer role.

## Checking the setup

Run the **Mac app** workflow from the Actions tab. It builds, signs, and notarizes the app and the DMG, keeps the DMG as a workflow artifact, and publishes nothing.

## Releasing a version

1. Set `MARKETING_VERSION` in `trackpad-edges.xcodeproj/project.xcproj` to the new version, and raise `CURRENT_PROJECT_VERSION` by one. Installed copies compare this build number, and a release fails if it is not higher than the live one.
2. Add `release-notes/v<version>.md`, with a few lines for people who use the app. A release fails without this file.
3. Update `CHANGELOG.md`.
4. Merge to `main`. The **Release** workflow does the rest.

A version that already has a tag is not released again. To release a version that has no tag yet, run the **Release** workflow from the Actions tab. A release that fails before it publishes leaves no tag, so merge the fix to `main` or run the workflow again. If only the landing page's deploy fails afterward, run **Deploy landing page** from the Actions tab, because running **Release** again changes nothing. A published DMG is never replaced, so a fix after publishing needs a new version. Releases run only from `main`.

## What a release does

1. `release.yml` reads the version and checks that the release notes exist.
2. `mac.yml` runs the tests, and `scripts/build-release.sh` builds the app with the adapter inside it and signs it.
3. The job notarizes and staples the app, and it does the same for the DMG. It then signs the DMG with the update key, checks that signature against the public key inside the built app, and writes `appcast.xml`.
4. The job creates the tag `v<version>` and publishes the release with `appcast.xml` and `TrackpadEdges.dmg`, so the link `releases/latest/download/TrackpadEdges.dmg` always gives the newest version.
5. The job starts the landing page's deploy, which reads the newest release, adds its link to the published copy of `site/main.js`, and publishes its `appcast.xml`. Installed copies learn about a version only at this point, so a release is finished when the deploy is green. A release writes nothing to `main`.

## Automatic updates

Installed copies read `https://trackpad.adiworks.dev/appcast.xml` every 24 hours, which `SUScheduledCheckInterval` sets in `Config/Info.plist`. The first launch checks right away. After that, a check is due at launch once a day has passed since the last one, and again every day while the app runs. **Check for Updates…** checks right away. Only a copy signed with this project's Developer ID checks at all.

Version 1.0 has no updater, so people on 1.0 must download the next version by hand once.

Do not change the bundle ID, the team, or the feed URL, because installed copies would stop finding or accepting updates. A new update key works only in a release signed with the same Developer ID, because that signature is what lets installed copies accept it.

## How the repository is protected

These settings live on GitHub, so this list records what they should be.

- The `main` ruleset blocks force pushes and deletion, and it requires a pull request with a passing `logic-tests` check. Repository administrators can bypass it, because the project has one maintainer.
- The tag ruleset blocks moving or deleting `v*` tags, so a published version keeps pointing at the commit that was built.
- The `release` environment holds the signing and notarization secrets, and only `main` can use it. Pull requests never reach it.
- Workflows can run only GitHub's own actions, each pinned to a commit SHA. Their default token can only read, and each job asks for what it needs.
- Automated updates watch the actions and the DMG tool, but not the app's Swift package. A routine update waits seven days before it is proposed, and a security update does not wait. The tool's lockfile, `.github/dmg/package-lock.json`, fixes every package, because the tool runs while the signing key is open.
- Secret scanning with push protection, dependency alerts, private vulnerability reporting, and code scanning for workflows and JavaScript are all on. Code scanning does not cover Swift, because that needs a build on a runner with this project's Xcode.

## Related docs

- [roadmap/installed-build.md](roadmap/installed-build.md) explains how the signed build works.
- [landing-page.md](landing-page.md) describes the public page.
