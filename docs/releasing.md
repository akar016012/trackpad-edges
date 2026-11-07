# Releasing

Status: the workflows are written, but no release has run yet. The first run is a dry run from the Actions tab, once the secrets below exist.

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

To make the certificate value, right-click **Developer ID Application** under **My Certificates** in Keychain Access, choose **Export**, save it as a `.p12` file with a password, and then run this command. Delete the file afterward.

```bash
base64 -i certificate.p12 | pbcopy
```

The API key comes from App Store Connect, under **Users and Access > Integrations > App Store Connect API > Team Keys**, and it needs the Developer role.

`main` must accept pushes from workflows, because a release commits the new download link to it.

## Checking the setup

Run the **Mac app** workflow from the Actions tab. It builds, signs, and notarizes the app and the DMG, keeps the DMG as a workflow artifact, and publishes nothing.

## Releasing a version

1. Set `MARKETING_VERSION` in `trackpad-edges.xcodeproj/project.xcproj` to the new version, and raise `CURRENT_PROJECT_VERSION` by one.
2. Add `release-notes/v<version>.md`, with a few lines for people who use the app. A release fails without this file.
3. Update `CHANGELOG.md`. For the first release, also change the Install section of the README to link the download.
4. Merge to `main`. The **Release** workflow does the rest.

A version that already has a tag is not released again. To ship the current version for the first time, run the **Release** workflow from the Actions tab. A failed release leaves no tag, so merge the fix to `main` or run the workflow again. Releases run only from `main`.

## What a release does

1. `release.yml` reads the version and checks that the release notes exist.
2. `mac.yml` runs the tests, and `scripts/build-release.sh` builds the app with the adapter inside it and signs it.
3. The job notarizes and staples the app, and it does the same for the DMG.
4. The job creates the tag `v<version>` and publishes the release with `TrackpadEdges.dmg`, so the link `releases/latest/download/TrackpadEdges.dmg` always gives the newest version.
5. The job sets `url` and `version` in `site/main.js`, and it deploys the landing page.

The app has no automatic updates, so people download a new version themselves.

## Related docs

- [roadmap/installed-build.md](roadmap/installed-build.md) explains how the signed build works.
- [landing-page.md](landing-page.md) describes the public page.
