/******************************************************************************/
/*                                                                            */
/* home-page.rex - The RexxHTTP site home page                                */
/* ===========================================                                */
/*                                                                            */
/* This file is part of the RexxHTTP package                                  */
/* [See https://rexx.epbcn.com/rexxhttp/]                                     */
/*                                                                            */
/* Copyright (c) 2006-2026 Josep Maria Blasco <josep.maria.blasco@epbcn.com>  */
/*                                                                            */
/* License: Apache License 2.0 (https://www.apache.org/licenses/LICENSE-2.0)  */
/*                                                                            */
/* This file is called by a one line wrapper, wrapper.rxl. The wrapper is     */
/* automatically executed by Apache, but the .rex file, when directly         */
/* requested, is served by the highlighter.                                   */
/*                                                                            */
/* Version history:                                                           */
/*                                                                            */
/* Date     Version Details                                                   */
/* -------- ------- --------------------------------------------------------- */
/* 20260630    1.0  First version                                             */
/*                                                                            */
/******************************************************************************/

 .response~content_type = "text/html"

 .HTML.Page~new("RexxHTTP")~done

::Requires "HTML.Page.cls"

::Resource BODY
    <p class="rotulo">Welcome</p>

    <h1>RexxHTTP is installed and running.</h1>

    <p class="intro">This page is itself a rexxlet &mdash;
      <a href="home-page.rex">a small ooRexx
    program</a> that RexxHTTP ran to produce what you are reading. If you can
    see it, the processor works.</p>

    <p>From here you can read <a href="rexxhttp.pdf">the manual</a> or explore
      <a href="examples/">the bundled examples</a>.
      Each example is a rexxlet you can read, copy, and adapt.</p>

    <div class="grid">
      <a class="card" href="rexxhttp.pdf">
        <p class="card-title">The manual</p>
        <p class="card-desc">RexxHTTP, cover to cover: concepts, a short
        tutorial, installation, and the full class reference.</p>
      </a>
      <a class="card" href="examples/">
        <p class="card-title">The examples</p>
        <p class="card-desc">A handful of worked rexxlets, from a one-line
        greeting to a page that fetches data from the network.</p>
      </a>
      <a class="card" href="readme.md">
        <p class="card-title">The read-me</p>
        <p class="card-desc">What RexxHTTP is, what it needs, where it came
        from, and how the repository is laid out.</p>
      </a>
    </div>

    <p class="rotulo">Under the hood</p>

    <h2>The site explains itself.</h2>

    <p class="intro">Every page here is served by a rexxlet you can also read,
      and that includes the machinery that builds the pages,
      which resides in the <a href="bin/"><code>bin/</code></a> subdirectory.
      <a href="architecture.md">How this site works</a> tells the whole story
      &mdash; how a request becomes a page, and why the site publishes its own
      source. The three utilities below do the work; each box links to its own
      code, highlighted and served by RexxHTTP itself.</p>

    <div class="grid">
      <a class="card" href="bin/html-page.md">
        <p class="card-title">The page factory</p>
        <p class="card-desc">Wraps a body in the shared header, footer and
        stylesheet, so no page repeats the chrome. The class behind this very
        page.</p>
      </a>
      <a class="card" href="bin/markdown.md">
        <p class="card-title">The Markdown renderer</p>
        <p class="card-desc">Turns any <code>.md</code> file into a styled
        page with Pandoc &mdash; and serves it verbatim when Pandoc is absent,
        so the document always arrives.</p>
      </a>
      <a class="card" href="bin/src-viewer.md">
        <p class="card-title">The source viewer</p>
        <p class="card-desc">Serves the source of any Rexx file as a
        highlighted page. It is what lets these boxes point straight at the
        code &mdash; and at <code>src/</code>, the processor itself.</p>
      </a>
    </div>
::END
