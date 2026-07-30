#!/usr/bin/env rexx
/******************************************************************************/
/*                                                                            */
/* RunHTTPTests.rex - Setup and runner for the RexxHTTP integration tests     */
/* ===================================================================        */
/*                                                                            */
/* This file is part of the RexxHTTP package                                  */
/* [See https://rexx.epbcn.com/rexxhttp/]                                     */
/*                                                                            */
/* Copyright (c) 2006-2026 Josep Maria Blasco <josep.maria.blasco@epbcn.com>  */
/*                                                                            */
/* License: Apache License 2.0 (https://www.apache.org/licenses/LICENSE-2.0)  */
/*                                                                            */
/* Checks prerequisites (ooRexx, Apache, modules), deploys the five RexxHTTP  */
/* sources, configures and starts Apache, deploys the fixture rexxlets with   */
/* their whitelist, runs the HTTP test suite, then stops Apache and cleans    */
/* up whatever it created.                                                    */
/*                                                                            */
/* This script targets Linux (including WSL): it uses apt-get and Apache      */
/* paths specific to Debian/Ubuntu.                                           */
/*                                                                            */
/* Montage note: the Action points straight at RexxHTTP.rex, which is LF      */
/* with a "#!/usr/bin/env rexx" shebang, so the kernel execs it directly.     */
/* This mirrors the production deployment. The real production montage may    */
/* differ in detail; when setup.md is rewritten to the real deployment,       */
/* align the VirtualHost/conf resources below.                                */
/*                                                                            */
/* Usage:                                                                     */
/*   rexx tests/http/RunHTTPTests.rex [--setup-only] [--no-stop] [--unit]     */
/*                                                                            */
/*   --setup-only   Check/install prerequisites and configure Apache, deploy  */
/*                  sources and fixtures, but do not run the tests.           */
/*   --no-stop      Do not stop Apache after running the tests.               */
/*   --unit         Run only the pure unit tests (RexxHTTP.unitGroup): no     */
/*                  Apache, no fixtures, no root. Classes are loaded from      */
/*                  src/ and driven with injected stubs.                       */
/*                                                                            */
/* Version history:                                                           */
/*                                                                            */
/* Date     Version Details                                                   */
/* -------- ------- --------------------------------------------------------- */
/* 20260611    1.0  First version                                             */
/*                                                                            */
/******************************************************************************/

  Parse Source . . myPath
  sep = .File~separator

  If .RexxInfo~platform \== "LINUX" Then Do
    Say "ERROR: RunHTTPTests.rex requires Linux (including WSL)."
    Say "Current platform:" .RexxInfo~platform
    Return 1
  End

  -- myDir is tests/http/ ; project root is two levels up.
  myDir = FileSpec("Location", myPath)
  If myDir~right(1) == sep Then myDir = myDir~left(myDir~length - 1)
  httpDir    = myDir
  testsDir   = httpDir~left(httpDir~lastPos(sep) - 1)
  projectDir = testsDir~left(testsDir~lastPos(sep) - 1)

  srcDir      = projectDir || sep || "src"
  fixturesDir = httpDir    || sep || "fixtures"

  setupOnly = 0
  noStop    = 0
  unitOnly  = 0

  Do i = 1 To Arg(1)~words
    option = Arg(1)~word(i)
    Select Case Lower(option)
      When "--setup-only" Then setupOnly = 1
      When "--no-stop"    Then noStop    = 1
      When "--unit"       Then unitOnly  = 1
      Otherwise Do
        Say "Unknown option:" option
        Say "Usage: rexx RunHTTPTests.rex [--setup-only] [--no-stop] [--unit]"
        Return 1
      End
    End
  End

  -- Unit mode: run the pure (non-HTTP) unit groups and exit. These need no
  -- Apache, no fixtures, no root: they load the classes from src/ straight
  -- into this process and drive them with injected stubs. REXX_PATH points
  -- ::Requires at src/; the framework dir goes on PATH like the HTTP run.
  If unitOnly Then Do
    Say "Running RexxHTTP unit tests (no Apache)..."
    Say "=========================================="
    Say
    savedDir = Directory()
    Call Directory testsDir
    unitEnv = 'REXX_PATH="'srcDir'" PATH="framework:http:$PATH"'
    Address System unitEnv 'rexx http/RexxHTTP.unitGroup'
    unitRC = RC
    Call Directory savedDir
    Return unitRC
  End

  -- Deployment locations. These mirror the wired paths inside RexxHTTP.rex.
  deployDir   = "/var/www/html/RexxHTTP"
  testDir     = "/var/www/html/test"
  confFile    = "/etc/apache2/conf-available/rexx-cgi.conf"

  -- The five sources that must be deployed together.
  sources = "HTTP.Request.cls HTTP.Response.cls HTTP.OutputStream.cls" -
            "HTTP.Cookie.cls RexxHTTP.rex"

  -- The fixture rexxlets, in whitelist order.
  fixtures = "hola multi qs check setck readck setckopts badck" -
             "late partial boom htmltype polstrict polbad badnm bsnm arrout" -
             "commitfail flushcrash addckfail" -
             "setpair readpair readname dupck" -
             "err404 errgen errescape errreset rdr rdr301 rdr303"  -
             "envpool enc" -
             "urlprobe urlnobar urlremap" -
             "crlfhdr crlfrdr crlfck" -
             "errthenfail chunkecho methodbody ctnorm ctnormsp ctnormqm ctnormws argopt arroutopt headwrap nrdy"

  -- Per-fixture SetEnv lines for the .htaccess block. Each entry is an
  -- array of "NAME value" strings; under the Action sub-request Apache
  -- delivers them REDIRECT_-prefixed, and the request pool recovers
  -- them through its general fallback.
  setEnvFor = .directory~new
  setEnvFor["polstrict"] = .array~of("REXXHTTP_ARGPOLICY Strict")    -- caseless; honoured
  setEnvFor["polbad"]    = .array~of("REXXHTTP_ARGPOLICY disparate") -- unknown -> 500
  -- REDIRECT_HTTP_FAKE is deliberately named as the fallback of ~http_fake.
  -- Under the Action sub-request Apache stacks its own prefix and it lands
  -- as REDIRECT_REDIRECT_HTTP_FAKE, so it must NOT be reachable (v113).
  setEnvFor["envpool"]   = .array~of("MYPLAIN plainvalue", "_MYVAR underscored", -
                                     "REDIRECT_HTTP_FAKE fallbackvalue")
  -- request_url / script_name probe (v76 swap+rename). Three deployments of
  -- the same fixture code, each with a different .htaccess, exercise the
  -- swap's contract in a one-hop request (fixtures deploy under testDir,
  -- /var/www/html/test):
  --   urlprobe - pair that matches the real topology (BASE=testDir peels the
  --     on-disk path to /<name>, URLBASE=/test restores the URL prefix).
  --     script_name reconstructs disk->URL and lands on the client's URL;
  --     request_url == script_name.
  --   urlnobar - NO pair. script_name takes its base=="" fallback (Return
  --     request_url), so the two still coincide, by the fallback path.
  --   urlremap - pair whose URLBASE injects a prefix the client's URL does
  --     not carry (BASE=testDir, URLBASE=/otheria). script_name reconstructs
  --     to /otheria/urlremap while request_url stays /test/urlremap: the two
  --     DIVERGE, proving the RFC reconstruction is live, not an alias.
  setEnvFor["urlprobe"]  = .array~of("REXXHTTP_BASE /var/www/html/test", -
                                     "REXXHTTP_URLBASE /test")
  setEnvFor["urlremap"]  = .array~of("REXXHTTP_BASE /var/www/html/test", -
                                     "REXXHTTP_URLBASE /otheria")

  Say
  Say "RexxHTTP Integration Tests - Setup and Runner"
  Say "=============================================="
  Say
  Say "Project directory:" projectDir
  Say

