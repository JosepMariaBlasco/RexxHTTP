/******************************************************************************/
/*                                                                            */
/* style-chooser.js -- Client-side Rexx highlight style chooser for RexxHTTP  */
/* ========================================================================= */
/*                                                                            */
/* This program is part of the RexxHTTP package                               */
/* [See https://rexx.epbcn.com/rexxhttp/]                                     */
/*                                                                            */
/* Copyright (c) 2024-2026 Josep Maria Blasco <josep.maria.blasco@epbcn.com>  */
/*                                                                            */
/* License: Apache License 2.0 (https://www.apache.org/licenses/LICENSE-2.0)  */
/*                                                                            */
/* Unlike the Parser's chooser.js -- which reloads the page with ?style=<x>   */
/* so the CGI re-highlights server-side -- this chooser switches style        */
/* entirely in the browser. It works because the highlighter emits identical  */
/* rx-* token markup for every style; only the outer                          */
/* <div class="highlight-rexx-<style>"> and the linked stylesheet differ.     */
/* Switching therefore reduces to (a) relabelling that outer div on every     */
/* highlighted block, and (b) activating the chosen style's stylesheet.       */
/*                                                                            */
/* Stylesheets are lazy-loaded: every rexx-<style>.css link but the default   */
/* ships with media="not all", so the browser does not fetch it until the     */
/* reader picks that style. Once fetched it stays in the browser cache.       */
/*                                                                            */
/******************************************************************************/

(function () {
  "use strict";

  document.addEventListener("DOMContentLoaded", function () {
    var chooser = document.getElementById("rexx-style-chooser");
    if (!chooser) return;

    /* The chooser only means anything if the page actually has highlighted    */
    /* Rexx blocks to restyle. Without the Parser (or on a page with no code   */
    /* at all) there are none, so the bar ships hidden and we reveal it here   */
    /* only when there is something to act on. Revealing (rather than hiding)  */
    /* avoids a flash of an empty control on code-less pages.                  */
    var hasBlocks = document.querySelector('[class*="highlight-rexx-"]') !== null;
    if (!hasBlocks) return;

    var bar = chooser.closest(".code-style-bar");
    if (bar) bar.hidden = false;

    /* Activate a lazily-linked stylesheet by clearing its media guard.       */
    /* The <link> carries data-rexx-style="<name>"; flipping media to "all"   */
    /* is what triggers the actual network fetch (once; cached thereafter).   */
    function activateSheet(style) {
      var link = document.querySelector(
        'link[data-rexx-style="' + style + '"]'
      );
      if (link && link.media !== "all") link.media = "all";
    }

    /* Relabel the outer div on every free block on the page. Blocks the      */
    /* author pinned to a style (marked data-rexx-style-locked by the          */
    /* highlighter) are left untouched, so their colours stay put.             */
    function relabel(style) {
      var blocks = document.querySelectorAll(
        '[class*="highlight-rexx-"]:not([data-rexx-style-locked])'
      );
      for (var i = 0; i < blocks.length; i++) {
        blocks[i].className = blocks[i].className.replace(
          /highlight-rexx-[A-Za-z0-9._-]+/g,
          "highlight-rexx-" + style
        );
      }
    }

    function apply(style) {
      activateSheet(style);
      relabel(style);
    }

    /* Persist the choice so it survives reloads and navigation, and reapply   */
    /* it on load. Reapplying on every load is also what keeps a reload         */
    /* deterministic: the server always ships the default (dark), so without    */
    /* this the browser could keep showing a previously-activated sheet.        */
    var STORAGE_KEY = "rexxhttp.codeStyle";

    function savedStyle() {
      try {
        return window.localStorage.getItem(STORAGE_KEY);
      } catch (e) {
        return null; /* storage disabled (private mode, etc.) — no persistence */
      }
    }

    function saveStyle(style) {
      try {
        window.localStorage.setItem(STORAGE_KEY, style);
      } catch (e) {
        /* ignore: persistence is best-effort */
      }
    }

    chooser.addEventListener("change", function () {
      saveStyle(chooser.value);
      apply(chooser.value);
    });

    /* Activate the stylesheets that author-locked blocks depend on. These      */
    /* blocks keep their own highlight-rexx-<style> class, but that class only   */
    /* paints if the matching (lazily-linked) sheet is active. The dropdown      */
    /* never selects these styles, so nothing else would switch them on.         */
    function activateLockedSheets() {
      var locked = document.querySelectorAll("[data-rexx-style-locked]");
      for (var i = 0; i < locked.length; i++) {
        var m = locked[i].className.match(/highlight-rexx-([A-Za-z0-9._-]+)/);
        if (m) activateSheet(m[1]);
      }
    }

    /* On load, honour a previously chosen style; otherwise use the default     */
    /* the chooser already shows. Either way we apply explicitly so the page    */
    /* reflects a known state rather than whatever the cache left active.       */
    var initial = savedStyle();
    if (initial === null || !chooser.querySelector('option[value="' + initial + '"]')) {
      initial = chooser.value;
    }
    chooser.value = initial;
    apply(initial);
    activateLockedSheets();
  });
})();
