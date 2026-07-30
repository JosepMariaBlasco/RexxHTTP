/******************************************************************************/
/*                                                                            */
/* InstallHelpers.cls - A set of helper routines for the install scripts      */
/* =====================================================================      */
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
/* 20260630    1.0  First version                                             */
/*                                                                            */
/******************************************************************************/

::Routine OSType Public

  If .RexxInfo~platform~caselessStartsWith("Windows") Then
    Return "Windows"

  -- SysVersion() returns "<sysname> <release>"; its first word is the
  -- struct utsname sysname field straight from uname(2) -- the very same
  -- source the external `uname` command reads -- so this is exactly what
  -- an `Address COMMAND "uname"` call would report, minus the child
  -- process. On macOS sysname is "Darwin".
  If Word(SysVersion(), 1) == "Darwin" Then Return "MacOS"

  Return "Linux"

/******************************************************************************/
/* Direct-invocation guard. We trust .sysCargs only when this program was     */
/* started directly -- from the CLI, or via an ADDRESS command (both create a */
/* fresh process whose .sysCargs is its own). When reached by an internal     */
/* CALL instead, .sysCargs belongs to the caller, so parsing it would read    */
/* the wrong arguments. A directly-started program has exactly one stack      */
/* frame; a CALL adds a frame on top. The driver checks this INLINE -- not    */
/* in a routine -- because measuring the stack inside a ::Routine would add   */
/* that routine's own frame and throw the count off. This routine only        */
/* supplies the message, so the wording lives in one place:                   */
/*                                                                            */
/*   If .Context~stackFrames~items > 1 Then Do                                */
/*     Say IndirectInvocationMsg("install.rex"); Exit 1                       */
/*   End                                                                      */
/******************************************************************************/
::Routine IndirectInvocationMsg Public
  Use Strict Arg myName
  msg = myName "must be invoked from the command line or via an ADDRESS" -
        "command, not through an internal CALL: it relies on .sysCargs," -
        "which only reflects its own arguments when started directly."
  Return msg

/******************************************************************************/
/* Minimum-version guard. RexxHTTP requires ooRexx 5.2.0 or later. The driver */
/* itself is a .rex, so a working interpreter is a given -- what is not given */
/* is that it is recent enough, so the check is on the VERSION, not on mere   */
/* presence. The comparison is compound on purpose: a major above 5 passes    */
/* outright, and only within the 5.x line is a release of 2 or more required, */
/* so a future 6.0.0 (release 0) is not rejected for the wrong reason. Both   */
/* sides of the '&' are always evaluable (neither depends on the other        */
/* holding first), so ooRexx's non-short-circuiting '&' is safe here.         */
/* The message lives in its companion routine so the wording stays            */
/* in one place:                                                              */
/*                                                                            */
/*   If \RexxVersionOK() Then Do                                              */
/*     Say RexxVersionMsg(); Exit 1                                           */
/*   End                                                                      */
/******************************************************************************/
::Routine RexxVersionOK Public
  major   = .RexxInfo~majorVersion
  release = .RexxInfo~release
  Return major > 5 | (major == 5 & release >= 2)

::Routine RexxVersionMsg Public
  msg = "ERROR: RexxHTTP requires ooRexx 5.2.0 or later; this is" -
        .RexxInfo~version"." "Please upgrade the interpreter and try again."
  Return msg

