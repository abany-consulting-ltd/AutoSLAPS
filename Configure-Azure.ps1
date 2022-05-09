########################################################################################################################################################
#
# Configure-Azure.ps1
# -----------------------
# 
# AUTHOR(S): Mark Kinsey (https://www.linkedin.com/in/markdkinsey/)
#
#########################################################################################################################################################

Function Install-HttpTriggerFunction {

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

    # ==========================================================================================================================================
    #
    # Function base code taken from https://github.com/MSEndpointMgr/IntuneWin32App
    # Credit goes to all contributers within this repo
    #
    # ==========================================================================================================================================

    param (
        [Parameter (Mandatory=$True)]
        [String] $SourceFolder,
        [String] $SetupFile,
        [String] $OutputFolder
    )
    
    # Package MSI as .intunewin file
    $Win32AppPackage = New-IntuneWin32AppPackage -SourceFolder $SourceFolder -SetupFile $SetupFile -OutputFolder $OutputFolder -Verbose

    # Get MSI meta data from .intunewin file
    #$IntuneWinFilePath = "$env:SystemRoot\TEMP\SLAPS-Install.intunewin"
    #$IntuneWinFile = $Win32AppPackage.Path
    #$IntuneWinMetaData = Get-IntuneWin32AppMetaData -FilePath $IntuneWinFile

    # Create custom display name like 'Name' and 'Version'
    $DisplayName = "AutoSLAPS"
    $Publisher = "Abany Consulting Limited"

    # Create PowerShell script detection rule
    $DetectionScriptFile = "$PSScriptRoot\SLAPS-Detect.ps1"
    $DetectionRule = New-IntuneWin32AppDetectionRuleScript -ScriptFile $DetectionScriptFile -EnforceSignatureCheck $false -RunAs32Bit $false

    # Create custom return code
    $ReturnCode = New-IntuneWin32AppReturnCode -ReturnCode 1337 -Type "retry"

    # Add install & uninstall command lines
    $InstallCLI = "powershell -ex bypass -windowstyle Hidden -file SLAPS-Install.ps1"
    $UnInstallCLI = "powershell -ex bypass -windowstyle Hidden -file SLAPS-Install.ps1"

    # Convert image file to icon
    $ImageFile = "$PSScriptRoot\appfiles\logo.png"
    $Icon = New-IntuneWin32AppIcon -FilePath $ImageFile

    # Add new MSI Win32 app
    $Win32App = Add-IntuneWin32App -FilePath $Win32AppPackage.Path -DisplayName $DisplayName -Description $DisplayName -Publisher $Publisher -InstallExperience "system" -InstallCommandLine $InstallCLI -UninstallCommandLine $UnInstallCLI -RestartBehavior "suppress" -DetectionRule $DetectionRule -ReturnCode $ReturnCode -Icon $Icon -Verbose

    # Add assignment for all users
    # Add-IntuneWin32AppAssignmentAllUsers -ID $Win32App.id -Intent "available" -Notification "showAll" -Verbose

}


$scriptName = $MyInvocation.MyCommand.Name
$transcriptFile = $ScriptName -replace ".ps1",".log"
$null = Start-Transcript -Path "$env:SystemRoot\TEMP\$transcriptFile"

# == IMPORT VARIABLES =================================================================================================================
# -- Variabes to be set to suit your requirements within the variables.json file

$JSON = Get-Content -Raw -Path $PSScriptRoot/variables.json
$var = @{}
(ConvertFrom-Json $JSON).psobject.properties | Foreach-object { $var[$_.Name] = $_.Value }

# AZURE CREDENTIALS
$azUN = $var.Azure_Username
$azPass = $var.Azure_Password
$azSecPass = ConvertTo-SecureString $azPass -AsPlainText -Force
$azCreds = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList ($azUN, $azSecPass)


# TENENCY INFO
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

# INTUNE APP
$SourceFolder = "$env:SystemRoot\TEMP\SLAPS"
$SetupFile = "SLAPS-Install.ps1"
$OutputFolder = "$env:SystemRoot\TEMP"

