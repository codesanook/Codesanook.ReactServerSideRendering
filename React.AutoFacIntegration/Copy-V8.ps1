param(
    [Parameter(Mandatory = $true)] [string] $SolutionDir,
    [Parameter(Mandatory = $true)] [string] $TargetDir
)

# https://github.com/projectkudu/kudu/issues/2048
$WarningPreference = "SilentlyContinue"

$destination = Join-Path -Path $SolutionDir -ChildPath "Codesanook.ReactJS.ServerSideRendering/bin/x86"
New-Item -ItemType Directory $destination -Force -ErrorAction SilentlyContinue | Out-Null

$files = Get-ChildItem -Path $TargetDir -Recurse | Where-Object { $_.FullName -Match 'x86.*v8' } 
$files | ForEach-Object{
	"Copying $_.FullName to $destination"
	Copy-Item -Path $_.FullName -Destination $destination -Force -Verbose
}
