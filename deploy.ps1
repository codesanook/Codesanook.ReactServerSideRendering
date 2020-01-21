# https://docs.microsoft.com/en-us/powershell/module/microsoft.powershell.core/set-strictmode?view=powershell-7
Set-StrictMode -Version Latest

"CUSTOM_VARIABLE: $Env:CUSTOM_VARIABLE"
"SCM_REPOSITORY_PATH: $Env:SCM_REPOSITORY_PATH"

# https://docs.microsoft.com/en-us/powershell/module/microsoft.powershell.core/about/about_preference_variables?view=powershell-7#erroractionpreference
"Current `$ErrorActionPreference value: $ErrorActionPreference"

function Invoke-ExternalCommand {
    param (
        [scriptblock] $ScriptBlock
    )
    # Displays an error message and continue executing if there is standard error.
    $ErrorActionPreference = "Continue"
    & $ScriptBlock 2>&1 
    if ($LastExitCode) {
        "Failed exitCode=$LastExitCode, command=$($ScriptBlock.ToString())"
    }
}

function Exit-ScriptIfError {
    if ($LastExitCode) {
        "Command failed with exitCode=$LastExitCode"
        Exit 1 
    }
}

# Verify node.js installed
if (-not (Get-Command -Name node -ErrorAction Ignore)) {
    throw "Missing node.js executable, please install node.js." +
    "If already installed, make sure it can be reached from current environment."
}

$ARTIFACTS = "$PSScriptRoot\..\artifacts"

# Set deployment source folder
if (-not $Env:DEPLOYMENT_SOURCE) {
    'Set $DEPLOYMENT_SOURCE variable from current directory'
    $Env:DEPLOYMENT_SOURCE = $PSScriptRoot
}

if (-not $Env:DEPLOYMENT_TARGET) {
    'Set $DEPLOYMENT_TARGET variable'
    $Env:DEPLOYMENT_TARGET = "$ARTIFACTS\wwwroot"
}

if (-not $Env:NEXT_MANIFEST_PATH) {
    'Set $NEXT_MANIFEST_PATH variable'
    $Env:NEXT_MANIFEST_PATH = "$ARTIFACTS\manifest"
}

if (-not $Env:PREVIOUS_MANIFEST_PATH) {
    'Set $PREVIOUS_MANIFEST_PATH variable'
    $Env:PREVIOUS_MANIFEST_PATH = "$ARTIFACTS\manifest"
}

if (-not $Env:KUDU_SYNC_CMD) {
    "Installing Kudu Sync"
    npm install kudusync -g --silent

    # Locally just running "kuduSync" would also work
    'Set $KUDU_SYNC_CMD varialble'
    $Env:KUDU_SYNC_CMD = "$Env:AppData\npm\kuduSync.cmd"
}

if (-not $Env:DEPLOYMENT_TEMP) {
    $random = Get-Random -InputObject $(0..$([int16]::MaxValue))

    'Set $DEPLOYMENT_TEMP and $CLEAN_LOCAL_DEPLOYMENT_TEMP variables'
    $Env:DEPLOYMENT_TEMP = "$Env:TEMP\___deployTemp$random"
    $CLEAN_LOCAL_DEPLOYMENT_TEMP = $true
}
else {
    $CLEAN_LOCAL_DEPLOYMENT_TEMP = $false
}

if ($CLEAN_LOCAL_DEPLOYMENT_TEMP) {
    'About to remove and create new $Env:DEPLOYMENT_TEMP directory'
    if (Test-Path -Path $Env:DEPLOYMENT_TEMP) {
        'Remove $Env:DEPLOYMENT_TEMP directory'
        Remove-Item -Path $Env:DEPLOYMENT_TEMP -Force -Recurse
    }

    'New $Env:DEPLOYMENT_TEMP directory'
    New-Item -ItemType Directory -Path $Env:DEPLOYMENT_TEMP
}

# Define default node version in WEBSITE_NODE_DEFAULT_VERSION App Setting
# Find all Node.js versions from api/diagnostics/runtime
# https://codesanook-reactjs-server-side-rendering.scm.azurewebsites.net/api/diagnostics/runtime
"Default node version $Env:WEBSITE_NODE_DEFAULT_VERSION"

# Set MSBUILD_PATH
'Set MSBUILD_PATH'
$MSBUILD_PATH = "${env:ProgramFiles(x86)}\MSBuild-15.3.409.57025\MSBuild\15.0\Bin\MSBuild.exe"

