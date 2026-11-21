#!/usr/bin/env rexx
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
/* 20261121         The run is a DO block: CATCH reports SYNTAX errors and    */
/*                  RexxHTTP.ConfigError, FINALLY restores .output; a         */
/*                  condition thrown by a rexxlet gets a 500 page too; needs  */
/*                  ooRexx 5.3.0 r13572                                       */
/*                                                                            */
/******************************************************************************/

  -- The whole run is one block. A SYNTAX error anywhere in it -- in the
  -- processor, in the classes, or in the rexxlet -- ends up in its CATCH
  -- clause, which reports it as a 500 page; so does a configuration error
  -- that the request object throws (USER RexxHTTP.ConfigError). The 404, 400
  -- and 500 pages of the processor itself are internal routines that EXIT,
  -- called from inside the block, so that they are covered too.

  Do

    -- If RexxHTTP.rex is called directly, simulate a 404 Not Found error
    If Direct() Then Call NotFound

    REXX_PATH = Env("REDIRECT_REXX_PATH")
    Call Value "REXX_PATH", REXX_PATH, "ENVIRONMENT"

    -- Create the request and response objects
   .local~request  = .HTTP.Request~new()
   .local~response = .HTTP.Response~new()
    -- The response object creates a buffered output stream
    bufferedOutput       = .response~output

    -- The rexxlet we have to call has been computed by the request object.
    -- SCRIPT_FILENAME is the processor's disk path -- the file to execute --
    -- whereas FILENAME/PATH_TRANSLATED now name the requested document.
    callee   = .request~script_filename

    -- Apply the argument policy BEFORE running the rexxlet. validate parses
    -- the request arguments eagerly (consuming any POST body) and reports
    -- the first violation. We reject here, while output is still untouched,
    -- so the error page is clean. "" means the request is acceptable.
    violation = .request~validate
    If violation \== "" Then Do
      Parse var violation code":"detail
      If code == "badpolicy" Then Call ConfigError     -- operator error: 500
      Else                        Call BadRequest      -- client error:   400
    End

    -- Set the buffered output stream as the default output stream.
    -- NOTE: .output~destination is a STACK, not a setter -- with an argument it
    -- PUSHES a new destination, without one it POPS back to the previous. The
    -- return value is NOT the previous destination (it is the one just pushed),
    -- so there is nothing worth keeping.
    --
    -- We keep NO bookkeeping flag for "did we push?". The single source of
    -- truth is the stack itself: .output~current is the destination on top,
    -- and it is our buffer if and only if it isA HTTP.OutputStream. The
    -- FINALLY clause below decides whether to pop by asking that question --
    -- so error(), which pops on its own, can never desynchronise a flag from
    -- the real stack state (the v97 double-pop bug). current is a READ, not
    -- a pop, and on an un-redirected stack it returns STDOUT (a .Stream),
    -- never .NIL, so the test is safe to ask in any state.
   .output~destination(bufferedOutput)
    Do
      Do
        -- Call our rexxlet!
        Call (callee) .request, .response, bufferedOutput
      Finally
        -- Restore the previous output stream, however the rexxlet ended (it
        -- returned, or it left a condition that the CATCH below handles):
        -- an error page is written to the CGI stream, not into the buffer.
        -- Only if our buffer is still on top: a rexxlet that called
        -- error()/404() already popped it, and popping again would empty
        -- the stack and leave .output on .NIL.
        If .output~current~isA(.HTTP.OutputStream) Then .output~destination
      End
    Catch uncaught = Any
      -- Whatever the rexxlet did not catch itself. See RexxletCondition.
      Call RexxletCondition uncaught
    End

    -- Flush the response. This will write the headers if necessary
   .response~flush

    -- We're done!
    Exit

  Catch config = User RexxHTTP.ConfigError
    Call ConfigFailure config

  Catch error = Syntax
    Call ErrorPage error
  End

  Exit

--------------------------------------------------------------------------------