/******************************************************************************/
/* ParseArgs: the single place where user arguments are parsed and sanitized. */
/* Reads .sysCargs -- already tokenized by the shell, so a quoted value with  */
/* spaces (e.g. --root "C:\Program Files\Apache") arrives as ONE element and  */
/* is never re-split. Returns a Directory of structured options that the      */
/* os-specific *.install scripts consume as-is (they do no parsing of their   */
/* own). The caller passes mode = "install" or "uninstall", which decides     */
/* which flags are legal.                                                     */
/*                                                                            */
/* On a bad argument it does NOT exit (a ::Routine cannot end the program);   */
/* it sets opts~valid = 0 and opts~errorMsg, and the driver prints+exits.     */
/*                                                                            */
/* Returned directory entries:                                                */
/*   valid       -- 1 | 0                                                     */
/*   errorMsg    -- "" or the message to print when valid = 0                 */
/*   mode        -- "install" | "uninstall"                                   */
/*   assumeYes   -- 0 | 1                                                     */
/*   keepApache  -- 0 | 1   (uninstall only)                                  */
/*   serverRoot  -- "" or the path        (Windows only)                      */
/*   zipUrl      -- "" or the URL          (Windows only, install only)       */
/*   port        -- "" or a numeric string 1..65535 (the Apache Listen port)  */
/*   user        -- 0 | 1   (Windows only; a user-level install with no        */
/*                  service and no elevation, rooted under the home)          */
/******************************************************************************/
::Routine ParseArgs Public
  Use Strict Arg mode

  opts = .Directory~new
  opts~valid      = 1
  opts~errorMsg   = ""
  opts~mode       = mode
  opts~assumeYes  = 0
  opts~keepApache = 0
  opts~serverRoot = ""
  opts~zipUrl     = ""
  opts~port       = ""
  opts~user       = 0

  isWindows = (OSType() == "Windows")
  args = .sysCargs
  i = 1
  Do While i <= args~items
    arg = args[i]
    Select Case Lower(arg)
      When "--yes" Then opts~assumeYes = 1

      When "--keep-apache" Then Do
        If mode \== "uninstall" Then
          Return BadArg(opts, "--keep-apache is only valid for uninstall.")
        opts~keepApache = 1
      End

      When "--root" Then Do
        If \isWindows Then
          Return BadArg(opts, "--root can only be specified under Windows.")
        i = i + 1
        If i > args~items Then Return BadArg(opts, "Missing value for --root.")
        opts~serverRoot = args[i]
      End

      When "--zip-url" Then Do
        If \isWindows Then
          Return BadArg(opts, "--zip-url can only be specified under Windows.")
        If mode \== "install" Then
          Return BadArg(opts, "--zip-url is only valid for install.")
        i = i + 1
        If i > args~items Then Return BadArg(opts, "Missing value for --zip-url.")
        opts~zipUrl = args[i]
      End

      When "--port" Then Do
        If mode \== "install" Then
          Return BadArg(opts, "--port is only valid for install; it is not needed to uninstall.")
        i = i + 1
        If i > args~items Then Return BadArg(opts, "Missing value for --port.")
        value = args[i]
        -- A TCP port is a whole number in 1..65535. Reject anything else
        -- (non-numeric, fractional, out of range) here, so the *.install
        -- files can trust opts~port without re-checking.
        If \value~dataType("W") Then
          Return BadArg(opts, "--port must be a whole number (got '"value"').")
        If value < 1 | value > 65535 Then
          Return BadArg(opts, "--port must be between 1 and 65535 (got "value").")
        opts~port = value
      End

      When "--user" Then Do
        If \isWindows Then
          Return BadArg(opts, "--user can only be specified under Windows.")
        opts~user = 1
      End

      Otherwise Return BadArg(opts, "Invalid argument '"arg"'.")
    End
    i = i + 1
  End

  -- Cross-option rule (checked here, after the loop, so it holds whatever
  -- order the two flags were given in). --keep-apache means "retire RexxHTTP
  -- but leave the Apache it was a guest on". A --user install is not a guest:
  -- it set up its own Apache under the home, with no service, so there is no
  -- pre-existing server to keep -- the two options are contradictory. Reject
  -- the combination rather than half-dismantle the user's private Apache.
  If opts~user, opts~keepApache Then
    Return BadArg(opts, "--user and --keep-apache cannot be combined: a --user install owns its Apache (there is no separate server to keep).")

  Return opts

BadArg:
  Use Strict Arg opts, message
  opts~valid    = 0
  opts~errorMsg = message
  Return opts

/******************************************************************************/
/* MakeTempFile: create a temporary file with an unpredictable name and mode  */
/* 600, and return its path ("" if it could not be created).                  */
/*                                                                            */
/* The installers build files in a temporary location and then install them   */
/* into root-owned destinations. A FIXED name under /tmp is unsafe on a        */
/* multi-user machine: any local user can pre-create that exact path as a      */
/* symlink, the installer then writes THROUGH the link, and the privileged     */
/* copy that follows plants attacker-controlled content in a root-owned file   */
/* (CWE-377 / CWE-59). mktemp(1) creates the file itself, atomically, with an  */
/* unguessable suffix and no world access, which closes the window: there is   */
/* nothing to pre-create and nothing to race.                                  */
/*                                                                            */
/* Note the mode: the file is 600, so a plain 'cp' that CREATES its            */
/* destination would carry that mode over. Callers whose destination must be   */
/* world-readable install it explicitly with 'install -m 644' rather than      */
/* 'cp' -- see the call sites. Callers that overwrite an EXISTING file are     */
/* unaffected, since cp keeps the destination's own mode.                      */
/******************************************************************************/
::Routine MakeTempFile Public
  Use Strict Arg prefix
  out = .Array~new
  Address System "mktemp" '"/tmp/'prefix'.XXXXXXXX"' With Output Using (out) Error Stem Discard.
  If RC \== 0 Then Return ""
  If out~items == 0 Then Return ""
  Return out[1]~strip

