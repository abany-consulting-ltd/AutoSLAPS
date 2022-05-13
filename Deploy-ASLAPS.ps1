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

    param (
        [Parameter (Mandatory=$True)]
        [String] $SourceFolder,
        [String] $SetupFile,
        [String] $OutputFolder,
        [String] $appVersion
    )
    
    # Set application version
    $line = Get-Content $env:SystemRoot\TEMP\ASLAPS\ASLAPS-Rotate.ps1 | Select-String "# Application Verion:" | Select-Object -ExpandProperty Line
    $newline = '# Application Verion: ' + "$appVersion"
    $content = Get-Content $env:SystemRoot\TEMP\ASLAPS\ASLAPS-Rotate.ps1
    $content | ForEach-Object {$_ -replace $line,$newline} | Set-Content $env:SystemRoot\TEMP\ASLAPS\ASLAPS-Rotate.ps1

    Set-Content $env:SystemRoot\TEMP\ASLAPS\vers.txt $appVersion

    # Package content as .intunewin file
    $Win32AppPackage = New-IntuneWin32AppPackage -SourceFolder $SourceFolder -SetupFile $SetupFile -OutputFolder $OutputFolder -Verbose

    $DisplayName = "AutoSLAPS"
    $Publisher = "Abany Consulting Limited"

    # Create detection rule
    $DetectionRule = New-IntuneWin32AppDetectionRule -File -FilePath C:\ProgramData\Microsoft\ASLAPS -FileOrFolderName installState.txt -FileDetectionType exists

    # Create requirement rule
    $RequirementRule = New-IntuneWin32AppRequirementRule -MinimumSupportedOperatingSystem 1903 -Architecture All 

    # Add install & uninstall command lines
    $InstallCLI = "powershell -ex bypass -windowstyle Hidden -file ASLAPS-Install.ps1"
    $UnInstallCLI = "powershell -ex bypass -windowstyle Hidden -file ASLAPS-UnInstall.ps1"

    # Convert image file to icon
    $ImageFile = "$PSScriptRoot\appfiles\logo.png"
    $Icon = New-IntuneWin32AppIcon -FilePath $ImageFile

    # Add new MSI Win32 app
    Add-IntuneWin32App -FilePath $Win32AppPackage.Path -DisplayName $DisplayName -Description $DisplayName -AppVersion $appVersion -Publisher $Publisher -InstallExperience "system" -InstallCommandLine $InstallCLI -UninstallCommandLine $UnInstallCLI -RestartBehavior "suppress" -DetectionRule $DetectionRule -RequirementRule $RequirementRule -Icon $Icon -Verbose


}

# Set transcript file and start
$scriptName = $MyInvocation.MyCommand.Name
$transcriptFile = $ScriptName -replace ".ps1",".log"
$null = Start-Transcript -Path "$env:SystemRoot\TEMP\$transcriptFile"


# == IMPORT VARIABLES =================================================================================================================
# -- Variabes to be set to suit your requirements within the variables.json file
# -- DO NOT ALTER IN VARIABLES IN THIS FILE --

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
$appVersion = $var.Intune_App_Version
$SourceFolder = "$env:SystemRoot\TEMP\ASLAPS"
$SetupFile = "ASLAPS-Install.ps1"
$OutputFolder = "$env:SystemRoot\TEMP"

$passLength = $var.Password_Char_Length

# -------------------------------------------------------------------------------------------------------------------------------------

# -- Check module dependecies and install if missing --

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


# AzureAD
$AzADModule = Get-InstalledModule AzureAD
if ($AzADModule)
{
    Write-Output "Module $($AzADModule.Name) is already installed"
}
else
{
    Write-Output "Attempting to install Az Module module"
    Install-Module -Name AzureAD -Repository PSGallery -Force
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

Connect-AzureAD -TenantId $azTen -Credential $azCreds


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

# Assign a managed service identity to the function
Update-AzFunctionApp -Name $funName -ResourceGroupName $funRG -IdentityType SystemAssigned -Force

# Configure access policy
$funObj = (Get-AzADServicePrincipal -SearchString $funName).Id
Set-AzKeyVaultAccessPolicy -VaultName $vaultName -ObjectId $funObj -PermissionsToSecrets Get,Set

# Import the vault name into the functions PS1 script
(Get-Content $PSScriptRoot\Set-KeyVaultSecret.ps1) -Replace 'AZ_VAULT_NAME', $vaultName | Set-Content $env:SystemRoot\TEMP\Set-KeyVaultSecret.ps1

# Import the password length requirements
(Get-Content $PSScriptRoot\Set-KeyVaultSecret.ps1) -Replace 'PASS_LENGTH', $passLength | Set-Content $env:SystemRoot\TEMP\Set-KeyVaultSecret.ps1

Start-Sleep 10

# Create security group for read
$ADGroup = New-AzureADGroup -DisplayName "AutoSLAPS Password Access" -MailEnabled $false -SecurityEnabled $true -MailNickName "NotSet"
Set-AzKeyVaultAccessPolicy -VaultName $vaultName -ObjectId $ADGroup.ObjectId -PermissionsToKeys get -PermissionsToSecrets get

# Get function URI
$http_KeyVault = Install-HttpTriggerFunction -funRG $funRG -funName $funName -funLocation $funLocation -funTestData $funTestData
$http_KeyVault_key = (Invoke-AzResourceAction -ResourceId $($http_KeyVault.ResourceId) -Action "listKeys" -Force).default
$http_KeyVault_URI = "https://$funName.azurewebsites.net/api/Set-KeyVaultSecret?code=$http_KeyVault_key"

# Create an area within C:\Windows\temp to package the Intune app
if (![System.IO.Directory]::Exists("$env:SystemRoot\TEMP\ASLAPS")) {
    New-Item -ItemType Directory -Force -Path "$env:SystemRoot\TEMP\ASLAPS"
}

# Import the functions URI into the password rotation PS1
(Get-Content $PSScriptRoot\ASLAPS-Rotate.ps1) -Replace 'AZ_FUN_URI', $http_KeyVault_URI | Set-Content $env:SystemRoot\TEMP\ASLAPS\ASLAPS-Rotate.ps1

# Import the local admin username into the password rotation PS1
(Get-Content $env:SystemRoot\TEMP\ASLAPS\ASLAPS-Rotate.ps1) -Replace 'ADMIN.NAME', $admin_Username | Set-Content $env:SystemRoot\TEMP\ASLAPS\ASLAPS-Rotate.ps1 

# Copy the installer/unistaller scripts ready to be packaged
Copy-Item -Path $PSScriptRoot\ASLAPS-Install.ps1 -Destination "$env:SystemRoot\TEMP\ASLAPS"
Copy-Item -Path $PSScriptRoot\ASLAPS-UnInstall.ps1 -Destination "$env:SystemRoot\TEMP\ASLAPS"

# Package the Intune application
Install-IntuneApp -SourceFolder $SourceFolder -SetupFile $SetupFile -OutputFolder $OutputFolder -AppVersion $appVersion

# Clean up
Remove-Item -LiteralPath "$env:SystemRoot\TEMP\ASLAPS" -Force -Recurse
Remove-Item $env:SystemRoot\TEMP\ASLAPS-Install.intunewin -Force
Remove-Item $env:SystemRoot\TEMP\Set-KeyVaultSecret.ps1 -Force



$null = Stop-Transcript