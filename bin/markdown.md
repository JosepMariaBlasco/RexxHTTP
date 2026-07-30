The Markdown renderer: markdown.rxl
===================================

[`markdown.rxl`](markdown.rxl) turns any `*.md` file in the site into a styled
HTML page. Request a markdown file by its normal URL and Apache routes it
through here; the [page factory](HTML.Page.cls) wraps the result in the site
chrome.

How it is wired
---------------

Two lines in the Apache config send every `.md` through this rexxlet:

```
Action markdown /bin/markdown.rxl
AddHandler markdown .md
```

Request the rexxlet directly — `/bin/markdown.rxl` — and it shows its own
source instead of rendering, because it was not reached as the `markdown`
handler.

What it does
------------

The renderer reads the requested file and hands it to
[Pandoc](https://pandoc.org), which converts the markdown to HTML. The page
title is taken from the document's first `<h1>`: a file that opens with
`# Getting started` becomes the page *Getting started*. A document with no
top-level heading gets a loud `*** missing title ***` instead — a nudge to the
author to add one.

If the [Rexx Parser](https://rexx.epbcn.com/rexx-parser/) is installed, the
renderer highlights any ` ```rexx ` fenced blocks *before* handing the document
to Pandoc. Pandoc passes embedded HTML through untouched, so the highlighted
blocks survive into the final page, and the code-style chooser in the banner can
restyle them. Without the Parser the fences render as plain `<pre><code>` and
the page is served all the same.

Graceful degradation
--------------------

If Pandoc is not present, the renderer does not fail: it serves the raw markdown
file as UTF-8 plain text. The document always arrives, rendered when it can be
and readable when it cannot.
