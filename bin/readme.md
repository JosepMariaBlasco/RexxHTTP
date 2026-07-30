The utilities behind the site
=============================

This directory holds the three example rexxlets that give the site its shape.
Each one is a small, self-contained program you can read, copy, and adapt — and
each is documented on its own page, with a link straight to its source.

- **The page factory** — wraps a body in the shared header, footer and
  stylesheet, so no page repeats the chrome.
  [About it](html-page.md) · [Source](HTML.Page.cls)

- **The Markdown renderer** — turns any `.md` file into a styled page with
  Pandoc, and serves it verbatim when Pandoc is absent.
  [About it](markdown.md) · [Source](markdown.rxl)

- **The source viewer** — serves the source of any Rexx file as a highlighted
  page. It is what lets the site show its own code.
  [About it](src-viewer.md) · [Source](src-viewer.rxl)

The viewer's work actually lives in a small shared class,
[`src-viewer.cls`](src-viewer.cls) — one routine that serves a file as source,
reused by the viewer and by the Markdown renderer alike.

For how these fit together into a site that documents and serves itself, see
[How this site works](../architecture.md).
