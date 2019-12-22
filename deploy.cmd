:: KUDU Deployment Script 
@IF "%SCM_TRACE_LEVEL%" NEQ "4" @ECHO off

:: Verify node.js installed
WHERE node >null 2>&1

IF %ERRORLEVEL% NEQ 0 (
  ECHO Missing node.js executable, please install node.js, if already installed make sure it can be reached from current environment.
  GOTO error
)

:: Setup
:: -----
SETLOCAL ENABLEDELAYEDEXPANSION

:: https://stackoverflow.com/a/10290765/1872200
:: %~dp0% refer to the current executed batch path
:: Set artifacts folder
SET ARTIFACTS=%~dp0%..\artifacts

:: Set deployment source folder
IF NOT DEFINED DEPLOYMENT_SOURCE (
	SET DEPLOYMENT_SOURCE=%~dp0%.
)

:: Set deployment source folder
IF NOT DEFINED DEPLOYMENT_TARGET (
	SET DEPLOYMENT_TARGET=%ARTIFACTS%\wwwroot
)

IF NOT DEFINED NEXT_MANIFEST_PATH (
	SET NEXT_MANIFEST_PATH=%ARTIFACTS%\manifest

	IF NOT DEFINED PREVIOUS_MANIFEST_PATH (
		SET PREVIOUS_MANIFEST_PATH=%ARTIFACTS%\manifest
	)
)

IF NOT DEFINED KUDU_SYNC_CMD (
	:: Install Kudu sync
	ECHO Installing Kudu Sync
	CALL npm install kudusync -g --silent
	IF !ERRORLEVEL! NEQ 0 GOTO error

	:: Locally just running "kuduSync" would also work
	SET KUDU_SYNC_CMD=%appdata%\npm\kuduSync.cmd
)

IF NOT DEFINED DEPLOYMENT_TEMP (
	SET DEPLOYMENT_TEMP=%temp%\___deployTemp%random%
	SET CLEAN_LOCAL_DEPLOYMENT_TEMP=true
)

IF DEFINED CLEAN_LOCAL_DEPLOYMENT_TEMP (
	IF EXIST "%DEPLOYMENT_TEMP%" RD /s /q "%DEPLOYMENT_TEMP%"
	MKDIR "%DEPLOYMENT_TEMP%"
)

:: Always set MSBUILD_PATH
SET MSBUILD_PATH=%ProgramFiles(x86)%\MSBuild-15.3.409.57025\MSBuild\15.0\Bin\MSBuild.exe
CALL :ExecuteCmd "%MSBUILD_PATH%" -version

ECHO:
ECHO "-----------------Variables---------------------------------"
ECHO "ARTIFACTS = %ARTIFACTS%"
ECHO "DEPLOYMENT_SOURCE = %DEPLOYMENT_SOURCE%"
ECHO "DEPLOYMENT_TARGET = %DEPLOYMENT_TARGET%"
ECHO "NEXT_MANIFEST_PATH = %NEXT_MANIFEST_PATH%"
ECHO "PREVIOUS_MANIFEST_PATH = %PREVIOUS_MANIFEST_PATH%"
ECHO "KUDU_SYNC_CMD = %appdata%\npm\kuduSync.cmd"
ECHO "DEPLOYMENT_TEMP = %DEPLOYMENT_TEMP%"
ECHO "CLEAN_LOCAL_DEPLOYMENT_TEMP = %CLEAN_LOCAL_DEPLOYMENT_TEMP%"
ECHO "MSBUILD_PATH = %MSBUILD_PATH%"
ECHO "KUDU_SELECT_NODE_VERSION_CMD = %KUDU_SELECT_NODE_VERSION_CMD%"

:: Write new empty line
:: https://ss64.com/nt/echo.html
ECHO:
ECHO "-----------------Variables END ---------------------------------"

GOTO Deployment

:: Utility Functions
:: Define default node version in WEBSITE_NODE_DEFAULT_VERSION App Setting
:: Find all Node versions is from api/diagnostics/runtime
:: https://codesanook-reactjs-server-side-rendering.scm.azurewebsites.net/api/diagnostics/runtime
:SelectNodeVersion
IF DEFINED KUDU_SELECT_NODE_VERSION_CMD (
    :: The following are done only on Windows Azure Websites environment
    CALL %KUDU_SELECT_NODE_VERSION_CMD% "%DEPLOYMENT_SOURCE%" "%DEPLOYMENT_TARGET%" "%DEPLOYMENT_TEMP%"
    IF !ERRORLEVEL! NEQ 0 GOTO error
) 