/******************************************************************************/
/* PinShebang: rewrite the first line of the DEPLOYED processor from the Unix */
/* env shebang "#!/usr/bin/env rexx" to <newShebang>, in place. Only the copy */
/* passed in is touched, never the canonical source, and only if its first    */
/* line IS that exact env shebang -- so it is idempotent (a file already      */
/* pinned, or with no env shebang, is left untouched). The caller supplies    */
/* what to pin to: an absolute "#!<rexx>" on Unix (env may not resolve rexx   */
/* on Apache's minimal PATH), a bare "#!rexx" on Windows (the ooRexx shebang  */
/* association keys off the token, not a path).                               */
/*                                                                            */
/* This is the common core shared by the Windows and Mac installers, which    */
/* both own their cgi-bin and can write it in place. The LINUX installer does */
/* NOT call this: its cgi-bin is root-owned, so it needs the same logic but a */
/* privileged write (temp file + sudo install), and keeps its own PinShebang. */
/* If the installer is ever made to run elevated as a whole, Linux could fold */
/* into this routine too.                                                     */
/*                                                                            */
/* EOL: writeLines re-emits each line with the platform's native terminator,  */
/* exactly as the old LineOut loop did -- LF on Unix (byte-transparent to the */
/* LF source pack.rex enforces), CRLF on Windows (accepted: ooRexx runs the   */
/* CGI either way, and only the cgi-bin copy is touched).                     */
/******************************************************************************/
::Routine PinShebang Public
  Use Strict Arg script, newShebang
  envShebang = "#!/usr/bin/env rexx"
  body = .File~readLines(script)
  If body~items > 0, body[1]~strip == envShebang Then Do
    body[1] = newShebang
    .File~writeLines(script, body, "Replace")
  End
  Return

/******************************************************************************/
/* SysCmd: run a command, return its exit code.                               */
/******************************************************************************/
::Routine SysCmd Public
  Use Strict Arg command
  Address System command
  Return RC

/******************************************************************************/
/* CmdOutputHas: run a command, capture its standard output, and return 1 if  */
/* any output line caselessly contains the given needle, else 0. Used for     */
/* probes whose exit code is not reliable -- tasklist and netstat both return */
/* 0 whether or not they found anything, so the answer is in the text,        */
/* not RC. Errors are swallowed: a probe that cannot run is treated as        */
/* 'not found'.                                                               */
/******************************************************************************/
::Routine CmdOutputHas Public
  Use Strict Arg command, needle
  out = .Array~new
  Address System command With Output Using (out) Error Stem Discard.
  Do line Over out
    If line~caselessContains(needle) Then Return 1
  End
  Return 0

/******************************************************************************/
/* PortBusyMsg: the message shown when the port the installer would use is    */
/* already taken. Kept here so all three installers word it the same way and  */
/* always point the user at the --port way out, whatever the port was.        */
/******************************************************************************/
::Routine PortBusyMsg Public
  Use Strict Arg port
  Return "Port" port "is busy. You can install on another port with: install --port NNNN"

/******************************************************************************/
/* RewriteListen: given an Apache "Listen ..." directive line and a port,     */
/* return the line with its port replaced. Handles "Listen 80" (bare port)    */
/* and "Listen 0.0.0.0:80" / "Listen [::]:80" (address:port) forms, keeping    */
/* any address prefix and any trailing protocol word ("Listen 80 https").     */
/* Leading whitespace is preserved. Shared by the installers so every platform */
/* rewrites the directive the same way, wherever the Listen actually lives     */
/* (httpd.conf on Windows, /etc/apache2/ports.conf on Debian/Ubuntu).         */
/******************************************************************************/
::Routine RewriteListen Public
  Use Strict Arg line, port
  stripped = line~strip("L")
  indent   = line~left(line~length - stripped~length)
  Parse Var stripped kw spec rest
  colon = spec~lastPos(":")
  If colon > 0 Then newSpec = spec~left(colon) || port
                Else newSpec = port
  If rest == "" Then Return indent || kw newSpec
  Return indent || kw newSpec rest

/******************************************************************************/
/* Ask: prompt for a yes/no answer. Returns 1 for yes, 0 for no.              */
/******************************************************************************/

::Routine Ask Public
  Use Strict Arg prompt
  Call CharOut , prompt "(Y/n) "
  Parse Pull answer
  -- Enter (an empty answer) accepts the default, which is yes: the capital Y
  -- in the prompt signals it. Any non-empty answer is read as before -- yes
  -- only if it abbreviates "y" (y, Y, yes, ...); anything else is no.
  If answer~strip == "" Then Return 1
  Return answer~caselessAbbrev("y")

/******************************************************************************/
/* IsWindowsAdmin: is this process running elevated (Administrator)?          */
/* "net session" needs elevation to succeed, so its exit code is a reliable   */
/* probe that does not depend on which account we are. Windows only; on other */
/* platforms the installers use sudo per command instead, so this is unused.  */
/******************************************************************************/

