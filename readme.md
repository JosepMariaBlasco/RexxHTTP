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

RexxHTTP is a servlet processor for [ooRexx](https://en.wikipedia.org/wiki/Object_REXX):
it lets you write web servlets as ordinary ooRexx programs running under
CGI on [Apache](https://httpd.apache.org/). A servlet receives a `request`
and a `response` object and produces its body with ordinary `Say` or
`CharOut`; the `request` and `response` objects are also placed in the
environment as `.request` and `.response`.

The central design idea is *lazy headers*: a servlet may write body content
before fixing the response headers, and the headers are emitted on the
first flush. This is made possible by a buffered output stream that sits
between the servlet and Apache.

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

- [ooRexx](https://www.oorexx.org/) 5.3.0 or later.
- [Apache](https://httpd.apache.org/) 2.0 or later, with `cgid` and
  `actions` enabled.

History
-------

RexxHTTP grew out of a servlet processor first published in 2006
(version 0.1, with a full 73-page manual) and rewritten in 2017
(version 0.2), which today serves some 40,000 URLs in production at
epbcn.com. This release is a clean, distilled 1.0: the dead branches of
the original (mod_rexx, OS/2, Microsoft IIS, the RSP page compiler) are
gone, and the documentation describes only what is actually verified
against the code.

Documentation
-------------

The manual is in [manual/](manual/). It is written for
[Pandoc Markdown](https://pandoc.org/) and rendered as a book.

Repository layout
-----------------

- [`src/`](src/) — the processor and its classes (`RexxHTTP.rex`,
  `HTTP.Request.cls`, `HTTP.Response.cls`, `HTTP.OutputStream.cls`,
  `HTTP.Cookie.cls`).
- [`manual/`](manual/) — the manual.
- [`tests/`](tests/) — the RexxHTTP test suite and a copy of the ooRexx test framework.

Some sites that use RexxHTTP
----------------------------

+ [This site](https://rexx.epbcn.com) (<https://rexx.epbcn.com>).
+ [Espacio psicoanalítico de Barcelona](https://www.epbcn.com) (<https://www.epbcn.com>).
+ [La cuadrícula de Cerdà](https://eixample.epbcn.com) (<https://eixample.epbcn.com>).
+ [Blog de Josep Maria Blasco](https://blog.jmblasco.com) (<https://blog.jmblasco.com>).
+ [Gabinete de Psicoterapia](https://www.psicoterapiabcn.com) (<https://www.psicoterapiabcn.com>).
