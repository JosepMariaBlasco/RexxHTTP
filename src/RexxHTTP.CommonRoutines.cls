/******************************************************************************/
/*                                                                            */
/* RexxHTTP.CommonRoutines.cls - Shared helper routines for rexxlets          */
/* =================================================================          */
/*                                                                            */
/* This file is part of the RexxHTTP package                                  */
/* [See https://rexx.epbcn.com/rexxhttp/]                                     */
/*                                                                            */
/* Copyright (c) 2006-2026 Josep Maria Blasco <josep.maria.blasco@epbcn.com>  */
/*                                                                            */
/* License: Apache License 2.0 (https://www.apache.org/licenses/LICENSE-2.0)  */
/*                                                                            */
/* A home for routines that many rexxlets need but that do not belong to any  */
/* single request/response object. A rexxlet loads it by absolute path,       */
/* anchored at the installation root, which Apache hands us as the            */
/* REXXHTTP_BASE environment variable (frozen at install time):               */
/*                                                                            */
/*     .context~package~loadPackage( -                                        */
/*        .request~RexxHTTP_base"/src/RexxHTTP.CommonRoutines.cls" )          */
/*                                                                            */
/* REXXHTTP_BASE carries no trailing separator; the caller supplies the "/".  */
/*                                                                            */
/* Version history:                                                           */
/*                                                                            */
/* Date     Version Details                                                   */
/* -------- ------- --------------------------------------------------------- */
/* 20260705    1.0  First version: HaveParser                                 */
/*                                                                            */
/******************************************************************************/

--------------------------------------------------------------------------------
-- HaveParser                                                                 --
--                                                                            --
-- Answer whether a usable Rexx Parser is reachable at runtime.               --
--                                                                            --
-- The decision is binary and resolved in two steps (see the design note      --
-- state/design-parser-highlighting.md):                                      --
--                                                                            --
--   1. Is REXX_PARSER set? We read it through the Request's environment pool   --
--      (.request~REXX_PARSER), NOT with a bare                               --
--      Value("REXX_PARSER", , "ENVIRONMENT"). Both ultimately read the        --
--      process environment, but the Request pool adds the REDIRECT_ fallback: --
--      when mod_actions reroutes the request to the wrapper, Apache renames   --
--      the original CGI variables with a REDIRECT_ prefix, so the value       --
--      arrives as REDIRECT_REXX_PARSER and a bare REXX_PARSER lookup comes    --
--      back empty. .request~unknown tries REXX_PARSER first, then             --
--      REDIRECT_REXX_PARSER, so it finds it either way (invariant: the        --
--      unknown-method contract). This is the same reason the rest of the      --
--      code reads environment variables through .request, never directly.    --
--   2. Does it actually locate the Parser? The anchor is the file            --
--      <REXX_PARSER>/Rexx.Parser.cls -- REXX_PARSER points at the Parser's   --
--      bin/ directory (confirmed with JMB, v69).                             --
--                                                                            --
--   Both true -> the Parser is available (.true). Either false -> not.        --
--                                                                            --
-- REXX_PARSER is frozen at install time (SetEnv REXX_PARSER <abs bin/>) so   --
-- that a rexxlet running inside Apache's child process -- which does NOT see --
-- the user's PATH -- can nonetheless know where the Parser is. Runtime never --
-- guesses; it just reads what install time pinned and checks the anchor.     --
--                                                                            --
-- A rexxlet is never served standalone, so .request always exists here.      --
--------------------------------------------------------------------------------

::Routine HaveParser Public

  parserBin = .request~REXX_PARSER
  If parserBin == "" Then Return .False

  Return SysFileExists(parserBin || .File~separator || "Rexx.Parser.cls")