# -------------------------------------------------------------------------------------------------------------------------------------

# -- Install module dependecies --

# NuGet
$packageProvider = Get-PackageProvider -Name Nuget -ListAvailable -ErrorAction SilentlyContinue
if ($packageProvider)
{
    Write-Output "NuGet package provider $($packageProvider.Version) is already installed"
}
else
{
    Write-Output "Attempting to install NuGet package provider"
    Install-PackageProvider -Name NuGet -MinimumVersion 2.8.5.201 -ForceBootstrap -Confirm:$false -Force
}


# Azure
$AzModule = Get-InstalledModule Az
if ($AzModule)
{
    Write-Output "Module $($AzModule.Name) is already installed"
}
else
{
    Write-Output "Attempting to install Az Module module"
    Install-Module -Name Az -Repository PSGallery -Force
}


# Intune
$inTuneModule = Get-InstalledModule IntuneWin32app
if ($inTuneModule)
{
    Write-Output "Module $($inTuneModule.Name) is already installed"
}
else
{
    Write-Output "Attempting to install InTuneWin32App module"
    Install-Module -Name IntuneWin32App -Repository PSGallery -Force
}



if ($azTen) {} else {
    Write-Error "Unable to get values from variables.json"
    $null = Stop-Transcript
    exit
}

if (Get-AzContext) {} else {
    Connect-AzAccount -Tenant $azTen -SubscriptionId $azSub -Credential $azCreds
}


if (Get-AzContext) {} else {
    Write-Error "Unable to establish session to AzureCloud"
    $null = Stop-Transcript
    exit
}

$IntuneGraphConnection = Connect-MSIntuneGraph -TenantID $azTen

if ($IntuneGraphConnection) {} else {
    Write-Error "Unable to establish session to Intune Graph API"
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
$http_KeyVault = Install-HttpTriggerFunction -funRG $funRG -funName $funName -funLocation $funLocation -funTestData $funTestData
$http_KeyVault_key = (Invoke-AzResourceAction -ResourceId $($http_KeyVault.ResourceId) -Action "listKeys" -Force).default
$http_KeyVault_URI = "https://$funName.azurewebsites.net/api/Set-KeyVaultSecret?code=$http_KeyVault_key"

# Package the Intune application
if (![System.IO.Directory]::Exists("$env:SystemRoot\TEMP\SLAPS")) {
    New-Item -ItemType Directory -Force -Path "$env:SystemRoot\TEMP\SLAPS"
}

(Get-Content $PSScriptRoot\SLAPS-Rotate.ps1) -Replace 'AZ_FUN_URI', $http_KeyVault_URI | Set-Content $env:SystemRoot\TEMP\SLAPS\SLAPS-Rotate.ps1 
(Get-Content $env:SystemRoot\TEMP\SLAPS\SLAPS-Rotate.ps1) -Replace 'ADMIN.NAME', $admin_Username | Set-Content $env:SystemRoot\TEMP\SLAPS\SLAPS-Rotate.ps1 



Copy-Item -Path $PSScriptRoot\schtask.bat -Destination "$env:SystemRoot\TEMP\SLAPS"
Copy-Item -Path $PSScriptRoot\SLAPS-Install.ps1 -Destination "$env:SystemRoot\TEMP\SLAPS"

Import-Module IntuneWin32App
Connect-MSIntuneGraph -TenantID $azTen
Install-IntuneApp -SourceFolder $SourceFolder -SetupFile $SetupFile -OutputFolder $OutputFolder

# Clean up
Remove-Item -LiteralPath "$env:SystemRoot\TEMP\SLAPS" -Force -Recurse
Remove-Item $env:SystemRoot\TEMP\SLAPS-Install.intunewin -Force
Remove-Item $env:SystemRoot\TEMP\Set-KeyVaultSecret.ps1 -Force



$null = Stop-Transcript