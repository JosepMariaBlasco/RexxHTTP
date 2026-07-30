#!/usr/bin/env rexx
/******************************************************************************/
/*                                                                            */
/* install.rex - Installer for RexxHTTP                                       */
/* ====================================                                       */
/*                                                                            */
/* This file is part of the RexxHTTP package                                  */
/* [See https://rexx.epbcn.com/rexxhttp/]                                     */
/*                                                                            */
/* Copyright (c) 2006-2026 Josep Maria Blasco <josep.maria.blasco@epbcn.com>  */
/*                                                                            */
/* License: Apache License 2.0 (https://www.apache.org/licenses/LICENSE-2.0)  */
/*                                                                            */
/* Installs RexxHTTP on a CLEAN machine, following the recipe of the manual's */
/* Installation chapter. See Windows.install, Linux.install and Mac.install   */
/* for the os-specific installation details                                   */
/*                                                                            */
/* Usage:                                                                     */
/*   rexx install [--yes] [--zip-url URL] [--root PATH]                       */
/*                                                                            */
/*   --yes         Assume "yes" to every prompt (non-interactive).            */
/*   --zip-url U   Override the Apache Lounge ZIP URL (e.g. a newer build).   */
/*   --root P      Server root (default C:\Apache24). For --uninstall, the    */
/*                 same root the install used.                                */
/*                                                                            */
/* Version history:                                                           */
/*                                                                            */
/* Date     Version Details                                                   */
/* -------- ------- --------------------------------------------------------- */
/* 20260630    1.0  First version                                             */
/*                                                                            */
/******************************************************************************/

  -- We rely on .sysCargs, which is trustworthy only when this driver is
  -- started directly (CLI or ADDRESS), not through an internal CALL. Guard
  -- inline: measuring the stack inside a routine would add its own frame.
  If .Context~stackFrames~items > 1 Then Do
    Say IndirectInvocationMsg("install")
    Exit 1
  End

  -- RexxHTTP requires ooRexx 5.2.0 or later. Stop early on an interpreter
  -- too old, before touching arguments or the system.
  If \RexxVersionOK() Then Do
    Say RexxVersionMsg()
    Exit 1
  End

  -- --help is driver-specific (its own usage text), so handle it here.
  Do a Over .sysCargs
    If a~caselessEquals("--help") Then Signal Help
  End

  -- Single point of parsing + sanitizing. Returns a structured directory;
  -- on a bad argument it reports valid = 0 rather than exiting (a ::Routine
  -- cannot end the program), so we print and exit here.
  opts = ParseArgs("install")
  If \opts~valid Then Do
    Say opts~errorMsg
    Exit 1
  End

  -- Hand the os-specific installer a ready-made options directory; it does
  -- no argument parsing of its own.
  Select Case OSType()
    When "Windows" Then Do
      -- A normal install writes under the server root (e.g. C:\Apache24) and
      -- registers Apache as a Windows service; both need Administrator, so we
      -- check up front and stop cleanly rather than failing halfway through.
      -- A --user install skips all of that: it roots under the user's home and
      -- runs Apache without a service, so it needs no elevation -- for people
      -- who do not control their machine (students on lab PCs, say).
      If \opts~user, \IsWindowsAdmin() Then Do
        Say "ERROR: this installer must be run as Administrator."
        Say "  Open a Command Prompt with 'Run as administrator' and try again,"
        Say "  or use --user to install under your home without a service."
        Exit 1
      End
      Call "Windows.install.orx" opts
    End
    When "Linux"   Then Call "Linux.install.orx"   opts
    When "MacOS"   Then Call "Mac.install.orx"     opts
    Otherwise Do
      Say "ERROR: unsupported platform" OSType()"."
      Exit 1
    End
  End

  Exit Result

Help:
  Say .Resources~Help
  Exit 1

::Resource Help
install - Installer for RexxHTTP

Usage:
  rexx install [--yes] [--zip-url URL] [--root PATH] [--port N] [--user]

  --yes         Assume "yes" to every prompt (non-interactive).
  --zip-url U   Override the Apache Lounge ZIP URL (e.g. a newer build)
                (Windows only).
  --root P      Server root (default C:\Apache24). For --uninstall, the
                same root the install used (Windows only).
  --port N      Have Apache listen on port N instead of the platform default
                (80 on Windows/Linux, 8080 on macOS). Install only.
  --user        Windows only: a user-level install under %USERPROFILE%\Apache24
                with no Windows service and no elevation, for machines where
                you are not an administrator. Apache runs in its own window
                (a start.cmd launcher is planted in the server root); it does
                not start automatically with Windows.

::END

::Requires "InstallHelpers.cls"
