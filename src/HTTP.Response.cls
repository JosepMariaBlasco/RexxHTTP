/******************************************************************************/
/*                                                                            */
/* HTTP.Response.cls - The HTTP response class                                */
/* ===========================================                                */
/*                                                                            */
/* This file is part of the RexxHTTP package                                  */
/* [See https://rexx.epbcn.com/rexxhttp/]                                     */
/*                                                                            */
/* Copyright (c) 2006-2026 Josep Maria Blasco <josep.maria.blasco@epbcn.com>  */
/*                                                                            */
/* License: Apache License 2.0 (https://www.apache.org/licenses/LICENSE-2.0)  */
/*                                                                            */
/* Version history:                                                           */
/*                                                                            */
/* Date     Version Details                                                   */
/* -------- ------- --------------------------------------------------------- */
/* 20061102    0.1  First version                                             */
/* 20170301    0.2  Drop support for mod_rexx, OS/2, IIS, rsp compilers       */
/*                  Change the way request~message works -- see 'unknown'.    */
/*                  By default, it looks in the environment variable pool.    */
/* 20260611    1.0  Global refactor, switch to Apache license                 */
/* 20260615         Add encoding methods                                      */
/* 20261121         THROW instead of RAISE for SYNTAX                         */
/*                                                                            */
/******************************************************************************/

.environment~HTTP.Response = .HTTP.Response

::Class HTTP.Response Public

--------------------------------------------------------------------------------
-- INIT method                                                                --
--------------------------------------------------------------------------------

::Method init
  Expose output headers cookies committed committing

  headers    = .directory~of( ("CONTENT-TYPE", "text/plain; charset=utf-8") )
  cookies    = .directory~new
  committed  = .false
  committing = .false

  output = .HTTP.OutputStream~new(.output~current, self)

--------------------------------------------------------------------------------
-- [] Method                                                                  --
--------------------------------------------------------------------------------

::Method "[]"
  Expose headers

  Use Strict Arg headername

  headername = .Validate~requestClassType(1, headername, .String)

  Return headers[headername~space~upper~translate("--","_ ")]

--------------------------------------------------------------------------------
-- []= Method                                                                 --
--------------------------------------------------------------------------------

::Method "[]="
  Expose headers committed

  If committed Then
    Throw syntax 93.900 array (-
      "Cannot set a header: the response is already committed")

  Use Strict Arg headervalue, headername

  headervalue = .Validate~requestClassType(1, headervalue, .String)
  headername  = .Validate~requestClassType(2, headername,  .String)

  self~rejectControlChars("Header '"headername"' value", headervalue)

  headers[headername~space~upper~translate("--","_ ")] = headervalue

--------------------------------------------------------------------------------
-- ADDCOOKIE method                                                           --
--------------------------------------------------------------------------------

::Method addcookie
  Expose cookies committed

  -- Same fail-fast as []= and unknown: no header mutation is silently
  -- dropped after commit. The commit state outranks argument validation,
  -- so this guard precedes the type check below.
  If committed Then
    Throw syntax 93.900 array (-
      "Cannot add a cookie: the response is already committed")

  Use Strict Arg Cookie

 If \Cookie~isA(.HTTP.Cookie) Then
    Throw syntax 93.948 array (1,"HTTP.COOKIE")

  name   = Cookie~name
  path   = Cookie~path
  domain = Cookie~domain

  -- Force validation/serialisation now, while we are still inside the
  -- rexxlet, so an inconsistent cookie raises here (and RexxHTTP's error
  -- page can render) instead of at commit time, past the point of no
  -- return. makestring memoises its result, so commit will not recompute.
  Cookie~makestring

  cookies[name";"path";"domain] = Cookie~copy

--------------------------------------------------------------------------------
-- COMMIT                                                                     --
--------------------------------------------------------------------------------

::Method commit
  Expose output committed committing headers cookies

  -- Do nothing if already committed

  If committed Then Return

  -- Point of no return: from here on, header bytes go to the stream. The
  -- committing flag lets the error handler tell "mid-commit" (some headers
  -- already emitted, committed still .false) apart from "untouched", so it
  -- never re-asserts headers over a half-written response.
  committing = .true

  out = output~underlyingstream
  out~Say("Content-Type:" self~content_type)
  Do e over cookies
    out~Say("Set-Cookie:" cookies[e]~makestring)
  End
  Do e over headers
    If e == "CONTENT-TYPE" Then Iterate
    out~Say(self~prettyHeader(e)":" headers[e])
  End
  out~Say()

  committed = .true

