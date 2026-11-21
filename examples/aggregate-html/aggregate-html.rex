.response~content_type = 'text/html; charset=utf-8'

Say '<!DOCTYPE html>'
Say '<html lang="en">'
Say '  <head>'
Say "    <title>Fetching and merging JSON from the web, returning HTML</title>"
Say '  </head>'
Say '  <body>'
Say '    <h1>Two posts, fetched and merged</h1>'
Say '    <p>This rexxlet fetches two sample posts from the public'
Say '       <a href="https://jsonplaceholder.typicode.com/">JSONPlaceholder</a>'
Say '       API, parses their JSON, and shows them below. The placeholder text'
Say '       is theirs &mdash; what this example demonstrates is a rexxlet reaching'
Say '       out to the network and composing the results.</p>'

Base = "https://jsonplaceholder.typicode.com/posts/"

Do id = 1 To 2
  post = FetchJSON(Base || id)
  If post == .nil Then
    Say '    <p>Could not load post 'id'.</p>'
  Else Do
    Say '    <article>'
    Say '      <h2>#'.response~encodeHTML(post["id"])' &mdash; '.response~encodeHTML(post["title"])'</h2>'
    Say '      <p>'.response~encodeHTML(post["body"])'</p>'
    Say '    </article>'
  End
End

Say '    <p>'
Say '      <small><a href="../">⬅️ Back to the examples.</a></small>'
Say '    </p>'
Say '  </body>'
Say '</html>'
Exit

-- Fetch a URL and parse the JSON body into a Rexx object.
-- Returns .nil if the download fails or the body is not valid JSON.
-- Note: this blocks the CGI process until curl returns, so we keep it
-- on a short leash -- --connect-timeout caps the connect phase at 5s,
-- and --max-time caps the whole transfer at 15s, so a dead remote host
-- cannot hang the request. -f makes curl return a non-zero RC on HTTP
-- >= 400 instead of handing back the error page as if it were the body.
-- curl ships with Windows 10/11, macOS and most Linux; wget does not.
FetchJSON: Procedure
  Use Strict Arg url

  -- Keep the probe silent in Apache's error.log when curl is absent. Two
  -- INDEPENDENT channels would otherwise write there, so both are muted:
  --   * the interpreter's trace: a missing binary is a FAILURE, which the
  --     default Trace Normal echoes. Trace("Off") silences it; Trace(setting)
  --     pushes the new setting and returns the previous one, restored below.
  --   * the child's stderr (the shell's "curl: not found"): Error Stem
  --     captures it instead of letting it flow through to the server log.
  -- Neither subsumes the other. The .nil return below already handles curl
  -- being absent or the fetch failing.
  savedTrace = Trace("Off")
  Do
    Address Command "curl -sf --connect-timeout 5 --max-time 15" url With Output Stem lines. Error Stem discard.
  Finally
    Call Trace savedTrace
  End
  If RC \= 0 Then Return .nil

  text = ""
  Do i = 1 To lines.0
    If i > 1 Then text = text || "0a"x
    text = text || lines.i
  End

  -- Not JSON after all? Then there is nothing to aggregate.
  Do
    Return .json~fromJson(text)
  Catch Syntax
    Return .nil
  End

::Requires "json.cls"