::Routine IsWindowsAdmin Public
  Return SysCmd("net session >nul 2>&1") == 0

/******************************************************************************/
/* Management directory + manifest. Two halves of "make uninstall self-       */
/* sufficient": the six install/ files are copied to a stable management      */
/* directory (so uninstall survives the download being deleted), and a        */
/* manifest records the one install-time decision uninstall cannot otherwise  */
/* recover -- the Windows server root, which may have been set with --root to */
/* something non-standard. On Linux/Mac the paths are fixed or derived from   */
/* brew, so there the manifest is written for uniformity but carries no       */
/* information uninstall could not recompute.                                 */
/*                                                                            */
/* The copy itself is NOT here: it needs sudo on Unix and SysFileCopy on      */
/* Windows, so each *.install does its own. What lives here is only what is   */
/* identical everywhere: the directory path, and reading/writing the manifest */
/* (pure Rexx via .Properties, no shell, no privilege).                       */
/*                                                                            */
/* .Properties trap (verified on 5.3): save/load round-trips name=value and   */
/* handles the backslashes in a Windows path, but it UPPERCASES keys, and the */
/* loaded entries are reachable with hasEntry/[]/at -- NOT getEntry. So we    */
/* key the manifest in upper case and read it with [] and hasEntry            */
/* throughout.                                                                */
/******************************************************************************/

-- The five files the uninstaller needs, copied verbatim into the management
-- directory so uninstall can run from there after the download is gone.
-- install.rex is deliberately NOT among them: it is the install driver and
-- has no role once installed. Named explicitly (each *.install copies these).
::Routine ManagementFiles Public
  Return "uninstall.rex InstallHelpers.cls" -
         "Linux.install.orx Mac.install.orx Windows.install.orx"

-- The stable directory where install leaves those files and the manifest,
-- and where uninstall runs from. Uniform basename "rexxhttp" on all three.
-- On Windows it lives under %ProgramData% (the per-machine application-data
-- location, the Windows equivalent of /usr/local/share), DELIBERATELY OUTSIDE
-- the Apache tree: keeping it out of the server root is what lets a symmetric
-- uninstall delete C:\Apache24 whole and clean, with no directory left behind
-- as the console's live cwd. ProgramData is read from the environment, not
-- hard-wired to C:\, because it can sit on another drive. The serverRoot
-- argument is now unused on every platform (Windows no longer hangs off it,
-- Unix never did); it is kept in the signature only to avoid churning callers.
::Routine ManagementDir Public
  Use Strict Arg platform, serverRoot = ""
  Select Case platform
    When "Windows" Then Return Value("ProgramData", , "ENVIRONMENT")"\rexxhttp"
    Otherwise           Return "/usr/local/share/rexxhttp"
  End

-- The manifest's full path inside the management directory. One name in one
-- place, so writer and reader cannot drift apart.
::Routine ManifestPath Public
  Use Strict Arg platform, mgmtDir
  If platform == "Windows" Then Return mgmtDir"\manifest"
  Return mgmtDir"/manifest"

-- Write the manifest to the given path. It records the two install-time
-- decisions the uninstall cannot otherwise recover: the Windows server root,
-- and the Apache Listen port (recorded only when the install changed it from
-- the platform default, so a keep-apache uninstall can put Listen back).
-- port defaults to "" -- callers that do not touch the port omit it and no
-- PORT key is written. Returns nothing; the caller decides placement and, on
-- Unix, moves it into the root-owned management directory with sudo.
::Routine WriteManifest Public
  Use Strict Arg path, serverRoot, port = ""
  props = .Properties~new
  props~setEntry("SERVERROOT", serverRoot)
  If port \== "" Then props~setEntry("PORT", port)
  props~save(path)
  Return

-- Read the manifest and return the recorded server root, or "" when there is
-- no usable manifest (missing file loads empty; absent key -> ""). The empty
-- string is the "fall back to flags/defaults" signal for the caller.
::Routine ReadManifestRoot Public
  Use Strict Arg path
  props = .Properties~new
  props~load(path)                       -- missing file: silently empty
  If \props~hasEntry("SERVERROOT") Then Return ""
  Return props["SERVERROOT"]

-- Read the manifest and return the recorded Apache Listen port, or "" when the
-- manifest has no PORT key -- which means the install did not change the port,
-- so the uninstall has nothing to restore.
::Routine ReadManifestPort Public
  Use Strict Arg path
  props = .Properties~new
  props~load(path)                       -- missing file: silently empty
  If \props~hasEntry("PORT") Then Return ""
  Return props["PORT"]

