::Routine OSType Public

  If .RexxInfo~platform~caselessStartsWith("Windows") Then
    Return "Windows"

  Address COMMAND "uname" With Output Stem uname.

  If uname.1 == "Darwin" Then Return "MacOS"

  Return "Linux"

/******************************************************************************/
/* Direct-invocation guard. We trust .sysCargs only when this program was      */
/* started directly -- from the CLI, or via an ADDRESS command (both create a  */
/* fresh process whose .sysCargs is its own). When reached by an internal CALL */
/* instead, .sysCargs belongs to the caller, so parsing it would read the      */
/* wrong arguments. A directly-started program has exactly one stack frame; a  */
/* CALL adds a frame on top. The driver checks this INLINE -- not in a routine */
/* -- because measuring the stack inside a ::Routine would add that routine's  */
/* own frame and throw the count off. This routine only supplies the message,  */
/* so the wording lives in one place:                                          */
/*                                                                            */
/*   If .Context~stackFrames~items > 1 Then Do                                 */
/*     Say IndirectInvocationMsg("install.rex"); Exit 1                        */
/*   End                                                                       */
/******************************************************************************/
::Routine IndirectInvocationMsg Public
  Use Strict Arg myName
  msg = myName "must be invoked from the command line or via an ADDRESS" -
        "command, not through an internal CALL: it relies on .sysCargs," -
        "which only reflects its own arguments when started directly."
  Return msg

/******************************************************************************/
/* ParseArgs: the single place where user arguments are parsed and sanitized. */
/* Reads .sysCargs -- already tokenized by the shell, so a quoted value with   */
/* spaces (e.g. --root "C:\Program Files\Apache") arrives as ONE element and   */
/* is never re-split. Returns a Directory of structured options that the       */
/* os-specific *.install scripts consume as-is (they do no parsing of their    */
/* own). The caller passes mode = "install" or "uninstall", which decides       */
/* which flags are legal.                                                       */
/*                                                                            */
/* On a bad argument it does NOT exit (a ::Routine cannot end the program);     */
/* it sets opts~valid = 0 and opts~errorMsg, and the driver prints+exits.       */
/*                                                                            */
/* Returned directory entries:                                                 */
/*   valid       -- 1 | 0                                                       */
/*   errorMsg    -- "" or the message to print when valid = 0                   */
/*   mode        -- "install" | "uninstall"                                    */
/*   assumeYes   -- 0 | 1                                                       */
/*   keepApache  -- 0 | 1   (uninstall only)                                   */
/*   serverRoot  -- "" or the path        (Windows only)                       */
/*   zipUrl      -- "" or the URL          (Windows only, install only)        */
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

      Otherwise Return BadArg(opts, "Invalid argument '"arg"'.")
    End
    i = i + 1
  End

  Return opts

BadArg:
  Use Strict Arg opts, message
  opts~valid    = 0
  opts~errorMsg = message
  Return opts

/******************************************************************************/
/* SysCmd: run a command, return its exit code.                               */
/******************************************************************************/
::Routine SysCmd Public
  Use Strict Arg command
  Address System command
  Return RC

/******************************************************************************/
/* CmdOutputHas: run a command, capture its standard output, and return 1 if   */
/* any output line caselessly contains the given needle, else 0. Used for      */
/* probes whose exit code is not reliable -- tasklist and netstat both return   */
/* 0 whether or not they found anything, so the answer is in the text, not RC.  */
/* Errors are swallowed: a probe that cannot run is treated as 'not found'.     */
/******************************************************************************/
::Routine CmdOutputHas Public
  Use Strict Arg command, needle
  out = .Array~new
  Address System command With Output Using (out) Error Using (.Array~new)
  Do line Over out
    If line~caselessContains(needle) Then Return 1
  End
  Return 0

/******************************************************************************/
/* Ask: prompt for a yes/no answer. Returns 1 for yes, 0 for no.              */
/******************************************************************************/

::Routine Ask Public
  Use Strict Arg prompt
  Call CharOut , prompt "(y/n) "
  Parse Pull answer
  Return answer~caselessAbbrev("y")

/******************************************************************************/
/* IsWindowsAdmin: is this process running elevated (Administrator)?           */
/* "net session" needs elevation to succeed, so its exit code is a reliable    */
/* probe that does not depend on which account we are. Windows only; on other  */
/* platforms the installers use sudo per command instead, so this is unused.   */
/******************************************************************************/

::Routine IsWindowsAdmin Public
  Return SysCmd("net session >nul 2>&1") == 0

-- The sample rexxlets shipped under examples/ that the installers deploy
-- into htdocs/examples/<name>/index. Listed explicitly (not globbed) so the
-- epbcn-specific examples/index -- which pulls in Bootstrap and the parser's
-- highlighter, absent on a fresh install -- is never dragged along. The
-- welcome page planted at the document root is the index for these instead.
-- Used by both the deploy step and the uninstall of every *.install.
::Routine ExampleDirs Public
  Return "hello-world hello-unicode-world hello-html-world" -
         "hello-html-and-unicode-world simple-form simple-cookie" -
         "simple-aggregate"

