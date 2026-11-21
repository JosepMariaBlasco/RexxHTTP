How This Site Works
===================

This is a document about the architecture of the site you are reading it on.
It assumes you have read [the manual](rexxhttp.pdf) and have met the
[three utilities](bin/) that ship with the package — the page factory, the
Markdown renderer and the source viewer. If you have not, what follows will
still make sense, but it will read like the description of machinery you have
never seen running.

The short version is that this site is *self-documenting* and
*self-transparent*. Self-documenting, because every page you can visit is a
page whose source you can also read. Self-transparent, because that includes
the processor itself: follow enough links and you end up reading RexxHTTP's own
classes, highlighted, served to you by RexxHTTP.

That is a pleasant trick, and it is worth saying at once that **it is not the
usual arrangement, and not the one we recommend**. A site does not normally
publish its own source. We do it here on purpose, and for teaching: a package
whose whole claim is that your programs are ordinary Rexx programs ought to let
you look at the programs. What follows is the arrangement that makes it
possible — and, at the end, what you would take back out before trying anything
like it on a site that matters.

What transparent means here
---------------------------

Concretely, on this site you can:

- visit [the home page](./) and then read
  [the program that produced it](home-page.rex);
- run any of [the examples](examples/) and read its source next to it;
- read [the page factory](bin/HTML.Page.cls) that gives every page on the site
  its frame, including this one;
- visit the [Markdown renderer](bin/markdown.rxl) and the
  [source viewer](bin/src-viewer.rxl), which greet you with a page about
  themselves;
- and read [the processor itself](src/) — all four classes and the main
  program — as ordinary highlighted source.

That last one is the part that surprises people. The page you are reading is
Markdown, turned into HTML by a rexxlet, wrapped in a frame by a class, and
delivered by a processor whose source is one click away. Nothing here is a
mock-up of a running system; it is the running system, showing you its
own parts.

Why this is not free
--------------------

Apache decides what to do with a file from its extension. An extension can be
wired to a handler that *runs* the file, or to one that *shows* it, but not to
both. So the two halves of what we just described pull in opposite directions.

Wire `.rex` to the processor and every `.rex` under the document root becomes
executable by URL. That is not a small thing: this site ships the whole of
`src/` as readable text, so the processor's own source would become a set of
entry points, and so would every example, and so would any `.rex` an operator
ever dropped into the tree. Wire `.rex` to the viewer instead, and the danger
goes away — but now nothing written in a `.rex` file can run at all, and the
site has no pages.

The way out is not to choose. It is to stop asking one file to do both jobs.

The trick: two names for every page
-----------------------------------

Every page on this site exists as **two files**.

The first is the program, and it carries a source extension:

```rexx
/* home-page.rex — the real program, some fifty lines of it */
.response~content_type = "text/html"
.HTML.Page~new("RexxHTTP")~done
::Requires "HTML.Page.cls"
::Resource BODY
  ...
::END
```

The second is a wrapper, and it carries the rexxlet extension. It is one line
long, and this is all of it:

```rexx
Call "home-page.rex"
```

`.rxl` is wired to RexxHTTP, so the wrapper runs. `.rex` is wired to the
viewer, so the program is shown. The wrapper reaches its program through the
file system, with an ordinary `Call`, which the web server has no say in; the
program is never reachable *as a program* from outside.

The whole site is built this way, and the arithmetic is the point. There are
ten wrappers in the entire tree — one at the root, one for the examples index,
and one per example — and each is a single `Call`. **The executable surface of
this site is ten lines, each of them written by hand, on purpose.** Everything
else in the tree, however much of it there is, is text that can be read and
nothing else.

The second step: directory indexes
----------------------------------

The wrappers are also what makes a bare directory URL work. The configuration
declares three index names:

```
DirectoryIndex wrapper.rxl index.rxl readme.md
```

They fall into two kinds. `wrapper.rxl` and `index.rxl` are rexxlets, so asking
for a directory *runs* its page: that is why [`examples/`](examples/) gives you
the examples index rather than a list of folders. (`index.rxl` is accepted as
an alternative name; no directory on this site currently uses it.)

`readme.md` is the documentary fallback, and it covers the directories that
have no page to run. [`bin/`](bin/) and [`src/`](src/) are both like this:
neither has a wrapper, so Apache falls through to the readme, and the Markdown
renderer turns it into a page in the site's own frame. The directory ends up
with an index anyway — a written one instead of a generated one.

