AGENTS.md
=========

Guidance for AI agents working on the RexxHTTP codebase. Read this
before changing anything. The project is small but it is infrastructure
in production, and a few non-obvious rules will bite you if you don't
know them.

What this project is
--------------------

RexxHTTP is a rexxlet processor for [ooRexx](https://www.oorexx.org/):
it runs web *rexxlets* — ordinary ooRexx programs — under CGI on Apache.
A rexxlet receives a `request` and a `response` object (also available
as `.request` and `.response` in the environment) and produces its body
with `Say` or `CharOut`.

The pipeline, end to end: Apache routes a request to a one-line wrapper,
which `Call`s `RexxHTTP.rex`; the processor builds the request/response
objects, runs the rexxlet, and flushes the response. The response is
buffered, which is what makes *lazy headers* possible — see below.

The full specification is the manual in [`manual/book.md`](manual/book.md).
**The manual is the spec; the code is the state.** When they disagree,
that is a finding to report, not a thing to silently "fix".

The sources
-----------

All in [`src/`](src/):

- `RexxHTTP.rex` — the processor (entry point).
- `HTTP.Request.cls` — the request class.
- `HTTP.Response.cls` — the response class.
- `HTTP.OutputStream.cls` — the buffered output stream (lazy headers).
- `HTTP.Cookie.cls` — the cookie class.

Invariants — do not break these
-------------------------------

This is live infrastructure serving tens of thousands of URLs. The
default bias is **conservative**: no observable behaviour change without
a real HTTP test against Apache to back it. "Looks equivalent" is not
a proof.

1. **The invocation contract is frozen.** A rexxlet receives
   `Use Arg request, response`; `.request`/`.response` exist in the
   environment; `.output` is redirected to the buffered stream during
   the rexxlet's run; `Say` works. Production rexxlets must keep running
   unchanged against any new version. Do not narrow or rename any of this.

2. **`request~unknown` resolution is contract, not detail.**
   `request~whatever` resolves against the environment-variable pool
   (HTTP_* direct; `_var` with a REDIRECT_ fallback; otherwise a direct
   `Value` lookup, cached). Rexxlets depend on this. Do not narrow it.

3. **Lazy headers is the thesis of the design.** Body content can be
   written before the headers are fixed; the commit emits the headers on
   the first flush (whether the rexxlet calls `flush` for an early
   partial response, or the processor flushes automatically at the end).
   Any refactor of the OutputStream must preserve this exactly.

Environment
-----------

- **Minimum ooRexx version: 5.3.0.** Earlier versions are not supported.
  Modern syntax (`.File~separator`, `~isA`, `||=`,
  `Use Strict Arg ... = default`, `caselessContains`, `Select Case`) is
  allowed and used.
- **Apache 2** with the `cgid` and `actions` modules.

Line endings
------------

The repository stores text as LF, but `*.rex` and `*.cls` are
materialised as **CRLF** on checkout (see `.gitattributes`). This is
intentional: the sources are edited on Windows, and ooRexx reads CRLF,
LF, or mixed line endings by design. Do **not** "normalise" line endings
or rewrite `::Requires` over this. When editing a source, check its
line-ending convention per file and preserve it — never assume by folder.

A claude.ai-specific note: that interface translates the first `.` in an
uploaded filename to `_`, so `HTTP.Request.cls` may arrive as
`HTTP_Request.cls`. The file is still really `HTTP.Request.cls`, and the
`::Requires "HTTP.Request.cls"` lines with the dot are correct. Do not
"fix" requires or rename files because of this.

Running the tests
-----------------

End-to-end integration tests live in [`tests/`](tests/). The runner
deploys the sources and fixtures, configures and starts Apache, runs the
suite, and cleans up:

```
rexx tests/http/RunHTTPTests.rex
```

These go through the real stack (Apache + curl) because that is the only
place the things that matter — lazy headers, cookie serialisation at
commit, the error page, stdin handling — actually show up. See
[`tests/http/readme.md`](tests/http/readme.md) for prerequisites, flags,
and the test montage.

When in doubt
-------------

- Read the manual entry for whatever you are touching before touching it.
- A thing that looks like a bug may be a documented decision; a thing
  that looks like a decision may be decay from the 0.2 rewrite. Check the
  manual before concluding either way.
- If a change would alter observable behaviour, stop and surface it
  rather than applying it. This codebase is conservative by design.
