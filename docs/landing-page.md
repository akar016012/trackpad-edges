# Landing page

Status: the sections below the hero were rebuilt on 2026-11-11 and tested at desktop, tablet, and phone sizes in one browser. The hero is unchanged. The page publishes to https://trackpad.adiworks.dev.

## What it is

`site/` holds a static page with no build tools. The hero is a working trackpad: the left edge dims the demo, the right edge steps a volume readout, the bottom edge seeks a track, and the corners press. When the page opens, the volume strip ticks up to its level with a small pulse on each step, unless the visitor prefers reduced motion. A web page cannot drive a Mac's trackpad haptics, so this is visual. All of it works by keyboard too. Keep the full-screen trackpad hero.

Below the hero, the page lists the nine edge actions, shows the haptics render, and gives a look around the settings with one screenshot for each of the Edges, Corners, Media, Haptics, and Profiles tabs and for the welcome tour. On a screen wider than 900 pixels, `site/main.js` turns the six headings into buttons that switch one screenshot beside the list. On a smaller screen, or without scripts, every screenshot sits under its own text. The launch film plays in a section of its own and loads only when the visitor starts it. The questions open and close, and the download section ends with three steps for installing the app.

The font is stored in `site/fonts/` under its open font license, and the page makes one request to another site, which reads the public releases list for the download count. That host sees the visitor's IP address, but the request carries no referrer and no cookies.

## Adding a build

The download shows a coming soon button until a release exists. Each deploy reads the newest release and fills `url` and `version` in the published copy of `site/main.js`, and the copy in the repository stays empty. The download section then links to the file, and the hero button keeps leading there, so that visitors see the requirements first. The [release workflow](releasing.md) does this by itself.

The download section also shows how many times every version's DMG has been downloaded. `site/main.js` reads that total from the public releases list in the visitor's browser, keeps it for ten minutes, and leaves it hidden when the request fails or the total is 0.

## Search engines

The page's title and description name what people search for: a free Mac app for volume and brightness on the trackpad. The page declares its canonical address, and a `SoftwareApplication` block in the page head describes the app as free software for macOS on Apple silicon. That block has no rating, because a rating must come from real reviews. Search results can show richer app details only after the page has such reviews.

`site/robots.txt` allows every crawler and points to `site/sitemap.xml`, which lists the one page. After each deploy, `.github/workflows/pages.yml` sends the page's address to IndexNow, which passes it to the search engines that take part. `site/9a65610ca2f8f1bb7a90909a043d3a57.txt` holds the key that proves the request comes from this site. The key is public by design, and it must stay in place while the workflow uses it.

Registering the site with each search engine's own webmaster tools needs the maintainer's accounts, so that step happens outside this repository.

## Deploying

`.github/workflows/pages.yml` publishes only `site/`. It also adds `appcast.xml`, the update feed, from the newest release, so that file is not in the repository. It runs on every push to `main` that changes `site/`, after each release, and by hand. The custom domain is set in the repository's Pages settings.

## Updating it

Public text must describe what the app does for the user, and it must not name tools, libraries, or vendors. The README's preview at `docs/images/launch.gif` comes from the film at `site/assets/launch.mp4`, so remake it when the film changes. The film's poster at `site/assets/film-poster.jpg` is a frame from 1.2 seconds into the film, so remake it then too.

The screenshots in `site/assets/` and `docs/images/` were captured from a debug build with example settings, so a new install looks different. The six in `site/assets/` are copies of the ones in `docs/images/`, so update both folders when a tab changes.

The deploy fills the download link by matching the `url` and `version` lines at the top of `site/main.js`, so keep those two lines in their current form. No other line in that file may start with two spaces and `url:` or `version:`.

## Related docs

- [dependencies.md](dependencies.md) lists the page's font and assets.
