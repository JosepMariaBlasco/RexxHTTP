RexxHTTP — sources
==================

The RexxHTTP rexxlet processor and its classes.

- [`RexxHTTP.rex`](RexxHTTP.rex) — the rexxlet processor: sets up the
  request/response objects, runs the rexxlet, and flushes the response.
- [`HTTP.Request.cls`](HTTP.Request.cls) — the HTTP request class.
- [`HTTP.Response.cls`](HTTP.Response.cls) — the HTTP response class.
- [`HTTP.OutputStream.cls`](HTTP.OutputStream.cls) — a buffered output
  stream for HTTP responses (this is what makes lazy headers possible).
- [`HTTP.Cookie.cls`](HTTP.Cookie.cls) — the cookie class.
- [`RexxHTTP.CommonRoutines.cls`](RexxHTTP.CommonRoutines.cls) — a reserved
  home for helper routines shared across rexxlets. Empty by design; a rexxlet
  loads it by absolute path anchored at `REXXHTTP_BASE` (see the file header).

See [the manual](../rexxhttp.pdf) for details and
[the top-level readme](../readme.md) for an overview.
