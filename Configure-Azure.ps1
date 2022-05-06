########################################################################################################################################################
#
# Configure-Azure.ps1
# -----------------------
# 
# AUTHOR(S): Mark Kinsey (https://www.linkedin.com/in/markdkinsey/)
#
#########################################################################################################################################################

Function Create-HttpTriggerFunction {

    Param(
      [Parameter (Mandatory=$True)]
      [String] $funRG,
      [String] $funName,
      [String] $funLocation,
      [String] $funTestData
    )

    $fnName = "Set-KeyVaultSecret"
    $FileContent = "$(Get-Content $env:SystemRoot\TEMP\Set-KeyVaultSecret.ps1 -Raw)"

    $props = @{
        name = "Set-KeyVaultSecret"
        script_root_path_href = "https://$funName.azurewebsites.net/admin/vfs/site/wwwroot/Set-KeyVaultSecret/"
        script_href = "https://$funName.azurewebsites.net/admin/vfs/site/wwwroot/Set-KeyVaultSecret/run.ps1"
        config_href = "https://$funName.azurewebsites.net/admin/vfs/site/wwwroot/Set-KeyVaultSecret/function.json"
        test_data_href = "https://$funName.azurewebsites.net/admin/vfs/data/Functions/sampledata/Set-KeyVaultSecret.dat"
        href = "https://$funName.azurewebsites.net/admin/functions/Set-KeyVaultSecret"
            config = @{
                bindings = @(
                    @{
                    authLevel = "function"
                    type = "httpTrigger"
                    direction = "in"
                    webHookType = ""
                    name = "Request"
                        methods = @(
                            "get"
                            "post"
                            )
                    }
                    @{
                    type = "http"
                    direction = "out"
                    name = "Response"
                    }
                )
        }
        files = @{
            "run.ps1" = $FileContent
        }
        test_data = $funTestData
        invoke_url_template = "https://$funName.azurewebsites.net/api/set-keyvaultsecret"
        language = "powershell"
        isDisabled = $false
    }

    New-AzResource -ResourceGroupName $funRG -ResourceType Microsoft.Web/sites/functions -ResourceName $funName/$fnName -Location $funLocation -PropertyObject $props -Force
}



function Install-IntuneApp {
    param (
        OptionalParameters
    )
    
    # Package MSI as .intunewin file
    $SourceFolder = "C:\Win32Apps\Source\7-Zip"
    $SetupFile = "7z1900-x64.msi"
    $OutputFolder = "C:\Win32Apps\Output"
    $Win32AppPackage = New-IntuneWin32AppPackage -SourceFolder $SourceFolder -SetupFile $SetupFile -OutputFolder $OutputFolder -Verbose

    # Get MSI meta data from .intunewin file
    $IntuneWinFile = $Win32AppPackage.Path
    $IntuneWinMetaData = Get-IntuneWin32AppMetaData -FilePath $IntuneWinFile

    # Create custom display name like 'Name' and 'Version'
    $DisplayName = $IntuneWinMetaData.ApplicationInfo.Name + " " + $IntuneWinMetaData.ApplicationInfo.MsiInfo.MsiProductVersion
    $Publisher = $IntuneWinMetaData.ApplicationInfo.MsiInfo.MsiPublisher

    # Create MSI detection rule
    $DetectionRule = New-IntuneWin32AppDetectionRuleMSI -ProductCode $IntuneWinMetaData.ApplicationInfo.MsiInfo.MsiProductCode -ProductVersionOperator "greaterThanOrEqual" -ProductVersion $IntuneWinMetaData.ApplicationInfo.MsiInfo.MsiProductVersion

    # Create custom return code
    $ReturnCode = New-IntuneWin32AppReturnCode -ReturnCode 1337 -Type "retry"

    # Convert image file to icon
    $ImageFile = "C:\Win32Apps\Logos\7-Zip.png"
    $Icon = New-IntuneWin32AppIcon -FilePath $ImageFile

    # Add new MSI Win32 app
    $Win32App = Add-IntuneWin32App -FilePath $IntuneWinFile -DisplayName $DisplayName -Description "Install 7-zip application" -Publisher $Publisher -InstallExperience "system" -RestartBehavior "suppress" -DetectionRule $DetectionRule -ReturnCode $ReturnCode -Icon $Icon -Verbose

    # Add assignment for all users
    Add-IntuneWin32AppAssignmentAllUsers -ID $Win32App.id -Intent "available" -Notification "showAll" -Verbose

}



$null = Start-Transcript -Path "$env:SystemRoot\TEMP\$($(Split-Path $PSCommandPath -Leaf).ToLower().Replace(".ps1",".log"))"

