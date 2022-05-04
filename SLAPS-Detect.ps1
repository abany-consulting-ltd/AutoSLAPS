
$resetFile = Get-ChildItem -LiteralPath C:\ProgramData\Microsoft\SLAPS\New-LocalAdmin.ps1 -ErrorAction SilentlyContinue
$adminUser = Get-LocalUser -Name acl.iadmin -ErrorAction SilentlyContinue
$task = Get-ScheduledTask -TaskName "SLAPS Password Reset" -ErrorAction SilentlyContinue

if (($resetFile) -and ($adminUser) -and ($task)) {
    Write-Output "All items installed OK"
    Exit 0
}

elseif (($resetFile) -and ($adminUser) -and ($task -eq $null)) {
    Write-Output "Could not detect Scheduled Task"
    Exit 1
}

elseif (($resetFile) -and ($adminUser -eq $null) -and ($task)) {
    Write-Output "Could not detect local admin account"
    Exit 1
}


else {
    Write-Output "Application not detected"
    Exit 1
}