-- The welcome rexxlet planted at the document root. It doubles as the
-- smoke test (a request to "/" runs it, proving the processor works) and
-- as the landing page for the sample installation. The planted rexxlet is
-- a lone file in htdocs with no access to the installer's classes, so it
-- must be self-contained: it carries its own HTML in its own ::Resource.
::Routine SmokeTest Public
  Return .resources~SmokeTest~makeString

::Resource SmokeTest End "::::End"
.response~content_type = "text/html; charset=utf-8"
Say .resources~WelcomePage

::Resource WelcomePage
<!DOCTYPE html>
<html lang="en">
  <head>
    <meta charset="utf-8">
    <title>Welcome to RexxHTTP</title>
    <style>
      body { font-family: system-ui, sans-serif; max-width: 40rem;
             margin: 3rem auto; padding: 0 1rem; line-height: 1.5; }
      h1   { font-size: 1.6rem; }
      code { background: #f0f0f0; padding: 0.1em 0.3em; border-radius: 3px; }
      ul   { padding-left: 1.2rem; }
      li   { margin: 0.3rem 0; }
      .note { color: #555; font-size: 0.95rem; margin-top: 2rem; }
    </style>
  </head>
  <body>
    <h1>Welcome to RexxHTTP</h1>
    <p>
      This is a sample installation, set up so you can try RexxHTTP out
      right away. If you can read this page, the processor is working: this
      very page is itself a Rexx rexxlet.
    </p>
    <p>Here are our bundled examples to explore:</p>
    <ul>
      <li><a href="/examples/hello-world/">Hello, world!</a> &mdash; the simplest rexxlet</li>
      <li><a href="/examples/hello-unicode-world/">Hello, world! &amp; Unicode</a></li>
      <li><a href="/examples/hello-html-world/">A simple HTML rexxlet</a></li>
      <li><a href="/examples/hello-html-and-unicode-world/">HTML and Unicode together</a></li>
      <li><a href="/examples/simple-form/">Reading a GET form</a></li>
      <li><a href="/examples/simple-cookie/">Setting and reading a cookie</a></li>
      <li><a href="/examples/simple-aggregate/">Fetching and merging JSON from the web</a></li>
    </ul>
    <p>
      If you have read our book, you can follow its tutorial chapter to
      build these step by step yourself.
    </p>
    <p class="note">
      The rexxlets are all written in Rexx, and they are named
      <code>index</code> on purpose: it keeps the URLs clean, so a rexxlet
      is reached as <code>/examples/hello-world/</code> rather than by a
      file name. The name <code>index</code> is part of the URL, not a hint
      about the implementation &mdash; a rexxlet is a resource Apache invokes,
      not a script you run directly.
    </p>
  </body>
</html>
::END
::::End

-- The index planted at htdocs/examples/index, so a request to /examples/
-- returns this page instead of Apache's directory listing. Self-contained,
-- in the same style as the welcome page but more concise: it only lists the
-- examples. Built with a custom resource terminator so the rexxlet's own
-- ::Resource can nest, the same trick SmokeTest uses.
::Routine ExamplesIndex Public
  Return .resources~ExamplesIndex~makeString

::Resource ExamplesIndex End "::::End"
.response~content_type = "text/html; charset=utf-8"
Say .resources~ExamplesPage

::Resource ExamplesPage
<!DOCTYPE html>
<html lang="en">
  <head>
    <meta charset="utf-8">
    <title>RexxHTTP examples</title>
    <style>
      body { font-family: system-ui, sans-serif; max-width: 40rem;
             margin: 3rem auto; padding: 0 1rem; line-height: 1.5; }
      h1   { font-size: 1.6rem; }
      ul   { padding-left: 1.2rem; }
      li   { margin: 0.3rem 0; }
    </style>
  </head>
  <body>
    <h1>RexxHTTP examples</h1>
    <p>Each of these is a small Rexx rexxlet. Follow a link to see it run.</p>
    <ul>
      <li><a href="hello-world/">Hello, world!</a> &mdash; the simplest rexxlet</li>
      <li><a href="hello-unicode-world/">Hello, world! &amp; Unicode</a></li>
      <li><a href="hello-html-world/">A simple HTML rexxlet</a></li>
      <li><a href="hello-html-and-unicode-world/">HTML and Unicode together</a></li>
      <li><a href="simple-form/">Reading a GET form</a></li>
      <li><a href="simple-cookie/">Setting and reading a cookie</a></li>
      <li><a href="simple-aggregate/">Fetching and merging JSON from the web</a></li>
    </ul>
    <p>
      <small><a href="/">&larr; Back to the welcome page.</a></small>
    </p>
  </body>
</html>
::END
::::End
