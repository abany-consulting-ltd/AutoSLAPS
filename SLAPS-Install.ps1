
 # start logging to TEMP in file "scriptname.log"
 $null = Start-Transcript -Path "$env:TEMP\$($(Split-Path $PSCommandPath -Leaf).ToLower().Replace(".ps1",".log"))"

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
        Start-Process -FilePath $installPath\schtask.bat | Out-Null
        #Start-Process "schtasks /Create /SC MONTHLY /MO 3 /TN "SLAPS Password Reset" /TR "Powershell.exe -WindowStyle Hidden -NonInteractive -ExecutionPolicy Bypass -File "C:\ProgramData\Microsoft\SLAPS\New-LocalAdmin.ps1"" /RU SYSTEM /RL HIGHEST /F >NUL"
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