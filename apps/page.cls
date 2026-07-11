/******************************************************************************/
/*                                                                            */
/* page.cls - A sample page factory                                           */
/* ================================                                           */
/*                                                                            */
/* This class is provided as an example. It shows how a rexxlet can           */
/* serve a page with the RexxHTTP look without repeating the header, the      */
/* footer or the stylesheet link in every one.                                */
/*                                                                            */
/* Use from a rexxlet:                                                        */
/*                                                                            */
/*   -- To load the class into a Servlet, use:                                */
/*      .context~package~loadPackage( .request~RexxHTTP_dir"/apps/page.cls" ) */
/*                                                                            */
/*    -- (a) explicit body:                                                   */
/*           myPage = .Page~new("My title")  -- Creates the page              */
/*           myPage~body("<p>Hello</p>")     -- Sets the body                 */
/*           myPage~done                     -- Emits the page contents       */
/*                                                                            */
/*    -- (b) explicit body, chained:                                          */
/*          .Page~new("My title")~body("<p>Hello</p>")~done                   */
/*                                                                            */
/*    -- (c) or without passing a body: it is taken from the rexxlet's        */
/*    --     own ::Resource BODY (see the done method). The rexxlet just      */
/*    --     declares:                                                        */
/*    --         ::Resource BODY                                              */
/*    --           <p>Hello</p>                                               */
/*    --         ::END                                                        */
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
/* 20260611    1.0  First version                                             */
/*                                                                            */
/******************************************************************************/

::Class Page Public

/******************************************************************************/
/* TITLE -- The page title                                                    */
/******************************************************************************/

::Attribute title

/******************************************************************************/
/* INIT -- Store the page title                                               */
/******************************************************************************/

::Method init
  Expose title body
  Use Strict Arg title

  body = .nil

/******************************************************************************/
/* BODY -- Set the body content explicitly                                    */
/******************************************************************************/

::Method body
  Expose body
  Use Strict Arg body
  Return self                           -- Allows chaining

/******************************************************************************/
/* DONE -- Assemble the whole page and emit it                                */
/******************************************************************************/

::Method done
  Expose title

  Use Strict Arg substitutions = (.Array~new)
 .Validate~requestClassType("substitutions", substitutions, .Array)

  body = self~page.Body
  Loop Counter c sub Over substitutions
    from = sub[1]
    to   = sub[2]
    body = body~changeStr(from, to)
  End

  -- css lives in <installation-path>/css, not necessarily /css, and we have
  -- to calculate its relative path.
  depth   = .request~uri~countStr("/") - ,
            .request~RexxHTTP_URL~countStr("/")
  cssPref = Copies("../", Max(depth, 0))

  out     = .MutableBuffer~new
  brand   = .request~RexxHTTP_URL
  year    =  Date("Iso")~left(4)

  -- The <link> list and the chooser <option> list are generated from the
  -- actual rexx-<style>.css sheets on disk (see styleSheets), not written out
  -- by hand: a new style drops in as a file and appears in both places with no
  -- edit here. The two strips come back tab-separated.
  Parse Value self~styleSheets With links "09"x options

  out~append(                             -
   .resources~page.header~makeString~     -
      changeStr("%title%",        title  )~ -
      changeStr("%stylelinks%",   links  )~ -
      changeStr("%styleoptions%", options)~ -
      changeStr("%css%",          cssPref)~ -
      changeStr("%home%",         brand  ), -
   .EndOfLine,                        -
    body,                             -
   .EndOfLine,                        -
   .resources~page.footer~makeString~ -
      changeStr("%css%",   cssPref)~  -
      changeStr("%home%",  brand)~    -
      changeStr("%year%",  year)      -
  )

  Say out~string

  Return self

/******************************************************************************/
/* STYLESHEETS -- Build the two style strips from the sheets on disk.         */
/*                                                                            */
/* Returns two tab-separated strings: the <link> block for the header, and    */
/* the <option> block for the code-style chooser. Both are generated from the */
/* rexx-<style>.css sheets that actually sit in the css/ directory, so adding */
/* a style is just dropping in a file -- no edit here and no drift between    */
/* the two lists.                                                             */
/*                                                                            */
/* The css/ directory is found relative to this class file (.context~package~ */
/* name is THIS page.cls, wherever it was installed), not to any URL.         */
/*                                                                            */
/* "dark" is the default and is treated specially: its <link> loads eagerly   */
/* (no media="not all"), and its <option> carries selected. Every other sheet */
/* loads disabled (media="not all") and its option is plain -- the JS style   */
/* chooser flips them at runtime. rexx-test<N>.css sheets are                 */
/* development-only and excluded (they are also kept out of the package by    */
/* the installer).                                                            */
/*                                                                            */
/* The hrefs embed the %css% placeholder verbatim, so the caller's single     */
/* changeStr("%css%", cssPref) expands the relative prefix on every line at   */
/* once, exactly as it does for the hand-written rexxhttp.css link.           */
/******************************************************************************/

