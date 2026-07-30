RexxHTTP integration tests
==========================

End-to-end integration tests for the RexxHTTP rexxlet processor. They
exercise the whole pipeline via Apache + curl: a request goes through
Apache to `RexxHTTP.rex`, which runs a rexxlet; the generated response
(status, headers, body) is then verified.

These are not unit tests of the classes in isolation. The point is to
catch what only shows up through the real stack — lazy headers, cookie
serialisation at commit time, the error page, stdin handling — the same
things that bit earlier sessions when verified any other way.


Prerequisites
-------------

- ooRexx 5.2.0 or later (the minimum supported version)
- Apache 2 with the `cgid` and `actions` modules
- curl

On Debian/Ubuntu:

```
apt-get install -y apache2
a2enmod cgid actions
```

ooRexx is installed from the epbcn package:

```
curl -sO https://rexx.epbcn.com/oorexx-latest.deb
dpkg -i oorexx-latest.deb
```


Running the tests
-----------------

The simplest way is the runner, which checks prerequisites, deploys the
sources and fixtures, configures and starts Apache, runs the suite, then
stops Apache and cleans up what it created:

```
rexx tests/http/RunHTTPTests.rex
```

Two flags are available:

- `--setup-only` deploys everything and leaves Apache running, but does
  not run the tests (it prints the manual command instead).
- `--no-stop` runs the tests but leaves Apache running afterwards.

The runner targets Linux (including WSL): it uses `apt-get` and Apache
paths specific to Debian/Ubuntu, and it uses `sudo` for the steps that
touch `/var/www` and `/etc/apache2`.

With Apache already set up, the suite can also be run by hand from the
`tests` directory:

```
cd tests
PATH="framework:http:$PATH" rexx http/RexxHTTP.testGroup
```

The tests use `http://127.0.0.1` as the base URL (not `localhost`, to
avoid DNS/proxy surprises). Both the base URL and the path under which
the fixtures are served can be overridden from the environment, so the
runner can point the suite at whatever deployment it set up:

- `REXXHTTP_TEST_BASEURL` (default `http://127.0.0.1`)
- `REXXHTTP_TEST_PATH` (default `/test/`)


The montage
-----------

The runner deploys the five sources to `/var/www/html/RexxHTTP/` and
configures Apache so that the `Action` points straight at `RexxHTTP.rex`:

```
Action RexxHTTPCGI /RexxHTTP/RexxHTTP.rex
```

`RexxHTTP.rex` is LF with a `#!/usr/bin/env rexx` shebang, so the kernel
execs it directly — no wrapper. The LF form is guaranteed at build time:
`pack.rex` aborts the build if `RexxHTTP.rex` carries any CR. This mirrors
the production deployment.

The five sources are `HTTP.Request.cls`, `HTTP.Response.cls`,
`HTTP.OutputStream.cls`, `HTTP.Cookie.cls`, and `RexxHTTP.rex`.

The fixtures are deployed to `/var/www/html/test/` with a whitelist
`.htaccess`: only the listed files are handled as rexxlets; anything else
is served statically. A few fixtures also carry per-fixture `SetEnv`
lines in that `.htaccess` — the arg-policy probes (`polstrict`, `polbad`),
the environment-pool probe (`envpool`), and the URL-reconstruction probes
(`urlprobe`, `urlnobar`, `urlremap`) — so the suite can drive operator
configuration through a real Apache sub-request.

In addition to the flat fixture set, the runner builds a **twelve-cell
CGI-contract topology** (`DeployMatrix`) in two physical zones: a docroot
zone at `/var/www/html/mtx` (served at `/mtx`) and an aliased zone at
`/opt/rexxhttp-matrix` (served at `/ali` via `Alias`). The same `cgivars`
probe is deployed under several names in each zone — as a directly-named
rexxlet, as an `Action` target, and as a `DirectoryIndex` — so the tests
can cover the *docroot-vs-alias*, *rexxlet-vs-DirectoryIndex*, and
*one-hop-vs-two-hop* axes of the CGI variable contract in one place.

