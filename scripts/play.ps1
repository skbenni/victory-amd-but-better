# Starts the title with the settings this fork is played with (README.md, "How to run it").
#   scripts\play.ps1 -Exe <path of your own copy's executable>
# -Safe         without the newer, faster ways (the first thing to try when something is wrong)
# -RayTracing   the title's own ray-traced indirect light: lit interiors, about a third slower
# -Build        target\release (the default for playing) or target\diag (detailed measurements)
# -Console      series-x (default) or series-s
# -More         other settings: -More @{VICTORY_PANEL='1'}
# The fast path uses up to eight list workers, capped by physical CPU cores.
# Run it from a normal window, not as administrator: the driver then keeps its shader cache elsewhere.
param(
    [Parameter(Mandatory)][string]$Exe,
    [switch]$Safe,
    [switch]$RayTracing,
    [ValidateSet('diag', 'release')][string]$Build = 'release',
    [ValidateSet('series-x', 'series-s')][string]$Console = 'series-x',
    [hashtable]$More = @{}
)
$thinThreads = 8
try {
    $physicalCores = (Get-CimInstance -ClassName Win32_Processor -ErrorAction Stop |
        Measure-Object -Property NumberOfCores -Sum).Sum
    if ($physicalCores -gt 0) { $thinThreads = [Math]::Min(8, [int]$physicalCores) }
} catch {
    # Keep the measured eight-worker default if Windows cannot report core counts.
}
$settings = @{
    VICTORY_TEXTURE_NO_WAIT = '1'; VICTORY_RELAY = '2'; VICTORY_WIDE_BACK = '1'; VICTORY_CARD_REHASH_RUNS = '1'
    VICTORY_JOIN_COPIES = '1'; VICTORY_INDIRECT_WINDOW = '1'; VICTORY_RELAY_COPY = '1'; VICTORY_CARD_STEPS = '2'
    VICTORY_INDIRECT_BATCH = '2'; VICTORY_MAP_THREADS = '1'; VICTORY_TITLE_PRIORITIES = '0'; VICTORY_CARD_AWAKE = '1'
    VICTORY_SHOW_AFTER = '1'; VICTORY_AMBIENT = '0.8'; VICTORY_D3D12_DRED = 'light'; VICTORY_SKIP_PIPELINES = 'none'
}
if ($Safe) {
    $settings.VICTORY_UNDER_WIDE = '0'; $settings.VICTORY_LAND_ECHO = '0'
} else {
    $settings.VICTORY_THIN = '1'; $settings.VICTORY_THIN_THREADS = "$thinThreads"
    $settings.VICTORY_OUTPUT = '1920x1080'
    $settings.VICTORY_FRAME_INTERVAL_MS = '16.667'
    $settings.VICTORY_JOIN_PARTS = '8'; $settings.VICTORY_UPLOAD_AHEAD = '1'
    $settings.VICTORY_PORT_CONSTANTS = '1'; $settings.VICTORY_PORT_CBV = '1'
    $settings.VICTORY_PORT_GUARD = '1'
    $settings.VICTORY_PORT_JOURNAL = '1'
    $settings.VICTORY_PORT_DESCRIPTORS = '1'
}
if ($RayTracing) { $settings.VICTORY_BVH_BUILDER = '1' }
foreach ($k in $More.Keys) { $settings[$k] = $More[$k] }

$victory = Join-Path $PSScriptRoot "..\target\$Build\victory.exe"
if (-not (Test-Path $victory)) { Write-Host "No $victory. Build it first (README.md)."; return }
if (-not (Test-Path $Exe)) { Write-Host "No $Exe."; return }
# (Other settings left over in this window go; where your files are stays.)
$paths = 'VICTORY_CONFIG', 'VICTORY_GAME_DIR', 'VICTORY_CACHE_DIR', 'VICTORY_DATA_DIR'
Get-ChildItem Env:VICTORY_* | Where-Object { $_.Name -notin $paths } | ForEach-Object { Remove-Item "Env:$($_.Name)" }
foreach ($k in $settings.Keys) { Set-Item "Env:$k" $settings[$k] }
$Exe = (Resolve-Path $Exe).Path
Push-Location (Join-Path $PSScriptRoot '..')   # victory.toml is looked for here
try { & $victory run $Exe --execute --console $Console } finally { Pop-Location }
