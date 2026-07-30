RexxHTTP — client-side scripts
==============================

One file, and the site works without it.

- [`style-chooser.js`](style-chooser.js) — the dropdown in the page header that
  restyles every highlighted Rexx block on the page.

How it works, and why it is worth a look
----------------------------------------

The highlighter emits the same `rx-*` token markup whatever style you ask for;
only the wrapper `<div class="highlight-rexx-<style>">` and the linked
stylesheet differ. Switching style therefore does not need the server: it
reduces to relabelling that wrapper on each block and activating the chosen
sheet, both of which the browser can do on its own. The chosen style is
remembered locally, so it survives from page to page.

The script is [the Rexx Parser](https://rexx.epbcn.com/rexx-parser/)'s own
chooser rather than a local one: it lives in the Parser's `js/`, and packaging
refreshes the copy kept here from there, exactly as it refreshes the
stylesheets. Edit it in the Parser, not in this directory. There used to be two
choosers — this one, restyling in the browser, and the Parser's, which reloaded
the page with `?style=<name>` so the CGI could re-highlight server-side.
Version 0.6 merged them into the single file you see here.

The browser-side switch survived the merge, and with it the bargain it strikes:
one request and one round trip less than a reload, at the price of a brief
flash of the default style on a slow connection, before the script runs. What
the merge added is the URL. Reaching a page as `?style=<name>` opens it in that
style, and choosing from the dropdown writes the name back into the address bar
through `replaceState`, so the page is relabelled rather than fetched again.
The parameter is read by the script and not by the server, so the page itself
still arrives rendered in the default style either way. On load the URL
outranks the remembered preference, which outranks the page default; a style
named in a URL is deliberately not remembered, since a link somebody sent you
should not quietly replace the style you chose for yourself. A name the page
does not offer is ignored, wherever it came from.

Two details make it behave when there is nothing to do. The style bar ships
hidden and the script reveals it only after finding highlighted blocks on the
page, so a page with no code — or a site with no Parser installed — shows no
empty control. And every stylesheet but the default is linked with
`media="not all"`, so the browser fetches a style sheet the first time somebody
actually chooses it, and not before.

One part of the script does nothing here. It wires a print button to a
server-rendered PDF, carrying the live style in the URL so the PDF comes back
in the colours on screen. That is the Parser's arrangement; this site emits no
such button and serves no such PDF, so the code sits idle.

See [`../css/readme.md`](../css/readme.md) for the sheets this script switches
between, [How This Site Works](../architecture.md) for how the pieces fit
together, and [the top-level readme](../readme.md) for an overview.
