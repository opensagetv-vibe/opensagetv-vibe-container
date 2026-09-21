$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $MyInvocation.MyCommand.Path
$core = if ($env:CORE_PACKAGE) { $env:CORE_PACKAGE } else { Join-Path $root '..\opensagetv-vibe-core\output\packages\sagetv-server-x86_64.tar.gz' }
$productionImage = if ($env:OPENSAGETV_VIBE_SERVER_IMAGE) { $env:OPENSAGETV_VIBE_SERVER_IMAGE } else { 'ghcr.io/opensagetv-vibe/opensagetv-vibe-server:u26-gpu-j11' }
$debugImage = if ($env:OPENSAGETV_VIBE_SERVER_DEBUG_IMAGE) { $env:OPENSAGETV_VIBE_SERVER_DEBUG_IMAGE } else { 'ghcr.io/opensagetv-vibe/opensagetv-vibe-server:u26-gpu-j11-debug' }
if (-not (Test-Path -LiteralPath $core)) { throw "Missing Core package: $core" }
New-Item -ItemType Directory -Force -Path (Join-Path $root 'artifacts') | Out-Null
Copy-Item -LiteralPath $core -Destination (Join-Path $root 'artifacts\sagetv-server-x86_64.tar.gz') -Force
$xmltv = Join-Path $root '..\opensagetv-vibe-xmltv-import\output'
if (-not (Test-Path "$xmltv\packages\XMLTVImportPlugin.jar")) { throw "Missing XMLTV output: $xmltv" }
$coreMcp = if ($env:CORE_MCP_OUTPUT) { $env:CORE_MCP_OUTPUT } else { Join-Path $root '..\opensagetv-vibe-core-MCP-Plugin\output' }
$coreMcpSource = if ($env:CORE_MCP_SOURCE) { $env:CORE_MCP_SOURCE } else { Join-Path $root '..\opensagetv-vibe-core-MCP-Plugin' }
$versionLine = Get-Content -LiteralPath (Join-Path $coreMcpSource 'release.properties') | Where-Object { $_ -like 'VERSION=*' } | Select-Object -First 1
if (-not $versionLine) { throw "Core MCP plugin VERSION is missing: $coreMcpSource\release.properties" }
$coreMcpVersion = $versionLine.Substring('VERSION='.Length).Trim()
$coreMcpPackage = Join-Path $coreMcp "packages\OpenSageTVVibeCoreMCPPlugin-jar-$coreMcpVersion.zip"
if (-not (Test-Path -LiteralPath $coreMcpPackage)) { throw "Missing Core MCP plugin output: $coreMcpPackage" }
New-Item -ItemType Directory -Force -Path (Join-Path $root 'artifacts\xmltv') | Out-Null
if (Test-Path -LiteralPath (Join-Path $root 'artifacts\ffmpeg-mim')) {
  Remove-Item -LiteralPath (Join-Path $root 'artifacts\ffmpeg-mim') -Recurse -Force
}
Copy-Item "$xmltv\packages\XMLTVImportPlugin.jar" (Join-Path $root 'artifacts\xmltv') -Force
Copy-Item "$xmltv\config-examples" (Join-Path $root 'artifacts\xmltv') -Recurse -Force
$coreMcpStage = Join-Path $root 'artifacts\core-mcp'
if (Test-Path -LiteralPath $coreMcpStage) { Remove-Item -LiteralPath $coreMcpStage -Recurse -Force }
New-Item -ItemType Directory -Force -Path $coreMcpStage | Out-Null
Add-Type -AssemblyName System.IO.Compression.FileSystem
$archive = [IO.Compression.ZipFile]::OpenRead($coreMcpPackage)
try {
  $entry = $archive.GetEntry('OpenSageTVVibeCoreMCPPlugin.jar')
  if (-not $entry) { throw "Core MCP plugin package does not contain its JAR: $coreMcpPackage" }
  [IO.Compression.ZipFileExtensions]::ExtractToFile($entry, (Join-Path $coreMcpStage 'OpenSageTVVibeCoreMCPPlugin.jar'), $true)
} finally { $archive.Dispose() }
Set-Content -LiteralPath (Join-Path $coreMcpStage 'VERSION') -Value $coreMcpVersion -Encoding ascii
docker build --target production -t $productionImage -f (Join-Path $root 'modern\Dockerfile') $root
if ($LASTEXITCODE) { exit $LASTEXITCODE }
docker build --target debug -t $debugImage -f (Join-Path $root 'modern\Dockerfile') $root
exit $LASTEXITCODE