--------------------------------------------------------------------------------
-- COMMITTED / COMMITTING -- read-only state flags                           --
--------------------------------------------------------------------------------
--
-- committed  is .true once the headers have been emitted (end of commit).
-- committing is .true from the moment commit starts emitting, so it covers
-- the mid-commit window where committed is still .false. Both are Get-only:
-- the response sets them internally; nothing outside may force them.
--

::Attribute committed  Get
::Attribute committing Get

--------------------------------------------------------------------------------
-- FLUSH                                                                      --
--------------------------------------------------------------------------------

::Method flush
  Expose output committed
  Use Strict Arg

  If \committed Then self~commit

  x = output~flush  -- Throw away the result (always "READY:")

--------------------------------------------------------------------------------
-- OUTPUT                                                                     --
--------------------------------------------------------------------------------

::Method output
  Expose output
  Use Strict Arg
  Return output

--------------------------------------------------------------------------------
-- PRETTYHEADER -- Title-case a header name for emission only                 --
--------------------------------------------------------------------------------
--
-- Headers are stored UPPERCASE in the directory, which is what makes the
-- case-insensitive lookup work (content_type, ["Content-Type"] and
-- [Content Type] all hit the same entry). This is purely cosmetic: when we
-- emit a header we title-case each dash-separated word (CONTENT-TYPE ->
-- Content-Type, LOCATION -> Location). The mechanical rule is right for
-- every header we emit; acronyms like WWW-Authenticate would come out as
-- Www-Authenticate, but those are request headers we never send, so no
-- exception table is kept. The stored key is never touched.
--

::Method prettyHeader Private
  Use Strict Arg name
  parts = name~translate(" ","-")~makeArray(" ")
  Do i = 1 To parts~items
    w = parts[i]
    parts[i] = w~left(1)~upper || w~substr(2)~lower
  End
  Return parts~makeString("Line","-")

--------------------------------------------------------------------------------
-- REJECTCONTROLCHARS -- Fail fast on CR/LF (or any control char) at the       --
-- origin, before a value reaches headers/cookies/commit.                     --
--------------------------------------------------------------------------------
--
-- Measured against Apache 2.4.58 (audit-core-20260725.md §2.1): a CR/LF pair
-- in a header value, a redirect location, or a cookie value/path/domain is
-- NOT filtered by Apache. A single CRLF injects an extra header; a double
-- CRLF closes the header block early and lets the attacker supply the body
-- (and, via a smuggled Content-Type, run arbitrary HTML/JS in the app's own
-- origin). Rejecting here -- at the exact rexxlet line that set the bad
-- value -- rather than centrally in commit is deliberate (JMB, v98): a
-- central check would still catch it, but the traceback would point at
-- commit, not at the offending Say/response[...]=/redirect(...) call, which
-- is what actually needs debugging. Same control-character test already used
-- by HTTP.Cookie~validatename, for one rule across the package.
--

::Method rejectControlChars Private
  Use Strict Arg label, s
  Do i = 1 To s~length
    c = s~substr(i,1)
    If c~c2d < 32 | c~c2d == 127 Then
      Throw syntax 93.900 array (-
        label "contains a control character (CR, LF, or other; 0x"c~c2x")" -
        "at position" i "-- rejected to prevent HTTP response splitting")
  End
  Return

--------------------------------------------------------------------------------
-- STATUSREASON -- Reason phrase for an HTTP status code                      --
--------------------------------------------------------------------------------
--
-- A short table covering the codes our apps actually use. A code that is not
-- in the table falls back to a generic reason for its family (3xx Redirect,
-- 4xx Client Error, 5xx Server Error), so an unusual code is never rejected;
-- it just gets a decent phrase. The rexxlet model allows arbitrary status.
--

::Method statusReason
  Expose reasons
  Use Strict Arg code

  If \reasons~isA(.Directory) Then Do
    reasons = .Directory~new
    reasons[301] = "Moved Permanently"
    reasons[302] = "Found"
    reasons[303] = "See Other"
    reasons[307] = "Temporary Redirect"
    reasons[308] = "Permanent Redirect"
    reasons[400] = "Bad Request"
    reasons[401] = "Unauthorized"
    reasons[403] = "Forbidden"
    reasons[404] = "Not Found"
    reasons[405] = "Method Not Allowed"
    reasons[500] = "Internal Server Error"
    reasons[502] = "Bad Gateway"
    reasons[503] = "Service Unavailable"
  End

  If reasons~hasIndex(code) Then Return reasons[code]

  -- Generic fallback by family (first digit)
  Select Case code~left(1)
    When "3" Then Return "Redirect"
    When "4" Then Return "Client Error"
    When "5" Then Return "Server Error"
    Otherwise     Return "Status"
  End

