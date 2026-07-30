The source viewer: src-viewer.rxl
=================================

[`src-viewer.rxl`](src-viewer.rxl) serves a program's source as a styled HTML
page. Request a source file by its normal URL and Apache routes it through here,
[highlighted](https://rexx.epbcn.com/rexx-parser/) when the Rexx Parser is
installed. This is the piece that makes the site *self-transparent*: follow
enough links and you end up reading RexxHTTP's own classes, served to you by
RexxHTTP.

How it is wired
---------------

Two lines in the Apache config send source files through this rexxlet:

```
Action src-viewer /bin/src-viewer.rxl
AddHandler src-viewer .rex .orx .oryx .cls
```

Request the rexxlet directly — `/bin/src-viewer.rxl` — and it shows its own
source, because it was not reached as the `src-viewer` handler.

What it does
------------

The viewer reads the requested file and, with the Rexx Parser present, produces
a highlighted rendering in the default *dark* style; the code-style chooser in
the banner can then switch styles in the browser. The page title is the file's
own name.

The actual work lives in [`src-viewer.cls`](src-viewer.cls), a single routine
that takes a file and emits it as a page — highlighted when it can, plain text
when it cannot. The rexxlet is a thin stub over it, and the Markdown renderer
calls the very same routine to show *its* own source. One place to serve source,
reused wherever source needs serving.

Why `.rxl` is not wired here
----------------------------

The handler covers source extensions — `.rex`, `.orx`, `.oryx`, `.cls` — but
deliberately **not** `.rxl`. A `.rxl` file is a rexxlet: RexxHTTP runs it, so
requesting one gets you the page it *produces*, not its source. A rexxlet that
wants to show its own source does what this one does — asks the shared routine
for it directly.

Graceful degradation
--------------------

If the Parser is not installed, the viewer does not fail: it serves the raw file
as UTF-8 plain text. The source always arrives, highlighted when it can be and
plain when it cannot.