-- The htdocs manifest lives beside the main manifest in the management
-- directory. It records, one per line, the document-root-relative path of
-- every file the installer planted in htdocs under the exclusion model. It is
-- a plain line list rather than a Properties file because it is a list, not a
-- set of keyed values, and staying line-oriented keeps it readable and trivial
-- to append to. The uninstall reads it to retire exactly what was planted.
::Routine HtdocsManifestPath Public
  Use Strict Arg platform, mgmtDir
  If platform == "Windows" Then Return mgmtDir"\htdocs.manifest"
  Return mgmtDir"/htdocs.manifest"

-- Write the htdocs manifest: one document-root-relative path per line, in the
-- order they were planted (directories are not listed; only files, since
-- removing the files and then their emptied directories is enough). Overwrites
-- any existing file. As with WriteManifest, the caller places this at a temp
-- path first and, on Unix, sudo-copies it into the root-owned mgmt directory.
::Routine WriteHtdocsManifest Public
  Use Strict Arg path, planted
  Call Stream path, "C", "Open Write Replace"
  Do rel Over planted
    Call LineOut path, rel
  End
  Call Stream path, "C", "Close"
  Return

-- Read the htdocs manifest and return its lines as a List of relative paths,
-- or an empty List when there is no manifest (an install predating the
-- exclusion model, or a partial install). The uninstall walks this in reverse
-- so files go before the directories that held them.
::Routine ReadHtdocsManifest Public
  Use Strict Arg path
  lines = .List~new
  If \SysFileExists(path) Then Return lines
  Call Stream path, "C", "Open Read"
  Do While Lines(path) > 0
    line = LineIn(path)~strip
    If line \== "" Then lines~append(line)
  End
  Call Stream path, "C", "Close"
  Return lines

-- Retire everything the htdocs manifest records, under docRoot. Removes the
-- files first, then prunes the directories that held them if (and only if)
-- they are left empty -- walking parents deepest-first so a nested tree
-- collapses from the leaves up. Directories that still hold operator files are
-- left in place: on the keep-apache (coexist) path htdocs is not ours to wipe,
-- so we only ever take back what we planted. A missing file is not an error
-- (an operator may have removed it); it is simply skipped.
--
-- sudo is the command prefix for privileged removal: "" deletes in-process
-- with the SysFile* API (used where the caller already owns the tree, e.g.
-- Windows), "sudo" routes deletion through the shell as root (Unix, where
-- htdocs is root-owned). Uniform with how the rest of the installer removes
-- things. Returns nothing.
::Routine UnplantHtdocs Public
  Use Strict Arg docRoot, planted, sudo = ""
  sep = .File~separator

  -- 1. Remove the planted files, and collect the directories they lived in.
  dirs = .Set~new
  Do rel Over planted
    abs = docRoot || sep || rel~changeStr("/", sep)
    If sudo == "" Then Do
      If SysFileExists(abs) Then Call SysFileDelete abs
    End
    Else
      Address System sudo "rm -f" '"'abs'"'
    parent = .File~new(abs)~parentFile
    If parent \== .nil Then dirs~put(parent~absolutePath)
  End

  -- 2. Prune now-empty directories deepest-first. Sorting the collected
  -- directory paths by descending length puts children before parents, so a
  -- directory is visited only after its subdirectories have had their chance
  -- to be pruned. Only empty directories are removed; a non-empty one is left
  -- untouched, which is exactly the coexist-safe behaviour we want.
  ordered = dirs~makeArray~sortWith(.DescendingLengthComparator~new)
  Do d Over ordered
    -- Walk up from each recorded directory towards docRoot, pruning empties.
    -- The stop test is exact string equality against docRoot. This is safe
    -- because `current` and `d` both come from `~absolutePath` (via parentFile),
    -- and callers pass an already-normalised docRoot: the two are produced by
    -- the same normalisation, so they compare equal at the boundary. ACCEPTED,
    -- not hardened: normalising docRoot here would touch the uninstall's
    -- directory-pruning path (the most destructive in the installer) with no
    -- e2e coverage on Win/Mac, for a mismatch the callers do not produce.
    current = d
    Do While current \== "", current \== docRoot
      f = .File~new(current)
      If \f~exists Then Leave
      kids = f~listFiles
      If kids \== .nil, kids~items > 0 Then Leave    -- not empty: stop here
      If sudo == "" Then Call SysRmDir current
      Else Address System sudo "rmdir" '"'current'"'
      parent = f~parentFile
      If parent == .nil Then Leave
      current = parent~absolutePath
    End
  End
  Return

-- Orders strings by DESCENDING length: longer paths (deeper directories) sort
-- first, so UnplantHtdocs prunes children before their parents. Ties keep a
-- stable-enough order; only relative depth matters here.
::Class DescendingLengthComparator SubClass Comparator
::Method compare
  Use Strict Arg left, right
  Return right~length - left~length