$SOLUTION_PATH = "$Env:DEPLOYMENT_SOURCE\Codesanook.ReactJS.sln"
$PROJECT_PATH = "$Env:DEPLOYMENT_SOURCE\Codesanook.ReactJS.ServerSideRendering\Codesanook.ReactJS.ServerSideRendering.csproj"
$PROJECT_DIR = "$Env:DEPLOYMENT_SOURCE\Codesanook.ReactJS.ServerSideRendering"

"-----------------Variables---------------------------------"
"ARTIFACTS = $Env:ARTIFACTS"
"DEPLOYMENT_SOURCE = $Env:DEPLOYMENT_SOURCE"
"DEPLOYMENT_TARGET = $Env:DEPLOYMENT_TARGET"
"NEXT_MANIFEST_PATH = $Env:NEXT_MANIFEST_PATH"
"PREVIOUS_MANIFEST_PATH = $Env:PREVIOUS_MANIFEST_PATH"
"KUDU_SYNC_CMD = $Env:KUDU_SYNC_CMD"
"DEPLOYMENT_TEMP = $Env:DEPLOYMENT_TEMP"
"IN_PLACE_DEPLOYMENT = $Env:IN_PLACE_DEPLOYMENT"

"CLEAN_LOCAL_DEPLOYMENT_TEMP = $CLEAN_LOCAL_DEPLOYMENT_TEMP"
"MSBUILD_PATH = $MSBUILD_PATH"

"SOLUTION_PATH = $SOLUTION_PATH" 
"PROJECT_PATH = $PROJECT_PATH" 
"PROJECT_DIR = $PROJECT_DIR" 
"-----------------Variables END ---------------------------------"

"Current node and npm version"
"node version $(& node --version)"
"npm version $(& npm --version)"

"Verify yarn installed" 
$Env:Path += ";$Env:AppData\npm"
if (Get-Command -Name yarn -ErrorAction Ignore) {
    "Update yarn as a global tool to the latest version"
    Invoke-ExternalCommand -ScriptBlock { & npm update yarn -g --silent }
    Exit-ScriptIfError
}
else {
    "Install yarn as a global tool"
    Invoke-ExternalCommand -ScriptBlock { & npm install yarn -g --silent }
    Exit-ScriptIfError
}

if (-not (Test-Path -Path "$PROJECT_DIR\package.json")) {
    throw "There is no $PROJECT_DIR\package.json file"
}

# Install node packages
Push-Location -Path  $PROJECT_DIR
"Installing node packages with yarn"
Invoke-ExternalCommand -ScriptBlock { & yarn install --silent }
Exit-ScriptIfError

# Build node packages
"Building node with yarn" 
Invoke-ExternalCommand -ScriptBlock { & yarn run dev }
Exit-ScriptIfError
Pop-Location

"Handling .NET Web Application deployment."
"Restore NuGet packages"
Invoke-ExternalCommand -ScriptBlock { & nuget restore "$SOLUTION_PATH" }
Exit-ScriptIfError

"Build .NET project to the temp directory"
if (-not $Env:IN_PLACE_DEPLOYMENT) {
    "Building with MSBUILD to '$Env:DEPLOYMENT_TEMP'" 
    Invoke-ExternalCommand -ScriptBlock { 
        & "$MSBUILD_PATH" `
            "$PROJECT_PATH" `
            /nologo `
            /verbosity:minimal `
            /t:Build `
            /t:pipelinePreDeployCopyAllFilesToOneFolder `
            /p:_PackageTempDir="$Env:DEPLOYMENT_TEMP" `
            /p:AutoParameterizationWebConfigConnectionStrings=false `
            /p:Configuration=Release `
            /p:UseSharedCompilation=false `
            /p:SolutionDir="$Env:DEPLOYMENT_SOURCE" `
            $Env:SCM_BUILD_ARGS
        # Set SCM_BUILD_ARGS apps settings to whatever string you want to append to the msbuild command line.
    }
    Exit-ScriptIfError
}

if (-not $Env:IN_PLACE_DEPLOYMENT) {
    "Kudu syncing" 
    Invoke-ExternalCommand -ScriptBlock {
        & "$Env:KUDU_SYNC_CMD" `
            -v 50 `
            -f "$Env:DEPLOYMENT_TEMP" `
            -t "$Env:DEPLOYMENT_TARGET" `
            -n "$Env:NEXT_MANIFEST_PATH" `
            -p "$Env:PREVIOUS_MANIFEST_PATH" `
            -i ".git;.hg;.deployment;deploy.cmd;deploy.ps1;node_modules;"
    }
    Exit-ScriptIfError
}

"Deployment successfully"