--------------------------------------------------------------------------------
-- Step 1: Check ooRexx                                                       --
--------------------------------------------------------------------------------

  Say "Checking ooRexx..."
  Address System "rexx -v > /dev/null 2>&1"
  If RC \== 0 Then Do
    Say "  ERROR: ooRexx is not installed or not in PATH."
    Return 1
  End
  Say "  OK."

--------------------------------------------------------------------------------
-- Step 2: Check Apache                                                       --
--------------------------------------------------------------------------------

  Say "Checking Apache..."
  Address System "which apachectl > /dev/null 2>&1"
  If RC \== 0 Then Do
    Say "  Apache is not installed."
    If \Ask("  Install apache2?") Then Return 1
    Address System "sudo apt-get update -qq && sudo apt-get install -y -qq apache2 2>&1"
    If RC \== 0 Then Do
      Say "  ERROR: Failed to install apache2."
      Return 1
    End
  End
  Say "  OK."

--------------------------------------------------------------------------------
-- Step 3: Check Apache modules (cgid, actions)                               --
--------------------------------------------------------------------------------

  Say "Checking Apache modules (cgid, actions)..."
  Address System "apachectl -M 2>/dev/null | grep -q cgid_module"
  cgidOK = (RC == 0)
  Address System "apachectl -M 2>/dev/null | grep -q actions_module"
  actionsOK = (RC == 0)

  If \cgidOK | \actionsOK Then Do
    missing = ""
    If \cgidOK    Then missing = missing "cgid"
    If \actionsOK Then missing = missing "actions"
    Say "  Missing modules:" missing~strip
    If \Ask("  Enable them?") Then Return 1
    Address System "sudo a2enmod cgid actions 2>&1"
    If RC \== 0 Then Do
      Say "  ERROR: Failed to enable modules."
      Return 1
    End
  End
  Say "  OK."

