/******************************************************************************/
/*                                                                            */
/* HTTP.Request.cls - The HTTP request class                                  */
/* =========================================                                  */
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
/* 20061102    0.1  First version                                             */
/* 20170301    0.2  Drop support for mod_rexx, OS/2, IIS, rsp compilers       */
/*                  Change the way request~message works -- see 'unknown'.    */
/*                  By default, it looks in the environment variable pool.    */
/* 20260611    1.0  Global refactor, switch to Apache license                 */
/* 20260615         Add decoding methods                                      */
/*                                                                            */
/******************************************************************************/

.environment~HTTP.Request = .HTTP.Request

::Class HTTP.Request Public

--------------------------------------------------------------------------------
-- INIT                                                                       --
--------------------------------------------------------------------------------

::Method init

  Expose http env envvars args_processed cookies_processed,
    rexxletFilename filename script_filename,
    content_length content_type,
    path_info path_translated,
    post_string query_string,
    request_method request_uri request_url uri arg_violation,
    action_request standard_request,
    action_document,
    urlbase base

  -- A third redirect level = three chained Actions: unsupported topology.
  If Env("REDIRECT_REDIRECT_REDIRECT_REXXHTTP_BASE") \== "" Then
    Raise syntax 98.900 array -
      ("rawResourcePath: unsupported Action chain (three redirect levels)")

  -- Two redirect levels? -- A rexxlet used as an Action
  -- One redirect level?  -- A standard rexxlet
  action_request   = Env("REDIRECT_REDIRECT_REXXHTTP_BASE") \== ""
  standard_request = \ action_request

  Select
    When standard_request Then Do
      urlbase = Env("REDIRECT_REXXHTTP_URLBASE")
      base    = Env("REDIRECT_REXXHTTP_BASE")
    End
    When action_request   Then Do
      urlbase = Env("REDIRECT_REDIRECT_REXXHTTP_URLBASE")
      base    = Env("REDIRECT_REDIRECT_REXXHTTP_BASE")
    End
  End

  -- Separator: "/" for unix, "\" for windows
  sep = .File~separator

  -- The HTTP_ pool and the general environment pool, kept separate

  http                  = .directory~new
  envvars               = .directory~new

  -- Retrieve environment variables

  content_length        = Env(content_length)
  content_type          = Env(content_type  )
  request_method        = Env(request_method)

  -- Variables PATH_INFO, PATH_TRANSLATED, POST_STRING, QUERY_STRING,
  -- SCRIPT_NAME have to be calculated manually

  path                  = Env(path_translated)
  query_string          = Env(query_string   )
  request_uri           = Env(request_uri    )

  If .File~separator == "\" Then
    path                = path~translate("\","/")

  args_processed        = .false
  cookies_processed     = .false
  arg_violation         = ""

  -- Determine rexxlet file from PATH_TRANSLATED, adjust FILENAME, and
  -- set current directory to point to the rexxlet file.

  rexxletFilename = ""
  If SysIsFile(path) Then Do
    rexxletFilename = path
    path_info = ""
    End
  Else Do
    pos = path~pos(sep)
    Do Forever
      pos = path~pos(sep,pos+1)
      If pos = 0 Then Leave
      If SysIsFile(path~left(pos-1)) Then Do
        rexxletFilename = path~left(pos-1)
        path_info = path~substr(pos)~translate("/",sep)
        Leave
      End
    End
  End

  -- SCRIPT_FILENAME is the disk path of the PROCESSOR: the rexlet Apache
  -- resolved. RexxHTTP.rex reads it as the callee it Calls, and ~script_name
  -- maps it back to URL space -- it is the execution/processor axis and must
  -- stay the rexlet.
  script_filename = rexxletFilename

  -- FILENAME / PATH_TRANSLATED are the disk path of the DOCUMENT the client
  -- asked for -- the disk twin of REQUEST_URL. Nothing executes them (the
  -- callee is script_filename), so they name the document. One hop: requested
  -- == processor, so the rexlet (final value here). Two hops: reassigned to the
  -- document after the Action cut below.
  filename = rexxletFilename
  path_translated = rexxletFilename
  directory = rexxletFilename~left(rexxletFilename~lastpos(sep))

  Call directory directory

  -- Build REQUEST_URL (the self-referential URL: the client's own URL with
  -- PATH_INFO and query string peeled off). This is NOT the CGI SCRIPT_NAME:
  -- that one is served by the ~script_name method, reconstructed from
  -- path_translated. This value was historically named script_name, hence the
  -- "SCRIPT_NAME" wording that survives in the length-clamp note below.

  requri = self~decodeForm(request_uri)
  -- REQUEST_URL (the self-referential URL: the client's own URL, PATH_INFO and
  -- query string peeled off) is built BELOW, after the Action document/tail cut
  -- has resolved path_info to its final document-axis, tail-only value. It must
  -- read that doctored path_info, not the raw handler-axis walk above: the raw
  -- value fuses processor+document under an Action (PATH_INFO longer than
  -- REQUEST_URI, subtraction negative, request_url empties out), whereas the
  -- doctored path_info is always a genuine suffix of REQUEST_URI, in one hop and
  -- in two. See the Action cut and the request_url build that follows it.

  If requri~pos("?") == 0 Then uri = requri
  Else uri = requri~left(requri~pos("?")-1)

  -- Action document/tail cut. For a rexlet used as an Action (two hops) the
  -- handler-axis walk near the top left path_info holding the whole client
  -- request (document + tail fused) -- Apache's PATH_INFO smuggling. Re-run the
  -- same SysIsFile walk on the document axis (rawResourcePath) to split the
  -- resolved document from its trailing path, and OVERWRITE path_info with the
  -- tail only -- "what you put after the resource you named". This happens
  -- AFTER request_url read the raw path_info above, so request_url keeps its
  -- established value while the path_info attribute ends up tail-only. Computed
  -- here, once, like everything else: CGI has no persistent state to make a
  -- lazy cache meaningful. action_document is kept for reuse (path_translated
  -- as document, a later round). Standard rexlets skip this: their handler axis
  -- and document axis coincide, so the raw path_info is already tail-only.
  action_document = ""
  If action_request Then Do
    reqfile = self~rawResourcePath
    action_document = reqfile
    path_info       = ""
    If \SysIsFile(reqfile) Then Do
      pos = reqfile~pos(sep)
      Do Forever
        pos = reqfile~pos(sep, pos + 1)
        If pos = 0 Then Leave
        If SysIsFile(reqfile~left(pos - 1)) Then Do
          action_document = reqfile~left(pos - 1)
          path_info       = reqfile~substr(pos)~translate("/", sep)
          Leave
        End
      End
    End
  End

  -- FILENAME / PATH_TRANSLATED for an Action (two hops): the document on disk.
  -- The callee is script_filename (the rexlet), so both may name the document.
  -- action_document holds the requested resource, resolved via rawResourcePath
  -- (REQUEST_URI + BASE/URLBASE) -- the honest, Alias-aware disk path. When it
  -- is a regular file it IS the document (target.mtx, any /x/y tail already
  -- split off). When it is a DIRECTORY it can only be a DirectoryIndex request
  -- (we never serve directories), so Apache has already resolved and appended
  -- the index basename to the tail of the raw PATH_TRANSLATED; graft that
  -- basename onto the directory to name the index file actually served
  -- (.../sub/ + index.mtx). One hop leaves action_document empty and both keep
  -- their rexlet value.
  If action_document \== "" Then Do
    If SysIsFile(action_document) Then
      filename = action_document
    Else
      filename = action_document || path~substr(path~lastpos(sep) + 1)
    path_translated = filename
  End

  -- REQUEST_URL: the self-referential URL -- the client's own URL with its
  -- extra PATH_INFO and query string peeled off, in ONE hop and in TWO. Built
  -- here, after the Action cut, because path_info is now the document-axis,
  -- tail-only value: a genuine suffix of REQUEST_URI in every cell of the
  -- matrix (docroot/Alias x rexlet/DirectoryIndex x one/two hops x with/without
  -- extra path). Reading the RAW handler-axis path_info here instead would fuse
  -- processor+document under an Action, make PATH_INFO longer than REQUEST_URI,
  -- drive the length negative and empty request_url out (the two-hop bug). With
  -- the doctored suffix the subtraction is always non-negative; the Max(0,...)
  -- guard stays only as a belt-and-braces against a decode length mismatch.
  pathinfolen = self~decodeForm(path_info)~length
  querylen = self~decodeForm(query_string)~length
  If querylen > 0 Then querylen = querylen + 1
  request_url = requri~left(Max(0, requri~length - pathinfolen - querylen))

  -- Delay processing until Arg() has been called

  post_string = ""

  Return

--------------------------------------------------------------------------------
-- VALIDATE                                                                    --
--   Force eager parsing of the request arguments and apply the configured     --
--   argument policy. Called by the processor BEFORE the rexxlet runs, so a    --
--   policy violation can be reported (400/500) without ceding control.        --
--   Returns "" if the request is acceptable, or a "code:detail" string:       --
--     novalue:<token>    a parameter without "="                              --
--     noname:<token>     a parameter with an empty name ("=value")            --
--     duplicate:<name>   a repeated name (caseless)                           --
--     digitname:<name>   a name beginning with a digit                        --
--     badpolicy:<value>  REXXHTTP_ARGPOLICY set to an unknown value           --
--   The processor renders 400 for the first four, 500 for badpolicy.          --
--------------------------------------------------------------------------------

::Method validate public
  Expose arg_violation

  -- Argument policy. Only "strict" is recognised in 1.0; the env var is
  -- already read (caseless, with REDIRECT_ fallback via the message
  -- mechanism) so that .htaccess can configure it and 1.1 only needs to
  -- add values to the enum. Absent => strict. Unknown => config error.
  policy = self~REXXHTTP_ARGPOLICY
  If policy == "" Then policy = "strict"
  If policy~upper \== "STRICT" Then Return "badpolicy:"policy

  self~process_args        -- eager parse + strict validation
  Return arg_violation

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
-- P R I V A T E   M E T H O D S                                              --
--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

::Method process_args private
  Expose args nargs args_processed request_method post_string arg_violation

  If args_processed Then Return

  -- Read the POST body eagerly (see ref-decisiones, v6): the old lazy
  -- parsing existed only because mod_rexx's wwwGetArgs committed the
  -- response. With mod_rexx gone, reading stdin does not commit stdout,
  -- so we read and validate up front, before the rexxlet runs.
  If self~method == "POST" Then post_string = CharIn(,,self~content_length)

  args = .stem~new

  If self~request_method = "GET" Then query = self~query_string
  Else                                query = post_string

  args[]  = ""
  nargs   = 0
  arg_violation = ""

  -- Split on "&" FIRST, then analyse each token in isolation, so an
  -- "&" can never be swallowed into a name (the old single-Parse
  -- pattern mis-parsed "debug&x=1" as name="debug&x"). Strict policy:
  -- every token must be name=value with a non-empty, unique (caseless)
  -- name that does not begin with a digit (the Rexx symbol convention;
  -- a numeric name would be unreachable through the arg method anyway).
  -- Empty tokens (&&, trailing &) are skipped, not rejected.
  rest = query
  i = 0
  Do While rest \== ""
    Parse var rest token"&"rest
    If token == "" Then Iterate            -- && or trailing &: ignore

    If token~pos("=") == 0 Then Do
      arg_violation = "novalue:"token       -- parameter without "="
      Leave
    End

    Parse var token name"="value
    -- Decode the NAME with the same decodeForm as the value (v11): a query
    -- string is application/x-www-form-urlencoded, where BOTH sides of
    -- each pair are percent-encoded and "+" means space. Decoding only
    -- the value was a parity bug: arg("user name") could not find a
    -- field sent as user+name. Validate the DECODED name, since that is
    -- what the rexxlet sees and keys on.
    name = self~decodeForm(name)
    If name == "" Then Do
      arg_violation = "noname:"token         -- "=value", empty name
      Leave
    End

    If name~left(1)~datatype("W") Then Do
      arg_violation = "digitname:"name       -- name beginning with a digit
      Leave
    End

    key = name~upper                         -- caseless identity (Rexx-style)
    If args~hasindex(key) Then Do
      arg_violation = "duplicate:"name        -- repeated name (caseless)
      Leave
    End

    i = i + 1
    args[i,"NAME"]  = name                    -- decoded name (v11), as the rexxlet sees it
    args[i,"VALUE"] = self~decodeForm(value)
    args[key]       = i                        -- search key is uppercased
    nargs           = i
  End

  args_processed = .true

  Return

--------------------------------------------------------------------------------

::Method process_cookies private
  Expose http cookies ncookies cookies_processed

  If cookies_processed Then Return

  cookies = .stem~new

  cookieline = self~http_cookie

  cookies[]  = ""
  ncookies   = 0

  If cookieline == .nil | cookieline == "" Then Do
    cookies_processed = .true
    Return
  End

  -- RFC 6265: the Cookie header is "name=value; name=value": split FIRST,
  -- decode each piece AFTER, so that an encoded "%3B" in a value can never
  -- act as a separator. The space that follows each ";" is stripped from
  -- the name. Decoding is percent-only: the "+" convention belongs to
  -- form-urlencoded data (see decodeForm), not to cookies.
  i = 0
  Do While cookieline \== ""
    Parse var cookieline pair";"cookieline
    If pair~strip == "" Then Iterate
    Parse var pair name"="value
    name  = self~decodeURIComponent(name~strip)
    value = self~decodeURIComponent(value)
    i = i + 1
    cookies[i,"NAME"]  = name
    cookies[i,"VALUE"] = value
    -- First-wins by name (v11): if two cookies share a name, the
    -- browser sends the most specific path first, and established
    -- server practice keeps the first. Positional cookie(n) still
    -- sees them all; only the by-name lookup is pinned to the first.
    -- (Lookup stays case-sensitive: no upper of the key, as in v10.)
    If \cookies~hasindex(name) Then cookies[name] = i
    ncookies           = i
  End

  cookies_processed = .true

  Return

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
-- P U B L I C   M E T H O D S                                                --
--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

--------------------------------------------------------------------------------
-- "[]"                                                                       --
--------------------------------------------------------------------------------

::Method "[]"

  Use Strict Arg entryname

  name = entryname~request("STRING")
  If name == .nil Then Raise syntax 93.914 array (entryname)

  name = Upper(name)~translate("_","-")

  -- Bracket access always goes to the environment pool, never to a
  -- like-named method: [] is the raw-variable door, ~name is the
  -- library face. (A name reaching a method is the job of ~name, which
  -- the language already resolves method-first.)
  Forward Array (name, .array~new) Message (unknown)

--------------------------------------------------------------------------------
-- ARG                                                                        --
--                                                                            --
--   Syntax:    (n is an integer, s a string                                  --
--     arg()                  --> Number of arguments                         --
--     arg(n[,Value])         --> value for nth argument                      --
--     arg(s[,Value])         --> value for argname=s, or ""                  --
--     arg(s,Exists)          --> If there is an arg named s then 1 else 0    --
--                            Similarly with Omitted                          --
--     arg(n,Name)            --> name of nth arg                             --
--     arg(n,Value)           --> value of nth arg                            --
--------------------------------------------------------------------------------

::Method arg
  Expose args nargs args_processed

  If \args_processed Then self~process_args

  If Arg() = 0  Then Return nargs

  If Arg(1,'o') Then Raise syntax 93.903 array (1)

  If Arg() > 2  Then Raise syntax 93.902 array (2)

  n = Arg(1)~request("STRING")
  If n == .nil Then Raise syntax 93.916 array (1,Arg(1))

  If Arg(2,'o') Then option = "V"
  Else Do
    option = Arg(2)~request("STRING")
    If option == .nil Then Raise syntax 93.916 array (2,Arg(2))
    option = option~translate~strip~left(1)
    If option = "" Then option = "V"
    If "NVEO"~pos(option) == 0 Then
      Raise syntax 93.914 array (2,"Name Value Exists Omitted",option)
  End

  If n~datatype("w"), n > 0 Then Do
    If n > nargs Then Do
      If      option == "E" Then Return .false
      Else If option == "O" Then Return .true
      Else                       Return ""
    End
    If option == "E" Then Return .true
    If option == "O" Then Return .false
    If option == "V" Then Return args[n,"VALUE"]
    If option == "N" Then Return args[n,"NAME"]
  End

  -- Named lookup is caseless (Rexx-style): names are indexed uppercased
  -- in process_args, so the search key must be uppercased too.
  key = n~upper
  If option == "E" Then Return args[key] \== ""
  If option == "O" Then Return args[key]  == ""
  If option == "V" Then
    If args[key] = "" Then Return ""
    Else Return args[args[key],"VALUE"]
  If option == "N" Then
    If args[key] = "" Then Return ""
    Else Return args[args[key],"NAME"]

--------------------------------------------------------------------------------
-- CONTENT_LENGTH                                                             --
--------------------------------------------------------------------------------

::Attribute content_length Get

--------------------------------------------------------------------------------
-- CONTENT_TYPE                                                               --
--------------------------------------------------------------------------------

::Attribute content_type Get

--------------------------------------------------------------------------------
-- COOKIE                                                                     --
--                                                                            --
--   Syntax:    (n is an integer, s a string                                  --
--     cookie()               --> Number of cookies                           --
--     cookie(n[,Value])      --> value of nth cookie                         --
--     cookie(s[,Value])      --> value for cookiename=s, or ""               --
--     cookie(s,Exists)       --> If there is a cookie named s then 1 else 0  --
--                            Similarly with Omitted                          --
--     cookie(n,Name)         --> name of nth cookie                          --
--     cookie(n,Value)        --> value of nth arg                            --
--------------------------------------------------------------------------------

::Method cookie
  Expose cookies ncookies cookies_processed

  If \cookies_processed Then self~process_cookies

  If Arg() = 0  Then Return ncookies

  If Arg(1,'o') Then Raise syntax 93.903 array (1)

  If Arg() > 2  Then Raise syntax 93.902 array (2)

  n = Arg(1)~request("STRING")
  If n == .nil Then Raise syntax 93.916 array (1,Arg(1))

  If Arg(2,'o') Then option = "V"
  Else Do
    option = Arg(2)~request("STRING")
    If option == .nil Then Raise syntax 93.916 array (2,Arg(2))
    option = option~translate~strip
    Select
      When option == ""               Then option = "V"
      When "NAME"~abbrev(option,1)    Then option = "N"
      When "VALUE"~abbrev(option,1)   Then option = "V"
      When "EXISTS"~abbrev(option,1)  Then option = "E"
      When "OMITTED"~abbrev(option,1) Then option = "O"
      Otherwise Raise syntax 93.914 array ("NAME VALUE EXISTS OMITTED",option)
    End
  End

  If n~datatype("w"), n > 0 Then Do
    If n > ncookies Then Do
      If      option == "E" Then Return .false
      Else If option == "O" Then Return .true
      Else                       Return ""
    End
    If option == "E" Then Return .true
    If option == "O" Then Return .false
    If option == "V" Then Return cookies[n,"VALUE"]
    If option == "N" Then Return cookies[n,"NAME"]
  End

  If option == "E" Then Return cookies[n] \== ""
  If option == "O" Then Return cookies[n]  == ""
  If option == "V" Then
    If cookies[n] = "" Then Return ""
    Else Return cookies[cookies[n],"VALUE"]
  If option == "N" Then
    If cookies[n] = "" Then Return ""
    Else Return cookies[cookies[n],"NAME"]

--------------------------------------------------------------------------------
-- FILENAME                                                                   --
--   The disk path of the DOCUMENT the client requested -- the file on disk    --
--   of what was asked for. One hop: the rexlet (requested == processor). Two  --
--   hops: the document served through the processor (target.mtx), or the      --
--   resolved DirectoryIndex file for a requested directory. Always a genuine  --
--   file; any trailing PATH_INFO is excluded. Alias of PATH_TRANSLATED. The   --
--   processor that runs it is SCRIPT_FILENAME. Resolved at init.              --
--------------------------------------------------------------------------------

::Attribute filename Get

--------------------------------------------------------------------------------
-- HANDLER                                                                    --
--   When the rexxlet is being used as a handler, the name of that handler as --
--   specified in the Apache configuration (e.g., "markdown"); otherwise,     --
--   the method returns .Nil.                                                 --
--------------------------------------------------------------------------------

-- When a rexxlet is being used as a handler, there are _two_ levels of
-- redirect. We are interested in the last one.
::Method handler
  handler = Env("REDIRECT_REDIRECT_HANDLER")
  If handler = "" Then Return .Nil
  Return handler

--------------------------------------------------------------------------------
-- IS_ACTION                                                                  --
--   Returns .True when this rexxlet has been called as a handler using an    --
--   Action Apache directive, and .False otherwise                            --
--------------------------------------------------------------------------------

::Method is_action
  Return self~handler \== .Nil

--------------------------------------------------------------------------------
-- METHOD                                                                     --
--------------------------------------------------------------------------------

::Method method
  Forward message (request_method)

--------------------------------------------------------------------------------
-- PATH_INFO                                                                  --
--   The extra path following the resource the CLIENT named -- "what you put  --
--   after something". Set by init: for a standard rexlet it is the raw       --
--   handler-axis tail; for an Action it is the document-axis tail, split     --
--   from the resolved document (see the Action cut in init). A plain         --
--   attribute getter -- the value is fully resolved at construction.         --
--------------------------------------------------------------------------------

::Attribute path_info Get

--------------------------------------------------------------------------------
-- PATH_TRANSLATED                                                            --
--   The disk path of the DOCUMENT requested -- alias of FILENAME (both       --
--   assigned from the same resolution in init). One hop == SCRIPT_FILENAME;  --
--   two hops it is the document, not the processor. For the processor's disk --
--   path (the callee) use SCRIPT_FILENAME.                                   --
--------------------------------------------------------------------------------

::Attribute path_translated Get

--------------------------------------------------------------------------------
-- POST_STRING                                                                --
--------------------------------------------------------------------------------

::Attribute post_string Get

--------------------------------------------------------------------------------
-- QUERY_STRING                                                               --
--------------------------------------------------------------------------------

::Attribute query_string Get

--------------------------------------------------------------------------------
-- REQUEST_METHOD                                                             --
--   Alias: METHOD                                                            --
--------------------------------------------------------------------------------

::Method request_method
  Expose request_method
  Use Strict Arg
  Return request_method

--------------------------------------------------------------------------------
-- REQUEST_URI                                                                --
--   Alias: UNPARSEDURI                                                       --
--   This is calculated at INIT time                                          --
--------------------------------------------------------------------------------

::Attribute request_uri Get

--------------------------------------------------------------------------------
-- rawResourcePath (PRIVATE)                                                  --
--   The RAW, pre-resolution on-disk path of the resource the client asked    --
--   for -- an internal step in computing FILENAME, not a public accessor.    --
--   It reconstructs the path from the URL but does NOT resolve it against    --
--   disk: in the Action case it still carries any trailing PATH_INFO, and    --
--   for a directory request it names the directory, not the served index.    --
--   The init runs a SysIsFile walk over this value to split the resolved     --
--   document from its tail; the RESULT of that walk is FILENAME, which is     --
--   the openable, document-on-disk path callers actually want. So this is     --
--   deliberately not exposed: it can return a value readLines cannot open     --
--   (".../doc.mtx/x/y", ".../sub/"). Public code wanting the document reads   --
--   ~filename, which since the v79 disk-axis reorder always names the        --
--   document (script_filename names the PROCESSOR). Kept private, and named   --
--   for what it is (a raw resource path), to make that contract clear.        --
--                                                                            --
--   For a plain rexxlet (one redirect hop) the requested resource IS the     --
--   rexxlet, so this returns script_filename unchanged. For a rexlet used    --
--   as an Action (two hops, e.g. a .md served through the Markdown           --
--   renderer) the document lives elsewhere -- possibly under an Alias        --
--   outside the docroot -- and its path is reconstructed, deterministically  --
--   and without guessing against disk, from a pair the installer/operator    --
--   freezes in each <Directory>:                                             --
--     REXXHTTP_BASE     the zone's root ON DISK                              --
--     REXXHTTP_URLBASE  the zone's URL prefix; "*" means "no prefix"         --
--                       (docroot or a plain subdir), "/ext" means aliased.   --
--   Apache stacks a REDIRECT_ prefix per internal redirect, so the pair for  --
--   the RESOURCE sits at the DEEPEST populated level (see the design note    --
--   design-rexlet-as-action.md). The rule, once the deepest pair is read:    --
--     rel  = REQUEST_URI (query string stripped) with urlbase peeled off     --
--     file = base || rel                                                     --
--                                                                            --
--   One condition is a configuration error, reported as 500 via Raise:       --
--     - REXXHTTP_BASE present but REXXHTTP_URLBASE empty at the resource      --
--       level: the operator wrote the base but forgot the paired urlbase      --
--       ("*" is the docroot value; empty is never legitimate here). Because  --
--       Value() cannot tell an unset variable from one set to "", the "*"    --
--       sentinel is what makes this distinguishable at all.                  --
--------------------------------------------------------------------------------

::Method rawResourcePath Private
  Expose script_filename request_uri action_request urlbase base
  Use Strict Arg

  -- No anchor at any level: nothing to reconstruct from. Fall back to the
  -- processor's own file (the plain, pre-REXXHTTP_BASE behaviour).
  If base == "" Then Return script_filename

  -- A plain rexlet: the requested resource IS the rexlet.
  If \action_request Then Return script_filename

  -- Two hops (rexlet-as-Action). We need the full pair. An empty urlbase
  -- here is the operator's forgotten SetEnv (docroot legitimately carries
  -- the "*" sentinel, never "").
  If urlbase == "" Then
    Raise syntax 98.900 array -
      ("rawResourcePath: REXXHTTP_BASE set without a paired REXXHTTP_URLBASE")

  -- Clean original URL: REQUEST_URI without any query string.
  requri = request_uri
  If requri~pos("?") > 0 Then requri = requri~left(requri~pos("?") - 1)

  -- Peel the URL prefix off the front, unless it is the "*" sentinel
  -- (no prefix: docroot or plain subdir). Nested If, not a comma guard,
  -- to stay clear of the non-short-circuit "&" and the trailing-comma trap.
  rel = requri
  If urlbase \== "*" Then
    If requri~left(urlbase~length) == urlbase Then
      rel = requri~substr(urlbase~length + 1)

  Return base || rel


--------------------------------------------------------------------------------
-- REQUEST_URL                                                                --
--   The self-referential URL: the client's own URL with any PATH_INFO and    --
--   query string peeled off. Was named ~script_name until the CGI SCRIPT_NAME --
--   (RFC 3875, resolved resource) took over that name; this is the value the  --
--   two production clients (calendario, SQLForm) actually consumed -- a URL   --
--   to hang return links off, NOT the CGI processor path. Computed in init.   --
--------------------------------------------------------------------------------

::Attribute request_url Get

--------------------------------------------------------------------------------
-- SCRIPT_FILENAME                                                            --
--   The disk path of the PROCESSOR -- the rexlet Apache resolved and ran,    --
--   the disk twin of SCRIPT_NAME. This is the callee RexxHTTP.rex Calls. One --
--   hop: == FILENAME. Two hops: the rexlet, distinct from FILENAME/          --
--   PATH_TRANSLATED (the document). Resolved at init.                        --
--------------------------------------------------------------------------------

::Attribute script_filename Get

--------------------------------------------------------------------------------
-- SCRIPT_NAME                                                                --
--   The RFC 3875 SCRIPT_NAME: the URL-space path of the resource Apache      --
--   actually resolved and ran, NOT the URL the client typed. They differ    --
--   whenever Apache rewrites internally before reaching us:                  --
--     - DirectoryIndex: client asks "/test/", Apache resolves it to          --
--       "/test/index.rxl"; the RFC SCRIPT_NAME is "/test/index.rxl", but     --
--       ~request_url returns "/test/" (the self-referential URL, useful in   --
--       its own right, just not what CGI names SCRIPT_NAME).                 --
--     - plain rexlet (client names it): resolved == requested, so this       --
--       returns the same value ~request_url does, by an honest path.         --
--                                                                            --
--   This mirrors the reconstruction machinery of rawResourcePath. That       --
--   method goes URL->disk (peel urlbase off REQUEST_URI, prepend base);       --
--   here we take the resolved processor on disk (script_filename) and map     --
--   it back into URL space: strip the on-disk base prefix, prepend the URL    --
--   prefix. The REXXHTTP_BASE / REXXHTTP_URLBASE pair, and the                --
--   deepest-redirect-level rule for reading it, are exactly the same.         --
--                                                                            --
--   Where the pair is not configured (pre-REXXHTTP_BASE deployments) it      --
--   falls back to the stored request_url value, so nothing regresses.        --
--------------------------------------------------------------------------------

::Method script_name
  Expose request_url script_filename base urlbase
  Use Strict Arg

  sep = .File~separator

  -- No anchor configured: fall back to the stored request_url. This keeps
  -- pre-REXXHTTP_BASE deployments behaving exactly as before.
  If base == "" Then Return request_url

  -- The resolved PROCESSOR on disk (script_filename). On Windows it may carry
  -- native separators; normalise to "/" so the base-strip and the emitted
  -- URL are both in URL space.
  file = script_filename
  If sep == "\" Then Do
    file = file~translate("/", sep)
    base = base~translate("/", sep)
  End

  -- Strip the on-disk base prefix to get the resource path relative to the
  -- zone root, then map it into URL space by prepending the URL prefix
  -- ("*" is the no-prefix sentinel: docroot or a plain subdir).
  rel = file
  If file~left(base~length) == base Then
    rel = file~substr(base~length + 1)

  -- Ensure a single leading "/" between prefix and relative path.
  If rel~left(1) \== "/" Then rel = "/"rel

  If urlbase == "*" Then Return rel
  Return urlbase || rel

--------------------------------------------------------------------------------
-- SYSTEM_VERSION                                                             --
--   Returns the current system version string                                --
--------------------------------------------------------------------------------

::Method system_version
  Use Strict Arg
  Return "REXXHTTP/1.0 20260611"

--------------------------------------------------------------------------------
-- UNKNOWN                                                                    --
--------------------------------------------------------------------------------

::Method unknown
  Expose http envvars

  Use arg message, args
  If args~dimension(1) > 0 Then Raise syntax 93.902 array (0)

  If message~left(5) = "HTTP_"     Then Do
    If \http~hasindex(message) Then http[message] = Env(message)
    Return http[message]
  End

  If \envvars~hasindex(message) Then Do
    val = Env(message)
    If val = "" Then val = Env("REDIRECT_"message)
    envvars[message] = val
  End

  Return envvars[message]

--------------------------------------------------------------------------------
-- UNPARSEDURI                                                                --
--   Alias of : REQUEST_URI                                                   --
--------------------------------------------------------------------------------

::Method unparseduri
  Forward message (request_uri)

--------------------------------------------------------------------------------
-- URI                                                                        --
--   This is calculated at INIT time                                          --
--------------------------------------------------------------------------------

::Attribute uri Get

--------------------------------------------------------------------------------
-- RexxHTTP_URL                                                               --
--   URL of the RexxHTTP package, or "" if RexxHTTP is not reachable          --
--------------------------------------------------------------------------------

--------------------------------------------------------------------------------
-- RexxHTTP_DIR                                                               --
--   Filesystem directory of the RexxHTTP package -- no final "/"             --
--------------------------------------------------------------------------------

::Method RexxHTTP_DIR
  Expose base
  Return base

--------------------------------------------------------------------------------
-- RexxHTTP_URL                                                               --
--   URL of the RexxHTTP package, or "" if RexxHTTP is not reachable          --
--   When it is not "", it always ends with "/" (mod_dir convention)          --
--------------------------------------------------------------------------------

::Method RexxHTTP_URL
  Expose urlbase
  If urlbase == "" Then Return ""       -- unreachable: no pair configured
  If urlbase == "*" Then Return "/"     -- docroot: present, no prefix
  Return urlbase"/"                     -- subdir: "/rexxhttp" -> "/rexxhttp/"

--------------------------------------------------------------------------------
-- DOCUMENT_URI                                                               --
--   The URL-space path of the DOCUMENT Apache actually resolved and served,  --
--   carrying its URL prefix (e.g. "/mtx/target.mtx", "/ali/sub/index.mtx").  --
--   It is the disk->URL twin of ~filename, exactly as ~script_name is the    --
--   twin of ~script_filename: filename names the served document on disk,    --
--   document_uri names that same document in URL space.                      --
--                                                                            --
--   It therefore RESOLVES what ~uri leaves raw. ~uri is the client's typed   --
--   URL minus the query string, so it keeps any extra PATH_INFO tail and,    --
--   for a DirectoryIndex request, names the directory ("/mtx/sub/"). This    --
--   value instead follows filename: the extra tail is gone (the document is  --
--   named, not what came after it) and a DirectoryIndex is resolved to the   --
--   index actually served ("/mtx/sub/index.mtx"). Under an Action it is the  --
--   original document, not the processor -- script_name covers that axis.    --
--                                                                            --
--   Reconstructed with the same REXXHTTP_BASE / REXXHTTP_URLBASE pair, read  --
--   at the deepest redirect level, that script_name and rawResourcePath use: --
--   strip the on-disk base off filename to get the path relative to the zone --
--   root, then prepend the URL prefix ("*" is the no-prefix sentinel). Where --
--   the pair is not configured (pre-REXXHTTP_BASE deployments) it falls back --
--   to the stored ~uri, so nothing regresses.                               --
--------------------------------------------------------------------------------

::Method document_uri
  Expose uri filename base urlbase
  Use Strict Arg

  sep = .File~separator

  -- No anchor configured: fall back to the raw ~uri (client URL, query
  -- stripped). Keeps pre-REXXHTTP_BASE deployments behaving as before.
  If base == "" Then Return uri

  -- The served DOCUMENT on disk (filename). On Windows it may carry native
  -- separators; normalise to "/" so the base-strip and the emitted URL are
  -- both in URL space.
  file = filename
  If sep == "\" Then Do
    file = file~translate("/", sep)
    base = base~translate("/", sep)
  End

  -- Strip the on-disk base prefix to get the document path relative to the
  -- zone root, then map it into URL space by prepending the URL prefix
  -- ("*" is the no-prefix sentinel: docroot or a plain subdir).
  rel = file
  If file~left(base~length) == base Then
    rel = file~substr(base~length + 1)

  -- Ensure a single leading "/" between prefix and relative path.
  If rel~left(1) \== "/" Then rel = "/"rel

  If urlbase == "*" Then Return rel
  Return urlbase || rel

--------------------------------------------------------------------------------
-- DECODEURICOMPONENT -- Percent-decode a URL component (no "+" rule)         --
--------------------------------------------------------------------------------
--
-- %xx-decoding alone: "+" stays literal. This is the correct decode for a
-- URL component and for cookie values, where "+" is a plus, not a space.
-- Inverse of encodeURIComponent (HTTP.Response). Available as a class method
-- (.HTTP.Request~decodeURIComponent(s)) and an instance method; the body
-- lives once, on the class. process_cookies uses it internally.
--

::Method decodeURIComponent Class
  Use Strict Arg from
  to    = .mutablebuffer~new
  lfrom = from~length
  Do i = 1 To lfrom
    c = from~substr(i,1)
    If c == "%" , i+2 <= lfrom Then Do
      hex = from~substr(i+1,2)
      If hex~datatype("X") Then Do
        i = i + 2
        c = hex~x2c
      End
    End
    to~append(c)
  End
  Return to~string

::Method decodeURIComponent
  Use Strict Arg from
  Return .HTTP.Request~decodeURIComponent(from)

--------------------------------------------------------------------------------
-- DECODEFORM -- Decode application/x-www-form-urlencoded                     --
--------------------------------------------------------------------------------
--
-- %xx-decoding PLUS the "+"->space rule. This is the decode for form data:
-- a conforming form serialiser emits space as "+", and this accepts both
-- "+" and %20 as space. Inverse of encodeForm (HTTP.Response). Available as
-- a class method and an instance method; the body lives once, on the class.
-- init and process_args use it internally.
--

::Method decodeForm Class
  Use Strict Arg from
  to    = .mutablebuffer~new
  lfrom = from~length
  Do i = 1 To lfrom
    c = from~substr(i,1)
    If c == "+" Then c = " "
    If c == "%" , i+2 <= lfrom Then Do
      hex = from~substr(i+1,2)
      If hex~datatype("X") Then Do
        i = i + 2
        c = hex~x2c
      End
    End
    to~append(c)
  End
  Return to~string

::Method decodeForm
  Use Strict Arg from
  Return .HTTP.Request~decodeForm(from)

--------------------------------------------------------------------------------
-- Env: Return the value of an environment variable                           --
--------------------------------------------------------------------------------

::Routine Env
  Return Value(Arg(1),,"ENVIRONMENT")