-- The exclusion model for populating htdocs. Instead of enumerating what to
-- deploy, the installer copies the WHOLE package into the document root and
-- leaves out only these top-level entries: the installer itself, the test
-- suite, the packer, and the two repo-only metadata files. Everything else
-- (bin/, css/, examples/, src/ as a readable
-- copy, the manual PDF, readme.md, LICENSE, and the root index) becomes the
-- browsable sample web. Matched by basename at the package root only; nothing
-- inside a kept directory is filtered. One list, shared by all three
-- platforms, so the rule cannot drift between them.
--
-- Note: this list is names only. Packaging artefacts are excluded separately
-- by extension (see IsPackagingArtifact), because a user who unzips the
-- downloaded rexxhttp-latest.zip and runs the install from that folder leaves
-- the .zip sitting in the package root -- it must not be copied into htdocs.
--
-- Some entries below no longer travel in the published zip at all: pack.rex
-- excludes ITSELF from the archive it builds (it is a build utility, not part
-- of what users download), and .gitattributes never made it in either, since
-- "zip -r ... *" leaves top-level dotfiles out. They stay on this list on
-- purpose: the installer takes its source root from its own location, so it
-- runs just as well from a git clone, where all three files DO exist and must
-- still be kept out of the document root.
--
-- agents.md is the opposite case and belongs here for its own reason: it DOES
-- travel in the zip (it is plain text, useful to anyone who downloads the
-- package meaning to contribute), but it is project guidance, not part of the
-- sample web -- so it ships, and it is not served. Shipping and serving are
-- separate decisions; this list only governs the second.
::Routine HtdocsExclude Public
  Return "install tests docbook pack.rex .gitattributes agents.md"

-- Is this basename a packaging artefact that must never reach htdocs? These
-- are the same extensions pack.rex excludes from the archive it builds
-- (*.zip *.deb *.war *.gz), caught here by suffix so any such file dropped
-- into the package root -- most commonly the downloaded rexxhttp-latest.zip
-- itself -- is left out of the deployed document root regardless of its name.
::Routine IsPackagingArtifact Public
  Use Strict Arg name
  Do ext Over ".zip .deb .war .gz"~makeArray(" ")
    If name~caselessEndsWith(ext) Then Return .true
  End
  Return .false

-- Is this basename a development-only file that must never reach htdocs, no
-- matter how deep it sits? Unlike HtdocsExclude (top-level entries) and
-- IsPackagingArtifact (by extension), this catches individual files by name
-- pattern anywhere in the tree. Today: the highlight style test sheets
-- rexx-test<N>.css, which live under css/ during development (the Parser's
-- own copy-exclusion list keeps them out of the package, but this is the
-- belt-and-braces guard in case one slips through).
::Routine IsExcludedFile Public
  Use Strict Arg name
  If name~caselessStartsWith("rexx-test"), name~caselessEndsWith(".css") Then
    Return .true
  Return .false

-- Depth-first listing of every file and directory under a root, directories
-- yielded before their contents on the way down. The installer walks this to
-- copy the package into htdocs; the uninstall walks the recorded manifest in
-- reverse, so children are removed before their parents. Returns a List of
-- .File objects. An unreadable directory (listFiles == .nil) contributes
-- nothing rather than aborting the walk.
::Routine deepListFiles Public
  Use Strict Arg directory, accumulator = (.List~new)
  files = .File~new(directory)~listFiles
  If files == .nil Then Return accumulator
  Do file Over files
    accumulator~append(file)
    If file~isDirectory Then Call deepListFiles file~absolutePath, accumulator
  End
  Return accumulator

-- Populate htdocs from the package under the exclusion model, and return the
-- manifest of what was planted: a List of paths RELATIVE to the document root
-- (forward slashes), files only. The caller records this list so the uninstall
-- knows exactly what to retire -- essential on the keep-apache (coexist) path,
-- where htdocs is not ours to wipe wholesale. srcRoot is the package root
-- (parent of this install/ directory); docRoot is where Apache serves from.
-- Top-level entries named in HtdocsExclude are skipped; everything else is
-- copied whole, creating directories as needed.
--
-- sudo is the command prefix for privileged copying: "" copies in-process with
-- SysFileCopy / SysMkDir (Windows, or wherever the caller owns docRoot),
-- "sudo" routes copy and mkdir through the shell as root (Unix, where htdocs is
-- root-owned). Symmetric with UnplantHtdocs.
::Routine PlantHtdocs Public
  Use Strict Arg srcRoot, docRoot, sudo = ""
  exclude  = HtdocsExclude()~makeArray(" ")
  planted  = .List~new

  -- Build the list of top-level package entries to copy (exclusions removed):
  -- named exclusions (HtdocsExclude) plus any packaging artefact by extension.
  roots = .Array~new
  entries = .File~new(srcRoot)~listFiles
  If entries == .nil Then Return planted   -- srcRoot unreadable: nothing to plant
  Do entry Over entries
    If exclude~hasItem(entry~name) Then Iterate
    If IsPackagingArtifact(entry~name) Then Iterate
    roots~append(entry)
  End

  -- Walk each kept top-level entry depth-first, mirroring it into docRoot.
  Do top Over roots
    If top~isDirectory Then Do
      -- Recreate the directory itself first, then every descendant.
      Call MirrorEntry top, srcRoot, docRoot, planted, sudo
      Do f Over deepListFiles(top~absolutePath)
        If \f~isDirectory, IsExcludedFile(f~name) Then Iterate
        Call MirrorEntry f, srcRoot, docRoot, planted, sudo
      End
    End
    Else Do
      If IsExcludedFile(top~name) Then Iterate
      Call MirrorEntry top, srcRoot, docRoot, planted, sudo
    End
  End

  Return planted

