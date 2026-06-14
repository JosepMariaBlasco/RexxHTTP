/******************************************************************************/
/*                                                                            */
/* HTTP.Cookie.cls - The RexxHTTP cookie class                                */
/* ===========================================                                */
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
/*                                                                            */
/******************************************************************************/

.environment~HTTP.Cookie = .HTTP.Cookie

::Class HTTP.Cookie Public

--------------------------------------------------------------------------------
-- INIT method                                                                --
--                                                                            --
-- INIT(name, value)                                                          --
--                                                                            --
-- name  must conform to RFC6265: ASCII non-control characters, none of the   --
--       separators ()<>@,;:\"/[]?={} space tab, and may not begin with "$".  --
--       A leading __Host- or __Secure- prefix is recognised and enforced at  --
--       makestring time (see CHECKPREFIX).                                   --
-- value any string. No encoding is performed here; the caller is responsible --
--       for percent-encoding if the value carries reserved characters.       --
--------------------------------------------------------------------------------

::Method init
  Expose name value path domain max_age secure httponly samesite cachedstring

  Use Strict Arg name, value = ""

  -- Validate the name against the RFC6265 token rules.
  self~validatename(name)

  -- Defaults: a session cookie (no Max-Age), not secure, not HttpOnly,
  -- no Path, no Domain, no SameSite emitted.
  path     = ""
  domain   = ""
  max_age  = -1          -- negative => session cookie, attribute omitted
  secure   = 0
  httponly = 0
  samesite = ""          -- "" => attribute omitted; else Strict/Lax/None

  -- Memoised Set-Cookie value. .nil => not yet computed (or invalidated by
  -- a setter). makestring populates it; any setter resets it to .nil.
  cachedstring = .nil

  Return

--------------------------------------------------------------------------------
-- VALIDATENAME                                                               --
-- Enforces the RFC6265 cookie-name token rules. Raises a syntax error        --
-- on the first violation.                                                    --
--------------------------------------------------------------------------------

::Method validatename Private
  Use Strict Arg n

  If n == "" Then Error("Cookie name may not be the null string")

  If n~left(1) == "$" Then
    Error("Cookie name may not begin with '$'")

  -- Separators forbidden by RFC6265, plus control chars and whitespace.
  -- The double-quote (22x) is one of them; built via x2c to keep the
  -- literal below unambiguous.
  separators = "()<>@,;:" || "22"x || "/[]?={}" || " " || "09"x
  Do i = 1 To n~length
    c = n~substr(i,1)
    If c~c2d < 32 | c~c2d == 127 Then
      Error("Cookie name contains a control character")
    If c~c2d > 127 Then
      Error("Cookie name contains a non-ASCII character")
    If separators~pos(c) > 0 Then
      Error("Cookie name contains the forbidden character '"c"'")
  End

  Return

--------------------------------------------------------------------------------
-- Simple attribute getters/setters                                           --
--------------------------------------------------------------------------------

::Method name
  Expose name
  Return name

::Method value
  Expose value
  Return value

::Method "value="
  Expose value cachedstring
  Use Strict Arg value
  cachedstring = .nil
  Return

::Method path
  Expose path
  Return path

::Method "path="
  Expose path cachedstring
  Use Strict Arg path
  cachedstring = .nil
  Return

::Method domain
  Expose domain
  Return domain

::Method "domain="
  Expose domain cachedstring
  Use Strict Arg domain
  cachedstring = .nil
  Return

--------------------------------------------------------------------------------
-- MAX_AGE / MAX_AGE=                                                         --
-- A whole number of seconds. Negative => session cookie (attribute omitted). --
-- Zero => the cookie is deleted by the user agent.                           --
--------------------------------------------------------------------------------

::Method max_age
  Expose max_age
  Return max_age

::Method "max_age="
  Expose max_age cachedstring
  Use Strict Arg seconds
  If \seconds~datatype("Whole") Then
    Error("Max-Age must be a whole number of seconds")
  max_age = seconds
  cachedstring = .nil
  Return

