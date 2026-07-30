#!/usr/bin/env rexx
/*--------------------------------------------------------------------------*/
/* gen-class-tables.rex                                                     */
/*                                                                            */
/* Generates the DocBook class-methods summary table (the rexxrefClassTable  */
/* pattern used throughout the official ooRexx documentation) for every      */
/* class documented in a RexxHTTP-style clsref.xml, and inserts/replaces it  */
/* in place, between idempotent GENERATED markers.                          */
/*                                                                            */
/* The official generator was never committed to the trunk (a 2019 one-off, */
/* lost). This is a clean reimplementation of its OUTPUT pattern, verified   */
/* against the real trunk source (svn oorexx/code-0/docs/trunk/rexxref/     */
/* en-US/streamclasses.xml and collclasses.xml, 2026-07-28) -- not guessed   */
/* from memory. One deliberate adaptation: rexxref's tables open with        */
/* "Methods inherited from the <xref to Object/Stream/...>" rows, because    */
/* rexxref documents those ancestor classes itself. A RexxHTTP-only book     */
/* does not, so those rows would be dangling <xref>s to undefined ids --     */
/* this generator omits them rather than invent a target. If a future       */
/* edition of this book documents ancestors too, that row can be added by   */
/* hand; it is out of this tool's scope.                                    */
/*                                                                            */
/* Detection rules (all derived from what Pass A already normalised, and    */
/* from the class .cls sources -- not invented):                           */
/*   - A class-opening section is <section id="..."><title>X Class</title> */
/*     -- the plain-title form Pass A produces for every class heading.    */
/*   - A DIRECT child section documents a METHOD iff its title, with any   */
/*     trailing " (Class Method)" qualifier stripped, contains no blank.   */
/*     Prose subsections ("Consistency Rules", "The Environment Pool", ...)*/
/*     always have a blank in their title and are skipped -- they are not  */
/*     part of the method surface.                                         */
/*   - A method is CLASS-SIDE iff its <imagedata fileref> contains the     */
/*     "_class_" infix -- the naming convention the book's own SVGs already*/
/*     use (cookie_class_new.svg, request_class_decodeform.svg, ...). This */
/*     also catches `new`, which is class-side but carries no "(Class      */
/*     Method)" title suffix (nothing else needs disambiguating from it).  */
/*   - Within each group (class-side / instance-side), methods sort        */
/*     alphabetically by title, case-insensitive -- matching rexxref (this */
/*     is also why operator titles like "[]" land first: they sort before  */
/*     letters, with no special-casing needed).                            */
/*                                                                            */
/* Usage:                                                                    */
/*   rexx gen-class-tables.rex CLSREF.xml                                    */
/*                                                                            */
/* Idempotent: re-running strips any previously generated blocks first, so   */
/* repeat runs replace rather than duplicate or drift.                       */
/*                                                                            */
/* Exit 0 on success, 1 on usage error, 2 if the file could not be read.     */
/*--------------------------------------------------------------------------*/

  Signal on syntax

  Parse Arg clsrefFile
  If clsrefFile = "" Then Do
    Say "usage: rexx gen-class-tables.rex CLSREF.xml"
    Exit 1
  End

  src = .stream~new(clsrefFile)
  If src~open("read") \= "READY:" Then Do
    Say "cannot read:" clsrefFile
    Exit 2
  End
  lines = .Array~new
  Do While src~lines > 0
    lines~append(src~linein)
  End
  src~close

  today = Date("S")                              -- YYYYMMDD, for the marker

  lines   = StripGenerated(lines)                 -- idempotency: drop old blocks first
  classes = FindClasses(lines)
  out     = BuildOutput(lines, classes, today)

  dst = .stream~new(clsrefFile)
  dst~open("write replace")
  Do outLine over out
    dst~lineout(outLine)
  End
  dst~close

  Say classes~items "class table(s) generated in" clsrefFile
  Exit 0

syntax:
  Say "gen-class-tables.rex: unexpected error, condition follows:"
  Say "  " Condition("O")~message
  Exit 2

/*--------------------------------------------------------------------------*/
/* StripGenerated: remove any previously generated table blocks (including  */
/* their markers) so a re-run replaces cleanly instead of duplicating.      */
/*--------------------------------------------------------------------------*/
::Routine StripGenerated
  Use Strict Arg lines

  out = .Array~new
  skipping = .false
  justEnded = .false        -- true for the one line right after an -END marker

  Do line over lines
    If justEnded Then Do
      justEnded = .false
      If line~strip = "" Then Iterate     -- swallow the single blank separator we emit; keeps re-runs stable
    End

    If \skipping, line~caselessPos("$GENERATED-") > 0, line~caselessPos("-START") > 0 Then Do
      skipping = .true
      Iterate
    End
    If skipping Then Do
      If line~caselessPos("$GENERATED-") > 0, line~caselessPos("-END") > 0 Then Do
        skipping = .false
        justEnded = .true
      End
      Iterate
    End
    out~append(line)
  End

  Return out

