RexxHTTP — tests
================

- [`http/`](http/) — [end-to-end integration tests](http/): a request goes through Apache
  to the processor and the response is verified. See
  [its readme](http/readme.md) for prerequisites and how to run them.
- [`framework/`](framework/) — the ooTest framework (the Rexx Language Association's
  official files, carried verbatim).

The quickest way to run the suite:

```
rexx tests/http/RunHTTPTests.rex
```

See [the top-level readme](../readme.md) for an overview of the project.