The real production montage may differ in detail. When `setup.md` is
rewritten to the real deployment, the conf resources in `RunHTTPTests.rex`
should be aligned with it.


Test fixtures
-------------

All fixtures are in `fixtures/`. Each is a small rexxlet (or, for a few
cases, a plain data file) exercising one facet of the processor. They are
grouped below by the area they probe; the whitelist order in
`RunHTTPTests.rex` is the authoritative list.

Basics and arguments:

| File        | Purpose                                                   |
|-------------|-----------------------------------------------------------|
| `hola`      | Minimal hello-world rexxlet                               |
| `multi`     | Echo GET/POST args in order, including duplicates         |
| `qs`        | Named-argument lookup (Value, Exists)                     |
| `check`     | Report method, script_name, uri                           |
| `readname`  | A field name with a space, percent-/plus-encoded          |
| `arrout`    | `arrayout` array-of-values accessor                       |
| `arroutopt` | `arrayout` accepting a caseless alias (`LINEAS`→LINES)    |
| `argopt`    | Caseless arg accessor accepting an odd-cased name         |
| `methodbody`| PUT/DELETE body/argument contract                         |
| `chunkecho` | Chunked POST body reading                                 |
| `nrdy`      | The three `HTTP.OutputStream` output methods (§3.8 guard) |

Cookies:

| File        | Purpose                                                   |
|-------------|-----------------------------------------------------------|
| `setck`     | Set a plain session cookie via `HTTP.Cookie`             |
| `readck`    | Read cookies back from the request                        |
| `setckopts` | Cookie with Max-Age, SameSite, HttpOnly                  |
| `setpair`   | Two cookies; caller-encoded value round trip (`;`, `+`)   |
| `readpair`  | Read two cookies; `"0"` not reported as a present name    |
| `dupck`     | Duplicate cookie name: by-name is first-wins, count sees both |
| `badck`     | Inconsistent cookie (SameSite=None without Secure) → error |
| `badnm`     | Cookie name carrying a non-ASCII byte                     |
| `bsnm`      | Cookie name carrying a backslash                          |
| `addckfail` | `addcookie` after commit (raises post-flush)              |

Headers, body and flushing:

| File        | Purpose                                                   |
|-------------|-----------------------------------------------------------|
| `late`      | Set a header *after* writing body (lazy headers)          |
| `partial`   | Explicit early flush, then more body                      |
| `htmltype`  | Override Content-Type to text/html                        |
| `ctnorm`    | Content-Type set via bracket + underscore key             |
| `ctnormsp`  | Content-Type via bracket key with a space                 |
| `ctnormqm`  | Content-Type via quoted message name with a space         |
| `ctnormws`  | Content-Type key with leading/trailing/internal whitespace |
| `crlfhdr`   | CRLF injected into a header value (built in code)         |
| `crlfck`    | CRLF injected into a cookie (built in code)               |
| `crlfrdr`   | Double CRLF + smuggled Content-Type in a redirect         |
| `commitfail`| Header set after an explicit flush (raises post-commit)   |
| `flushcrash`| Runtime error *after* an explicit flush                   |

Errors and redirects:

| File        | Purpose                                                   |
|-------------|-----------------------------------------------------------|
| `boom`      | Deliberate runtime error (error page)                     |
| `err404`    | `error(404, ...)` with a message                          |
| `errgen`    | `error(503)` with no message                              |
| `errescape` | Error message with characters needing HTML-escaping       |
| `errreset`  | Body written before `error()` is discarded                |
| `errthenfail`| `error()` then a further failure (double-pop guard, v98) |
| `rdr`       | `redirect()` to a path (default status)                   |
| `rdr301`    | `redirect(..., 301)`                                      |
| `rdr303`    | `redirect(..., 303)`                                      |

Argument policy, environment pool and URL reconstruction:

