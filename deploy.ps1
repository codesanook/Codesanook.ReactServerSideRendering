Get-Command node -ErrorAction Ignore | Out-Null
if (-not $?) {
	throw "Missing node.js executable, please install node.js, if already installed make sure it can be reached from current environment."
}

$ARTIFACTS = Resolve-Path -Path "$PSScriptRoot\..\artifacts" -ErrorAction Ignore

# Set deployment source folder

if (-not(Get-Variable $DEPLOYMENT_SOURCE -Scope Global)) {
	$DEPLOYMENT_SOURCE = $PSScriptRoot
}

if (-not(Get-Variable $DEPLOYMENT_TARGET -Scope Global)) {
	$DEPLOYMENT_TARGET = "$ARTIFACTS\wwwroot"
}

if (-not(Get-Variable $NEXT_MANIFEST_PATH -Scope Global)) {
	$NEXT_MANIFEST_PATH = "$ARTIFACTS\manifest"

	if (-not(Get-Variable $PREVIOUS_MANIFEST_PATH -Scope Global)) {
		$PREVIOUS_MANIFEST_PATH = "$ARTIFACTS\manifest"
	}
}

if (-not(Get-Variable $KUDU_SYNC_CMD -Scope Global)) {
	"Installing Kudu Sync"
	& npm install kudusync -g --silent
	if (-not $?) {
		throw "Error install kudusync"
	}

	# Locally just running "kuduSync" would also work
	$KUDU_SYNC_CMD = "$env:APPDATA\npm\kuduSync.cmd"
}



if (-not(Get-Variable $DEPLOYMENT_TEMP -Scope Global)) {
	$random = Get-Random -InputObject $(0..$([int16]::MaxValue))
	$DEPLOYMENT_TEMP = "$env:TEMP\___deployTemp$random"
	$CLEAN_LOCAL_DEPLOYMENT_TEMP = $true
}

if (-not(Get-Variable $CLEAN_LOCAL_DEPLOYMENT_TEMP -Scope Global)) {
    if (Test-Path -Path $DEPLOYMENT_TEMP) {
        Remove-Item $DEPLOYMENT_SOURCE -Force -Recurse
        New-Item -ItemType Directory -Value $DEPLOYMENT_TEMP
   } 
}


# Define default node version in WEBSITE_NODE_DEFAULT_VERSION App Setting
# Find all Node.js versions from api/diagnostics/runtime
# https://codesanook-reactjs-server-side-rendering.scm.azurewebsites.net/api/diagnostics/runtime
if ((Get-Variable $KUDU_SELECT_NODE_VERSION_CMD -Scope Global)) {
    "Setting node version"
    # The following are done only on Windows Azure Websites environment
    & $KUDU_SELECT_NODE_VERSION_CMD "$DEPLOYMENT_SOURCE" "$DEPLOYMENT_TARGET" "$DEPLOYMENT_TEMP"
	if (-not $?) {
		throw "Error select node version"
	}
) 

$NODE_EXE = node
$SET NPM_CMD = npm

# Always set MSBUILD_PATH
$MSBUILD_PATH="$ProgramFiles(x86)\MSBuild-15.3.409.57025\MSBuild\15.0\Bin\MSBuild.exe"
& "%MSBUILD_PATH%" -version

$SOLUTION_PATH = "%DEPLOYMENT_SOURCE%\Codesanook.ReactJS.sln"
$PROJECT_PATH = "%DEPLOYMENT_SOURCE%\Codesanook.ReactJS.ServerSideRendering\Codesanook.ReactJS.ServerSideRendering.csproj"
$PROJECT_DIR  = "%DEPLOYMENT_SOURCE%\Codesanook.ReactJS.ServerSideRendering"