::Method styleSheets Private
  sep    = .File~separator
  clsDir = .File~new(.context~package~name)~parentFile~absolutePath
  cssDir = .File~new(clsDir || sep || ".." || sep || "css")~absolutePath

  Call SysFileTree cssDir || sep || "rexx-*.css", "sheets.", "FO"

  names = .Array~new
  Do i = 1 To sheets.0
    base = .File~new(sheets.i)~name              -- "rexx-<style>.css"
    If base~caselessStartsWith("rexx-test") Then Iterate   -- dev-only
    style = base~substr(6)                       -- drop leading "rexx-"
    style = style~left(style~length - 4)         -- drop trailing ".css"
    names~append(style)
  End
  names~sort                                     -- alphabetical == current order

  links   = .MutableBuffer~new
  options = .MutableBuffer~new
  Do style Over names
    href  = '%css%css/rexx-'style'.css'
    -- "dark" is the default: eager link (no media guard), selected option.
    If style == "dark" Then media = ""
                        Else media = ' media="not all"'
    link = '  <link rel="stylesheet" href="'href'"'media' data-rexx-style="'style'">'
    links~append(link, .EndOfLine)

    If style == "dark" Then sel = " selected"
                        Else sel = ""
    option = '        <option value="'style'"'sel'>'style'</option>'
    options~append(option, .EndOfLine)
  End

  Return links~string || "09"x || options~string

/******************************************************************************/
/* PAGE.HEADER -- The page header, with substitutable %placeholders%          */
/******************************************************************************/

::Resource PAGE.HEADER
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>%title%</title>
  <link rel="stylesheet" href="%css%css/rexxhttp.css">
%stylelinks%
</head>
<body>
  <header class="site-header">
    <div class="wrap">
      <p class="marca"><a href="%home%">RexxHTTP</a></p>
      <p class="lema">Serving web content with Rexx</p>
    </div>
  </header>
  <main class="wrap">
    <div class="code-style-bar" hidden>
      <label class="code-style-bar__label" for="rexx-style-chooser">Code style</label>
      <select id="rexx-style-chooser" class="code-style-bar__select">
%styleoptions%
      </select>
    </div>
::END

/******************************************************************************/
/* PAGE.BODY -- If a body has been specified manually, return that body.      */
/*              Otherwise, return the rexxlet's ::Resource BODY as a string.  */
/*              If everything fails, return "".                               */
/******************************************************************************/

::Method page.Body Private
  Expose body

  -- 1) Body has been specified manually
  If body \== .Nil Then Return body

  -- 2) Look for a ::Resource BODY
  myself = .Context~package
  stackFrames = .context~stackFrames
  Do i = 1 To stackFrames~items
    exe = stackFrames[i]~executable
    If exe == .nil Then Iterate
    If exe~package \== myself Then Signal Found
  End

  -- 3) Not found: Return ""
  Return ""

Found:
  res = stackFrames[i]~executable~package~resource("BODY")
  If res \== .nil Then Return res~makeString
  Return ""

/******************************************************************************/
/* PAGE.FOOTER -- The page footer, with substitutable %placeholders%          */
/******************************************************************************/

::Resource PAGE.FOOTER
  </main>
  <footer class="site-footer">
    <div class="wrap">
      Served by <a href="%home%">RexxHTTP</a> &mdash; a rexxlet processor for ooRexx. <a href="%home%rexxhttp.pdf">Documentation</a>.
      <br>
      Copyright &copy; <a href="https://rexx.epbcn.com/josep-maria-blasco/">Josep Maria Blasco</a>, 2006-%year%.
      Distributed under <a href="%home%LICENSE">the Apache 2.0 license</a>.
    </div>
  </footer>
  <script src="%css%js/style-chooser.js"></script>
</body>
</html>
::END