--------------------------------------------------------------------------------
-- Step 4: Deploy the five sources                                  --
--------------------------------------------------------------------------------

  Say "Deploying RexxHTTP sources to" deployDir"..."
  Address System "sudo mkdir -p" deployDir
  Do src Over sources~makeArray(" ")
    Address System "sudo cp" '"'srcDir || sep || src'"' deployDir
    If RC \== 0 Then Do
      Say "  ERROR: Failed to copy" src
      Return 1
    End
  End
  Address System "sudo chmod 755" deployDir"/RexxHTTP.rex"
  Say "  OK."

--------------------------------------------------------------------------------
-- Step 5: Apache configuration                                              --
--------------------------------------------------------------------------------

  Say "Writing Apache config" confFile"..."
  createdConf = 0
  Address System "test -f" confFile
  If RC == 0 Then
    Say "  Already exists (left as is)."
  Else Do
    tmpConf = MakeTempFile("rexx-cgi.conf")
    If tmpConf == "" Then Do
      Say "  ERROR: Could not create a temporary file."
      Return 1
    End
    conf = .Resources~ApacheConf~makeString("L", "0A"x)
    Call Stream tmpConf, "C", "Open Write Replace"
    Call CharOut tmpConf, conf
    Call Stream tmpConf, "C", "Close"
    -- install -m 644, not cp: MakeTempFile leaves the staging file 600 and
    -- this destination is created here, so cp would hand Apache a config it
    -- cannot read.
    Address System "sudo install -m 644" tmpConf confFile
    Address System "rm -f" tmpConf
    Address System "sudo a2enconf rexx-cgi > /dev/null 2>&1"
    createdConf = 1
    Say "  Created and enabled."
  End

--------------------------------------------------------------------------------
-- Step 6: Deploy fixtures + whitelist                                       --
--------------------------------------------------------------------------------

  Say "Deploying fixtures to" testDir"..."
  Address System "sudo mkdir -p" testDir
  Do fx Over fixtures~makeArray(" ")
    Address System "sudo cp" '"'fixturesDir || sep || fx'"' testDir
  End

  -- The headwrap fixture serves a FIXED file next to itself on disk. Its
  -- payload is a plain document (NOT a rexxlet: it stays out of the whitelist
  -- below, so Apache serves it statically). The 63-byte count is contract --
  -- the HEAD/GET wrapper tests lean on the fixed content.
  Address System 'printf "FIXED PAYLOAD LINE 1\nFIXED PAYLOAD LINE 2\nFIXED PAYLOAD LINE 3\n" | sudo tee' testDir"/headwrap.data > /dev/null"

  -- Whitelist .htaccess: only the listed files are rexxlets; the rest are
  -- served statically.
  tmpHt = MakeTempFile("rexxhttp-htaccess")
  If tmpHt == "" Then Do
    Say "  ERROR: Could not create a temporary file."
    Return 1
  End
  Call Stream tmpHt, "C", "Open Write Replace"
  Do fx Over fixtures~makeArray(" ")
    Call LineOut tmpHt, "<Files" fx">"
    Call LineOut tmpHt, "  SetHandler RexxHTTPCGI"
    If setEnvFor~hasIndex(fx) Then
      Do envLine Over setEnvFor[fx]
        Call LineOut tmpHt, "  SetEnv" envLine
      End
    Call LineOut tmpHt, "</Files>"
  End
  Call Stream tmpHt, "C", "Close"
  -- install -m 644: Apache reads this .htaccess as www-data, and cp would
  -- carry over the staging file's 600.
  Address System "sudo install -m 644" tmpHt testDir"/.htaccess"
  Address System "rm -f" tmpHt
  Say "  OK."

