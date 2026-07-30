/******************************************************************************/
/*                                                                            */
/* HTTPTestCase.cls - ooTestCase subclass for RexxHTTP integration tests      */
/* ====================================================================       */
/*                                                                            */
/* This file is part of the RexxHTTP package                                  */
/* [See https://rexx.epbcn.com/rexxhttp/]                                     */
/*                                                                            */
/* Copyright (c) 2006-2026 Josep Maria Blasco <josep.maria.blasco@epbcn.com>  */
/*                                                                            */
/* License: Apache License 2.0 (https://www.apache.org/licenses/LICENSE-2.0)  */
/*                                                                            */
/* Provides HTTP helpers (curl-backed) plus body/header assertions for the    */
/* RexxHTTP rexxlet-processor integration tests. Modelled on the Rexx Parser  */
/* CGITestCase, extended to capture response headers (Set-Cookie, lazy        */
/* headers, Content-Type), to issue POST requests, and to carry a cookie jar  */
/* for round-trip tests.                                                      */
/*                                                                            */
/* Version history:                                                           */
/*                                                                            */
/* Date     Version Details                                                   */
/* -------- ------- --------------------------------------------------------- */
/* 20260611    1.0  First version                                             */
/*                                                                            */
/******************************************************************************/

::Requires "ooTest.frm"

::Class HTTPTestCase Subclass ooTestCase Public

/******************************************************************************/
/* httpGet: perform an HTTP GET via curl. Returns a Directory with:           */
/*   status  - the HTTP status code as a string ("200", "404", ...)           */
/*   body    - the response body (text), lines joined with LF                 */
/*   headers - the raw response header block (text), as returned by curl -D   */
/*                                                                            */
/* An optional cookie jar file may be supplied. If given, curl reads it with  */
/* -b (sends stored cookies) and writes it with -c (stores Set-Cookie), so    */
/* successive calls sharing one jar perform a real browser-style round trip.  */
/******************************************************************************/

::Method httpGet
  Use Strict Arg url, jar = ""
  Return self~curl("GET", url, "", jar)

/******************************************************************************/
/* httpPost: perform an HTTP POST via curl with a urlencoded body.            */
/* The data argument is sent verbatim as the request body with               */
/* Content-Type application/x-www-form-urlencoded (curl's --data default).    */
/******************************************************************************/

::Method httpPost
  Use Strict Arg url, data, jar = ""
  Return self~curl("POST", url, data, jar)

/******************************************************************************/
/* httpHead: perform an HTTP HEAD via curl (--head). The response carries     */
/* headers but no body, by definition; the returned Directory's "body" entry  */
/* is therefore expected to be empty. Used to assert the HEAD contract: same  */
/* headers a GET would set, no body, query string passed through.             */
/******************************************************************************/

::Method httpHead
  Use Strict Arg url, jar = ""
  Return self~curl("HEAD", url, "", jar)

/******************************************************************************/
/* curl (private): the workhorse. Writes status, body and headers to temp     */
/* files, reads them back, and returns them in a Directory.                   */
/******************************************************************************/

::Method curl Private
  Use Strict Arg verb, url, data, jar

  response = .Directory~new

  tmpBody = "/tmp/rexxhttp-test-body.tmp"
  tmpHdr  = "/tmp/rexxhttp-test-hdr.tmp"
  tmpStat = "/tmp/rexxhttp-test-stat.tmp"

  -- Assemble the curl command. -s silent, --noproxy to dodge any local proxy,
  -- -D dumps response headers, -o writes the body, -w prints the status code.
  opts = "-s --noproxy 127.0.0.1"
  If jar \== "" Then opts = opts "-b" jar "-c" jar
  If verb == "POST" Then opts = opts "--data" '"'data'"'

  -- --head issues a real HEAD request: curl sends the HEAD method and reads
  -- only the header block (which it writes to -o, since in --head mode the
  -- headers ARE the output). The response has no body by definition, so we
  -- point the body sink at /dev/null and read the headers from -D alone.
  -- Otherwise curl would dump the header block into tmpBody and the body
  -- assertions would see headers where they expect emptiness.
  bodySink = tmpBody
  If verb == "HEAD" Then Do
    opts     = opts "--head"
    bodySink = "/dev/null"
  End

  Address System "curl" opts "-D" tmpHdr "-o" bodySink ,
    "-w %{http_code}" '"'url'"' ">" tmpStat

  response~setEntry("status",  self~slurp(tmpStat)~strip)
  response~setEntry("headers", self~slurp(tmpHdr))
  response~setEntry("body",    self~slurp(tmpBody))

  Address System "rm -f" tmpBody tmpHdr tmpStat

  Return response

/******************************************************************************/
/* slurp (private): read an entire file into a string, lines joined with LF.  */
/* Returns "" if the file is empty or unreadable.                             */
/******************************************************************************/

::Method slurp Private
  Use Strict Arg path

  If Stream(path, "C", "Query Exists") == "" Then Return ""

  lines = .Array~new
  Call Stream path, "C", "Open Read"
  Loop While Lines(path) > 0
    lines~append(LineIn(path))
  End
  Call Stream path, "C", "Close"

  Return lines~makeString("L", "0A"x)

/******************************************************************************/
/* Assertions on response text                                                */
/******************************************************************************/

