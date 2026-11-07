# Landing page

Status: the page is built and tested at desktop and phone sizes. It publishes to https://trackpad.adiworks.dev.

## What it is

`site/` holds a static page with no build tools. The hero is a working trackpad: the left edge dims the demo, the right edge steps a volume readout, the bottom edge seeks a track, and the corners press. When the page opens, the volume strip ticks up to its level with a small pulse on each step, unless the visitor prefers reduced motion. A web page cannot drive a Mac's trackpad haptics, so this is visual. All of it works by keyboard too. The font is stored in `site/fonts/` under its open font license, and the page makes one request to another site, which reads the public releases list for the download count. That host sees the visitor's IP address, but the request carries no referrer and no cookies.

## Adding a build

The download shows a coming soon button until a release exists. Each deploy reads the newest release and fills `url` and `version` in the published copy of `site/main.js`, and the copy in the repository stays empty. The download section then links to the file, and the hero button keeps leading there, so that visitors see the requirements first. The [release workflow](releasing.md) does this by itself.

The download section also shows how many times every version's DMG has been downloaded. `site/main.js` reads that total from the public releases list in the visitor's browser, keeps it for ten minutes, and leaves it hidden when the request fails or the total is 0.

## Deploying

`.github/workflows/pages.yml` publishes only `site/`. It also adds `appcast.xml`, the update feed, from the newest release, so that file is not in the repository. It runs on every push to `main` that changes `site/`, after each release, and by hand. The custom domain is set in the repository's Pages settings.

## Updating it

Public text must describe what the app does for the user, and it must not name tools, libraries, or vendors. The README's preview at `docs/images/launch.gif` comes from the film at `site/assets/launch.mp4`, so remake it when the film changes. The screenshots in `site/assets/` and `docs/images/` were captured from a debug build with example settings, so a new install looks different. Update them when a tab changes.

## Related docs

- [dependencies.md](dependencies.md) lists the page's font and assets.