--------------------------------------------------------------------------------
-- ENCODEHTML -- Escape text for safe interpolation into HTML                 --
--------------------------------------------------------------------------------
--
-- Escapes the five characters that are unsafe in HTML markup, including
-- attribute context: & < > " '. Available both as a class method
-- (.HTTP.Response~encodeHTML(s), no instance needed) and as an instance
-- method (.response~encodeHTML(s)). The instance method delegates to the
-- class method; the body lives once, on the class.
--

::Method encodeHTML Class
  Use Strict Arg text
  Return text~changeStr("&","&amp;")~changeStr("<","&lt;") -
             ~changeStr(">","&gt;")~changeStr('"',"&quot;") -
             ~changeStr("'","&#39;")

::Method encodeHTML
  Use Strict Arg text
  Return .HTTP.Response~encodeHTML(text)

--------------------------------------------------------------------------------
-- ENCODEURICOMPONENT -- Percent-encode a single URL component (RFC 3986)     --
--------------------------------------------------------------------------------
--
-- Escapes everything that is not RFC 3986 unreserved (A-Z a-z 0-9 - . _ ~).
-- Space becomes %20. Use for a value that goes inside a URL (a query field,
-- a path segment): it escapes the reserved characters & / = ? # so they
-- cannot break the surrounding URL structure. Contrast with encodeURI, which
-- leaves the reserved characters intact for an already-formed URL.
--

::Method encodeURIComponent Class
  Use Strict Arg from
  to        = .mutablebuffer~new
  unreserved = XRange("A","Z")XRange("a","z")XRange("0","9")"-._~"
  Do i = 1 To from~length
    c = from~substr(i,1)
    If Pos(c,unreserved) = 0 Then c = "%"c~c2x
    to~append(c)
  End
  Return to~string

::Method encodeURIComponent
  Use Strict Arg from
  Return .HTTP.Response~encodeURIComponent(from)