--------------------------------------------------------------------------------
-- SECURE / SECURE=                                                           --
--------------------------------------------------------------------------------

::Method secure
  Expose secure
  Return secure

::Method "secure="
  Expose secure cachedstring
  Use Strict Arg val
  If val \== 0, val \== 1 Then Error("Secure must be 0 or 1")
  secure = val
  cachedstring = .nil
  Return

--------------------------------------------------------------------------------
-- HTTPONLY / HTTPONLY=                                                       --
--------------------------------------------------------------------------------

::Method httponly
  Expose httponly
  Return httponly

::Method "httponly="
  Expose httponly cachedstring
  Use Strict Arg val
  If val \== 0, val \== 1 Then Error("HttpOnly must be 0 or 1")
  httponly = val
  cachedstring = .nil
  Return

--------------------------------------------------------------------------------
-- SAMESITE / SAMESITE=                                                       --
-- Accepts Strict, Lax, None (case-insensitive); stored canonicalised.        --
-- "" clears the attribute. The Secure-with-None rule is enforced at          --
-- makestring time, not here, so attributes may be set in any order.          --
--------------------------------------------------------------------------------

::Method samesite
  Expose samesite
  Return samesite

::Method "samesite="
  Expose samesite cachedstring
  Use Strict Arg val

  Select Case val~upper
    When ""       Then samesite = ""
    When "STRICT" Then samesite = "Strict"
    When "LAX"    Then samesite = "Lax"
    When "NONE"   Then samesite = "None"
    Otherwise          Error("SameSite must be Strict, Lax or None")
  End

  cachedstring = .nil

--------------------------------------------------------------------------------
-- CHECKCONSISTENCY (Private)                                                 --
-- Strict cross-attribute validation, run from makestring. Raises on the      --
-- first violation so a servlet never emits a Set-Cookie the browser would    --
-- silently discard.                                                          --
--------------------------------------------------------------------------------

::Method checkconsistency Private
  Expose name path domain secure samesite

  -- SameSite=None requires Secure (RFC6265bis; browsers reject otherwise).
  If samesite == "None", secure \== 1 Then
    Error("SameSite=None requires Secure")

  -- __Secure- prefix: must be Secure. Prefix match is case-insensitive,
  -- mirroring browser behaviour (__SeCuRe- is treated as __Secure-).
  If name~left(9)~upper == "__SECURE-" Then Do
    If secure \== 1 Then
      Error("__Secure- prefixed cookies require Secure")
  End

  -- __Host- prefix: must be Secure, Path=/, and no Domain.
  If name~left(7)~upper == "__HOST-" Then Do
    If secure \== 1 Then
      Error("__Host- prefixed cookies require Secure")
    If domain \== "" Then
      Error("__Host- prefixed cookies may not set Domain")
    If path \== "/" Then
      Error("__Host- prefixed cookies require Path=/")
  End

--------------------------------------------------------------------------------
-- MAKESTRING                                                                 --
-- Returns the value for a Set-Cookie header. Runs strict consistency checks  --
-- first. Attribute order follows common practice: name=value first, then     --
-- Max-Age, Domain, Path, SameSite, then the valueless flags Secure/HttpOnly. --
--------------------------------------------------------------------------------

::Method makestring
  Expose name value path domain max_age secure httponly samesite cachedstring

  -- Return the memoised value if nothing changed since it was computed.
  If cachedstring \== .nil Then Return cachedstring

  self~checkconsistency

  s = name"="value

  If max_age >= 0 Then    s ||= "; Max-Age="max_age

  If domain \== "" Then   s ||= "; Domain="domain

  If path \== "" Then     s ||= "; Path="path

  If samesite \== "" Then s ||= "; SameSite="samesite

  If secure == 1 Then     s ||= "; Secure"

  If httponly == 1 Then   s ||= "; HttpOnly"

  cachedstring = s

  Return s

--------------------------------------------------------------------------------
-- Error                                                                      --
--------------------------------------------------------------------------------
::Routine Error

  Raise syntax 93.900 array (Arg(1))