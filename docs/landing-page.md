# Landing page

Status: the page is built and tested locally at desktop and phone sizes, but it is not deployed. The repository is private, and nothing has been published.

## What it is

`site/` holds a static page with no build step. The hero is a working trackpad: the left edge dims the demo, the right edge steps a volume readout, the bottom edge seeks a track, and the corners press. All of it works by keyboard too. The page loads nothing from other sites, because the font is stored in `site/fonts/` under its open font license.

## Adding a build

The download is a placeholder until a build exists. Set `url`, and optionally `version`, in the `release` object at the top of `site/main.js`. The download section then links to the file, and the hero button keeps leading there, so that visitors see the requirements first. Sharing a build needs notarization, as [installed-build.md](roadmap/installed-build.md) explains.

## Deploying

`.github/workflows/pages.yml` publishes only `site/`, and it runs by hand until GitHub Pages is turned on. Making this repository public would also publish these internal notes, so do that only after they are cleaned up for open source.

1. Choose where the page lives. Pages can run from this private repository on a plan that allows it, or from a separate public repository that holds only `site/`. The published page is public in both cases.
2. In the repository settings, set the Pages source to **GitHub Actions**.
3. Set `og:image` in `site/index.html` to the full address of `assets/share.jpg`, because link previews need an absolute address. Add an `og:url` tag with the page's address.
4. Run the **Deploy landing page** workflow.

All other links in the page are relative, so it works at a project address and on a custom domain. A project address shows your account and repository name, and only a custom domain avoids that.

## Before it goes live

The more edge actions, two-finger slides, and profiles are on the page, but they have not all been confirmed on a trackpad. Confirm them first, or take them off the page.

## Updating it

Public text must describe what the app does for the user, and it must not name tools, libraries, or vendors. The screenshots in `site/assets/` were captured from a debug build with temporary settings. Update them when the Edges or Profiles tab changes.

## Related docs

- [dependencies.md](dependencies.md) records where the dark band render came from.
