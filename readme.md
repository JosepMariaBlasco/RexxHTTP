RexxHTTP
========

RexxHTTP is hosted on:

- <https://rexx.epbcn.com/rexxhttp/> (daily builds *and* releases,
  full documentation).
- <https://github.com/JosepMariaBlasco/rexxhttp/> (releases only,
  documentation is partial due to the limitations of GitHub highlighting).

The documentation copy at <https://rexx.epbcn.com/rexxhttp/> uses
the Rexx Highlighter to display Rexx programs, and therefore has better
highlighting. On the other hand, the copy at
<https://github.com/JosepMariaBlasco/rexxhttp/>
has version control, bug reporting, and all the features offered by GitHub.

What it is
----------

RexxHTTP is a rexxlet processor for [ooRexx](https://en.wikipedia.org/wiki/Object_REXX):
it lets you write web rexxlets as ordinary ooRexx programs running under
CGI on [Apache](https://httpd.apache.org/). A rexxlet receives a `request`
and a `response` object and produces its body with ordinary `Say` or
`CharOut`; the `request` and `response` objects are also placed in the
environment as `.request` and `.response`.

The central design idea is *lazy headers*: a rexxlet may write body content
before fixing the response headers, and the headers are emitted on the
first flush. This is made possible by a buffered output stream that sits
between the rexxlet and Apache.

RexxHTTP is written by Josep Maria Blasco
&lt;<josep.maria.blasco@epbcn.com>&gt; and distributed
under [the Apache 2.0 license](LICENSE). Some files may
contain contributions from other authors, as attributed
in the corresponding copyright notices.

Download
--------

<https://rexx.epbcn.com/rexxhttp/rexxhttp-latest.zip>.

Requirements
------------

- [ooRexx](https://www.oorexx.org/) 5.2.0 or later.
- [Apache](https://httpd.apache.org/) 2.4 or later,
  with `cgid` and `actions` enabled.
- (Optional) [Pandoc](https://pandoc.org/), to
  [render Markdown documents](bin/markdown.rxl) nicely.
  Under Windows, Pandoc should be installed for all users.

Installation
------------

- Automated install, for clean machines: unzip
  [the distribution package](rexxhttp-latest.zip)
  in a directory of your choice, and open a console
  terminal in the `install/` subdirectory (under Windows,
  you have to open the console as an administrator;
  under Linux, you will need the `sudo` password),
  then type `install`.
- Manual installation: please refer to [the manual](rexxhttp.pdf).

Trying it in an AI assistant
----------------------------

If you'd like to experiment with RexxHTTP inside an AI assistant, you can
try our skill at <https://rexx.epbcn.com/skills/rexxhttp.md>, part of the
[Rexx skills collection](https://rexx.epbcn.com/skills/).

History
-------

RexxHTTP grew out of a rexxlet processor first published in 2006
(version 0.1, with [a full 73-page manual](https://www.epbcn.com/pdf/josep-maria-blasco/2006-11-02-RexxHttp-Servlet-programming-in-Rexx.pdf))
and rewritten in 2017 (version 0.2), which today serves
some 40,000 URLs in production at
epbcn.com and other sites. This release is a clean, distilled 1.0:
the dead branches of the original (mod_rexx, OS/2, Microsoft IIS, the RSP page compiler)
are gone, and the documentation describes only what is actually verified
against the code.

Documentation
-------------

The manual is in [rexxhttp.pdf](rexxhttp.pdf).

Examples
--------

You can also take a look at our [examples](examples/) (source
code included).

Repository layout
-----------------

- [`bin/`](bin/) — loadable Rexx served through the site: an example page
  factory ([`HTML.Page.cls`](bin/HTML.Page.cls)), the Pandoc-aware Markdown
  processor ([`markdown.rxl`](bin/markdown.rxl)), and the source viewer
  ([`src-viewer.rxl`](bin/src-viewer.rxl)).
- `css/` — CSS style sheets.
- [`examples/`](examples/) — the examples.
- `install/` — Installation files.
- [`src/`](src/) — the processor and its classes
  ([`RexxHTTP.rex`](src/RexxHTTP.rex),
  [`HTTP.Request.cls`](src/HTTP.Request.cls),
  [`HTTP.Response.cls`](src/HTTP.Response.cls),
  [`HTTP.OutputStream.cls`](src/HTTP.OutputStream.cls),
  [`HTTP.Cookie.cls`](src/HTTP.Cookie.cls)).
- [`tests/`](tests/) — the RexxHTTP test suite and a copy of the ooRexx test framework.

Some sites that use RexxHTTP
----------------------------

+ [This site](./)
+ [Espacio psicoanalítico de Barcelona](https://www.epbcn.com) (<https://www.epbcn.com>).
+ [La cuadrícula de Cerdà](https://eixample.epbcn.com) (<https://eixample.epbcn.com>).
+ [Blog de Josep Maria Blasco](https://blog.jmblasco.com) (<https://blog.jmblasco.com>).
+ [Gabinete de Psicoterapia](https://www.psicoterapiabcn.com) (<https://www.psicoterapiabcn.com>).
