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
      -- Windows needs an elevated console: the installer writes under the
      -- server root (e.g. C:\Apache24), which requires Administrator. Check
      -- up front and stop cleanly, rather than failing halfway through
      -- writing httpd.conf.
      If \IsWindowsAdmin() Then Do
        Say "ERROR: this installer must be run as Administrator."
        Say "  Open a Command Prompt with 'Run as administrator' and try again."
        Exit 1
      End
      Call "Windows.install.orx" opts
    End
    When "Linux"   Then Call "Linux.install.orx"   opts
    When "MacOS"   Then Call "Mac.install.orx"     opts
  End

  Exit Result

Help:
  Say .Resources~Help
  Exit 1

::Resource Help
install - Installer for RexxHTTP

Usage:
  rexx install [--yes] [--zip-url URL] [--root PATH]

  --yes         Assume "yes" to every prompt (non-interactive).
  --zip-url U   Override the Apache Lounge ZIP URL (e.g. a newer build)
                (Windows only).
  --root P      Server root (default C:\Apache24). For --uninstall, the
                same root the install used (Windows only).

::END

::Requires "InstallHelpers.cls"