--------------------------------------------------------------------------------
-- Step 6b: Deploy the CGI-contract matrix (variable x topology)              --
--   Two physical zones (docroot /mtx, aliased /ali), each serving the same   --
--   cgivars probe through the four resolution/hop shapes, give the twelve    --
--   topology cells. See DeployMatrix and the CGI-contract tests.             --
--------------------------------------------------------------------------------

  Call DeployMatrix fixturesDir, sep
  Say "  OK."

--------------------------------------------------------------------------------
-- Step 7: Start Apache                                                      --
--------------------------------------------------------------------------------

  Say "Starting Apache..."
  Address System "sudo apachectl start 2>/dev/null"
  Call SysSleep 0.5
  Say "  OK."

--------------------------------------------------------------------------------
-- Step 8: Smoke test                                                        --
--------------------------------------------------------------------------------

  Say "Smoke test (curl http://127.0.0.1/test/hola)..."
  -- Unpredictable name here too. Nothing privileged is copied out of this
  -- file, but the shell redirect below would still follow a symlink left
  -- at a fixed path by another local user.
  tmpSmoke = MakeTempFile("http-smoke")
  If tmpSmoke == "" Then Do
    Say "  ERROR: Could not create a temporary file."
    Return 1
  End
  Address System "curl -s -o /dev/null -w '%{http_code}'" ,
    "--noproxy 127.0.0.1 http://127.0.0.1/test/hola >" tmpSmoke "2>&1"
  smoke = LineIn(tmpSmoke)
  Call Stream tmpSmoke, "C", "Close"
  Address System "rm -f" tmpSmoke
  If smoke~strip \== "200" Then Do
    Say "  WARNING: smoke test returned" smoke~strip "(expected 200)."
    Say "  The tests may fail. Check the Apache configuration and error log."
  End
  Else
    Say "  OK (HTTP 200)."

  Say
  If setupOnly Then Do
    Say "Setup complete. Apache is running."
    Say "Run the tests manually with:"
    Say '  cd' testsDir '&& PATH="framework:http:$PATH" rexx http/RexxHTTP.testGroup'
    Return 0
  End

--------------------------------------------------------------------------------
-- Step 9: Run the tests                                                     --
--------------------------------------------------------------------------------

  Say "Running RexxHTTP tests..."
  Say "========================="
  Say

  savedDir = Directory()
  Call Directory testsDir

  Address System 'PATH="framework:http:$PATH" rexx http/RexxHTTP.testGroup'
  testRC = RC

  Call Directory savedDir
  Say

--------------------------------------------------------------------------------
-- Step 10: Stop Apache (unless --no-stop)                                   --
--------------------------------------------------------------------------------

  If \noStop Then Do
    Say "Stopping Apache..."
    Address System "sudo apachectl stop 2>/dev/null"
    Say "  OK."
  End
  Else
    Say "Apache left running (--no-stop)."

--------------------------------------------------------------------------------
-- Step 11: Clean up the config we created                                   --
--------------------------------------------------------------------------------

  If createdConf Then Do
    Say "Removing" confFile "(created by this script)..."
    Address System "sudo a2disconf rexx-cgi > /dev/null 2>&1"
    Address System "sudo rm -f" confFile
    Say "  OK."
  End

  -- Tear down the CGI-contract matrix (config + both zones).
  Address System "sudo a2disconf rexxhttp-matrix > /dev/null 2>&1"
  Address System "sudo rm -f /etc/apache2/conf-available/rexxhttp-matrix.conf"
  Address System "sudo rm -rf /var/www/html/mtx /opt/rexxhttp-matrix"

  Return testRC

