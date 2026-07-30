RexxHTTP — stylesheets
======================

Two families of stylesheet live here, and they come from different places.

The site's own sheet
--------------------

- [`rexxhttp.css`](rexxhttp.css) — everything the pages of this site look
  like: the palette, the layout wrapper, the header and footer, the cards, the
  code-style bar. It is linked by
  [the page factory](../bin/HTML.Page.cls) into every page, and it is the one
  to edit if you want the site to look like something else.

The highlighting sheets
-----------------------

The other twenty-five files are named `rexx-<style>.css` — `rexx-dark.css`,
`rexx-tokio-night.css`, `rexx-vim-light-morning.css` and so on. They are not
part of RexxHTTP: they ship with
[the Rexx Parser](https://rexx.epbcn.com/rexx-parser/) and they colour the
`rx-*` token markup its highlighter emits. `dark` is the default.

They are worth a note because **nothing enumerates them**. The page factory
does not carry a list of style names, and neither does the chooser in the page
header: both are built at request time from the `rexx-*.css` files actually
present in this directory. Adding a style is therefore a matter of dropping a
file in here — it appears in the `<link>` block and in the chooser's
`<option>` list on the next request, with no source to edit and no chance of
the two lists drifting apart. Removing one works the same way.

Only the default sheet is fetched eagerly. The rest are linked with
`media="not all"` so the browser leaves them alone until a reader picks that
style; see [`../js/style-chooser.js`](../js/style-chooser.js) for the other
half of that arrangement.

See [How This Site Works](../architecture.md) for how the pieces fit together,
and [the top-level readme](../readme.md) for an overview of the package.
