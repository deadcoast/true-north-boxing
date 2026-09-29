param([switch]$Verify)
$ErrorActionPreference = 'Stop'
$project = Join-Path (Split-Path -Parent $PSScriptRoot) 'engine/greybox'
if (-not (Test-Path -LiteralPath (Join-Path $project 'project.godot'))) {
    throw 'The True North Boxing source project is missing from engine/greybox.'
}
$engine = Get-Command godot.exe, Godot*_console.exe -ErrorAction SilentlyContinue |
    Select-Object -First 1 -ExpandProperty Source
if (-not $engine) {
    $packages = Join-Path $env:LOCALAPPDATA 'Microsoft/WinGet/Packages'
    $engine = Get-ChildItem -Path (Join-Path $packages 'GodotEngine.GodotEngine_*/Godot*_console.exe') -ErrorAction SilentlyContinue |
        Sort-Object FullName -Descending | Select-Object -First 1 -ExpandProperty FullName
}
if (-not $engine) { throw 'Godot 4 is required. Install it or put godot.exe on PATH, then run this launcher again.' }
if ($Verify) {
    [pscustomobject]@{ Engine = $engine; Project = $project; Scene = 'res://main.tscn'; Entry = 'Before the bell' } | ConvertTo-Json
    exit 0
}
# Launch the actual working source, with its normal saved controls and first bell.
& $engine --path $project
exit $LASTEXITCODE
