$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $MyInvocation.MyCommand.Path
$name = 'sagetv-u26-container-test'
$data = Join-Path $env:TEMP ('sagetv-u26-clean-test-' + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Force -Path $data | Out-Null
try {
  docker run -d --name $name -e PUID=0 -e PGID=0 -v "${data}:/opt/sagetv" sagetv-server-26-gpu-j11:local | Out-Null
  Start-Sleep -Seconds 25
  docker exec $name test -f /opt/sagetv/server/Sage.jar
  docker exec $name test -s /opt/sagetv/server/JARs/XMLTVImportPlugin.jar
  docker exec $name grep -q '^epg/epg_import_plugin=xmltv.XMLTVImportPlugin$' /opt/sagetv/server/Sage.properties
  docker exec $name pgrep -f 'java.*sage.Sage'
  if ($LASTEXITCODE) { throw 'SageTV process did not start' }
  $health = docker inspect $name --format '{{.State.Health.Status}}'
  if ($health -ne 'healthy') { throw "Container health is $health" }
  docker stop --time 20 $name | Out-Null
} finally {
  # The runtime image declares several data volumes. Remove anonymous test
  # volumes with the container instead of leaking five volumes per run.
  docker rm -f -v $name 2>$null | Out-Null
  $resolvedData = [IO.Path]::GetFullPath($data)
  $resolvedTemp = [IO.Path]::GetFullPath($env:TEMP).TrimEnd([IO.Path]::DirectorySeparatorChar) + [IO.Path]::DirectorySeparatorChar
  if ($resolvedData.StartsWith($resolvedTemp) -and (Split-Path -Leaf $resolvedData).StartsWith('sagetv-u26-clean-test-')) {
    Remove-Item -LiteralPath $resolvedData -Recurse -Force -ErrorAction SilentlyContinue
  }
}
& docker run --rm --entrypoint bash -v "${root}\tests:/tests:ro" sagetv-server-26-gpu-j11:local /tests/core-xmltv-autodiscovery.sh
if ($LASTEXITCODE) { throw 'Core XMLTV auto-discovery regression failed' }
Write-Output 'CONTAINER TEST PASSED'
