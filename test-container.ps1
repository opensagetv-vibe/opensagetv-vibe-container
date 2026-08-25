$ErrorActionPreference = 'Stop'
$name = 'sagetv-u26-container-test'
$data = Join-Path $env:TEMP 'sagetv-u26-clean-test'
New-Item -ItemType Directory -Force -Path $data | Out-Null
try {
  docker run -d --name $name -e PUID=0 -e PGID=0 -v "${data}:/opt/sagetv" sagetv-server-26-gpu-j11:local | Out-Null
  Start-Sleep -Seconds 25
  docker exec $name test -f /opt/sagetv/server/Sage.jar
  docker exec $name pgrep -f 'java.*sage.Sage'
  if ($LASTEXITCODE) { throw 'SageTV process did not start' }
  docker stop --time 20 $name | Out-Null
} finally {
  docker rm -f $name 2>$null | Out-Null
}
Write-Output 'CONTAINER TEST PASSED'
