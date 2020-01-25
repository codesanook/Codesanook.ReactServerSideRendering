# https://docs.microsoft.com/en-us/powershell/module/microsoft.powershell.core/set-strictmode?view=powershell-7
Set-StrictMode -Version Latest

# https://docs.microsoft.com/en-us/powershell/module/microsoft.powershell.core/about/about_preference_variables?view=powershell-7#erroractionpreference
$ErrorActionPreference = "Stop"

Import-Module -Name .\DeploymentUtility -Force

"Verify if Node.js installed"
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

$MSBUILD_PATH = "${env:ProgramFiles(x86)}\MSBuild-15.3.409.57025\MSBuild\15.0\Bin\MSBuild.exe"
"`$MSBUILD_PATH is set to $MSBUILD_PATH"

# Log environment variables
$environmentNameToWriteValue = @(
    "DEPLOYMENT_SOURCE"
    "DEPLOYMENT_TARGET"
    "NEXT_MANIFEST_PATH"
    "PREVIOUS_MANIFEST_PATH"
    "KUDU_SYNC_CMD"
    "DEPLOYMENT_TEMP"
    "IN_PLACE_DEPLOYMENT"
    "WEBSITE_NODE_DEFAULT_VERSION"
    "SCM_REPOSITORY_PATH"
    "Path" 
    "SOLUTION_PATH"
    "PROJECT_DIR"
    "PROJECT_PATH"
    "CUSTOM_VARIABLE" # Defined in .dployment
)
Write-EnviromentValue -EnvironmentName $environmentNameToWriteValue

# Define default node version in WEBSITE_NODE_DEFAULT_VERSION App Setting
# Find all Node.js versions from api/diagnostics/runtime
# https://codesanook-reactjs-server-side-rendering.scm.azurewebsites.net/api/diagnostics/runtime
"node version $(& node --version)"
"npm version $(& npm --version)"

"Verify if yarn installed" 
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

"Bulding Node project"
if (-not (Test-Path -Path "$Env:PROJECT_DIR\package.json")) {
    throw "There is no $Env:PROJECT_DIR\package.json file"
}

# Install node packages
Push-Location -Path  $Env:PROJECT_DIR
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
Invoke-ExternalCommand -ScriptBlock { & nuget restore "$Env:SOLUTION_PATH" }
Exit-ScriptIfError

"Build .NET project to the temp directory"
if (-not $Env:IN_PLACE_DEPLOYMENT) {
    "Building with MSBUILD to '$Env:DEPLOYMENT_TEMP'" 
    Invoke-ExternalCommand -ScriptBlock { 
        & "$Env:MSBUILD_PATH" `
            "$Env:PROJECT_PATH" `
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
        # Set SCM_BUILD_ARGS App Services Apps Settings to string you want to append to the msbuild command line.
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