/*--------------------------------------------------------------------------*/
/* FindClasses: walk the (already-stripped) lines and return an Array of    */
/* ClassRec, each holding its own methods (MethodRec) in document order,    */
/* plus the line index of the first documented method -- the insertion      */
/* point for that class's table.                                            */
/*--------------------------------------------------------------------------*/
::Routine FindClasses
  Use Strict Arg lines

  classes = .Array~new
  currentClass = .nil
  depth = 0

  Do i = 1 To lines~items
    line = lines[i]

    If line~pos("<section id=") > 0 Then Do
      id    = ExtractAttr(line, "id")
      title = ExtractTitle(line)

      Select
        When depth = 0 Then Do
          currentClass = .ClassRec~new
          currentClass~id    = id
          currentClass~title = title
          classes~append(currentClass)
        End
        When depth = 1, currentClass \== .nil Then Do
          strippedTitle = StripClassMethodSuffix(title)
          If strippedTitle~pos(" ") = 0 Then Do
            m = .MethodRec~new
            m~id        = id
            m~title     = title
            m~classSide = SectionHasClassImage(lines, i)
            currentClass~methods~append(m)
            If currentClass~firstMethodLine = .nil Then
              currentClass~firstMethodLine = i
          End
          -- else: a prose subsection (has a blank in its title) -- not a method, skip
        End
        Otherwise Nop                    -- depth > 1 never occurs in this book; ignore defensively
      End

      depth += 1
    End

    If line~pos("</section>") > 0 Then
      depth -= 1
  End

  Return classes

/*--------------------------------------------------------------------------*/
/* SectionHasClassImage: does the section starting at lines[startIndex]     */
/* reference an image whose filename carries the "_class_" infix, before    */
/* the section closes? That infix is the book's own convention for a       */
/* class-side (as opposed to instance-side) method.                         */
/*--------------------------------------------------------------------------*/
::Routine SectionHasClassImage
  Use Strict Arg lines, startIndex

  Do j = startIndex + 1 To lines~items
    line = lines[j]
    If line~pos("</section>")  > 0 Then Leave
    If line~pos("<section id=") > 0 Then Leave      -- safety net; should not occur first
    If line~pos("imagedata fileref=") > 0, line~pos("_class_") > 0 Then
      Return .true
  End

  Return .false

/*--------------------------------------------------------------------------*/
/* BuildOutput: splice each class's generated table into the line array,    */
/* immediately before that class's first documented method.                */
/*--------------------------------------------------------------------------*/
::Routine BuildOutput
  Use Strict Arg lines, classes, today

  inserts = .Directory~new                        -- lineIndex (as string) -> Array of table lines
  Do cls over classes
    If cls~firstMethodLine \== .nil Then
      inserts[cls~firstMethodLine] = BuildTable(cls, today)
  End

  out = .Array~new
  Do i = 1 To lines~items
    If inserts~hasIndex(i) Then Do
      Do tableLine over inserts[i]
        out~append(tableLine)
      End
    End
    out~append(lines[i])
  End

  Return out

/*--------------------------------------------------------------------------*/
/* BuildTable: the <table> block (with its GENERATED markers) for one       */
/* class, in the literal shape verified against streamclasses.xml.          */
/*--------------------------------------------------------------------------*/
::Routine BuildTable
  Use Strict Arg cls, today

  classMethods    = .Array~new
  instanceMethods = .Array~new
  Do m over cls~methods
    If m~classSide Then classMethods~append(m)
                   Else instanceMethods~append(m)
  End
  classMethods    = SortGroup(classMethods)
  instanceMethods = SortGroup(instanceMethods)

  bareName = StripClassSuffix(cls~title)           -- "HTTP.Cookie Class" -> "HTTP.Cookie"
  tableId  = cls~id || "-methods"

  out = .Array~new
  out~append('<!-- $GENERATED-' || today || '-START rexxrefClassTable(' || bareName || ') -->')
  out~append('<table id="' || tableId || '" frame="all" pgwide="1">')
  out~append('<title>' || cls~title || '</title>')
  out~append('<tgroup cols="1">')
  out~append('<tbody>')
  out~append(' <row><entry align="center"><emphasis role="bold">' || bareName || '</emphasis></entry>')
  out~append(' </row>')
  out~append(' <row><entry>')

  If classMethods~items > 0 Then Do
    out~append('  <simplelist>')
    Do m over classMethods
      out~append('   <member><xref linkend="' || m~id || '" xrefstyle="select:title"/></member>')
    End
    out~append('  </simplelist>')
  End

  out~append('  <simplelist columns="3">')
  Do m over instanceMethods
    out~append('   <member><xref linkend="' || m~id || '" xrefstyle="select:title"/></member>')
  End
  out~append('  </simplelist>')

  out~append(' </entry></row>')
  out~append('</tbody>')
  out~append('</tgroup>')
  out~append('</table>')
  out~append('<!-- $GENERATED-' || today || '-END rexxrefClassTable(' || bareName || ') -->')
  out~append('')

  Return out

