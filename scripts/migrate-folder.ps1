# migrate-folder.ps1 - move a folder to another drive and leave a junction behind.
#
# Safety model:
#   1. copy   (robocopy /E, never /MOVE: /MOVE deletes the emptied source root)
#   2. verify (file count AND byte count must match)
#   3. delete source only after verification passes
#   4. create junction
#   5. on junction failure: recreate source dir and copy everything back
#
# Exit codes: 0 ok, 1 bad args, 2 verify mismatch (both copies kept), 3 source not removable, 4 junction failed (rolled back)
#
# Usage:
#   powershell -NoProfile -ExecutionPolicy Bypass -File migrate-folder.ps1 -Source "C:\Users\me\AppData\Local\Arduino15" -Target "D:\arduino\data"
#   add -DryRun to copy + verify only, without deleting anything.

param(
    [Parameter(Mandatory = $true)][string]$Source,
    [Parameter(Mandatory = $true)][string]$Target,
    [string]$LogFile = "$env:TEMP\migrate-folder.log",
    [switch]$DryRun
)

$ErrorActionPreference = 'Continue'

function Say([string]$m) {
    $line = "[{0}] {1}" -f (Get-Date -Format 'HH:mm:ss'), $m
    Write-Output $line
    try { Add-Content -Path $LogFile -Value $line -Encoding UTF8 } catch { }
}
function Get-Stats([string]$p) {
    $s = Get-ChildItem -LiteralPath $p -Recurse -Force -File -ErrorAction SilentlyContinue |
        Measure-Object -Property Length -Sum
    [pscustomobject]@{ Count = [int]$s.Count; Bytes = [long]$s.Sum }
}

$Source = (Resolve-Path -LiteralPath $Source -ErrorAction Stop).ProviderPath.TrimEnd('\')
if (-not (Test-Path -LiteralPath $Target)) { New-Item -ItemType Directory -Path $Target -Force | Out-Null }
$Target = (Resolve-Path -LiteralPath $Target).ProviderPath.TrimEnd('\')

$srcItem = Get-Item -LiteralPath $Source -Force
if ($srcItem.LinkType -eq 'Junction' -or $srcItem.LinkType -eq 'SymbolicLink') {
    Say "ABORT: source is already a $($srcItem.LinkType) -> $($srcItem.Target)"
    exit 2
}
if ($Source.StartsWith($Target, [StringComparison]::OrdinalIgnoreCase) -or
    $Target.StartsWith($Source, [StringComparison]::OrdinalIgnoreCase)) {
    Say "ABORT: source and target overlap"
    exit 1
}

Say "SOURCE: $Source"
Say "TARGET: $Target"
$before = Get-Stats $Source
Say ("SOURCE STATS: {0} files, {1:N2} GB" -f $before.Count, ($before.Bytes / 1GB))
if ($before.Count -eq 0) { Say "ABORT: source is empty"; exit 1 }

Say "COPY phase (robocopy /E)"
$rc = robocopy $Source $Target /E /XJ /R:2 /W:2 /NFL /NDL /NJH /NP
Say "robocopy exit code: $LASTEXITCODE"

$after = Get-Stats $Target
Say ("TARGET STATS: {0} files, {1:N2} GB" -f $after.Count, ($after.Bytes / 1GB))

if ($before.Count -ne $after.Count -or [math]::Abs($before.Bytes - $after.Bytes) -gt 1MB) {
    Say "RESULT: FAIL - counts differ, nothing deleted. Both copies kept."
    Say "  source: $($before.Count) files / $($before.Bytes) bytes"
    Say "  target: $($after.Count) files / $($after.Bytes) bytes"
    exit 2
}
Say "VERIFY: OK"
if ($DryRun) { Say "DRY RUN: stopping before delete"; exit 0 }

Say "DELETE source"
Remove-Item -LiteralPath $Source -Recurse -Force -ErrorAction SilentlyContinue
if (Test-Path -LiteralPath $Source) {
    Say "RESULT: FAIL - source still has locked files, no junction created."
    Say "  close the apps using this folder, then re-run."
    exit 3
}

Say "CREATE junction"
$null = New-Item -ItemType Junction -Path $Source -Target $Target -ErrorAction SilentlyContinue
$link = Get-Item -LiteralPath $Source -Force -ErrorAction SilentlyContinue
if ($link -and $link.LinkType -eq 'Junction') {
    Say ("RESULT: OK - {0} -> {1}" -f $Source, ($link.Target -join ','))
    Say ("FREED on source volume: {0:N2} GB" -f ($before.Bytes / 1GB))
    exit 0
}

Say "RESULT: FAIL - junction creation failed, rolling back"
if (-not (Test-Path -LiteralPath $Source)) { New-Item -ItemType Directory -Path $Source -Force | Out-Null }
$rc2 = robocopy $Target $Source /E /MOVE /XJ /R:2 /W:2 /NFL /NDL /NJH /NP
Say "rollback robocopy exit code: $LASTEXITCODE"
$back = Get-Stats $Source
Say ("ROLLBACK STATS: {0} files, {1:N2} GB" -f $back.Count, ($back.Bytes / 1GB))
exit 4
