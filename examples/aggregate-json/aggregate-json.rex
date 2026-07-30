.response~content_type = "application/json; charset=utf-8"

-- This rexxlet fetches two sample posts from the public JSONPlaceholder
-- API, parses each one, and emits the two of them merged into a single
-- JSON array. It is the JSON-returning sibling of the aggregate-html
-- example: same fetch, same merge, but the result is served as JSON text
-- rather than rendered as a page. A client (a browser fetch, another
-- rexxlet, a command-line tool) can consume it directly.

Base = "https://jsonplaceholder.typicode.com/posts/"

posts = .Array~new

Do id = 1 To 2
  post = FetchJSON(Base || id)
  If post \== .nil Then posts~append(post)
End

Say .json~toJson(posts)
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
  Address Command "curl -sf --connect-timeout 5 --max-time 15" url With Output Stem lines. Error Stem discard.
  Call Trace savedTrace
  If RC \= 0 Then Return .nil

  text = ""
  Do i = 1 To lines.0
    If i > 1 Then text = text || "0a"x
    text = text || lines.i
  End

  Signal On Syntax Name BadJSON
  Return .json~fromJson(text)

BadJSON:
  Return .nil

::Requires "json.cls"
