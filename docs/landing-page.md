# Landing page

Status: the page is built and tested at desktop and phone sizes. It publishes to https://trackpad.adiworks.dev.

## What it is

`site/` holds a static page with no build step. The hero is a working trackpad: the left edge dims the demo, the right edge steps a volume readout, the bottom edge seeks a track, and the corners press. When the page opens, the volume strip ticks up to its level with a small pulse on each step, unless the visitor prefers reduced motion. A web page cannot drive a Mac's trackpad haptics, so this is visual. All of it works by keyboard too. The page loads nothing from other sites, because the font is stored in `site/fonts/` under its open font license.

## Adding a build

The download is a placeholder until a build exists. Set `url`, and optionally `version`, in the `release` object at the top of `site/main.js`. The download section then links to the file, and the hero button keeps leading there, so that visitors see the requirements first. The [release workflow](releasing.md) does this by itself.

## Deploying

`.github/workflows/pages.yml` publishes only `site/`. It runs on every push to `main` that changes `site/`, and it can also run by hand. The custom domain is set in the repository's Pages settings.

## Updating it

Public text must describe what the app does for the user, and it must not name tools, libraries, or vendors. The README's preview at `docs/images/launch.gif` comes from the film at `site/assets/launch.mp4`, so remake it when the film changes. The screenshots in `site/assets/` and `docs/images/` were captured from a debug build with example settings, so a new install looks different. Update them when a tab changes.

## Related docs

- [dependencies.md](dependencies.md) lists the page's font and assets.