-- Direct: is RexxHTTP.rex being invoked DIRECTLY by URL, rather than reached
-- through the Action that dispatches a rexxlet to us? A direct hit has no
-- document to run, so it is a 404.
--
-- The discriminator is REDIRECT_HANDLER: Apache sets it (to the Action's
-- handler name) on every Action dispatch -- one hop or two -- and leaves it
-- empty on a direct URL hit. Measured across the direct, one-hop and two-hop
-- topologies. The old test searched REQUEST_URI for the substring "RexxHTTP.rex"
-- unanchored, which false-positived on any request whose QUERY STRING merely
-- mentioned the name (e.g. ?doc=RexxHTTP.rex returned a spurious 404 over a
-- valid rexxlet). We do not care about the handler's NAME, only whether ANY
-- Action redirect brought us here, so an emptiness test is exactly right and
-- is immune to the query string. See ref-decisiones.md "v99 -- Direct()".
Direct: Return Env("REDIRECT_HANDLER") == ""

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
-- ConfigFailure: report a configuration error as a 500 page                  --
--------------------------------------------------------------------------------

-- The request object throws USER RexxHTTP.ConfigError when the operator's
-- configuration cannot work (see rawResourcePath and init in
-- HTTP.Request.cls); the description is the reason, shown as the page. The
-- page honours the response's state the same three ways ErrorPage does.
-- Today the condition is thrown while .request is still being built, so
-- .response does not exist yet and we take the Else (Say straight to the CGI
-- stream). The .response arms are hardening for any future use of the channel
-- from a point where a response is live.

ConfigFailure:
  Use Strict Arg config
  reason = config~description
  If .response~isA(.HTTP.Response) Then Do
    -- A live, untouched response: let error() reset the body, set the 500
    -- status/type and HTML-escape the reason, then commit so the headers and
    -- page actually go out. If it is already committed, the headers are on
    -- the wire; we simply stop without corrupting the stream.
    If \.response~committed, \.response~committing Then Do
     .response~error(500, reason)
    End
  End
  Else Do
    Say "Status: 500 Internal Server Error"
    Say "Content-type: text/html; charset=utf-8"
    Say
    Say reason
  End
Exit

--------------------------------------------------------------------------------
-- RexxletCondition: what to do with a condition the rexxlet did not catch    --
--------------------------------------------------------------------------------

-- The CATCH ANY clause around the call of the rexxlet gets every condition
-- that leaves the rexxlet. Only the call is inside that block: an active
-- CATCH ANY counts as a NOVALUE trap for the code of its block (not for an
-- external routine such as the rexxlet: measured), and the processor's own
-- code is kept out of it. Each kind is handled as before THROW existed, and
-- a thrown condition gets a page of its own:
--
--   SYNTAX              the error page, as always (ErrorPage).
--   thrown (THROW)      the error page, with the error that the interpreter
--                       would report for it: 4.1, or 4.901 with the
--                       description. Before, the run ended without a page,
--                       the error went to the server log, and Apache sent
--                       its own 500.
--   HALT, raised        the error page with error 4.1: an untrapped HALT
--                       became SYNTAX 4.1, which the old trap reported.
--   anything else, raised (RAISE USER, NOTREADY, ERROR...): ignored, as an
--                       untrapped raised condition is. The rexxlet has
--                       ended; the response is flushed as usual.

RexxletCondition:
  Use Strict Arg uncaught
  If uncaught~condition == "SYNTAX" Then Call ErrorPage uncaught
  If uncaught~thrown == .true       Then Call ErrorPage uncaught
  If uncaught~condition == "HALT"   Then Call ErrorPage uncaught
Return

--------------------------------------------------------------------------------
-- ErrorPage: report an error as a 500 page                                   --
--------------------------------------------------------------------------------

