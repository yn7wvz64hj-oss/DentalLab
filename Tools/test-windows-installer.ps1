$ErrorActionPreference = 'Stop'
$taskInstall = Join-Path $env:RUNNER_TEMP 'DentalLab-installer-test'
$taskPreview = Join-Path $env:RUNNER_TEMP 'DentalLab-installed-preview.png'
$taskArchive = Join-Path $env:LOCALAPPDATA 'DentalLab'
New-Item -ItemType Directory -Path $taskArchive -Force | Out-Null
$taskSentinel = Join-Path $taskArchive 'installer-sentinel.txt'
Set-Content -LiteralPath $taskSentinel -Value 'Synthetic archive must survive uninstall.'
$taskSetup = (Resolve-Path 'dist/installer/DentalLab-Setup-Windows-x64.exe').Path
$taskResult = Start-Process -FilePath $taskSetup -ArgumentList @('/VERYSILENT','/SUPPRESSMSGBOXES','/NORESTART',"/DIR=`"$taskInstall`"") -Wait -PassThru -WindowStyle Hidden
if ($taskResult.ExitCode -ne 0) { throw "Installer failed: $($taskResult.ExitCode)" }
$taskExecutable = Join-Path $taskInstall 'DentalLab.exe'
if (!(Test-Path -LiteralPath $taskExecutable)) { throw 'Installed executable missing.' }
$taskResult = Start-Process -FilePath $taskExecutable -ArgumentList @('--preview',"`"$taskPreview`"") -Wait -PassThru -WindowStyle Hidden
if ($taskResult.ExitCode -ne 0 -or !(Test-Path -LiteralPath $taskPreview)) { throw 'Installed app failed to render synthetic preview.' }
$taskUninstall = Join-Path $taskInstall 'unins000.exe'
$taskResult = Start-Process -FilePath $taskUninstall -ArgumentList @('/VERYSILENT','/SUPPRESSMSGBOXES','/NORESTART') -Wait -PassThru -WindowStyle Hidden
if ($taskResult.ExitCode -ne 0) { throw 'Uninstall failed.' }
for ($taskAttempt = 0; $taskAttempt -lt 15 -and (Test-Path -LiteralPath $taskExecutable); $taskAttempt++) { Start-Sleep -Seconds 1 }
if (Test-Path -LiteralPath $taskExecutable) { throw 'App was not uninstalled.' }
if ((Get-Content -LiteralPath $taskSentinel -Raw).Trim() -ne 'Synthetic archive must survive uninstall.') { throw 'Archive sentinel modified.' }
Write-Output 'PASS: install, installed app, uninstall, and preservation of separate archive.'
