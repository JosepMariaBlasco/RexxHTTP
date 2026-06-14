/******************************************************************************/
/*                                                                            */
/* HTTP.OutputStream.cls - A buffered output stream for HTTP responses        */
/* ===================================================================        */
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

.environment~HTTP.OutputStream = .HTTP.OutputStream

::Class HTTP.OutputStream SubClass Stream Public

--------------------------------------------------------------------------------
-- INIT                                                                       --
--------------------------------------------------------------------------------

::Method init

  Expose underlyingstream stream_name buffer state description opened datetime timestamp eol

  Parse Value Date("S") Time() With y +4 m +2 d time
  datetime  = m"-"Right(y,2)"-"d time
  timestamp = y"-"m"-"d time

  Use Strict Arg underlyingstream
  If Arg(1)~class \= .Stream Then
    Raise Syntax 93.948 array (1,"Stream")

  stream_name = "HTTP.OutputStream:1"

  -- Initialize the buffer and other variables
  buffer = .mutablebuffer~new(,32768)
  state  = underlyingstream~state
  opened =  state == "READY"
  If opened Then description = ""
  Else description = "Underlying stream not ready:" underlyingstream~description

  -- End-of-line for the HTTP body: LF, the web convention for text bodies.
  eol = '0a'x

  Return

/*******************************************************************************
* The following are new methods                                                *
*******************************************************************************/
--------------------------------------------------------------------------------
-- UNDERLYINGSTREAM                                                           --
--------------------------------------------------------------------------------

::Method underlyingstream
  Expose underlyingstream
  Return underlyingstream

/*******************************************************************************
* The following are STREAM input methods. They all raise NOTREADY              *
*******************************************************************************/

::Method arrayin
  Expose stream_name
  Raise notready Additional (self) Description (stream_name) Return ""

::Method charin
  Expose stream_name
  Raise notready Additional (self) Description (stream_name) Return ""

::Method chars
  Expose stream_name
  Raise notready Additional (self) Description (stream_name) Return ""

::Method linein
  Expose stream_name
  Raise notready Additional (self) Description (stream_name) Return ""

::Method lines
  Expose stream_name
  Raise notready Additional (self) Description (stream_name) Return 0

::Method makearray
  Expose stream_name
  Raise notready Additional (self) Description (stream_name) Return .nil

::Method supplier
  Expose stream_name
  Raise notready Additional (self) Description (stream_name) Return .nil

/*******************************************************************************
* The following are STREAM methods                                             *
*******************************************************************************/

--------------------------------------------------------------------------------
-- ARRAYOUT                                                                   --
--------------------------------------------------------------------------------

::Method arrayout
  Expose buffer

  -- Max two args
  If Arg() > 2 Then Raise syntax 93.902 array (2)

  -- First argument must not be omitted...
  If Arg(1,'O') Then Raise Syntax 93.903 array (1)

  -- ... and must be an array...
  array = Arg(1)~request("ARRAY")
  If array == .nil Then Raise syntax 93.939 array (1)
  -- ... of dimension 1.
  If array~dimension \== 1 Then Raise syntax 93.939 array (1)

  -- Second argument must be one of "LINES", "CHARS". If omitted, assume "LINES"
  If Arg(2,'O') Then option = "LINES"
  Else Do
    option = Arg(2)~request("STRING")
    If option == .nil Then Raise syntax 93.916 array(2)
    option = option~strip~translate
    If "LINES"~abbrev(option,1) Then option = "LINES"
    If "CHARS"~abbrev(option,1) Then option = "CHARS"
  End

  If option \== "LINES", option \== "CHARS" Then
    Raise syntax 93.914 array ("LINES, CHARS",option)

  arraystring = array~makestring(option~left(4))

  buffer~append(arraystring)

--------------------------------------------------------------------------------
-- CHAROUT                                                                    --
--------------------------------------------------------------------------------

::Method charout
  Expose buffer opened state description

  -- Max two args
  If Arg() > 2 Then Raise syntax 93.902 array (2)

  -- First argument must be a string. If not specified, close the stream
  If Arg(1,'O') Then Do
    self~close
    Return 0
    End
  Else Do
    string = Arg(1)
    string = string~request("STRING")
    If string == .nil Then Raise syntax 93.916 array (1)
  End

  -- Cannot position transient streams
  If Arg(2,'E') Then Raise syntax 93.958

  If \opened Then self~open("WRITE")   -- Try to open the file

  If state \== "READY" Then Return 1  -- There was an error

  buffer~append(string)

  Return 0

--------------------------------------------------------------------------------
-- CLOSE                                                                      --
--------------------------------------------------------------------------------

::Method close
  Expose opened
  Use Strict Arg

  If \opened Then Return ""

  Return self~flush

--------------------------------------------------------------------------------
-- COMMAND                                                                    --
--------------------------------------------------------------------------------

