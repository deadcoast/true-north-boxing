param([switch]$ServerOnly)
$ErrorActionPreference = 'Stop'
$repoRoot = Split-Path -Parent $PSScriptRoot
$uvExe = Join-Path $env:USERPROFILE '.local/bin/uv.exe'
$env:UV_CACHE_DIR = Join-Path $repoRoot '.uv-cache'
$env:UV_TOOL_DIR = Join-Path $repoRoot '.uv-cache/tools'
$env:UV_PYTHON_DOWNLOADS = 'never'
$env:GODOT_AI_DISABLE_TELEMETRY = 'true'
$env:PATH = "$(Split-Path -Parent $uvExe);$env:PATH"
$pythonExe = Join-Path $repoRoot '.venv/Scripts/python.exe'
$existingServer = $null
try { $existingServer = Invoke-RestMethod 'http://127.0.0.1:8000/godot-ai/status' -TimeoutSec 2 } catch { }
if ($existingServer -and ($existingServer.name -ne 'godot-ai' -or $existingServer.server_version -ne '3.2.1' -or $existingServer.ws_port -ne 9500)) {
    throw 'Port 8000 has an incompatible service; leave it running and resolve the port configuration.'
}
if ($ServerOnly) {
    if ($existingServer) { Write-Output 'Compatible Godot AI server already running.'; exit 0 }
    & $uvExe tool run --python $pythonExe --from godot-ai==3.2.1 godot-ai --transport streamable-http --port 8000 --ws-port 9500
    exit $LASTEXITCODE
}
$godotExe = (Get-Command 'Godot*_console.exe' | Select-Object -First 1).Source
if (-not $godotExe) { throw 'Installed Godot console executable not found on PATH.' }
$logDir = Join-Path $repoRoot '.pacer/godot-testing'
New-Item -ItemType Directory -Force -Path $logDir | Out-Null
$server = $null
if (-not $existingServer) {
    $server = Start-Process pwsh -WindowStyle Hidden -PassThru -ArgumentList @('-NoProfile', '-File', "`"$PSCommandPath`"", '-ServerOnly') -RedirectStandardOutput (Join-Path $logDir 'server.log') -RedirectStandardError (Join-Path $logDir 'server-errors.log')
}
# The user explicitly requested interactive Godot control; keep its editor visible.
$editor = Start-Process $godotExe -PassThru -ArgumentList @('--editor', '--path', "`"$(Join-Path $repoRoot 'engine/latency_harness')`"", '--log-file', "`"$(Join-Path $logDir 'editor.log')`"")
@{server_launcher_pid=$server.Id; editor_pid=$editor.Id; project='engine/latency_harness'; mcp_url='http://127.0.0.1:8000/mcp'} | ConvertTo-Json
