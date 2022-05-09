
# start logging to TEMP in file "scriptname.log"
$scriptName = $MyInvocation.MyCommand.Name
$transcriptFile = $ScriptName -replace ".ps1",".log"
$null = Start-Transcript -Path "$env:SystemRoot\TEMP\$transcriptFile"

$installPath = "C:\ProgramData\Microsoft\SLAPS"

if (![System.IO.Directory]::Exists($installPath)) {
    New-Item -ItemType Directory -Force -Path $installPath
}

Copy-Item -Path '.\SLAPS-Rotate.ps1' -Destination $installPath
Copy-Item -Path .\schtask.bat -Destination $installPath


# Create a Scheduled Task if it is not present.
$taskName = "SLAPS Password Reset"
$task = $null
$task = Get-ScheduledTask | Where-Object {$_.TaskName -like "$taskName"}
    
if ($task -eq $null) {
    $tn = get-date -f hh:mm
    $taskTrigger = New-ScheduledTaskTrigger -Daily -DaysInterval 90 -At $tn
    $taskAction = New-ScheduledTaskAction -Execute 'PowerShell.exe' -Argument "-WindowStyle Hidden -NonInteractive -ExecutionPolicy Bypass -File C:\ProgramData\Microsoft\SLAPS\SLAPS-Rotate.ps1"
    $taskSettings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -RunOnlyIfNetworkAvailable
    Register-ScheduledTask -TaskName $taskName -Action $taskAction -Trigger $taskTrigger -User SYSTEM -Settings $taskSettings -RunLevel Highest
}

Start-Sleep 10

# Apply additional settings for the Scheduled Task
$task = Get-ScheduledTask | Where-Object {$_.TaskName -like "$taskName"}

if ($task -eq $null) {
    throw "The Scheduled Task has not installed properly. Cannot continue."
} else {
    Set-ScheduledTask -TaskName $taskName -Settings $(New-ScheduledTaskSettingsSet -StartWhenAvailable)

    Start-Sleep 5

    $LTR = (Get-ScheduledTask | Where-Object {$_.TaskName -like "$taskName"} | Get-ScheduledTaskInfo).LastTaskResult

    if ($LTR -eq "267011") {
        Start-ScheduledTask -TaskName "$taskName" | Out-Null
    } else {
        Write-Output "Scheduled task already present with run history.. no need for initial run."
    }
}


$null = Stop-Transcript