/******************************************************************************/
/* Ask: prompt for a yes/no answer. Returns 1 for yes, 0 for no.             */
/******************************************************************************/

Ask:
  Use Strict Arg prompt
  Call CharOut , prompt "(y/n) "
  Parse Pull answer
  Return Lower(answer~strip)~abbrev("y")

/******************************************************************************/
/* DeployMatrix: build the twelve-cell CGI-contract topology.                */
/*                                                                            */
/* Two physical zones give the "docroot vs Alias" axis:                       */
/*   - docroot zone at /var/www/html/mtx, served in URL space at /mtx         */
/*   - aliased zone at /opt/rexxhttp-matrix, served at /ali (Alias)           */
/* Within each zone the same cgivars probe is deployed under the names each   */
/* resolution needs, giving the "rexxlet vs DirectoryIndex" and "one vs two    */
/* hops" axes:                                                                */
/*   probe.rxl        rexxlet named directly           -> one hop              */
/*   target.mtx       served by Action -> probe.rxl    -> two hops            */
/*   index.rxl        DirectoryIndex of the zone root  -> one hop             */
/*   wrapper.rxl      DirectoryIndex of the zone root  -> one hop             */
/*   sub/index.mtx    DirectoryIndex -> Action          -> two hops            */
/* The "with/without extra path" axis is exercised by the test URLs, not by   */
/* deployment. DirectoryIndex + extra path is the impossible cell (Apache     */
/* hard 404), so eleven URLs over four resources give the twelve live cells   */
/* (the two DirectoryIndex resources carry no extra-path variant).            */
/*                                                                            */
/* The (base, urlbase) pair is set per zone via SetEnv in MatrixConf. Both    */
/* zones use a real prefix (/mtx, /ali), never the "*" sentinel, so the       */
/* reconstruction is exercised, not just the fallback.                        */
/******************************************************************************/

DeployMatrix:
  Use Strict Arg fixturesDir, sep

  probe = fixturesDir || sep || "cgivars"

  docZone = "/var/www/html/mtx"
  aliZone = "/opt/rexxhttp-matrix"

  Do zone Over .Array~of(docZone, aliZone)
    Address System "sudo mkdir -p" zone
    Address System "sudo mkdir -p" zone"/sub"
    -- One hop, rexxlet named:            probe.rxl
    -- Two hops, rexxlet as Action:       target.mtx (a plain file, run via Action)
    -- One hop, DirectoryIndex:          index.rxl
    -- Two hops, DirectoryIndex->Action: sub/index.mtx
    Address System "sudo cp" '"'probe'"' zone"/probe.rxl"
    Address System "sudo cp" '"'probe'"' zone"/index.rxl"
    Address System 'printf "matrix target\n" | sudo tee' zone"/target.mtx > /dev/null"
    Address System 'printf "matrix index\n"  | sudo tee' zone"/sub/index.mtx > /dev/null"
    -- v99: an Action document whose NAME needs percent-encoding (a space),
    -- to prove rawResourcePath decodes REQUEST_URI before hitting disk. Only
    -- meaningful in the docroot zone's Action path, but harmless in both.
    Address System 'printf "spaced doc\n" | sudo tee "'zone'/spaced doc.mtx" > /dev/null'
  End

  -- Write the zone config from the MatrixConf resource and enable it.
  tmpConf = MakeTempFile("rexxhttp-matrix.conf")
  If tmpConf == "" Then Return
  conf = .Resources~MatrixConf~makeString("L", "0A"x)
  Call Stream tmpConf, "C", "Open Write Replace"
  Call CharOut tmpConf, conf
  Call Stream tmpConf, "C", "Close"
  Address System "sudo install -m 644" tmpConf "/etc/apache2/conf-available/rexxhttp-matrix.conf"
  Address System "rm -f" tmpConf
  Address System "sudo a2enconf rexxhttp-matrix > /dev/null 2>&1"

  Return

