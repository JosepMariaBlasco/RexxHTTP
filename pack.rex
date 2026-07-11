Parse Arg version .
date = date(s)

/* --------------------------------------------------------------------- */
/* Generate the Unix wrapper with guaranteed LF line endings.            */
/*                                                                       */
/* The wrapper is the one file that MUST be LF: Apache execs it by its   */
/* shebang, and a trailing CR would make the kernel look for "rexx\r".   */
/* RexxHTTP.rex and the classes may be CRLF (ooRexx reads either, and    */
/* on Unix RexxHTTP.rex is reached via Call, never by shebang), but the  */
/* wrapper cannot.                                                       */
/*                                                                       */
/* Writing it here, at pack time, makes the LF independent of how the    */
/* tree was checked out, edited (Notepad++), or synced (Dropbox): the    */
/* bytes are emitted raw, so no text-mode translation can turn the \n    */
/* into \r\n. The file is created fresh on every pack.                   */
/* --------------------------------------------------------------------- */
LF = "0a"x

wrapperLocation = "src/RexxHTTP_wrapper"

wrapper = .stream~new(wrapperLocation)
wrapper~open("write replace")
-- raw bytes: LF only, no CRLF translation
wrapper~charOut(                                          -
  .resources~Contents~makeString("L", LF)LF  -
)
wrapper~close

Say "generated" wrapperLocation "(LF)"

/* --------------------------------------------------------------------- */
/* Pre-generate syntax-highlighted source for the examples.              */
/*                                                                       */
/* RexxHTTP must run standalone: at a deployed site the Rexx Parser is   */
/* not guaranteed to be present, so the examples/index.rxl rexxlet cannot    */
/* highlight the sources live. Instead we highlight them HERE, at pack   */
/* time, where the Parser IS available (in ../rexx-parser at the build   */
/* site), and ship the result. For each example we write a .highlighted  */
/* file next to its index.rxl; examples/index.rxl serves that pre-rendered HTML  */
/* and, when a .highlighted is missing, simply lists the example without */
/* its source. A copy of the dark stylesheet travels in examples/css/    */
/* so the highlighted markup renders without the Parser installed.       */
/*                                                                       */
/* The .highlighted files and the CSS copy are versioned in the tree,    */
/* but pack regenerates them fresh on every run, so they never drift     */
/* from the sources they describe.                                       */
/* --------------------------------------------------------------------- */
parserDir = Value("REXX_PARSER_DIR", , "ENVIRONMENT")
If parserDir == "" Then parserDir = "../rexx-parser"

highlighter = parserDir"/bin/highlight.rex"
cssSource   = parserDir"/css/rexx-dark.css"

If \ SysFileExists(highlighter) Then Do
  Say "WARNING: highlighter not found at" highlighter
  Say "         (set REXX_PARSER_DIR or place the parser at ../rexx-parser)"
  Say "         examples/.highlighted files NOT regenerated this pack."
End
Else Do
  -- Copy the rexx-*.css stylesheets into the distribution so the set travels
  -- with us. The client-side style chooser (js/style-chooser.js) lazy-loads all
  -- but rexx-dark.css, but every sheet offered must be present to be picked.
  -- rexx-test1.css is a Parser development fixture, not a real theme, so it is
  -- excluded.
  Call SysMkDir "css"
  cssCopied = 0
  Call SysFileTree parserDir"/css/rexx-*.css", "cssFiles.", "FO"
  Do i = 1 To cssFiles.0
    base = FileSpec("Name", cssFiles.i)
    If base == "rexx-test1.css" Then Iterate   -- dev fixture, not a theme
    Call SysFileCopy cssFiles.i, "css/"base
    cssCopied = cssCopied + 1
  End
  If cssCopied > 0 Then
    Say "copied" cssCopied "rexx-*.css stylesheets to css/"
  Else
    Say "WARNING: no rexx-*.css stylesheets found under" parserDir"/css/"

  -- One .highlighted per example, next to its index.rxl. The set of examples is
  -- discovered by walking examples/: every subdirectory that holds an "index.rxl"
  -- file is an example to highlight. This keeps pack self-contained (no shared
  -- list to maintain) and in step with the exclusion-model installer, which
  -- likewise ships whatever examples/ contains rather than an enumerated set.
  Do entry Over .File~new("examples")~listFiles
    If \entry~isDirectory Then Iterate
    dir = entry~name
    src = "examples/"dir"/index.rxl"
    out = "examples/"dir"/.highlighted"
    If SysFileExists(src) Then Do
      Address Command "rexx" highlighter "-h" src ">" out
      Say "highlighted" src "->" out
    End
  End
End

/* --------------------------------------------------------------------- */
/* Package, as before.                                                   */
/* --------------------------------------------------------------------- */
zip1     = "rexxhttp-"version"-"date".zip"
zip2     = "rexxhttp-latest.zip"
"del *.zip"
"zip -r" zip1 "* -x *trace.xml *.zip *.deb *.war *.gz"
"zip -r" zip2 "* -x *trace.xml *.zip *.deb *.war *.gz"


::Resource Contents
#!/usr/bin/env rexx
/* RexxHTTP wrapper (Unix). Generated by pack.rex - do not edit by hand. */
/* Apache execs this; it Calls the processor, which sits beside it, so   */
/* RexxHTTP.rex's CRLF and its own shebang stay inert. Keep the two      */
/* files together in the same directory.                                 */
Call "RexxHTTP.rex"
::END
