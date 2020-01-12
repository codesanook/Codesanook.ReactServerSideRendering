# https://docs.microsoft.com/en-us/powershell/module/microsoft.powershell.core/set-strictmode?view=powershell-7
Set-StrictMode -Version Latest

# https://docs.microsoft.com/en-us/powershell/module/microsoft.powershell.core/about/about_preference_variables?view=powershell-7erroractionpreference
$ErrorActionPreference = "Stop"

# https://docs.microsoft.com/en-us/powershell/module/microsoft.powershell.core/about/about_preference_variables?view=powershell-7#verbosepreference
$VerbosePreference = "Stop"

Get-Command node
$ARTIFACTS = "$PSScriptRoot\..\artifacts"
if (-not(Test-Path -Path $ARTIFACTS)) {
    New-Item -ItemType Directory -Path $ARTIFACTS -Force
}

# Set deployment source folder
if (-not $env:SCM_REPOSITORY_PATH) {
    'Set $DEPLOYMENT_SOURCE variable from $env:SCM_REPOSITORY_PATH'
	$DEPLOYMENT_SOURCE = $env:SCM_REPOSITORY_PATH
}

if (-not(Get-Variable -Name DEPLOYMENT_SOURCE -ErrorAction Ignore)) {
    'Set $DEPLOYMENT_SOURCE variable from current directory'
	$DEPLOYMENT_SOURCE = $PSScriptRoot
}

if (-not $env:DEPLOYMENT_TARGET) {
    'Set $DEPLOYMENT_TARGET variable'
	$DEPLOYMENT_TARGET = "$ARTIFACTS\wwwroot"
}else{
	$DEPLOYMENT_TARGET = $env:DEPLOYMENT_TARGET
}

if (-not $env:NEXT_MANIFEST_PATH) {
    'Set $NEXT_MANIFEST_PATH variable'
	$NEXT_MANIFEST_PATH = "$ARTIFACTS\manifest"
}else{
	$NEXT_MANIFEST_PATH = $env:NEXT_MANIFEST_PATH
}

if (-not $env:PREVIOUS_MANIFEST_PATH) {
	'Set $PREVIOUS_MANIFEST_PATH variable'
	$PREVIOUS_MANIFEST_PATH = "$ARTIFACTS\manifest"
}else{
	$PREVIOUS_MANIFEST_PATH = $env:PREVIOUS_MANIFEST_PATH
}

if (-not $env:KUDU_SYNC_CMD) {
	"Installing Kudu Sync"
	npm install kudusync -g --silent

	# Locally just running "kuduSync" would also work
    'Set $KUDU_SYNC_CMD varialble'
	$KUDU_SYNC_CMD = "$env:APPDATA\npm\kuduSync.cmd"
}else{
	$KUDU_SYNC_CMD = $env:KUDU_SYNC_CMD
}

if (-not $env:DEPLOYMENT_TEMP) {
	$random = Get-Random -InputObject $(0..$([int16]::MaxValue))

    'Set $DEPLOYMENT_TEMP and $CLEAN_LOCAL_DEPLOYMENT_TEMP variables'
	$DEPLOYMENT_TEMP = "$env:TEMP\___deployTemp$random"
	$CLEAN_LOCAL_DEPLOYMENT_TEMP = $true
}else{
	$DEPLOYMENT_TEMP = $env:DEPLOYMENT_TEMP
	$CLEAN_LOCAL_DEPLOYMENT_TEMP = $false
}

if ($CLEAN_LOCAL_DEPLOYMENT_TEMP) {
    'About to remove and create new $DEPLOYMENT_TEMP directory'
    if (Test-Path -Path $DEPLOYMENT_TEMP) {
        'Remove $DEPLOYMENT_TEMP directory'
        Remove-Item -Path $DEPLOYMENT_TEMP -Force -Recurse
    }

    'New $DEPLOYMENT_TEMP directory'
    New-Item -ItemType Directory -Path $DEPLOYMENT_TEMP
}

# Define default node version in WEBSITE_NODE_DEFAULT_VERSION App Setting
# Find all Node.js versions from api/diagnostics/runtime
# https://codesanook-reactjs-server-side-rendering.scm.azurewebsites.net/api/diagnostics/runtime
"Default node version $env:WEBSITE_NODE_DEFAULT_VERSION"