# == IMPORT VARIABLES =================================================================================================================
# -- Variabes to be set to suit your requirements within the variables.json file
$JSON = Get-Content -Raw -Path $PSScriptRoot/variables.json
$var = @{}
(ConvertFrom-Json $JSON).psobject.properties | Foreach-object { $var[$_.Name] = $_.Value }

$azTen = $var.Azure_Tenent_ID
$azSub = $var.Azure_Subscription_ID

# AZURE VAULT
$vaultName = $var.Azure_Vault_Name
$vaultRG = $var.Azure_Vault_ResourceGroup
$vaultLocation = $var.Azure_Vault_Location

# AZURE FUNCTION
$funName = $var.Azure_Function_Name
$funRG = $var.Azure_Function_ResourceGroup
$funLocation = $var.Azure_Function_Location
$funStorage = $var.Azure_Storage_Name
$funTestData = $var.Test_Data
$admin_Username = $var.Local_Admin_UserName

# ------------------------------------------------------------------------------------------------------------------------------------

if ($azTen) {} else {
    Write-Error "Unable to get values from variables.json"
    $null = Stop-Transcript
    exit
}

if (Get-AzContext) {} else {
    Connect-AzAccount -Tenant $azTen -SubscriptionId $azSub
}



if (Get-AzContext) {} else {
    Write-Error "Unable to establish session to AzureCloud"
    $null = Stop-Transcript
    exit
}


# Create the vault
try {
    New-AzKeyVault -Name $vaultName -ResourceGroupName $vaultRG -Location $vaultLocation
}
catch {
    Write-Error $_
    $null = Stop-Transcript
    exit
}




# Create the function
try {
    New-AzFunctionApp -Name $funName -ResourceGroupName $funRG -Location $funLocation -StorageAccountName $funStorage -Runtime PowerShell
}
catch {
    Write-Error $_
    $null = Stop-Transcript
    exit
}

# Assign a managed service identity
Update-AzFunctionApp -Name $funName -ResourceGroupName $funRG -IdentityType SystemAssigned -Force

# Get the ObjectID of function
$funObj = (Get-AzADServicePrincipal -SearchString $funName).Id

# Configure access policy
Set-AzKeyVaultAccessPolicy -VaultName $vaultName -ObjectId $funObj -PermissionsToSecrets Get,Set

(Get-Content $PSScriptRoot\Set-KeyVaultSecret.ps1) -Replace 'AZ_VAULT_NAME', $vaultName | Set-Content $env:SystemRoot\TEMP\Set-KeyVaultSecret.ps1 

Start-Sleep 10

# Get function URI
$http_KeyVault = Create-HttpTriggerFunction -funRG $funRG -funName $funName -funLocation $funLocation -funTestData $funTestData
$http_KeyVault_key = (Invoke-AzResourceAction -ResourceId $($http_KeyVault.ResourceId) -Action "listKeys" -Force).default
$http_KeyVault_URI = "https://$funName.azurewebsites.net/api/Set-KeyVaultSecret?code=$http_KeyVault_key"

# Package the Intune application
if (![System.IO.Directory]::Exists("$env:SystemRoot\TEMP\SLAPS")) {
    New-Item -ItemType Directory -Force -Path "$env:SystemRoot\TEMP\SLAPS"
}

(Get-Content $PSScriptRoot\SLAPS-Rotate.ps1) -Replace 'AZ_FUN_URI', $http_KeyVault_URI | Set-Content $env:SystemRoot\TEMP\SLAPS\SLAPS-Rotate.ps1 
(Get-Content $PSScriptRoot\SLAPS-Rotate.ps1) -Replace 'ADMIN.NAME', $admin_Username | Set-Content $env:SystemRoot\TEMP\SLAPS\SLAPS-Rotate.ps1 



Copy-Item -Path $PSScriptRoot\schtask.bat -Destination "$env:SystemRoot\TEMP\SLAPS"
Copy-Item -Path $PSScriptRoot\SLAPS-Install.ps1 -Destination "$env:SystemRoot\TEMP\SLAPS"


Set-Location $PSScriptRoot
.\IntuneWinAppUtil.exe -c C:\SLAPS -s C:\SLAPS\SLAPS-Install.ps1 -o C:\


# Clean up
Remove-Item -Path $env:SystemRoot\TEMP\Set-KeyVaultSecret.ps1 -Force
Remove-Item -Path $env:SystemRoot\TEMP\SLAPS-Rotate.ps1 -Force



$null = Stop-Transcript