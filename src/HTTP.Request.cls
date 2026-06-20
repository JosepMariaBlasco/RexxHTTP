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
    rspfilename filename,
    content_length content_type,
    path_info path_translated,
    post_string query_string,
    request_method request_uri script_name uri arg_violation

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

  If sep == "\" Then
    path                = path~translate("\","/")

  args_processed        = .false
  cookies_processed     = .false
  arg_violation         = ""

  -- Determine rsp file from PATH_TRANSLATED, adjust FILENAME, and
  -- set current directory to point to the rsp file.

  rspfilename = ""
  If SysIsFile(path) Then Do
    rspfilename = path
    path_info = ""
    End
  Else Do
    pos = path~pos(sep)
    Do Forever
      pos = path~pos(sep,pos+1)
      If pos = 0 Then Leave
      If SysIsFile(path~left(pos-1)) Then Do
        rspfilename = path~left(pos-1)
        path_info = path~substr(pos)~translate("/",sep)
        Leave
      End
    End
  End

  filename = rspfilename
  path_translated = rspfilename
  directory = rspfilename~left(rspfilename~lastpos(sep))

  Call directory directory

  -- Build SCRIPT_NAME

  requri = self~decodeForm(request_uri)
  pathinfolen = self~decodeForm(self~path_info)~length
  querylen = self~decodeForm(query_string)~length
  If querylen > 0 Then querylen = querylen + 1
  script_name = requri~left(requri~length - pathinfolen - querylen)

  If requri~pos("?") == 0 Then uri = requri
  Else uri = requri~left(requri~pos("?")-1)

  -- Delay processing until Arg() has been called

  post_string = ""

  Return

--------------------------------------------------------------------------------
-- VALIDATE                                                                    --
--   Force eager parsing of the request arguments and apply the configured     --
--   argument policy. Called by the processor BEFORE the servlet runs, so a    --
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
  -- so we read and validate up front, before the servlet runs.
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
    -- what the servlet sees and keys on.
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
    args[i,"NAME"]  = name                    -- decoded name (v11), as the servlet sees it
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

::Method content_length
  Expose content_length
  Use Strict Arg
  Return content_length

--------------------------------------------------------------------------------
-- CONTENT_TYPE                                                               --
--------------------------------------------------------------------------------

::Method content_type
  Expose content_type
  Use Strict Arg
  Return content_type

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
--   NOTE: This returns the full path and filename to the servlet or rsp file.--
--------------------------------------------------------------------------------

::Method filename
  Expose filename
  Use Strict Arg
  Return filename

--------------------------------------------------------------------------------
-- METHOD                                                                     --
--------------------------------------------------------------------------------

::Method method
  Forward message (request_method)

--------------------------------------------------------------------------------
-- PATH_INFO                                                                  --
--------------------------------------------------------------------------------

::Method path_info
  Expose path_info
  Use Strict Arg
  Return path_info

--------------------------------------------------------------------------------
-- PATH_TRANSLATED                                                            --
--   NOTE: This returns the full path and filename to the servlet or rsp file.--
--------------------------------------------------------------------------------

::Method path_translated
  Expose path_translated
  Use Strict Arg
  Return path_translated

--------------------------------------------------------------------------------
-- POST_STRING                                                                --
--------------------------------------------------------------------------------

::Method post_string
  Expose post_string
  Use Strict Arg
  Return post_string

--------------------------------------------------------------------------------
-- QUERY_STRING                                                               --
--------------------------------------------------------------------------------

::Method query_string
  Expose query_string
  Use Strict Arg
  Return query_string

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

::Method request_uri
  Expose request_uri
  Use Strict Arg
  Return request_uri

--------------------------------------------------------------------------------
-- SCRIPT_NAME                                                                --
--------------------------------------------------------------------------------

::Method script_name
  Expose script_name
  Use Strict Arg
  Return script_name

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

::Method uri
  Expose uri
  Use Strict Arg
  Return uri

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

