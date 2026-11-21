# Run in a normal PowerShell terminal, outside the restricted agent session.
# Synchronize main; preserve old branches and stashes for a separate review.
param([string]$Godot = "")

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest
$repo = Split-Path $PSScriptRoot -Parent
$scriptPath = "tools/sync_repository.ps1"
$originalAppData = $env:APPDATA

function Invoke-Git {
    param([Parameter(ValueFromRemainingArguments = $true)][string[]]$GitArgs)
    & git @GitArgs
    if ($LASTEXITCODE -ne 0) { throw "Git failed: git $($GitArgs -join ' ')" }
}

function Find-Godot {
    if ($Godot) { return $Godot }
    if ($env:GODOT) { return $env:GODOT }
    foreach ($name in @("godot", "godot4", "godot.exe")) {
        $command = Get-Command $name -ErrorAction SilentlyContinue
        if ($command) { return $command.Source }
    }
    $candidates = @(Get-ChildItem -Path "$env:USERPROFILE\Tools\Godot", "C:\Godot*" -Filter "Godot_v4*_console.exe" -Recurse -Depth 1 -ErrorAction SilentlyContinue)
    if ($candidates.Count) {
        return ($candidates | Sort-Object { [version]($_.BaseName -replace '^Godot_v([\d.]+).*', '$1') } -Descending | Select-Object -First 1).FullName
    }
    throw "Godot 4 not found. Pass -Godot <console executable path>."
}

Push-Location $repo
try {
    if ((Invoke-Git branch --show-current) -ne "main") { throw "Switch to main before running this script." }
    $expected = "https://github.com/JaspervanderSter/game-off-2026.git"
    if ((Invoke-Git remote get-url origin) -ne $expected -or
        (Invoke-Git remote get-url --push origin) -ne $expected) {
        throw "Unexpected origin URL; no changes made."
    }
    foreach ($marker in @("MERGE_HEAD", "CHERRY_PICK_HEAD", "REVERT_HEAD", "rebase-merge", "rebase-apply")) {
        $markerPath = Invoke-Git rev-parse --git-path $marker
        if (Test-Path -LiteralPath $markerPath) { throw "An unfinished Git operation exists: $marker" }
    }
    # Only the helper itself may be uncommitted. Never sweep unrelated files into a commit.
    $dirty = @(Invoke-Git status --porcelain=v1 --untracked-files=all)
    $unexpected = @($dirty | Where-Object { $_.Length -lt 4 -or $_.Substring(3) -ne $scriptPath })
    if ($unexpected.Count) { throw "Uncommitted work detected. Review it first:`n$($unexpected -join "`n")" }
    $godotExe = Find-Godot
    $stamp = Get-Date -Format "yyyyMMdd-HHmmss-fff"
    $backupDir = Join-Path ([System.IO.Path]::GetTempPath()) "game-off-sync-$stamp"
    New-Item -ItemType Directory -Path $backupDir | Out-Null
    Invoke-Git bundle create (Join-Path $backupDir "before-sync.bundle") --all
    Invoke-Git stash list | Set-Content -LiteralPath (Join-Path $backupDir "stashes.txt")
    Write-Host "Recovery bundle: $backupDir"

    Invoke-Git fetch --prune origin
    if ($dirty.Count) {
        Invoke-Git add -- $scriptPath
        Invoke-Git diff --cached --check
        Invoke-Git commit -m "Add guarded repository synchronization helper" -- $scriptPath
    }
    # This integrates origin/main only. Historical feature branches need a content review.
    & git merge --no-edit origin/main
    if ($LASTEXITCODE -ne 0) {
        & git rev-parse --verify -q MERGE_HEAD *> $null
        if ($LASTEXITCODE -eq 0) { Invoke-Git merge --abort }
        throw "Merge failed; nothing was pushed. Resolve the divergence before retrying."
    }

    # Keep test preferences and fixtures separate from the player's saved data.
    $env:APPDATA = Join-Path $backupDir "test-profile"
    New-Item -ItemType Directory -Path $env:APPDATA | Out-Null
    foreach ($project in @("prototypes/prototype_02", "tools/tuning_fork")) {
        $label = $project.Replace('/', '-')
        $importLog = Join-Path $backupDir "$label-import.log"
        & $godotExe --headless --audio-driver Dummy --path $project --import *> $importLog
        if ($LASTEXITCODE -ne 0 -or (Select-String -LiteralPath $importLog -Pattern 'SCRIPT ERROR:|Parse Error:' -Quiet)) {
            throw "Godot import failed. See $importLog. Nothing was pushed."
        }
        $testLog = Join-Path $backupDir "$label-tests.log"
        & $godotExe --headless --audio-driver Dummy --path $project res://tests/run_tests.tscn *> $testLog
        $testExit = $LASTEXITCODE
        Get-Content -LiteralPath $testLog -Tail 12
        if ($testExit -ne 0 -or (Select-String -LiteralPath $testLog -Pattern 'SCRIPT ERROR:|Parse Error:|[1-9][0-9]* failures' -Quiet)) {
            throw "Tests failed. See $testLog. Nothing was pushed."
        }
    }
    $env:APPDATA = $originalAppData
    Invoke-Git diff --check
    if (@(Invoke-Git status --porcelain=v1 --untracked-files=all).Count) {
        throw "Verification changed tracked or untracked files. Review them before pushing."
    }
    Invoke-Git push origin main:main
    Invoke-Git fetch --prune origin
    if ((Invoke-Git rev-parse HEAD) -ne (Invoke-Git rev-parse origin/main)) {
        throw "Remote main changed again; rerun to synchronize."
    }
    Invoke-Git status --short --branch
    Write-Host "Synchronization complete. Historical branches and stashes were preserved:"
    Invoke-Git branch -vv
    Invoke-Git stash list
} finally {
    $env:APPDATA = $originalAppData
    Pop-Location
}
