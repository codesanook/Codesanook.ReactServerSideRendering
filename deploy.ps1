# https://docs.microsoft.com/en-us/powershell/module/microsoft.powershell.core/set-strictmode?view=powershell-7
Set-StrictMode -Version Latest
# https://docs.microsoft.com/en-us/powershell/module/microsoft.powershell.core/about/about_preference_variables?view=powershell-7#erroractionpreference
$ErrorActionPreference = "Continue" # Just explicit set it
Import-Module -Name .\DeploymentUtility -Force

"Verify if Node.js installed"
if (-not (Get-Command -Name node -ErrorAction Ignore)) {
    throw  (
		"Missing node.js executable, please install node.js." +
		"If already installed, make sure it can be reached from current environment."
	)
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

# Log environment variables
$environmentNameToWriteValue = @(
    "DEPLOYMENT_SOURCE"
    "DEPLOYMENT_TARGET"
    "NEXT_MANIFEST_PATH"
    "PREVIOUS_MANIFEST_PATH"
    "DEPLOYMENT_TEMP"
    "IN_PLACE_DEPLOYMENT"
    "WEBSITE_NODE_DEFAULT_VERSION"
    "WEBSITE_NPM_DEFAULT_VERSION"
    "SCM_REPOSITORY_PATH"
    "Path" 
    "SOLUTION_PATH"
    "PROJECT_PATH"
    "MSBUILD_PATH"
)
Write-EnviromentValue -EnvironmentName $environmentNameToWriteValue

Install-KuduSync
Install-Yarn

# Install npm packages
$projectDir = (Get-Item (Join-Path $PSScriptRoot $Env:PROJECT_PATH)).Directory.FullName
Push-Location -Path $projectDir
"Installing npm packages with yarn"
Invoke-ExternalCommand -ScriptBlock { yarn install }

# Build Node.js project
"Building Nodel.js project with yarn" 
Invoke-ExternalCommand -ScriptBlock { yarn run dev }
Pop-Location

"Handling .NET Web Application deployment."
"Restore NuGet packages"
Invoke-ExternalCommand -ScriptBlock { nuget restore "$Env:SOLUTION_PATH" }


$preCompiledDir = "$Env:DEPLOYMENT_SOURCE\build\Precompiled"

"Build .NET project to the temp directory"
if (-not $Env:IN_PLACE_DEPLOYMENT) {
    "Building with MSBUILD to '$Env:DEPLOYMENT_TEMP'" 
    Invoke-ExternalCommand -ScriptBlock {
        cmd /c "$Env:MSBUILD_PATH" `
            "$Env:PROJECT_PATH" `
            /t:Build `
            /t:pipelinePreDeployCopyAllFilesToOneFolder `
            /p:_PackageTempDir=$preCompiledDir `
            /p:AutoParameterizationWebConfigConnectionStrings=false `
            /p:Configuration=Release `
            /p:UseSharedCompilation=false `
            /p:SolutionDir="$Env:DEPLOYMENT_SOURCE" `
            /verbosity:minimal `
            /maxcpucount `
            /nologo `
            $Env:SCM_BUILD_ARGS
			# Set SCM_BUILD_ARGS as App Service Configuration to any string you want to append to the MSBuild command line.
    }
}

if (-not $Env:IN_PLACE_DEPLOYMENT) {
    "Syncing a build output to a deployment folder" 
    Invoke-ExternalCommand -ScriptBlock {
        cmd /c kudusync `
            -f "$preCompiledDir" `
            -t "$Env:DEPLOYMENT_TARGET" `
            -n "$Env:NEXT_MANIFEST_PATH" `
            -p "$Env:PREVIOUS_MANIFEST_PATH" `
            -i ".git;.hg;.deployment;deploy.cmd;deploy.ps1;node_modules;"
    }
}

if ($Env:POST_DEPLOYMENT_ACTION) {
    "Post deployment stub"
    Invoke-ExternalCommand -ScriptBlock { $Env:POST_DEPLOYMENT_ACTION }
}

"Deployment successfully"

