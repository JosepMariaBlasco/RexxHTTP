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

The pipeline, end to end: Apache invokes `RexxHTTP.rex` directly (via its
`#!` shebang — on Unix pinned to an absolute path if Apache's `PATH` does
not see `rexx`, on Windows through the `#!rexx` token); the processor
builds the request/response objects, runs the rexxlet, and flushes the
response. The response is buffered, which is what makes *lazy headers*
possible — see below.

The full specification is the manual in [`rexxhttp.pdf`](rexxhttp.pdf).
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
- `RexxHTTP.CommonRoutines.cls` — reserved home for routines shared across
  rexxlets. Empty by design; loaded by `loadPackage` from `REXXHTTP_BASE`.

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
   `request~whatever` resolves against the environment-variable pool by a
   **single branch** with a **single cache**: a direct `Value` lookup and,
   if that comes back empty, a fallback to `REDIRECT_`*name*. There are no
   per-prefix branches. Neither the underscore nor `HTTP_` is a special
   namespace: a client header and an operator-defined variable resolve by
   the same path, with or without a prefix (the `_var` branch was dropped
   in v19; the `HTTP_*` one in v113 — measured: Apache never fabricates
   `REDIRECT_HTTP_*`, so the fallback is inert for those names). Rexxlets
   depend on this. Do not narrow it.

3. **Lazy headers is the thesis of the design.** Body content can be
   written before the headers are fixed; the commit emits the headers on
   the first flush (whether the rexxlet calls `flush` for an early
   partial response, or the processor flushes automatically at the end).
   Any refactor of the OutputStream must preserve this exactly.

4. **Conditions: THROW, CATCH and FINALLY, with one exception.** The
   classes throw their SYNTAX errors (`Throw syntax 93.9xx ...`; for SYNTAX
   it reports exactly what RAISE did, only `THROWN` is 1). The read side of
   `HTTP.OutputStream` keeps `Raise notready`: it must behave as `.stdout`
   does, and a thrown NOTREADY is not trapped by `Call On Notready`
   (measured). A configuration error is `Throw user RexxHTTP.ConfigError`,
   with the reason as its description. `RexxHTTP.rex` runs as one DO block:
   its CATCH clauses report `RexxHTTP.ConfigError` and SYNTAX as 500 pages,
   and a FINALLY clause around the call of the rexxlet restores `.output`.
   Around the call only, a `Catch any` handles what the rexxlet leaves
   uncaught (`RexxletCondition`): SYNTAX, any condition it *threw*, and a
   raised HALT get the 500 page (error 4.1, or 4.901 with a description,
   for the last two); anything else it *raised* is ignored, as before. Keep
   that clause around the call alone: an active `Catch any` counts as a
   NOVALUE trap for the code of its own block. With `REXXHTTP_LOGERRORS`
   set to 1 (yes, true, on), the error reports also go to stderr, that is,
   to the server's error log (`LogError`); unset, nothing changes.

The request/response contract
-----------------------------

Details a rexxlet author relies on that the manual does not yet cover.
These are behaviour, not implementation notes: hold them frozen like the
invariants above.

### HTTP methods and where arguments come from

Version 1.0 supports **GET, POST, PUT and DELETE**. Argument source is
asymmetric on purpose:

- **GET, PUT and DELETE** take their arguments from the **query string**.
- **POST** takes them from the **body**.

PUT and DELETE bodies are read (they must be drained, or the request
hangs Apache waiting on stdin) but **not parsed** as arguments: the raw
body is left untouched in `request~post_string` for the rexxlet to
interpret however it likes — JSON, binary, an opaque resource. Parsing a
PUT body as form arguments would fire the strict arg-policy with a bogus
400 on a JSON payload, so it is deliberately left raw. (`chunked` bodies
are handled too; the raw body still lands in `post_string`.)

### HEAD

HEAD is supported, and there are two ways it plays out:

- **Default** — a rexxlet that does not branch on the method runs in
  full under HEAD, and **Apache prunes the body** on the way back. Its
  side effects execute exactly as they would under GET; only the emitted
  body is discarded. The query string reaches it just like GET. The
  framework deliberately does **not** intercept HEAD: in plain CGI there
  is no general way to produce a rexxlet's headers without running it
  (lazy headers, invariant 3), so a real `Content-Length` requires
  executing the body and letting Apache prune it.
- **Optimised** — a rexxlet that already knows its answer may branch on
  `request~method == "HEAD"`, set its headers (e.g. from a file `stat`),
  and `Return` without writing a body, to skip the body work. The
  `headwrap` fixture is the canonical example.

One caveat: the response `Content-Length` is governed by **Apache, not
the rexxlet**. `mod_cgi` recomputes it from the actual body emitted and
ignores whatever the script declares; on an optimised HEAD, with no body
to measure, Apache emits no `Content-Length` at all. So the optimised
HEAD is cheap but arrives without a `Content-Length` — an unavoidable
trade-off against the default (which has the length but runs the body).

### Header-key normalisation on the response

`response[key]`, `response[key] = value`, and the attribute forms
(`response~content_type`, `response~content_type = ...`) all resolve to
the **same key**. Word separators are interchangeable: hyphen, underscore
and space are equivalent, so `response["Content-Type"]`,
`response["Content_Type"]` and `response["Content Type"]` are one key.
Matching is caseless. Outer whitespace is trimmed and interior runs are
collapsed, so `response["  content   type  "]` is still `Content-Type` —
the key is robust to sloppy spacing.

A **quoted** message with a space (`response~"Content type" = ...`) is a
distinct, valid path that converges too: `response~"Content type"`,
`response~content_type`, and the three bracket forms above are all the
same key.

Environment
-----------

- **Minimum ooRexx version: 5.3.0 r13572.** Earlier versions are not supported.
  From that revision ooRexx carries the Rexx Parser (`parser.cls` and its
  `parser/` folder, in ooRexx's bin directory), which the viewers use to
  highlight (`ParserComponent`, in `bin/src-viewer.cls`). No stand-alone Parser.
- **Apache 2** with the `cgid` and `actions` modules.

Line endings
------------

The whole tree is **LF**. This is enforced: `pack.rex` walks the tree
before packaging and aborts (Exit 1) if any editable file carries a `CR`.
The check is a blacklist, not a whitelist of extensions — it excludes
`*.svg` (ebnf2svg generates them CRLF on purpose), `*.css` (refreshed by
pack from the Parser), `*.pdf`, `*.zip`, `*trace.xml`, and `pack.rex`
itself; everything else must be LF. When editing or adding a source, keep
it LF — a stray CRLF will fail the pack. (Historical note: the sources
used to be materialised as CRLF on checkout via `.gitattributes`, for
editing on Windows; that was retired and the tree migrated to LF.)

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
