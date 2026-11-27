# Builds Shapeshifters Duel for Windows and the Web from the latest main and
# uploads both to itch.io with butler. Run it from a normal PowerShell terminal.
#
#   .\tools\release_itch.ps1                 pull main, test, build, upload
#   .\tools\release_itch.ps1 -DryRun         everything except the upload
#   .\tools\release_itch.ps1 -Force          upload even if this commit was already released
#   .\tools\release_itch.ps1 -RegisterTask   check for new commits every 15 minutes (Windows task)
#   .\tools\release_itch.ps1 -UnregisterTask remove that task
#
# Other options: -Godot <console exe>, -Butler <butler.exe>, -SkipTests,
# -Target <user/game>, -IntervalMinutes <n> (with -RegisterTask).
#
# One-time setup: install butler (https://itchio.itch.io/butler) and run
# "butler login" once. See "Automatic itch.io release" in README.md.
param(
	[string]$Godot = "",
	[string]$Butler = "",
	[string]$Target = "spacemonkeyc/shapeshifter-duel",
	[string]$WindowsChannel = "windows",
	[string]$WebChannel = "html5",
	[switch]$SkipTests,
	[switch]$DryRun,
	[switch]$Force,
	[switch]$RegisterTask,
	[switch]$UnregisterTask,
	[int]$IntervalMinutes = 15
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest
$repo = Split-Path $PSScriptRoot -Parent
$game = Join-Path $repo "prototypes\prototype_02"
$exportRoot = Join-Path $repo "export"
$windowsOut = Join-Path $exportRoot "ShapeshiftersDuel"
$webOut = Join-Path $exportRoot "ShapeshiftersDuel-Web"
$stateDir = Join-Path $env:LOCALAPPDATA "ShapeshiftersDuelRelease"
$stateFile = Join-Path $stateDir "last_released_commit.txt"
$taskName = "Shapeshifters Duel itch release"
$expectedOrigin = "https://github.com/JaspervanderSter/game-off-2026.git"

function Invoke-Git {
	param([Parameter(ValueFromRemainingArguments = $true)][string[]]$GitArgs)
	$output = & git @GitArgs
	if ($LASTEXITCODE -ne 0) { throw "Git failed: git $($GitArgs -join ' ')" }
	return $output
}

function Find-Godot {
	if ($Godot) { return $Godot }
	if ($env:GODOT) { return $env:GODOT }
	foreach ($name in @("godot", "godot4", "godot.exe")) {
		$cmd = Get-Command $name -ErrorAction SilentlyContinue
		if ($cmd) { return $cmd.Source }
	}
	$candidates = @(Get-ChildItem -Path "$env:USERPROFILE\Tools\Godot", "C:\Godot*" -Filter "Godot_v4*_console.exe" -Recurse -Depth 1 -ErrorAction SilentlyContinue)
	if ($candidates.Count) {
		return ($candidates | Sort-Object { [version]($_.BaseName -replace '^Godot_v([\d.]+).*', '$1') } -Descending | Select-Object -First 1).FullName
	}
	throw "Godot 4 not found. Pass -Godot <path to Godot_v4.x_console.exe> or set `$env:GODOT."
}

function Find-Butler {
	if ($Butler) { return $Butler }
	if ($env:BUTLER) { return $env:BUTLER }
	$cmd = Get-Command "butler" -ErrorAction SilentlyContinue
	if ($cmd) { return $cmd.Source }
	foreach ($path in @("$env:USERPROFILE\Tools\butler\butler.exe", "$env:APPDATA\itch\apps\butler\butler.exe")) {
		if (Test-Path -LiteralPath $path) { return $path }
	}
	throw "butler not found. Download it from https://itchio.itch.io/butler, unzip it to $env:USERPROFILE\Tools\butler, then run 'butler login' once."
}

function Invoke-Logged {
	# Runs a native command, keeps its output in a log and stops on failure.
	# Start-Process avoids PowerShell 5.1 turning native stderr into errors.
	param([string]$Executable, [string[]]$Arguments, [string]$Log, [string]$WorkingDirectory = $repo)
	$quoted = $Arguments | ForEach-Object { if ($_ -match '[\s"]') { '"' + ($_ -replace '"', '\"') + '"' } else { $_ } }
	$process = Start-Process -FilePath $Executable -ArgumentList $quoted -WorkingDirectory $WorkingDirectory -NoNewWindow -Wait -PassThru -RedirectStandardOutput $Log -RedirectStandardError "$Log.stderr"
	$errors = [IO.File]::ReadAllText("$Log.stderr")
	if ($errors) { [IO.File]::AppendAllText($Log, "`r`n" + $errors) }
	Remove-Item -LiteralPath "$Log.stderr" -ErrorAction SilentlyContinue
	return $process.ExitCode
}

if ($UnregisterTask) {
	Unregister-ScheduledTask -TaskName $taskName -Confirm:$false -ErrorAction SilentlyContinue
	Write-Host "Removed the scheduled task '$taskName' (if it existed)."
	return
}

if ($RegisterTask) {
	$extra = @()
	if ($Godot) { $extra += "-Godot `"$Godot`"" }
	if ($Butler) { $extra += "-Butler `"$Butler`"" }
	$arguments = "-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File `"$PSCommandPath`" $($extra -join ' ')"
	$action = New-ScheduledTaskAction -Execute "powershell.exe" -Argument $arguments -WorkingDirectory $repo
	$trigger = New-ScheduledTaskTrigger -Once -At (Get-Date).AddMinutes(1) -RepetitionInterval (New-TimeSpan -Minutes $IntervalMinutes)
	$settings = New-ScheduledTaskSettingsSet -StartWhenAvailable -MultipleInstances IgnoreNew -ExecutionTimeLimit (New-TimeSpan -Hours 2)
	Register-ScheduledTask -TaskName $taskName -Action $action -Trigger $trigger -Settings $settings -Description "Builds and uploads Shapeshifters Duel to itch.io when main has a new commit." -Force | Out-Null
	Write-Host "Registered '$taskName': checks main every $IntervalMinutes minutes while you are logged in."
	Write-Host "Logs: $stateDir\logs"
	return
}

New-Item -ItemType Directory -Force $stateDir | Out-Null
$stamp = Get-Date -Format "yyyyMMdd-HHmmss"
$logDir = Join-Path $stateDir "logs\$stamp"
New-Item -ItemType Directory -Force $logDir | Out-Null
Start-Transcript -LiteralPath (Join-Path $logDir "release.log") | Out-Null
$originalAppData = $env:APPDATA
Push-Location $repo
try {
	# 1. Bring main up to date without ever touching local work.
	if ((Invoke-Git branch --show-current) -ne "main") { throw "Switch to main before releasing." }
	if ((Invoke-Git remote get-url origin) -ne $expectedOrigin) { throw "Unexpected origin URL; nothing done." }
	$dirty = @(Invoke-Git status --porcelain=v1)
	if ($dirty.Count) { throw "Uncommitted changes in the repository; nothing done:`n$($dirty -join "`n")" }
	Invoke-Git fetch --prune origin | Out-Null
	Invoke-Git merge --ff-only origin/main | Out-Null
	$commit = (Invoke-Git rev-parse HEAD).Trim()
	$short = (Invoke-Git rev-parse --short HEAD).Trim()

	$released = if (Test-Path -LiteralPath $stateFile) { (Get-Content -LiteralPath $stateFile -Raw).Trim() } else { "" }
	if ($released -eq $commit -and -not $Force -and -not $DryRun) {
		Write-Host "Commit $short is already on itch.io. Nothing to do (use -Force to upload again)."
		return
	}

	$godotExe = Find-Godot
	$butlerExe = if ($DryRun) { "" } else { Find-Butler }
	$version = ((Select-String -LiteralPath (Join-Path $game "project.godot") -Pattern '^config/version="(.*)"').Matches[0].Groups[1].Value)
	$userVersion = "$version+$short"
	Write-Host "Releasing $userVersion ($commit)"

	# 2. Tests, with a throwaway profile so the player's saved data stays untouched.
	if (-not $SkipTests) {
		$env:APPDATA = Join-Path $logDir "test-profile"
		New-Item -ItemType Directory -Force $env:APPDATA | Out-Null
		$importLog = Join-Path $logDir "import.log"
		if ((Invoke-Logged $godotExe @("--headless", "--audio-driver", "Dummy", "--path", $game, "--import") $importLog) -ne 0) {
			throw "Godot import failed. See $importLog"
		}
		$testLog = Join-Path $logDir "tests.log"
		$code = Invoke-Logged $godotExe @("--headless", "--audio-driver", "Dummy", "--path", $game, "res://tests/run_tests.tscn") $testLog
		Get-Content -LiteralPath $testLog -Tail 5
		if ($code -ne 0 -or (Select-String -LiteralPath $testLog -Pattern 'SCRIPT ERROR:|Parse Error:|[1-9][0-9]* failures' -Quiet)) {
			throw "Tests failed. See $testLog. Nothing uploaded."
		}
		$env:APPDATA = $originalAppData
	}

	# 3. Windows build (the canonical script: icon, audio workspaces, zip).
	& (Join-Path $game "export_windows.ps1") -Godot $godotExe
	if (-not (Test-Path -LiteralPath (Join-Path $windowsOut "ShapeshiftersDuel.exe"))) { throw "Windows export failed." }

	# 4. Web build.
	if (Test-Path -LiteralPath $webOut) { Remove-Item -Recurse -Force -LiteralPath $webOut }
	New-Item -ItemType Directory -Force $webOut | Out-Null
	$webLog = Join-Path $logDir "web-export.log"
	$code = Invoke-Logged $godotExe @("--headless", "--audio-driver", "Dummy", "--path", $game, "--export-release", "Web", (Join-Path $webOut "index.html")) $webLog
	foreach ($file in @("index.html", "index.js", "index.wasm", "index.pck")) {
		if (-not (Test-Path -LiteralPath (Join-Path $webOut $file))) { $code = 1 }
	}
	if ($code -ne 0) { throw "Web export failed. See $webLog" }
	$webZip = "$webOut.zip"
	if (Test-Path -LiteralPath $webZip) { Remove-Item -Force -LiteralPath $webZip }
	Compress-Archive -Path (Join-Path $webOut "*") -DestinationPath $webZip

	if ($DryRun) {
		Write-Host "Dry run: built $windowsOut and $webOut; nothing uploaded."
		return
	}

	# 5. Upload. butler only sends what changed since the previous push.
	foreach ($push in @(@($windowsOut, $WindowsChannel), @($webOut, $WebChannel))) {
		$pushLog = Join-Path $logDir "butler-$($push[1]).log"
		$code = Invoke-Logged $butlerExe @("push", $push[0], "$($Target):$($push[1])", "--userversion", $userVersion) $pushLog
		# butler redraws a progress bar in place; show only its plain lines.
		Get-Content -LiteralPath $pushLog | Where-Object { $_ -and $_ -notmatch '[▐▌%]' } | Select-Object -Last 4
		if ($code -ne 0) { throw "butler push to $($push[1]) failed. See $pushLog (run 'butler login' if it asks for a key)." }
	}
	Set-Content -LiteralPath $stateFile -Value $commit -Encoding ascii
	Write-Host "Uploaded $userVersion to https://$($Target.Split('/')[0]).itch.io/$($Target.Split('/')[1])"
	Write-Host "itch.io takes a few minutes to process the new builds."
} finally {
	$env:APPDATA = $originalAppData
	Pop-Location
	Stop-Transcript | Out-Null
}
