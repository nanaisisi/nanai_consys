# Install a Windows background task to run monitor.nu at user logon via Task Scheduler
param(
  [string]$NuPath = "",
  [int]$IntervalSec = 5
)

$ErrorActionPreference = "Stop"

# Resolve nushell
if ([string]::IsNullOrWhiteSpace($NuPath)) {
  $NuPath = (Get-Command nu.exe -ErrorAction Stop).Source
}

$RepoRoot = Split-Path -Parent $MyInvocation.MyCommand.Path | Split-Path -Parent
$ScriptPath = Join-Path $RepoRoot "scripts/monitor.nu"
$ScriptPathNu = $ScriptPath -replace "\\", "/"
$DataDir = Join-Path $env:APPDATA "nushell"
$LogDir = Join-Path $DataDir "nanai_consys"
$LogPath = Join-Path $LogDir "metrics.ndjson"
New-Item -ItemType Directory -Force -Path $LogDir | Out-Null

# Build action to run at logon
$NuArgs = @(
  "--commands",
  "use $ScriptPathNu; main --interval $IntervalSec --log-path '$LogPath'"
)

$Action = New-ScheduledTaskAction -Execute $NuPath -Argument ($NuArgs -join " ")
$Trigger = New-ScheduledTaskTrigger -AtLogOn
$Principal = New-ScheduledTaskPrincipal -UserId $env:USERNAME -RunLevel LeastPrivilege -LogonType InteractiveToken
$Settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -StartWhenAvailable

$TaskName = "nanai_consys_monitor"

# Remove existing task if present
try { Unregister-ScheduledTask -TaskName $TaskName -Confirm:$false } catch {}

Register-ScheduledTask -TaskName $TaskName -Action $Action -Trigger $Trigger -Principal $Principal -Settings $Settings | Out-Null

Write-Host "Installed scheduled task '$TaskName' running every logon with interval ${IntervalSec}s. Logs: $LogPath"
