$installPath = "C:\ProgramData\Microsoft\SLAPS"

if (![System.IO.Directory]::Exists($installPath)) {
    New-Item -ItemType Directory -Force -Path $installPath
}

Copy-Item -Path .\New-LocalAdmin.ps1 -Destination $installPath


# Create a Scheduled Task if it is not present.
$taskName = "SLAPS Password Reset"
$task = $null
$task = Get-ScheduledTask | Where-Object {$_.TaskName -like "$taskName"}
    
if ($task -eq $null) {
        Start-Process -FilePath $PSScriptRoot\schtask.bat | Out-Null
}

Start-Sleep 10

$LTR = (Get-ScheduledTask | Where-Object {$_.TaskName -like "$taskName"} | Get-ScheduledTaskInfo).LastTaskResult

if ($LTR -eq "267011") {
    Start-ScheduledTask -TaskName "$taskName" | Out-Null
}