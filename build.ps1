$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $MyInvocation.MyCommand.Path
$core = if ($env:CORE_PACKAGE) { $env:CORE_PACKAGE } else { Join-Path $root '..\opensagetv-core\output\packages\sagetv-server-x86_64.tar.gz' }
if (-not (Test-Path -LiteralPath $core)) { throw "Missing Core package: $core" }
New-Item -ItemType Directory -Force -Path (Join-Path $root 'artifacts') | Out-Null
Copy-Item -LiteralPath $core -Destination (Join-Path $root 'artifacts\sagetv-server-x86_64.tar.gz') -Force
docker build --target production -t sagetv-server-26-gpu-j11:local -f (Join-Path $root 'modern\Dockerfile') $root
if ($LASTEXITCODE) { exit $LASTEXITCODE }
docker build --target debug -t sagetv-server-26-gpu-j11:debug-local -f (Join-Path $root 'modern\Dockerfile') $root
exit $LASTEXITCODE