So every directory of this site answers with something somebody wrote, rather
than with a generated listing — not because listings were switched off, but
because there is always a better answer available before Apache gets that far.
Four directories take the readme route (`bin/`, `src/`, `css/` and `js/`), ten
take the wrapper route, and none of them falls through.

The same folder, in two places
------------------------------

`src/` is worth its own note, because the automated installer plants it
**twice** (a custom installation can of course keep just one copy, if it
prefers).

One copy goes into Apache's `cgi-bin`, which is where the processor actually
runs from: the `Action RexxHTTP /cgi-bin/RexxHTTP.rex` line points there, and
nothing under `cgi-bin` is meant to be requested by anybody — it is only the
address the handler dispatches through.

The other copy goes under the document root, where the viewer serves it as
text. That is the one you can read.

They are the same files with two destinations, and the effect is nicer than it
sounds: when you open [`HTTP.Response.cls`](src/HTTP.Response.cls) and read how
the response is committed on the first flush, the program showing it to you is
that file's twin, running from `cgi-bin`, committing this very response on its
first flush.

The three utilities, and what they do without
---------------------------------------------

Three files in [`bin/`](bin/) make the rest of it work. None of them is part of
RexxHTTP — the processor does not know they exist — and all three are meant to
be read and copied.

- [`HTML.Page.cls`](bin/HTML.Page.cls) gives every page its frame: the head,
  the header, the footer, the stylesheet links and the code-style chooser.
- [`markdown.rxl`](bin/markdown.rxl) turns any `.md` file on the site into a
  styled page. It is what is rendering the document you are reading.
- [`src-viewer.rxl`](bin/src-viewer.rxl) serves program source as a highlighted
  page. It is what shows you everything the previous sections invited you to
  look at.

The last two are wired through Apache `Action` directives, and each is also a
page in its own right: visit either one directly and it explains itself instead
of doing its job.

What they have in common is that neither insists on its tools. The renderer
uses [Pandoc](https://pandoc.org/) when Pandoc is installed and serves the raw
Markdown as plain UTF-8 text when it is not. Both it and the viewer use the
[Rexx Parser](https://rexx.epbcn.com/rexx-parser/), which ooRexx carries, for
highlighting when they find it, and emit unhighlighted text when they do not — which is why
both of them load their highlighting class dynamically rather than with
`::Requires`, a directive for a missing file being fatal at load time. And
underneath both, the
configuration carries `AddType`/`AddCharset` lines for the same extensions, so
that if you removed the two rexxlets altogether Apache would still serve those
files inline as UTF-8 rather than offering them as downloads.

The site degrades three times over and keeps serving every document. That is
deliberate, and it is the part most worth copying.

Before you do this anywhere real
--------------------------------

Everything above is a teaching arrangement. On a site that matters, here is
what you would take back out, and why.

**Take out the viewer first.** The line that enables it reads

```
AddHandler src-viewer .rex .rexx .cls .orx .oryx
```

and it is declared for the whole document-root `<Directory>` — not for a list
of files, and not for the examples folder. It publishes *any* file with one of
those extensions that is under the root, now or at any point in the future.
Here that is deliberate and everything under the root is meant to be public.
Somewhere else, it is the mechanism by which a class file that somebody left in
the tree without thinking about it becomes a published document.

**Then take out the readable copy of `src/`.** In production the processor only
needs to exist in `cgi-bin`, where it runs. The copy under the document root
exists solely so you can read it. While you are there, `Options -Indexes` is
worth adding: every directory here happens to carry an index, but that is a
property of this tree today, not a guarantee about the next directory somebody
creates.

**Then reconsider the wrappers.** They earn their keep only because we wanted
the program to be readable. If you do not, put the code straight into the
`.rxl` and drop the second file; one rexxlet per page is the ordinary way to
work, and the manual's [tutorial](rexxhttp.pdf) is written that way throughout.

One distinction to keep, though, because it is the thing that makes all of this
defensible in the first place: **opening an extension to the viewer is not
opening it to the processor**. Asking for one of those five extensions never
runs anything: the file is read from disk and written back out as text. A
`.rex` does of course run — that is what the wrappers are for — but it runs
because a program called it, never because somebody requested it. `.rxl` is
deliberately absent from the viewer's list, for the mirror-image reason: a
rexxlet is run by RexxHTTP, never shown as source. The whitelist principle the
manual argues for is intact throughout: on this site, as on any other, the only
files that run as code are the ones named to run as code. Here there happen to
be ten of them, and you can read all ten.
