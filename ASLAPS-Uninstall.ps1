
# start logging to TEMP in file "scriptname.log"
$scriptName = $MyInvocation.MyCommand.Name
$transcriptFile = $ScriptName -replace ".ps1",".log"
$null = Start-Transcript -Path "$env:SystemRoot\TEMP\$transcriptFile"


# Remove Local Admin and enable built in
$builtInAdmin = Get-LocalUser -Name Administrator
            
if ($builtInAdmin.Enabled -eq "False") {
    Enable-LocalUser -Name Administrator -Confirm:$false
        if($?) {
            Write-Output "Enabled the built in Administrator account"
        } else {
            Write-Output "Unable to enable the built in Administrator account. Uninstallation of AutoASLAPS will not continue until the built in Administrator account can be enabled."
            exit
        }
}


# Remove Scheduled Task
Get-ScheduledTask "ASLAPS Password Reset" | Unregister-ScheduledTask -Confirm:$False


# Remove directory
Remove-Item -LiteralPath "C:\ProgramData\Microsoft\ASLAPS" -Force -Recurse


$null = Stop-Transcript