# Run from a normal PowerShell terminal. Commits the reviewed audio and editor work.
$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

function Invoke-Git {
    param([Parameter(ValueFromRemainingArguments = $true)][string[]]$GitArgs)
    $result = & git @GitArgs
    if ($LASTEXITCODE -ne 0) { throw "Git failed: git $($GitArgs -join ' ')" }
    return $result
}

$files = @(
    "prototypes/prototype_02/AUDIO_WORKSPACE.md",
    "prototypes/prototype_02/project.godot",
    "prototypes/prototype_02/scripts/audio/alternate_audio.gd",
    "prototypes/prototype_02/scripts/main.gd",
    "prototypes/prototype_02/tests/audio_workspace_tests.gd",
    "prototypes/prototype_02/tests/run_tests.gd",
    "prototypes/prototype_02/export_windows.ps1",
    "prototypes/prototype_02/tuning_fork.json",
    "tools/tuning_fork/README.md",
    "tools/tuning_fork/docs/File format.md",
    "tools/tuning_fork/docs/Gaps.md",
    "tools/tuning_fork/docs/Music.md",
    "tools/tuning_fork/docs/Tool.md",
    "tools/tuning_fork/scripts/music_panel.gd",
    "tools/tuning_fork/scripts/sound_library.gd",
    "tools/tuning_fork/scripts/tuning_fork.gd",
    "tools/tuning_fork/tests/music_tests.gd",
    "tools/commit_push_audio_mode.ps1"
)

Push-Location (Split-Path $PSScriptRoot -Parent)
try {
    if ((Invoke-Git branch --show-current) -ne "main") {
        throw "Switch to main before running this script."
    }
    $expected = "https://github.com/JaspervanderSter/game-off-2026.git"
    if ((Invoke-Git remote get-url origin) -ne $expected -or
        (Invoke-Git remote get-url --push origin) -ne $expected) {
        throw "Unexpected origin URL; nothing was committed or pushed."
    }
    foreach ($marker in @("MERGE_HEAD", "CHERRY_PICK_HEAD", "REVERT_HEAD", "rebase-merge", "rebase-apply")) {
        if (Test-Path -LiteralPath (Invoke-Git rev-parse --git-path $marker)) {
            throw "An unfinished Git operation exists: $marker"
        }
    }
    $otherStaged = @(Invoke-Git diff --cached --name-only | Where-Object { $_ -notin $files })
    if ($otherStaged.Count) {
        throw "Other files are staged. Unstage them before retrying: $($otherStaged -join ', ')"
    }
    Invoke-Git fetch origin
    & git merge-base --is-ancestor origin/main HEAD
    if ($LASTEXITCODE -ne 0) {
        throw "Remote main has changes missing locally. Synchronize before retrying; nothing was committed or pushed."
    }
    Invoke-Git diff --check -- @files
    Invoke-Git add -- @files
    Invoke-Git diff --cached --check
    $staged = @(Invoke-Git diff --cached --name-only)
    if ($staged.Count) {
        Invoke-Git commit -m "Persist Windows audio mode and simplify Tuning Fork audio workspace"
    } else {
        Write-Host "Audio and Tuning Fork changes are already committed."
    }
    Invoke-Git push origin main:main
    Invoke-Git fetch origin
    if ((Invoke-Git rev-parse HEAD) -ne (Invoke-Git rev-parse origin/main)) {
        throw "Remote main changed again. Check the repository before retrying."
    }
    Write-Host "Commit and push complete." -ForegroundColor Green
    Invoke-Git log -1 --oneline
    Invoke-Git status --short --branch
} finally {
    Pop-Location
}