-- Mirror a single package entry (file or directory) into docRoot, preserving
-- its path relative to srcRoot. Directories are created; files are copied and
-- their relative path appended to the planted manifest. Relative paths use
-- forward slashes regardless of platform separator, so the manifest is
-- portable and readable. sudo as in PlantHtdocs.
::Routine MirrorEntry
  Use Strict Arg entry, srcRoot, docRoot, planted, sudo = ""
  sep = .File~separator
  abs = entry~absolutePath
  -- Relative path = absolute minus the srcRoot prefix and its separator.
  rel = abs~substr(srcRoot~length + 2)
  relSlash = rel~changeStr(sep, "/")
  dest = docRoot || sep || rel

  If entry~isDirectory Then Do
    Call MakeDir dest, sudo                 -- harmless if it already exists
    Return
  End

  -- Ensure the parent directory exists (deepListFiles yields dirs before their
  -- files, but a lone top-level file has no directory entry of its own).
  parent = .File~new(dest)~parentFile
  If parent \== .nil, \parent~exists Then
    Call MakeDir parent~absolutePath, sudo
  If sudo == "" Then
    Call SysFileCopy entry~absolutePath, dest
  Else
    Address System sudo "cp" '"'entry~absolutePath'"' '"'dest'"'
  planted~append(relSlash)
  Return

-- Create a directory, directly (SysMkDir) or as root (sudo mkdir -p). mkdir -p
-- is harmless on an existing directory; SysMkDir on an existing one simply
-- fails without effect, which is fine since callers never depend on its RC.
::Routine MakeDir
  Use Strict Arg dir, sudo = ""
  If sudo == "" Then Call SysMkDir dir
  Else Address System sudo "mkdir -p" '"'dir'"'
  Return

