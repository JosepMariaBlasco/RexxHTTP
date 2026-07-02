RexxHTTP integration tests
==========================

End-to-end integration tests for the RexxHTTP rexxlet processor. They
exercise the whole pipeline via Apache + curl: a request goes through
Apache to the wrapper, which `Call`s `RexxHTTP.rex`, which runs a rexxlet;
the generated response (status, headers, body) is then verified.

These are not unit tests of the classes in isolation. The point is to
catch what only shows up through the real stack — lazy headers, cookie
serialisation at commit time, the error page, stdin handling — the same
things that bit earlier sessions when verified any other way.


Prerequisites
-------------

- ooRexx 5.3.0 or later (the minimum supported version)
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

The runner deploys the five sources plus a one-line wrapper to
`/var/www/html/RexxHTTP/`, and configures Apache so that the `Action`
points at the **wrapper**, not at `RexxHTTP.rex` directly:

```
Action RexxHTTPCGI /RexxHTTP/wrapper
```

The wrapper is a one-line LF Rexx script whose only job is to
`Call "/var/www/html/RexxHTTP/RexxHTTP.rex"`. This mirrors the production
deployment and sidesteps the CRLF-shebang problem: the sources are stored
and checked out CRLF (see the repository's `.gitattributes`), so the
kernel cannot exec `RexxHTTP.rex` directly (its `#!` line ends in CR).
Reached via `Call` from the LF wrapper, that shebang is just an inert
comment, and ooRexx reads the CRLF body fine.

The fixtures are deployed to `/var/www/html/test/` with a whitelist
`.htaccess`: only the listed files are handled as rexxlets; anything else
is served statically.

The real production montage may differ in detail. When `setup.md` is
rewritten to the real deployment, the VirtualHost/wrapper resources in
`RunHTTPTests.rex` should be aligned with it.


Test fixtures
-------------

All fixtures are in `fixtures/`. Each is a small rexxlet exercising one
facet of the processor:

| File        | Purpose                                                   |
|-------------|-----------------------------------------------------------|
| `hola`      | Minimal hello-world rexxlet                               |
| `multi`     | Echo GET/POST args in order, including duplicates         |
| `qs`        | Named-argument lookup (Value, Exists)                     |
| `check`     | Report method, script_name, uri                           |
| `setck`     | Set a plain session cookie via `HTTP.Cookie`              |
| `readck`    | Read cookies back from the request                        |
| `setckopts` | Cookie with Max-Age, SameSite, HttpOnly                  |
| `badck`     | Inconsistent cookie (SameSite=None without Secure)        |
| `late`      | Set a header *after* writing body (lazy headers)          |
| `partial`   | Explicit early flush, then more body                      |
| `boom`      | Deliberate runtime error (error page)                     |
| `htmltype`  | Override Content-Type to text/html                        |


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
  rexxlet itself (returning a 404). That guard is not tested here: in this
  montage a direct request to the processor is intercepted by the
  ScriptAlias and fails the CRLF-shebang exec before ooRexx runs. Reaching
  the guard needs a request routed through the wrapper whose request_uri
  contains the processor name, which is a montage concern.
