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

  Address System "curl" opts "-D" tmpHdr "-o" tmpBody ,
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
