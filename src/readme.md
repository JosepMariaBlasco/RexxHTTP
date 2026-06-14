RexxHTTP — sources
==================

The RexxHTTP servlet processor and its classes.

- `RexxHTTP.rex` — the servlet processor: sets up the request/response
  objects, runs the servlet, and flushes the response.
- `HTTP.Request.cls` — the HTTP request class.
- `HTTP.Response.cls` — the HTTP response class.
- `HTTP.OutputStream.cls` — a buffered output stream for HTTP responses
  (this is what makes lazy headers possible).
- `HTTP.Cookie.cls` — the cookie class.

See [the manual](../manual/) for details and
[the top-level readme](../readme.md) for an overview.