-- Locate the Rexx Parser's bin/ directory in the user's environment at install
-- time, or "" when it cannot be found. This runs where we DO see the user's
-- environment (unlike Apache's child at runtime), so the result can be frozen
-- into the Apache config (SetEnv REXX_PATH; see RexxHTTPSetEnvLines).
--
-- Search order, first hit wins: current directory, then REXX_PATH, then PATH.
-- The anchor is the file Rexx.Parser.cls. From the file we return its PARENT
-- directory.
--
-- When srcRoot is supplied (the RexxHTTP package root being installed), we also
-- consider a Parser checked out as a SIBLING of RexxHTTP: <srcRoot>/../rexx-parser
-- /bin. Convention -- rexxhttp/ and rexx-parser/ side by side under a common
-- parent -- so one ".." hop off srcRoot lands on the sibling; .File normalizes
-- it. This catches the common developer checkout even when the sibling bin/ is
-- on no search variable. The sibling is folded into the standard order by
-- TEMPORARILY prepending it to PATH for the probe, then restoring PATH (measured
-- in ooRexx 5.3.0: SysSearchPath does see a variable set in-process via
-- Call Value ..."ENVIRONMENT"). PATH is restored on every exit path.
--
-- SysSearchPath takes the NAME of an environment variable (not its value) and
-- returns the absolute path of the first matching file, or "" if none; a
-- missing variable yields "" without error. We probe the current directory
-- separately with .File~exists so the cwd->REXX_PATH->PATH order is explicit
-- and does not depend on SysSearchPath's internal handling of ".".
::Routine ParserBin Public
  Use Strict Arg srcRoot = ""
  anchor = "Rexx.Parser.cls"

  -- 1. Current directory.
  cwdHit = .File~new(anchor)
  If cwdHit~exists Then Return cwdHit~parentFile~absolutePath

  -- Temporarily fold a sibling rexx-parser/bin into PATH, if srcRoot was given
  -- and the sibling directory resolves. Saved for restoration below.
  savedPath = .Nil
  If srcRoot \== "" Then Do
    sep     = .File~separator
    sibling = .File~new(srcRoot || sep || ".." || sep || "rexx-parser" || sep || "bin")~absolutePath
    If .File~new(sibling)~exists Then Do
      savedPath = Value("PATH", , "ENVIRONMENT")
      Call Value "PATH", sibling || .File~pathSeparator || savedPath, "ENVIRONMENT"
    End
  End

  -- 2. REXX_PATH, then 3. PATH (with the sibling prepended, if any).
  found = ""
  Do var Over .Array~of("REXX_PATH", "PATH")
    hit = SysSearchPath(var, anchor)
    If hit \== "" Then Do
      found = .File~new(hit)~parentFile~absolutePath
      Leave
    End
  End

  -- Restore PATH no matter what (only touched if we prepended above).
  If savedPath \== .Nil Then Call Value "PATH", savedPath, "ENVIRONMENT"

  Return found                             -- "" => not found; rexxlet degrades

-- Produce the SetEnv lines the Apache config fragment needs for point 17, as a
-- single string of complete lines (native line terminators). Three variables,
-- all frozen here at install time so Apache's child process -- which does not
-- see the user's PATH -- can read them at runtime:
--
--   REXXHTTP_BASE     the installation root (docRoot): where the whole package,
--                     including src/RexxHTTP.CommonRoutines.cls, was planted.
--                     The installer already knows it, so this is
--                     unconditional. No trailing separator: the consumer
--                     supplies the "/".
--   REXXHTTP_URLBASE  the URL prefix of the installation. A clean-machine
--                     install always lands at the document root, so this is
--                     the "*" sentinel (no prefix). Emitted together with
--                     BASE so the pair is never half-configured (BASE without
--                     URLBASE makes the rexxlet 500). A subdirectory (aliased)
--                     deployment is manual config, outside this installer.
--   REXX_PATH         the package's own bin/ (<docRoot>/bin), so a rexxlet can
--                     resolve ::Requires "HTML.Page.cls" (and the other loadable
--                     classes that live there) no matter which directory the
--                     rexxlet itself sits in -- PLUS the Parser's bin/ when found.
--                     Apache prefixes REXX_PATH to REDIRECT_REXX_PATH across
--                     the Action; RexxHTTP.rex reinjects it before calling the
--                     rexxlet, and ooRexx reads it at ::Requires time (and
--                     markdown.rxl at searchPath time). The package bin/ is in
--                     the slash form the Apache config uses; entries are joined
--                     with the platform list separator.
--
-- srcRoot is the RexxHTTP package root being installed FROM (the source tree),
-- distinct from docRoot (the install TARGET). Passed through to ParserBin so a
-- Parser checked out as a sibling of RexxHTTP is detected. Optional: when
-- omitted, sibling detection is simply skipped.
--
-- Returned as text so each installer can splice it into the fragment it writes,
-- wherever that installer puts SetEnv directives. Empty variables are never
-- emitted (an empty REXXHTTP_BASE would be a bug in the caller; guard anyway).
::Routine RexxHTTPSetEnvLines Public
  Use Strict Arg docRoot, indent = "", srcRoot = ""
  eol = .endOfLine
  out = .MutableBuffer~new

  -- Locate the Parser once (sibling detection uses srcRoot when given).
  -- The Parser half of REXX_PATH derives from this single probe.
  parserBin = ParserBin(srcRoot)

  If docRoot \== "" Then Do
    out~append(indent, "SetEnv REXXHTTP_BASE """docRoot"""", eol)
    -- A clean-machine install always lands at the document root: no URL
    -- prefix, so the URLBASE half of the pair is the "*" sentinel. Emitting
    -- it here keeps BASE and URLBASE together -- never half a pair, which
    -- would make the rexxlet 500 (BASE set, URLBASE empty). A subdirectory
    -- deployment (RexxHTTP hung off an alias) is a manual-config scenario,
    -- outside this clean-machine installer's scope.
    out~append(indent, "SetEnv REXXHTTP_URLBASE *", eol)
    -- REXX_PATH: the package's own bin/ (so ::Requires in a rexxlet resolves
    -- regardless of the rexxlet's own directory), plus the Parser's bin/ when
    -- found -- markdown.rxl locates FencedCode.cls by scanning REXX_PATH, and the
    -- Parser classes live outside <docRoot>/bin (in the separate rexx-parser
    -- package), so without this entry highlighting silently stays off even with
    -- the Parser installed. docRoot is already in the slash form the Apache
    -- config wants, so "/bin" is glued with "/"; entries are joined with the
    -- platform list separator.
    rexxPath = docRoot"/bin"
    If parserBin \== "" Then
      rexxPath = rexxPath || .File~pathSeparator || parserBin
    out~append(indent, "SetEnv REXX_PATH """rexxPath"""", eol)
  End

  Return out~string