| File        | Purpose                                                   |
|-------------|-----------------------------------------------------------|
| `polstrict` | `REXXHTTP_ARGPOLICY Strict` honoured (caseless)           |
| `polbad`    | Unknown `REXXHTTP_ARGPOLICY` value → 500                  |
| `envpool`   | `[]` reaches the environment pool; REDIRECT_ fallback     |
| `enc`       | Encoder family via the instance accessor                  |
| `urlprobe`  | script_name/request_url that match the real topology      |
| `urlnobar`  | URL reconstruction via the base=="" fallback              |
| `urlremap`  | URLBASE injects a prefix, proving live RFC reconstruction |

CGI-variable contract matrix:

| File        | Purpose                                                   |
|-------------|-----------------------------------------------------------|
| `cgivars`   | Probe deployed across the twelve-cell topology (`DeployMatrix`) |
| `headwrap`  | Wrapper that always delivers a fixed file (`headwrap.data`) |


What is tested
--------------

- **Hello world**: status 200, body, Content-Type, and the LF-only body
  convention (the body uses LF, headers stay CRLF per RFC).
- **GET arguments**: count, order, duplicate names, percent- and
  plus-decoding.
- **Named lookup**: Value, and Exists for present/absent args.
- **POST arguments**: count, value, and method reporting.
- **Request properties**: method, script_name (query excluded), uri.
- **Cookies**: Set-Cookie emission, the full attribute string
  (Max-Age/SameSite/HttpOnly), a browser-style round trip via a cookie
  jar, and the strict guard — an inconsistent cookie now raises inside
  the rexxlet (at `addcookie`), so RexxHTTP's own error page renders
  rather than a bare Apache 500.
- **Lazy headers**: a header set after the body was written still appears.
- **Partial flush**: an explicit early flush still yields the full body.
- **Error page**: rendered on a rexxlet runtime error as plain text, with
  the program path trimmed to the DOCUMENT_ROOT-relative form and an
  ooRexx-style traceback (from the condition's stack frames).
- **Unconsumed POST body**: a POST whose body the rexxlet never reads
  still returns a complete response (the processor reads the body eagerly
  while parsing arguments).


Framework
---------

`HTTPTestCase.cls` extends the official ooTest `ooTestCase` with:

- **`httpGet(url [, jar])`** — HTTP GET via curl; returns a Directory with
  `status`, `body`, and the raw `headers` block. An optional cookie-jar
  file makes successive calls share cookies (real round trips).
- **`httpPost(url, data [, jar])`** — HTTP POST with a urlencoded body.
- **`httpHead(url [, jar])`** — HTTP HEAD (headers only).
- **`httpGetCookie(url, jar)`** — GET that records the response cookies
  into the given jar, for a subsequent round-trip read.
- **`httpPostChunked(url, data [, jar])`** — POST with a chunked
  transfer-encoded body, to exercise streamed body reading.
- **`httpVerb(verb, url [, data [, jar]])`** — arbitrary method (PUT,
  DELETE, ...), for the method/body contract tests.
- **`assertContains` / `assertNotContains`** — caseless body substring
  checks.
- **`assertHeader(headers, name, valueSubstring, label)`** — assert a
  response header line matches name + value substring (both caseless).
- **`assertNoHeader(headers, name, label)`** — assert no such header.

The ooTest framework itself lives in `../framework/` (the Rexx Language
Association's official files, carried verbatim).


Notes and known limitations
----------------------------

- **Direct-call 404**: `RexxHTTP.rex` guards against being run as a
  rexxlet itself (returning a 404). With the Action pointing straight at
  the LF processor, a direct URL hit runs it as a plain CGI under the
  ScriptAlias, `REDIRECT_HANDLER` is empty, and the guard fires. Its 404
  page is byte-shaped like Apache's stock 404 on purpose, so the suite
  asserts on the status. This *is* tested here (`test_direct_invocation_404`),
  along with the v99 regression tests that a query string merely mentioning
  the processor name does not spuriously 404 a valid rexxlet.