/******************************************************************************/
/* MakeTempFile: create a temporary file with an unpredictable name and mode  */
/* 600, and return its path ("" if it could not be created).                  */
/*                                                                            */
/* Same routine as the installers carry in InstallHelpers.cls, repeated here  */
/* because this runner deliberately has no ::Requires on install/ -- it must  */
/* run against a plain checkout. A fixed name under /tmp can be pre-created   */
/* as a symlink by any local user, and the sudo copies that follow would then */
/* plant that content in Apache's configuration (CWE-377 / CWE-59). mktemp(1) */
/* creates the file atomically with an unguessable suffix and no world access.*/
/*                                                                            */
/* The file is mode 600, so call sites whose destination must be readable by  */
/* Apache install it with "install -m 644" rather than "cp".                   */
/******************************************************************************/
MakeTempFile: Procedure
  Use Strict Arg prefix
  out = .Array~new
  Address System "mktemp" '"/tmp/'prefix'.XXXXXXXX"' With Output Using (out) Error Stem Discard.
  If RC \== 0 Then Return ""
  If out~items == 0 Then Return ""
  Return out[1]~strip

/******************************************************************************/
/* Resources: the files this script generates.                               */
/******************************************************************************/

::Resource ApacheConf
ServerName localhost

<Directory "/var/www/html/RexxHTTP">
    Options +ExecCGI
    AddHandler cgi-script .rex
    Require all granted
</Directory>

ScriptAlias /RexxHTTP/ /var/www/html/RexxHTTP/

# Action points straight at RexxHTTP.rex: it is LF with a
# "#!/usr/bin/env rexx" shebang, so the kernel execs it directly.
Action RexxHTTPCGI /RexxHTTP/RexxHTTP.rex

<Directory "/var/www/html/test">
    AllowOverride All
    Options +ExecCGI
    Require all granted
</Directory>
::END

::Resource MatrixConf
# ==========================================================================
# CGI-contract matrix: two zones, twelve topology cells.
# Deployed by DeployMatrix (see the prolog). The cgivars probe lives in both
# zones; each zone pairs REXXHTTP_BASE (disk) with REXXHTTP_URLBASE (URL) so
# the disk->URL reconstruction is exercised with a real prefix, not the "*"
# sentinel. probe.rxl and index.rxl are rexlets (one hop); target.mtx and
# sub/index.mtx are documents served through an Action to probe.rxl (two hops).
# ==========================================================================

# ---- docroot zone: /var/www/html/mtx served at /mtx ----
<Directory "/var/www/html/mtx">
    AllowOverride None
    Options +ExecCGI
    Require all granted
    SetEnv REXXHTTP_BASE /var/www/html/mtx
    SetEnv REXXHTTP_URLBASE /mtx
    DirectoryIndex index.rxl
    <Files "probe.rxl">
        SetHandler RexxHTTPCGI
    </Files>
    <Files "index.rxl">
        SetHandler RexxHTTPCGI
    </Files>
    AddHandler mtxhandler-doc .mtx
    Action mtxhandler-doc /mtx/probe.rxl
</Directory>
<Directory "/var/www/html/mtx/sub">
    AllowOverride None
    Options +ExecCGI
    Require all granted
    SetEnv REXXHTTP_BASE /var/www/html/mtx
    SetEnv REXXHTTP_URLBASE /mtx
    DirectoryIndex index.mtx
</Directory>

# ---- aliased zone: /opt/rexxhttp-matrix served at /ali ----
Alias /ali /opt/rexxhttp-matrix
<Directory "/opt/rexxhttp-matrix">
    AllowOverride None
    Options +ExecCGI
    Require all granted
    SetEnv REXXHTTP_BASE /opt/rexxhttp-matrix
    SetEnv REXXHTTP_URLBASE /ali
    DirectoryIndex index.rxl
    <Files "probe.rxl">
        SetHandler RexxHTTPCGI
    </Files>
    <Files "index.rxl">
        SetHandler RexxHTTPCGI
    </Files>
    AddHandler mtxhandler-ali .mtx
    Action mtxhandler-ali /ali/probe.rxl
</Directory>
<Directory "/opt/rexxhttp-matrix/sub">
    AllowOverride None
    Options +ExecCGI
    Require all granted
    SetEnv REXXHTTP_BASE /opt/rexxhttp-matrix
    SetEnv REXXHTTP_URLBASE /ali
    DirectoryIndex index.mtx
</Directory>
::END
