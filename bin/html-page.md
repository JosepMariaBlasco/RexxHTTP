The page factory: HTML.Page.cls
===============================

The [`HTML.Page.cls`](HTML.Page.cls) class is provided as an example. It shows
how a rexxlet can serve a page with the RexxHTTP look — the header, the footer
and the stylesheet link — without repeating that chrome in every one.

How to use it from a rexxlet
----------------------------

To load the class into a servlet, use

```rexx
::Requires "HTML.Page.cls"
```

Ways to use the page factory
----------------------------

### Explicit body

```rexx
myPage = .HTML.Page~new("My title")     -- Creates the page
myPage~body("<p>Hello</p>")             -- Sets the body
myPage~done                             -- Emits the page contents
```

### Explicit body, chained

```rexx
.HTML.Page~new("My title")~body("<p>Hello</p>")~done
```

### Without passing a body

When there is no explicit call to the `body` method, the body is taken from the
rexxlet's own `::Resource BODY`. The rexxlet just declares:

```rexx
::Resource BODY
  <p>Hello</p>
::END
```

### Placeholder substitution

The `done` method accepts an optional array of placeholder substitutions. Every
substitution is a two-element array of the form `(key, value)`. The elements of
the substitution array are inspected in order, and the body is transformed by
`body~changeStr(key, value)` for each.

```rexx
.HTML.Page~new("Testing substitutions")~done(    -
   ("%something%", "placeholder substitutions"),  -
   ("%name%",      "Josep Maria Blasco")          -
 )

::Resource BODY
  <h1>A header about %something%</h1>
  <p>Hello, %name%!</p>
::END
```

A note on the title
-------------------

The string you pass to `new` is the page's own name. The factory brands it for
you: it appends ` — RexxHTTP` unless the name already ends in `RexxHTTP`, so
every page reads *its own name first, the site name last*, and the home page —
whose name simply *is* `RexxHTTP` — stays bare. You never write the suffix
yourself.