::Method command
  Use Strict Arg one

  command = one~request('STRING')
  If command == .nil Then Raise syntax 93.916 array (1)

  command = command~space~translate

  Parse var command verb options

  Select
    When verb == "OPEN"     Then Return self~open(options)
    When verb == "CLOSE"    Then Do
      If options \== "" Then Raise Syntax 93
      Return self~close
      End
    When verb == "FLUSH"    Then Do
      If options \== "" Then Raise Syntax 93
      Return self~flush()
      End
    When verb == "SEEK"     Then Return self~seek(options)
    When verb == "POSITION" Then Return self~seek(options)
    When verb == "QUERY"    Then Return self~query(options)
    Otherwise               Raise Syntax 93
  End

--------------------------------------------------------------------------------
-- DESCRIPTION                                                                --
--------------------------------------------------------------------------------

::Method description
  Expose description state
  Use Strict Arg
  Return (state":"description)~strip

--------------------------------------------------------------------------------
-- RESET                                                                      --
--------------------------------------------------------------------------------
--
-- Discards any buffered output that has not yet been flushed. Used by
-- HTTP.Response~error and ~redirect to clear a half-built body before
-- emitting an error or redirect response, mirroring the servlet model's
-- implicit buffer reset. Has no effect on already-flushed (committed)
-- output: bytes that have left the buffer cannot be recalled.
--

::Method reset
  Expose buffer
  Use Strict Arg
  buffer~setbuffersize(0)
  Return

--------------------------------------------------------------------------------
-- FLUSH                                                                      --
--------------------------------------------------------------------------------

::Method flush
  Expose state buffer underlyingstream

  Use Strict Arg

  If state \== "READY" Then Return state":"

  If \.response~committed Then .response~commit

  underlyingstream~charout(buffer~string)
  underlyingstream~flush

  buffer~setbuffersize(0)

  Return "READY:"

--------------------------------------------------------------------------------
-- LINEOUT                                                                    --
--------------------------------------------------------------------------------

::Method lineout
  Expose buffer state description opened eol

  -- Max two args
  If Arg() > 2 Then Raise syntax 93.902 array (2)

  -- First argument must be a string.
  -- If not specified, close the stream (i.e., flush and continue)
  If Arg(1,'O') Then Do
    self~close
    Return 0
    End
  Else Do
    string = Arg(1)~request("STRING")
    If string == .nil Then Raise syntax 93.916 array (1)
  End

  -- Cannot position transient streams
  If Arg(2,'E') Then Raise syntax 93.958

  If state \== "READY" Then Return 1 -- There was a previous error

  buffer~append(string)
  buffer~append(eol)

  Return 0

--------------------------------------------------------------------------------
-- OPEN                                                                       --
--   HTTP OutputStreams are always open, unless their underlying stream       --
--   reports a problem, in which case they cannot be opened                   --
--------------------------------------------------------------------------------

::Method open
  Expose state
  Return state":"

--------------------------------------------------------------------------------
-- POSITION                                                                   --
--------------------------------------------------------------------------------

::Method position
  Raise syntax 93.958

--------------------------------------------------------------------------------
-- QUALIFY                                                                    --
--------------------------------------------------------------------------------

::Method qualify
  Expose stream_name
  Use Strict Arg
  Return stream_name

--------------------------------------------------------------------------------
-- QUERY                                                                      --
--------------------------------------------------------------------------------

::Method query
  Expose stream_name buffer opened datetime timestamp

  -- We want exactly one argument...
  If Arg() < 1 Then Raise syntax 93.903 array (1)
  If Arg() > 1 Then Raise syntax 93.902 array (1)

  -- ...which can be converted into a string...
  query = Arg(1)~request('STRING')
  If query == .nil Then Raise syntax 93.916 array (1)

  query = query~space~translate

  Parse var query option more

  Select
    When query == "DATETIME"   Then Return datetime
    When query == "EXISTS"     Then Return stream_name
    When query == "HANDLE"     Then Raise syntax 93
    When query == "SIZE"       Then Return ""
    When query == "STREAMTYPE" Then Return "UNKNOWN"
    When query == "TIMESTAMP"  Then Return timestamp
    When option  == "POSITION" |,
         option  == "SEEK"     Then Return 1
    Otherwise Raise syntax 93
  End

--------------------------------------------------------------------------------
-- SAY                                                                        --
--------------------------------------------------------------------------------

::Method say
  Use Strict arg line = ""

  -- Let LINEOUT do the error checking
  Return self~lineout(line)

--------------------------------------------------------------------------------
-- SEEK                                                                       --
--------------------------------------------------------------------------------

::Method seek
  Raise syntax 93.958

--------------------------------------------------------------------------------
-- STATE                                                                      --
--------------------------------------------------------------------------------

::Method state
  Expose state
  Use Strict Arg
  Return state

--------------------------------------------------------------------------------
-- UNINIT                                                                     --
--------------------------------------------------------------------------------

-- This method is needed so that we don't get an error 40
::Method uninit
  Return
