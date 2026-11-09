# Settings export and import

Status: this feature is planned, and none of it is built yet.

## Goal

You should be able to save your settings to a file and load them again. That lets you move your setup to a new Mac, keep a backup before you experiment, and share a profile with someone else.

## Behavior

- **Export Settings…** saves every setting, including profiles, to a file that you name.
- **Import Settings…** reads a file, shows a summary of what it would change, and replaces your settings only after you confirm.
- The summary lists every corner action that opens something, presses keys, or runs a shortcut, so that a shared file cannot hide what it will do.
- An app, file, or browser that a corner refers to but that does not exist on this Mac is marked in the summary, and that corner stays a normal part of the trackpad until you choose again.
- The settings from before the import are kept, and **Undo Import** restores them until the app quits.
- A file from a newer version of the app imports what this version understands, and the summary says that some settings were skipped.

## Settings

The General pane gains a **Settings** row with **Export…** and **Import…** buttons. The file uses the extension `.trackpadedges`, and it is plain JSON, so it can be read and compared.

## Implementation plan

1. Add a small wrapper around `AppSettings` that records a format version and the app version that wrote the file.
2. Encode it with `JSONEncoder` using sorted keys and pretty printing, so that two exports can be compared line by line.
3. Decode imports with the same rules that saved settings already use, so that a missing value takes its default, a value from a newer version falls back by itself, and numbers are held to their ranges.
4. Build the summary by comparing the imported settings with the current ones, and check every path with `FileManager`.
5. Keep the previous settings in memory for **Undo Import**, and keep the current copy under a separate defaults key, as `settings.unreadable` already does for unreadable data.
6. Declare the file type in `Info.plist`, so that Finder shows the app's icon and a double click opens the import summary.

## Risks

- A file holds file paths, links, and shortcut names, which can be personal. The export dialog should say so before you share one.
- A file from someone else could set a corner to open a link or press keys. The summary and the confirmation are the defense, so they must list those actions plainly.

## Verification

- Unit tests cover a round trip, a file with missing keys, a file from a newer version, a file that is not valid, and the summary of changes.
- By hand, an export from one Mac imports on another, and a missing app is marked.

## Related docs

- [settings.md](../settings.md) describes every setting.
- [per-app-profiles.md](per-app-profiles.md) describes how profiles are stored.
