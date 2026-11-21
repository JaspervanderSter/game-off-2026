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

function Repair-CloudImports {
    # Godot's import-cache filename is the MD5 of the complete resource path.
    foreach ($name in @("clouds.ogg", "clouds_2.ogg")) {
        $sidecar = "prototypes/prototype_02/default/sfx/ui/$name.import"
        if (-not (Test-Path -LiteralPath $sidecar)) { continue }
        $resource = "res://default/sfx/ui/$name"
        $md5 = [System.Security.Cryptography.MD5]::Create()
        try {
            $hash = [BitConverter]::ToString($md5.ComputeHash([Text.Encoding]::UTF8.GetBytes($resource))).Replace('-', '').ToLowerInvariant()
        } finally { $md5.Dispose() }
        $text = [IO.File]::ReadAllText((Join-Path $repo $sidecar))
        $text = $text.Replace("res://sfx/ui/$name", $resource)
        $text = $text -replace ([regex]::Escape("$name-") + '[a-f0-9]{32}'), "$name-$hash"
        [IO.File]::WriteAllText((Join-Path $repo $sidecar), $text, (New-Object Text.UTF8Encoding($false)))
        Invoke-Git add -- $sidecar
    }
    $generator = "prototypes/prototype_02/tools/make_cloud_whoosh.gd"
    if (Test-Path -LiteralPath $generator) {
        $text = [IO.File]::ReadAllText((Join-Path $repo $generator))
        $text = $text.Replace('res://sfx/ui/', 'res://default/sfx/ui/')
        [IO.File]::WriteAllText((Join-Path $repo $generator), $text, (New-Object Text.UTF8Encoding($false)))
        Invoke-Git add -- $generator
    }
}

function Invoke-GodotCheck {
    param([string]$Executable, [string[]]$EngineArgs, [string]$Log)
    # PowerShell 5.1 treats redirected native stderr as terminating errors when
    # ErrorActionPreference is Stop. Capture each stream through Start-Process.
    $stderrLog = "$Log.stderr"
    $process = Start-Process -FilePath $Executable -ArgumentList $EngineArgs -WorkingDirectory $repo -WindowStyle Hidden -Wait -PassThru -RedirectStandardOutput $Log -RedirectStandardError $stderrLog
    $errors = [IO.File]::ReadAllText($stderrLog)
    if ($errors) { [IO.File]::AppendAllText($Log, "`r`n" + $errors) }
    Get-Content -LiteralPath $Log -Tail 12
    if ($process.ExitCode -ne 0 -or (Select-String -LiteralPath $Log -Pattern 'SCRIPT ERROR:|Parse Error:|[1-9][0-9]* failures' -Quiet)) {
        throw "Godot verification failed. See $Log. Nothing was pushed."
    }
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
    & git merge --no-commit --no-edit origin/main
    if ($LASTEXITCODE -ne 0) {
        $mergeHead = Invoke-Git rev-parse --git-path MERGE_HEAD
        $unmerged = @(Invoke-Git diff --name-only --diff-filter=U)
        $known = '^prototypes/prototype_02/default/sfx/ui/(clouds\.json|clouds(?:_2)?\.ogg(?:\.import)?)$'
        $unknown = @($unmerged | Where-Object { $_ -notmatch $known })
        # Resolve only additions relocated by Git's directory-rename detection.
        # A content conflict (stage 1 or 2) must still stop for manual review.
        $nonAdditions = @(Invoke-Git ls-files --unmerged | Where-Object { $_ -notmatch ' 3\t' })
        if (-not (Test-Path -LiteralPath $mergeHead) -or -not $unmerged.Count -or $unknown.Count -or $nonAdditions.Count) {
            if (Test-Path -LiteralPath $mergeHead) { Invoke-Git merge --abort }
            throw "Unexpected merge conflict; merge aborted and nothing pushed."
        }
        Write-Host "Resolving relocated cloud sound additions under default/sfx/ui."
        foreach ($path in $unmerged) { Invoke-Git add -- $path }
    }
    $mergeHead = Invoke-Git rev-parse --git-path MERGE_HEAD
    if (Test-Path -LiteralPath $mergeHead) {
        Repair-CloudImports
        Invoke-Git diff --cached --check
        Invoke-Git commit --no-edit
    }

    # Keep test preferences and fixtures separate from the player's saved data.
    $env:APPDATA = Join-Path $backupDir "test-profile"
    New-Item -ItemType Directory -Path $env:APPDATA | Out-Null
    foreach ($project in @("prototypes/prototype_02", "tools/tuning_fork")) {
        $label = $project.Replace('/', '-')
        $importLog = Join-Path $backupDir "$label-import.log"
        Invoke-GodotCheck -Executable $godotExe -EngineArgs @('--headless', '--audio-driver', 'Dummy', '--path', $project, '--import') -Log $importLog
        $testLog = Join-Path $backupDir "$label-tests.log"
        Invoke-GodotCheck -Executable $godotExe -EngineArgs @('--headless', '--audio-driver', 'Dummy', '--path', $project, 'res://tests/run_tests.tscn') -Log $testLog
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