-- Called with the condition object: from the CATCH clause of the main block
-- (SYNTAX), and from RexxletCondition (SYNTAX, a thrown condition, a raised
-- HALT). The buffered stream is no longer on .output's destination stack:
-- the FINALLY clause around the call of the rexxlet has popped it (and an
-- error before that call happened before it was pushed), so Say writes to
-- the CGI stream. An error in here is not caught: the CATCH clauses of a
-- block are inactive while one of them runs (it used to be "Signal off
-- syntax").

ErrorPage:
  Use Strict Arg error

  -- Commit the response. This will emit the page headers.
  --
  -- .response only exists once RexxHTTP.rex has built it (see the main
  -- flow). A syntax error raised BEFORE that -- e.g. inside
  -- HTTP.Request~new() -- reaches this handler with .response still
  -- unset, so .response is the literal string "RESPONSE" (the default
  -- value of an unset .environment entry). Sending it ~committed then
  -- raises here and buries the ORIGINAL error under a misleading
  -- 'RESPONSE does not understand COMMITTED'. Guard on the real type so
  -- an early failure still surfaces its own stack trace to the client
  -- and the error log.
  If .response~isA(.HTTP.Response) Then Do
    -- Only assert the 500 status/type if nothing has gone out yet: once
    -- the response is committed (or mid-commit), the headers are already
    -- on the wire and setting them now would raise (committed) or corrupt
    -- a half-written response (committing). commit itself is idempotent.
    --
    -- KNOWN AND ACCEPTED: if the rexxlet called ~commit itself and THEN
    -- failed, the client gets the status that commit already emitted --
    -- typically "200 OK" -- with this error page as the body, and the
    -- body the rexxlet had buffered before the failure is lost (commit
    -- writes the headers straight to the underlying stream; only ~flush
    -- drains the body buffer, and we Exit before reaching it).
    -- Not worth fixing: the status cannot be recalled once it is on the
    -- wire, so a ~flush here would not make the response truthful -- it
    -- would only append the partial body ahead of the trace, at the cost
    -- of more code on the most delicate path in the processor. The error
    -- and its failing line DO reach the client, so nothing fails silently,
    -- and a rexxlet that commits by hand has already opted out of the
    -- buffered model. See ref-decisiones.md (v95).
    If \.response~committed, \.response~committing Then Do
     .response~content_type = "text/plain; charset=utf-8"
     .response~status       = "500 Internal Server Error"
    End
   .response~commit
  End
  Else Do
    -- No response object: the failure predates its creation. Emit a
    -- minimal CGI 500 by hand. .output was never redirected to the
    -- response buffer (that happens later in the main flow), so Say
    -- writes straight to STDOUT, which is exactly the CGI response.
    Say "Status: 500 Internal Server Error"
    Say "Content-Type: text/plain; charset=utf-8"
    Say ""
  End

  -- Output an error page
  Say "Internal server error"
  Say "---------------------"
  Say

  -- Extract program name and sanitize it to avoid showing
  -- too much details about our internals
  document_root = Env(document_root)
  program_name  = error~program
  -- On Windows the program's name carries the native separator and
  -- DOCUMENT_ROOT Apache's "/", and the file system ignores case: compare
  -- them in one form (otherwise the full path reached the client). Shown
  -- with "/", as the URL that named it.
  If .File~separator == "\" Then Do
    program_name = program_name~translate("/", "\")
    If program_name~caselessStartsWith(document_root~translate("/", "\")) Then
      program_name = SubStr(program_name, Length(document_root) + 1)
  End
  Else If program_name~startsWith(document_root) Then
    program_name = SubStr(program_name, Length(document_root) + 1)

  -- Print an error message that is as similar as possible
  -- to a standard ooRexx error message
  Do frame Over error~stackFrames
    Say frame~makeString
  End
  If error~condition == "SYNTAX" Then Do
    Say "Error" error~rc "running" program_name "line" -
      error~position":" error~errortext
    Say "Error" error~code":" error~message
  End
  Else Do
    -- Any other condition is error 4, as the interpreter reports a thrown
    -- condition that nothing catches: 4.901 when it was thrown with a
    -- description, 4.1 otherwise (an untrapped raised HALT was 4.1, with
    -- or without one).
    description = error~description
    If description == .nil Then description = ""
    message = "Program interrupted with" error~condition "condition"
    If error~thrown == .true, description \== "" Then Do
      code    = 4.901
      message = message":" description"."
    End
    Else Do
      code    = 4.1
      message = message"."
    End
    Say "Error 4 running" program_name "line" error~position":" ErrorText(4)
    Say "Error" code":" message
  End

Exit

--------------------------------------------------------------------------------
-- Load our dependencies                                                      --
--------------------------------------------------------------------------------

::Requires "HTTP.Request.cls"
::Requires "HTTP.Response.cls"
::Requires "HTTP.OutputStream.cls"
::Requires "HTTP.Cookie.cls"