/*--------------------------------------------------------------------------*/
/* SortGroup: within one method group (class-side or instance-side), rexxref */
/* does NOT merge operator methods ("[]", "[]=") alphabetically among the    */
/* named ones -- verified against the real source (collclasses.xml, Array    */
/* class table: AtGet/PutSet appear first, ahead of AllIndexes/AllItems/...,  */
/* which alphabetical-by-title or alphabetical-by-id would both contradict). */
/* Operators (title's first character is neither a letter nor a digit) sort  */
/* first, among themselves; identifier- and digit-led titles (e.g. "404")    */
/* follow, alphabetically.                                                   */
/*--------------------------------------------------------------------------*/
::Routine SortGroup
  Use Strict Arg methods

  operators = .Array~new
  named     = .Array~new
  Do m over methods
    first = m~title~left(1)
    If first~datatype("A") Then named~append(m)     -- "A" = alphanumeric (letter or digit)
                            Else operators~append(m)
  End

  out = SortMethods(operators)
  out~appendAll(SortMethods(named))
  Return out

/*--------------------------------------------------------------------------*/
/* SortMethods: alphabetical by title, case-insensitive. StringTable        */
/* iteration order is undefined -- ~allIndexes~sort is the fix (see         */
/* skills/oorexx.md); a zero-padded sequence tiebreak keeps keys unique     */
/* even if two titles were ever to collide.                                 */
/*--------------------------------------------------------------------------*/
::Routine SortMethods
  Use Strict Arg methods

  -- The tiebreak separator must sort BELOW any character that can end a
  -- real title ("=", "]", "_", digits, letters...), or it would corrupt
  -- prefix ordering (e.g. "domain" vs "domain=": found the hard way --
  -- "~" as separator put "domain=" before "domain", since "~" (0x7E) is
  -- ASCII-greater than "=" (0x3D)). '01'x is lower than any printable
  -- character, so it never intrudes on the real comparison.
  keyed = .StringTable~new
  seq = 0
  Do m over methods
    seq += 1
    key = m~title~upper || "01"x || Right(seq, 6, "0")
    keyed[key] = m
  End

  sortedKeys = keyed~allIndexes
  sortedKeys~sort

  out = .Array~new
  Do key over sortedKeys
    out~append(keyed[key])
  End

  Return out

/*--------------------------------------------------------------------------*/
/* Small string helpers.                                                    */
/*--------------------------------------------------------------------------*/
::Routine ExtractAttr
  Use Strict Arg line, attrName
  marker = attrName || '="'
  p = line~pos(marker)
  If p = 0 Then Return ""
  start = p + marker~length
  q = line~pos('"', start)
  Return line~substr(start, q - start)

::Routine ExtractTitle
  Use Strict Arg line
  openTag  = "<title>"
  closeTag = "</title>"
  p = line~pos(openTag)
  If p = 0 Then Return ""
  start = p + openTag~length
  q = line~pos(closeTag, start)
  Return line~substr(start, q - start)

::Routine StripClassMethodSuffix
  Use Strict Arg title
  suffix = " (Class Method)"
  If title~right(suffix~length) = suffix Then
    Return title~substr(1, title~length - suffix~length)
  Return title

::Routine StripClassSuffix
  Use Strict Arg title
  suffix = " Class"
  If title~right(suffix~length) = suffix Then
    Return title~substr(1, title~length - suffix~length)
  Return title

/*--------------------------------------------------------------------------*/
/* Records.                                                                  */
/*--------------------------------------------------------------------------*/
::Class MethodRec
::Attribute id
::Attribute title
::Attribute classSide

::Class ClassRec
::Attribute id
::Attribute title
::Attribute methods
::Attribute firstMethodLine

::Method init
  Expose methods firstMethodLine
  methods = .Array~new
  firstMethodLine = .nil
