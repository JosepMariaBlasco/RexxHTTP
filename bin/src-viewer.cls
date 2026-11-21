/******************************************************************************/
/*                                                                            */
/* bin/src-viewer.cls - Serve a program's source as a styled page             */
/* ===============================================================            */
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
/* 20260729    1.0  Extracted from src-viewer.rxl so it can be reused         */
/* 20261121    1.1  ParserComponent: find the Parser that ooRexx carries      */
/*                  (parser.cls and its parser/ folder), and only that one    */
/*                                                                            */
/******************************************************************************/

  -- One job lives here, shared by everything that wants to publish source:
  -- take a file and emit it as a page. With the Rexx Parser installed the
  -- source is highlighted; without it, the raw file is served as UTF-8 plain
  -- text. Either way the source arrives. Both src-viewer.rxl (serving other
  -- files) and markdown.rxl (showing its own source when called directly)
  -- reduce to a single call into here.

--------------------------------------------------------------------------------
-- ShowSource -- Emit one file as a page: highlighted if the Parser is        --
-- reachable, plain text otherwise. Sets the response content type and writes --
-- the whole response; the caller has nothing left to do but exit.            --
--------------------------------------------------------------------------------

::Routine ShowSource Public
  Use Strict Arg filename

  -- Is the highlighter reachable?
  Highlighter.cls = ParserComponent("Highlighter.cls")

  -- No Parser? Serve the raw file as plain text -- the source still arrives.
  If Highlighter.cls == .Nil Then Do
   .response~content_type = "text/plain; charset=utf-8"
    Say .File~readChars(filename)
    Return
  End

  -- We have the Parser: highlight and emit HTML.
 .response~content_type = "text/html; charset=utf-8"
 .context~package~loadPackage( Highlighter.cls~absolutePath )

  -- Default style is "dark"; the client-side style chooser restyles it.
  options.        = 0
  options.style   = "dark"
  options.mode    = "HTML"

  source      = .File~readLines(filename)
  highlighted = .Highlighter~new( filename, source, options. )~parse

 .HTML.Page~new( .File~new(filename)~name ) -
   ~body( highlighted~makeString )          -
   ~done

--------------------------------------------------------------------------------
-- ParserComponent -- Locate one file of the Rexx Parser, or .Nil.            --
--                                                                            --
-- The Parser is the one ooRexx carries since 5.3.0 r13570: parser.cls in     --
-- ooRexx's bin directory, which is on PATH, and its parser/ folder beside    --
-- it. parser.cls is searched for on ".", REXX_PATH and PATH, in that order,  --
-- and the component in that parser/ folder. Highlighter.cls and              --
-- FencedCode.cls load parser.cls themselves. The caller loads the component, --
-- so that a routine in it (FencedCode) is visible to the caller.             --
--------------------------------------------------------------------------------

::Routine ParserComponent Public
  Use Strict Arg name

  parser = .File~searchPath("parser.cls",                            -
    (".",Value("REXX_PATH",,environment),Value("PATH",,environment)) -
  )
  If parser == .Nil Then Return .Nil

  component = .File~new("parser" || .File~separator || name, parser~parentFile)
  If \component~exists Then Return .Nil

  Return component

::Requires "HTML.Page.cls"