::Method assertContains
  Use Strict Arg text, substring, label
  self~assertTrue(text~caselessPos(substring) > 0, label)

::Method assertNotContains
  Use Strict Arg text, substring, label
  self~assertTrue(text~caselessPos(substring) == 0, label)

/******************************************************************************/
/* assertHeader: assert that the response header block contains a header      */
/* whose line matches "name: ...value...". Both name and the value substring  */
/* are matched caselessly. Useful for Content-Type, Set-Cookie, lazy headers. */
/******************************************************************************/

::Method assertHeader
  Use Strict Arg headers, name, valueSubstring, label
  found = .False
  Do line Over headers~makeArray("0A"x)
    Parse Var line hname ":" hvalue
    If hname~strip~caselessCompare(name) == 0 Then Do
      If hvalue~caselessPos(valueSubstring) > 0 Then found = .True
    End
  End
  self~assertTrue(found, label)

/******************************************************************************/
/* assertNoHeader: assert that NO header line has the given name.             */
/******************************************************************************/

::Method assertNoHeader
  Use Strict Arg headers, name, label
  found = .False
  Do line Over headers~makeArray("0A"x)
    Parse Var line hname ":"
    If hname~strip~caselessCompare(name) == 0 Then found = .True
  End
  self~assertTrue(\found, label)

/******************************************************************************/
/* httpGetCookie: GET with a raw "Cookie:" request header (v11). A cookie jar */
/* cannot carry two cookies of the same name, but a browser sends them as a   */
/* single header "name=A; name=B"; this helper reproduces that exactly, for   */
/* the first-wins duplicate test.                                             */
/******************************************************************************/

::Method httpGetCookie
  Use Strict Arg url, cookieHeader

  response = .Directory~new

  tmpBody = "/tmp/rexxhttp-test-body.tmp"
  tmpHdr  = "/tmp/rexxhttp-test-hdr.tmp"
  tmpStat = "/tmp/rexxhttp-test-stat.tmp"

  opts = "-s --noproxy 127.0.0.1 -H" '"'"Cookie: "cookieHeader'"'

  Address System "curl" opts "-D" tmpHdr "-o" tmpBody ,
    "-w %{http_code}" '"'url'"' ">" tmpStat

  response~setEntry("status",  self~slurp(tmpStat)~strip)
  response~setEntry("headers", self~slurp(tmpHdr))
  response~setEntry("body",    self~slurp(tmpBody))

  Address System "rm -f" tmpBody tmpHdr tmpStat

  Return response

/******************************************************************************/
/* httpPostChunked: POST with Transfer-Encoding: chunked and NO               */
/* Content-Length (v99). curl chunks the body when the explicit header is     */
/* present; Apache unwraps it and hands the reassembled body to the CGI on    */
/* stdin with CONTENT_LENGTH empty -- the case readBodyToEOF exists for.       */
/* Verbatim body, Content-Type application/x-www-form-urlencoded.             */
/******************************************************************************/

::Method httpPostChunked
  Use Strict Arg url, data

  response = .Directory~new

  tmpBody = "/tmp/rexxhttp-test-body.tmp"
  tmpHdr  = "/tmp/rexxhttp-test-hdr.tmp"
  tmpStat = "/tmp/rexxhttp-test-stat.tmp"

  -- --data sends the body; the explicit Transfer-Encoding header makes curl
  -- frame it as chunked and drop Content-Length. -H Expect: strips curl's
  -- automatic 100-continue so the exchange is a single round trip.
  opts = "-s --noproxy 127.0.0.1"
  opts = opts "-H" '"'"Transfer-Encoding: chunked"'"'
  opts = opts "-H" '"'"Expect:"'"'
  opts = opts "--data" '"'data'"'

  Address System "curl" opts "-D" tmpHdr "-o" tmpBody ,
    "-w %{http_code}" '"'url'"' ">" tmpStat

  response~setEntry("status",  self~slurp(tmpStat)~strip)
  response~setEntry("headers", self~slurp(tmpHdr))
  response~setEntry("body",    self~slurp(tmpBody))

  Address System "rm -f" tmpBody tmpHdr tmpStat

  Return response


/******************************************************************************/
/* httpVerb: perform an arbitrary-method request (PUT, DELETE, ...) with an    */
/* optional urlencoded body (v99). -X sets the method; --data sends the body   */
/* with a fixed Content-Length, exactly like httpPost. An empty data string    */
/* sends no body. Used to exercise the PUT/DELETE argument/body contract.      */
/******************************************************************************/

::Method httpVerb
  Use Strict Arg verb, url, data = ""

  response = .Directory~new

  tmpBody = "/tmp/rexxhttp-test-body.tmp"
  tmpHdr  = "/tmp/rexxhttp-test-hdr.tmp"
  tmpStat = "/tmp/rexxhttp-test-stat.tmp"

  opts = "-s --noproxy 127.0.0.1 -X" verb
  If data \== "" Then opts = opts "--data" '"'data'"'

  Address System "curl" opts "-D" tmpHdr "-o" tmpBody ,
    "-w %{http_code}" '"'url'"' ">" tmpStat

  response~setEntry("status",  self~slurp(tmpStat)~strip)
  response~setEntry("headers", self~slurp(tmpHdr))
  response~setEntry("body",    self~slurp(tmpBody))

  Address System "rm -f" tmpBody tmpHdr tmpStat

  Return response

