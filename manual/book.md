---
title: "RexxHTTP: Servlet programming in Rexx"
author: Josep Maria Blasco
date: TODO month 2026
lang: en
rexxpub:
  docclass: book
  section-numbers: 2
  number-figures: true
  outline: 3
---

<!--
  ============================================================================
  RexxHTTP manual — book.md (RexxPub `book` document class)
  ============================================================================

  STATUS: PLACEHOLDER. Skeleton only. Each chapter carries a TODO note
  describing what goes there. Fill in a fresh session (item 8).

  AUTHORING RULES (decided in the v8 architecture session — see handoff):

  1. This is the SUCCESSOR of the 2006 PDF manual,
     https://www.epbcn.com/pdf/josep-maria-blasco/2006-11-02-RexxHttp-Servlet-programming-in-Rexx.pdf
     distilled — not copied — to what the 1.0 actually is.

  2. DROPPED for good (do NOT bring across from the 2006 manual):
       - mod_rexx, OS/2, Microsoft IIS
       - RSP / RSPCOMP / REXXTAGS / page compiler interface
       - the "Writing portable servlets" chapter (it existed for mod_rexx)
       - the CPL license appendix (now Apache 2.0)

  3. CLASS REFERENCE RULE (critical, invariant 5 applied to the docs):
     every method entry in chapter 5 is written by READING THE ACTUAL .cls
     ON DISK and verifying signature + behaviour against the code. The 2006
     PDF is used ONLY for rationale/prose, never as the source of truth for
     what a method does. (The 2006 manual documents an `rc` that no longer
     exists, Netscape/Version cookies that are gone, etc.) Code is the
     state; the manual is the spec.

  4. Rexx code goes in ```rexx fenced blocks — the Rexx Highlighter renders
     them. Shell/Apache/config go in plain ``` blocks.

  5. COMPILATION is done OUTSIDE this container by JMB (pagedjs-cli does not
     run well here). Claude writes the .md; JMB renders, or uploads the
     HTML/PDF for Claude to load and review.

  6. RexxPub `book` defaults already set above: size 12, section-numbers 2.
     Chapters use {.chapter} on an H1; parts use {.part}; the ToC is the
     {#toc} div below; the running-header book title is the {.book-title}
     span in the title page H1.
  ============================================================================
-->

::::: title-page

[RexxHTTP]{.book-title} <small>Servlet programming in Rexx</small>
==================================================================

::: author
Josep Maria Blasco
:::

::: affiliation
Espacio Psicoanalítico de Barcelona
:::

::: date
TODO month 2026
:::

:::::


::: {#toc .toc-exclude}

## Contents {.toc-exclude}

:::


Introduction {.chapter}
=======================

RexxHTTP is a servlet processor for ooRexx. It runs as a CGI program
under the Apache HTTP server: Apache hands it an incoming request, and
RexxHTTP turns the raw CGI environment into a small set of objects, runs
your servlet against them, and writes the result back as an HTTP
response. A servlet is an ordinary ooRexx program, so the whole of
ooRexx is available to it, with the HTTP request and the response it is
about to build handed in as objects rather than scraped out of
environment variables by hand.

For each request RexxHTTP builds three objects. A **request** object
exposes the request line, the headers and the GET/POST arguments through
named methods, decoding percent- and plus-escapes for you. A
**response** object collects the status line and the response headers
and lets you attach cookies. And an **output stream** receives the body:
it is a buffering subclass of the built-in `Stream` class, and that
buffering is what makes the response headers *lazy* — you may keep
changing status, headers and cookies after you have already started
writing the body, right up until the response is committed. The request
and the response reach the servlet as the `.request` and `.response`
objects, placed in the environment by RexxHTTP; the body is produced
with ordinary `Say` or `CharOut` instructions. (A servlet may also pick
the two objects up with `Use Arg request, response`; both ways are
official, but going through `.request` and `.response` is the more
robust of the two.) The response is committed on the first flush — and
that first flush is either one the servlet triggers itself, by calling
`flush` (for instance to send an early partial response), or the one
RexxHTTP performs automatically when the servlet ends. This is the
central idea of the design, and the chapter [The request/response model]
returns to it in detail.

RexxHTTP requires ooRexx 5.3.0 or later. It is released under the Apache
License 2.0 and published at <https://rexx.epbcn.com> and on GitHub.

A short historical note. RexxHTTP first appeared in 2006 as a more
ambitious thing: alongside CGI it supported mod_rexx, ran on OS/2 and
Windows as well as Unix, was meant to work under Microsoft IIS, and
defined a Rexx Server Pages compiler interface for mixing HTML and Rexx
in a single page. None of that survives in the 1.0. This release is
CGI-on-Apache only — no mod_rexx, no IIS, no OS/2, no page compilers —
and the manual describes only what the 1.0 actually does, verified
against the code and against a live Apache. The 2006 manual[^manual-2006]
remains the record of the wider original; this one is deliberately
narrower, and says so plainly rather than promising features the
released code no longer carries.

[^manual-2006]: Josep Maria Blasco, *RexxHttp: Servlet programming in
Rexx*, version 0.1, 2 November 2006:
<https://www.epbcn.com/pdf/josep-maria-blasco/2006-11-02-RexxHttp-Servlet-programming-in-Rexx.pdf>.


Installation {.chapter}
=======================

<!--
  DRAFT (v20). RexxHTTP-specific install matter for an Apache-savvy
  reader. The prerequisite install line and the smoke test were run live
  in the container; the handler/whitelist directives mirror
  tests/http/RunHTTPTests.rex.
  Highlighter: every block here is a plain fence (shell/config), never a
  rexx-tagged fence.
  Scope: assumes an Apache-savvy reader. Covers only RexxHTTP-specific
  matter (the five files, the wrapper/CRLF wrinkle, the handler +
  whitelist directives). No full VirtualHost, no filesystem steps, no
  platform-specific activation (a2ensite etc.) — those are the reader's.
  RHDIR is a placeholder for the sources directory; reconcile naming and
  the example paths with JMB before publishing.
-->

RexxHTTP runs as a CGI program under Apache. This chapter assumes you
already keep an Apache server and know how your platform applies its
configuration; it covers only what is specific to RexxHTTP — which files
make up the package, the one wrinkle in how the processor is invoked,
and the handful of directives that turn a file into a servlet. The
wrinkle is worth understanding rather than copying blindly, so the
chapter explains the *why* alongside the *what*.

Prerequisites
-------------

RexxHTTP needs ooRexx 5.3.0 or later and an Apache 2 server with the
`cgid` and `actions` modules enabled. It also uses `curl` for the smoke
test at the end.

Installing ooRexx itself is outside the scope of this manual; the
interpreter is obtained and installed separately, from the Open Object
Rexx project.[^oorexx-download] RexxHTTP assumes a working `rexx` on the
server and nothing more.

[^oorexx-download]: <https://sourceforge.net/projects/oorexx/>.

On Debian or Ubuntu, Apache and the two modules are:

```
sudo apt-get install -y apache2
sudo a2enmod cgid actions
```

`cgid` is what runs the CGI program; `actions` is what lets you route a
request to a CGI program of your choosing rather than executing the
requested file directly. The next section explains why that matters.

The five sources
----------------

A RexxHTTP installation is five files: the processor, `RexxHTTP.rex`,
and the four classes it requires — `HTTP.Request.cls`,
`HTTP.Response.cls`, `HTTP.OutputStream.cls` and `HTTP.Cookie.cls`. They
are distributed together in the download.[^download] The processor's
`::Requires` directives name the four classes, which ooRexx then locates
by its ordinary search rules, so the classes need only be *reachable*
from the processor — they do not have to sit in the same directory.
Keeping all five together is simply the easy choice, and the one this
chapter makes.

[^download]: <https://rexx.epbcn.com/rexxhttp/rexxhttp-latest.zip>.

Where the five files live is up to you, subject only to ooRexx being
able to reach the classes from the processor. They can sit outside the
document tree, or inside it — at <https://rexx.epbcn.com/rexxhttp/> the
sources are deliberately served as browsable content, the same files
that the processor runs, so the repository can be read online. This is
not a contradiction: whether a file is a servlet or static content is
not a property of the file or of where it sits, but of the
configuration (the next sections build this up). A `.rex` can be served
raw under one path and executed under another. The examples below assume
the five files in a directory `RHDIR` and the wrapper, introduced next,
in a CGI-enabled directory; substitute your own paths.

The wrapper, and why it exists
------------------------------

Here is the wrinkle. The RexxHTTP sources are stored with CRLF line
endings — they are edited on Windows and travel through a shared folder
to the server, and the chapter [Rationale] explains why that choice is
deliberate rather than accidental. A consequence is that the first line
of `RexxHTTP.rex`, its `#!` shebang, ends in a carriage return. If the
kernel tried to `exec` the file directly, it would look for an
interpreter literally named `rexx\r`, fail to find it, and Apache would
report `Exec format error`. ooRexx itself is unbothered by CRLF — it
reads CRLF, LF or mixed sources happily — but the kernel's shebang parser
is not.

The fix is a one-line wrapper. The only file the kernel ever execs is a
tiny Rexx script stored with Unix (LF) line endings, whose entire body
hands control to the processor:

```
#!/usr/bin/env rexx
Call "RHDIR/RexxHTTP.rex"
```

Reached by `Call`, `RexxHTTP.rex` is *loaded by name*, not exec'd by the
kernel, so its CRLF shebang is just an inert comment and ooRexx reads the
CRLF body without complaint. The wrapper is the one file that must be LF
and executable; the five sources stay exactly as shipped.

Telling Apache which files are servlets
---------------------------------------

The `actions` module lets you define a *handler* — a named action backed
by a CGI program — and then hand selected requests to it. RexxHTTP uses
this to route a request at the wrapper instead of at the requested file.
The handler is declared once, pointing at the wrapper through a
`ScriptAlias` that exposes it as an executable CGI:

```
ScriptAlias /rexxhttp-bin/ "RHDIR/"
Action RexxHTTPCGI /rexxhttp-bin/wrapper
```

`ScriptAlias` makes the wrapper runnable under an internal URL path;
`Action` names the handler `RexxHTTPCGI` and binds it to that wrapper.
Nothing under `/rexxhttp-bin/` is meant for the public — it is only the
address the handler dispatches through.

With the handler defined, you decide which files are servlets. The
recommended model — the reasoning is in the [Rationale] chapter — is a
**whitelist**: a file is a servlet only when you say so explicitly, and
everything else is served as ordinary static content. You whitelist a
file by handing it to the handler with `SetHandler`. The RexxHTTP-specific
part of a site's configuration is therefore just these directives,
scoped to wherever the servlets live:

```
<Directory "/path/to/your/site">
    Options +ExecCGI
    <Files "index">
        SetHandler RexxHTTPCGI
    </Files>
</Directory>
```

A request for `/index` now runs the servlet; everything beside it —
templates, images, stylesheets — is served straight off disk. Each extra
servlet is one more `<Files>` block. The same `<Files>` lines work
verbatim in an `.htaccess` file inside the directory, if you prefer
per-directory control to editing the server config, provided
`AllowOverride` permits it.

That block is all RexxHTTP adds. *Where* it goes, and how you activate
it, is your platform's business, not this manual's: on Debian or Ubuntu
the directives live in a site file under `sites-available` and are
enabled with `a2ensite` and a reload; on a prepackaged Windows Apache
they go in the bundled `httpd.conf` or an included fragment. RexxHTTP
does not care which, as long as the handler, the `ScriptAlias` and the
`<Files>` whitelist end up in effect for the directory that holds your
servlets.

If a servlet needs environment values of its own, set them the usual
Apache way, with `SetEnv`, and read them back through the request object
as the [request/response model][The request/response model] chapter
describes.

Smoke test
----------

A minimal servlet confirms the montage end to end. Put this in a file
named `hola` in a whitelisted directory:

```
Use Arg request, response
response~content_type = "text/plain"
Say "Hola, mundo"
```

Whitelist it (`<Files "hola">`), reload Apache, and request it:

```
$ curl http://example.epbcn.com/hola
Hola, mundo
```

A `200` with that body means all the moving parts line up: Apache routed
the request through the handler, the wrapper called the processor, the
processor built the request and response objects, ran the servlet, and
flushed the body back. If instead you get a `500`, the first place to
look is the wrapper's line endings and the path it `Call`s; if you get
the file's source text rather than its output, the file was served
statically and is missing from the whitelist.

A second, more thorough check is to run the bundled integration suite,
which stands up its own throwaway Apache montage, exercises the whole
pipeline and tears it down again. It is described in the test suite's
own readme and is the same suite the project verifies every release
against.


Tutorial {.chapter}
===================

<!--
  DRAFT (v18). Progression built from, and verified against, the suite
  fixtures: hola, multi, qs, late, setck/readck, partial. Each ```rexx
  block is the body of a real servlet or a faithful reduction of one.
  Re-verify against a live Apache run if any signature changes before
  publishing. Cross-references point at the Class Reference and the
  request/response model chapter by title, never by number.
-->

This chapter builds a few small servlets, each one introducing a little
more of the API, until the shape of a RexxHTTP servlet is familiar. It
assumes RexxHTTP is installed and reachable, as the [Installation]
chapter describes; the examples are written for a servlet directory
mapped at `/test`, the layout the test suite uses, so a servlet in the
file `hola` answers at `/test/hola`. Adjust the path to wherever your
own deployment maps its servlets.

A servlet is an ordinary ooRexx program. There is no framework class to
subclass and no entry point to declare: the file *is* the servlet, and
running it produces the response. What RexxHTTP adds is the two objects
it hands the servlet — the request that came in, and the response being
built — and the redirection that turns a plain `Say` into body output.
Everything below is a consequence of those two facts.

A first servlet
---------------

The smallest useful servlet greets the world. Put this in a file named
`hola` in the servlet directory:

```rexx
Use Arg request, response
response~content_type = "text/plain"
Say "Hola, mundo"
```

Request it:

```
$ curl http://127.0.0.1/test/hola
Hola, mundo
```

Three lines, and each earns its place. `Use Arg request, response`
picks up the two objects the processor passes in. The assignment sets
the response's `Content-Type`; a fresh response already carries
`text/plain; charset=utf-8`, so for this particular servlet the line is
strictly redundant, but it is worth writing out once to see where the
content type comes from — and the moment you emit HTML you will need it
in earnest (`response~content_type = "text/html"`). The `Say` writes
the body.

That last point is the one to dwell on. `Say` does not print to a
terminal here: while the servlet runs, the default output stream is the
response's buffered body, so `Say` *appends a line to the response*.
Nothing is sent yet — the body is collected in a buffer — and when the
servlet ends, the processor flushes it, writing the headers and then the
body to the client. A servlet that does nothing but `Say` still
produces a complete, well-formed HTTP response; the processor handles
the envelope.

The `request` and `response` arguments are one of two equivalent ways to
reach those objects. The processor also publishes them in the global
environment as `.request` and `.response`, which work in any scope —
inside a routine or a method, without the variable having to be passed
along — and that is the form this manual prefers. The servlet above
could just as well have read:

```rexx
.response~content_type = "text/plain"
Say "Hola, mundo"
```

:::noindent
and omitted the `Use Arg` line entirely. Both forms are official; the
environment symbols are the more robust of the two, because they do not
depend on a variable being in scope. The rest of this chapter uses
whichever reads more clearly at the point in question.
:::

In fact the content type can go too. A fresh response already carries
`Content-Type: text/plain; charset=utf-8`, so the smallest servlet that
works is a single line:

```rexx
Say "Hello, world"
```

That is a complete servlet. The `Say` writes the body, the processor
flushes it, and the default content type RexxHTTP seeded the response
with does the rest.

The `charset=utf-8` in that default is not decoration. RexxHTTP labels
the response as UTF-8, so if your editor speaks Unicode you can write it
straight into the servlet and it reaches the browser intact:

```rexx
Say "नमस्ते", "P ≝ 𝔐", "🦞🍐"
```

That single `Say` produces three lines: Devanagari,
mathematical notation, a couple of emoji — and the browser renders them
correctly, because the response already announces the encoding the bytes
are in. There is nothing to configure: the default content type carries
the charset, and the body is sent as written.

Reading the request
-------------------

Most servlets do something with what the client sent. Request arguments
— the query string of a `GET`, the form body of a `POST` — are reached
through `arg`, which is modelled on the built-in Rexx `Arg` function:
called with no argument it returns the count, and otherwise the first
argument selects one, by position when it is a whole number and by name
otherwise. A second argument says what to return — `Value` (the
default), `Name`, `Exists` or `Omitted`.

Here is a servlet that enumerates every argument it received, by
position:

```rexx
n = .request~arg
Say "count="n
Do i = 1 To n
  Say i": ".request~arg(i, "Name")"=".request~arg(i, "Value")
End
```

Calling it shows the arguments back in the order they arrived, names in
their original spelling:

```
$ curl "http://127.0.0.1/test/multi?q=hello&Lang=ca"
count=2
1: q=hello
2: Lang=ca
```

Lookup by name is the more common case, and it is caseless — `arg("lang")`
finds `Lang` — while `Exists` lets a servlet branch on whether an
argument was sent at all:

```rexx
Say "q=".request~arg("q", "Value")
Say "exists=".request~arg("q", "Exists")
Say "missing_exists=".request~arg("nope", "Exists")
```

```
$ curl "http://127.0.0.1/test/qs?q=hello"
q=hello
exists=1
missing_exists=0
```

Two things are happening here that the servlet never has to code around.
First, names and values arrive *decoded*: percent-escapes and the
`+`-for-space convention of form encoding are already undone, on both
sides of each pair, so an argument the form sent as `user+name` is
reached as `arg("user name")`. Second, the arguments are guaranteed
well-formed before the servlet runs. RexxHTTP applies a strict argument
policy — every parameter must have the shape *name*`=`*value*, names
must be non-empty, must not begin with a digit, and must be unique
caselessly — and a request that breaks a rule is answered with `400 Bad
Request` and never reaches the servlet. So `arg` never has to cope with a
malformed or duplicated parameter; the servlet may assume every argument
has a name and a value and that a name names exactly one argument. The
[Rationale] chapter explains why strict-by-default is the right policy
for this kind of deployment, rather than a hazard. The full repertoire
of `arg` — positional versus named lookup, the four options, the
treatment of duplicates — is in the `HTTP.Request` reference in the
[Class Reference].

The same servlet code serves a `GET` and a form `POST` without change:
the processor parses the query string of the one and the
`application/x-www-form-urlencoded` body of the other into the same
arguments, so `arg` reads identically either way.

Setting a cookie
----------------

A cookie the response sets is an `HTTP.Cookie` object: create it, set
its attributes, and hand it to `.response~addcookie`. The cookie is
scheduled then, and emitted as a `Set-Cookie` header when the response
is committed.

```rexx
c = .HTTP.Cookie~new("session")
c~value = "abc123"
c~path = "/"
.response~addcookie(c)
Say "cookie set"
```

```
$ curl -i "http://127.0.0.1/test/setck"
HTTP/1.1 200 OK
...
Set-Cookie: session=abc123; Path=/
Content-Type: text/plain; charset=utf-8

cookie set
```

A freshly created cookie is the quietest thing possible — a session
cookie with `name=value` and nothing else — and you add only the
attributes you want: `c~max_age = 86400` for a lifetime, `c~httponly = 1`
to keep it from JavaScript, `c~samesite = "Lax"` and so on. The cookie
validates eagerly: an inconsistent combination, such as `SameSite=None`
without `Secure`, is refused at `addcookie` rather than emitted as a
header the browser would silently drop. The attribute set and the
consistency rules are in the `HTTP.Cookie` reference.

Reading a cookie back is the request side, and it parallels `arg`:

```rexx
Say "count=".request~cookie()
Say "session=".request~cookie("session", "Value")
```

```
$ curl --cookie "session=abc123" "http://127.0.0.1/test/readck"
count=1
session=abc123
```

The two halves form a round trip: a value is taken verbatim on the way
out (encode any reserved characters yourself) and returned
percent-decoded on the way in. Note one asymmetry from `arg`: cookie
lookup by name is case-*sensitive*, because user agents treat `session`
and `Session` as different cookies, and the option word is given as an
abbreviation rather than by its first letter alone. The details are in
the `cookie` entry of the `HTTP.Request` reference.

Headers after the body: lazy headers
-------------------------------------

Because the body is buffered, the response headers stay changeable
*after* output has begun — right up until the response is committed.
This is unusual enough to be worth seeing directly. The following
servlet writes a line of body, *then* sets a header, then writes more
body:

```rexx
Say "body first line"
.response~content_type = "text/plain"
.response~x_late_header = "yes"
Say "body second line"
```

The header set after the first `Say` still reaches the client:

```
$ curl -i "http://127.0.0.1/test/late"
HTTP/1.1 200 OK
...
X-Late-Header: yes
Content-Type: text/plain; charset=utf-8

body first line
body second line
```

The body the servlet "wrote" went into the buffer, not onto the wire, so
when `x_late_header` was assigned the head had not yet been sent and the
new header simply joined the others. Nothing is committed until the
first flush — here, the processor's automatic one after the servlet
returns — at which point the whole head goes out in front of the whole
body. (The message form `.response~x_late_header = "yes"` reaches the
header `X-Late-Header`; the response object turns underscores into
hyphens. A header whose name truly contains an underscore needs the
bracket form, `response["X_Odd_Name"] =` — see the `HTTP.Response`
reference.)

This freedom has one edge. Once the response *is* committed the head is
on the wire and can no longer change, so a header assignment after that
point is a programming error and raises, rather than failing silently. A
servlet that just writes body and lets the processor flush never meets
this edge; a servlet that flushes early does, deliberately — which is
the next topic.

Flushing early
--------------

A servlet may flush the response itself, before it returns, by calling
`.response~flush`:

```rexx
.response~content_type = "text/plain"
Say "before flush"
.response~flush
Say "after flush"
```

```
$ curl "http://127.0.0.1/test/partial"
before flush
after flush
```

The output is identical to a servlet that never flushed — and that is
the honest result to show. The first flush commits the response: it
writes the headers, then the body buffered so far, and from that point
the head is frozen. What an explicit flush buys is therefore not what
intuition (or the 2006 manual) suggests. It does *not* reliably make the
client see "before flush" appear before "after flush": in a production
deployment `mod_deflate` sits downstream and buffers the CGI output to
compress it, so progressive, client-visible streaming is not something a
servlet can count on. What an early flush does buy is control over
*when* the head is committed — fixing the headers and status at a chosen
point — which is occasionally what you want and is the mechanism behind
the lazy-header behaviour above. The [The request/response model]
chapter tells this story properly, `mod_deflate` and all; for everyday
servlets, simply never calling `flush` and letting the processor do it
is exactly right.

Errors and redirects
--------------------

Two common responses have their own one-line forms, written to be the
last thing a servlet does. To send an error page:

```rexx
If \recordExists(.request~arg("id")) Then
  Exit .response~error(404, "no such record")

.response~content_type = "text/html; charset=utf-8"
Say "<p>found it</p>"
```

`error(status [, detail])` sets the status, switches the content type to
`text/html`, and replaces any buffered body with a short error page; the
optional detail is HTML-escaped and shown as a diagnostic line.
`.response~404(detail)` is shorthand for the commonest case. To redirect:

```rexx
Exit .response~redirect("/test/hola")
```

`redirect(location [, status])` defaults to `302`; pass `301` for a
permanent move or `303` after a form `POST`. Both `error` and `redirect`
follow the same commit discipline as a late header: they discard an
uncommitted body and do their work, but raise if the response has
already been committed, since by then the status can no longer change.
Their full behaviour is in the `HTTP.Response` reference.

Where to go next
----------------

These servlets exercise most of the everyday API: reading arguments and
cookies, writing the body, setting headers and cookies on the response,
and the two shorthand exits. The one idea underneath all of them — the
buffered body, the lazy headers, the single commit — is the subject of
the next chapter, [The request/response model], which is worth reading
before building anything larger. The exhaustive, method-by-method
account of the four classes is the [Class Reference].


The request/response model {.chapter}
=====================================

<!--
  DRAFT (v18). Conceptual chapter, verified against the code on disk:
  HTTP.Response.cls (commit/flush/init), HTTP.OutputStream.cls (flush).
  Authoring rule 3: code is the source of truth here, not the 2006 PDF.
  The mod_deflate note is the v8 decision — flush kept for its internal
  effect, NOT for client-visible streaming; do not repeat the 2006
  "watch the page appear" promise. Cross-references by title.
-->

The [Tutorial] showed servlets that work without explaining why they
work. This chapter is the why. It describes the three objects RexxHTTP
builds for each request, the buffering that sits under the response, and
the single moment — the *commit* — that turns a buffer full of headers
and body into bytes on the wire. Almost everything that can surprise a
servlet author, from a header that takes effect after it was "too late"
to set, to one that mysteriously raises, follows from this one model.

The three objects
-----------------

For each request, before the servlet runs, RexxHTTP builds three objects
and hands the servlet the first two.

A **request** (`HTTP.Request`) is the incoming side, read-only. It holds
the request line and headers — reached as named accessors or, for
anything CGI passed as an environment variable, through the environment
pool — and it holds the arguments and cookies the client sent, parsed
and decoded. By the time the servlet runs the parsing is already done
and the argument policy already applied, so the request a servlet sees
is always well-formed.

A **response** (`HTTP.Response`) is the outgoing side, and it is the
object this chapter is really about. It is made of three parts: a set of
headers (seeded with one, `Content-Type: text/plain; charset=utf-8`), an
optional set of cookies, and a buffered output stream that collects the
body. The headers and cookies stay freely modifiable for as long as the
body is being written — that is the whole point of the design — and are
serialised only once, at commit.

An **output stream** (`HTTP.OutputStream`) is that body buffer: a
write-only subclass of `Stream` that the response creates for itself.
While the servlet runs, the default output stream is redirected to it,
which is why a plain `Say` writes to the response body rather than to a
console that is not there. The servlet almost never names this object;
it just uses `Say`.

The request and response reach the servlet two ways at once — as the two
arguments to `Use Arg`, and as the environment symbols `.request` and
`.response` — and the two are the same objects. This manual prefers the
environment symbols, because they reach the response from any scope
(a routine, a method) without the object having to be passed along, and
because the body of a servlet rarely wants to thread `response` through
every call that might need to set a header.

Buffering, and why
------------------

A CGI program speaks to the web server through its standard output: the
bytes it writes become the HTTP response, headers first, then a blank
line, then the body. The catch is order. Once a single header byte has
been written, the headers are decided; anything the program "sets" after
that is too late, because it has already gone out — or worse, the body
has, and the header lands in the middle of it.

RexxHTTP removes that catch by not writing the body straight to the
server. The output stream collects it in a buffer instead. While the
buffer fills, the headers and cookies are still just entries in two
directories on the response object: setting one, changing one, adding a
cookie are all ordinary updates to in-memory state, and the order in
which the servlet does them relative to its `Say`s does not matter,
because none of it has been serialised yet.

This is what the introduction and the Tutorial called *lazy headers*. A
servlet can write half its page, decide from what it computed there that
the content type should be `text/html` rather than the default, set it,
and finish the page — and the header is correct on the wire, because at
the moment it was set nothing had yet been committed. The buffer buys
the servlet the freedom to decide late.

Commit
------

*Commit* is the moment the buffered head becomes bytes. It happens once
per response, and it does a fixed sequence: it writes the `Content-Type`
header, then one `Set-Cookie` line per scheduled cookie, then every
other header, then the blank line that separates head from body — all
straight to the server's output stream, ahead of the buffered body.
After commit the head is on the wire and cannot be changed.

Commit is **idempotent**: the first call emits the head and marks the
response committed; any later call returns at once, having done nothing.
A servlet therefore never has to track whether the response is "already"
committed before asking for a flush — asking twice is harmless.

Servlets rarely call `commit` directly. It is driven by *flush*. The
response's `flush` (and the output stream's, which it delegates to)
commits the response if it has not been committed yet, and only then
writes the buffered body out and empties the buffer. So the **first
flush is what commits**, and that first flush is one of two things:

- one the servlet performs itself, by calling `.response~flush` — for
  instance to fix the headers at a deliberate point; or
- the one RexxHTTP performs automatically after the servlet returns.

A servlet that never flushes still gets exactly one flush, the
processor's final one, and so still produces a complete response with
its head committed once. The common case needs no `flush` at all.

Commit discipline
-----------------

Everything a servlet can do to the head — set a header (`.response[...]=`
or the message form), schedule a cookie (`addcookie`), or replace the
response wholesale (`error`, `404`, `redirect`) — is legal *before*
commit and an error *after* it. The reason is physical: past commit the
head is already on the wire, so a late change could not possibly take
effect. RexxHTTP treats the attempt as a programming error and raises
(`Syntax` 93.900, *the response is already committed*) rather than
accept a call it would have to silently ignore. The body may still be
written and flushed after commit; only the head is frozen.

This is why the order of guards matters in one place worth noting. When
a cookie is added to an already-committed response, the failure reported
is *already committed*, not *not a cookie* even if the argument is also
wrong: the commit check comes first, because the commit state outranks
argument validation. The same fail-fast governs `error` and `redirect`,
which discard an uncommitted buffered body and do their work, but raise
on a committed response instead of pretending to change a status that
has already shipped.

There is also a brief internal window the servlet never sees but which
explains the care in the design: while `commit` is partway through
writing the head, the response is *committing* but not yet *committed*.
RexxHTTP's own error handling distinguishes the two, so that a fault
raised in the middle of emitting headers does not try to re-assert
headers over a response that is already half-written. A servlet only
ever observes the two stable states, before and after; `committed`
reports which. The per-method detail — what `error`, `addcookie`,
`commit` and `committed` each do, argument by argument — is in the
[Class Reference].

A note on streaming and mod_deflate
------------------------------------

It is tempting to read "the servlet can flush early" as "the servlet can
stream a page to the browser progressively, a piece at a time." The 2006
manual made roughly that promise. In a modern production deployment it
no longer holds, and this manual will not repeat it.

The reason is `mod_deflate`. To compress the response, Apache's
`mod_deflate` buffers the CGI program's output on its own account before
sending it on, which means the boundaries at which a servlet flushes are
not the boundaries at which the client receives anything: the compressor
decides those. An early `.response~flush` does *not* reliably make the
first half of a page appear in the browser before the servlet has
finished computing the second half.

What an early flush still does — and the reason the flush mechanism is
kept — is *internal* and entirely real. It commits the response at a
chosen point, fixing the headers and status exactly there rather than at
the end. That control over commit ordering is occasionally what a
servlet wants, and it is the mechanism behind the lazy-header behaviour
this chapter described. Think of `flush` as "decide the head now," not
as "push bytes to the browser now." For the great majority of servlets
neither concern arises: they write their body, return, and let the
processor's final flush commit and send the whole thing at once.


Class Reference {.chapter}
==========================

<!--
  TODO. Method-by-method, like §5 of the 2006 manual, but VERIFIED AGAINST
  THE CODE ON DISK (see authoring rule 3 above). Four classes. For each
  method: signature, what it does, arguments, return, raised conditions,
  and a short example where useful.

  FIRST STEP of the writing session: read these four files IN FULL before
  writing a single entry —
    src/HTTP.Cookie.cls
    src/HTTP.OutputStream.cls
    src/HTTP.Request.cls
    src/HTTP.Response.cls
  (In v8 only HTTP.Response.cls was read in full; the others were skimmed.)
-->

The `HTTP.Cookie` class
-----------------------

An `HTTP.Cookie` instance represents one cookie the response will set:
one instance, one `Set-Cookie` header. The servlet creates the cookie,
sets its attributes, and hands it to `.response~addcookie`:

```rexx
c = .HTTP.Cookie~new("session", "abc123")
c~max_age  = 86400
c~samesite = "Lax"
c~httponly = 1
.response~addcookie(c)
```

This is a response-side class only. Cookies arriving *with* the request
are not `HTTP.Cookie` instances; they reach the servlet as plain
name/value pairs through `.request~cookie` (see the `HTTP.Request`
reference).

`HTTP.Cookie` is a modern, RFC 6265 cookie: lifetime is expressed with
`Max-Age` (the class does not emit `Expires`, which survives only for
user agents long gone — when both are present, `Max-Age` wins anyway),
and the `SameSite`, `Secure` and `HttpOnly` attributes and the `__Host-`
and `__Secure-` name prefixes are supported.

The class validates eagerly, so that an invalid cookie fails in the
servlet, never as a `Set-Cookie` line the browser silently discards. An
invalid *name* is rejected at creation. Rules that involve *several*
attributes are checked when the cookie is serialised — in practice, at
`addcookie` — so that attributes may be set in any order.

### Consistency rules

A cookie must satisfy all of these to serialise:

- `SameSite=None` requires `Secure`.
- A name with the `__Secure-` prefix requires `Secure`.
- A name with the `__Host-` prefix requires `Secure`, `Path=/`, and no
  `Domain`.

Prefix matching is case-insensitive, mirroring what user agents do:
`__host-` is `__Host-`.

### `new`

```rexx
cookie = .HTTP.Cookie~new(name, value)
cookie = .HTTP.Cookie~new(name)         -- value defaults to ""
```

Creates a cookie named *name* with the given *value* (default: the null
string — a cookie with an empty value is legal).

The name must not be the null string and must not begin with `$`; its
characters must be ASCII, and neither control characters nor any of the
separator characters `( ) < > @ , ; : \ " / [ ] ? = { }`, space, or tab.
The `__Host-` and
`__Secure-` prefixes are recognised; the requirements they carry are
listed above and checked at serialisation time.

The value is taken as given: no encoding is performed. If the value
carries reserved characters (`;`, `,`, spaces...), percent-encode it
yourself; on the way back, `.request~cookie` returns it already decoded,
so the round trip is: encode on output, read plain on input.

A freshly created cookie is a *session cookie* with everything at its
quietest: no `Max-Age`, no `Path`, no `Domain`, no `SameSite`, not
`Secure`, not `HttpOnly`. Only `name=value` is emitted.

### `name`

```rexx
string = cookie~name
```

Returns the cookie's name. There is no `name=`: a cookie's name is fixed
at creation.

### `value`, `value=`

```rexx
string = cookie~value
cookie~value = newvalue
```

The cookie's value. As at creation, the new value is taken as given —
encoding reserved characters is the caller's business.

### `path`, `path=`

```rexx
string = cookie~path
cookie~path = path
```

The `Path` attribute, emitted as given. The default, the null string,
omits the attribute. A `__Host-` cookie must have `Path=/`.

### `domain`, `domain=`

```rexx
string = cookie~domain
cookie~domain = domain
```

The `Domain` attribute, emitted as given. The default, the null string,
omits the attribute. A `__Host-` cookie must not set one.

### `max_age`, `max_age=`

```rexx
seconds = cookie~max_age
cookie~max_age = seconds
```

The cookie's lifetime, a whole number of seconds. A negative value — the
default is −1 — makes it a session cookie: the attribute is omitted. Zero
instructs the user agent to delete the cookie, which is also how *you*
delete one — set `Max-Age` to zero on a cookie with the same name (and
the same `Path` and `Domain`, if the original had them):

```rexx
gone = .HTTP.Cookie~new("session", "")
gone~max_age = 0
.response~addcookie(gone)
```

### `secure`, `secure=`

```rexx
flag = cookie~secure
cookie~secure = flag
```

The `Secure` attribute: `1` emits it, `0` — the default — does not.
Required by `SameSite=None` and by the `__Secure-` and `__Host-` name
prefixes.

### `httponly`, `httponly=`

```rexx
flag = cookie~httponly
cookie~httponly = flag
```

The `HttpOnly` attribute: `1` emits it, `0` — the default — does not.

### `samesite`, `samesite=`

```rexx
string = cookie~samesite
cookie~samesite = value
```

The `SameSite` attribute: `Strict`, `Lax` or `None`, accepted
case-insensitively and stored in canonical spelling (the getter returns
`Strict`, `Lax` or `None` regardless of how it was assigned). The null
string — the default — omits the attribute; assigning it clears a
previously set value. `SameSite=None` requires `Secure`; the rule is
checked at serialisation, not here, so the two may be assigned in either
order.

### `makestring`

```rexx
string = cookie~makestring
```

Returns the value of the `Set-Cookie` header this cookie will produce —
exactly what `addcookie` will schedule and `commit` will emit. The
consistency rules above are checked first: an inconsistent cookie does
not serialise. Attributes appear in a fixed order: `name=value`, then
`Max-Age`, `Domain`, `Path`, `SameSite`, then the valueless `Secure` and
`HttpOnly`:

```
id=v; Max-Age=3600; Domain=example.org; Path=/; SameSite=Lax; Secure; HttpOnly
```

Servlets rarely need `makestring` — `addcookie` drives it — but it is
convenient for logging or testing what a cookie will look like on the
wire.

The `HTTP.OutputStream` class
-----------------------------

<!--
  Verified against src/HTTP.OutputStream.cls (v9) + isolated runs + suite.
-->

An `HTTP.OutputStream` collects the response body. The servlet does not
create it: the response object does, and `.response~output` returns it.
During servlet execution the default output stream (`.output`) is
redirected to it, so the three statements below write to the same place:

```rexx
Say "one"                        -- the usual way
.output~say("two")               -- explicitly, via the default stream
.response~output~say("three")    -- explicitly, via the response
```

Nothing reaches the client until the stream is flushed; the first flush
commits the response — headers out first, then the buffered body. This
buffering is what makes lazy headers possible, and it is the reason the
class exists; the request/response model chapter tells that story. The
servlet rarely needs to do anything: the processor flushes once after the
servlet returns.

The class is a subclass of `Stream` and honours the stream protocol as
far as it makes sense for what it is: a *write-only*, *transient* stream.
It cannot be read (the input methods raise NOTREADY) and it cannot be
positioned. Lines written to it end in LF, the web convention for text
bodies.

### `arrayin`, `charin`, `chars`, `linein`, `lines`, `makearray`, `supplier`

The stream is write-only: every input method raises the NOTREADY
condition, with a description naming the stream. If the condition is not
trapped, the usual Rexx semantics apply — the call is ignored and returns
a neutral value (the null string, `0`, or `.nil`, as appropriate to each
method).

### `arrayout`

```rexx
.response~output~arrayout( array, option )
.response~output~arrayout( array )      -- option defaults to "L"
```

Appends the elements of *array* — a single-dimensional array, or an
object that produces one when sent a `request("ARRAY")` message — to
the body. With *option* `"LINES"` (the default; `"L"` will do) the
elements are joined by LF, with no LF after the last one; with
`"CHARS"` (`"C"`) they are concatenated with no separator.

### `charout`

```rexx
rc = .response~output~charout( string )
```

Appends *string* to the body exactly as given — no line end. The
argument must have a string value. Returns `0` on success. Called with
no argument, `charout` closes the stream (here: flushes it — see
`close`). The stream protocol's positioning argument is not accepted:
this is a transient stream.

```rexx
.response~output~charout("no trailing newline here")
```

### `close`

```rexx
.response~output~close
```

Flushes any pending output. An HTTP output stream has no real notion of
being closed — it remains writable afterwards; *close* is how the stream
protocol spells "I am done for now", and here that means a flush.

### `command`

```rexx
.response~output~command( string )
```

The stream-protocol command interface: the verbs `OPEN`, `CLOSE`,
`FLUSH`, `QUERY`, `SEEK` and `POSITION` are accepted and dispatched to
the corresponding methods.

### `description`

```rexx
string = .response~output~description
```

Returns the stream's state, followed by a description when there is
something to describe — typically only when the underlying stream was
not ready when the output stream was created.

### `flush`

```rexx
.response~output~flush
```

The workhorse. Commits the response if it is not yet committed — this is
where the headers get written, in front of everything — then writes the
buffered body to the underlying CGI stream, flushes it, and empties the
buffer. `.response~flush` does the same thing through the response
object. Flushing explicitly mid-servlet is allowed, and fixes the point
past which headers can no longer change; what it does *not* promise is
client-visible streaming — see the request/response model chapter.

### `init`

Servlets do not construct output streams: the response object creates
one, wrapped around the real CGI output stream, when *it* is created.
The wrapped stream must be a `Stream` instance proper — in particular,
output streams do not nest: an `HTTP.OutputStream` will not accept
another one as its underlying stream.

### `lineout`

```rexx
rc = .response~output~lineout( line )
```

Appends *line*, which must have a string value, followed by LF. Returns
`0` on success. Called with no argument, it closes (flushes) the stream,
like `charout`. The positioning argument is not accepted.

### `open`

```rexx
.response~output~open
```

An HTTP output stream is always open, unless its underlying stream
reported a problem when the output stream was created — in which case it
cannot be opened at all. The method returns the stream's state and
changes nothing.

### `position`, `seek`

Not supported: transient streams cannot be positioned. Both raise.

### `qualify`

```rexx
string = .response~output~qualify
```

Returns the stream's name, the fixed label `HTTP.OutputStream:1`.

### `query`

```rexx
value = .response~output~query( option )
```

The stream-protocol query interface, answered as befits a transient
stream that exists only for the duration of the request: `EXISTS` returns
the stream's label, `SIZE` the null string, `STREAMTYPE` returns
`UNKNOWN`, `DATETIME` and `TIMESTAMP` return the stream's creation time,
and the `POSITION`/`SEEK` queries return `1`. `HANDLE` is not supported.

### `say`

```rexx
.response~output~say( line )
.response~output~say                    -- emits an end-of-line
```

`lineout` with a default: called without an argument it appends an empty
line rather than closing the stream.

### `state`

```rexx
string = .response~output~state
```

The stream's state — `READY` in any response you will ever want to send.

### `underlyingstream`

```rexx
stream = .response~output~underlyingstream
```

Returns the wrapped stream: the real CGI output, connected to the web
server. This is the response's plumbing — `commit` writes the headers
through it — and a servlet has no business writing to it directly:
anything sent there bypasses the buffer and lands in front of content
the response has not emitted yet, headers included.

The `HTTP.Request` class
------------------------

<!--
  Verified against src/HTTP.Request.cls (v10) + live fixtures + suite.
-->

An `HTTP.Request` instance represents the request being served. The
servlet does not create it: the processor instantiates one per incoming
request, before the servlet runs, and hands it to the servlet as its
first argument; like the response, it is also published in the global
environment, as `.request` (the two forms are equivalent — see the
introduction to `HTTP.Response`).

The request object is read-only, and answers three kinds of questions:
what came with the request line and the headers (the environment pool,
and a set of accessors), what arguments the query string or the request
body carried (`arg`), and what cookies the user agent sent (`cookie`).

By the time the servlet runs, the groundwork is done: the processor has
parsed the arguments — reading the request body, for a POST — and
applied the argument policy, so the arguments a servlet sees are always
well-formed; and creating the request has set the current directory to
the directory of the servlet file, so relative paths in the servlet
resolve next to it.

### The environment pool

CGI delivers a request as environment variables, and the request object
embraces that: any message that does not match one of the methods below
answers with the value of the environment variable of the same name.

```rexx
agent  = .request~http_user_agent     -- the User-Agent request header
server = .request~server_name         -- a standard CGI variable
raw    = .request~http_cookie         -- the raw Cookie header
```

A variable that is not set answers the null string. The pool is
read-only: these messages accept no arguments, and there is no
assignment form. The message name arrives uppercased — the usual Rexx
behaviour — which is just what the upper-case names of the CGI world
expect.

The lookup understands the deployment it lives in. Under an
`Action`-based deployment, Apache reaches the processor through an
internal subrequest, and hands some variables over under a `REDIRECT_`
prefix. The request object absorbs that detail:

- A name beginning with `HTTP_` — a request header, in the form Apache
  passes them — is looked up as given.
- Any other name is looked up as given first, and, only if that comes
  back empty, under a `REDIRECT_` prefix. So the standard CGI variables,
  which arrive unprefixed, are never shadowed, while a value that exists
  only behind the `Action` subrequest's `REDIRECT_` is still found.

So `.request~remote_addr` simply works, and a
`SetEnv MYAPP_MODE production` in an `.htaccess` is `.request~myapp_mode`
wherever Apache actually put the value — prefixed or not. There is no
special namespace: an operator-defined variable is an ordinary pool
name. If you ever want the prefixed form explicitly, you can always name
it: `.request~redirect_remote_user`. `REXXHTTP_ARGPOLICY`, the
argument-policy switch, is read through this same pool — which is why a
per-directory `SetEnv` is all it takes to configure it (next section).

### Arguments, and the strict policy

Before the servlet runs, the processor parses the request arguments —
the query string of a GET, the `application/x-www-form-urlencoded` body
of a POST — and applies the *argument policy*. The policy of the 1.0,
`strict`, the default and the only one, demands of every parameter
that:

- it has the form *name*`=`*value* — an empty value (`k=`) is
  legitimate, a token without `=` is not;
- the name is not empty and does not begin with a digit (the Rexx
  symbol convention — and a numeric name would be unreachable through
  `arg` anyway, since positions take precedence there);
- the name is unique, compared caselessly: `X` and `x` are the same
  name.

These rules are applied to the *decoded* name — the one the servlet
will see and key on. Two spellings that decode to one name (say
`user+name` and `user%20name`) are therefore a single name, and a
request carrying both is rejected as a duplicate.

A request that breaks one of these rules is answered with `400 Bad
Request`, stating the reason, and the servlet never runs. Stray `&`s —
doubled, or trailing — are ignored, not rejected. The policy is
configured per directory or per servlet with `SetEnv
REXXHTTP_ARGPOLICY` in the Apache configuration; the value is caseless,
`strict` is the only value the 1.0 recognises, and an unknown value is
answered with a `500` configuration error — an operator mistake, not a
client one.

The payoff is what the servlet gets to assume: every argument it sees
has a name and a value, and a name names exactly one argument.

Argument names and values alike are delivered decoded — percent-escapes,
and the `+`-for-space convention of form encoding, applied to both
sides of each pair as `application/x-www-form-urlencoded` prescribes.
So a field named `user name`, which a form sends as `user+name` (or
`user%20name`), is reached as `arg("user name")`.

### `[]`

```rexx
value = .request[name]
```

Bracket lookup: *name*, which must have a string value, is uppercased,
its hyphens become underscores, and the result is looked up in the
environment pool — always, never against a like-named method. The
bracket form is the raw-variable door: it lets you reach an environment
variable by its HTTP spelling even when a method shares the name.

```rexx
length = .request["Content-Length"]    -- the CONTENT_LENGTH variable, raw
agent  = .request["HTTP-User-Agent"]   -- the HTTP_USER_AGENT variable
```

This is the complement of the message form: `.request~content_length`
gives you the method (the parsed length), while
`.request["Content-Length"]` gives you the raw environment variable of
that name. Use `~name` for the library's view, `[name]` for the
variable underneath.

There is no bracket assignment: the request is read-only.

### `arg`

```rexx
count = .request~arg
value = .request~arg( n )
value = .request~arg( name )
value = .request~arg( n   , option )
value = .request~arg( name, option )
```

Access to the request arguments, modelled on the built-in `Arg`
function. Called with no arguments, it returns how many there are.
Otherwise the first argument, which must be given and must have a
string value, selects one — by position, when it is a positive whole
number; by name, compared caselessly, in any other case — and *option*
says what to return about it. The option is identified by its first
nonblank character, caselessly, again in the manner of the built-in:

- `Value` — the default — returns the argument's value, decoded; the
  null string when there is no such argument.
- `Name` returns the argument's name, in its original spelling.
- `Exists` returns whether such an argument exists.
- `Omitted` returns the opposite.

```rexx
-- /servlet?q=hello&Lang=ca
.request~arg                   -- 2
.request~arg(2, "Name")        -- "Lang" (the spelling is preserved...)
.request~arg("lang")           -- "ca"   (...but lookup is caseless)
.request~arg("page", "Exists") -- 0
```

Positional access reaches the arguments in the order the request sent
them; a position beyond the count yields the null string (and `Exists`
and `Omitted` answer accordingly). Under the strict policy these are
the only shapes a request can have: see the previous section for what
`arg` never has to cope with.

### `content_length`

```rexx
length = .request~content_length
```

The size of the request body, in bytes, as the request declared it; the
null string when the request carried none (a GET, typically).

### `content_type`

```rexx
type = .request~content_type
```

The media type of the request body, as the request declared it — for a
form POST, `application/x-www-form-urlencoded`; the null string when
the request carried none.

### `cookie`

```rexx
count = .request~cookie
value = .request~cookie( n )
value = .request~cookie( name )
value = .request~cookie( n   , option )
value = .request~cookie( name, option )
```

Access to the cookies the user agent sent, with the same shape as
`arg`: no arguments for the count, a first argument — required, with a
string value — that selects by position when it is a positive whole
number and by name in any other case, and an *option* choosing among
`Name`, `Value` (the default), `Exists` and `Omitted`, with the same
meanings as in `arg`. Two differences, both deliberate. Lookup by name
is case-*sensitive*: `session` and `Session` are different cookies, to
the request object as to the user agent. And the option is given as an
abbreviation of the option word — any leading part will do, caselessly
— rather than by its first character alone.

Cookie values are delivered percent-decoded, and only percent-decoded:
the `+`-for-space convention belongs to form encoding, not to cookies,
so a literal `+` in a value survives the trip. This is the reading half
of the round trip stated in the `HTTP.Cookie` reference — encode on
output, read plain on input — and it is safe for the whole repertoire:
an encoded `;` (`%3B`) comes back as a `;` *inside* the value, never as
a cookie separator.

When the request carries several cookies with the same name — the same
name under different `Path`s, say — positional access reaches every
one; lookup by name resolves to the last one sent.

```rexx
If .request~cookie("session", "Exists") Then
  session = .request~cookie("session")
```

### `filename`

```rexx
path = .request~filename
```

The full filesystem path of the servlet file. `path_translated` answers
the same.

### `method`, `request_method`

```rexx
verb = .request~method
```

The request method, as sent: `GET`, `POST`, and so on. `method` and
`request_method` are one method under two names.

### `path_info`

```rexx
extra = .request~path_info
```

The extra path: what the request URI carries beyond the part that
locates the servlet, decoded, `/`-separated. A request for
`/test/show/reports/2026`, served by the servlet file `show`, has the
`script_name` `/test/show` and the `path_info` `/reports/2026`. The
null string when there is none.

### `path_translated`

```rexx
path = .request~path_translated
```

The full filesystem path of the servlet file — where the request URI
landed once Apache translated it. `filename` answers the same.

### `post_string`

```rexx
body = .request~post_string
```

The body of a POST request, exactly as received — still in its transfer
encoding; the processor has already read it by the time the servlet
runs. The null string for a GET. The parsed, decoded view of the same
data is `arg`.

### `query_string`

```rexx
query = .request~query_string
```

The query string, exactly as received — still encoded, without the
`?`. The null string when there is none. The parsed, decoded view of
the same data is `arg`.

### `request_uri`, `unparseduri`

```rexx
raw = .request~request_uri
```

The request URI exactly as the client sent it: path and query string,
still encoded. `unparseduri` is the same method under a second name.

### `script_name`

```rexx
name = .request~script_name
```

The URI path that locates the servlet, decoded: `uri` without the
`path_info`.

### `system_version`

```rexx
version = .request~system_version
```

The processor identification string — for this release,
`REXXHTTP/1.0 20260611`.

### `unknown`

The environment pool described at the top of this reference is
implemented by `unknown`: a message that matches no method answers the
corresponding environment variable. The get form only — such a message
accepts no arguments.

### `uri`

```rexx
path = .request~uri
```

The path of the request, decoded, query string excluded:
`script_name` plus `path_info`.

### `validate`

```rexx
violation = .request~validate
```

The processor's hook. Parses the arguments eagerly — reading the body
of a POST — and applies the argument policy, returning the null string
when the request is acceptable, and a short `code:detail` description
of the first violation otherwise. The processor calls it before the
servlet runs — this is where the `400` of the strict policy comes from
— so a servlet never needs to: by the time a servlet runs, `validate`
has already returned the null string.

The `HTTP.Response` class
-------------------------

An `HTTP.Response` instance represents the response being built for the
current request. The servlet does not create it: the processor instantiates
one response per request, before the servlet runs, and hands it to the
servlet as its second argument. It is also published in the global
environment, so both of these reach the same object:

```rexx
Use Arg request, response     -- as the second argument...
...
.response~flush               -- ...or as an environment symbol
```

The two are equivalent. The environment symbol has the advantage of
working in any scope — an internal routine, a `::Routine`, a method —
without the variable having to travel there, and this manual uses that
form, `.request` and `.response`, throughout.

A response is made of three parts: a set of *headers*, an optional set of
*cookies*,
and a buffered *output stream* that collects the body. The headers and
cookies remain freely modifiable while the servlet writes the body; they
are serialised only when the response is *committed*, which happens at the
first flush (see the request/response model chapter). After the servlet
returns, the processor issues a final flush, so a servlet that never
touches the response object beyond `Say` still produces a complete,
well-formed response.

### Headers, and the two ways to name them

Headers live in a directory keyed by the upper-cased header name. Two
different syntaxes reach that directory, and they normalise the name
differently — deliberately so, because each syntax has its own grammar:

- **Message form.** `.response~cache_control = "no-store"` and its read
  counterpart `.response~cache_control`. A hyphen is not legal inside a
  Rexx message name (it would parse as a subtraction), so the message form
  uses an underscore wherever the HTTP name has a hyphen; the response
  object translates underscores to hyphens to reach the real header name.

- **Bracket form.** `.response["Cache-Control"] = "no-store"` and
  `.response["Cache-Control"]`. Here the name is an ordinary string, the
  hyphen poses no problem, and the name is used as written; only its case
  is normalised.

Both routes converge on the same internal key (`CACHE-CONTROL`), each
starting from what its own grammar allows. One practical consequence: a
header whose real name contains an underscore can only be reached through
the bracket form, since the message form would turn that underscore into
a hyphen.

Header names are case-insensitive in HTTP. Internally they are stored
upper-cased — that is what makes the lookup case-insensitive, so that the
message form, the bracket form and any mix of case all reach the same
entry. On the way out, though, the name is title-cased for readability:
the response to the example above carries the header line
`Cache-Control: no-store`, not `CACHE-CONTROL: no-store`. The rule is
mechanical — each hyphen-separated word gets an initial capital — so a few
acronym headers come out unconventionally (`WWW-Authenticate` would emit as
`Www-Authenticate`). RexxHTTP never sends those itself, and since HTTP
treats the names case-insensitively no client minds; only a test that
compares a raw header block case-sensitively need take note.

Every response carries a `Content-Type`: the header directory is seeded at
creation time with the default `text/plain; charset=utf-8`, which the
servlet may overwrite but not remove.

### The status line

There is no first-class status method, and none is needed. Under CGI the
response status is set through the `Status` pseudo-header (RFC 3875),
which to the response object is a header like any other:

```rexx
.response~status = "404 Not Found"
```

`commit` emits it with the rest of the headers; Apache consumes it and
builds the corresponding HTTP status line (the `Status` line itself does
not reach the client). A response that sets no status is a `200 OK`.

Setting `status` by hand is the low-level route. For the common cases —
sending an error page or redirecting — `error`, `404` and `redirect`
set the status, the matching headers and (for errors) a body in one
call, and are written to be the last statement a servlet runs:
`Exit .response~error(404)`.

### `error`

```rexx
.response~error( status, detail )
.response~error( status )               -- detail is optional
```

Emits an error response with HTTP status *status* and a short HTML page,
and returns `0`. *status* is a numeric code; *detail*, if given, is shown
on the page as a single diagnostic line and is HTML-escaped, so a detail
containing `<`, `>` or `&` is displayed literally rather than interpreted.

The reason phrase is supplied automatically for the codes a servlet is
likely to use (the `3xx` redirects, `400`, `401`, `403`, `404`, `405`,
`500`, `502`, `503`). A code outside that set still works: it is given a
generic phrase for its family — *Redirect*, *Client Error* or *Server
Error* — so an unusual status is never refused.

`error` follows the buffering model. If the response has **not** been
committed, any body the servlet had written so far is discarded, the
status and a `text/html` content type are set, and the error page replaces
the buffered body; the normal flush then sends it. If the response **has**
been committed — the head has already reached the client, so the status can
no longer be changed — `error` raises a `Syntax` condition rather than
pretend to do the impossible. This mirrors the servlet rule for `sendError`
on a committed response.

Because it returns `0`, `error` reads naturally as a servlet's final act:

```rexx
If \record~exists Then Exit .response~error(404, "no such record")
```

### `404`

```rexx
.response~404
.response~404( detail )                 -- detail is optional
```

Shorthand for `error(404 [, detail])` — the single most common error from a
servlet, given its own name. Same return value and same buffering rules.

### `redirect`

```rexx
.response~redirect( location, status )
.response~redirect( location )          -- status defaults to 302 (Found)
```

Emits a redirect to *location* and returns `0`. It sets the `Location`
header and a `3xx` status; *status* defaults to `302` (*Found*), the
conventional temporary redirect. No body is sent.

A different code is requested explicitly. The two that come up in practice:
`301` (*Moved Permanently*) when a resource has acquired its canonical URL
and the new address should replace the old — for example when an optional
slug is added to a path — and `303` (*See Other*) after a form `POST`, so
that a refresh re-fetches the result page with `GET` instead of resubmitting
the form. Note that `301` is cached aggressively by user agents; use it only
for a move that is genuinely permanent, never for one that might be undone.

```rexx
Exit .response~redirect("/publishers/acme-press/", 301)
```

`redirect` obeys the same commit discipline as `error`: it discards an
uncommitted buffered body and raises if the response is already committed.

### `[]`

```rexx
value = .response[headername]
```

Returns the current value of header *headername*, or `.nil` if no such
header has been set. The name is case-insensitive and is given literally,
hyphens included. *headername* must have a string value.

### `[]=`

```rexx
.response[headername] = headervalue
```

Sets header *headername* to *headervalue*, creating or overwriting it.
Headers are single-valued: assigning to an existing name replaces its
value. Both arguments must have string values. Headers may be set after
body output has begun — that is the point of the design; see the
request/response model chapter — but must be set before the first flush:
once the response is committed the head is already on the wire, so a late
assignment cannot take effect and is treated as a programming error rather
than silently ignored — it raises (error 93.900, *the response is already
committed*). This matches `error`, `redirect` and `addcookie`, which obey
the same discipline; see *Commit discipline* in the request/response model
chapter.

### `addcookie`

```rexx
.response~addcookie( cookie )
```

Schedules *cookie*, which must be an `HTTP.Cookie` instance, for emission
as a `Set-Cookie` header at commit time. The cookie must be internally
consistent: an inconsistent one — say, `SameSite=None` without `Secure` —
is not accepted, and `addcookie` raises at once. The consistency rules are
given in the `HTTP.Cookie` reference.

A cookie scheduled after the response is committed could never be emitted —
the head is already on the wire — so, like `[]=`, `addcookie` treats this as
a programming error and raises (error 93.900) rather than dropping the cookie
silently. The commit check comes first, before the argument is even type-
checked: past commit the failure is *already committed*, not *not a cookie*.

The cookie is stored *by copy*: changes made to the cookie object after
`addcookie` returns do not affect what will be emitted. Cookies are keyed
by the triple (name, `Path`, `Domain`), matching the identity rules user
agents apply: adding a cookie with the same name but a different `Path` or
`Domain` yields an additional `Set-Cookie` line, while re-adding one with
the same triple replaces the previous one. The relative order of the
`Set-Cookie` lines in the response is unspecified.

```rexx
c = .HTTP.Cookie~new("session", "abc123")
c~httponly = 1
.response~addcookie(c)
```

### `commit`

```rexx
.response~commit
```

Serialises the response head: writes the `Content-Type` header, then one
`Set-Cookie` line per scheduled cookie, then the remaining headers, then
the blank line that separates head from body — all directly to the
underlying CGI output stream, ahead of the buffered body. Commit is
idempotent: the first call emits the head and marks the response
committed; subsequent calls return immediately.

Servlets rarely call `commit` directly: the first `flush` — explicit, or
the processor's final one — commits the response if needed. Once the head
is committed it cannot be changed: any later attempt to set a header (`[]=`
or `response~name = value`), schedule a cookie (`addcookie`) or replace the
response wholesale (`error`, `404`, `redirect`) raises error 93.900 rather
than failing silently. The body may still be written and flushed; only the
head is frozen.

### `committed`

```rexx
state = .response~committed
```

Returns `.true` if the response has been committed (its headers have been
emitted), `.false` otherwise. Takes no arguments.

### `flush`

```rexx
.response~flush
```

Commits the response if it is not yet committed, then flushes the buffered
output stream, writing the body collected so far to the underlying CGI
stream. Returns nothing. The processor calls it once after the servlet
returns; a servlet may also call it explicitly at any point (see the
request/response model chapter for what an early flush does — and does not
— buy you once `mod_deflate` sits downstream).

### `init`

Servlets do not create responses; the processor does, once per request.
A fresh response starts with exactly one header, `Content-Type:
text/plain; charset=utf-8`; no cookies; not committed; and a new
`HTTP.OutputStream` wrapped around the current default output stream as
its body buffer.

### `output`

```rexx
stream = .response~output
```

Returns the response's buffered output stream, an `HTTP.OutputStream`
instance. During servlet execution the default output stream (`.output`)
is redirected to this same object, which is why a plain `Say` writes to
the response body; `.response~output` is the explicit handle, for stream
methods like `~charout` or an explicit `~flush`:

```rexx
.response~output~charout("no trailing newline here")
```

### `unknown`

The message forms described above —

```rexx
.response~content_type = "text/html"   -- set
type = .response~content_type          -- get
```

— are not individual methods: they are resolved by `unknown`, which maps
any unknown message to the header of the same name, translating
underscores to hyphens (so `content_type` reaches `CONTENT-TYPE`). The
set form requires exactly one value, which must have a string value; the
get form accepts no arguments. Reading a header that has not been set
returns `.nil`, exactly as with the bracket form.

Because *every* unknown message becomes a header access, the response
object cannot tell a header from a typo. A misspelled getter that carries
arguments fails fast (`.response~addcokie(c)` raises, since the get form
accepts no arguments), but a misspelled *assignment* fails silently:
`.response~comitted = 1` quietly creates — and emits — a header named
`COMITTED`. Mind your spelling; that is the price of the convenience.


Rationale {.chapter}
====================

This chapter explains the design — not what RexxHTTP does, which the rest
of the manual covers, but why it does it that way. The shape of the 1.0
is the result of a few decisions, most of them inherited from the 2006
original and kept because they are still right, a couple of them new and
made by subtraction.

The largest decision is one of those subtractions, and the rest of this
chapter reads more clearly once it is on the table. The 2006 RexxHTTP
tried to be portable along three axes at once: it ran under both CGI and
mod_rexx, on OS/2 and Windows as well as Unix, and aimed at Microsoft IIS
beside Apache. Much of the original rationale was the bookkeeping of
holding those axes together — reconciling the variables CGI gave you with
the ones mod_rexx gave you, working around an OS/2 Object Rexx that
lacked a `MutableBuffer`, and so on. The 1.0 keeps one point in that
space: CGI, on Apache, on a current ooRexx. mod_rexx is no longer
maintained upstream, IIS and OS/2 are not targets anyone is asking for,
and committing to a single gateway is what lets the rest of the design be
simple. Several of the decisions below were originally compromises
between two gateways; with only one gateway left, they reduce to a single
clear answer, and this chapter states the answer rather than the old
negotiation.

Associating Rexx files with a handler
-------------------------------------

A servlet is an ordinary Rexx file, and the web server has to be told
to run it through RexxHTTP rather than serve it or execute it directly.
Apache's `Action` directive is the mechanism: it binds a handler name to
the RexxHTTP processor, and a small wrapper invokes that handler for the
servlet files you nominate. This is the same approach the 2006 manual
described, and it has aged well precisely because it asks nothing unusual
of Apache — `Action` is a stock directive, and the routing is data in the
configuration rather than logic in the processor.

What has changed is the disposition. In 2006 the natural move was to map
broad extensions — `.htm`, `.html`, `.rsp` — to the handler, because the
point was to run whole trees of pages, some of them compiled, through one
gateway. The 1.0 has no page compilers and no such ambition, and the
[Installation] chapter recommends the opposite default: a whitelist, so
that only the files you explicitly mark are run as servlets and
everything else is served as a static file. On infrastructure that has
served tens of thousands of URLs for years, "run as code only what is
named" is the conservative and correct default; opening an extension to
the handler is the exception, made deliberately.

The environment-variable request model
---------------------------------------

CGI delivers a request as a set of environment variables, and RexxHTTP
takes that literally: the request object answers any message it does not
recognise with the value of the like-named environment variable. This is
the single most Rexx-like decision in the design. Rexx programs reach
their world through `Value` and through variables; making
`request~remote_addr` resolve to the `REMOTE_ADDR` the server set means a
servlet author touches the CGI environment the same way they touch
everything else, without a lookup table or an import step. The mechanics
are in the Class Reference under [The environment pool]; the reason is
that the request object should feel like Rexx, not like a wrapper bolted
over Rexx.

This convenience raises one question. If `request~anything` can name an
environment variable, then a variable could share a name with a method —
present or future — and the author needs a predictable answer to which
one wins. The 2006 manual settled it by carving out a namespace: operator-set
variables had to begin with an underscore, where no method would ever
live. It worked, but it asked the author to remember a naming rule, and
the variables that motivated it — timezone hints for the old
Netscape-style cookies, settings for the page compilers — are all gone
from the 1.0. So the rule went with them, in favour of something
plainer: two doors instead of one reserved name. `request~name` is the
library's view, where a method wins when one exists, exactly as Rexx
method lookup already works; `request["name"]` is the raw variable
underneath, which always reaches the environment pool and never a
method. An operator-set variable is then just an ordinary variable —
`SetEnv MYAPP_MODE production` is `request~myapp_mode`, no underscore
required — and if a future method ever shadowed it, the bracket form
reaches it regardless. The collision question is answered not by
reserving names but by giving the author a way to ask for either side of
one.

The problem of request values
------------------------------

The trickiest part of the 2006 rationale was titled "the problem of
request values," and the problem was real: what Apache actually invokes
is the RexxHTTP processor, not your servlet, so the raw CGI variables
describe the processor's invocation, not the request the servlet means to
read. On top of that, the CGI specification is in places ambiguous or
self-contradictory, and the 2006 system had to paper over differences
between what CGI reported and what mod_rexx reported for the same notion.

With mod_rexx gone, the second half of that problem evaporates: there is
one gateway, so there is nothing to reconcile. What remains is the first
half — reconstructing the values a servlet *should* see from the values
the processor is *handed* — and a commitment the 2006 design made and the
1.0 keeps: where CGI is inconsistent, RexxHTTP is consistent, and it
documents what its methods mean rather than passing the server's quirks
through. Three cases from the original are worth keeping, because the
methods still behave as described and the reasoning is still the cleanest
account of why:

`path_translated` always answers the full filesystem path of the servlet
file, whether or not there is extra path information after it. The CGI
specification's own definition of this variable is incoherent — it
promises a "translated version" of the extra path info, which by
construction has no physical mapping — and Apache, left to itself,
returns something useless. RexxHTTP picks the meaning that is actually
useful and holds to it.

`script_name` always answers the virtual path that locates the servlet,
with any extra path information stripped — what you want for building
self-referential URLs — and `path_info` answers that extra path, decoded,
or the null string when there is none. The split between the two is clean
by design, so a servlet can always ask "where am I?" and "what came after
me?" as separate questions.

`request_uri` (with its alias `unparseduri`) answers the request URI
exactly as the client sent it, still encoded; `uri` answers the decoded
path with the query string removed. Naming both, with stable meanings,
spares the servlet author from guessing which encoding and which trimming
a given server happened to apply.

The thread through all three is the same: the request object is a
*specification* the servlet can rely on, not a thin pass-through of
whatever the gateway felt like reporting.

Strict by default
-----------------

The 1.0 parses GET and POST arguments under a single, default, and
currently only argument policy, `strict`: every parameter must be a
genuine *name*`=`*value* pair, the name must be a usable Rexx symbol and
must be unique caselessly, and a request that breaks any of these is
answered `400 Bad Request` before the servlet runs at all. The mechanics
are in [Arguments, and the strict policy]; the decision is to make this
the default rather than an opt-in.

The reasoning is specific to the kind of service RexxHTTP exists to run.
For a public site with a large, stable set of URLs — the case RexxHTTP
was extracted from — malformed argument input is not a case to be
handled gracefully; it is a request that cannot have come from the
site's own pages, and the safe, predictable response is to reject it at
the door. Strict-by-default turns a class of ambiguous input into a clear
`400`, and in exchange every servlet downstream gets to assume that each
argument it sees has a name and a value, and that a name names exactly
one argument. The strictness is a feature paid for once, at the boundary,
so that no servlet has to pay for it again.

Why the sources are stored CRLF
-------------------------------

The repository stores its sources with CRLF line endings — specifically
the `.rex` and `.cls` files — and this is deliberate, not an accident of
the editing platform. The sources are maintained on Windows, ooRexx reads
CRLF, LF or mixed line endings equally by design, and the wrapper that
Apache executes is the one place the choice would otherwise bite: a
shebang line is sensitive to what follows the interpreter path. Pinning
the convention per file, and documenting it, means a checkout on any
platform materialises sources that run, and that nobody "tidies" the line
endings into a wrapper that no longer executes. The full rule, and how it
is enforced through `.gitattributes`, is in the project's `agents.md`.

Why CGI only
------------

The remaining question the 2006 manual would have asked — why CGI rather
than something faster — now answers itself. mod_rexx, the high-performance
path the original offered alongside CGI, is no longer maintained upstream,
so it is not a path the 1.0 can responsibly ship. CGI is what is left, and
for the workloads RexxHTTP actually carries it is enough: the cost is a
process per request, which on a personal site or a small business — a
large fraction of the real web — disappears into the noise. Choosing the
one gateway that is current and maintained, rather than carrying a second
that is neither, is the same conservative instinct that runs through the
rest of this chapter: ship what is known to work, and say plainly what
was left out.


License {.chapter .unnumbered}
==============================

<!--
  DRAFT (v18). Option A: copyright notice + standard Apache boilerplate +
  pointer to the repo LICENSE, NOT the full 11 KB text (which would bloat
  the PDF and duplicate the canonical copy in the repo). Copyright range
  2006-2026: first publication (v0.1, 2006) to this release (1.0, 2026);
  the 2017 v0.2 was never distributed. The grant is in the present tense
  about THIS version — earlier versions were under the CPL, so the Apache
  grant is not asserted retroactively. Replaces the 2006 CPL appendix.
-->

RexxHTTP is free software, released under the Apache License, Version
2.0.

> Copyright 2006–2026 Josep Maria Blasco
>
> Licensed under the Apache License, Version 2.0 (the "License"); you may
> not use this software except in compliance with the License. You may
> obtain a copy of the License at
>
> > <http://www.apache.org/licenses/LICENSE-2.0>
>
> Unless required by applicable law or agreed to in writing, software
> distributed under the License is distributed on an "AS IS" BASIS,
> WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or
> implied. See the License for the specific language governing
> permissions and limitations under the License.

The complete text of the License accompanies the distribution, in the
file `LICENSE` at the root of the repository.

This release is the first published under the Apache License. The 2006
version was distributed under the Common Public License; the present
1.0, and the manual you are reading, replace it — the licence included.
