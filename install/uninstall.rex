#!/usr/bin/env rexx
/******************************************************************************/
/*                                                                            */
/* uninstall.rex - Uninstaller for RexxHTTP                                   */
/* ========================================                                   */
/*                                                                            */
/* This file is part of the RexxHTTP package                                  */
/* [See https://rexx.epbcn.com/rexxhttp/]                                     */
/*                                                                            */
/* Copyright (c) 2006-2026 Josep Maria Blasco <josep.maria.blasco@epbcn.com>  */
/*                                                                            */
/* License: Apache License 2.0 (https://www.apache.org/licenses/LICENSE-2.0)  */
/*                                                                            */
/* Usage:                                                                     */
/*   rexx uninstall [--yes] [--keep-apache]                                   */
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
    Say IndirectInvocationMsg("uninstall")
    Exit 1
  End

  -- --help is driver-specific (its own usage text), so handle it here.
  Do a Over .sysCargs
    If a~caselessEquals("--help") Then Signal Help
  End

  -- Single point of parsing + sanitizing. The mode ("uninstall") rides in
  -- the options directory, so the os-specific scripts need no injected flag.
  opts = ParseArgs("uninstall")
  If \opts~valid Then Do
    Say opts~errorMsg
    Exit 1
  End

  Select Case OSType()
    When "Windows" Then Call "Windows.install.orx" opts
    When "Linux"   Then Call "Linux.install.orx"   opts
    When "MacOS"   Then Call "Mac.install.orx"     opts
  End

  Exit Result

Help:
  Say .Resources~Help
  Exit 1

::Resource Help
uninstall - Uninstaller for RexxHTTP

Usage:
  rexx uninstall [--yes] [--root PATH] [--keep-apache]

  --yes         Assume "yes" to every prompt (non-interactive).
  --keep-apache Remove RexxHTTP-related configuration from Apache but
                do not remove Apache.
  --root P      Server root (default C:\Apache24). For --uninstall, the
                same root the install used (Windows Only).

::END

::Requires "InstallHelpers.cls"