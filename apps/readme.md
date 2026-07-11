A sample page factory: page.cls
===============================

The <a href="page.cls">page.cls</a> class is provided as an example.
It shows how a rexxlet can serve a page with the RexxHTTP look
without repeating the header, the
footer or the stylesheet link in every one.

How to use it from a rexxlet
----------------------------

To load the class into a Servlet, use

```rexx
 .context~package~loadPackage( .request~RexxHTTP_dir"/apps/page.cls" )
```

Ways to use the page factory
----------------------------

### Explicit body

```rexx
  myPage = .Page~new("My title")     -- Creates the page
  myPage~body("<p>Hello</p>")        -- Sets the body
  myPage~done                        -- Emits the page contents
```

### Explicit body, chained

```rexx
 .Page~new("My title")~body("<p>Hello</p>")~done
```

### Without passing a body

When there is no explicit call to the `body` method,
the body is taken from the rexxlet's
own `::Resource BODY`. The rexxlet just declares:


```rexx
::Resource BODY
  <p>Hello</p>
::END
```

### Placeholder substitution

The `done` method accepts an optional array of placeholder
substitutions. Every substitution is a two-element array
of the form `(key, value)`. Elements of the substitution
array ara inspected in order, and the body is
substituted by `body~changeStr(key, value)`.

```rexx
.Page~new("Testing substitutions")~done(         -
   ("%something%", "placeholder substitutions"), -
   ("%name%","Josep Maria Blasco")               -
 )

::Resource BODY
  <h1>A header about %something%</h1>
  <p>Hello, %name%!</p>
::END
```