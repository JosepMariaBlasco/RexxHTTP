/******************************************************************************/
/*                                                                            */
/* examples/examples-index.rex - The index of bundled examples                */
/* ===========================================================                */
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
/* 20260704    1.0  First version                                             */
/*                                                                            */
/******************************************************************************/

  -- We will build our page manually and feed it to the page
  -- using the ~body method

 .response~content_type = "text/html"

  body = .MutableBuffer~new
  eol  = .endOfLine

  body~append(.Resources~before~makeString)

  -- Each pair is (directory, link title). The titles follow the naming
  -- scheme that makes explicit what every example returns.
  Loop pair Over -
    ("hello-world-plain",         'Greeting the world &mdash; returning plain text'),                -
    ("hello-world-html",          'Greeting the world &mdash; returning HTML'),                      -
    ("hello-world-unicode-plain", 'Greeting the world with Unicode &mdash; returning plain text'),   -
    ("hello-world-unicode-html",  'Greeting the world with Unicode &mdash; returning HTML'),         -
    ("simple-form-html",          'Reading a HTML GET form'),                                        -
    ("simple-cookie-html",        'Setting, reading and resetting a cookie'),                        -
    ("aggregate-json",            'Fetching and merging JSON from the web &mdash; returning JSON'),  -
    ("aggregate-html",            'Fetching and merging JSON from the web &mdash; returning HTML')

    directory  = pair[1]
    linkTitle  = pair[2]

    entry = "      <li><a href='"directory"/'>"linkTitle"</a>" -
            "[<a href='"directory"/"directory".rex'>Source</a>]</li>"
    body~append(entry,eol)
  End

  body~append(.Resources~after~makeString)

 .HTML.Page~new("Examples")~body(body~string)~done

  Exit

::Requires "HTML.Page.cls"

--------------------------------------------------------------------------------

::Resource before
    <p class="rotulo">Examples</p>

    <h1>RexxHTTP examples</h1>
    <p class="intro">
      Each of these is a small rexxlet. Follow a link
      to see it run, or click the "[Source]" links to read its source.
    </p>

    <ol>
::END

--------------------------------------------------------------------------------

::Resource after
    </ol>

    <p>
    You can also have a look at <a href="examples-index.rex">the rexxlet that produces this page</a>.
    </p>
::END