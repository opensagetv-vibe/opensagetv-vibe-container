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
New-Item -ItemType Directory -Force -Path (Join-Path $root 'artifacts\xmltv') | Out-Null
if (Test-Path -LiteralPath (Join-Path $root 'artifacts\ffmpeg-mim')) {
  Remove-Item -LiteralPath (Join-Path $root 'artifacts\ffmpeg-mim') -Recurse -Force
}
Copy-Item "$xmltv\packages\XMLTVImportPlugin.jar" (Join-Path $root 'artifacts\xmltv') -Force
Copy-Item "$xmltv\config-examples" (Join-Path $root 'artifacts\xmltv') -Recurse -Force
docker build --target production -t $productionImage -f (Join-Path $root 'modern\Dockerfile') $root
if ($LASTEXITCODE) { exit $LASTEXITCODE }
docker build --target debug -t $debugImage -f (Join-Path $root 'modern\Dockerfile') $root
exit $LASTEXITCODE
