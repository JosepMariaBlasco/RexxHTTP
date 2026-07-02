#!rexx
/******************************************************************************/
/*                                                                            */
/* RexxHTTP.rex - A ooRexx rexxlet processor                                  */
/* =========================================                                  */
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
/*                                                                            */
/******************************************************************************/

  Signal on syntax

  -- If RexxHTTP.rex is called directly, simulate a 404 Not Found error
  If Direct() Then Signal NotFound

  -- Create the request and response objects
 .environment~request  = .HTTP.Request~new()
 .environment~response = .HTTP.Response~new()
  -- The response object creates a buffered output stream
  bufferedOutput       = .response~output

  -- The rexxlet we have to call has been computed by the request object
  callee   = .request~path_translated

  -- Apply the argument policy BEFORE running the rexxlet. validate parses
  -- the request arguments eagerly (consuming any POST body) and reports
  -- the first violation. We reject here, while output is still untouched,
  -- so the error page is clean. "" means the request is acceptable.
  violation = .request~validate
  If violation \== "" Then Do
    Parse var violation code":"detail
    If code == "badpolicy" Then Signal ConfigError   -- operator error: 500
    Else                        Signal BadRequest    -- client error:   400
  End

  -- Set the buffered output stream as the default output stream
  originalOutput = .output~destination(bufferedOutput)
    -- Call our rexxlet!
    Call (callee) .request, .response
  -- Restore the previous output stream
 .output~destination(originaloutput)

  Drop originaloutput

  -- Flush the response. This will write the headers if necessary
 .response~flush

  -- We're done!
  Exit

--------------------------------------------------------------------------------

Direct: Return Env(request_uri)~caselessContains("RexxHTTP.rex") > 0

--------------------------------------------------------------------------------
-- Env: Return the value of an environment variable                           --
--------------------------------------------------------------------------------

Env: Return Value(Arg(1),,"ENVIRONMENT")

--------------------------------------------------------------------------------
-- NotFound: Return 404 Not found when RexxHTTP.rex is called directly        --
--------------------------------------------------------------------------------

NotFound:
  Say "Content-Type: text/html"
  Say "Status: 404 Not Found"
  Say ""
  Say '<!DOCTYPE HTML PUBLIC "-//IETF//DTD HTML 2.0//EN">'
  Say '<HTML><HEAD>'
  Say '<TITLE>404 Not Found</TITLE>'
  Say '</HEAD><BODY>'
  Say '<H1>Not Found</H1>'
  Say '<P>The requested URL' Env(request_uri) 'was not found on this server.</P>'
  Say '<HR>'
  Say Env(server_signature)
  Say '</BODY></HTML>'
Exit

--------------------------------------------------------------------------------
-- BadRequest: Return 400 when the request arguments violate the policy       --
--   (a parameter without "=", an empty name, a repeated name, or a name      --
--   beginning with a digit). "detail" and "code" are set by the Parse of     --
--   the validate result.                                                     --
--------------------------------------------------------------------------------

BadRequest:
  Say "Content-Type: text/html"
  Say "Status: 400 Bad Request"
  Say ""
  Say '<!DOCTYPE HTML PUBLIC "-//IETF//DTD HTML 2.0//EN">'
  Say '<HTML><HEAD>'
  Say '<TITLE>400 Bad Request</TITLE>'
  Say '</HEAD><BODY>'
  Say '<H1>Bad Request</H1>'
  Say '<P>The query string is malformed:' Reason(code, detail)'.</P>'
  Say '<HR>'
  Say Env(server_signature)
  Say '</BODY></HTML>'
Exit

--------------------------------------------------------------------------------
-- ConfigError: Return 500 when REXXHTTP_ARGPOLICY is set to an unknown value --
--   This is an operator configuration error, not a client error.            --
--------------------------------------------------------------------------------

ConfigError:
  Say "Content-Type: text/html"
  Say "Status: 500 Internal Server Error"
  Say ""
  Say '<!DOCTYPE HTML PUBLIC "-//IETF//DTD HTML 2.0//EN">'
  Say '<HTML><HEAD>'
  Say '<TITLE>500 Internal Server Error</TITLE>'
  Say '</HEAD><BODY>'
  Say '<H1>Internal Server Error</H1>'
  Say '<P>Server misconfiguration: unknown REXXHTTP_ARGPOLICY value' -
      '"'detail'".</P>'
  Say '<HR>'
  Say Env(server_signature)
  Say '</BODY></HTML>'
Exit

--------------------------------------------------------------------------------
-- Reason: Turn a validate violation code into a human-readable phrase        --
--------------------------------------------------------------------------------

Reason: Procedure
  Use Strict Arg code, detail
  Select
    When code == "novalue"   Then Return "parameter without a value:" detail
    When code == "noname"    Then Return "parameter with an empty name:" detail
    When code == "duplicate" Then Return "duplicate parameter name:" detail
    When code == "digitname" Then Return "parameter name begins with a digit:" detail
    Otherwise                     Return "invalid parameter" detail
  End

--------------------------------------------------------------------------------
-- Syntax error handler                                                       --
--------------------------------------------------------------------------------

Syntax:

  error     = Condition("O")

  Signal off syntax                               -- Avoid loops

  -- Restore STDOUT if necessary
  If Var("originalOutput") Then .output~destination --(originalOutput)

  -- Commit the response. This will emit the page headers.
  -- Only assert the 500 status/type if nothing has gone out yet: once
  -- the response is committed (or mid-commit), the headers are already
  -- on the wire and setting them now would raise (committed) or corrupt
  -- a half-written response (committing). commit itself is idempotent.
  If \.response~committed, \.response~committing Then Do
   .response~content_type = "text/plain; charset=utf-8"
   .response~status       = "500 Internal Server Error"
  End
 .response~commit

  -- Output an error page
  Say "Internal server error"
  Say "---------------------"
  Say

  -- Extract program name and sanitize it to avoid showing
  -- too much details about our internals
  document_root = Env(document_root)
  program_name  = error~program
  If program_name~startsWith(document_root) Then
    program_name = SubStr(program_name, Length(document_root) + 1)

  -- Print an error message that is as similar as possible
  -- to a standard ooRexx error message
  Do frame Over error~stackFrames
    Say frame~makeString
  End
  Say "Error" error~rc "running" program_name "line" -
    error~position":" error~errortext
  Say "Error" error~code":" error~errortext

Exit

--------------------------------------------------------------------------------
-- Load our dependencies                                                      --
--------------------------------------------------------------------------------

::Requires "HTTP.Request.cls"
::Requires "HTTP.Response.cls"
::Requires "HTTP.OutputStream.cls"
::Requires "HTTP.Cookie.cls"
