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
/* sources plus a one-line wrapper, configures and starts Apache, deploys the */
/* fixture rexxlets with their whitelist, runs the HTTP test suite, then      */
/* stops Apache and cleans up whatever it created.                            */
/*                                                                            */
/* This script targets rexxlet (including WSL): it uses apt-get and Apache    */
/* paths specific to Debian/Ubuntu.                                           */
/*                                                                            */
/* Montage note: the Action points at a one-line LF wrapper that Calls        */
/* RexxHTTP.rex, NOT at RexxHTTP.rex directly. This mirrors the production    */
/* deployment and sidesteps the CRLF-shebang exec problem (RexxHTTP.rex is    */
/* materialised CRLF; reached via Call, its shebang stays an inert comment).  */
/* The real production montage may differ in detail; when setup.md is         */
/* rewritten to the real deployment, align the VirtualHost/Wrapper            */
/* resources below.                                                           */
/*                                                                            */
/* Usage:                                                                     */
/*   rexx tests/http/RunHTTPTests.rex [--setup-only] [--no-stop]              */
/*                                                                            */
/*   --setup-only   Check/install prerequisites and configure Apache, deploy  */
/*                  sources and fixtures, but do not run the tests.           */
/*   --no-stop      Do not stop Apache after running the tests.               */
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
    Say "ERROR: RunHTTPTests.rex requires rexxlet (including WSL)."
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

  Do i = 1 To Arg(1)~words
    option = Arg(1)~word(i)
    Select Case Lower(option)
      When "--setup-only" Then setupOnly = 1
      When "--no-stop"    Then noStop    = 1
      Otherwise Do
        Say "Unknown option:" option
        Say "Usage: rexx RunHTTPTests.rex [--setup-only] [--no-stop]"
        Return 1
      End
    End
  End

  -- Deployment locations. These mirror the wired paths inside RexxHTTP.rex.
  deployDir   = "/var/www/html/RexxHTTP"
  testDir     = "/var/www/html/test"
  wrapperFile = deployDir || "/wrapper"
  confFile    = "/etc/apache2/conf-available/rexx-cgi.conf"

  -- The five sources that must be deployed together.
  sources = "HTTP.Request.cls HTTP.Response.cls HTTP.OutputStream.cls" -
            "HTTP.Cookie.cls RexxHTTP.rex"

  -- The fixture rexxlets, in whitelist order.
  fixtures = "hola multi qs check setck readck setckopts badck" -
             "late partial boom htmltype polstrict polbad badnm arrout" -
             "commitfail flushcrash addckfail" -
             "setpair readpair readname dupck" -
             "err404 errgen errescape errreset rdr rdr301 rdr303"  -
             "envpool enc" -
             "urlprobe urlnobar urlremap"

  -- Per-fixture SetEnv lines for the .htaccess block. Each entry is an
  -- array of "NAME value" strings; under the Action sub-request Apache
  -- delivers them REDIRECT_-prefixed, and the request pool recovers
  -- them through its general fallback.
  setEnvFor = .directory~new
  setEnvFor["polstrict"] = .array~of("REXXHTTP_ARGPOLICY Strict")    -- caseless; honoured
  setEnvFor["polbad"]    = .array~of("REXXHTTP_ARGPOLICY disparate") -- unknown -> 500
  setEnvFor["envpool"]   = .array~of("MYPLAIN plainvalue", "_MYVAR underscored")
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
-- Step 4: Deploy the five sources + wrapper                                  --
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

  -- The one-line wrapper. It is exec'd by the kernel, so it must be LF.
  Say "Creating wrapper" wrapperFile"..."
  tmpWrap = "/tmp/rexxhttp-wrapper.tmp"
  wrapper = .Resources~Wrapper~makeString("L", "0A"x)
  wrapper = wrapper~changeStr("%deployDir%", deployDir)
  Call Stream tmpWrap, "C", "Open Write Replace"
  Call CharOut tmpWrap, wrapper
  Call Stream tmpWrap, "C", "Close"
  Address System "sudo cp" tmpWrap wrapperFile
  Address System "rm -f" tmpWrap
  Address System "sudo chmod 755" wrapperFile
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
    tmpConf = "/tmp/rexx-cgi.conf.tmp"
    conf = .Resources~ApacheConf~makeString("L", "0A"x)
    Call Stream tmpConf, "C", "Open Write Replace"
    Call CharOut tmpConf, conf
    Call Stream tmpConf, "C", "Close"
    Address System "sudo cp" tmpConf confFile
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

  -- Whitelist .htaccess: only the listed files are rexxlets; the rest are
  -- served statically.
  tmpHt = "/tmp/rexxhttp-htaccess.tmp"
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
  Address System "sudo cp" tmpHt testDir"/.htaccess"
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
  Address System "curl -s -o /dev/null -w '%{http_code}'" ,
    "--noproxy 127.0.0.1 http://127.0.0.1/test/hola > /tmp/http-smoke.tmp 2>&1"
  smoke = LineIn("/tmp/http-smoke.tmp")
  Call Stream "/tmp/http-smoke.tmp", "C", "Close"
  Address System "rm -f /tmp/http-smoke.tmp"
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
/* resolution needs, giving the "rexlet vs DirectoryIndex" and "one vs two    */
/* hops" axes:                                                                */
/*   probe.rxl        rexlet named directly           -> one hop              */
/*   target.mtx       served by Action -> probe.rxl    -> two hops            */
/*   index.rxl        DirectoryIndex of the zone root  -> one hop             */
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
    -- One hop, rexlet named:            probe.rxl
    -- Two hops, rexlet as Action:       target.mtx (a plain file, run via Action)
    -- One hop, DirectoryIndex:          index.rxl
    -- Two hops, DirectoryIndex->Action: sub/index.mtx
    Address System "sudo cp" '"'probe'"' zone"/probe.rxl"
    Address System "sudo cp" '"'probe'"' zone"/index.rxl"
    Address System 'printf "matrix target\n" | sudo tee' zone"/target.mtx > /dev/null"
    Address System 'printf "matrix index\n"  | sudo tee' zone"/sub/index.mtx > /dev/null"
  End

  -- Write the zone config from the MatrixConf resource and enable it.
  tmpConf = "/tmp/rexxhttp-matrix.conf.tmp"
  conf = .Resources~MatrixConf~makeString("L", "0A"x)
  Call Stream tmpConf, "C", "Open Write Replace"
  Call CharOut tmpConf, conf
  Call Stream tmpConf, "C", "Close"
  Address System "sudo cp" tmpConf "/etc/apache2/conf-available/rexxhttp-matrix.conf"
  Address System "rm -f" tmpConf
  Address System "sudo a2enconf rexxhttp-matrix > /dev/null 2>&1"

  Return

/******************************************************************************/
/* Resources: the files this script generates.                               */
/******************************************************************************/

::Resource Wrapper
#!/usr/bin/env rexx
Call "%deployDir%/RexxHTTP.rex"
::END

::Resource ApacheConf
ServerName localhost

<Directory "/var/www/html/RexxHTTP">
    Options +ExecCGI
    AddHandler cgi-script .rex
    Require all granted
</Directory>

ScriptAlias /RexxHTTP/ /var/www/html/RexxHTTP/

# Action points at the wrapper (one-line LF Rexx that Calls RexxHTTP.rex),
# not at RexxHTTP.rex directly: the wrapper's LF shebang keeps the kernel
# happy, and RexxHTTP.rex is reached via Call so its CRLF shebang is inert.
Action RexxHTTPCGI /RexxHTTP/wrapper

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