--------------------------------------------------------------------------------
-- ENCODEURI -- Percent-encode an already-formed URL (RFC 3986)               --
--------------------------------------------------------------------------------
--
-- Escapes illegal and unwise characters (controls, space, high ASCII, and
-- < > % " { } [ ] \ ^ `) but RESPECTS the reserved characters that give a
-- URL its structure (/ ? # & = @ : + ; , $ ! ' ( ) *). Space becomes %20.
-- Use on a whole URL; use encodeURIComponent on a piece that goes inside
-- one. (This is the JS pair: they differ by one word and do opposite things
-- with & / = -- pick deliberately.)
--

::Method encodeURI Class
  Use Strict Arg from
  to     = .mutablebuffer~new
  escape = XRange('00'x,'20'x)XRange('80'x,'ff'x)'<>%"{}[]\^`'
  Do i = 1 To from~length
    c = from~substr(i,1)
    If Pos(c,escape) > 0 Then c = "%"c~c2x
    to~append(c)
  End
  Return to~string

::Method encodeURI
  Use Strict Arg from
  Return .HTTP.Response~encodeURI(from)

--------------------------------------------------------------------------------
-- ENCODEFORM -- Percent-encode for application/x-www-form-urlencoded         --
--------------------------------------------------------------------------------
--
-- Twin of encodeURIComponent with the two differences the form-urlencoded
-- media type mandates (WHATWG URL Standard): (a) the safe set is more
-- aggressive -- only A-Z a-z 0-9 * - . _ stay raw (note that ~ IS escaped here,
-- unlike in encodeURIComponent); (b) space becomes "+", not %20. This is the
-- conforming serialisation for a form body; decodeForm is its inverse.
--

::Method encodeForm Class
  Use Strict Arg from
  to   = .mutablebuffer~new
  safe = XRange("A","Z")XRange("a","z")XRange("0","9")"*-._"
  Do i = 1 To from~length
    c = from~substr(i,1)
    If c == " " Then c = "+"
    Else If Pos(c,safe) = 0 Then c = "%"c~c2x
    to~append(c)
  End
  Return to~string

::Method encodeForm
  Use Strict Arg from
  Return .HTTP.Response~encodeForm(from)

--------------------------------------------------------------------------------
-- ERROR -- Emit an error response with the given status code                 --
--------------------------------------------------------------------------------
--
-- error(status [,detail]) sets the status, discards any buffered body that
-- has not been flushed, and writes a sober HTML5 error page. detail, if
-- given, is shown (HTML-escaped) as a diagnostic line.
--
-- Rexxlet semantics: if the response is already committed, the headers have
-- already gone to the client and the status cannot be changed, so this
-- raises (the ooRexx equivalent of IllegalStateException). Otherwise it
-- returns 0, so the one-line idiom "Exit .response~error(404)" works.
--

::Method error
  Expose output headers committed

  Use Strict Arg status, detail = ""

  If self~committed Then
    Throw syntax 93.900 array (-
      "Cannot send an error response: the response is already committed")

  -- Discard any body buffered before this call (e.g. a half-built page).
  -- Mirrors redirect(); without it the stale body leaks ahead of the error
  -- page. Safe here: committed output was ruled out just above.
  output~reset

  reason = self~statusReason(status)
  title  = status reason

  If .output~current~isA( .HTTP.OutputStream ) Then
   .output~destination

  Say "Content-type: text/html; charset=utf-8"
  Say "Status:" status reason
  Say ""

  Say "<!DOCTYPE html>"
  Say "<html lang=""en"">"
  Say "<head>"
  Say "<meta charset=""utf-8"">"
  Say "<meta name=""viewport"" content=""width=device-width, initial-scale=1"">"
  Say "<title>"self~encodeHTML(title)"</title>"
  Say "<style>"
  Say "  body{font:16px/1.5 system-ui,sans-serif;max-width:40rem;"-
        "margin:4rem auto;padding:0 1.5rem;color:#1a1a1a}"
  Say "  h1{font-size:1.5rem;margin:0 0 .5rem}"
  Say "  .code{color:#888;font-variant-numeric:tabular-nums}"
  Say "  p{margin:.5rem 0;color:#444}"
  Say "</style>"
  Say "</head>"
  Say "<body>"
  Say "<h1><span class=""code"">"status"</span>" self~encodeHTML(reason)"</h1>"
  If detail \== "" Then
    Say "<p>"self~encodeHTML(detail)"</p>"
  Say "</body>"
  Say "</html>"

  committed = .True
  Return 0

--------------------------------------------------------------------------------
-- 404 -- Shorthand for error(404 [,detail])                                  --
--------------------------------------------------------------------------------

::Method 404
  Use Strict Arg detail = ""
  Return self~error(404, detail)

--------------------------------------------------------------------------------
-- REDIRECT -- Emit a redirect to the given location                          --
--------------------------------------------------------------------------------
--
-- redirect(location [,status]) sets Location and a 3xx status. status
-- defaults to 302 Found, the conventional temporary redirect. A permanent
-- (301) or Post/Redirect/Get (303) redirect is requested explicitly.
-- Same commit discipline as error: raises if already committed, otherwise
-- returns 0 for the "Exit .response~redirect(url)" idiom. No body is sent.
--

::Method redirect
  Expose output headers
  Use Strict Arg location, status = 302

  If self~committed Then
    Throw syntax 93.900 array (-
      "Cannot redirect: the response is already committed")

  self~rejectControlChars("Redirect location", location)

  reason = self~statusReason(status)

  output~reset

  headers["STATUS"]   = status reason
  headers["LOCATION"] = location

  Return 0

--------------------------------------------------------------------------------
-- UNKNOWN                                                                    --
--------------------------------------------------------------------------------

::Method unknown
  Expose headers committed

  Use arg message, args

  -- "response~content_type = 'text/plain'" syntax

  If message~right(1) == "=" Then Do
    If committed Then
      Throw syntax 93.900 array (-
        "Cannot set a header: the response is already committed")
    headername = message~left(message~length-1)~space~upper~translate("--","_ ")
    If args~dimension(1) < 1 Then Throw syntax 93.901 array (1)
    If args~dimension(1) > 1 Then Throw syntax 93.902 array (1)
    headervalue = .Validate~requestClassType(1, args[1], .String)
    self~rejectControlChars("Header '"headername"' value", headervalue)
    headers[headername] = headervalue
    Return
  End

  -- "response~content_type" syntax

  If args~dimension(1) > 0 Then Throw syntax 93.902 array (0)

  Return headers[message~space~upper~translate("--","_ ")]
