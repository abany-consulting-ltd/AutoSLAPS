
# start logging to TEMP in file "scriptname.log"
$scriptName = $MyInvocation.MyCommand.Name
$transcriptFile = $ScriptName -replace ".ps1",".log"
$null = Start-Transcript -Path "$env:SystemRoot\TEMP\$transcriptFile"

$installPath = "C:\ProgramData\Microsoft\ASLAPS"

if (![System.IO.Directory]::Exists($installPath)) {
    New-Item -ItemType Directory -Force -Path $installPath
}

Copy-Item -Path '.\ASLAPS-Rotate.ps1' -Destination $installPath
Copy-Item -Path '.\vers.txt' -Destination $installPath



# Create a Scheduled Task if it is not present.
$taskName = "ASLAPS Password Reset"
$task = $null
$task = Get-ScheduledTask | Where-Object {$_.TaskName -like "$taskName"}
    
if ($task -eq $null) {
    $tn = get-date -f hh:mm
    $taskTrigger = New-ScheduledTaskTrigger -Daily -DaysInterval 90 -At $tn
    $taskAction = New-ScheduledTaskAction -Execute 'PowerShell.exe' -Argument "-WindowStyle Hidden -NonInteractive -ExecutionPolicy Bypass -File C:\ProgramData\Microsoft\ASLAPS\ASLAPS-Rotate.ps1"
    $taskSettings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries:$true -DontStopIfGoingOnBatteries:$true -RunOnlyIfNetworkAvailable:$true -Hidden:$true
    Register-ScheduledTask -TaskName $taskName -Action $taskAction -Trigger $taskTrigger -User SYSTEM -Settings $taskSettings -RunLevel Highest
}

Start-Sleep 10

# Apply additional settings for the Scheduled Task
$task = Get-ScheduledTask | Where-Object {$_.TaskName -like "$taskName"}

if ($task -eq $null) {
    throw "The Scheduled Task has not installed properly. Cannot continue."
} else {
    
    Start-Sleep 5

    $LTR = (Get-ScheduledTask | Where-Object {$_.TaskName -like "$taskName"} | Get-ScheduledTaskInfo).LastTaskResult

    if ($LTR -eq "267011") {
        Start-ScheduledTask -TaskName "$taskName" | Out-Null
    } else {
        Write-Output "Scheduled task already present with run history.. no need for initial run."
    }
}

# version check
$installedVersion = Get-Content C:\ProgramData\Microsoft\ASLAPS\ASLAPS-Rotate.ps1 | Select-String "# Application Verion:" | Select-Object -ExpandProperty Line
$deployVerion = Get-Content C:\ProgramData\Microsoft\ASLAPS\vers.txt

if ($installedVersion -notlike "*$deployVerion*")
    {
    # sends a non-ok error code to intune - not current version
	Write-Output "Current Version is not latest version"
    $VerionState = "Update required"
    Set-Content C:\ProgramData\Microsoft\ASLAPS\installState.txt $VerionState
} else {
    Write-Output "Application found and running on latest version"
    $VerionState = "Up to date"
    Set-Content C:\ProgramData\Microsoft\ASLAPS\installState.txt $VerionState
}



$null = Stop-Transcript