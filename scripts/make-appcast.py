#!/usr/bin/env python3
"""Writes the update feed for one release.

Usage: scripts/make-appcast.py <version> <build> <minimum macOS> <download URL> <length>
       <signature> <release notes> <output>

The release job signs the DMG and passes the results here. The feed lists only the newest version,
because an installed copy needs nothing older.
"""

import html
import sys
from email.utils import formatdate
from xml.sax.saxutils import escape, quoteattr


def notes_html(markdown):
    """Turns release notes, which hold only paragraphs and one-level lists, into HTML."""
    parts = []
    items = []

    def close_list():
        if items:
            parts.append("<ul>" + "".join(items) + "</ul>")
            items.clear()

    for line in markdown.splitlines():
        line = line.strip()
        if line.startswith("- "):
            items.append("<li>" + html.escape(line[2:]) + "</li>")
            continue
        close_list()
        if line:
            parts.append("<p>" + html.escape(line) + "</p>")
    close_list()
    return "".join(parts)


def make_feed(version, build, minimum, url, length, signature, notes):
    return f"""<?xml version="1.0" encoding="utf-8"?>
<rss version="2.0" xmlns:sparkle="http://www.andymatuschak.org/xml-namespaces/sparkle">
  <channel>
    <title>Trackpad Edges</title>
    <item>
      <title>Version {escape(version)}</title>
      <pubDate>{formatdate(usegmt=True)}</pubDate>
      <sparkle:version>{escape(build)}</sparkle:version>
      <sparkle:shortVersionString>{escape(version)}</sparkle:shortVersionString>
      <sparkle:minimumSystemVersion>{escape(minimum)}</sparkle:minimumSystemVersion>
      <description>{escape(notes_html(notes))}</description>
      <enclosure url={quoteattr(url)} length={quoteattr(length)} type="application/octet-stream" sparkle:edSignature={quoteattr(signature)}/>
    </item>
  </channel>
</rss>
"""


def main():
    if len(sys.argv) != 9:
        sys.exit(__doc__)
    version, build, minimum, url, length, signature, notes_path, output = sys.argv[1:]
    with open(notes_path, encoding="utf-8") as file:
        notes = file.read()
    feed = make_feed(version, build, minimum, url, length, signature, notes)
    with open(output, "w", encoding="utf-8") as file:
        file.write(feed)


if __name__ == "__main__":
    main()