SET NODE_EXE=node
SET NPM_CMD=npm
GOTO :EOF

:Deployment
::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
:: Deployment
:: ----------
ECHO Handling .NET Web Application deployment.

SET SOLUTION_PATH="%DEPLOYMENT_SOURCE%\Codesanook.ReactJS.sln"
SET PROJECT_PATH="%DEPLOYMENT_SOURCE%\Codesanook.ReactJS.ServerSideRendering\Codesanook.ReactJS.ServerSideRendering.csproj"

:: Restore NuGet packages
CALL :ExecuteCmd nuget restore %SOLUTION_PATH%
IF !ERRORLEVEL! NEQ 0 GOTO error

:: Build to the temporary path
IF /I "%IN_PLACE_DEPLOYMENT%" NEQ "1" (
	ECHO "Building with MSBUILD to '%DEPLOYMENT_TEMP%'" 
	CALL :ExecuteCmd "%MSBUILD_PATH%" %PROJECT_PATH% /nologo /verbosity:m /t:Build /t:pipelinePreDeployCopyAllFilesToOneFolder /p:_PackageTempDir="%DEPLOYMENT_TEMP%";AutoParameterizationWebConfigConnectionStrings=false;Configuration=Release;UseSharedCompilation=false /p:SolutionDir="%DEPLOYMENT_SOURCE%\.\\" %SCM_BUILD_ARGS%
) ELSE (
	CALL :ExecuteCmd "%MSBUILD_PATH%" %PROJECT_PATH% /nologo /verbosity:m /t:Build /p:AutoParameterizationWebConfigConnectionStrings=false;Configuration=Release;UseSharedCompilation=false /p:SolutionDir="%DEPLOYMENT_SOURCE%\.\\" %SCM_BUILD_ARGS%
)
IF !ERRORLEVEL! NEQ 0 GOTO error

TREE /F /A "%DEPLOYMENT_TEMP%"

:: Select node version from DEPLOYMENT_TEMP folder
CALL :SelectNodeVersion 

ECHO "Current NODE and NPM version"
CALL :ExecuteCmd !NODE_EXE! --version
CALL :ExecuteCmd !NPM_CMD! --version
IF !ERRORLEVEL! NEQ 0 GOTO error

ECHO "Install yarn"
CALL :ExecuteCmd !NPM_CMD! install -g yarn

:: Install node packages
IF EXIST "%DEPLOYMENT_TEMP%\package.json" (

    ECHO Current working directory '%~dp0%'
    ECHO Found '%DEPLOYMENT_TEMP%\package.json'
    PUSHD "%DEPLOYMENT_TEMP%"

    ECHO Installing Node.js packages
    CALL :ExecuteCmd yarn install
    IF !ERRORLEVEL! NEQ 0 GOTO error

    POPD
)

:: Build node packages
IF EXIST "%DEPLOYMENT_TEMP%\package.json" (
    PUSHD "%DEPLOYMENT_TEMP%"
    CALL :ExecuteCmd yarn run dev
    IF !ERRORLEVEL! NEQ 0 GOTO error
    POPD
)

:: KuduSync
ECHO Kudu syncing 
IF /I "%IN_PLACE_DEPLOYMENT%" NEQ "1" (
	CALL :ExecuteCmd "%KUDU_SYNC_CMD%" -v 50 -f "%DEPLOYMENT_TEMP%" -t "%DEPLOYMENT_TARGET%" -n "%NEXT_MANIFEST_PATH%" -p "%PREVIOUS_MANIFEST_PATH%" -i ".git;.hg;.deployment;deploy.cmd;node_modules"
	IF !ERRORLEVEL! NEQ 0 GOTO error
)

::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
GOTO end

:: Execute command routine that will echo out when error
:ExecuteCmd
SETLOCAL
:: set all parameters to _CMD_
SET _CMD_=%*
CALL %_CMD_%
IF "%ERRORLEVEL%" NEQ "0" ECHO Failed exitCode=%ERRORLEVEL%, command=%_CMD_%
EXIT /b %ERRORLEVEL%

:error
ENDLOCAL

ECHO An error has occurred during web site deployment.
CALL :exitSetErrorLevel
CALL :exitFromFunction 2>nul

:exitSetErrorLevel
::exit batch file with set error code to 1
EXIT /b 1

:exitFromFunction
()

:end
ENDLOCAL
ECHO Finished successfully.
