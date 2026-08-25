$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $MyInvocation.MyCommand.Path
$core = if ($env:CORE_PACKAGE) { $env:CORE_PACKAGE } else { Join-Path $root '..\opensagetv-core\output\packages\sagetv-server-x86_64.tar.gz' }
if (-not (Test-Path -LiteralPath $core)) { throw "Missing Core package: $core" }
New-Item -ItemType Directory -Force -Path (Join-Path $root 'artifacts') | Out-Null
Copy-Item -LiteralPath $core -Destination (Join-Path $root 'artifacts\sagetv-server-x86_64.tar.gz') -Force
$mim = Join-Path $root '..\opensagetv-ffmpeg-mim\output\linux-x64'
$xmltv = Join-Path $root '..\opensagetv-xmltv-import\output'
if (-not (Test-Path "$mim\ffmpeg_MIM")) { throw "Missing Linux MIM output: $mim" }
if (-not (Test-Path "$xmltv\packages\XMLTVImportPlugin.jar")) { throw "Missing XMLTV output: $xmltv" }
New-Item -ItemType Directory -Force -Path (Join-Path $root 'artifacts\ffmpeg-mim'),(Join-Path $root 'artifacts\xmltv') | Out-Null
Copy-Item "$mim\*" (Join-Path $root 'artifacts\ffmpeg-mim') -Recurse -Force
Copy-Item "$xmltv\packages\XMLTVImportPlugin.jar" (Join-Path $root 'artifacts\xmltv') -Force
Copy-Item "$xmltv\config-examples" (Join-Path $root 'artifacts\xmltv') -Recurse -Force
docker build --target production -t sagetv-server-26-gpu-j11:local -f (Join-Path $root 'modern\Dockerfile') $root
if ($LASTEXITCODE) { exit $LASTEXITCODE }
docker build --target debug -t sagetv-server-26-gpu-j11:debug-local -f (Join-Path $root 'modern\Dockerfile') $root
exit $LASTEXITCODE