# Always set MSBUILD_PATH
'Set MSBUILD_PATH'
$MSBUILD_PATH = "${env:ProgramFiles(x86)}\MSBuild-15.3.409.57025\MSBuild\15.0\Bin\MSBuild.exe"
"MSBUILD_PATH: $MSBUILD_PATH"
'Get MSBuild version'
& "$MSBUILD_PATH" -version

$SOLUTION_PATH = "$DEPLOYMENT_SOURCE\Codesanook.ReactJS.sln"
$PROJECT_PATH = "$DEPLOYMENT_SOURCE\Codesanook.ReactJS.ServerSideRendering\Codesanook.ReactJS.ServerSideRendering.csproj"
$PROJECT_DIR  = "$DEPLOYMENT_SOURCE\Codesanook.ReactJS.ServerSideRendering"

"-----------------Variables---------------------------------"
"ARTIFACTS = $ARTIFACTS"
"DEPLOYMENT_SOURCE = $DEPLOYMENT_SOURCE"
"DEPLOYMENT_TARGET = $DEPLOYMENT_TARGET"
"NEXT_MANIFEST_PATH = $NEXT_MANIFEST_PATH"
"PREVIOUS_MANIFEST_PATH = $PREVIOUS_MANIFEST_PATH"

"KUDU_SYNC_CMD = $KUDU_SYNC_CMD"
"DEPLOYMENT_TEMP = $DEPLOYMENT_TEMP"
"CLEAN_LOCAL_DEPLOYMENT_TEMP = $CLEAN_LOCAL_DEPLOYMENT_TEMP"
"MSBUILD_PATH = $MSBUILD_PATH"

"SOLUTION_PATH = $SOLUTION_PATH" 
"PROJECT_PATH = $PROJECT_PATH" 
"PROJECT_DIR = $PROJECT_DIR" 

 "-----------------Variables END ---------------------------------"


"Handling .NET Web Application deployment."

"Current node and npm version"
node --version
npm --version

# Verify yarn installed 
"Remove yarn if exist"
npm uninstall -g yarn

"Add yarn as a global tool"
npm install -g yarn

# Install node packages
if(Test-Path -Path "$PROJECT_DIR\package.json") {
    "Current working directory '$PSScriptRoot'"
    "Found $PROJECT_DIR\package.json"

    Push-Location -Path  $PROJECT_DIR
    "Installing node packages with yarn"
    yarn install --silent
    Pop-Location
}else{
    throw "There is no $PROJECT_DIR\package.json file"
}

# Build node packages
if(Test-Path -Path "$PROJECT_DIR\package.json") {
    Push-Location $PROJECT_DIR
	"Building node with yarn" 
    yarn run dev
    Pop-Location
}

"Restore NuGet packages"
nuget restore "$SOLUTION_PATH"

"Build .NET project to the temp directory"
"$DEPLOYMENT_SOURCE\\"

if(-not $env:IN_PLACE_DEPLOYMENT){
	"Building with MSBUILD to '$DEPLOYMENT_TEMP'" 

	& "$MSBUILD_PATH" `
        "$PROJECT_PATH" `
        /nologo `
        /verbosity:minimal `
        /t:Build `
        /t:pipelinePreDeployCopyAllFilesToOneFolder `
        /p:_PackageTempDir="$DEPLOYMENT_TEMP" `
        /p:AutoParameterizationWebConfigConnectionStrings=false `
        /p:Configuration=Release `
        /p:UseSharedCompilation=false `
        /p:SolutionDir="$DEPLOYMENT_SOURCE\\" `
        $env:SCM_BUILD_ARGS
        # Set SCM_BUILD_ARGS apps settings to whatever string you want to append to the msbuild command line.
} 

"Output structure of build result"
tree "$DEPLOYMENT_TEMP" /f /a 
# /f Displays the names of the files in each directory.
# /a Specifies that tree is to use text characters instead of graphic characters to show the lines that link subdirectories.

if(-not $env:IN_PLACE_DEPLOYMENT){
	"Kudu syncing" 
	& "$KUDU_SYNC_CMD" `
        -v 50 `
        -f "$DEPLOYMENT_TEMP" `
        -t "$DEPLOYMENT_TARGET" `
        -n "$NEXT_MANIFEST_PATH" `
        -p "$PREVIOUS_MANIFEST_PATH" `
        -i ".git;.hg;.deployment;deploy.cmd;deploy.ps1;node_modules;"

    if (-not $?) {
        throw "Error syncing Kudu"
    }
}

"Deployment successfully"
